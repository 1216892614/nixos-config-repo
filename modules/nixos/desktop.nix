{ pkgs, config, ... }:

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
      "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GTK_USE_PORTAL = "1";
  };

  environment.systemPackages = with pkgs; [
    xwayland-satellite
    v4l-utils
    ffmpeg
    libva
    libva-utils
  ];

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
