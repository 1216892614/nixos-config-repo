_install_ai() {
  local name="${1:-}"
  local src="${2:-}"
  local dest="@config_home_homeDirectory@/.local/opt/$name"
  if [ ! -f "$src" ]; then
    echo "AppImage not found: $src, skipping $name"
    return 0
  fi
  local hash_file="$dest/.appimage-sha256"
  local current_hash=""
  current_hash=$(sha256sum "$src" | cut -d' ' -f1)
  if [ -f "$hash_file" ] && [ "$(cat "$hash_file")" = "$current_hash" ]; then
    echo "AppImage $name: already up to date"
    return 0
  fi
  echo "AppImage $name: installing..."
  rm -rf "$dest"
  mkdir -p "$dest"
  local tmp=""
  tmp=$(mktemp -d)
  (cd "$tmp" && "$src" --appimage-extract) >/dev/null 2>&1
  cp -a "$tmp/squashfs-root/." "$dest/"
  rm -rf "$tmp"
  echo "$current_hash" > "$hash_file"
  echo "AppImage $name: installed"
}

REPO="@config_home_homeDirectory@/nixos-config-repo/appimages"
_install_ai "xmcl"      "$REPO/xmcl.AppImage"
_install_ai "cursor"    "$REPO/cursor.AppImage"
_install_ai "osu"       "$REPO/osu.AppImage"
_install_ai "obsidian"  "$REPO/obsidian.AppImage"
_install_ai "skills-manager" "$REPO/skills-manager.AppImage"
_install_ai "flclash"  "$REPO/flclash.AppImage"
_install_ai "frame-control" "$REPO/frame-control.AppImage"
_install_ai "artcraft-launcher" "$REPO/artcraft-launcher.AppImage"
