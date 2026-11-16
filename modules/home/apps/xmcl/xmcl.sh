#!/usr/bin/env bash
XMCL_DIR="$HOME/.local/opt/xmcl"
# 移除 AppImage 自带的 ANGLE/Vulkan 库，让 steam-run 提供系统 NVIDIA EGL
for lib in libEGL.so libGLESv2.so libvk_swiftshader.so libvulkan.so.1; do
  [ -f "$XMCL_DIR/$lib" ] && mv "$XMCL_DIR/$lib" "$XMCL_DIR/$lib.bundled"
done
export BROWSER="@config_home_profileDirectory@/bin/google-chrome-stable"
export JAVA_HOME="$HOME/.local/lib/jdk21"
exec /run/current-system/sw/bin/steam-run \
  "$XMCL_DIR/xmcl" \
  --no-sandbox --disable-gpu-sandbox \
  --ozone-platform-hint=auto --enable-wayland-ime \
  "$@"
