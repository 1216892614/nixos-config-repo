{ ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
in
{
  services.flatpak = {
    enable = true;

    packages = [
      "app.xmcl.voxelum"  # X Minecraft Launcher
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

    # osu! 需要 X11 socket 走 XWayland 以获得更好的游戏性能（NVIDIA Wayland 合成开销大）
    overrides."sh.ppy.osu".Context.sockets = [ "wayland" "x11" "fallback-x11" ];
  };

  # overrides 由 flatpak-managed-install 根据 services.flatpak.overrides 写入
  # /var/lib/flatpak/overrides/global，不能把该路径做成指向只读 /etc 的符号链接，否则脚本写入会报 Read-only file system

  systemd.services.flatpak-managed-install = {
    enable = true;
    # 安装失败（如网络问题）时不把 unit 标为 failed，避免 nixos-rebuild switch 报错
    serviceConfig.SuccessExitStatus = [ 0 1 ];
  };
}
