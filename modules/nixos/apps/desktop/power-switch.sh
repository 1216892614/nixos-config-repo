BACKLIGHT="/sys/class/backlight/amdgpu_bl1"
MAX=$(cat "$BACKLIGHT/max_brightness")

if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || cat /sys/class/power_supply/AC0/online 2>/dev/null || echo 1)" = "1" ]; then
  # 接电
  @powerProfilesDaemon@/bin/powerprofilesctl set balanced
  echo "$MAX" > "$BACKLIGHT/brightness"
else
  # 离电
  @powerProfilesDaemon@/bin/powerprofilesctl set power-saver
  echo "$((MAX * 70 / 100))" > "$BACKLIGHT/brightness"
fi
