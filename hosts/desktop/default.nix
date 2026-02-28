{ inputs, config, pkgs, lib, ... }:

let
  nixosModulesDir = ../../modules/nixos;
  nixosModuleFiles = builtins.filter
    (f: lib.hasSuffix ".nix" f)
    (builtins.attrNames (builtins.readDir nixosModulesDir));
in
{
  imports =
    (map (f: nixosModulesDir + "/${f}") nixosModuleFiles)
    ++ [ ./hardware-configuration.nix ];

  networking.hostName = "desktop";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.ep-o1 = import ../../modules/home;
}
