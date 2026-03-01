{ config, lib, pkgs, inputs, ... }:

{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;

    settings = {
      theme = "gruvbox-dark";
      default_shell = "fish";
    };
  };
}
