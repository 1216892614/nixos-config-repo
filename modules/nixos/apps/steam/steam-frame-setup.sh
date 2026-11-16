set -eu
export PATH="@toolPath@:$PATH"

log() { echo "[steam-frame] $(date '+%F %T') $*"; }

# 等待适配器的无线接口就绪（最多 10 秒）
IFACE=""
PHY=""
for i in $(seq 1 20); do
  for phy in /sys/class/ieee80211/*/device; do
    vid=$(cat "$phy/../../../idVendor" 2>/dev/null || true)
    pid=$(cat "$phy/../../../idProduct" 2>/dev/null || true)
    if [ "$vid" = "28de" ] && [ "$pid" = "2432" ]; then
      PHY="$(basename "$(dirname "$phy")")"
      for net in "$(dirname "$phy")"/net/*/; do
        IFACE="$(basename "$net")"
        break
      done
      break
    fi
  done
  [ -n "$IFACE" ] && break
  sleep 0.5
done

if [ -z "$IFACE" ]; then
  log "未找到 Steam Frame 无线接口，跳过"
  exit 0
fi

log "检测到 Steam Frame 接口: $IFACE (phy: $PHY)"

# 设置监管域为 US（解锁 6 GHz）
CURRENT=$(iw reg get 2>/dev/null | grep -oP '(?<=country )\w+' | head -1 || true)
if [ "$CURRENT" != "US" ]; then
  log "当前监管域: $CURRENT → 设置为 US"
  iw reg set US
  sleep 1
  NEW=$(iw reg get 2>/dev/null | grep -oP '(?<=country )\w+' | head -1 || true)
  log "监管域已设置: $NEW"
else
  log "监管域已是 US，无需修改"
fi

# 关闭适配器接口的省电模式
iw dev "$IFACE" set power_save off 2>/dev/null && \
  log "已关闭 $IFACE 省电模式" || \
  log "关闭省电模式失败（接口可能未关联）"

# 关闭 rtw89 inactive power save（需要 CONFIG_RTW89_DEBUGFS=y，7.2+）
# 参考：SteamFrameDongleFix — 不关闭会导致每次扫描唤醒芯片耗时 ~10s
DEBUGFS="/sys/kernel/debug/ieee80211/$PHY/rtw89/fw_crash"
if [ -d "/sys/kernel/debug/ieee80211/$PHY/rtw89" ]; then
  DM="/sys/kernel/debug/ieee80211/$PHY/rtw89/disable_dm"
  if [ -f "$DM" ]; then
    echo 0x20 > "$DM" 2>/dev/null && \
      log "已关闭 inactive power save (disable_dm 0x20)" || \
      log "关闭 inactive power save 失败"
  else
    log "disable_dm 不存在，跳过（需要 CONFIG_RTW89_DEBUGFS=y）"
  fi
else
  log "rtw89 debugfs 不存在，跳过 inactive power save"
fi
