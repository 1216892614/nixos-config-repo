#!/usr/bin/env bash
set -euo pipefail

SCREENSHOT_DIR="$HOME/screenshot"
RECORDING_DIR="$HOME/Videos/recordings"
PIDFILE="/tmp/wf-recorder.pid"

mkdir -p "$SCREENSHOT_DIR" "$RECORDING_DIR"

notify() {
  notify-send -a "Capture" "$1" "$2"
}

screenshot_menu() {
  local file="$1"
  choice=$(printf "编辑并保存\n仅保存\n复制到剪贴板\n取消" | walker --dmenu --placeholder "截图操作")
  case "$choice" in
    "编辑并保存")
      wl-copy < "$file"
      satty --filename "$file" --output-filename "$file"
      wl-copy < "$file"
      notify "截图已保存" "$file"
      ;;
    "仅保存")
      notify "截图已保存" "$file"
      ;;
    "复制到剪贴板")
      wl-copy < "$file"
      notify "已复制到剪贴板" ""
      ;;
    *) ;;
  esac
}

screenshot_full() {
  local file="$SCREENSHOT_DIR/$(date +'%Y-%m-%d-%H%M%S').png"
  grim "$file"
  screenshot_menu "$file"
}

screenshot_region() {
  local file="$SCREENSHOT_DIR/$(date +'%Y-%m-%d-%H%M%S').png"
  grim -g "$(slurp)" "$file"
  screenshot_menu "$file"
}

select_audio() {
  choice=$(printf "系统音频\n麦克风\n无音频" | walker --dmenu --placeholder "选择音频源")
  case "$choice" in
    "系统音频") echo "--audio" ;;
    "麦克风") echo "--audio --audio-device=$(pactl get-default-source)" ;;
    "无音频") echo "" ;;
    *) echo "" ;;
  esac
}

record_full() {
  local file="$RECORDING_DIR/$(date +'%Y-%m-%d-%H%M%S').mp4"
  local audio_flag
  audio_flag=$(select_audio)
  notify "录屏开始" "按 Super+G 停止"
  # shellcheck disable=SC2086
  wf-recorder -f "$file" $audio_flag -c h264_vaapi -r 30 &
  echo $! > "$PIDFILE"
}

record_region() {
  local file="$RECORDING_DIR/$(date +'%Y-%m-%d-%H%M%S').mp4"
  local audio_flag region
  audio_flag=$(select_audio)
  region=$(slurp)
  notify "录屏开始" "按 Super+G 停止"
  # shellcheck disable=SC2086
  wf-recorder -f "$file" -g "$region" $audio_flag -c h264_vaapi -r 30 &
  echo $! > "$PIDFILE"
}

stop_recording() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -INT "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
    notify "录屏已停止" "保存到 $RECORDING_DIR"
  fi
}

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  choice=$(printf "停止录屏\n全屏截图\n区域截图\n取消" | walker --dmenu --placeholder "录屏中...")
  case "$choice" in
    "停止录屏") stop_recording ;;
    "全屏截图") screenshot_full ;;
    "区域截图") screenshot_region ;;
    *) ;;
  esac
else
  choice=$(printf "全屏截图\n区域截图\n全屏录屏\n区域录屏\n取消" | walker --dmenu --placeholder "截图与录屏")
  case "$choice" in
    "全屏截图") screenshot_full ;;
    "区域截图") screenshot_region ;;
    "全屏录屏") record_full ;;
    "区域录屏") record_region ;;
    *) ;;
  esac
fi
