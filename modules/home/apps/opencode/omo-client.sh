#!/usr/bin/env bash
set -euo pipefail

port="${1:?missing port}"
cwd="${2:?missing cwd}"
url="http://127.0.0.1:$port"
health="$url/global/health"

for _ in $(seq 1 150); do
  if wget -qO- "$health" >/dev/null 2>&1; then
    cd "$cwd"
    exec opencode attach "$url" --dir "$cwd"
  fi
  sleep 0.2
done

echo "omo: timed out waiting for $health" >&2
exit 1
