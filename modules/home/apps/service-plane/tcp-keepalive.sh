if @keepAliveCheck@; then
  # omp 活跃 → 保持服务存活
  touch "$activity_file"
  if [ "$state" != "true" ]; then
    log "@name@: omp active, waking..."
    @wake@
  fi
elif [ -f "$activity_file" ]; then
  @stopBlock@
fi
