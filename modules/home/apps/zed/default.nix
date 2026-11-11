{ config, lib, pkgs, env, colors, ... }:

let

  mossFernTheme = {
    "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
    name = "Moss and Fern";
    author = "ep-o1";
    themes = [{
      name = "Moss and Fern";
      appearance = "dark";
      style = {
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

        "editor.cursor" = colors.accent;

        "editor.selection" = "${colors.selection}cc";
        "editor.selection.inactive" = "${colors.selection}70";

        "search.match_background" = "${colors.terminal.yellow}40";

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

        border = colors.surface.over;
        "border.variant" = "${colors.surface.over}80";
        "border.focused" = colors.accent;
        "border.selected" = colors.accent;
        "border.disabled" = colors.surface.lift;
        "border.transparent" = "#00000000";

        text = colors.fg;
        "text.muted" = colors.comment;
        "text.placeholder" = "${colors.comment}aa";
        "text.disabled" = "${colors.inactive}cc";
        "text.accent" = colors.accent;

        icon = colors.fg;
        "icon.muted" = colors.comment;
        "icon.disabled" = colors.inactive;
        "icon.placeholder" = colors.comment;
        "icon.accent" = colors.accent;

        "element.background" = colors.surface.lift;
        "element.hover" = "${colors.surface.over}cc";
        "element.active" = "${colors.surface.over}e0";
        "element.selected" = "${colors.accent}30";
        "element.disabled" = "${colors.surface.lift}80";

        "ghost_element.background" = "#00000000";
        "ghost_element.hover" = "${colors.surface.over}60";
        "ghost_element.active" = "${colors.surface.over}90";
        "ghost_element.selected" = "${colors.accent}25";
        "ghost_element.disabled" = "${colors.surface.lift}40";

        surface = colors.surface.base;
        "surface.background" = colors.surface.base;
        "elevated_surface.background" = colors.surface.lift;
        "drop_target.background" = "${colors.accent}20";

        "created" = colors.added;
        "modified" = colors.modified;
        "deleted" = colors.removed;
        "conflict" = colors.terminal.yellow;
        "renamed" = colors.terminal.blue;

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

        "link_text.hover" = colors.func;

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

    package = pkgs.symlinkJoin {
      name = "zed-with-declarative-credentials-for-stale-desktop-environment";
      paths = [ pkgs.zed-editor ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/zeditor" \
          --set DEEPSEEK_API_KEY ${lib.escapeShellArg (env.deepseekApiKey or "")} \
          --set BIGBIGDOG_API_KEY ${lib.escapeShellArg (env.bigbigdogApiKey or "")} \
          --set BYTECATCODE_API_KEY ${lib.escapeShellArg (env.bytekatApiKey or "")}
        ln -s zeditor "$out/bin/zed"
      '';
    };

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

      language_models = {
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

        openai_compatible = {
          bigbigdog = {
            api_url = "https://www.hongkongdog.cc/v1";
            available_models = [
              { name = "claude-fable-5"; display_name = "Claude Fable 5"; max_tokens = 200000; }
              { name = "claude-fable-5-1"; display_name = "Claude Fable 5.1"; max_tokens = 200000; }
              { name = "claude-fable-5-2"; display_name = "Claude Fable 5.2"; max_tokens = 200000; }
              { name = "claude-haiku-4-5-20251001"; display_name = "Claude Haiku 4.5"; max_tokens = 200000; }
              { name = "claude-haiku-4-5-20251001-thinking"; display_name = "Claude Haiku 4.5 Thinking"; max_tokens = 200000; }
              { name = "claude-haiku-5-5"; display_name = "Claude Haiku 5.5"; max_tokens = 200000; }
              { name = "claude-haiku-5-5-thinking"; display_name = "Claude Haiku 5.5 Thinking"; max_tokens = 200000; }
              { name = "claude-opus-4-6"; display_name = "Claude Opus 4.6"; max_tokens = 200000; }
              { name = "claude-opus-4-6-thinking"; display_name = "Claude Opus 4.6 Thinking"; max_tokens = 200000; }
              { name = "claude-opus-4-7"; display_name = "Claude Opus 4.7"; max_tokens = 200000; }
              { name = "claude-opus-4-7-thinking"; display_name = "Claude Opus 4.7 Thinking"; max_tokens = 200000; }
              { name = "claude-opus-4-8"; display_name = "Claude Opus 4.8"; max_tokens = 200000; }
              { name = "claude-opus-4-8-thinking"; display_name = "Claude Opus 4.8 Thinking"; max_tokens = 200000; }
              { name = "claude-opus-5"; display_name = "Claude Opus 5"; max_tokens = 200000; }
              { name = "claude-opus-5-thinking"; display_name = "Claude Opus 5 Thinking"; max_tokens = 200000; }
              { name = "claude-opus-5-5"; display_name = "Claude Opus 5.5"; max_tokens = 200000; }
              { name = "claude-opus-5-5-thinking"; display_name = "Claude Opus 5.5 Thinking"; max_tokens = 200000; }
              { name = "claude-sonnet-4-6"; display_name = "Claude Sonnet 4.6"; max_tokens = 200000; }
              { name = "claude-sonnet-4-6-thinking"; display_name = "Claude Sonnet 4.6 Thinking"; max_tokens = 200000; }
              { name = "claude-sonnet-5"; display_name = "Claude Sonnet 5"; max_tokens = 200000; }
              { name = "claude-sonnet-5-thinking"; display_name = "Claude Sonnet 5 Thinking"; max_tokens = 200000; }
              { name = "claude-sonnet-5-5"; display_name = "Claude Sonnet 5.5"; max_tokens = 200000; }
              { name = "claude-sonnet-5-5-thinking"; display_name = "Claude Sonnet 5.5 Thinking"; max_tokens = 200000; }
              { name = "codex-auto-review"; display_name = "Codex Auto Review"; max_tokens = 200000; }
              { name = "composer-2.5"; display_name = "Composer 2.5"; max_tokens = 200000; }
              { name = "gpt-5.4"; display_name = "GPT 5.4"; max_tokens = 272000; }
              { name = "gpt-5.4-mini"; display_name = "GPT 5.4 Mini"; max_tokens = 272000; }
              { name = "gpt-5.5"; display_name = "GPT 5.5"; max_tokens = 272000; }
              { name = "gpt-5.6-sol"; display_name = "GPT 5.6 Sol"; max_tokens = 272000; }
              { name = "gpt-5.6-sol-openai-compact"; display_name = "GPT 5.6 Sol Compact"; max_tokens = 272000; }
              { name = "gpt-5.6-terra"; display_name = "GPT 5.6 Terra"; max_tokens = 272000; }
              { name = "gpt-5.6-terra-openai-compact"; display_name = "GPT 5.6 Terra Compact"; max_tokens = 272000; }
              { name = "gpt-6-astra"; display_name = "GPT 6 Astra"; max_tokens = 272000; }
              { name = "gpt-6-luna"; display_name = "GPT 6 Luna"; max_tokens = 272000; }
              { name = "gpt-6-sol"; display_name = "GPT 6 Sol"; max_tokens = 272000; }
              { name = "gpt-6.1-sol"; display_name = "GPT 6.1 Sol"; max_tokens = 272000; }
              { name = "gpt-6.1-terra"; display_name = "GPT 6.1 Terra"; max_tokens = 272000; }
              { name = "gpt-image-2"; display_name = "GPT Image 2"; max_tokens = 32000; }
              { name = "gpt-image-2.5"; display_name = "GPT Image 2.5"; max_tokens = 32000; }
              { name = "grok-4.5"; display_name = "Grok 4.5"; max_tokens = 131072; }
              { name = "grok-4.6"; display_name = "Grok 4.6"; max_tokens = 131072; }
              { name = "grok-4.7"; display_name = "Grok 4.7"; max_tokens = 131072; }
              { name = "kimi-k3"; display_name = "Kimi K3"; max_tokens = 131072; }
              { name = "musk-4.5"; display_name = "Musk 4.5"; max_tokens = 131072; }
            ];
          };

          bytecatcode = {
            api_url = "https://bytecat.lamclod.cn/v1";
            available_models = [
              { name = "claude-haiku-4-5-20251001"; display_name = "ByteCat Claude Haiku 4.5"; max_tokens = 200000; }
              { name = "claude-opus-4-6"; display_name = "ByteCat Claude Opus 4.6"; max_tokens = 200000; }
              { name = "claude-opus-4-7"; display_name = "ByteCat Claude Opus 4.7"; max_tokens = 200000; }
              { name = "claude-opus-4-8"; display_name = "ByteCat Claude Opus 4.8"; max_tokens = 200000; }
              { name = "claude-sonnet-4-6"; display_name = "ByteCat Claude Sonnet 4.6"; max_tokens = 200000; }
            ];
          };
        };
      };
    };
  };

  home.sessionVariables = {
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
    DEEPSEEK_API_KEY = env.deepseekApiKey or "";
    BIGBIGDOG_API_KEY = env.bigbigdogApiKey or "";
    BYTECATCODE_API_KEY = env.bytekatApiKey or "";
  };

  programs.fish.shellAliases.zed = "${config.programs.zed-editor.package}/bin/zeditor";
  home.file.".local/bin/zed".source = "${config.programs.zed-editor.package}/bin/zed";

  home.file.".local/bin/zeditor" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec zed "$@"
    '';
  };

  home.file.".local/bin/zed-server" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec zed --foreground "$@"
    '';
  };

  xdg.dataFile."applications/zed.desktop".source = ./zed.desktop;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = "zed.desktop";
      "application/x-zerosize" = "zed.desktop";
      "application/json" = "zed.desktop";
      "application/xml" = "zed.desktop";
      "application/x-yaml" = "zed.desktop";
      "application/yaml" = "zed.desktop";
      "application/toml" = "zed.desktop";
      "text/xml" = "zed.desktop";
      "text/csv" = "zed.desktop";
      "text/tab-separated-values" = "zed.desktop";
      "text/html" = "zed.desktop";
      "text/css" = "zed.desktop";
      "text/javascript" = "zed.desktop";
      "application/javascript" = "zed.desktop";
      "application/x-javascript" = "zed.desktop";
      "application/xhtml+xml" = "zed.desktop";
      "application/x-httpd-php" = "zed.desktop";
      "text/x-python" = "zed.desktop";
      "text/x-python3" = "zed.desktop";
      "text/x-script.python" = "zed.desktop";
      "text/x-csrc" = "zed.desktop";
      "text/x-chdr" = "zed.desktop";
      "text/x-c++src" = "zed.desktop";
      "text/x-c++hdr" = "zed.desktop";
      "text/x-java" = "zed.desktop";
      "text/x-go" = "zed.desktop";
      "text/x-rust" = "zed.desktop";
      "text/x-lua" = "zed.desktop";
      "text/x-ruby" = "zed.desktop";
      "text/x-perl" = "zed.desktop";
      "text/x-haskell" = "zed.desktop";
      "text/x-kotlin" = "zed.desktop";
      "text/x-scala" = "zed.desktop";
      "text/x-swift" = "zed.desktop";
      "text/x-dart" = "zed.desktop";
      "text/typescript" = "zed.desktop";
      "text/x-typescript" = "zed.desktop";
      "application/x-typescript" = "zed.desktop";
      "text/x-shellscript" = "zed.desktop";
      "application/x-shellscript" = "zed.desktop";
      "text/x-sh" = "zed.desktop";
      "text/x-makefile" = "zed.desktop";
      "text/x-cmake" = "zed.desktop";
      "text/x-dockerfile" = "zed.desktop";
      "application/x-nix" = "zed.desktop";
      "text/x-nix" = "zed.desktop";
      "text/markdown" = "zed.desktop";
      "text/x-markdown" = "zed.desktop";
      "text/x-tex" = "zed.desktop";
      "text/x-log" = "zed.desktop";
      "text/x-diff" = "zed.desktop";
      "text/x-patch" = "zed.desktop";
      "application/x-desktop" = "zed.desktop";
      "application/sql" = "zed.desktop";
      "text/x-sql" = "zed.desktop";
      "x-scheme-handler/zed" = "zed.desktop";
      "x-scheme-handler/http" = "com.google.Chrome.desktop";
      "x-scheme-handler/https" = "com.google.Chrome.desktop";
    };
  };

  xdg.configFile."zed/themes/moss-fern.json".text = builtins.toJSON mossFernTheme;
}
