#!/bin/sh
set -eu
COMFYUI_URL="http://service-plane-comfyui:8188"
SABLIER_URL="http://service-plane-sablier:10000"
SESSION_DURATION="30m"
CHECK_INTERVAL=15

log() { echo "[keepalive] $(date '+%H:%M:%S') $*"; }

while true; do
  sleep "$CHECK_INTERVAL"

  # 容器未运行时跳过
  if ! curl -sf "$COMFYUI_URL/api/prompt" >/dev/null 2>&1; then
    continue
  fi

  # 检查队列：queue_running 或 queue_pending 非空 = 有活跃任务
  queue=$(curl -sf "$COMFYUI_URL/api/prompt" 2>/dev/null || echo '{}')
  running=$(echo "$queue" | grep -o '"queue_running":\[[^]]*\]' | grep -c '"' || true)
  pending=$(echo "$queue" | grep -o '"queue_pending":\[[^]]*\]' | grep -c '"' || true)

  if [ "$running" -gt 2 ] || [ "$pending" -gt 2 ]; then
    log "队列活跃 (running=$running, pending=$pending)，刷新 session"
    curl -sf -X PUT \
      "$SABLIER_URL/api/sessions/comfyui" \
      -H "Content-Type: application/json" \
      -d "{\"duration\":\"$SESSION_DURATION\"}" \
      >/dev/null 2>&1 || true
  fi
done
