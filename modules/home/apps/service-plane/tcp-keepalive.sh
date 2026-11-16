if @keepAliveCheck@; then
  # omp 活跃 → 保持服务存活
  touch "$activity_file"
  if [ "$state" != "true" ]; then
    log "@name@: omp active, waking..."
    docker start "service-plane-@name@-1" >/dev/null 2>&1 || true
  fi
elif [ -f "$activity_file" ]; then
  @stopBlock@
fi
