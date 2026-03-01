{ config, lib, pkgs, inputs, ... }:

{
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
    ];
  };

  home.packages = with pkgs; [
    grim
    slurp
    satty
    wf-recorder
  ];
}
