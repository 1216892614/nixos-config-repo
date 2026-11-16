{ pkgs, colors, ... }:

let
  mkLeaf = { pane = { }; };

  mkSplit = direction: children:
    if builtins.length children == 1 then
      builtins.head children
    else
      {
        pane = {
          split_direction = direction;
          _children = children;
        };
      };

  mkGrid = cols: rows:
    mkSplit "horizontal" (
      builtins.genList
        (_: mkSplit "vertical" (builtins.genList (_: mkLeaf) rows))
        cols
    );

  mkLayout = cols: rows: {
    layout = {
      _children = [
        {
          default_tab_template = {
            _children = [
              {
                pane = {
                  size = 1;
                  borderless = true;
                  plugin = {
                    location = "zellij:tab-bar";
                  };
                };
              }
              { children = { }; }
              {
                pane = {
                  size = 1;
                  borderless = true;
                  plugin = {
                    location = "zellij:status-bar";
                  };
                };
              }
            ];
          };
        }
        {
          tab = {
            _props.focus = true;
            _children = [ (mkGrid cols rows) ];
          };
        }
      ];
    };
  };

  tpl = import ../../../../lib/template.nix;
  actualShellCwdForScriptRecordingPatch = ../../../../patches/zellij-script-cwd.patch;
in
{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    package = pkgs.zellij.override {
      zellij-unwrapped = pkgs.zellij-unwrapped.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ actualShellCwdForScriptRecordingPatch ];
      });
    };

    settings = {
      theme = "moss-fern";
      default_shell = "fish";
      simplified_ui = true;
      pane_frames = false;
      default_mode = "locked";
      show_startup_tips = false;
    };

    extraConfig = (tpl ./theme.kdl {
      terminal_brightWhite = colors.terminal.brightWhite;
      accent = colors.accent;
      terminal_cyan = colors.terminal.cyan;
      terminal_green = colors.terminal.green;
      terminal_magenta = colors.terminal.magenta;
      terminal_bg = colors.terminal.bg;
      selection = colors.selection;
      terminal_red = colors.terminal.red;
      terminal_blue = colors.terminal.blue;
      terminal_black = colors.terminal.black;
      terminal_yellow = colors.terminal.yellow;
    }) + builtins.readFile ./keybinds.kdl;

    layouts = {
      "lo-1x2" = mkLayout 1 2;
      "lo-2x1" = mkLayout 2 1;
      "lo-2x2" = mkLayout 2 2;
      "lo-3x4" = mkLayout 3 4;
    };
  };
}
