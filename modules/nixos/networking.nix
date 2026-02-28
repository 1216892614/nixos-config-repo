{ lib, ... }:

{
  networking = {
    hostName = lib.mkDefault "desktop";
    networkmanager.enable = true;
    firewall.enable = true;
  };
}
