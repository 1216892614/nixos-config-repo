_install_deb() {
  local name="${1:-}"
  local src="${2:-}"
  local dest="@config_home_homeDirectory@/.local/opt/$name"
  if [ ! -f "$src" ]; then
    echo "Deb not found: $src, skipping $name"
    return 0
  fi
  local hash_file="$dest/.deb-sha256"
  local current_hash=""
  current_hash=$(sha256sum "$src" | cut -d' ' -f1)
  if [ -f "$hash_file" ] && [ "$(cat "$hash_file")" = "$current_hash" ]; then
    echo "Deb $name: already up to date"
    return 0
  fi
  echo "Deb $name: installing..."
  rm -rf "$dest"
  mkdir -p "$dest"
  local tmp=""
  tmp=$(mktemp -d)
  @pkgs_dpkg@/bin/dpkg-deb -x "$src" "$tmp"
  cp -a "$tmp/." "$dest/"
  rm -rf "$tmp"
  # Patch ELF binaries
  find "$dest" -type f -executable -exec sh -c '
    file "$1" | grep -q "ELF.*executable" && @pkgs_patchelf@/bin/patchelf --set-interpreter @pkgs_glibc@/lib/ld-linux-x86-64.so.2 "$1" 2>/dev/null || true
  ' _ {} \;
  echo "$current_hash" > "$hash_file"
  echo "Deb $name: installed"
}

DEB_REPO="@config_home_homeDirectory@/nixos-config-repo/debs"
if [ -d "$DEB_REPO" ]; then
  for app_dir in "$DEB_REPO"/*/; do
    [ -d "$app_dir" ] || continue
    app_name="$(basename "$app_dir")"
    # 取目录下最新的 .deb 文件
    deb_file="$(ls -t "$app_dir"*.deb 2>/dev/null | head -1)"
    if [ -n "$deb_file" ]; then
      _install_deb "$app_name" "$deb_file"
    else
      echo "Deb $app_name: no .deb file found in $app_dir, skipping"
    fi
  done
fi
