{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
let
  tpl = import ../../../../lib/template.nix;
in
{
  home.file.".local/bin/dingtalk".text = ''
    #!/usr/bin/env bash
    DINGTALK_BASE="${config.home.homeDirectory}/.local/opt/dingtalk/opt/apps/com.alibabainc.dingtalk/files"
    VERSION_DIR="$(find "$DINGTALK_BASE" -maxdepth 1 -type d -name '*-Release.*' | head -1)"
    if [ -z "$VERSION_DIR" ]; then
      echo "DingTalk: version directory not found in $DINGTALK_BASE" >&2
      exit 1
    fi
    cd "$VERSION_DIR"
    LD_PRELOAD="./libgbm.so ./plugins/dtwebview/libcef.so" exec ./com.alibabainc.dingtalk "$@"
  '';
  home.file.".local/bin/dingtalk".executable = true;
  xdg.dataFile."applications/dingtalk.desktop".text = (tpl ./dingtalk.desktop { config_home_homeDirectory = config.home.homeDirectory; });
}
