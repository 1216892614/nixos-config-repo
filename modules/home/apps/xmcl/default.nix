{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
let
  tpl = import ../../../../lib/template.nix;
in
{
  home.file.".local/bin/java-mc".text = (builtins.readFile ./java-wrapper.sh);
  home.file.".local/bin/java-mc".executable = true;

  home.file.".local/bin/xmcl".text = (tpl ./xmcl.sh { config_home_profileDirectory = config.home.profileDirectory; });
  home.file.".local/bin/xmcl".executable = true;
  xdg.dataFile."applications/xmcl.desktop".text = ''
    [Desktop Entry]
    Name=X Minecraft Launcher
    Comment=Minecraft launcher with modpack support
    Exec=${config.home.homeDirectory}/.local/bin/xmcl %U
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/xmcl/xmcl.png
    Categories=Game;
    Keywords=minecraft;launcher;mod;
  '';
}
