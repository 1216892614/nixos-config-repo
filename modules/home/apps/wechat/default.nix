{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
let
  tpl = import ../../../../lib/template.nix;
in
{
  home.file.".local/bin/wechat-wrapper".text = ''
    #!/bin/sh
    if command -v systemctl >/dev/null 2>&1; then
      for line in $(systemctl --user show-environment 2>/dev/null); do
        case "$line" in *=*) export "$line" ;; esac
      done 2>/dev/null || true
    fi
    exec ${pkgs.wechat}/bin/wechat "$@"
  '';
  home.file.".local/bin/wechat-wrapper".executable = true;
  xdg.dataFile."applications/wechat.desktop".text = (tpl ./wechat.desktop { config_home_homeDirectory = config.home.homeDirectory; });
}
