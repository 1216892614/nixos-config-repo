#!/usr/bin/env bash
set -euo pipefail
port="${1:?missing port}"
cwd="${2:?missing cwd}"
cd "$cwd"
exec opencode serve --hostname 127.0.0.1 --port "$port"
