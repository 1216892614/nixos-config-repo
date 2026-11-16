{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  home.file.".local/bin/qoder-desktop".text = ''
    #!/usr/bin/env bash
    exec "${config.home.homeDirectory}/.local/opt/qoder/opt/Qoder/qoder" --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime "$@"
  '';
  home.file.".local/bin/qoder-desktop".executable = true;
  xdg.dataFile."applications/qoder.desktop".text = ''
    [Desktop Entry]
    Name=Qoder
    Comment=Agentic Coding Platform
    Exec=${config.home.homeDirectory}/.local/bin/qoder-desktop --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime %F
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/qoder/usr/share/icons/hicolor/512x512/apps/qoder.png
    Categories=Development;IDE;
    Keywords=qoder;code;editor;ai;agent;
    MimeType=text/plain;
  '';
}
