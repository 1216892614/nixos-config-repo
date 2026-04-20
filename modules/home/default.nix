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
    gemini-cli
    codex
    opencode
    claude-code
    docker-buildx
    wl-clipboard
    wl-clip-persist # 保持剪贴板内容在源应用失焦后不丢失（Wayland 剪贴板所有权模型）
    wtype       # simulate keypress for walker clipboard paste
    cliphist
    uv  # provides uvx for running Python tools (e.g. astrbot)
    wechat  # nixpkgs package, https://mynixos.com/nixpkgs/package/wechat
    qq      # nixpkgs package, https://mynixos.com/nixpkgs/package/qq
    qqmusic
  ];

  # Claude Code / Codex / Gemini / OpenCode providers: env managed by ~/.cc-switch or manual config.

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
  };

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

  # wl-clip-persist: 在源应用失焦/关闭后保持剪贴板内容，解决 Wayland 下 QQ/微信等读不到最新剪贴板的问题
  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "Keep Wayland clipboard alive after source app loses focus";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard both";
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
    _install_ai "cc-switch" "$REPO/cc-switch.AppImage"
    _install_ai "osu"       "$REPO/osu.AppImage"
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
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec "${config.home.homeDirectory}/.local/opt/xmcl/xmcl" --no-sandbox "$@"
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
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
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

  # CC Switch — bin: usr/bin/cc-switch (Electron)
  home.file.".local/bin/cc-switch".text = ''
    #!/usr/bin/env bash
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec "${config.home.homeDirectory}/.local/opt/cc-switch/usr/bin/cc-switch" --no-sandbox --ozone-platform-hint=auto --enable-wayland-ime "$@"
  '';
  home.file.".local/bin/cc-switch".executable = true;
  xdg.dataFile."applications/cc-switch.desktop".text = ''
    [Desktop Entry]
    Name=CC Switch
    Comment=AI provider switcher for Claude Code, Codex, Gemini CLI, OpenCode
    Exec=${config.home.homeDirectory}/.local/bin/cc-switch %U
    Terminal=false
    Type=Application
    Icon=${config.home.homeDirectory}/.local/opt/cc-switch/cc-switch.png
    Categories=Development;Utility;
    Keywords=cc-switch;claude;codex;gemini;opencode;ai;
    MimeType=x-scheme-handler/ccswitch;
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

  home.file.".config/noctalia/wallpaper.jpeg".source = ../../wallpaper.jpeg;
  home.file.".cache/noctalia/wallpapers.json".text = builtins.toJSON {
    defaultWallpaper = "${config.home.homeDirectory}/.config/noctalia/wallpaper.jpeg";
  };

  programs.home-manager.enable = true;
}
