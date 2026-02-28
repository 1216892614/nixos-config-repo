{ pkgs, ... }:

{
  users.users.ep-o1 = {
    isNormalUser = true;
    home = "/home/ep-o1";
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;
}
