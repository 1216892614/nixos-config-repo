{ config, lib, pkgs, inputs, ... }:

{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;

    settings = {
      theme = "ayu-dark";
      default_shell = "fish";
    };
  };
}
