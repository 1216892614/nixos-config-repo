{ lib, ... }:

{
  networking = {
    hostName = lib.mkDefault "desktop";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      # Trust Cloudflare WARP interfaces for Zero Trust private network
      trustedInterfaces = [ "warp0" "CloudflaredWARP" ];
    };
  };
}
