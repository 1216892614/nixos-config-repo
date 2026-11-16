{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
let
  tpl = import ../../../../lib/template.nix;
in
{
  home.activation.installDebs = lib.hm.dag.entryAfter [ "writeBoundary" ] (tpl ./install-deb.sh { config_home_homeDirectory = config.home.homeDirectory; pkgs_dpkg = pkgs.dpkg; pkgs_patchelf = pkgs.patchelf; pkgs_glibc = pkgs.glibc; });

  home.activation.installAppImages = lib.hm.dag.entryAfter [ "writeBoundary" ] (tpl ./install-appimage.sh { config_home_homeDirectory = config.home.homeDirectory; });
}
