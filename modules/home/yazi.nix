{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../lib/colors.nix;
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
        terminal = [
          {
            run = ''kitty --directory "%s" -e zellij'';
            orphan = true;
            desc = "Open in Zellij (kitty)";
            "for" = "linux";
          }
        ];
      };

      open = {
        prepend_rules = [
          { url = "*/"; use = "terminal"; }
        ];
      };
    };

    # Forest Night theme — colors derived from lib/colors.nix

    plugins = {
      clipboard = pkgs.fetchFromGitHub {
        owner = "XYenon";
        repo = "clipboard.yazi";
        rev = "3b9681091b783d6bc5d07172afd6159060a7db63";
        hash = "sha256-8p2RC8F8JH1K36HebJM58stHX+lFLD+KYQxfdJm06y0=";
      };
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

  xdg.configFile."yazi/theme.toml".text = ''
    # Forest Night — generated from lib/colors.nix
    [manager]
    cwd = { fg = "${colors.accent}" }

    hovered = { fg = "${colors.bg}", bg = "${colors.accent}" }
    preview_hovered = { underline = true }

    find_keyword = { fg = "${colors.terminal.yellow}", italic = true }
    find_position = { fg = "${colors.terminal.magenta}", bg = "reset", italic = true }

    marker_selected = { fg = "${colors.accent}", bg = "${colors.accent}" }
    marker_copied   = { fg = "${colors.terminal.green}", bg = "${colors.terminal.green}" }
    marker_cut      = { fg = "${colors.terminal.red}", bg = "${colors.terminal.red}" }

    tab_active   = { fg = "${colors.bg}", bg = "${colors.accent}" }
    tab_inactive = { fg = "${colors.fg}", bg = "${colors.surface.lift}" }
    tab_width    = 1

    border_symbol = "│"
    border_style  = { fg = "${colors.comment}" }

    [status]
    separator_open  = ""
    separator_close = ""
    separator_style = { fg = "${colors.surface.lift}", bg = "${colors.surface.lift}" }

    mode_normal = { fg = "${colors.bg}", bg = "${colors.accent}", bold = true }
    mode_select = { fg = "${colors.bg}", bg = "${colors.terminal.yellow}", bold = true }
    mode_unset  = { fg = "${colors.bg}", bg = "${colors.terminal.red}", bold = true }

    progress_label  = { fg = "${colors.fg}", bold = true }
    progress_normal = { fg = "${colors.accent}", bg = "${colors.surface.lift}" }
    progress_error  = { fg = "${colors.terminal.red}", bg = "${colors.surface.lift}" }

    permissions_t = { fg = "${colors.accent}" }
    permissions_r = { fg = "${colors.terminal.yellow}" }
    permissions_w = { fg = "${colors.terminal.red}" }
    permissions_x = { fg = "${colors.terminal.green}" }
    permissions_s = { fg = "${colors.comment}" }

    [input]
    border   = { fg = "${colors.accent}" }
    title    = {}
    value    = {}
    selected = { reversed = true }

    [select]
    border   = { fg = "${colors.accent}" }
    active   = { fg = "${colors.terminal.magenta}" }
    inactive = {}

    [tasks]
    border  = { fg = "${colors.accent}" }
    title   = {}
    hovered = { underline = true }

    [which]
    mask            = { bg = "${colors.surface.lift}" }
    cand            = { fg = "${colors.terminal.cyan}" }
    rest            = { fg = "${colors.comment}" }
    desc            = { fg = "${colors.terminal.magenta}" }
    separator       = "  "
    separator_style = { fg = "${colors.comment}" }

    [help]
    on      = { fg = "${colors.terminal.magenta}" }
    exec    = { fg = "${colors.terminal.cyan}" }
    desc    = { fg = "${colors.comment}" }
    hovered = { bg = "${colors.surface.lift}", bold = true }
    footer  = { fg = "${colors.fg}", bg = "${colors.bg}" }

    [filetype]
    rules = [
      { mime = "image/*", fg = "${colors.terminal.cyan}" },
      { mime = "video/*", fg = "${colors.terminal.yellow}" },
      { mime = "audio/*", fg = "${colors.terminal.yellow}" },
      { mime = "application/zip",  fg = "${colors.terminal.magenta}" },
      { mime = "application/gzip", fg = "${colors.terminal.magenta}" },
      { mime = "application/x-tar", fg = "${colors.terminal.magenta}" },
      { mime = "application/x-bzip2", fg = "${colors.terminal.magenta}" },
      { mime = "application/x-7z-compressed", fg = "${colors.terminal.magenta}" },
      { mime = "application/x-rar", fg = "${colors.terminal.magenta}" },
      { name = "*", fg = "${colors.fg}" },
      { name = "*/", fg = "${colors.accent}" },
    ]
  '';
}
