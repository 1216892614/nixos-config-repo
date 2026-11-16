"""AI IME Daemon — 监听输入法请求，调用本地 Qwen 返回候选词

通信方式：/tmp/rime-ai/ 下的 request.json / response.json
缓存：Dragonfly (Redis 兼容) localhost:6399
LLM：Ollama localhost:11434 (qwen3:4b)
"""

import json
import os
import time
import hashlib
import signal
import sys
from pathlib import Path

import redis
import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# ── 配置 ──────────────────────────────────────────────────────────────
WORK_DIR = Path("/tmp/rime-ai")
REQUEST_FILE = WORK_DIR / "request.json"
RESPONSE_FILE = WORK_DIR / "response.json"
HISTORY_FILE = WORK_DIR / "history.json"

REDIS_HOST = os.environ.get("AI_IME_REDIS_HOST", "127.0.0.1")
REDIS_PORT = int(os.environ.get("AI_IME_REDIS_PORT", "6399"))
CACHE_TTL = int(os.environ.get("AI_IME_CACHE_TTL", "86400"))  # 24h

LLM_BASE_URL = os.environ.get("AI_IME_LLM_URL", "http://127.0.0.1:11434/v1")
LLM_MODEL = os.environ.get("AI_IME_LLM_MODEL", "qwen3:4b")
LLM_TIMEOUT = float(os.environ.get("AI_IME_LLM_TIMEOUT", "5.0"))

HISTORY_WINDOW = 30 * 60  # 30 分钟滑动窗口
HISTORY_MAX_ITEMS = 50


SYSTEM_PROMPT = """你是一个中文输入法助手。根据用户最近的输入上下文和当前的拼音输入，预测用户最可能想输入的词或短语。

规则：
- 只输出一个最佳候选词/短语，不要解释
- 考虑上下文连贯性
- 如果无法确定，输出最常见的候选
- 不要输出标点符号，除非上下文明确需要
- 直接输出结果，不要任何前缀或后缀
- 不要输出 <think> 或其他标签"""


# ── 输入历史管理 ─────────────────────────────────────────────────────
class InputHistory:
    def __init__(self):
        self.entries: list[dict] = []
        self._load()

    def _load(self):
        if HISTORY_FILE.exists():
            try:
                self.entries = json.loads(HISTORY_FILE.read_text())
            except (json.JSONDecodeError, OSError):
                self.entries = []

    def _save(self):
        try:
            HISTORY_FILE.write_text(json.dumps(self.entries, ensure_ascii=False))
        except OSError:
            pass

    def add(self, msg: str, result: str):
        now = time.time()
        self.entries.append({"msg": msg, "result": result, "ts": now})
        self._prune()
        self._save()

    def _prune(self):
        cutoff = time.time() - HISTORY_WINDOW
        self.entries = [e for e in self.entries if e["ts"] > cutoff]
        if len(self.entries) > HISTORY_MAX_ITEMS:
            self.entries = self.entries[-HISTORY_MAX_ITEMS:]

    def context_str(self) -> str:
        self._prune()
        if not self.entries:
            return ""
        recent = self.entries[-20:]
        return "".join(e["result"] for e in recent)


# ── 缓存 ─────────────────────────────────────────────────────────────
class Cache:
    def __init__(self):
        self.r: redis.Redis | None = None
        self._connect()

    def _connect(self):
        try:
            self.r = redis.Redis(
                host=REDIS_HOST, port=REDIS_PORT,
                decode_responses=True, socket_timeout=0.5,
                socket_connect_timeout=0.5
            )
            self.r.ping()
        except (redis.ConnectionError, redis.TimeoutError, OSError):
            self.r = None

    def _key(self, msg: str, context: str) -> str:
        h = hashlib.md5(f"{context}|{msg}".encode()).hexdigest()[:12]
        return f"ime:{h}"

    def get(self, msg: str, context: str) -> str | None:
        if not self.r:
            self._connect()
        if not self.r:
            return None
        try:
            return self.r.get(self._key(msg, context))
        except (redis.ConnectionError, redis.TimeoutError):
            self.r = None
            return None

    def set(self, msg: str, context: str, result: str):
        if not self.r:
            self._connect()
        if not self.r:
            return
        try:
            self.r.setex(self._key(msg, context), CACHE_TTL, result)
        except (redis.ConnectionError, redis.TimeoutError):
            self.r = None


# ── LLM 调用 ─────────────────────────────────────────────────────────
def query_llm(msg: str, context: str) -> str:
    user_content = ""
    if context:
        user_content += f"最近输入: {context}\n"
    user_content += f"当前拼音: {msg}"

    resp = requests.post(
        f"{LLM_BASE_URL}/chat/completions",
        json={
            "model": LLM_MODEL,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
            "max_tokens": 32,
            "temperature": 0.3,
        },
        timeout=LLM_TIMEOUT,
    )
    resp.raise_for_status()
    content = resp.json()["choices"][0]["message"]["content"].strip()
    # 清理可能的 <think> 标签（Qwen3 thinking mode）
    if "<think>" in content:
        # 取 </think> 之后的内容
        parts = content.split("</think>")
        content = parts[-1].strip() if len(parts) > 1 else ""
    return content


# ── 请求处理 ──────────────────────────────────────────────────────────
def handle_request(history: InputHistory, cache: Cache):
    try:
        data = json.loads(REQUEST_FILE.read_text())
    except (json.JSONDecodeError, OSError):
        return

    req_id = data.get("id")
    msg = data.get("msg", "").strip()
    if not msg or req_id is None:
        return

    # 太短的输入不值得调 LLM
    if len(msg) < 2:
        return

    # 写入 "thinking" 状态
    write_response(req_id, status="thinking")

    context = history.context_str()

    # 查缓存
    cached = cache.get(msg, context)
    if cached:
        write_response(req_id, text=cached)
        history.add(msg, cached)
        return

    # 调 LLM
    try:
        result = query_llm(msg, context)
        if result:
            cache.set(msg, context, result)
            write_response(req_id, text=result)
            history.add(msg, result)
        else:
            write_response(req_id, error="empty")
    except requests.Timeout:
        write_response(req_id, error="timeout")
    except Exception as e:
        write_response(req_id, error=str(e)[:80])


def write_response(req_id: int, text: str | None = None,
                   error: str | None = None, status: str | None = None):
    resp = {"id": req_id}
    if status:
        resp["status"] = status
    if text is not None:
        resp["text"] = text
    if error is not None:
        resp["error"] = error
    try:
        RESPONSE_FILE.write_text(json.dumps(resp, ensure_ascii=False))
    except OSError:
        pass


# ── 文件监听 ──────────────────────────────────────────────────────────
class RequestHandler(FileSystemEventHandler):
    def __init__(self, history: InputHistory, cache: Cache):
        self.history = history
        self.cache = cache
        self._last_id = -1

    def on_modified(self, event):
        if event.src_path == str(REQUEST_FILE):
            self._process()

    def on_created(self, event):
        if event.src_path == str(REQUEST_FILE):
            self._process()

    def _process(self):
        try:
            data = json.loads(REQUEST_FILE.read_text())
            req_id = data.get("id", -1)
            if req_id <= self._last_id:
                return
            self._last_id = req_id
        except (json.JSONDecodeError, OSError):
            return
        handle_request(self.history, self.cache)


# ── 主入口 ────────────────────────────────────────────────────────────
def main():
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    history = InputHistory()
    cache = Cache()

    handler = RequestHandler(history, cache)
    observer = Observer()
    observer.schedule(handler, str(WORK_DIR), recursive=False)
    observer.start()

    print(f"ai-ime-daemon started, watching {WORK_DIR}", flush=True)
    print(f"  LLM: {LLM_BASE_URL} model={LLM_MODEL}", flush=True)
    print(f"  Cache: {REDIS_HOST}:{REDIS_PORT}", flush=True)

    def shutdown(sig, frame):
        observer.stop()
        observer.join()
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == "__main__":
    main()
