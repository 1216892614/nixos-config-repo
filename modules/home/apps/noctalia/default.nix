{ config, lib, pkgs, colors, ... }:

let
  tpl = import ../../../../lib/template.nix;

  noctaliaPkg = pkgs.noctalia;
  noctaliaBin = "${noctaliaPkg}/bin/noctalia";

  declarativeSettingsReappliedOnRebuild = ./noctalia-config.toml;

  customPaletteToml = pkgs.writeText "noctalia-custom-palette.toml" (tpl ./palette.toml {
      accent = colors.accent;
      bg = colors.bg;
      surface_lift = colors.surface.lift;
      entity = colors.entity;
      constant = colors.constant;
      error = colors.error;
      bar_bg = colors.bar.bg;
      bar_fg = colors.bar.fg;
      gutter = colors.gutter;
      surface_over = colors.surface.over;
      fg = colors.fg;
      keyword = colors.keyword;
      surface_sunk = colors.surface.sunk;
      terminal_bg = colors.terminal.bg;
      surface_base = colors.surface.base;
  });
in
{
  home.packages = [ noctaliaPkg ];

  home.file.".local/bin/noctalia-ipc" = {
    executable = true;
    source = pkgs.writeShellScript "noctalia-ipc" ''
      exec "${noctaliaBin}" msg "$@"
    '';
  };

  home.activation.noctaliaInitConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (tpl ./deploy-config.sh {
    settings = declarativeSettingsReappliedOnRebuild;
    palette = customPaletteToml;
  });

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

  home.file.".config/noctalia/wallpaper.jpeg".source = ../../../../wallpapers/moss-fern.jpg;
  home.file.".config/noctalia/wallpapers/moss-fern.jpg".source = ../../../../wallpapers/moss-fern.jpg;
  home.file.".config/noctalia/wallpapers/endcard_02.jpg".source = ../../../../wallpapers/endcard_02.jpg;
  home.file.".config/noctalia/wallpapers/endcard_10.jpg".source = ../../../../wallpapers/endcard_10.jpg;
  home.file.".config/noctalia/wallpapers/endcard_11.jpg".source = ../../../../wallpapers/endcard_11.jpg;
  home.file.".cache/noctalia/wallpapers.json".text = builtins.toJSON {
    defaultWallpaper = "${config.home.homeDirectory}/.config/noctalia/wallpaper.jpeg";
  };
}
