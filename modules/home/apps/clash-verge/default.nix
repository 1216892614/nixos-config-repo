{ config, lib, pkgs, ... }:

let
  tpl = import ../../../../lib/template.nix;
  disableLightweightModeToAvoidBlankWebview = false;
  yamlFormat = pkgs.formats.yaml { };
  yq = "${pkgs.yq-go}/bin/yq";
  appDir = "${config.home.homeDirectory}/.local/share/io.github.clash-verge-rev.clash-verge-rev";
  mixedPort = 7897;
  tunDevice = "Mihomo";
  vergeDefaults = {
    enable_tun_mode = true;                   # 默认开启 TUN
    enable_system_proxy = true;               # 默认开启系统代理
    enable_silent_start = false;              # 禁用静默启动（触发轻量模式导致 GUI 空白）
    enable_auto_launch = true;                # GUI 中标记为开机自启
    verge_mixed_port = mixedPort;             # 混合端口（与防火墙放行端口一致）
    enable_random_port = false;
    enable_auto_light_weight_mode = disableLightweightModeToAvoidBlankWebview;    # 禁用轻量模式（v2.5.x bug workaround）
    auto_check_update = false;              # 版本由 Nix 管理，禁用内置更新检查
  };
  clashDefaults = {
    "allow-lan" = true;           # 默认允许局域网代理
    ipv6 = true;                  # 默认开启 ipv6
    "mixed-port" = mixedPort;
    mode = "rule";                # 默认规则模式（不能用 direct，否则代理不工作）
    tun = {
      enable = true;
      stack = "system";           # 内核态转发，替代 gvisor 用户态栈
      device = tunDevice;
      "auto-route" = true;
      "auto-detect-interface" = true;
      "dns-hijack" = [ "any:53" ];
      mtu = 1500;
    };
  };

  vergeYaml = yamlFormat.generate "verge.yaml.default" vergeDefaults;
  configYaml = yamlFormat.generate "config.yaml.default" clashDefaults;

in
{
  home.activation.seedClashVergeConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" ] (tpl ./seed-config.sh {
      inherit appDir vergeYaml configYaml yq;
      sed = "${pkgs.gnused}/bin/sed";
    });
  xdg.desktopEntries.clash-verge-rev = {
    name = "Clash Verge Rev";
    genericName = "Proxy Client";
    comment = "A Clash Meta GUI based on Tauri";
    exec = "${pkgs.clash-verge-rev}/bin/clash-verge %u";
    terminal = false;
    icon = "clash-verge";
    categories = [ "Network" ];
    mimeType = [ "x-scheme-handler/clash" ];
  };
}
