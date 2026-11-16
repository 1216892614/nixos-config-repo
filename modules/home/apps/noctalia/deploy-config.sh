SETTINGS="$HOME/.local/state/noctalia/settings.toml"
mkdir -p "$(dirname "$SETTINGS")"
cp "@settings@" "$SETTINGS"
chmod 644 "$SETTINGS"

# 部署自定义调色板
PALETTE_DIR="$HOME/.local/state/noctalia/custom-palettes"
mkdir -p "$PALETTE_DIR"
cp "@palette@" "$PALETTE_DIR/nixos-theme.toml"
chmod 644 "$PALETTE_DIR/nixos-theme.toml"
