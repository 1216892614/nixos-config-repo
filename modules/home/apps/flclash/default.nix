{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  xdg.desktopEntries.flclash = {
    name = "FlClash";
    genericName = "Proxy Client";
    comment = "A multi-platform proxy client based on Clash Meta (mihomo)";
    exec = "${config.home.homeDirectory}/.local/opt/flclash/FlClash %u";
    terminal = false;
    icon = "${config.home.homeDirectory}/.local/opt/flclash/data/flutter_assets/assets/images/icon.png";
    categories = [ "Network" ];
  };
}
