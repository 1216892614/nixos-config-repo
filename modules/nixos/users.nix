{ pkgs, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
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

  # sudo 需要认证（howdy 面部识别或密码）
  security.sudo.wheelNeedsPassword = true;
}
