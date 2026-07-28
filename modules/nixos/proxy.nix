{ pkgs, lib, config, ... }:

# Clash Verge Rev — 通过官方 NixOS 模块 programs.clash-verge 集成
#
# 该模块由 nixpkgs 维护，正确处理了：
#   - serviceMode：以 root 运行 clash-verge-service（特权 IPC 助手），
#     并把控制套接字 /run/clash-verge-rev/service.sock 的属组设为 cfg.group
#     （默认 users），这样普通用户运行的 GUI 才能连上、开启 TUN。
#   - tunMode：给 GUI 主程序设置 cap_net_admin 等 capability（security.wrappers）。
#   - autoStart：生成 XDG 自启动项（比在 niri 里硬塞 spawn 更标准）。
#
# 默认开关（TUN / 系统代理 / 局域网 / ipv6 / 静默启动）由 home-manager 的
# clash-verge.nix 首次播种到 verge.yaml / config.yaml，且之后仍可在 GUI 修改。
#
# 注意：clash-verge-rev 使用 nixpkgs-unstable 提供的版本（当前 2.5.2）。

{
  programs.clash-verge = {
    enable = true;
    package = pkgs.clash-verge-rev;
    serviceMode = true;   # 特权服务，供 GUI 开启 TUN（无需每次 sudo）
    tunMode = true;       # 给 GUI 主程序设置 TUN 所需 capability
    autoStart = true;     # 开机自启（XDG autostart）
    group = "users";      # 允许 users 组访问 service 套接字（ep-o1 属于 users）
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
