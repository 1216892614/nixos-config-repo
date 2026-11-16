{ lib, ... }:

{
  networking = {
    hostName = lib.mkDefault "desktop";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      trustedInterfaces = [ "warp0" "CloudflaredWARP" ];
    };
  };
}
