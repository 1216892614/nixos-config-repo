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

    update.onActivation = true;

    overrides.global = {
      Context = {
        sockets = [ "wayland" "!x11" "!fallback-x11" ];
      };
      Environment = {
        XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";
      };
    };
  };
}
