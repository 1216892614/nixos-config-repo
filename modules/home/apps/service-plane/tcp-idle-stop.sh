last=$(stat -c %Y "$activity_file" 2>/dev/null || echo 0)
now=$(date +%s)
elapsed=$((now - last))
if [ "$elapsed" -ge @idleTimeout@ ]; then
  if [ "$state" = "true" ]; then
    log "@name@: idle ${elapsed}s (>=@idleTimeout@s), stopping"
    docker stop "service-plane-@name@-1" >/dev/null 2>&1 || true
  fi
fi
