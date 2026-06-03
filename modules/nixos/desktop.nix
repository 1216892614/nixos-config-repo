{ pkgs, config, lib, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
  rustdeskUser = env.username or "ep-o1";
  rustdeskPassword = env.rustdeskPermanentPassword or "";
in
{
  security.polkit.enable = true;

  services.gnome.gnome-keyring.enable = true;

  # 显示管理器：提供图形登录界面，niri-flake 已将 niri 会话注册到 sessionPackages
  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };
  services.displayManager.defaultSession = "niri";

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-desktop-portal-termfilechooser
    ];
    config.niri = {
      default = [ "gnome" "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GTK_USE_PORTAL = "1";
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    # Same idea as: pkgs.steam.override { extraPkgs = pkgs: [ ...fonts... ]; }
    # Force fonts to exist inside Steam's FHS env (some setups still show □□□ without this).
    extraPackages = with pkgs; [
      wqy_zenhei
      source-han-sans
      source-han-serif
      source-han-mono
      noto-fonts-color-emoji
      sarasa-gothic
    ];
  };

  # RustDesk unattended access runs as a root system service on Linux.
  systemd.services.rustdesk = {
    description = "RustDesk remote desktop service";
    requires = [ "network.target" ];
    after = [ "network.target" "systemd-user-sessions.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rustdesk}/bin/rustdesk --service";
      # Stop both the tray and the server subprocesses on shutdown.
      ExecStop = "${pkgs.procps}/bin/pkill -f 'rustdesk --'";
      PIDFile = "/run/rustdesk.pid";
      KillMode = "mixed";
      TimeoutStopSec = 30;
      User = "root";
      LimitNOFILE = 100000;
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "PULSE_LATENCY_MSEC=60"
        "PIPEWIRE_LATENCY=1024/48000"
      ];
    };
  };

  system.activationScripts.rustdeskPermissions.text = ''
    set -eu

    cfg_root="/root/.config/rustdesk"
    cfg_user="/home/${rustdeskUser}/.config/rustdesk"
    pw=${lib.escapeShellArg rustdeskPassword}

    mkdir -p "$cfg_root" "$cfg_user"

    ensure_options() {
      local file="$1"
      if [ ! -f "$file" ]; then
        cat >"$file" <<'EOF'
[options]
approve-mode = 'password'
verification-method = 'use-permanent-password'
allow-linux-headless = 'Y'
EOF
      else
        tmp="$(mktemp)"
        ${pkgs.gawk}/bin/awk '
          BEGIN { options_done = 0; skip = 0 }
          /^\[options\]$/ {
            print "[options]"
            print "approve-mode = \047password\047"
            print "verification-method = \047use-permanent-password\047"
            print "allow-linux-headless = \047Y\047"
            options_done = 1
            skip = 1
            next
          }
          /^\[/ {
            skip = 0
          }
          !skip {
            print
          }
          END {
            if (!options_done) {
              if (NR > 0) {
                print ""
              }
              print "[options]"
              print "approve-mode = \047password\047"
              print "verification-method = \047use-permanent-password\047"
              print "allow-linux-headless = \047Y\047"
            }
          }
        ' "$file" >"$tmp"
        install -m 600 "$tmp" "$file"
        rm -f "$tmp"
      fi
    }

    ensure_options "$cfg_root/RustDesk2.toml"

    if [ -n "$pw" ]; then
      ${pkgs.rustdesk}/lib/rustdesk/rustdesk --password "$pw" >/dev/null 2>&1 || true
    fi

    if [ -f "$cfg_root/RustDesk.toml" ]; then
      install -m 600 "$cfg_root/RustDesk.toml" "$cfg_user/RustDesk.toml"
    fi
    install -m 600 "$cfg_root/RustDesk2.toml" "$cfg_user/RustDesk2.toml"
    chown -R ${rustdeskUser}:users "/home/${rustdeskUser}/.config/rustdesk"

    systemctl restart rustdesk.service >/dev/null 2>&1 || true
  '';

  networking.firewall = {
    # Steam Remote Play docs also mention TCP 27037; open it explicitly.
    allowedTCPPorts = [ 27037 21114 21115 21116 21117 21118 21119 ];
    allowedUDPPorts = [ 21116 ];
  };

  environment.systemPackages = with pkgs; [
    git
    xwayland-satellite
    v4l-utils
    ffmpeg
    libva
    libva-utils
    vlc
  ];

  # 把 DISPLAY 和输入法相关变量写入 systemd user / D-Bus 环境，重启后从登录就生效
  # 必须用 Environment= 显式设值，否则 dbus-update-activation-environment 无值可导出
  systemd.user.services.dbus-update-activation-environment = {
    description = "Update D-Bus activation environment (DISPLAY + IM)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig.Type = "oneshot";
    environment = {
      QT_IM_MODULE = "fcitx";
      SDL_IM_MODULE = "fcitx";
      INPUT_METHOD = "fcitx";
      XMODIFIERS = "@im=fcitx";
    };
    serviceConfig.ExecStart = "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_IM_MODULE SDL_IM_MODULE INPUT_METHOD XMODIFIERS";
  };

  programs.niri.enable = true;

  hardware = {
    bluetooth.enable = true;
    graphics.enable = true;
    enableAllFirmware = true;
    opentabletdriver.enable = true;
  };

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  boot = {
    kernelModules = [ "v4l2loopback" "uvcvideo" "uinput" ];
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];
  };
}
