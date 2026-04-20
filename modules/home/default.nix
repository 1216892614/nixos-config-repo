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
  ];

  home.username = "ep-o1";
  home.homeDirectory = "/home/ep-o1";
  home.stateVersion = "24.11";

  home.sessionVariables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.wayland.dev}/lib/pkgconfig";
  };

  home.packages = with pkgs; [
    google-chrome
    code-cursor
    gemini-cli
    cc-switch
    codex
    opencode
    claude-code
    docker-buildx
    wl-clipboard
    wtype       # simulate keypress for walker clipboard paste
    cliphist
    uv  # provides uvx for running Python tools (e.g. astrbot)
    wechat  # nixpkgs package, https://mynixos.com/nixpkgs/package/wechat
    qq      # nixpkgs package, https://mynixos.com/nixpkgs/package/qq
    qqmusic
  ];

  # Claude Code / Codex / Gemini / OpenCode providers: managed by CC Switch (~/.cc-switch).

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
  };

  gtk = {
    enable = true;
    theme = {
      name = "gruvbox-dark";
      package = pkgs.gruvbox-dark-gtk;
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

  # fcitx5/Rime: 用户服务 + 失败重启，避免运行一段时间后输入法挂掉
  systemd.user.services.fcitx5 = {
    Unit = {
      Description = "Fcitx5 input method (Rime)";
      After = [ "graphical-session.target" "dbus-update-activation-environment.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/fcitx5";
      Restart = "on-failure";
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

   # CC Switch: wrapper so launch from Walker gets WAYLAND_DISPLAY etc.; fallbacks if session env is stale
  # NOTE: IM/GDK env overrides are now baked into the cc-switch overlay (symlinkJoin + makeWrapper),
  # so this wrapper only needs to ensure Wayland display is set for Walker launches.
  home.file.".local/bin/cc-switch-wrapper".text = ''
    #!/bin/sh
    if command -v systemctl >/dev/null 2>&1; then
      for line in $(systemctl --user show-environment 2>/dev/null); do
        case "$line" in *=*) export "$line" ;; esac
      done 2>/dev/null || true
    fi
    # 若 systemd 用户环境里没有 Wayland，用常见回退（避免运行一段时间后从 Walker 启动失败）
    : "''${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
    export XDG_RUNTIME_DIR
    if [ -z "$WAYLAND_DISPLAY" ] && [ -S "$XDG_RUNTIME_DIR/wayland-1" ]; then
      export WAYLAND_DISPLAY=wayland-1
    fi
    if [ -z "$WAYLAND_DISPLAY" ] && [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
      export WAYLAND_DISPLAY=wayland-0
    fi
    exec ${pkgs.cc-switch}/bin/cc-switch "$@"
  '';
  home.file.".local/bin/cc-switch-wrapper".executable = true;

  # CC Switch: desktop entry for Walker
  xdg.dataFile."applications/cc-switch.desktop".text = ''
    [Desktop Entry]
    Name=CC Switch
    Comment=Manage Claude Code, Codex, Gemini CLI, OpenCode providers
    Exec=${config.home.homeDirectory}/.local/bin/cc-switch-wrapper
    Terminal=false
    Type=Application
    Categories=Settings;Utility;
    Keywords=cc-switch;claude;codex;gemini;opencode;ai;
  '';

  # Steam: wrapper with /bin/sh; load systemd user env so launch from Walker (Elephant) gets WAYLAND_DISPLAY etc.
  home.file.".local/bin/steam-wrapper".text = ''
    #!/bin/sh
    if command -v systemctl >/dev/null 2>&1; then
      for line in $(systemctl --user show-environment 2>/dev/null); do
        case "$line" in *=*) export "$line" ;; esac
      done 2>/dev/null || true
    fi
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

  # X Minecraft Launcher (Flatpak): desktop entry so Walker shows it; run "flatpak install -y flathub app.xmcl.voxelum" once if not installed.
  xdg.dataFile."applications/app.xmcl.voxelum.desktop".text = ''
    [Desktop Entry]
    Name=X Minecraft Launcher
    Comment=Minecraft launcher with modpack support (Fabric, Forge, Quilt)
    Exec=${pkgs.flatpak}/bin/flatpak run --branch=stable --arch=x86_64 --file-forwarding app.xmcl.voxelum @@u %U @@
    Terminal=false
    Type=Application
    Icon=app.xmcl.voxelum
    Categories=Game;
    Keywords=minecraft;launcher;mod;
    X-Flatpak=app.xmcl.voxelum
  '';
  home.file.".local/bin/xmcl".text = ''
    #!/usr/bin/env bash
    exec ${pkgs.flatpak}/bin/flatpak run --branch=stable --arch=x86_64 --file-forwarding app.xmcl.voxelum "$@"
  '';
  home.file.".local/bin/xmcl".executable = true;

  # QQ (nixpkgs): desktop entry so Walker shows it; absolute Exec path.
  xdg.dataFile."applications/qq.desktop".text = ''
    [Desktop Entry]
    Name=QQ
    Name[zh_CN]=QQ
    Exec=${pkgs.qq}/bin/qq --enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer --ozone-platform-hint=auto --enable-wayland-ime=true --wayland-text-input-version=3 %U
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

  home.file.".config/noctalia/wallpaper.png".source = ../../wallpaper.png;
  home.file.".cache/noctalia/wallpapers.json".text = builtins.toJSON {
    defaultWallpaper = "${config.home.homeDirectory}/.config/noctalia/wallpaper.png";
  };

  programs.home-manager.enable = true;
}
