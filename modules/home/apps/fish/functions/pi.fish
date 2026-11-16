if test (count $argv) -gt 1
  echo "usage: pi [<cols>x<rows>]" >&2
  return 1
end

for cmd in zellij omp
  if not command -sq $cmd
    echo "pi: required command not found: $cmd" >&2
    return 127
  end
end

set -l launcher "$HOME/.local/bin/omp-launch"
if not test -x "$launcher"
  echo "pi: helper not found or not executable: $launcher" >&2
  return 1
end

# ── 确保 SearXNG 服务栈就绪 ──────────────────────────────────────
set -l compose_dir "$HOME/.config/service-plane"
if test -f "$compose_dir/docker-compose.yml"
  # 拉起 searxng 和 tcp-gate（如果已在运行则无操作）
  set -l gate_state (docker inspect --format='{{.State.Running}}' service-plane-tcp-gate 2>/dev/null; or echo "missing")
  if test "$gate_state" != "true"
    echo "🔄 pi: 启动 SearXNG 服务..." >&2
    docker compose -f "$compose_dir/docker-compose.yml" up -d --no-deps searxng tcp-gate 2>/dev/null
    # 等待 tcp-gate 就绪（最多 10 秒）
    set -l i 0
    while test $i -lt 20
      if curl -sf -o /dev/null http://127.0.0.1:18980 2>/dev/null
        break
      end
      sleep 0.5
      set i (math $i + 1)
    end
    if test $i -ge 20
      echo "⚠️  pi: SearXNG 启动超时，Web Search 可能不可用" >&2
    end
  end
end

if test (count $argv) -eq 1
  command "$launcher" $argv[1]
else
  command "$launcher"
end
return $status
