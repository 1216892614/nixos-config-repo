{ pkgs, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
  disableManpageCompletionsBrokenInFish48 = true;
in
{
  users.users.ep-o1 = {
    isNormalUser = true;
    home = "/home/ep-o1";
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" "adbusers" ];
    openssh.authorizedKeys.keys = [ env.sshPublicKey ];
  };

  programs.fish.enable = true;
  programs.fish.generateCompletions = !disableManpageCompletionsBrokenInFish48;

  security.sudo.wheelNeedsPassword = true;
}
