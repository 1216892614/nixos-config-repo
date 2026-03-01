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
    # Noctalia 顶栏录屏插件依赖，未安装时录屏按钮不显示
    gpu-screen-recorder
  ];
}
