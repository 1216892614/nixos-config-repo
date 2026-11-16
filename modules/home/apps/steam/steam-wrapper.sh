#!/bin/sh
if command -v systemctl >/dev/null 2>&1; then
  for line in $(systemctl --user show-environment 2>/dev/null); do
    case "$line" in *=*) export "$line" ;; esac
  done 2>/dev/null || true
fi

# Always use :1 (niri's spare Xwayland) for Steam. The primary :0 is
# shared with all other X11 clients and routinely saturates the 256-client
# limit, causing game launches to fail with "Check your DISPLAY".
# Using :1 gives Steam and its games a dedicated Xwayland with fresh budget.
pick_display() {
  sock=/tmp/.X11-unix/X1
  if [ -S "$sock" ]; then
    DISPLAY=:1
    export DISPLAY
  fi
}
pick_display

# ── 着色器缓存持久化 ──
# 核心修复已在系统级 environment.variables 设置（见 modules/nixos/desktop.nix）：
#   __GL_SHADER_DISK_CACHE_SIZE=10GB + SKIP_CLEANUP 解决 NVIDIA 驱动清理缓存
# 此处补充 Steam/DXVK 专用变量：
export MESA_SHADER_CACHE_DIR="$HOME/.cache/mesa-shader-cache"
export DXVK_STATE_CACHE=1
export DXVK_STATE_CACHE_PATH="$HOME/.local/share/Steam/dxvk-cache"

# Fix: Steam's bundled libaudio.so (2012) crashes in pa_card_info callback
# with PipeWire. Intercept pa_context_get_card_info_list to make it a no-op.
# Load both 32-bit and 64-bit; ld.so silently ignores the wrong ELF class.
export LD_PRELOAD="@steamPulseFix@/lib/steam_pulse_fix64.so:@steamPulseFix@/lib/steam_pulse_fix32.so${LD_PRELOAD:+:$LD_PRELOAD}"

# Wayland Remote Play: -pipewire 启用 PipeWire ScreenCast 桌面捕获
# 不加此参数 Steam 只走 X11 XShm 捕获，Wayland 桌面串流为空。
# XDG_CURRENT_DESKTOP 让 Steam 知道走 portal 协议而非 X11 截帧
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}"

# Ensure we run NixOS Steam (programs.steam) so extraPackages/fonts are present.
exec /run/current-system/sw/bin/steam -pipewire "$@"
