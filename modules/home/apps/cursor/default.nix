{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  home.file.".cursor/mcp.json".text = builtins.toJSON {
    inherit mcpServers;
  };
  home.packages = with pkgs; [ nil pyright ];
  home.file.".local/bin/cursor".text = ''
    #!/usr/bin/env bash
    exec "${config.home.homeDirectory}/.local/opt/cursor/usr/share/cursor/cursor" --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime "$@"
  '';
  home.file.".local/bin/cursor".executable = true;
  xdg.dataFile."applications/cursor.desktop".text = ''
    [Desktop Entry]
    Name=Cursor
    Comment=AI Code Editor
    Exec=${config.home.homeDirectory}/.local/bin/cursor --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime %F
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/cursor/co.anysphere.cursor.png
    Categories=Development;IDE;
    Keywords=cursor;code;editor;ai;
    MimeType=text/plain;
  '';
}
