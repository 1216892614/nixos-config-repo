#!/usr/bin/env bash
# island-agent-hook.sh — claude-code-hooks 兼容的 shell hook
# oh-my-openagent 从 ~/.claude/settings.json 读取 hooks 配置
# 格式: hooks.UserPromptSubmit / hooks.Stop → command 接收 JSON stdin
#
# 配置示例 (~/.claude/settings.json):
# {
#   "hooks": {
#     "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.config/dynamic-island/island-agent-hook.sh"}]}],
#     "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "~/.config/dynamic-island/island-agent-hook.sh"}]}]
#   }
# }

AGENT_FILE="/tmp/island-agent.json"

# 从 stdin 读取 JSON 事件
INPUT=$(cat)

# 提取 hook_event_name
EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | head -1 | cut -d'"' -f4)
# 提取 prompt（如有）
PROMPT=$(echo "$INPUT" | grep -o '"prompt":"[^"]*"' | head -1 | cut -d'"' -f4 | head -c 60)

write_state() {
  local state="$1"
  local task="$2"
  printf '{"source":"opencode","state":"%s","task":"%s","ts":%d}' \
    "$state" "$task" "$(date +%s)" > "$AGENT_FILE"
}

case "$EVENT" in
  UserPromptSubmit)
    write_state "running" "${PROMPT:-working}"
    ;;
  Stop)
    write_state "done" ""
    ;;
  *)
    # 其他事件（PreToolUse 等）刷新 running 状态
    write_state "running" "working"
    ;;
esac

# 输出空 JSON 表示不修改行为
echo '{}'
