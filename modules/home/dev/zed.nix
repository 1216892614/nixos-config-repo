{ config, lib, pkgs, inputs, ... }:

let
  env = if builtins.pathExists ../../../env.nix then import ../../../env.nix else {};
  colors = import ../../../lib/colors.nix;

  # Zed theme generated from lib/colors.nix (Moss & Fern v2)
  mossFernTheme = {
    "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
    name = "Moss and Fern";
    author = "ep-o1";
    themes = [{
      name = "Moss and Fern";
      appearance = "dark";
      style = {
        # ── Editor ─────────────────────────────────────────────────────
        background = colors.bg;
        "editor.background" = colors.bg;
        "editor.foreground" = colors.fg;
        "editor.gutter.background" = colors.bg;
        "editor.active_line.background" = "${colors.surface.lift}cc";
        "editor.highlighted_line.background" = "${colors.surface.lift}aa";
        "editor.line_number" = colors.comment;
        "editor.active_line_number" = colors.fg;
        "editor.wrap_guide" = "${colors.surface.over}60";
        "editor.invisible" = "${colors.surface.over}80";
        "editor.subheader.background" = colors.surface.sunk;
        "editor.document_highlight.read_background" = "${colors.selection}60";
        "editor.document_highlight.write_background" = "${colors.selection}90";

        # ── Cursor ────────────────────────────────────────────────────
        "editor.cursor" = colors.accent;

        # ── Selection — 高对比度，文字清晰可见 ──────────────────────
        "editor.selection" = "${colors.selection}cc";
        "editor.selection.inactive" = "${colors.selection}70";

        # ── Search highlights ─────────────────────────────────────────
        "search.match_background" = "${colors.terminal.yellow}40";

        # ── Terminal ──────────────────────────────────────────────────
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

        # ── UI panels ────────────────────────────────────────────────
        "panel.background" = colors.surface.sunk;
        "panel.focused_border" = colors.accent;
        "tab_bar.background" = colors.surface.sunk;
        "tab.active_background" = colors.bg;
        "tab.inactive_background" = colors.surface.sunk;
        "toolbar.background" = colors.bg;
        "status_bar.background" = colors.surface.sunk;
        "title_bar.background" = colors.surface.sunk;
        "title_bar.inactive_background" = "${colors.surface.sunk}e0";
        "scrollbar.thumb.background" = "${colors.surface.over}90";
        "scrollbar.thumb.hover_background" = "${colors.inactive}cc";
        "scrollbar.track.background" = colors.bg;
        "scrollbar.track.border" = colors.bg;
        "pane.focused_border" = colors.accent;

        # ── Borders ──────────────────────────────────────────────────
        border = colors.surface.over;
        "border.variant" = "${colors.surface.over}80";
        "border.focused" = colors.accent;
        "border.selected" = colors.accent;
        "border.disabled" = colors.surface.lift;
        "border.transparent" = "#00000000";

        # ── Text ─────────────────────────────────────────────────────
        text = colors.fg;
        "text.muted" = colors.comment;
        "text.placeholder" = "${colors.comment}aa";
        "text.disabled" = "${colors.inactive}cc";
        "text.accent" = colors.accent;

        # ── Icons — 使图标清晰可辨 ──────────────────────────────────
        icon = colors.fg;
        "icon.muted" = colors.comment;
        "icon.disabled" = colors.inactive;
        "icon.placeholder" = colors.comment;
        "icon.accent" = colors.accent;

        # ── Element backgrounds（按钮、列表项等）─────────────────────
        "element.background" = colors.surface.lift;
        "element.hover" = "${colors.surface.over}cc";
        "element.active" = "${colors.surface.over}e0";
        "element.selected" = "${colors.accent}30";
        "element.disabled" = "${colors.surface.lift}80";

        # ── Ghost elements（文件树、命令面板候选项等）─────────────────
        "ghost_element.background" = "#00000000";
        "ghost_element.hover" = "${colors.surface.over}60";
        "ghost_element.active" = "${colors.surface.over}90";
        "ghost_element.selected" = "${colors.accent}25";
        "ghost_element.disabled" = "${colors.surface.lift}40";

        # ── Surface ──────────────────────────────────────────────────
        surface = colors.surface.base;
        "surface.background" = colors.surface.base;
        "elevated_surface.background" = colors.surface.lift;
        "drop_target.background" = "${colors.accent}20";

        # ── Git gutters ──────────────────────────────────────────────
        "created" = colors.added;
        "modified" = colors.modified;
        "deleted" = colors.removed;
        "conflict" = colors.terminal.yellow;
        "renamed" = colors.terminal.blue;

        # ── Diagnostics ──────────────────────────────────────────────
        "error" = colors.error;
        "error.background" = "${colors.error}15";
        "error.border" = "${colors.error}50";
        "warning" = colors.terminal.yellow;
        "warning.background" = "${colors.terminal.yellow}15";
        "warning.border" = "${colors.terminal.yellow}50";
        "info" = colors.func;
        "info.background" = "${colors.func}15";
        "info.border" = "${colors.func}50";
        "hint" = "${colors.comment}cc";
        "hint.background" = "${colors.surface.lift}80";
        "hint.border" = "${colors.surface.over}60";
        "predictive" = "${colors.comment}90";

        # ── Links ────────────────────────────────────────────────────
        "link_text.hover" = colors.func;

        # ── Players（多人协作光标颜色）───────────────────────────────
        players = [
          { cursor = colors.accent; background = "${colors.accent}30"; selection = "${colors.accent}30"; }
          { cursor = colors.func; background = "${colors.func}30"; selection = "${colors.func}30"; }
          { cursor = colors.terminal.magenta; background = "${colors.terminal.magenta}30"; selection = "${colors.terminal.magenta}30"; }
          { cursor = colors.terminal.yellow; background = "${colors.terminal.yellow}30"; selection = "${colors.terminal.yellow}30"; }
          { cursor = colors.tag; background = "${colors.tag}30"; selection = "${colors.tag}30"; }
          { cursor = colors.constant; background = "${colors.constant}30"; selection = "${colors.constant}30"; }
          { cursor = colors.terminal.red; background = "${colors.terminal.red}30"; selection = "${colors.terminal.red}30"; }
          { cursor = colors.terminal.brightGreen; background = "${colors.terminal.brightGreen}30"; selection = "${colors.terminal.brightGreen}30"; }
        ];

        # ── Syntax highlighting ──────────────────────────────────────
        "syntax" = {
          "keyword" = { color = colors.keyword; font_weight = 600; };
          "function" = { color = colors.func; };
          "function.method" = { color = colors.func; };
          "function.special_definition" = { color = colors.func; };
          "string" = { color = colors.string; };
          "string.escape" = { color = colors.constant; };
          "string.regex" = { color = colors.regexp; };
          "string.special" = { color = colors.string; font_style = "italic"; };
          "constant" = { color = colors.constant; };
          "number" = { color = colors.constant; };
          "boolean" = { color = colors.constant; };
          "comment" = { color = colors.comment; font_style = "italic"; };
          "comment.doc" = { color = colors.comment; font_style = "italic"; };
          "tag" = { color = colors.tag; };
          "operator" = { color = colors.operator; };
          "type" = { color = colors.entity; };
          "type.builtin" = { color = colors.entity; font_weight = 600; };
          "constructor" = { color = colors.entity; };
          "variable" = { color = colors.fg; };
          "variable.special" = { color = colors.constant; };
          "property" = { color = colors.tag; };
          "punctuation" = { color = "${colors.fg}cc"; };
          "punctuation.bracket" = { color = "${colors.fg}bb"; };
          "punctuation.delimiter" = { color = "${colors.fg}aa"; };
          "punctuation.special" = { color = colors.operator; };
          "attribute" = { color = colors.entity; font_style = "italic"; };
          "label" = { color = colors.tag; };
          "link_text" = { color = colors.func; };
          "link_uri" = { color = colors.string; font_style = "italic"; };
          "embedded" = { color = colors.fg; };
          "emphasis" = { font_style = "italic"; };
          "emphasis.strong" = { font_weight = 700; };
          "title" = { color = colors.func; font_weight = 700; };
          "preproc" = { color = colors.keyword; };
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
        dark = "Moss and Fern";
        light = "Moss and Fern";
      };
      buffer_font_family = "Sarasa Mono SC";
      buffer_font_size = 14;
      ui_font_family = "Sarasa UI SC";
      ui_font_size = 14;
      hour_format = "hour24";
      vim_mode = false;
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

      # ── LLM Providers ──────────────────────────────────────────────────────
      language_models = {
        # DeepSeek (direct API)
        deepseek = {
          api_url = "https://api.deepseek.com";
          available_models = [
            {
              name = "deepseek-v4-pro";
              display_name = "DeepSeek V4 Pro";
              max_tokens = 1000000;
              max_output_tokens = 384000;
            }
          ];
        };

        # OpenAI-compatible providers
        openai_compatible = {
          # BigBigDog — Claude/GPT/Gemini relay
          bigbigdog = {
            api_url = "https://www.hongkongdog.cc/v1";
            available_models = [
              {
                name = "claude-fable-5";
                display_name = "Claude Fable 5";
                max_tokens = 200000;
              }
              {
                name = "claude-opus-4-8";
                display_name = "Claude Opus 4.8";
                max_tokens = 200000;
              }
              {
                name = "claude-opus-4-7";
                display_name = "Claude Opus 4.7";
                max_tokens = 200000;
              }
              {
                name = "claude-opus-4-6";
                display_name = "Claude Opus 4.6";
                max_tokens = 200000;
              }
              {
                name = "gpt-5.3-codex";
                display_name = "GPT 5.3 Codex";
                max_tokens = 272000;
              }
              {
                name = "gpt-5.4";
                display_name = "GPT 5.4";
                max_tokens = 272000;
              }
              {
                name = "gpt-5.4-mini";
                display_name = "GPT 5.4 Mini";
                max_tokens = 272000;
              }
              {
                name = "gpt-5.5";
                display_name = "GPT 5.5";
                max_tokens = 272000;
              }
              {
                name = "gemini-3-flash";
                display_name = "Gemini 3 Flash";
                max_tokens = 1000000;
              }
              {
                name = "gemini-3.1-pro-preview";
                display_name = "Gemini 3.1 Pro";
                max_tokens = 1000000;
              }
            ];
          };

          # ByteCatCode — Anthropic relay
          bytecatcode = {
            api_url = "https://bytecat.lamclod.cn/v1";
            available_models = [
              {
                name = "claude-fable-5";
                display_name = "ByteCat Claude Fable 5";
                max_tokens = 200000;
              }
              {
                name = "claude-opus-4-8";
                display_name = "ByteCat Claude Opus 4.8";
                max_tokens = 200000;
              }
              {
                name = "claude-opus-4-7";
                display_name = "ByteCat Claude Opus 4.7";
                max_tokens = 200000;
              }
              {
                name = "claude-opus-4-6";
                display_name = "ByteCat Claude Opus 4.6";
                max_tokens = 200000;
              }
            ];
          };
        };
      };
    };
  };

  # Set API keys via environment variables for Zed LLM providers
  # Zed reads: DEEPSEEK_API_KEY, BIGBIGDOG_API_KEY, BYTECATCODE_API_KEY
  home.sessionVariables = {
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
    DEEPSEEK_API_KEY = env.deepseekApiKey or "";
    BIGBIGDOG_API_KEY = env.bigbigdogApiKey or "";
    BYTECATCODE_API_KEY = env.bytekatApiKey or "";
  };

  # Expose `zeditor` CLI alias (the package ships `bin/zed`)
  home.file.".local/bin/zeditor" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec zed "$@"
    '';
  };

  # Expose `zed-server` for headless / remote development usage
  home.file.".local/bin/zed-server" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec zed --foreground "$@"
    '';
  };

  # Desktop entry so Walker can discover Zed
  xdg.dataFile."applications/zed.desktop".text = ''
    [Desktop Entry]
    Name=Zed
    Comment=High-performance code editor
    Exec=zed %U
    Terminal=false
    Type=Application
    Icon=zed
    Categories=Development;IDE;TextEditor;
    Keywords=zed;editor;code;
    MimeType=text/plain;application/x-zerosize;x-scheme-handler/zed;
    Actions=NewWorkspace;

    [Desktop Action NewWorkspace]
    Exec=zed --new %U
    Name=Open a new workspace
  '';

  # Set Zed as default application for text files
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = "zed.desktop";
      "application/x-zerosize" = "zed.desktop";
      "x-scheme-handler/zed" = "zed.desktop";
    };
  };

  # Install Moss & Fern theme (generated from lib/colors.nix)
  xdg.configFile."zed/themes/moss-fern.json".text = builtins.toJSON mossFernTheme;
}
