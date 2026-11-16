{ pkgs, ... }:

let
  defaultMixedProxyPort = 7897;
  defaultTunInterface = "Mihomo";  # 与 mihomo tun.device 一致
in
{
  programs.clash-verge = {
    enable = true;
    package = pkgs.clash-verge-rev;
    autoStart = true;
    serviceMode = true;
    tunMode = true;
  };

  networking.firewall = {
    trustedInterfaces = [ defaultTunInterface ];
    extraReversePathFilterRules = ''
      iifname "${defaultTunInterface}" accept
    '';
    allowedTCPPorts = [ defaultMixedProxyPort ];
    allowedUDPPorts = [ defaultMixedProxyPort ];
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.resolved.enable = true;
  networking.nameservers = [ "223.5.5.5" "119.29.29.29" "8.8.8.8" ];
}
