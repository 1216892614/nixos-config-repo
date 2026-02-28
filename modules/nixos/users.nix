{ pkgs, ... }:

let
  env = import ../../env.nix;
in
{
  users.users.ep-o1 = {
    isNormalUser = true;
    home = "/home/ep-o1";
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
    openssh.authorizedKeys.keys = [ env.sshPublicKey ];
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;
}
