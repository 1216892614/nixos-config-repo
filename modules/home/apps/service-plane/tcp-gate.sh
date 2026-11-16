#!/bin/sh
set -eu

ACTIVITY_DIR="/tmp/gate-activity"
mkdir -p "$ACTIVITY_DIR"

log() { echo "[tcp-gate] $(date '+%H:%M:%S') $*"; }

idle_reaper() {
  while true; do
    sleep 30
    @idleServices@
  done
}
idle_reaper &
REAPER_PID=$!
trap "kill $REAPER_PID 2>/dev/null; wait" EXIT

@handlers@

log "Starting TCP listeners..."
@listeners@

log "All listeners active."
wait
