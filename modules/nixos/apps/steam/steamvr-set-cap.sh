set -eu
LAUNCHER="@steamvrCompositorPath@"
if [ ! -f "$LAUNCHER" ]; then
  echo "[steamvr-setcap] vrcompositor-launcher 不存在，跳过"
  exit 0
fi
CURRENT=$(@libcap@/bin/getcap "$LAUNCHER" 2>/dev/null || true)
if echo "$CURRENT" | grep -q cap_sys_nice; then
  echo "[steamvr-setcap] cap_sys_nice 已存在，无需设置"
  exit 0
fi
@libcap@/bin/setcap CAP_SYS_NICE=eip "$LAUNCHER"
echo "[steamvr-setcap] 已设置 cap_sys_nice: $(@libcap@/bin/getcap "$LAUNCHER")"
