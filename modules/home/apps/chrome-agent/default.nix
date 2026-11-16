{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
let
  tpl = import ../../../../lib/template.nix;
in
{
  home.activation.installChromeAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] (tpl ./install.sh { config_home_homeDirectory = config.home.homeDirectory; });
}
