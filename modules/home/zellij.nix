{ config, lib, pkgs, inputs, ... }:

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

  colors = import ../../lib/colors.nix;
in
{
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;

    settings = {
      theme = "moss-fern";
      default_shell = "fish";
      simplified_ui = true;
      pane_frames = false;
      default_mode = "locked";
      show_startup_tips = false;
    };

    extraConfig = ''
      themes {
          moss-fern {
              text_unselected {
                  base "${colors.terminal.brightWhite}"
                  emphasis_0 "${colors.accent}"
                  emphasis_1 "${colors.terminal.cyan}"
                  emphasis_2 "${colors.terminal.green}"
                  emphasis_3 "${colors.terminal.magenta}"
                  background "${colors.terminal.black}"
              }
              text_selected {
                  base "${colors.terminal.brightWhite}"
                  emphasis_0 "${colors.accent}"
                  emphasis_1 "${colors.terminal.cyan}"
                  emphasis_2 "${colors.terminal.green}"
                  emphasis_3 "${colors.terminal.magenta}"
                  background "${colors.selection}"
              }
              ribbon_unselected {
                  base "${colors.terminal.black}"
                  emphasis_0 "${colors.terminal.red}"
                  emphasis_1 "${colors.terminal.brightWhite}"
                  emphasis_2 "${colors.terminal.blue}"
                  emphasis_3 "${colors.terminal.magenta}"
                  background "${colors.fg}"
              }
              ribbon_selected {
                  base "${colors.terminal.black}"
                  emphasis_0 "${colors.terminal.red}"
                  emphasis_1 "${colors.accent}"
                  emphasis_2 "${colors.terminal.magenta}"
                  emphasis_3 "${colors.terminal.blue}"
                  background "${colors.terminal.green}"
              }
              table_title {
                  base "${colors.terminal.brightWhite}"
                  emphasis_0 "${colors.terminal.cyan}"
                  emphasis_1 "${colors.terminal.green}"
                  emphasis_2 "${colors.terminal.blue}"
                  emphasis_3 "${colors.terminal.magenta}"
                  background "${colors.terminal.black}"
              }
              table_cell_unselected {
                  base "${colors.terminal.brightWhite}"
                  emphasis_0 "${colors.accent}"
                  emphasis_1 "${colors.terminal.cyan}"
                  emphasis_2 "${colors.terminal.green}"
                  emphasis_3 "${colors.terminal.magenta}"
                  background "${colors.terminal.black}"
              }
              table_cell_selected {
                  base "${colors.terminal.black}"
                  emphasis_0 "${colors.accent}"
                  emphasis_1 "${colors.terminal.cyan}"
                  emphasis_2 "${colors.terminal.green}"
                  emphasis_3 "${colors.terminal.magenta}"
                  background "${colors.terminal.green}"
              }
              list_unselected {
                  base "${colors.terminal.brightWhite}"
                  emphasis_0 "${colors.accent}"
                  emphasis_1 "${colors.terminal.cyan}"
                  emphasis_2 "${colors.terminal.green}"
                  emphasis_3 "${colors.terminal.magenta}"
                  background "${colors.terminal.bg}"
              }
              list_selected {
                  base "${colors.terminal.black}"
                  emphasis_0 "${colors.accent}"
                  emphasis_1 "${colors.terminal.cyan}"
                  emphasis_2 "${colors.terminal.green}"
                  emphasis_3 "${colors.terminal.magenta}"
                  background "${colors.terminal.green}"
              }
              frame_selected {
                  base "${colors.terminal.green}"
                  emphasis_0 "${colors.terminal.red}"
                  emphasis_1 "${colors.terminal.brightWhite}"
                  emphasis_2 "${colors.terminal.cyan}"
                  emphasis_3 "${colors.terminal.blue}"
              }
              exit_code_success {
                  base "${colors.terminal.green}"
                  emphasis_0 "${colors.terminal.cyan}"
                  emphasis_1 "${colors.terminal.black}"
                  emphasis_2 "${colors.terminal.magenta}"
                  emphasis_3 "${colors.terminal.blue}"
              }
              exit_code_error {
                  base "${colors.terminal.red}"
                  emphasis_0 "${colors.terminal.yellow}"
                  emphasis_1 "${colors.accent}"
                  emphasis_2 "${colors.terminal.brightWhite}"
                  emphasis_3 "${colors.terminal.magenta}"
              }
          }
      }
      keybinds clear-defaults=true {
          normal {
          }
          locked {
              bind "Ctrl g" { SwitchToMode "Normal"; }
          }
          resize {
              bind "r" { SwitchToMode "Normal"; }
              bind "h" "Left" { Resize "Increase Left"; }
              bind "j" "Down" { Resize "Increase Down"; }
              bind "k" "Up" { Resize "Increase Up"; }
              bind "l" "Right" { Resize "Increase Right"; }
              bind "H" { Resize "Decrease Left"; }
              bind "J" { Resize "Decrease Down"; }
              bind "K" { Resize "Decrease Up"; }
              bind "L" { Resize "Decrease Right"; }
              bind "=" "+" { Resize "Increase"; }
              bind "-" { Resize "Decrease"; }
          }
          pane {
              bind "p" { SwitchToMode "Normal"; }
              bind "h" "Left" { MoveFocus "Left"; }
              bind "l" "Right" { MoveFocus "Right"; }
              bind "j" "Down" { MoveFocus "Down"; }
              bind "k" "Up" { MoveFocus "Up"; }
              bind "Tab" { SwitchFocus; }
              bind "n" { NewPane; SwitchToMode "Locked"; }
              bind "d" { NewPane "Down"; SwitchToMode "Locked"; }
              bind "r" { NewPane "Right"; SwitchToMode "Locked"; }
              bind "s" { NewPane "stacked"; SwitchToMode "Locked"; }
              bind "x" { CloseFocus; SwitchToMode "Locked"; }
              bind "f" { ToggleFocusFullscreen; SwitchToMode "Locked"; }
              bind "z" { TogglePaneFrames; SwitchToMode "Locked"; }
              bind "w" { ToggleFloatingPanes; SwitchToMode "Locked"; }
              bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "Locked"; }
              bind "c" { SwitchToMode "RenamePane"; PaneNameInput 0; }
          }
          move {
              bind "m" { SwitchToMode "Normal"; }
              bind "n" "Tab" { MovePane; }
              bind "p" { MovePaneBackwards; }
              bind "h" "Left" { MovePane "Left"; }
              bind "j" "Down" { MovePane "Down"; }
              bind "k" "Up" { MovePane "Up"; }
              bind "l" "Right" { MovePane "Right"; }
          }
          tab {
              bind "t" { SwitchToMode "Normal"; }
              bind "r" { SwitchToMode "RenameTab"; TabNameInput 0; }
              bind "h" "Left" "Up" "k" { GoToPreviousTab; }
              bind "l" "Right" "Down" "j" { GoToNextTab; }
              bind "n" { NewTab; SwitchToMode "Locked"; }
              bind "x" { CloseTab; SwitchToMode "Locked"; }
              bind "s" { ToggleActiveSyncTab; SwitchToMode "Locked"; }
              bind "b" { BreakPane; SwitchToMode "Locked"; }
              bind "]" { BreakPaneRight; SwitchToMode "Locked"; }
              bind "[" { BreakPaneLeft; SwitchToMode "Locked"; }
              bind "1" { GoToTab 1; SwitchToMode "Locked"; }
              bind "2" { GoToTab 2; SwitchToMode "Locked"; }
              bind "3" { GoToTab 3; SwitchToMode "Locked"; }
              bind "4" { GoToTab 4; SwitchToMode "Locked"; }
              bind "5" { GoToTab 5; SwitchToMode "Locked"; }
              bind "6" { GoToTab 6; SwitchToMode "Locked"; }
              bind "7" { GoToTab 7; SwitchToMode "Locked"; }
              bind "8" { GoToTab 8; SwitchToMode "Locked"; }
              bind "9" { GoToTab 9; SwitchToMode "Locked"; }
              bind "Tab" { ToggleTab; }
          }
          scroll {
              bind "s" { SwitchToMode "Normal"; }
              bind "e" { EditScrollback; SwitchToMode "Locked"; }
              bind "f" { SwitchToMode "EnterSearch"; SearchInput 0; }
              bind "Ctrl c" { ScrollToBottom; SwitchToMode "Locked"; }
              bind "j" "Down" { ScrollDown; }
              bind "k" "Up" { ScrollUp; }
              bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
              bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
              bind "d" { HalfPageScrollDown; }
              bind "u" { HalfPageScrollUp; }
          }
          search {
              bind "Ctrl c" { ScrollToBottom; SwitchToMode "Locked"; }
              bind "j" "Down" { ScrollDown; }
              bind "k" "Up" { ScrollUp; }
              bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
              bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
              bind "d" { HalfPageScrollDown; }
              bind "u" { HalfPageScrollUp; }
              bind "n" { Search "down"; }
              bind "p" { Search "up"; }
              bind "c" { SearchToggleOption "CaseSensitivity"; }
              bind "w" { SearchToggleOption "Wrap"; }
              bind "o" { SearchToggleOption "WholeWord"; }
          }
          entersearch {
              bind "Ctrl c" "Esc" { SwitchToMode "Scroll"; }
              bind "Enter" { SwitchToMode "Search"; }
          }
          renametab {
              bind "Ctrl c" "Enter" { SwitchToMode "Locked"; }
              bind "Esc" { UndoRenameTab; SwitchToMode "Tab"; }
          }
          renamepane {
              bind "Ctrl c" "Enter" { SwitchToMode "Locked"; }
              bind "Esc" { UndoRenamePane; SwitchToMode "Pane"; }
          }
          session {
              bind "o" { SwitchToMode "Normal"; }
              bind "d" { Detach; }
              bind "w" {
                  LaunchOrFocusPlugin "session-manager" {
                      floating true
                      move_to_focused_tab true
                  };
                  SwitchToMode "Locked"
              }
              bind "c" {
                  LaunchOrFocusPlugin "configuration" {
                      floating true
                      move_to_focused_tab true
                  };
                  SwitchToMode "Locked"
              }
              bind "p" {
                  LaunchOrFocusPlugin "plugin-manager" {
                      floating true
                      move_to_focused_tab true
                  };
                  SwitchToMode "Locked"
              }
          }
          shared_except "locked" "renametab" "renamepane" {
              bind "Ctrl g" { SwitchToMode "Locked"; }
              bind "Ctrl q" { Quit; }
          }
          shared_except "renamepane" "renametab" "entersearch" "locked" {
              bind "Esc" { SwitchToMode "Locked"; }
          }
          // Alt keybinds work in BOTH normal and locked modes
          shared_among "normal" "locked" {
              bind "Alt n" { NewPane; }
              bind "Alt f" { ToggleFloatingPanes; }
              bind "Alt i" { MoveTab "Left"; }
              bind "Alt o" { MoveTab "Right"; }
              bind "Alt h" "Alt Left" { MoveFocusOrTab "Left"; }
              bind "Alt l" "Alt Right" { MoveFocusOrTab "Right"; }
              bind "Alt j" "Alt Down" { MoveFocus "Down"; }
              bind "Alt k" "Alt Up" { MoveFocus "Up"; }
              bind "Alt =" "Alt +" { Resize "Increase"; }
              bind "Alt -" { Resize "Decrease"; }
              bind "Alt [" { PreviousSwapLayout; }
              bind "Alt ]" { NextSwapLayout; }
          }
          shared_except "locked" "renametab" "renamepane" {
              bind "Enter" { SwitchToMode "Locked"; }
          }
          shared_except "pane" "locked" "renametab" "renamepane" "entersearch" {
              bind "p" { SwitchToMode "Pane"; }
          }
          shared_except "resize" "locked" "renametab" "renamepane" "entersearch" {
              bind "r" { SwitchToMode "Resize"; }
          }
          shared_except "scroll" "locked" "renametab" "renamepane" "entersearch" {
              bind "s" { SwitchToMode "Scroll"; }
          }
          shared_except "session" "locked" "renametab" "renamepane" "entersearch" {
              bind "o" { SwitchToMode "Session"; }
          }
          shared_except "tab" "locked" "renametab" "renamepane" "entersearch" {
              bind "t" { SwitchToMode "Tab"; }
          }
          shared_except "move" "locked" "renametab" "renamepane" "entersearch" {
              bind "m" { SwitchToMode "Move"; }
          }
      }
    '';

    layouts = {
      "lo-1x2" = mkLayout 1 2;
      "lo-2x1" = mkLayout 2 1;
      "lo-2x2" = mkLayout 2 2;
      "lo-3x4" = mkLayout 3 4;
    };
  };
}
