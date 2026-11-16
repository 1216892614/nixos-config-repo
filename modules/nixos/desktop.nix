{ pkgs, config, lib, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
  rustdeskUser = env.username or "ep-o1";

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
      xdg-desktop-portal-wlr            # Steam Remote Play: auto-approve screencast
      xdg-desktop-portal-termfilechooser
    ];
    config.niri = {
      default = [ "gnome" "gtk" ];
      # ScreenCast → wlr portal（可配 chooser_type=none 自动授权，见 home 侧配置）
      # 解决 Steam Remote Play 无画面：GNOME portal 弹框在 Xwayland 下无法交互
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
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


  environment.variables = {
    MESA_SHADER_CACHE_DIR = "$HOME/.cache/mesa-shader-cache";
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
    gamescope  # 游戏缩放/帧率限制 wrapper
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
    # v4l2loopback 不能放在 kernelModules 里（有 assertion 阻止，会影响 howdy）
    # 通过 systemd modules-load 在启动后加载，howdy 先绑定真实 IR 设备不受影响
    kernelModules = [ "uvcvideo" "uinput" ];
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];
    extraModprobeConfig = ''
      options v4l2loopback video_nr=10 exclusive_caps=1 card_label="OBS_Virtual_Camera"
    '';
  };

  # 延迟加载 v4l2loopback（绕过 boot.kernelModules assertion）
  systemd.services.v4l2loopback-load = {
    description = "Load v4l2loopback kernel module";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.kmod}/bin/modprobe v4l2loopback";
    };
  };
}
