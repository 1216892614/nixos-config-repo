"""将 AI processor 和 filter 注册到 moqi.yaml 的 engine 中"""
import sys

moqi_path = sys.argv[1]  # moqi.yaml

lines = open(moqi_path).readlines()

# ── 注册 processor ─────────────────────────────────────────────────────
# 插入到 processors 块的 speller 之前（让 AI processor 在拼写处理前运行）
in_processors = False
speller_idx = -1
proc_indent = 6

for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped == "processors:" or stripped.startswith("processors:"):
        in_processors = True
    elif in_processors:
        if stripped == "- speller":
            speller_idx = i
            proc_indent = len(line) - len(line.lstrip())
            break
        elif stripped and not stripped.startswith("-") and not stripped.startswith("#"):
            in_processors = False

ai_proc_line = " " * proc_indent + "- lua_processor@*rime_ai_processor  # AI 候选请求\n"
# 检查是否已注册
already_has_proc = any("rime_ai_processor" in l for l in lines)
if not already_has_proc and speller_idx >= 0:
    lines.insert(speller_idx, ai_proc_line)

# ── 注册 filter ────────────────────────────────────────────────────────
# 插入到 filters 块末尾
in_filters = False
last_filter_idx = -1
filter_indent = 6

for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped == "filters:" or stripped.startswith("filters:"):
        in_filters = True
    elif in_filters:
        if stripped.startswith("- ") or stripped.startswith("#- ") or stripped.startswith("# -"):
            last_filter_idx = i
            filter_indent = len(line) - len(line.lstrip())
        elif stripped and not stripped.startswith("#"):
            in_filters = False

ai_filter_line = " " * filter_indent + "- lua_filter@*ai_ime  # AI 候选词\n"
already_has_filter = any("lua_filter@*ai_ime" in l for l in lines)
if not already_has_filter and last_filter_idx >= 0:
    lines.insert(last_filter_idx + 1, ai_filter_line)

open(moqi_path, "w").write("".join(lines))
