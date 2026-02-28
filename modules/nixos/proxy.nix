{ pkgs, lib, ... }:

let
  env = import ../../env.nix;

  fetchConfig = pkgs.writeShellScript "fetch-mihomo-config" ''
    mkdir -p /etc/mihomo
    ${pkgs.curl}/bin/curl -sL -o /etc/mihomo/config.yaml "${env.mihomoSubscribeUrl}"
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

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
