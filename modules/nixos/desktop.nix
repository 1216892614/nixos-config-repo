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

  colors = import ../../lib/colors.nix;
in
{
  security.polkit.enable = true;

  # 禁用 niri-flake 自带的 KDE polkit agent（缺少 QML 模块导致崩溃，且不支持自动 howdy 认证）
  systemd.user.services.niri-flake-polkit.enable = false;

  # 使用 polkit-gnome agent 替代：polkitd 通过 PAM (polkit-1 service) 验证，
  # PAM 栈中 howdy (sufficient) 会自动尝试人脸识别，成功则免密码
  systemd.user.services.polkit-gnome-agent = {
    description = "Polkit GNOME Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # polkit 127+ 的 agent-helper 运行在严格沙箱中，
  # 导致 howdy 无法访问 IR 摄像头和模型文件。放宽沙箱以支持人脸识别。
  systemd.services."polkit-agent-helper@" = {
    serviceConfig = {
      PrivateDevices = lib.mkForce false;
      DevicePolicy = lib.mkForce "auto";
      DeviceAllow = lib.mkForce "";
      PrivateNetwork = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      ProtectSystem = lib.mkForce "full";  # 允许读 /dev, /sys 等
      NoNewPrivileges = lib.mkForce false;
      ProtectKernelModules = lib.mkForce false;
      SystemCallFilter = lib.mkForce "";   # 不过滤系统调用（v4l2 ioctl 需要）
    };
  };

  services.gnome.gnome-keyring.enable = true;

  # ─── 自动登录：greetd + 直接启动 niri（无密码、无 greeter）───
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "niri-session";
        user = rustdeskUser;
      };
    };
  };

  # 开机后直接进入 niri → Noctalia Shell 负责锁屏认证（howdy + 密码）

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

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession = {
      enable = true;
      args = [ "--hdr-enabled" "--hdr-itm-enable" "--prefer-output" "DP-3" ];
    };
    # Same idea as: pkgs.steam.override { extraPkgs = pkgs: [ ...fonts... ]; }
    # Force fonts to exist inside Steam's FHS env (some setups still show □□□ without this).
    extraPackages = with pkgs; [
      wqy_zenhei
      source-han-sans
      source-han-serif
      source-han-mono
      noto-fonts-color-emoji
      sarasa-gothic
      gamescope
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
      ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
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
      ${pkgs.rustdesk-flutter}/lib/rustdesk/rustdesk --password "$pw" >/dev/null 2>&1 || true
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
    gh  # GitHub CLI
    xwayland-satellite
    v4l-utils
    ffmpeg
    libva
    libva-utils
    vlc
    gamescope  # HDR/VRR compositing for games and media
  ];

  # IM 环境变量由 niri spawn-at-startup 统一导入 systemd/DBus（见 niri.nix）
  # 不再需要独立 oneshot 服务，避免与 niri spawn 竞争导致变量丢失

  programs.niri.enable = true;

  hardware = {
    bluetooth.enable = true;
    graphics.enable = true;
    enableAllFirmware = true;
    opentabletdriver.enable = true;
  };

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  # 电源自动切换：离电 → power-saver + 亮度70%，接电 → balanced + 亮度100%
  services.udev.extraRules = let
    power-switch = pkgs.writeShellScript "power-switch" ''
      BACKLIGHT="/sys/class/backlight/amdgpu_bl1"
      MAX=$(cat "$BACKLIGHT/max_brightness")

      if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || cat /sys/class/power_supply/AC0/online 2>/dev/null || echo 1)" = "1" ]; then
        # 接电
        ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
        echo "$MAX" > "$BACKLIGHT/brightness"
      else
        # 离电
        ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
        echo "$((MAX * 70 / 100))" > "$BACKLIGHT/brightness"
      fi
    '';
  in ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${power-switch}"
  '';

  # HP laptop function key fixups (via hwdb)
  # Remap HP WMI hotkeys scancode 0x21a8 (KEY_PROG2) → KEY_PLAYPAUSE
  services.udev.extraHwdb = ''
    evdev:name:HP WMI hotkeys:*
     KEYBOARD_KEY_21a8=playpause
  '';

  boot = {
    # 注意：v4l2loopback 不能放在 kernelModules 里，否则 howdy 面部识别会失效
    # 只放在 extraModulePackages 里让它按需加载
    kernelModules = [ "uvcvideo" "uinput" ];
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];
  };
}
