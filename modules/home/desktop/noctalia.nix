{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
  avatarImage = ../../../icons/avatar.png;

  # Noctalia v5: 编译后二进制，无 QML 补丁；插件通过 noctalia msg plugins 管理
  noctaliaPkg = pkgs.noctalia;
  noctaliaBin = "${noctaliaPkg}/bin/noctalia";

  # ── Noctalia v5 设置 (TOML) ──────────────────────────────────────────────
  # v5 配置位于 ~/.local/state/noctalia/settings.toml，运行时可写。
  # rebuild 时从仓库配置覆盖部署，保证声明式可复现。
  initialSettingsToml = ../../../noctalia-config.toml;

  # ── 自定义调色板（对应 v4 colors.json 的 Material You token） ──────────
  # v5 支持 custom color scheme 目录；部署到 ~/.local/state/noctalia/custom-palettes/
  customPaletteToml = pkgs.writeText "noctalia-custom-palette.toml" ''
    [light]
    primary = "${colors.accent}"
    on_primary = "${colors.bg}"
    primary_container = "${colors.surface.lift}"
    on_primary_container = "${colors.accent}"
    secondary = "${colors.entity}"
    on_secondary = "${colors.bg}"
    secondary_container = "${colors.surface.lift}"
    on_secondary_container = "${colors.entity}"
    tertiary = "${colors.constant}"
    on_tertiary = "${colors.bg}"
    tertiary_container = "${colors.surface.lift}"
    on_tertiary_container = "${colors.constant}"
    error = "${colors.error}"
    on_error = "${colors.bg}"
    error_container = "${colors.surface.lift}"
    on_error_container = "${colors.error}"
    background = "${colors.bar.bg}"
    on_background = "${colors.bar.fg}"
    surface = "${colors.bar.bg}"
    on_surface = "${colors.bar.fg}"
    surface_variant = "${colors.bar.bg}"
    on_surface_variant = "${colors.bar.fg}"
    outline = "${colors.gutter}"
    outline_variant = "${colors.surface.over}"
    inverse_surface = "${colors.fg}"
    inverse_on_surface = "${colors.bg}"
    inverse_primary = "${colors.keyword}"
    surface_dim = "${colors.surface.sunk}"
    surface_bright = "${colors.surface.lift}"
    surface_container_lowest = "${colors.terminal.bg}"
    surface_container_low = "${colors.surface.sunk}"
    surface_container = "${colors.surface.base}"
    surface_container_high = "${colors.surface.lift}"
    surface_container_highest = "${colors.surface.over}"

    [dark]
    primary = "${colors.accent}"
    on_primary = "${colors.bg}"
    primary_container = "${colors.surface.lift}"
    on_primary_container = "${colors.accent}"
    secondary = "${colors.entity}"
    on_secondary = "${colors.bg}"
    secondary_container = "${colors.surface.lift}"
    on_secondary_container = "${colors.entity}"
    tertiary = "${colors.constant}"
    on_tertiary = "${colors.bg}"
    tertiary_container = "${colors.surface.lift}"
    on_tertiary_container = "${colors.constant}"
    error = "${colors.error}"
    on_error = "${colors.bg}"
    error_container = "${colors.surface.lift}"
    on_error_container = "${colors.error}"
    background = "${colors.bar.bg}"
    on_background = "${colors.bar.fg}"
    surface = "${colors.bar.bg}"
    on_surface = "${colors.bar.fg}"
    surface_variant = "${colors.bar.bg}"
    on_surface_variant = "${colors.bar.fg}"
    outline = "${colors.gutter}"
    outline_variant = "${colors.surface.over}"
    inverse_surface = "${colors.fg}"
    inverse_on_surface = "${colors.bg}"
    inverse_primary = "${colors.keyword}"
    surface_dim = "${colors.surface.sunk}"
    surface_bright = "${colors.surface.lift}"
    surface_container_lowest = "${colors.terminal.bg}"
    surface_container_low = "${colors.surface.sunk}"
    surface_container = "${colors.surface.base}"
    surface_container_high = "${colors.surface.lift}"
    surface_container_highest = "${colors.surface.over}"
  '';
in
{
  home.packages = [ noctaliaPkg ];

  # noctalia msg wrapper：niri 快捷键的稳定 IPC 入口
  home.file.".local/bin/noctalia-ipc" = {
    executable = true;
    source = pkgs.writeShellScript "noctalia-ipc" ''
      exec "${noctaliaBin}" msg "$@"
    '';
  };

  # ── 部署配置（每次 rebuild 覆盖，保证声明式） ────────────────────────
  home.activation.noctaliaInitConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SETTINGS="$HOME/.local/state/noctalia/settings.toml"
    mkdir -p "$(dirname "$SETTINGS")"
    cp "${initialSettingsToml}" "$SETTINGS"
    chmod 644 "$SETTINGS"

    # 部署自定义调色板
    PALETTE_DIR="$HOME/.local/state/noctalia/custom-palettes"
    mkdir -p "$PALETTE_DIR"
    cp "${customPaletteToml}" "$PALETTE_DIR/nixos-theme.toml"
    chmod 644 "$PALETTE_DIR/nixos-theme.toml"
  '';

  # ── systemd 用户服务 ──────────────────────────────────────────────────
  systemd.user.services.noctalia = {
    Unit = {
      Description = "Noctalia";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${noctaliaBin}";
      Restart = "always";
      RestartSec = "2";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # 启动后立即锁屏（等待 Noctalia IPC 就绪）
  systemd.user.services.noctalia-lock-on-start = {
    Unit = {
      Description = "Lock screen on session start";
      After = [ "noctalia.service" ];
      BindsTo = [ "noctalia.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "noctalia-lock-on-start" ''
        cmd="${noctaliaBin}"
        for _ in $(seq 1 30); do
          "$cmd" msg session lock 2>/dev/null && exit 0
          sleep 0.2
        done
      '');
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "noctalia.service" ];
    };
  };

}
