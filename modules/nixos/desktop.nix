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

  programs.steam = {
    enable = true;
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

  environment.systemPackages = with pkgs; [
    git
    xwayland-satellite
    v4l-utils
    ffmpeg
    libva
    libva-utils
    vlc
  ];

  # Ensure DISPLAY is available to D-Bus and systemd --user activation env
  systemd.user.services.dbus-update-activation-environment = {
    description = "Update D-Bus activation environment";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY GTK_IM_MODULE QT_IM_MODULE SDL_IM_MODULE INPUT_METHOD XMODIFIERS";
    };
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
