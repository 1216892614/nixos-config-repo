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
    # Catppuccin Mocha — ayu-dark structure, mocha palette
    [mgr]
    cwd = { fg = "${colors.comment}" }

    hovered         = { reversed = true }
    preview_hovered = { underline = true }

    find_keyword  = { fg = "${colors.terminal.yellow}", bold = true, italic = true, underline = true }
    find_position = { fg = "${colors.terminal.magenta}", bold = true, italic = true }

    marker_copied   = { fg = "${colors.bg}", bg = "${colors.terminal.green}" }
    marker_cut      = { fg = "${colors.bg}", bg = "${colors.terminal.red}" }
    marker_marked   = { fg = "${colors.bg}", bg = "${colors.terminal.blue}" }
    marker_selected = { fg = "${colors.bg}", bg = "${colors.terminal.yellow}" }

    count_copied   = { fg = "${colors.bg}", bg = "${colors.terminal.green}" }
    count_cut      = { fg = "${colors.comment}", bg = "${colors.terminal.red}" }
    count_selected = { fg = "${colors.bg}", bg = "${colors.terminal.yellow}" }

    border_symbol = " "

    [tabs]
    active   = { fg = "${colors.bg}", bg = "${colors.accent}", bold = true }
    inactive = { fg = "${colors.accent}", bg = "${colors.bg}" }
    sep_inner = { open = "", close = "" }
    sep_outer = { open = "", close = "" }

    [mode]
    normal_main = { fg = "${colors.bg}", bg = "${colors.accent}", bold = true }
    normal_alt  = { fg = "${colors.terminal.blue}", bg = "${colors.surface.lift}", bold = true }

    select_main = { fg = "${colors.bg}", bg = "${colors.terminal.blue}", bold = true }
    select_alt  = { fg = "${colors.bg}", bg = "${colors.terminal.blue}", bold = true }

    unset_main = { fg = "${colors.bg}", bg = "${colors.terminal.red}", bold = true }
    unset_alt  = { fg = "${colors.bg}", bg = "${colors.terminal.red}", bold = true }

    [status]
    overall   = {}
    sep_left  = { open = "", close = "" }
    sep_right = { open = "", close = "" }

    progress_label  = { fg = "${colors.bg}", bold = true }
    progress_normal = { fg = "${colors.accent}", bg = "${colors.bg}" }
    progress_error  = { fg = "${colors.terminal.red}", bg = "${colors.bg}" }

    perm_type  = { fg = "${colors.fg}" }
    perm_write = { fg = "${colors.terminal.red}" }
    perm_exec  = { fg = "${colors.terminal.green}" }
    perm_read  = { fg = "${colors.terminal.blue}" }
    perm_sep   = { fg = "${colors.comment}" }

    [select]
    border   = { fg = "${colors.accent}" }
    active   = { fg = "${colors.terminal.red}", bold = true }
    inactive = { fg = "${colors.comment}", bg = "${colors.bg}" }

    [input]
    border = { fg = "${colors.accent}" }
    value  = { fg = "${colors.comment}" }

    [completion]
    border = { fg = "${colors.accent}", bg = "${colors.bg}" }

    [tasks]
    border  = { fg = "${colors.accent}" }
    title   = { fg = "${colors.comment}" }
    hovered = { fg = "${colors.terminal.green}", underline = true }

    [which]
    cols = 3
    mask            = { bg = "${colors.bg}" }
    cand            = { fg = "${colors.accent}" }
    rest            = { fg = "${colors.bg}" }
    desc            = { fg = "${colors.comment}" }
    separator       = " > "
    separator_style = { fg = "${colors.comment}" }

    [help]
    on     = { fg = "${colors.accent}" }
    run    = { fg = "${colors.terminal.green}" }
    footer = { fg = "${colors.bg}", bg = "${colors.comment}" }

    [notify]
    title_info  = { fg = "${colors.terminal.green}" }
    title_warn  = { fg = "${colors.terminal.yellow}" }
    title_error = { fg = "${colors.terminal.red}" }

    [filetype]
    rules = [
      # directories
      { url = "*/", fg = "${colors.terminal.blue}" },

      # executables
      { url = "*", is = "exec", fg = "${colors.terminal.green}" },

      # images
      { mime = "image/*", fg = "${colors.terminal.yellow}" },

      # media
      { mime = "{audio,video}/*", fg = "${colors.terminal.green}" },

      # archives
      { mime = "application/{,g}zip", fg = "${colors.terminal.red}" },
      { mime = "application/x-{tar,bzip*,7z-compressed,xz,rar}", fg = "${colors.terminal.red}" },

      # documents
      { mime = "application/{pdf,doc,rtf,vnd.*}", fg = "${colors.terminal.blue}" },

      # scripts and code
      { mime = "application/{x-shellscript,x-python,x-ruby,x-javascript}", fg = "${colors.terminal.yellow}" },
      { mime = "text/x-{c,c++}", fg = "${colors.terminal.blue}" },

      # config files
      { url = "*.json", fg = "${colors.terminal.yellow}" },
      { url = "*.yml", fg = "${colors.terminal.blue}" },
      { url = "*.toml", fg = "${colors.terminal.magenta}" },

      # special files
      { url = "*", is = "orphan", bg = "${colors.bg}" },
      { url = "*", is = "dummy", bg = "${colors.bg}" },

      # fallback
      { url = "*/", fg = "${colors.terminal.blue}" },
    ]
  '';
}
