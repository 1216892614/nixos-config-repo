{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../lib/colors.nix;
  
  # Forest Night theme for Yazi
  forest-night-theme = ''
    [manager]
    cwd = { fg = "${colors.accent}" }
    
    hovered         = { fg = "${colors.bg}", bg = "${colors.accent}" }
    preview_hovered = { underline = true }
    
    find_keyword  = { fg = "${colors.string}", italic = true }
    find_position = { fg = "${colors.comment}", bg = "reset", italic = true }
    
    marker_selected = { fg = "${colors.func}", bg = "${colors.func}" }
    marker_copied   = { fg = "${colors.string}", bg = "${colors.string}" }
    marker_cut      = { fg = "${colors.removed}", bg = "${colors.removed}" }
    
    tab_active   = { fg = "${colors.bg}", bg = "${colors.accent}" }
    tab_inactive = { fg = "${colors.fg}", bg = "${colors.surface.lift}" }
    tab_width    = 1
    
    border_symbol = "│"
    border_style  = { fg = "${colors.surface.over}" }
    
    [status]
    separator_open  = ""
    separator_close = ""
    separator_style = { fg = "${colors.surface.over}", bg = "${colors.surface.over}" }
    
    mode_normal = { fg = "${colors.bg}", bg = "${colors.accent}", bold = true }
    mode_select = { fg = "${colors.bg}", bg = "${colors.func}", bold = true }
    mode_unset  = { fg = "${colors.bg}", bg = "${colors.comment}", bold = true }
    
    progress_label  = { fg = "${colors.fg}", bold = true }
    progress_normal = { fg = "${colors.accent}", bg = "${colors.surface.lift}" }
    progress_error  = { fg = "${colors.error}", bg = "${colors.surface.lift}" }
    
    permissions_t = { fg = "${colors.func}" }
    permissions_r = { fg = "${colors.string}" }
    permissions_w = { fg = "${colors.removed}" }
    permissions_x = { fg = "${colors.accent}" }
    permissions_s = { fg = "${colors.comment}" }
    
    [select]
    border   = { fg = "${colors.accent}" }
    active   = { fg = "${colors.accent}" }
    inactive = { fg = "${colors.fg}" }
    
    [input]
    border   = { fg = "${colors.accent}" }
    title    = {}
    value    = {}
    selected = { reversed = true }
    
    [completion]
    border   = { fg = "${colors.accent}" }
    active   = { bg = "${colors.surface.lift}" }
    inactive = {}
    
    [tasks]
    border  = { fg = "${colors.accent}" }
    title   = {}
    hovered = { underline = true }
    
    [which]
    mask            = { bg = "${colors.surface.sunk}" }
    cand            = { fg = "${colors.accent}" }
    rest            = { fg = "${colors.comment}" }
    desc            = { fg = "${colors.fg}" }
    separator       = "  "
    separator_style = { fg = "${colors.comment}" }
    
    [help]
    on      = { fg = "${colors.accent}" }
    exec    = { fg = "${colors.func}" }
    desc    = { fg = "${colors.fg}" }
    hovered = { bg = "${colors.surface.lift}", bold = true }
    footer  = { fg = "${colors.bg}", bg = "${colors.fg}" }
    
    [filetype]
    rules = [
      { mime = "image/*", fg = "${colors.accent}" },
      { mime = "video/*", fg = "${colors.tag}" },
      { mime = "audio/*", fg = "${colors.constant}" },
      { mime = "application/zip", fg = "${colors.removed}" },
      { mime = "application/gzip", fg = "${colors.removed}" },
      { mime = "application/x-tar", fg = "${colors.removed}" },
      { mime = "application/x-bzip", fg = "${colors.removed}" },
      { mime = "application/x-bzip2", fg = "${colors.removed}" },
      { mime = "application/x-7z-compressed", fg = "${colors.removed}" },
      { mime = "application/x-rar", fg = "${colors.removed}" },
      { name = "*", fg = "${colors.fg}" },
      { name = "*/", fg = "${colors.accent}" }
    ]
  '';
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
            run = ''kitty -e zellij --cwd "%s"'';
            orphan = true;
            desc = "Open in Zellij (kitty)";
            "for" = "linux";
          }
        ];
      };

      open = {
        prepend_rules = [
          { mime = "inode/directory"; use = "terminal"; }
        ];
      };
    };

    # Forest Night theme (custom)

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

  xdg.configFile."yazi/theme.toml" = {
    text = forest-night-theme;
  };
}
