"""AI IME Daemon：给 Rime 的第 2 位候选出主意

Rime filter 每次刷新候选时同步请求 /suggest，带上按键串和词库前几个候选；
上屏时请求 /commit 记录用户实际选了什么。

出候选的顺序：
  1. 记忆：同一串按键以前上屏过的词（人名等），或以当前按键开头的常用词
  2. LLM，两个问题并行问：
     - 英文：按键串本身是不是英文单词/技术名词（linux → Linux）
     - 上下文：有最近上屏文字时，词库后面的候选是不是比第 1 个更合适
     小模型被要求"拿不准就弃权"，否则它总会挑一个词库候选，把正确的第 1 位挤下去。
LLM 只在预算时间内等待；超时的结果留在缓存里，下次同样的输入直接命中。

通信：$XDG_RUNTIME_DIR/rime-ai/daemon.sock 上的 HTTP
记忆：$XDG_STATE_HOME/rime-ai/memory.json
缓存：进程内 LRU + Dragonfly（Redis 兼容）localhost:6399
LLM：Ollama localhost:11434 (qwen2.5:1.5b-instruct)

提示词按 1.5B 模型调过：输入法只问两个窄问题，靠 few-shot 例子教会小模型弃权和大小写，
效果和 qwen3:4b 持平，CPU 上快 2.5 倍。改提示词时 few-shot 别用测试里会出现的词。
"""

import hashlib
import json
import os
import queue
import signal
import socketserver
import sys
import threading
import time
from collections import OrderedDict
from concurrent.futures import Future
from concurrent.futures import TimeoutError as FutureTimeout
from http.server import BaseHTTPRequestHandler
from pathlib import Path

import redis
import requests

# ── 配置 ──────────────────────────────────────────────────────────────
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "rime-ai"
SOCKET_PATH = Path(os.environ.get("AI_IME_SOCKET", str(RUNTIME_DIR / "daemon.sock")))
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "rime-ai"
MEMORY_FILE = STATE_DIR / "memory.json"

REDIS_HOST = os.environ.get("AI_IME_REDIS_HOST", "127.0.0.1")
REDIS_PORT = int(os.environ.get("AI_IME_REDIS_PORT", "6399"))
CACHE_TTL = int(os.environ.get("AI_IME_CACHE_TTL", "86400"))  # 24h

LLM_BASE_URL = os.environ.get("AI_IME_LLM_URL", "http://127.0.0.1:11434/v1")
LLM_MODEL = os.environ.get("AI_IME_LLM_MODEL", "qwen2.5:1.5b-instruct")
LLM_TIMEOUT = float(os.environ.get("AI_IME_LLM_TIMEOUT", "5.0"))
# 每次按键最多为 LLM 阻塞输入法这么久
BUDGET = float(os.environ.get("AI_IME_BUDGET_MS", "250")) / 1000

MIN_INPUT = 2            # 少于 2 个按键不出候选
EN_MIN_INPUT = 4         # 更短的按键串几乎都是双拼（ui、sd、ni），问英文只会误报
PREFIX_MIN_INPUT = 4     # 至少两个音节才按前缀联想记忆里的词
PREFIX_MIN_COUNT = 2     # 前缀联想只用上屏过至少 2 次的词
CONTEXT_WINDOW = 30 * 60 # 最近上屏文字的时间窗口
CONTEXT_CHARS = 60
MEMORY_MAX_CODES = 20000
RECENT_MAX = 200
STALE_JOB = 2.0          # 排队超过 2 秒的 LLM 请求直接丢弃（用户早已打完）


EN_PROMPT = """判断一串小写字母是不是英文。用户用小鹤双拼打中文，多数按键串是拼音编码，不是英文。
- 是英文单词（包括 test、error 这类普通单词）、技术名词、产品名或缩写：输出它的标准写法。专有名词按官方大小写，如 GitHub、JavaScript、iPhone；普通单词保持小写
- 否则（拼音编码、不完整的单词、看不出意思的字母）：只输出 -
不要解释"""
# 小模型照着例子学：专有名词、普通单词、双拼编码交错排列，各占约三分之一
EN_SHOTS = [("redis", "Redis"), ("uiji", "-"), ("build", "build"), ("javascript", "JavaScript"), ("nihk", "-"),
            ("hello", "hello"), ("ubuntu", "Ubuntu"), ("vsdk", "-"), ("value", "value"), ("iphone", "iPhone"),
            ("kube", "-"), ("json", "JSON"), ("ugdk", "-"), ("push", "push"), ("chrome", "Chrome"), ("dmxi", "-")]

CTX_PROMPT = """你是中文输入法的候选助手。给你用户最近上屏的文字，和当前按键的词库候选（带编号）。
- 最近上屏的文字明确说明应该是另一个候选：输出它的编号
- 否则输出 0（大多数情况都是 0，词库第 1 候选通常就对）
只输出一项，不要解释"""
# (最近上屏, 按键, 词库候选, 答案)
CTX_SHOTS = [
    ("我在路边拦了辆出租车，", "uiji", ["实际", "世纪", "司机", "时机", "史记"], "3"),
    ("这个方案", "uiji", ["实际", "世纪", "司机", "时机", "史记"], "0"),
    ("Docker 容器", "uijp", ["世界", "师姐", "视界"], "0"),
    ("他在河里钓到一条", "dayu", ["大雨", "大于", "大鱼"], "3"),
    ("外面下着", "dayu", ["大于", "大雨", "大鱼"], "2"),
    ("今天", "dayu", ["大雨", "大于", "大鱼"], "0"),
]


# ── 记忆：用户实际上屏过什么 ─────────────────────────────────────────
class Memory:
    """codes: 按键串 → {上屏文字: [次数, 最近时间]}；recent: [[时间, 上屏文字], ...]"""

    def __init__(self, path: Path):
        self.path = path
        self.lock = threading.Lock()
        self.codes: dict[str, dict[str, list]] = {}
        self.recent: list[list] = []
        try:
            data = json.loads(path.read_text())
            self.codes = data.get("codes", {})
            self.recent = data.get("recent", [])
        except (OSError, json.JSONDecodeError):
            pass

    def record(self, code: str, text: str):
        now = time.time()
        with self.lock:
            entry = self.codes.setdefault(code, {}).setdefault(text, [0, now])
            entry[0] += 1
            entry[1] = now
            self.recent.append([now, text])
            del self.recent[:-RECENT_MAX]
            if len(self.codes) > MEMORY_MAX_CODES:
                # 淘汰最久没用过的按键串
                oldest = sorted(self.codes, key=lambda c: max(v[1] for v in self.codes[c].values()))
                for c in oldest[: len(self.codes) - MEMORY_MAX_CODES]:
                    del self.codes[c]
            self._save()

    def _save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            json.dump({"codes": self.codes, "recent": self.recent}, f, ensure_ascii=False)
        os.replace(tmp, self.path)

    @staticmethod
    def _best(texts: dict[str, list]) -> tuple[str, int]:
        text, (count, _) = max(texts.items(), key=lambda kv: (kv[1][0], kv[1][1]))
        return text, count

    def exact(self, code: str) -> str | None:
        with self.lock:
            texts = self.codes.get(code)
            return self._best(texts)[0] if texts else None

    def by_prefix(self, code: str) -> str | None:
        """以 code 开头、更长的按键串里上屏次数最多的词"""
        best, best_count = None, PREFIX_MIN_COUNT - 1
        with self.lock:
            for c, texts in self.codes.items():
                if len(c) > len(code) and c.startswith(code):
                    text, count = self._best(texts)
                    if count > best_count:
                        best, best_count = text, count
        return best

    def context(self) -> str:
        cutoff = time.time() - CONTEXT_WINDOW
        with self.lock:
            text = "".join(t for ts, t in self.recent if ts > cutoff)
        return text[-CONTEXT_CHARS:]


# ── 缓存：进程内 LRU 挡在 Dragonfly 前面 ─────────────────────────────
class Cache:
    def __init__(self):
        self.local: OrderedDict[str, str] = OrderedDict()
        self.lock = threading.Lock()
        self.r: redis.Redis | None = None

    def _redis(self) -> redis.Redis | None:
        if self.r is None:
            try:
                r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True,
                                socket_timeout=0.5, socket_connect_timeout=0.5)
                r.ping()
                self.r = r
            except (redis.ConnectionError, redis.TimeoutError, OSError):
                return None
        return self.r

    def get_local(self, key: str) -> str | None:
        with self.lock:
            if key in self.local:
                self.local.move_to_end(key)
                return self.local[key]
        return None

    def get_remote(self, key: str) -> str | None:
        """只在 LLM 工作线程里调用：Dragonfly 空闲时是停的，唤醒要好几秒"""
        r = self._redis()
        if r is None:
            return None
        try:
            value = r.get(key)
        except (redis.ConnectionError, redis.TimeoutError):
            self.r = None
            return None
        if value is not None:
            self._put_local(key, value)
        return value

    def set(self, key: str, value: str):
        self._put_local(key, value)
        r = self._redis()
        if r is None:
            return
        try:
            r.set(key, value, ex=CACHE_TTL)
        except (redis.ConnectionError, redis.TimeoutError):
            self.r = None

    def _put_local(self, key: str, value: str):
        with self.lock:
            self.local[key] = value
            self.local.move_to_end(key)
            while len(self.local) > 2000:
                self.local.popitem(last=False)


# ── LLM ───────────────────────────────────────────────────────────────
def _with_shots(system: str, shots: list[tuple[str, str]], question: str) -> list[dict]:
    messages = [{"role": "system", "content": system}]
    for q, a in shots:
        messages += [{"role": "user", "content": q}, {"role": "assistant", "content": a}]
    messages.append({"role": "user", "content": question})
    return messages


def english_messages(code: str) -> list[dict]:
    return _with_shots(EN_PROMPT, EN_SHOTS, code)


def _ctx_question(context: str, code: str, cands: list[str]) -> str:
    numbered = " ".join(f"{i}.{c}" for i, c in enumerate(cands, 1))
    return f"最近上屏: {context}\n按键: {code}\n词库候选: {numbered}"


def context_messages(code: str, cands: list[str], context: str) -> list[dict]:
    shots = [(_ctx_question(*shot[:3]), shot[3]) for shot in CTX_SHOTS]
    return _with_shots(CTX_PROMPT, shots, _ctx_question(context, code, cands))


def parse_english(code: str, answer: str) -> str | None:
    # 只接受同一串字母换了大小写/加了标点（Node.js），防止模型自由发挥成别的词
    letters = "".join(ch for ch in answer.lower() if ch.isalpha())
    return answer if letters == code else None


def parse_context(cands: list[str], answer: str) -> str | None:
    if answer.isdigit() and 2 <= int(answer) <= len(cands):
        return cands[int(answer) - 1]
    return None


def clean(text: str) -> str | None:
    text = text.strip().strip("\"'“”‘’「」").strip()
    # 小模型偶尔会解释一通；候选应该是一行短文本
    if not text or "\n" in text or len(text) > 24 or text == "-":
        return None
    return text


def query_llm(messages: list[dict]) -> str | None:
    resp = requests.post(
        f"{LLM_BASE_URL}/chat/completions",
        json={"model": LLM_MODEL, "messages": messages, "max_tokens": 24, "temperature": 0},
        timeout=LLM_TIMEOUT,
    )
    resp.raise_for_status()
    return clean(resp.json()["choices"][0]["message"]["content"])


class LlmPool:
    """后进先出：用户连续打字时优先算最新的输入，过期的直接丢弃"""

    def __init__(self, cache: Cache, workers: int = 2):
        self.cache = cache
        self.jobs: queue.LifoQueue = queue.LifoQueue()
        self.inflight: dict[str, Future] = {}
        self.lock = threading.Lock()
        for _ in range(workers):
            threading.Thread(target=self._work, daemon=True).start()

    def submit(self, key: str, messages: list[dict]) -> Future:
        with self.lock:
            fut = self.inflight.get(key)
            if fut is None:
                fut = Future()
                self.inflight[key] = fut
                self.jobs.put((time.monotonic(), key, messages, fut))
        return fut

    def _work(self):
        while True:
            queued_at, key, messages, fut = self.jobs.get()
            result = None
            try:
                if time.monotonic() - queued_at <= STALE_JOB:
                    result = self.cache.get_remote(key)
                    if result is None:
                        result = query_llm(messages) or ""
                        self.cache.set(key, result)
            except Exception as e:  # noqa: BLE001 — 网络/模型错误只影响这一次候选
                print(f"llm error: {e}", file=sys.stderr, flush=True)
            finally:
                with self.lock:
                    self.inflight.pop(key, None)
                fut.set_result(result)


# ── 出候选 ────────────────────────────────────────────────────────────
class Suggester:
    def __init__(self, memory: Memory, cache: Cache, pool: LlmPool):
        self.memory, self.cache, self.pool = memory, cache, pool

    def suggest(self, code: str, cands: list[str]) -> str:
        if len(code) < MIN_INPUT:
            return ""
        top = cands[0] if cands else None
        for remembered in (self.memory.exact(code),
                           self.memory.by_prefix(code) if len(code) >= PREFIX_MIN_INPUT else None):
            if remembered and remembered != top:
                return remembered

        # 先把两个问题都提交，两个 worker 并行算；再按英文优先的顺序在同一个预算内取结果
        questions = []
        if len(code) >= EN_MIN_INPUT:
            questions.append((self._ask(english_messages(code)), lambda a: parse_english(code, a)))
        context = self.memory.context()
        if context and len(cands) >= 2:
            questions.append((self._ask(context_messages(code, cands, context)), lambda a: parse_context(cands, a)))

        deadline = time.monotonic() + BUDGET
        for fut, parse in questions:
            try:
                answer = fut.result(timeout=max(0.0, deadline - time.monotonic()))
            except FutureTimeout:
                continue
            pick = parse(answer) if answer else None
            if pick and pick != top:
                return pick
        return ""

    def _ask(self, messages: list[dict]) -> Future:
        key = "ime:" + hashlib.sha1(json.dumps(messages, ensure_ascii=False).encode()).hexdigest()[:20]
        cached = self.cache.get_local(key)
        if cached is None:
            return self.pool.submit(key, messages)
        fut = Future()
        fut.set_result(cached)
        return fut


# ── HTTP over Unix socket ─────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):
    suggester: Suggester

    def address_string(self):
        return "unix"

    def log_message(self, fmt, *args):
        pass

    def _reply(self, status: int, body: str = ""):
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            data = json.loads(self.rfile.read(length) or b"{}")
            code = str(data.get("input", ""))
        except (ValueError, json.JSONDecodeError):
            return self._reply(400)
        if self.path == "/suggest":
            cands = [str(c) for c in data.get("cands", [])][:5]
            return self._reply(200, self.suggester.suggest(code, cands))
        if self.path == "/commit":
            text = str(data.get("text", ""))
            # 直接上屏按键本身（回车输出字母）不算选词
            if code and text and text != code:
                self.suggester.memory.record(code, text)
            return self._reply(204)
        return self._reply(404)


class UnixHTTPServer(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True

    def get_request(self):
        conn, _ = self.socket.accept()
        return conn, ("unix", 0)


def main():
    SOCKET_PATH.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    SOCKET_PATH.unlink(missing_ok=True)

    cache = Cache()
    Handler.suggester = Suggester(Memory(MEMORY_FILE), cache, LlmPool(cache))
    server = UnixHTTPServer(str(SOCKET_PATH), Handler)
    os.chmod(SOCKET_PATH, 0o600)

    print(f"ai-ime-daemon listening on {SOCKET_PATH}", flush=True)
    print(f"  LLM: {LLM_BASE_URL} model={LLM_MODEL} budget={BUDGET * 1000:.0f}ms", flush=True)
    print(f"  Memory: {MEMORY_FILE}  Cache: {REDIS_HOST}:{REDIS_PORT}", flush=True)

    def shutdown(sig, frame):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        SOCKET_PATH.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
