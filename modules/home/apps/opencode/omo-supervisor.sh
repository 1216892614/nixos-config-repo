#!/usr/bin/env bash
set -euo pipefail

port="${1:?missing port}"
cwd="${2:?missing cwd}"
server_pid=""

cleanup() {
  if [ -n "$server_pid" ] && kill -0 "$server_pid" >/dev/null 2>&1; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [ -n "${ZELLIJ:-}" ]; then
    zellij action quit >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

"@home@/.local/bin/omo-server" "$port" "$cwd" &
server_pid=$!

"@home@/.local/bin/omo-client" "$port" "$cwd"
