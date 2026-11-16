{ pkgs, colors, ... }:

let
  tpl = import ../../../../lib/template.nix;
in
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";

    settings = {
      manager = {
        show_hidden = true;
        sort_by = "size";
        sort_dir_first = true;
        linemode = "size";
      };

      opener = {
        edit = [
          {
            run = ''zed "$@"'';
            orphan = true;
            desc = "Edit in Zed";
            "for" = "linux";
          }
        ];
        terminal = [
          {
            run = ''kitty --directory "$1" -e zellij'';
            orphan = true;
            desc = "Open in Zellij (kitty)";
            "for" = "linux";
          }
        ];
        image = [
          {
            run = ''imv "$@"'';
            orphan = true;
            desc = "View in imv";
          }
        ];
        postscript = [
          {
            run = ''evince "$@"'';
            orphan = true;
            desc = "View PS/EPS/AI in Evince";
          }
        ];
      };

      open = {
        prepend_rules = [
          { mime = "text/*"; use = "edit"; }
          { mime = "application/json"; use = "edit"; }
          { mime = "application/toml"; use = "edit"; }
          { mime = "application/xml"; use = "edit"; }
          { mime = "application/x-nix"; use = "edit"; }
          { mime = "application/javascript"; use = "edit"; }
          { url = "*/"; use = "terminal"; }
          { mime = "image/*"; use = "image"; }
          { mime = "application/postscript"; use = "postscript"; }
          { mime = "application/eps"; use = "postscript"; }
          { mime = "application/x-eps"; use = "postscript"; }
          { mime = "image/x-eps"; use = "postscript"; }
          { mime = "application/illustrator"; use = "postscript"; }
          { url = "*.ai"; use = "postscript"; }
          { url = "*.eps"; use = "postscript"; }
          { url = "*.ps"; use = "postscript"; }
        ];
      };

      plugin = {
        prepend_previewers = [
          { mime = "application/postscript"; run = "gs-preview"; }
          { mime = "application/eps"; run = "gs-preview"; }
          { mime = "application/x-eps"; run = "gs-preview"; }
          { mime = "image/x-eps"; run = "gs-preview"; }
          { mime = "application/illustrator"; run = "gs-preview"; }
          { url = "*.ai"; run = "gs-preview"; }
          { url = "*.eps"; run = "gs-preview"; }
          { url = "*.ps"; run = "gs-preview"; }
        ];
        prepend_preloaders = [
          { mime = "application/postscript"; run = "gs-preview"; }
          { mime = "application/eps"; run = "gs-preview"; }
          { mime = "application/x-eps"; run = "gs-preview"; }
          { mime = "image/x-eps"; run = "gs-preview"; }
          { mime = "application/illustrator"; run = "gs-preview"; }
          { url = "*.ai"; run = "gs-preview"; }
          { url = "*.eps"; run = "gs-preview"; }
          { url = "*.ps"; run = "gs-preview"; }
        ];
      };
    };


    plugins = {
      clipboard = pkgs.fetchFromGitHub {
        owner = "XYenon";
        repo = "clipboard.yazi";
        rev = "3b9681091b783d6bc5d07172afd6159060a7db63";
        hash = "sha256-8p2RC8F8JH1K36HebJM58stHX+lFLD+KYQxfdJm06y0=";
      };
      gs-preview = ../../../../pkgs/yazi-plugins/gs-preview.yazi;
    };

    keymap = {
      manager.prepend_keymap = [
        {
          on = [ "y" ];
          run = [
            "yank"
            "plugin clipboard -- --action=copy"
          ];
          desc = "Yank and copy to system clipboard";
        }
        {
          on = [ "<Enter>" ];
          run = "open";
          desc = "Open file or directory (folders open in Zellij)";
        }
      ];
    };
  };

  xdg.configFile."yazi/theme.toml".text = tpl ./theme.toml {
      comment = colors.comment;
      terminal_yellow = colors.terminal.yellow;
      terminal_magenta = colors.terminal.magenta;
      bg = colors.bg;
      terminal_green = colors.terminal.green;
      terminal_red = colors.terminal.red;
      terminal_blue = colors.terminal.blue;
      accent = colors.accent;
      surface_lift = colors.surface.lift;
      fg = colors.fg;
  };
}
