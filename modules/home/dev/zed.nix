{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;

  # Zed theme generated from lib/colors.nix (Forest Night)
  forestNightTheme = {
    name = "Forest Night";
    author = "ep-o1";
    themes = [{
      name = "Forest Night";
      appearance = "dark";
      style = {
        # Editor
        background = colors.bg;
        "editor.background" = colors.bg;
        "editor.foreground" = colors.fg;
        "editor.gutter.background" = colors.bg;
        "editor.line.active" = colors.surface.lift;
        "editor.active_line.background" = colors.surface.lift;
        "editor.highlighted_line.background" = colors.surface.lift;
        "editor.wrap_guide" = colors.surface.lift;
        "editor.invisible" = colors.surface.over;

        # Cursor
        "editor.cursor" = colors.accent;

        # Selection
        "editor.selection" = colors.selection;

        # Terminal
        "terminal.background" = colors.terminal.bg;
        "terminal.foreground" = colors.terminal.fg;
        "terminal.ansi.black" = colors.terminal.black;
        "terminal.ansi.red" = colors.terminal.red;
        "terminal.ansi.green" = colors.terminal.green;
        "terminal.ansi.yellow" = colors.terminal.yellow;
        "terminal.ansi.blue" = colors.terminal.blue;
        "terminal.ansi.magenta" = colors.terminal.magenta;
        "terminal.ansi.cyan" = colors.terminal.cyan;
        "terminal.ansi.white" = colors.terminal.white;
        "terminal.ansi.bright_black" = colors.terminal.brightBlack;
        "terminal.ansi.bright_red" = colors.terminal.brightRed;
        "terminal.ansi.bright_green" = colors.terminal.brightGreen;
        "terminal.ansi.bright_yellow" = colors.terminal.brightYellow;
        "terminal.ansi.bright_blue" = colors.terminal.brightBlue;
        "terminal.ansi.bright_magenta" = colors.terminal.brightMagenta;
        "terminal.ansi.bright_cyan" = colors.terminal.brightCyan;
        "terminal.ansi.bright_white" = colors.terminal.brightWhite;

        # UI panels
        "panel.background" = colors.surface.sunk;
        "panel.focused_border" = colors.accent;
        "tab_bar.background" = colors.surface.sunk;
        "tab.active_background" = colors.bg;
        "tab.inactive_background" = colors.surface.sunk;
        "toolbar.background" = colors.bg;
        "status_bar.background" = colors.surface.sunk;
        "title_bar.background" = colors.surface.sunk;
        "title_bar.inactive_background" = colors.surface.sunk;
        "scrollbar.thumb.background" = colors.surface.over;
        "scrollbar.track.background" = colors.bg;

        # Borders
        border = colors.surface.lift;
        "border.variant" = colors.surface.over;
        "border.focused" = colors.accent;
        "border.selected" = colors.accent;
        "border.disabled" = colors.surface.lift;

        # Text / syntax
        text = colors.fg;
        "text.muted" = colors.comment;
        "text.placeholder" = colors.comment;
        "text.disabled" = colors.surface.over;
        "text.accent" = colors.accent;

        # Element backgrounds
        "element.background" = colors.surface.lift;
        "element.hover" = colors.surface.over;
        "element.selected" = colors.selection;

        # Surface
        surface = colors.surface.base;
        "surface.background" = colors.surface.base;
        "elevated_surface.background" = colors.surface.lift;

        # Git gutters
        "created" = colors.added;
        "modified" = colors.modified;
        "deleted" = colors.removed;
        "conflict" = colors.terminal.yellow;

        # Diagnostics
        "error" = colors.error;
        "error.background" = colors.surface.lift;
        "warning" = colors.terminal.yellow;
        "warning.background" = colors.surface.lift;
        "info" = colors.tag;
        "info.background" = colors.surface.lift;

        # Links
        "link_text.hover" = colors.tag;

        # Syntax highlighting
        "syntax" = {
          "keyword" = { color = colors.keyword; };
          "function" = { color = colors.func; };
          "string" = { color = colors.string; };
          "constant" = { color = colors.constant; };
          "comment" = { color = colors.comment; };
          "tag" = { color = colors.tag; };
          "operator" = { color = colors.operator; };
          "number" = { color = colors.constant; };
          "type" = { color = colors.entity; };
          "variable" = { color = colors.fg; };
          "property" = { color = colors.fg; };
          "punctuation" = { color = colors.comment; };
          "attribute" = { color = colors.entity; };
          "label" = { color = colors.tag; };
        };
      };
    }];
  };
in
{
  programs.zed-editor = {
    enable = true;

    extensions = [ "nix" "toml" "fish" ];

    userSettings = {
      auto_update = false;
      theme = {
        mode = "dark";
        dark = "Forest Night";
        light = "Forest Night";
      };
      buffer_font_family = "Sarasa Mono SC";
      buffer_font_size = 14;
      ui_font_family = "Sarasa UI SC";
      ui_font_size = 14;
      hour_format = "hour24";
      vim_mode = true;
      base_keymap = "VSCode";
      load_direnv = "shell_hook";
      terminal = {
        font_family = "Sarasa Mono SC";
        font_size = 13;
        shell = "system";
        working_directory = "current_project_directory";
      };
      telemetry = {
        metrics = false;
        diagnostics = false;
      };
    };
  };

  # Install Forest Night theme
  xdg.configFile."zed/themes/forest-night.json".text = builtins.toJSON forestNightTheme;

  # Set zed as default EDITOR/VISUAL
  home.sessionVariables = {
    EDITOR = "zeditor --wait";
    VISUAL = "zeditor --wait";
  };
}
