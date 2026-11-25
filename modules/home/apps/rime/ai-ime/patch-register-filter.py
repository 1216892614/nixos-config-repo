"""将 AI filter 注册到 moqi.yaml 的 engine/filters 末尾"""
import sys

moqi_path = sys.argv[1]  # moqi.yaml

lines = open(moqi_path).readlines()

# 插入到 filters 块末尾：要拿到 uniquifier 之后的最终候选
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
