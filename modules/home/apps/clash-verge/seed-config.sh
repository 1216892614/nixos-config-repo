_appdir="@appDir@"
run mkdir -p "$_appdir"

# 仅在目标文件不存在时播种，已存在则保留用户/GUI 的改动
if [ ! -e "$_appdir/verge.yaml" ]; then
  run cp @vergeYaml@ "$_appdir/verge.yaml"
  run chmod 644 "$_appdir/verge.yaml"
  echo "clash-verge: seeded default verge.yaml"
else
  echo "clash-verge: verge.yaml exists, leaving GUI-managed config untouched"
fi

# ── 强制修补：禁用轻量模式（无论新旧文件都执行） ──
# 使用 sed 原地替换；如果字段不存在则追加
if grep -q "enable_auto_light_weight_mode" "$_appdir/verge.yaml"; then
  run @sed@ -i \
    's/^enable_auto_light_weight_mode:.*/enable_auto_light_weight_mode: false/' \
    "$_appdir/verge.yaml"
else
  echo "enable_auto_light_weight_mode: false" >> "$_appdir/verge.yaml"
fi

# ── 强制修补：禁用内置更新检查（版本由 Nix 管理） ──
if grep -q "auto_check_update" "$_appdir/verge.yaml"; then
  run @sed@ -i \
    's/^auto_check_update:.*/auto_check_update: false/' \
    "$_appdir/verge.yaml"
else
  echo "auto_check_update: false" >> "$_appdir/verge.yaml"
fi


if [ ! -e "$_appdir/config.yaml" ]; then
  run cp @configYaml@ "$_appdir/config.yaml"
  run chmod 644 "$_appdir/config.yaml"
  echo "clash-verge: seeded default config.yaml"
else
  echo "clash-verge: config.yaml exists, leaving GUI-managed config untouched"
fi

# ── 强制修补：TUN 配置 ──
# 确保 tun.enable = true 且 stack = system（内核态转发，替代 gvisor 用户态栈）
if [ -e "$_appdir/config.yaml" ]; then
  run @yq@ -i '.tun.enable = true | .tun.stack = "system" | .tun.device = "Mihomo"' "$_appdir/config.yaml"
fi

# ── 强制修补：proxy-server-nameserver 使用直连 DNS ──
# 代理节点域名解析必须直连，不能走自身代理端口（会递归死锁）
if [ -e "$_appdir/config.yaml" ]; then
  run @yq@ -i '.dns.proxy-server-nameserver = ["119.29.29.29", "223.5.5.5"]' "$_appdir/config.yaml"
fi
