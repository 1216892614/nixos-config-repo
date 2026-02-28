{ ... }:

{
  services.flatpak = {
    enable = true;

    packages = [
      "com.qq.QQ"
      "com.qq.QQmusic"
      "com.tencent.WeChat"
      "com.valvesoftware.Steam"
      "sh.ppy.osu"
    ];

    # 不在 activation 时执行，避免网络/仓库失败导致 nixos-rebuild 报错
    update.onActivation = false;

    overrides.global = {
      Context = {
        sockets = [ "wayland" "!x11" "!fallback-x11" ];
      };
      Environment = {
        XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
      };
    };
  };

  # 不随 activation 启动，避免失败导致 nixos-rebuild 报错；需要时手动执行 flatpak install
  systemd.services.flatpak-managed-install.enable = false;
}
