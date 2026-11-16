{ colors, ... }:

let
  tpl = import ../../../../lib/template.nix;
  providersWithoutClipboardShortcut = [ "desktopapplications" "calc" "websearch" ];
in
{
  programs.walker = {
    enable = true;
    runAsService = true;

    config = {
      theme = "forest-night";
      builtins.clipboard = {
        image_height = 300;
        max_entries = 50;
        exec = "sh -c 'cliphist decode | wl-copy && sleep 0.3 && wtype -M ctrl v -m ctrl'";
      };
      providers = {
        default = providersWithoutClipboardShortcut;
        empty = [ "desktopapplications" ];
        max_results = 50;
      };
    };

    themes = {
      forest-night = {
        style = tpl ./theme.css {
      bg = colors.bg;
      surface_over = colors.surface.over;
      fg = colors.fg;
      error = colors.error;
        };
      };
    };
  };
}
