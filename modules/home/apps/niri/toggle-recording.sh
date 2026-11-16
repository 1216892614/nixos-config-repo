if pgrep -x wf-recorder > /dev/null; then
  recfile=$(cat /tmp/wf-recorder-path 2>/dev/null)
  pkill -x wf-recorder
  printf "%s" "$recfile" | wl-copy
  kitty -e yazi "$HOME/Videos"
else
  mkdir -p "$HOME/Videos"
  recfile="$HOME/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4"
  printf "%s" "$recfile" > /tmp/wf-recorder-path
  nohup wf-recorder -f "$recfile" > /tmp/wf-recorder.log 2>&1 &
fi
