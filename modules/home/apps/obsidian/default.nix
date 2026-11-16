{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  home.file.".local/bin/obsidian".text = ''
    #!/usr/bin/env bash
    exec "${config.home.homeDirectory}/.local/opt/obsidian/obsidian" --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime "$@"
  '';
  home.file.".local/bin/obsidian".executable = true;
  xdg.dataFile."applications/obsidian.desktop".text = ''
    [Desktop Entry]
    Name=Obsidian
    Comment=Knowledge base and note-taking
    Exec=${config.home.homeDirectory}/.local/bin/obsidian %U
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/obsidian/obsidian.png
    Categories=Office;
    Keywords=obsidian;notes;markdown;knowledge;
    MimeType=x-scheme-handler/obsidian;
  '';
}
