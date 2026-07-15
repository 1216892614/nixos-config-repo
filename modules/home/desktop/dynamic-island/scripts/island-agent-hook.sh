#!/usr/bin/env bash
# island-agent-hook.sh — Dynamic Island agent 状态更新脚本
# 由 oh-my-openagent claude-code-hooks 或 omp --hook 调用
# 用法: island-agent-hook.sh <action> [options]
#   action: start | done | error
#   环境变量:
#     ISLAND_SOURCE   — "opencode" 或 "omp"
#     ISLAND_MODEL    — 模型名称
#     ISLAND_TASK     — 任务描述
#     ISLAND_RESULT   — 结果（done/error 时）

set -euo pipefail

JSON_FILE="/tmp/island-agent.json"
ACTION="${1:-}"
SOURCE="${ISLAND_SOURCE:-opencode}"
MODEL="${ISLAND_MODEL:-unknown}"
TASK="${ISLAND_TASK:-}"
RESULT="${ISLAND_RESULT:-}"
PID="${ISLAND_PID:-$$}"

# 确保 JSON 文件存在
if [ ! -f "$JSON_FILE" ]; then
  echo "[]" > "$JSON_FILE"
fi

# 读取现有 JSON
EXISTING=$(cat "$JSON_FILE" 2>/dev/null || echo "[]")
if [ -z "$EXISTING" ] || [ "$EXISTING" = "" ]; then
  EXISTING="[]"
fi

TS=$(date +%s)

case "$ACTION" in
  start)
    # 添加新的 running 条目
    # 先清除同 source+pid 的旧条目
    NEW_ENTRY="{\"id\":\"${SOURCE}-${PID}\",\"source\":\"${SOURCE}\",\"pid\":${PID},\"model\":\"${MODEL}\",\"state\":\"running\",\"task\":\"${TASK}\",\"result\":null,\"ts\":${TS}}"
    UPDATED=$(echo "$EXISTING" | jq --argjson entry "$NEW_ENTRY" \
      '[.[] | select(.id != "'"${SOURCE}-${PID}"'")] + [$entry]' 2>/dev/null || echo "[$NEW_ENTRY]")
    echo "$UPDATED" > "$JSON_FILE"
    ;;
  done)
    # 更新为 done 状态
    UPDATED=$(echo "$EXISTING" | jq \
      --arg id "${SOURCE}-${PID}" \
      --arg result "${RESULT:-done}" \
      --argjson ts "$TS" \
      '[.[] | if .id == $id then .state = "done" | .result = $result | .ts = $ts else . end]' 2>/dev/null || echo "$EXISTING")
    echo "$UPDATED" > "$JSON_FILE"
    ;;
  error)
    # 更新为 error 状态
    UPDATED=$(echo "$EXISTING" | jq \
      --arg id "${SOURCE}-${PID}" \
      --arg result "${RESULT:-error}" \
      --argjson ts "$TS" \
      '[.[] | if .id == $id then .state = "error" | .result = $result | .ts = $ts else . end]' 2>/dev/null || echo "$EXISTING")
    echo "$UPDATED" > "$JSON_FILE"
    ;;
  *)
    echo "Usage: $0 {start|done|error}" >&2
    exit 1
    ;;
esac
