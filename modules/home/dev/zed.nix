{ config, lib, pkgs, inputs, ... }:

let
  env = if builtins.pathExists ../../../env.nix then import ../../../env.nix else {};
  colors = import ../../../lib/colors.nix;

  # Zed theme generated from lib/colors.nix (Catppuccin Mocha)
  catppuccinMochaTheme = {
    name = "Catppuccin Mocha";
    author = "ep-o1";
    themes = [{
      name = "Catppuccin Mocha";
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
        dark = "Catppuccin Mocha";
        light = "Catppuccin Mocha";
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
            api_url = "https://www.dogapi.cc/v1";
            available_models = [
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
    DEEPSEEK_API_KEY = env.opencodeDeepseekApiKey or "";
    BIGBIGDOG_API_KEY = env.opencodeBigbigdogApiKey or "";
    BYTECATCODE_API_KEY = env.opencodeBytekatApiKey or "";
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

  # Install Catppuccin Mocha theme (generated from lib/colors.nix)
  xdg.configFile."zed/themes/catppuccin-mocha.json".text = builtins.toJSON catppuccinMochaTheme;
}
