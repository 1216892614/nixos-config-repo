{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
let
  tpl = import ../../../../lib/template.nix;
  qqPackage = (import inputs.nixpkgs-qq { system = pkgs.stdenv.hostPlatform.system; config.allowUnfree = true; }).qq;
in
{
  xdg.dataFile."applications/qq.desktop".text = (tpl ./qq.desktop { pkgs_libpulseaudio = pkgs.libpulseaudio; qqPackage = qqPackage; });
}
