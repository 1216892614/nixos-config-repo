{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
in
{
  programs.walker = {
    enable = true;
    runAsService = true;

    config = {
      builtins.clipboard = {
        image_height = 300;
        max_entries = 50;
        exec = "sh -c 'cliphist decode | wl-copy && sleep 0.3 && wtype -M ctrl v -m ctrl'";
      };
      providers = {
        # clipboard only when launched with Super+V (walker -m clipboard)
        default = [ "desktopapplications" "calc" "websearch" ];
        empty = [ "desktopapplications" ];
        max_results = 50;
      };
    };

    themes = {
      forest-night = {
        style = ''
          * {
            font-family: "Sarasa UI SC", sans-serif;
          }
          #window {
            background: ${colors.bg};
            border: 2px solid ${colors.accent};
            border-radius: 12px;
            padding: 16px;
          }
          #search entry {
            background: ${colors.surface.lift};
            color: ${colors.fg};
            border: 1px solid ${colors.surface.over};
            border-radius: 8px;
            padding: 8px;
          }
          #item {
            background: transparent;
            color: ${colors.fg};
            border-radius: 8px;
            padding: 8px;
          }
          #item:selected {
            background: ${colors.surface.lift};
            color: ${colors.accent};
            border: 1px solid ${colors.accent};
          }
          scrollbar slider {
            background: ${colors.surface.over};
            border-radius: 4px;
            min-width: 4px;
          }
        '';
      };
    };
  };

  # Memory pinning: keep walker + elephant in physical RAM.
  # Walker (~20 MB) is the app launcher; elephant (~40 MB) is its backend.
  # Swapping these causes noticeable delay when pressing Super+Return.
  systemd.user.services.walker.Service = {
    MemoryMin = "48M";
    MemoryLow = "96M";
    OOMScoreAdjust = "-600";
  };
  systemd.user.services.elephant.Service = {
    MemoryMin = "64M";
    MemoryLow = "128M";
    OOMScoreAdjust = "-600";
  };
}
