cat > /tmp/handle-@name@.sh << 'HANDLER'
#!/bin/sh
ACTIVITY_DIR="/tmp/gate-activity"
touch "$ACTIVITY_DIR/@name@"
state=$(docker inspect --format='{{.State.Running}}' "service-plane-@name@-1" 2>/dev/null || echo "false")
if [ "$state" != "true" ]; then
  echo "[tcp-gate] @name@: waking..." >&2
  docker start "service-plane-@name@-1" >/dev/null 2>&1 || true
  i=0; while [ $i -lt 60 ]; do
    if @healthCheck@ >/dev/null 2>&1; then break; fi
    sleep 0.5; i=$((i+1))
  done
  if [ $i -ge 60 ]; then
    echo "[tcp-gate] @name@: health check timed out" >&2
    exit 1
  fi
  echo "[tcp-gate] @name@: ready (${i}x0.5s)" >&2
fi
touch "$ACTIVITY_DIR/@name@"
exec socat - "TCP:@name@:@containerPort@"
HANDLER
chmod +x /tmp/handle-@name@.sh
