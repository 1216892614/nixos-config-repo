# Allow non-Nix binaries (e.g. npm/Bun native addons) that expect
# /lib64/ld-linux-x86-64.so.2 and common runtime libs to run on NixOS.
{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Provides libstdc++.so.6 for native addons like opencode's file watcher.
      stdenv.cc.cc.lib
    ];
  };
}
