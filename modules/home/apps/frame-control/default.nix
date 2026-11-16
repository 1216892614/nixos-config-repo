{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  xdg.desktopEntries.frame-control = {
    name = "Frame Control";
    genericName = "Device Manager";
    comment = "Desktop app for managing a Valve Steam Frame over SSH";
    exec = "${config.home.homeDirectory}/.local/opt/frame-control/frame-control --no-sandbox %U";
    terminal = false;
    icon = "${config.home.homeDirectory}/.local/opt/frame-control/frame-control.png";
    categories = [ "Utility" ];
    mimeType = [ "x-scheme-handler/frame-control" ];
  };
}
