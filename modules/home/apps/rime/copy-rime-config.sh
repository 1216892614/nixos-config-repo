RIME_SRC="@rimeWithCustom@"
RIME_DEST="@homeDirectory@/.local/share/fcitx5/rime"
RIME_STAMP="$RIME_DEST/.nix-source-hash"
FCITX_PROFILE="@homeDirectory@/.config/fcitx5/profile"
$DRY_RUN_CMD mkdir -p "$RIME_DEST"

NEW_HASH="@rimeWithCustom@"
OLD_HASH="$(cat "$RIME_STAMP" 2>/dev/null || echo "")"
if [ "$NEW_HASH" != "$OLD_HASH" ]; then
  $DRY_RUN_CMD cp -rL --no-preserve=mode "$RIME_SRC"/* "$RIME_DEST"/ 2>/dev/null || true
  $DRY_RUN_CMD chmod -R u+w "$RIME_DEST" 2>/dev/null || true
  $DRY_RUN_CMD rm -rf "$RIME_DEST"/build 2>/dev/null || true
  echo "$NEW_HASH" > "$RIME_STAMP"
  # 预编译词典，避免 fcitx5 启动时 rime 在线 deploy 导致内存峰值过高崩溃
  echo "Pre-building Rime schemas..."
  $DRY_RUN_CMD @rimeDeployer@ --build "$RIME_DEST" 2>&1 || true
fi

# Ensure rime is in fcitx5 profile (fcitx5 strips it when Rime fails to load)
if [ -f "$FCITX_PROFILE" ] && ! grep -q "Name=rime" "$FCITX_PROFILE" 2>/dev/null; then
  $DRY_RUN_CMD rm -f "$FCITX_PROFILE"
fi
