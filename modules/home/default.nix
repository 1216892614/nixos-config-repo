{ config, lib, pkgs, inputs, ... }:

let
  env = if builtins.pathExists ../../env.nix then import ../../env.nix else {};
  w11CursorTheme = pkgs.runCommand "w11-cc-v2.2-dark-default-wayland" {} ''
    mkdir -p $out/share/icons
    cp -R "${inputs.self}/icons/W11-CC-V2.2-Dark-Default-wayland" "$out/share/icons/W11-CC-V2.2-Dark-Default-wayland"
  '';
in
{
  imports = [
    ./desktop/niri.nix
    ./desktop/clash-verge.nix
    ./desktop/noctalia.nix
    ./desktop/walker.nix
    ./shell/fish.nix
    ./dev/git.nix
    ./dev/cursor.nix
    ./dev/languages.nix
    ./terminal.nix
    ./zellij.nix
    ./yazi.nix
    ./recording.nix
    ./rime-custom.nix
    ./opencode-lark.nix
  ];

  home.username = "ep-o1";
  home.homeDirectory = "/home/ep-o1";
  home.stateVersion = "24.11";

  home.sessionVariables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.wayland.dev}/lib/pkgconfig";
    NOTION_TOKEN = env.notionToken or "";
  };

  home.packages = with pkgs; [
    (callPackage ../../pkgs/lark.nix {})
    google-chrome
    rustdesk-flutter
    gemini-cli
    codex
    opencode
    claude-code
    docker-buildx
    brightnessctl   # backlight control for laptop fn keys
    playerctl       # MPRIS media player control for fn keys
    wl-clipboard
    xclip           # X11 clipboard access for clipsync bridge
    clipnotify      # X11 clipboard change notifications for clipsync
    clipsync        # bidirectional X11↔Wayland clipboard bridge
    wtype       # simulate keypress for walker clipboard paste
    cliphist
    uv  # provides uvx for running Python tools (e.g. astrbot)
    fastfetch
    wechat  # nixpkgs package, https://mynixos.com/nixpkgs/package/wechat
    qq      # nixpkgs package, https://mynixos.com/nixpkgs/package/qq
    qqmusic
  ];

  # Claude Code / Codex / Gemini / OpenCode providers: configured manually.

  # ── OpenCode: opencode.json + oh-my-openagent.json ──────────────────────
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    permission = "allow";
    model = "bigbigdog/claude-opus-4-6";
    small_model = "deepseek/deepseek-v4-pro";
    plugin = [ "oh-my-openagent" ];
    theme = "catppuccin";
    provider = {
      bytecatcode = {
        models = {
          "claude-opus-4-8" = { name = "claude-opus-4-8"; };
          "claude-opus-4-7" = { name = "claude-opus-4-7"; };
          "claude-opus-4-6" = { name = "claude-opus-4-6"; };
        };
        npm = "@ai-sdk/anthropic";
        options = {
          apiKey = env.opencodeBytekatApiKey or "";
          baseURL = "https://bytecat.lamclod.cn/v1";
        };
      };
      "bytecatcode-cn" = {
        models = {
          "GLM-5.1" = { name = "glm-5.1"; };
        };
        npm = "@ai-sdk/anthropic";
        options = {
          apiKey = env.opencodeBytekatCnApiKey or "";
          baseURL = "https://bytecat.lamclod.cn/v1";
        };
      };
      bigbigdog = {
        npm = "@ai-sdk/openai-compatible";
        name = "BigBigDog (OpenAI-compatible)";
        options = {
          apiKey = env.opencodeBigbigdogApiKey or "";
          baseURL = "https://www.dogapi.cc/v1";
        };
        models = {
          "claude-opus-4-8" = { name = "claude-opus-4-8"; };
          "claude-opus-4-7" = { name = "claude-opus-4-7"; };
          "claude-opus-4-6" = { name = "claude-opus-4-6"; };
          "gpt-5.3-codex" = { name = "gpt-5.3-codex"; };
          "gpt-5.4" = { name = "gpt-5.4"; };
          "gpt-5.4-mini" = { name = "gpt-5.4-mini"; };
          "gpt-5.5" = { name = "gpt-5.5"; };
          "gpt-5.3-codex-spark" = { name = "gpt-5.3-codex-spark"; };
          "gemini-3-flash" = { name = "gemini-3-flash"; };
          "gemini-3.1-flash-lite" = { name = "gemini-3.1-flash-lite"; };
          "gemini-3.1-flash-lite-preview" = { name = "gemini-3.1-flash-lite-preview"; };
          "gemini-3.1-pro-preview" = { name = "gemini-3.1-pro-preview"; };
        };
      };
      deepseek = {
        npm = "@ai-sdk/openai-compatible";
        name = "DeepSeek";
        options = {
          apiKey = env.opencodeDeepseekApiKey or "";
          baseURL = "https://api.deepseek.com/v1";
        };
        models = {
          "deepseek-v4-pro" = { name = "deepseek-v4-pro"; };
          "DeepSeek-V4-Pro" = { name = "deepseek-v4-pro"; };
        };
      };
    };
  };

  xdg.configFile."opencode/oh-my-openagent.json".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    agents = {
      hephaestus = { model = "bigbigdog/gpt-5.5"; };
      oracle = { model = "deepseek/deepseek-v4-pro"; };
      librarian = { model = "deepseek/deepseek-v4-pro"; };
      explore = { model = "deepseek/deepseek-v4-pro"; };
      multimodal-looker = { model = "bigbigdog/claude-opus-4-6"; };
      prometheus = { model = "bigbigdog/claude-opus-4-6"; };
      metis = { model = "bigbigdog/claude-opus-4-6"; };
      momus = { model = "bigbigdog/claude-opus-4-6"; };
      atlas = { model = "bigbigdog/claude-opus-4-6"; };
    };
    categories = {
      visual-engineering = { model = "bigbigdog/claude-opus-4-6"; };
      ultrabrain = { model = "deepseek/deepseek-v4-pro"; };
      deep = { model = "bigbigdog/gpt-5.5"; };
      artistry = { model = "deepseek/deepseek-v4-pro"; };
      quick = { model = "deepseek/deepseek-v4-pro"; };
      unspecified-low = { model = "deepseek/deepseek-v4-pro"; };
      unspecified-high = { model = "deepseek/deepseek-v4-pro"; };
      writing = { model = "deepseek/deepseek-v4-pro"; };
    };
  };

  # Disabled: replaced by modules/nixos/apfs-automount.nix which handles
  # all external FS types (APFS, NTFS, exFAT, ext4, etc.) with unified naming
  # services.udiskie = {
  #   enable = true;
  #   automount = true;
  #   notify = true;
  #   tray = "auto";
  # };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    cursorTheme = {
      name = "W11-CC-V2.2-Dark-Default-wayland";
      package = w11CursorTheme;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  home.pointerCursor = {
    name = "W11-CC-V2.2-Dark-Default-wayland";
    package = w11CursorTheme;
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  # fcitx5/Rime: 用户服务 + 无条件重启，避免运行一段时间后输入法挂掉或卡死
  systemd.user.services.fcitx5 = {
    Unit = {
      Description = "Fcitx5 input method (Rime)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'until [ -n \"$WAYLAND_DISPLAY\" ]; do sleep 0.2; done'";
      ExecStart = "/run/current-system/sw/bin/fcitx5";
      Restart = "always";
      RestartSec = "3";
      Environment = "QT_IM_MODULE=fcitx SDL_IM_MODULE=fcitx INPUT_METHOD=fcitx XMODIFIERS=@im=fcitx";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.cliphist-text = {
    Unit = {
      Description = "Clipboard history for text";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.cliphist-image = {
    Unit = {
      Description = "Clipboard history for images";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # clipsync: 双向剪贴板桥接（X11↔Wayland），替代 wl-clip-persist
  # X11 app（QQ/WeChat/Steam）的复制操作通过此服务同步到 Wayland 端（cliphist 自动收录）
  systemd.user.services.clipsync = {
    Unit = {
      Description = "Bidirectional clipboard bridge (X11 ↔ Wayland)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.clipsync}/bin/clipsync";
      Restart = "on-failure";
      RestartSec = "3";
      Environment = "DISPLAY=:0";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Figma Agent: serves local fonts to Figma web client (localhost:44950)
  # NOTE: Figma 网页版检测到 Linux UA 会跳过 font helper 请求，
  #       需要将浏览器 User-Agent 伪装为 Windows 才能生效。
  xdg.configFile."figma-agent/config.json".text = builtins.toJSON {
    use_system_fonts = true;
    font_directories = [
      "~/.local/share/fonts"
    ];
  };

  systemd.user.services.figma-agent = {
    Unit = {
      Description = "Figma Agent — local font service";
      After = [ "default.target" ];
    };
    Service = {
      ExecStart = "${pkgs.figma-agent-linux}/bin/figma-agent";
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Chrome: 默认启用垂直标签栏（仅首次 seed，不覆盖用户后续修改）
  home.activation.seedChromeVerticalTabs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    prefs_file="${config.home.homeDirectory}/.config/google-chrome/Default/Preferences"
    if [ -f "$prefs_file" ]; then
      if ! ${pkgs.python3}/bin/python3 -c "
import json, sys
with open('$prefs_file') as f:
    p = json.load(f)
if p.get('tab_strip', {}).get('tab_strip_layout_type') is not None:
    sys.exit(1)
p.setdefault('tab_strip', {})['tab_strip_layout_type'] = 1
with open('$prefs_file', 'w') as f:
    json.dump(p, f)
"; then
        echo "chrome: vertical tabs already configured, skipping"
      else
        echo "chrome: enabled vertical tabs (tab_strip_layout_type=1)"
      fi
    else
      run mkdir -p "$(dirname "$prefs_file")"
      echo '{"tab_strip":{"tab_strip_layout_type":1}}' > "$prefs_file"
      echo "chrome: created Preferences with vertical tabs enabled"
    fi
  '';

  # Symlink ~/.local/share/fonts → system font dir so apps with hardcoded
  # font paths (RustDesk fontdb, etc.) can find CJK fonts on NixOS
  home.activation.linkFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    fonts_dir="${config.home.homeDirectory}/.local/share/fonts"
    target="/run/current-system/sw/share/X11/fonts"
    if [ -L "$fonts_dir" ]; then
      current=$(readlink "$fonts_dir")
      if [ "$current" != "$target" ]; then
        rm "$fonts_dir"
        ln -s "$target" "$fonts_dir"
      fi
    elif [ ! -e "$fonts_dir" ]; then
      mkdir -p "$(dirname "$fonts_dir")"
      ln -s "$target" "$fonts_dir"
    else
      echo "Warning: $fonts_dir exists and is not a symlink, skipping"
    fi
  '';

  # AstrBot: Agentic IM chatbot (https://astrbot.app/, https://github.com/AstrBotDevs/AstrBot); run via uvx (first run may install)
  home.file.".local/bin/astrbot".text = ''
    #!/usr/bin/env bash
    exec "${pkgs.uv}/bin/uvx" astrbot "''$@"
  '';
  home.file.".local/bin/astrbot".executable = true;

  home.file.".local/bin/omo-server".text = ''
    #!/usr/bin/env bash
    set -euo pipefail
    port="''${1:?missing port}"
    cwd="''${2:?missing cwd}"
    cd "$cwd"
    exec opencode serve --hostname 127.0.0.1 --port "$port"
  '';
  home.file.".local/bin/omo-server".executable = true;

  home.file.".local/bin/omo-client".text = ''
    #!/usr/bin/env bash
    set -euo pipefail

    port="''${1:?missing port}"
    cwd="''${2:?missing cwd}"
    url="http://127.0.0.1:$port"
    health="$url/global/health"

    for _ in $(seq 1 150); do
      if wget -qO- "$health" >/dev/null 2>&1; then
        cd "$cwd"
        exec opencode attach "$url" --dir "$cwd"
      fi
      sleep 0.2
    done

    echo "omo: timed out waiting for $health" >&2
    exit 1
  '';
  home.file.".local/bin/omo-client".executable = true;

  home.file.".local/bin/omo-supervisor".text = ''
    #!/usr/bin/env bash
    set -euo pipefail

    port="''${1:?missing port}"
    cwd="''${2:?missing cwd}"
    server_pid=""

    cleanup() {
      if [ -n "$server_pid" ] && kill -0 "$server_pid" >/dev/null 2>&1; then
        kill "$server_pid" >/dev/null 2>&1 || true
        wait "$server_pid" 2>/dev/null || true
      fi
      if [ -n "''${ZELLIJ:-}" ]; then
        zellij action quit >/dev/null 2>&1 || true
      fi
    }

    trap cleanup EXIT INT TERM

    "${config.home.homeDirectory}/.local/bin/omo-server" "$port" "$cwd" &
    server_pid=$!

    "${config.home.homeDirectory}/.local/bin/omo-client" "$port" "$cwd"
  '';
  home.file.".local/bin/omo-supervisor".executable = true;

  home.file.".local/bin/omo-launch".text = ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "$#" -ne 0 ]; then
      echo "usage: omo" >&2
      exit 1
    fi

    for cmd in zellij mktemp ss awk grep; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "omo: required command not found: $cmd" >&2
        exit 127
      fi
    done

    cwd="$PWD"
    helper_dir="${config.home.homeDirectory}/.local/bin"
    for helper in "$helper_dir/omo-server" "$helper_dir/omo-client" "$helper_dir/omo-supervisor"; do
      if [ ! -x "$helper" ]; then
        echo "omo: helper not found or not executable: $helper" >&2
        exit 1
      fi
    done

    layout_file="$(mktemp /tmp/omo-layout-XXXXXX.kdl)"
    cleanup() {
      rm -f "$layout_file"
    }
    trap cleanup EXIT

    find_port() {
      local candidate
      for _ in $(seq 1 200); do
        candidate="$(shuf -i 20000-65000 -n 1)"
        if ! ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$candidate$"; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      return 1
    }

    port="$(find_port)" || {
      echo "omo: failed to find a free TCP port" >&2
      exit 1
    }

    OMO_CWD="$cwd" OMO_PORT="$port" OMO_HOME="${config.home.homeDirectory}" "${pkgs.python3}/bin/python3" - <<'PY' >"$layout_file"
import os

cwd = os.environ["OMO_CWD"]
port = os.environ["OMO_PORT"]
home = os.environ["OMO_HOME"]

client = f'{home}/.local/bin/omo-client'
supervisor = f'{home}/.local/bin/omo-supervisor'

def q(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

print("layout {")
print("    default_tab_template {")
print('        pane size=1 borderless=true {')
print('            plugin location="zellij:tab-bar"')
print("        }")
print("        children")
print('        pane size=1 borderless=true {')
print('            plugin location="zellij:status-bar"')
print("        }")
print("    }")
print(f'    tab name="omo" focus=true cwd={q(cwd)} {{')
print('        pane split_direction="horizontal" {')
print('            pane split_direction="vertical" {')
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print("            }")
print('            pane split_direction="vertical" {')
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print("            }")
print("        }")
print("    }")
print(f'    tab name="fish" cwd={q(cwd)} {{')
print('        pane split_direction="horizontal" {')
print('            pane split_direction="vertical" {')
print(f'                pane command={q(supervisor)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print("            }")
print('            pane split_direction="vertical" {')
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print("                pane")
print("            }")
print("        }")
print("    }")
print("}")
PY

    command zellij --layout "$layout_file"
  '';
  home.file.".local/bin/omo-launch".executable = true;

  home.file.".local/bin/lo-launch".text = ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "$#" -ne 1 ]; then
      echo "usage: lo <cols>x<rows>" >&2
      exit 1
    fi

    spec="$1"
    if [[ ! "$spec" =~ ^([1-9][0-9]*)x([1-9][0-9]*)$ ]]; then
      echo "lo: invalid layout spec: $spec" >&2
      echo "usage: lo <cols>x<rows>" >&2
      exit 1
    fi

    for cmd in zellij mktemp; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "lo: required command not found: $cmd" >&2
        exit 127
      fi
    done

    cols="''${BASH_REMATCH[1]}"
    rows="''${BASH_REMATCH[2]}"
    cwd="$PWD"
    layout_file="$(mktemp /tmp/lo-layout-XXXXXX.kdl)"
    cleanup() {
      rm -f "$layout_file"
    }
    trap cleanup EXIT

    LO_CWD="$cwd" LO_COLS="$cols" LO_ROWS="$rows" "${pkgs.python3}/bin/python3" - <<'PY' >"$layout_file"
import os

cwd = os.environ["LO_CWD"]
cols = int(os.environ["LO_COLS"])
rows = int(os.environ["LO_ROWS"])

def q(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

def emit_grid(indent: str, cols: int, rows: int) -> None:
    print(f'{indent}pane split_direction="horizontal" {{')
    for _ in range(cols):
        print(f'{indent}    pane split_direction="vertical" {{')
        for _ in range(rows):
            print(f"{indent}        pane")
        print(f'{indent}    }}')
    print(f'{indent}}}')

print("layout {")
print("    default_tab_template {")
print('        pane size=1 borderless=true {')
print('            plugin location="zellij:tab-bar"')
print("        }")
print("        children")
print('        pane size=1 borderless=true {')
print('            plugin location="zellij:status-bar"')
print("        }")
print("    }")
print(f'    tab focus=true cwd={q(cwd)} {{')
emit_grid("        ", cols, rows)
print("    }")
print("}")
PY

    if [ -n "''${ZELLIJ:-}" ]; then
      command zellij action new-tab --layout "$layout_file" --cwd "$cwd"
    else
      command zellij --layout "$layout_file"
    fi
  '';
  home.file.".local/bin/lo-launch".executable = true;

  # Steam: wrapper with /bin/sh; load systemd user env so launch from Walker (Elephant) gets WAYLAND_DISPLAY etc.
  #
  # X11 fallback rationale:
  #   On long-lived niri sessions the primary Xwayland (:0) accumulates X11
  #   clients (each browser tab, IM, IDE, tray app, etc. opens 1+ X
  #   connections; even a casual session can push past 200). The X server has
  #   a hard cap of MAXCLIENTS = 256 client slots per server. When Steam
  #   launches it spawns ~10–20 helpers (srt-logger, breakpad, webhelper,
  #   pressure-vessel, fossilize, overlay), each of which opens an X
  #   connection. If that pushes the count over 256 the X server returns
  #   "Maximum number of clients reached" and Steam aborts during init with
  #   the misleading XOpenIM() failure + breakpad assert.
  #
  # niri starts a *second* Xwayland on :1 specifically as a spare. We probe
  # :0 first; if it's near saturation we transparently switch DISPLAY to :1
  # so Steam gets a fresh client budget. Steam UI still renders on the niri
  # Wayland compositor regardless of which Xwayland it talks to.
  home.file.".local/bin/steam-wrapper".text = ''
    #!/bin/sh
    if command -v systemctl >/dev/null 2>&1; then
      for line in $(systemctl --user show-environment 2>/dev/null); do
        case "$line" in *=*) export "$line" ;; esac
      done 2>/dev/null || true
    fi

    # If DISPLAY=:0 is close to MAXCLIENTS (256), fall back to :1 (niri's
    # spare Xwayland). Threshold is conservative: Steam itself opens ~20
    # connections during init, so leave that headroom.
    pick_display() {
      [ -z "$DISPLAY" ] && return
      sock=/tmp/.X11-unix/X1
      [ -S "$sock" ] || return  # no spare available
      cur=$(ss -x 2>/dev/null | grep -c "/tmp/\.X11-unix/X0")
      if [ -n "$cur" ] && [ "$cur" -ge 230 ]; then
        echo "[steam-wrapper] DISPLAY=:0 has $cur X clients (cap 256); switching to :1" >&2
        DISPLAY=:1
        export DISPLAY
      fi
    }
    pick_display

    # Ensure we run NixOS Steam (programs.steam) so extraPackages/fonts are present.
    exec /run/current-system/sw/bin/steam "$@"
  '';
  home.file.".local/bin/steam-wrapper".executable = true;
  xdg.dataFile."applications/steam.desktop".text =
    builtins.replaceStrings
      [ "Exec=steam" ]
      [ "Exec=${config.home.homeDirectory}/.local/bin/steam-wrapper" ]
      (builtins.readFile "${pkgs.steam}/share/applications/steam.desktop");

  # Steam follows per-user fontconfig; force strong CJK fallbacks.
  xdg.configFile."fontconfig/conf.d/99-steam-cjk.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <alias>
        <family>sans-serif</family>
        <prefer>
          <family>WenQuanYi Zen Hei</family>
          <family>Sarasa UI SC</family>
          <family>Source Han Sans SC</family>
        </prefer>
      </alias>

      <alias>
        <family>serif</family>
        <prefer>
          <family>Source Han Serif SC</family>
          <family>Sarasa UI SC</family>
          <family>WenQuanYi Zen Hei</family>
        </prefer>
      </alias>

      <match target="pattern">
        <test name="family" compare="eq">
          <string>Arial</string>
        </test>
        <edit name="family" mode="assign" binding="strong">
          <string>WenQuanYi Zen Hei</string>
        </edit>
      </match>
    </fontconfig>
  '';

  # WeChat (nixpkgs): wrapper so Walker can launch; load systemd user env for WAYLAND_DISPLAY etc.
  home.file.".local/bin/wechat-wrapper".text = ''
    #!/bin/sh
    if command -v systemctl >/dev/null 2>&1; then
      for line in $(systemctl --user show-environment 2>/dev/null); do
        case "$line" in *=*) export "$line" ;; esac
      done 2>/dev/null || true
    fi
    exec ${pkgs.wechat}/bin/wechat "$@"
  '';
  home.file.".local/bin/wechat-wrapper".executable = true;
  xdg.dataFile."applications/wechat.desktop".text = ''
    [Desktop Entry]
    Name=WeChat
    Name[zh_CN]=微信
    Exec=${config.home.homeDirectory}/.local/bin/wechat-wrapper %U
    Terminal=false
    Type=Application
    Icon=wechat
    Categories=Network;
    Keywords=wechat;weixin;微信;
    Comment=WeChat Desktop
    Comment[zh_CN]=微信桌面版
  '';

  # ── Deb 应用（rebuild 时自动解包安装，幂等） ──────────────────────────
  # 目录结构：debs/<app-name>/*.deb（子目录名即应用名，deb 文件名随意）
  # 解包到 ~/.local/opt/<app-name>/，按 sha256 幂等跳过
  home.activation.installDebs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _install_deb() {
      local name="''${1:-}"
      local src="''${2:-}"
      local dest="${config.home.homeDirectory}/.local/opt/$name"
      if [ ! -f "$src" ]; then
        echo "Deb not found: $src, skipping $name"
        return 0
      fi
      local hash_file="$dest/.deb-sha256"
      local current_hash=""
      current_hash=$(sha256sum "$src" | cut -d' ' -f1)
      if [ -f "$hash_file" ] && [ "$(cat "$hash_file")" = "$current_hash" ]; then
        echo "Deb $name: already up to date"
        return 0
      fi
      echo "Deb $name: installing..."
      rm -rf "$dest"
      mkdir -p "$dest"
      local tmp=""
      tmp=$(mktemp -d)
      ${pkgs.dpkg}/bin/dpkg-deb -x "$src" "$tmp"
      cp -a "$tmp/." "$dest/"
      rm -rf "$tmp"
      # Patch ELF binaries
      find "$dest" -type f -executable -exec sh -c '
        file "$1" | grep -q "ELF.*executable" && ${pkgs.patchelf}/bin/patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 "$1" 2>/dev/null || true
      ' _ {} \;
      echo "$current_hash" > "$hash_file"
      echo "Deb $name: installed"
    }

    DEB_REPO="${config.home.homeDirectory}/nixos-config-repo/debs"
    if [ -d "$DEB_REPO" ]; then
      for app_dir in "$DEB_REPO"/*/; do
        [ -d "$app_dir" ] || continue
        app_name="$(basename "$app_dir")"
        # 取目录下最新的 .deb 文件
        deb_file="$(ls -t "$app_dir"*.deb 2>/dev/null | head -1)"
        if [ -n "$deb_file" ]; then
          _install_deb "$app_name" "$deb_file"
        else
          echo "Deb $app_name: no .deb file found in $app_dir, skipping"
        fi
      done
    fi
  '';


  # ── AppImage 应用（rebuild 时自动解压安装，幂等） ──────────────────────
  # 源文件在仓库 appimages/ 目录，解压到 ~/.local/opt/<name>/
  # activation 脚本：比较 AppImage 的 sha256，变了才重新解压，没变跳过
  home.activation.installAppImages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _install_ai() {
      local name="''${1:-}"
      local src="''${2:-}"
      local dest="${config.home.homeDirectory}/.local/opt/$name"
      if [ ! -f "$src" ]; then
        echo "AppImage not found: $src, skipping $name"
        return 0
      fi
      local hash_file="$dest/.appimage-sha256"
      local current_hash=""
      current_hash=$(sha256sum "$src" | cut -d' ' -f1)
      if [ -f "$hash_file" ] && [ "$(cat "$hash_file")" = "$current_hash" ]; then
        echo "AppImage $name: already up to date"
        return 0
      fi
      echo "AppImage $name: installing..."
      rm -rf "$dest"
      mkdir -p "$dest"
      local tmp=""
      tmp=$(mktemp -d)
      (cd "$tmp" && "$src" --appimage-extract) >/dev/null 2>&1
      cp -a "$tmp/squashfs-root/." "$dest/"
      rm -rf "$tmp"
      echo "$current_hash" > "$hash_file"
      echo "AppImage $name: installed"
    }

    REPO="${config.home.homeDirectory}/nixos-config-repo/appimages"
    _install_ai "xmcl"      "$REPO/xmcl.AppImage"
    _install_ai "cursor"    "$REPO/cursor.AppImage"
    _install_ai "osu"       "$REPO/osu.AppImage"
    _install_ai "obsidian"  "$REPO/obsidian.AppImage"
  '';

  # Java wrapper for Minecraft: 注入 LD_LIBRARY_PATH 让 GLFW 能 dlopen 系统库，
  # 并强制 X11 绕过 niri Wayland 兼容性问题
  home.file.".local/bin/java-mc".text = ''
    #!/usr/bin/env bash
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    unset WAYLAND_DISPLAY
    export DISPLAY="''${DISPLAY:-:0}"
    exec /home/ep-o1/.minecraftx/jre/java-runtime-delta/bin/java.real "$@"
  '';
  home.file.".local/bin/java-mc".executable = true;

  # X Minecraft Launcher — bin: xmcl (Electron, root level)
  home.file.".local/bin/xmcl".text = ''
    #!/usr/bin/env bash
    exec "${config.home.homeDirectory}/.local/opt/xmcl/xmcl" --no-sandbox --ozone-platform-hint=auto "$@"
  '';
  home.file.".local/bin/xmcl".executable = true;
  xdg.dataFile."applications/xmcl.desktop".text = ''
    [Desktop Entry]
    Name=X Minecraft Launcher
    Comment=Minecraft launcher with modpack support
    Exec=${config.home.homeDirectory}/.local/bin/xmcl %U
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/xmcl/xmcl.png
    Categories=Game;
    Keywords=minecraft;launcher;mod;
  '';

  # Cursor — bin: usr/share/cursor/cursor (Electron)
  home.file.".local/bin/cursor".text = ''
    #!/usr/bin/env bash
    exec "${config.home.homeDirectory}/.local/opt/cursor/usr/share/cursor/cursor" --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime "$@"
  '';
  home.file.".local/bin/cursor".executable = true;
  xdg.dataFile."applications/cursor.desktop".text = ''
    [Desktop Entry]
    Name=Cursor
    Comment=AI Code Editor
    Exec=${config.home.homeDirectory}/.local/bin/cursor --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime %F
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/cursor/co.anysphere.cursor.png
    Categories=Development;IDE;
    Keywords=cursor;code;editor;ai;
    MimeType=text/plain;
  '';

  # osu! — bin: usr/bin/osu! (dotnet)
  home.file.".local/bin/osu".text = ''
    #!/usr/bin/env bash
    exec "${config.home.homeDirectory}/.local/opt/osu/usr/bin/osu!" "$@"
  '';
  home.file.".local/bin/osu".executable = true;
  xdg.dataFile."applications/osu.desktop".text = ''
    [Desktop Entry]
    Name=osu!
    Comment=Rhythm is just a click away
    Exec=${config.home.homeDirectory}/.local/bin/osu %U
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/osu/osu.png
    Categories=Game;
    Keywords=osu;rhythm;game;
  '';

  # Obsidian — bin: obsidian (Electron)
  home.file.".local/bin/obsidian".text = ''
    #!/usr/bin/env bash
    exec "${config.home.homeDirectory}/.local/opt/obsidian/obsidian" --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime "$@"
  '';
  home.file.".local/bin/obsidian".executable = true;
  xdg.dataFile."applications/obsidian.desktop".text = ''
    [Desktop Entry]
    Name=Obsidian
    Comment=Knowledge base and note-taking
    Exec=${config.home.homeDirectory}/.local/bin/obsidian %U
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/obsidian/obsidian.png
    Categories=Office;
    Keywords=obsidian;notes;markdown;knowledge;
    MimeType=x-scheme-handler/obsidian;
  '';

  # QQ (nixpkgs): desktop entry so Walker shows it; absolute Exec path.
  xdg.dataFile."applications/qq.desktop".text = ''
    [Desktop Entry]
    Name=QQ
    Name[zh_CN]=QQ
    Exec=${pkgs.qq}/bin/qq --enable-features=WebRTCPipeWireCapturer --ozone-platform=wayland --enable-wayland-ime %U
    Terminal=false
    Type=Application
    Icon=qq
    Comment=Tencent QQ
    Comment[zh_CN]=腾讯QQ
    Categories=Network;
    Keywords=qq;tencent;
  '';

  # QQ Music (nixpkgs): desktop entry so Walker shows it; absolute Exec path.
  xdg.dataFile."applications/qqmusic.desktop".text = ''
    [Desktop Entry]
    Name=QQ Music
    Name[zh_CN]=QQ音乐
    Exec=${pkgs.qqmusic}/bin/qqmusic %U
    Terminal=false
    Type=Application
    Icon=qqmusic
    Comment=Tencent QQMusic
    Comment[zh_CN]=QQ音乐
    Categories=AudioVideo;
  '';

  xdg.configFile."xdg-terminal-exec/termfilechooser.conf".text = ''
    cmd=${config.home.homeDirectory}/.local/bin/yazi-wrapper.sh
  '';

  home.file.".local/bin/yazi-wrapper.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      kitty --class=file_chooser -e yazi "$@" --chooser-file="$1"
    '';
  };

  home.file.".config/noctalia/wallpaper.jpeg".source = ../../wallpapers/endcard_02.jpg;
  home.file.".config/noctalia/wallpapers/endcard_02.jpg".source = ../../wallpapers/endcard_02.jpg;
  home.file.".config/noctalia/wallpapers/endcard_10.jpg".source = ../../wallpapers/endcard_10.jpg;
  home.file.".config/noctalia/wallpapers/endcard_11.jpg".source = ../../wallpapers/endcard_11.jpg;
  home.file.".cache/noctalia/wallpapers.json".text = builtins.toJSON {
    defaultWallpaper = "${config.home.homeDirectory}/.config/noctalia/wallpaper.jpeg";
  };

  programs.home-manager.enable = true;
}
