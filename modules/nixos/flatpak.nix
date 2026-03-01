{ ... }:

let
  env = import ../../env.nix;
in
{
  services.flatpak = {
    enable = true;

    packages = [
      "com.qq.QQ"
      "com.qq.QQmusic"
      "com.tencent.WeChat"
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

    overrides."com.qq.QQ".Context.sockets = [ "wayland" "x11" "fallback-x11" ];
    overrides."com.qq.QQ".Environment = {
      http_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      https_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      all_proxy = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
      HTTP_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      HTTPS_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      ALL_PROXY = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
      no_proxy = "localhost,127.0.0.1,::1";
      NO_PROXY = "localhost,127.0.0.1,::1";
    };

    overrides."com.tencent.WeChat".Context.sockets = [ "wayland" "x11" "fallback-x11" ];
    overrides."com.tencent.WeChat".Environment = {
      http_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      https_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      all_proxy = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
      HTTP_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      HTTPS_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      ALL_PROXY = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
      no_proxy = "localhost,127.0.0.1,::1";
      NO_PROXY = "localhost,127.0.0.1,::1";
      # 禁用 Electron 崩溃上报，避免 Flatpak 沙箱内 ptrace: Operation not permitted
      ELECTRON_DISABLE_CRASH_REPORTER = "1";
    };

    overrides."com.qq.QQmusic".Context.sockets = [ "wayland" "x11" "fallback-x11" ];
    overrides."com.qq.QQmusic".Environment = {
      http_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      https_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      all_proxy = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
      HTTP_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      HTTPS_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      ALL_PROXY = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
      no_proxy = "localhost,127.0.0.1,::1";
      NO_PROXY = "localhost,127.0.0.1,::1";
    };
  };

  # Apply critical Flatpak overrides even when flatpak-managed-install is disabled.
  environment.etc."flatpak/overrides/global".text = ''
    [Context]
    sockets=wayland;!x11;!fallback-x11

    [Environment]
    XCURSOR_PATH=/run/host/user-share/icons:/run/host/share/icons
  '';

  systemd.tmpfiles.rules = [
    "L+ /var/lib/flatpak/overrides/global - - - - /etc/flatpak/overrides/global"
  ];

  # 不随 activation 启动，避免失败导致 nixos-rebuild 报错；需要时手动执行 flatpak install
  systemd.services.flatpak-managed-install.enable = false;
}
