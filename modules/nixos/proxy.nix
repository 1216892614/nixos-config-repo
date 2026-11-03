{ pkgs, lib, config, ... }:

# Clash Verge Rev — 通过官方 NixOS 模块 programs.clash-verge 集成
#
# 该模块由 nixpkgs 维护，自动处理：
#   - clash-verge-service：以 root 运行特权 IPC 助手（systemd 服务），
#     普通用户 GUI 通过 IPC 套接字开启 TUN 模式。
#   - autoStart：生成 XDG 自启动项（比在 niri 里硬塞 spawn 更标准）。
#
# 默认开关（TUN / 系统代理 / 局域网 / ipv6 / 静默启动）由 home-manager 的
# clash-verge.nix 首次播种到 verge.yaml / config.yaml，且之后仍可在 GUI 修改。
#
# 注意：使用 nixpkgs-unstable 提供的版本，flake update 即可跟进新版。

{
  programs.clash-verge = {
    enable = true;
    package = pkgs.clash-verge-rev;
    autoStart = true;       # 开机自启（XDG autostart）
    serviceMode = true;     # root systemd service → IPC socket → GUI 可安装/控制 mihomo
    tunMode = true;         # 给二进制加 cap_net_admin capabilities → 可创建 TUN 接口
  };

  # ── TUN 模式相关防火墙 / 转发 ─────────────────────────────────────
  networking.firewall = {
    # clash 的 TUN 接口默认名为 "Meta"
    trustedInterfaces = [ "Meta" ];
    extraReversePathFilterRules = ''
      iifname "Meta" accept
    '';
    # 局域网代理：放行 clash-verge-rev 默认混合端口 7897
    # （如在 GUI 中改了端口，记得同步修改这里）
    allowedTCPPorts = [ 7897 ];
    allowedUDPPorts = [ 7897 ];
  };

  # TUN / 局域网代理需要内核开启 IP 转发（含 ipv6）
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # DNS：由 systemd-resolved 兜底；clash 开启后会接管/劫持 DNS（fake-ip）
  services.resolved.enable = true;
  networking.nameservers = [ "223.5.5.5" "119.29.29.29" "8.8.8.8" ];
}
