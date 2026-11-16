{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  home.file.".local/bin/osu".text = ''
    #!/usr/bin/env bash
    exec "${config.home.homeDirectory}/.local/opt/osu/usr/bin/osu!" "$@"
  '';
  home.file.".local/bin/osu".executable = true;
  xdg.dataFile."applications/osu.desktop".text = ''
    [Desktop Entry]
    Name=osu!
    Comment=Rhythm is just a click away
    Exec=${config.home.homeDirectory}/.local/bin/osu %U
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/osu/osu.png
    Categories=Game;
    Keywords=osu;rhythm;game;
  '';
}
