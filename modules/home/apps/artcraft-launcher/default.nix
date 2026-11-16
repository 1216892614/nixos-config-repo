{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  xdg.desktopEntries.artcraft-launcher = {
    name = "ArtCraft Launcher";
    genericName = "App Launcher";
    comment = "Install, update and launch the Craft App Suite";
    exec = "${config.home.homeDirectory}/.local/opt/artcraft-launcher/usr/bin/artcraft-launcher";
    terminal = false;
    icon = "${config.home.homeDirectory}/.local/opt/artcraft-launcher/ai.storyteller.artcraft-launcher.png";
    categories = [ "Utility" ];
    settings = {
      StartupWMClass = "ai.storyteller.artcraft-launcher";
      Keywords = "artcraft;craft;launcher;installer;updater;photocraft;filmcraft;apps;";
    };
  };
}
