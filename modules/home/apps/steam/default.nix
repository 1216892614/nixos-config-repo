{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
let
  tpl = import ../../../../lib/template.nix;
  steamPulseFix = pkgs.callPackage ../../../../pkgs/steam-pulse-fix { };
in
{
  home.file.".local/bin/steam-wrapper".text = tpl ./steam-wrapper.sh { inherit steamPulseFix; };
  home.file.".local/bin/steam-wrapper".executable = true;
  xdg.dataFile."applications/steam.desktop".text =
    builtins.replaceStrings
      [ "Exec=steam" ]
      [ "Exec=${config.home.homeDirectory}/.local/bin/steam-wrapper" ]
      (builtins.readFile "${pkgs.steam}/share/applications/steam.desktop");

  xdg.desktopEntries.r2modman = {
    name = "r2modman";
    genericName = "Mod Manager";
    comment = "Thunderstore mod manager for Steam games";
    exec = "r2modman --no-sandbox";
    terminal = false;
    icon = "r2modman";
    type = "Application";
    categories = [ "Game" ];
  };
  xdg.configFile."fontconfig/conf.d/99-steam-cjk.conf".source = ./cjk-fontconfig.xml;
}
