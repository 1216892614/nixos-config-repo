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
        exec = "wl-copy";
      };
    };

    themes = {
      ayu-dark = {
        ui = {
          window = {
            box = {
              background = colors.bg;
              border.color = colors.accent;
              border.width = 2;
              corner_radius = 12;
              padding = 16;
            };
          };
          search = {
            entry = {
              background = colors.surface.lift;
              color = colors.fg;
              border.color = colors.surface.over;
              corner_radius = 8;
              padding = 8;
            };
            spinner = {
              color = colors.accent;
            };
          };
          list = {
            item = {
              background = "transparent";
              color = colors.fg;
              corner_radius = 8;
              padding = 8;
            };
            item_selected = {
              background = colors.surface.lift;
              color = colors.accent;
              corner_radius = 8;
              padding = 8;
              border.color = colors.accent;
              border.width = 1;
            };
          };
          scroll = {
            bar = {
              background = colors.surface.over;
              corner_radius = 4;
              width = 4;
            };
          };
        };
      };
    };
  };
}
