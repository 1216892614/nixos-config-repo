{ pkgs, lib, ... }:

let
  env = import ../../env.nix;

  fetchConfig = pkgs.writeShellScript "fetch-mihomo-config" ''
    mkdir -p /etc/mihomo
    tmp=$(mktemp)
    if ${pkgs.curl}/bin/curl -sL -o "$tmp" --connect-timeout 15 "${env.mihomoSubscribeUrl}" 2>/dev/null && [ -s "$tmp" ]; then
      mv "$tmp" /etc/mihomo/config.yaml
    fi
    rm -f "$tmp"
    # 拉取失败时保留现有 config.yaml，不阻塞 activation
    exit 0
  '';
in
{
  services.mihomo = {
    enable = true;
    tunMode = true;
    configFile = "/etc/mihomo/config.yaml";
    webui = pkgs.metacubexd;
  };

  systemd.services.mihomo-fetch-config = {
    description = "Fetch mihomo config from subscribe URL";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "mihomo.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = fetchConfig;
      RemainAfterExit = true;
    };
  };

  systemd.timers.mihomo-fetch-config = {
    description = "Periodically update mihomo config";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  networking.firewall = {
    trustedInterfaces = [ "Mihomo" ];
    extraReversePathFilterRules = ''
      iifname "Mihomo" accept
    '';
    allowedTCPPorts = [ env.mihomoMixedPort env.mihomoApiPort ];
    allowedUDPPorts = [ env.mihomoMixedPort ];
  };

  services.resolved.enable = false;
  networking.nameservers = [ "127.0.0.1" ];

  # 全系统代理环境变量（走本机 mihomo）
  environment.sessionVariables = {
    http_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
    HTTP_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
    https_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
    HTTPS_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
    all_proxy = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
    ALL_PROXY = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
    no_proxy = "localhost,127.0.0.1,::1";
    NO_PROXY = "localhost,127.0.0.1,::1";
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
