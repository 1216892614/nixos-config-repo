{ pkgs, ... }:

{
  services.udisks2.enable = true;

  environment.systemPackages = [ pkgs.android-tools ];
}
