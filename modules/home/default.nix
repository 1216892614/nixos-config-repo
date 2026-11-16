{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # 缺少私密配置时立即报错，避免生成空 API key 和空模型列表。
  env = if builtins.pathExists ../../env.nix then import ../../env.nix else
    throw "缺少 env.nix：请使用 fish ./scripts/rebuild.fish 或 --flake path:/home/ep-o1/nixos-config-repo#主机名 构建；Git flake 不包含未跟踪的 env.nix。";
  colors = import ../../lib/colors.nix;
  qqPackage = (import inputs.nixpkgs-qq {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  }).qq;
  w11CursorTheme = pkgs.runCommand "w11-cc-v2.2-dark-default-wayland" { } ''
    mkdir -p $out/share/icons
    cp -R "${inputs.self}/icons/W11-CC-V2.2-Dark-Default-wayland" "$out/share/icons/W11-CC-V2.2-Dark-Default-wayland"
  '';
  # WhiteSur 打包的 icon-theme.cache 是无效的（magic bytes 不对），GTK 无法解析导致图标回退到 hicolor。
  # 重新生成有效的 gtk icon cache。
  # 同时修复 Inherits 行：原始只继承 hicolor,breeze（breeze 未安装），补上 Adwaita
  # 使 Qt/GTK 能找到 symbolic 图标（如 input-keyboard-symbolic），否则系统托盘图标显示为空白/棋盘。
  whitesurIconTheme = pkgs.whitesur-icon-theme.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.gtk3 ];
    postFixup = (old.postFixup or "") + ''
      for theme in $out/share/icons/WhiteSur*; do
        if [ -f "$theme/index.theme" ]; then
          sed -i 's/^Inherits=.*/Inherits=Adwaita,hicolor/' "$theme/index.theme"
          gtk-update-icon-cache --force --quiet "$theme"
        fi
      done
    '';
  });

  # ── 统一 MCP 服务器定义（cursor / opencode / omp 共用）──────────────────
  mcpServers = {
    context7 = {
      url = "https://mcp.context7.com/mcp";
      headers = { "x-api-key" = env.context7ApiKey or ""; };
    };
    # nixpkgs 自带 mcp-nixos；不用 `nix run github:` 以免启动时撞 GitHub API 限流
    nixos = {
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
    rust-docs = {
      command = "${config.home.homeDirectory}/.cargo/bin/rust-docs-mcp";
    };
    # 连接正在运行的 Chrome（含登录态）；配合 page-share 扩展使用。
    # 前提：Chrome 中打开 chrome://inspect/#remote-debugging 勾选允许远程调试（一次性）
    chrome-devtools = {
      command = "${pkgs.nodejs}/bin/npx";
      args = [ "-y" "chrome-devtools-mcp@1.12.0" "--autoConnect" ];
    };
    # 本地 ComfyUI MCP（comfy-mcp stdio → Docker 容器内 ComfyUI）
    comfyui = {
      command = "${pkgs.uv}/bin/uvx";
      args = [ "comfy-mcp" ];
      env = {
        COMFYUI_URL = "http://127.0.0.1:8188";
        COMFY_BIN = "${pkgs.writeShellScript "comfy-cli-wrapper" ''
          exec ${pkgs.uv}/bin/uvx --from comfy-cli comfy "$@"
        ''}";
      };
    };
  };
in
{
  _module.args = { inherit env colors mcpServers; };

  imports = (import ../../lib/app-modules.nix (./. + "/apps")) ++ [
    ./dev/git.nix
    ./dev/languages.nix
    ./terminal.nix
    ./recording.nix
  ];

  home.username = "ep-o1";
  home.homeDirectory = "/home/ep-o1";
  home.stateVersion = "24.11";
  home.enableNixpkgsReleaseCheck = false; # nixos-unstable 始终领先 HM release 周期

  home.sessionVariables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.wayland.dev}/lib/pkgconfig";
    NOTION_TOKEN = env.notionToken or "";
    QT_ICON_THEME = "WhiteSur-dark";
  };

  home.packages = with pkgs; [
    google-chrome
    rustdesk-flutter
    codex
    opencode
    omp
    docker-buildx
    brightnessctl # backlight control for laptop fn keys
    playerctl # MPRIS media player control for fn keys
    wl-clipboard
    xclip # X11 clipboard access for clipsync bridge
    clipnotify # X11 clipboard change notifications for clipsync
    clipsync # bidirectional X11↔Wayland clipboard bridge
    clippaste # smart clipboard paste (text via wtype stdin, image via shortcut)
    cliphist
    uv # provides uvx for running Python tools (e.g. astrbot)
    fastfetch
    wechat # nixpkgs package, https://mynixos.com/nixpkgs/package/wechat
    qqPackage # QQ from isolated nixpkgs
    qqmusic
    telegram-desktop
    # ── 文档阅读 ──
    foliate # PDF / EPUB / DjVu / CBR / FB2 / MOBI 阅读器
    (callPackage ../../pkgs/doxx.nix { }) # 终端 DOCX 查看器 (doxx file.docx)
    ghostscript # AI/PDF/PS 文件渲染（ImageMagick delegate）
    evince # PS/EPS/AI 文档查看器（通过 Ghostscript 渲染）
    # ── 图片查看 ──
    imv # Wayland 原生轻量图片查看器
    # ── 云存储 ──
    rclone # 多云存储挂载/同步（OneDrive, GDrive 等）
    # ── 游戏 Mod ──
    r2modman # Thunderstore mod manager（管理 Steam 游戏 mod）
    protontricks # Proton Wine prefix 工具（为 mod 设置 winhttp DLL override 等）
  ];

  # ── 文档格式 MIME 关联 ──
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # imv: 图片
      "image/png" = "imv-dir.desktop";
      "image/jpeg" = "imv-dir.desktop";
      "image/gif" = "imv-dir.desktop";
      "image/webp" = "imv-dir.desktop";
      "image/bmp" = "imv-dir.desktop";
      "image/svg+xml" = "imv-dir.desktop";
      # Foliate: 电子书 + PDF
      "application/pdf" = "com.github.johnfactotum.Foliate.desktop";
      "application/epub+zip" = "com.github.johnfactotum.Foliate.desktop";
      "image/vnd.djvu" = "com.github.johnfactotum.Foliate.desktop";
      "application/x-mobipocket-ebook" = "com.github.johnfactotum.Foliate.desktop";
      "application/x-cbr" = "com.github.johnfactotum.Foliate.desktop";
      "application/x-cbz" = "com.github.johnfactotum.Foliate.desktop";
      "application/x-cb7" = "com.github.johnfactotum.Foliate.desktop";
      "application/x-fb2+xml" = "com.github.johnfactotum.Foliate.desktop";
      # Evince: PostScript / EPS / Adobe Illustrator（通过 Ghostscript 渲染）
      "application/postscript" = "org.gnome.Evince.desktop";
      "application/eps" = "org.gnome.Evince.desktop";
      "application/x-eps" = "org.gnome.Evince.desktop";
      "image/x-eps" = "org.gnome.Evince.desktop";
      "application/illustrator" = "org.gnome.Evince.desktop";
      # imv: 额外图片格式
      "image/tiff" = "imv-dir.desktop";
      "image/x-tga" = "imv-dir.desktop";
      "image/x-icon" = "imv-dir.desktop";
      "image/vnd.microsoft.icon" = "imv-dir.desktop";
      "image/heif" = "imv-dir.desktop";
      "image/avif" = "imv-dir.desktop";
      # Clash Verge Rev: 注册 clash:// URL scheme 避免启动时 EROFS 写入只读 mimeapps.list
      "x-scheme-handler/clash" = "clash-verge-rev.desktop";
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
      name = "WhiteSur-dark";
      package = whitesurIconTheme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.theme = null;
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

  # ── Portal-GTK 竞态修复 ─────────────────────────────────────────────────
  # 问题：xdg-desktop-portal-gtk 被 D-Bus activation 拉起时，WAYLAND_DISPLAY
  # 可能还没传入 systemd 用户环境，导致它连 :0 失败后标记 failed，后续每次
  # D-Bus 调用超时 25s × 3 = 75s 阻塞所有 GTK 应用。
  # 修法：ExecCondition 轮询等 WAYLAND_DISPLAY；Restart=on-failure 保证崩溃后重试。
  xdg.configFile."systemd/user/xdg-desktop-portal-gtk.service.d/wayland-gate.conf".text = ''
    [Service]
    ExecCondition=${pkgs.bash}/bin/bash -c 'for i in $(seq 1 50); do if systemctl --user show-environment 2>/dev/null | grep -q "^WAYLAND_DISPLAY="; then exit 0; fi; sleep 0.1; done; echo "portal-gtk: WAYLAND_DISPLAY not found after 5s" >&2; exit 1'
    Restart=on-failure
    RestartSec=1
  '';

  # ── Portal-wlr: auto-approve screencast（Steam Remote Play 全桌面串流）──
  # chooser_type=none 只会取输出列表里的第一个显示器，不一定是正在玩的那块。
  # 改用 simple chooser：输出 niri 当前聚焦的显示器名（开始串流时游戏/XMCL 所在屏），
  # 取不到时回落到主屏 DP-3。portal-wlr 用输出名（如 DP-3）匹配目标。
  # max_fps=60 避免 Remote Play 串流帧率被限。
  xdg.configFile."xdg-desktop-portal-wlr/config".text =
    let
      pickOutput = pkgs.writeShellScript "xdpw-pick-focused-output" ''
        name=$(/run/current-system/sw/bin/niri msg --json focused-output 2>/dev/null | ${pkgs.jq}/bin/jq -r '.name // empty')
        echo "''${name:-DP-3}"
      '';
    in
    ''
      [screencast]
      chooser_type=simple
      chooser_cmd=${pickOutput}
      max_fps=60
    '';

  # ── 启动诊断：记录 graphical-session 各服务就绪时间 ──────────────────
  # 查看结果：journalctl --user -u boot-diag -b
  # 排查完毕后可删除此服务
  systemd.user.services.boot-diag = {
    Unit = {
      Description = "Boot timing diagnostics";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "boot-diag" ''
        echo "=== Boot Diagnostics $(date -Iseconds) ==="
        echo ""
        echo "--- systemd-analyze blame --user ---"
        ${pkgs.systemd}/bin/systemd-analyze blame --user 2>&1 | head -30 || true
        echo ""
        echo "--- systemd-analyze critical-chain --user ---"
        ${pkgs.systemd}/bin/systemd-analyze critical-chain --user --no-pager 2>&1 || true
        echo ""
        echo "--- Pending jobs (if any) ---"
        systemctl --user list-jobs --no-pager 2>&1 || echo "(none)"
        echo ""
        echo "--- Portal status ---"
        systemctl --user status xdg-desktop-portal.service --no-pager 2>&1 | head -15 || true
        echo ""
        echo "--- Walker status ---"
        systemctl --user status walker.service --no-pager 2>&1 | head -15 || true
        echo ""
        echo "--- D-Bus activation times (portal backends) ---"
        journalctl --user -b -u xdg-desktop-portal.service --no-pager 2>&1 | tail -20 || true
        echo ""
        echo "--- gnome-keyring ---"
        systemctl --user status gnome-keyring-daemon.service --no-pager 2>&1 | head -10 || true
        echo ""
        echo "=== END ==="
      '';
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # fcitx5 由 NixOS i18n.inputMethod (modules/nixos/ime.nix) 的 XDG autostart 管理
  # 不再定义独立 systemd 用户服务，避免与 app-org.fcitx.Fcitx5@autostart 抢 D-Bus name

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

  # xwayland-spare: 备用 Xwayland 实例 (:1)
  # 主 Xwayland (:0) 有 256 客户端硬上限，QQ/WeChat/Chrome 等长期运行后易耗尽。
  # Steam 等重量级 X11 应用启动时通过 steam-wrapper 自动检测并切到 :1。
  systemd.user.services.xwayland-spare = {
    Unit = {
      Description = "Spare Xwayland instance (:1) for client overflow";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :1";
      Restart = "on-failure";
      RestartSec = "3";
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


  home.file.".local/bin/lo-launch".text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        if [ "$#" -ne 2 ]; then
          echo "usage: lo-launch <cols>x<rows> <name>" >&2
          exit 1
        fi

        spec="$1"
        session_name="$2"
        if [[ ! "$spec" =~ ^([1-9][0-9]*)x([1-9][0-9]*)$ ]]; then
          echo "lo: invalid layout spec: $spec" >&2
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

        LO_CWD="$cwd" LO_COLS="$cols" LO_ROWS="$rows" LO_NAME="$session_name" "${pkgs.python3}/bin/python3" - <<'PY' >"$layout_file"
    import os

    cwd = os.environ["LO_CWD"]
    cols = int(os.environ["LO_COLS"])
    rows = int(os.environ["LO_ROWS"])
    name = os.environ["LO_NAME"]

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
    print(f'    tab name={q(name)} focus=true cwd={q(cwd)} {{')
    emit_grid("        ", cols, rows)
    print("    }")
    print("}")
    PY

        if [ -n "''${ZELLIJ:-}" ]; then
          command zellij action new-tab --layout "$layout_file" --name "$session_name" --cwd "$cwd"
        else
          command zellij --session "$session_name" --layout "$layout_file"
        fi
  '';
  home.file.".local/bin/lo-launch".executable = true;



  # WeChat (nixpkgs): wrapper so Walker can launch; load systemd user env for WAYLAND_DISPLAY etc.

  # ── Deb 应用（rebuild 时自动解包安装，幂等） ──────────────────────────
  # 目录结构：debs/<app-name>/*.deb（子目录名即应用名，deb 文件名随意）
  # 解包到 ~/.local/opt/<app-name>/，按 sha256 幂等跳过

  # ── Herdr: native terminal for coding agents (curl installer) ────────────
  # 安装到 ~/.local/share/herdr-app/，二进制链接到 ~/.local/bin/herdr-app
  # 同时安装 herdr-core 和 hc CLI

  # ── FlClash 桌面入口（AppImage 解压后） ────────────────────────────────

  # ── Frame Control 桌面入口（AppImage 解压后） ──────────────────────────

  # ── ArtCraft Launcher 桌面入口（AppImage 解压后） ──────────────────────

  # ── chrome-agent: browser automation for AI agents (cargo install) ──────
  # 幂等: 只在版本变化或二进制不存在时重新安装

  # Java wrapper for Minecraft: 注入 LD_LIBRARY_PATH 让 GLFW 能 dlopen 系统库，
  # 并强制 X11 绕过 niri Wayland 兼容性问题。
  # 使用稳定符号链接 ~/.local/lib/jdk21，不依赖 nix store hash。


  # Qoder Desktop — bin: opt/Qoder/qoder (Electron)

  # osu! — bin: usr/bin/osu! (dotnet)

  # Obsidian — bin: obsidian (Electron)

  # 钉钉 DingTalk — bin: com.alibabainc.dingtalk (Qt native)
  # 通过 Elevator.sh 启动，需要 cd 到版本目录并 LD_PRELOAD libgbm + libcef

  # QQ (nixpkgs): desktop entry so Walker shows it; absolute Exec path.
  # 注意：QQ (Electron) 的 RUNPATH 中不含 libpulse，导致 Chromium 回退到 ALSA 后端，
  # ALSA 后端通过 PipeWire PCM 插件虽可播放，但设备枚举对麦克风录制有问题。
  # 通过 env 注入 libpulseaudio 路径使 Chromium 使用 PulseAudio 后端（由 PipeWire 提供）。

  # QQ Music (nixpkgs): desktop entry so Walker shows it; absolute Exec path.

  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
    default_dir=${config.home.homeDirectory}
    env=TERMCMD=kitty --title termfilechooser --class file_chooser
  '';


  programs.home-manager.enable = true;
}
