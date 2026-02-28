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
    ++ (
      if builtins.pathExists ../../hardware-configuration.nix
      then [ ../../hardware-configuration.nix ]
      else [ ../../hardware-configuration.nix.example ]
    );

  networking.hostName = "desktop";
  system.stateVersion = "24.11";

  home-manager.users.ep-o1 = import ../../modules/home;
}
