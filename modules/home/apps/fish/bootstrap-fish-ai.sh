FISH_AI_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fish-ai"
FISH_AI_SRC="@fishAiSrc@"
MARKER="$FISH_AI_DIR/.installed-rev"
CURRENT_REV="@fishAiRev@"

if [ ! -f "$MARKER" ] || [ "$(cat "$MARKER" 2>/dev/null)" != "$CURRENT_REV" ] \
   || [ ! -x "$FISH_AI_DIR/bin/python3" ] || [ ! -x "$FISH_AI_DIR/bin/lookup_setting" ]; then
  # Never keep a successful marker across a failed or partial install.
  rm -f "$MARKER"
  echo "🥡 fish-ai: bootstrapping Python venv..."
  @uv@ venv --quiet --clear --python 3.13 "$FISH_AI_DIR"
  echo "🍬 fish-ai: installing dependencies..."
  # nix store 只读，需拷贝源码到可写临时目录
  FISH_AI_TMP="$(mktemp -d)"
  cp -r "$FISH_AI_SRC"/. "$FISH_AI_TMP"
  chmod -R u+w "$FISH_AI_TMP"
  @uv@ pip install --quiet --python "$FISH_AI_DIR/bin/python3" "$FISH_AI_TMP"
  rm -rf "$FISH_AI_TMP"
  if [ ! -x "$FISH_AI_DIR/bin/lookup_setting" ]; then
    echo "fish-ai: missing lookup_setting after installation" >&2
    exit 1
  fi
  # 符号链接系统 CA 证书
  if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
    ln -snf /etc/ssl/certs/ca-certificates.crt \
      "$("$FISH_AI_DIR/bin/python3" -c 'import certifi; print(certifi.where())')"
  fi
  echo "$CURRENT_REV" > "$MARKER"
  echo "✅ fish-ai: ready!"
fi
