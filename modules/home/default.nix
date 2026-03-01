{ config, lib, pkgs, inputs, ... }:

let
  env = if builtins.pathExists ../../env.nix then import ../../env.nix else {};
  openclawGatewayToken = env.openclawGatewayToken or "";
  discordBotToken = env.discordBotToken or "";
in
{
  imports = [
    ./desktop/niri.nix
    ./desktop/noctalia.nix
    ./desktop/walker.nix
    ./shell/fish.nix
    ./dev/git.nix
    ./dev/zed.nix
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
    OPENCLAW_URL = "http://localhost:18789";
  } // lib.optionalAttrs (openclawGatewayToken != "") {
    OPENCLAW_GATEWAY_TOKEN = openclawGatewayToken;
  };

  home.packages = with pkgs; [
    steam
    google-chrome
    code-cursor
    codex
    docker-buildx
    wl-clipboard
    cliphist
    uv  # provides uvx for running Python tools
    # OpenClaw not in profile (would conflict with nodejs bin/node); gateway runs via systemd below.
  ];

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

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
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

  # OpenClaw gateway: start at graphical session; use http://localhost:18789
  # Use flake store path (not in home.packages) to avoid bin/node conflict with nodejs.
  systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw gateway (localhost:18789)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${inputs.nix-openclaw.packages.${pkgs.system}.default}/bin/openclaw gateway --allow-unconfigured";
      # gateway 配置重载时会 exit 0 做 full process restart，需 Restart=always 让 systemd 再拉起
      Restart = "always";
      RestartSec = "3s";
      Environment = [ "HOME=${config.home.homeDirectory}" ]
        ++ lib.optional (discordBotToken != "") "DISCORD_BOT_TOKEN=${discordBotToken}";
      WorkingDirectory = "%h";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # OpenClaw: on each rebuild, generate a new gateway token and write to ~/.openclaw and environment.d.
  # Only set gateway.auth.token so port and other gateway config are preserved; if jq fails (e.g. JSON5), write minimal config.
  home.activation.openclawGenToken = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    OPENCLAW_DIR="''${HOME}/.openclaw"
    ENV_D_DIR="''${HOME}/.config/environment.d"
    $DRY_RUN_CMD mkdir -p "$OPENCLAW_DIR" "$ENV_D_DIR"
    token="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
    $DRY_RUN_CMD printf '%s' "$token" > "$OPENCLAW_DIR/gateway-token"
    if [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
      if $DRY_RUN_CMD ${pkgs.jq}/bin/jq --arg t "$token" '.gateway.auth.token = $t | .channels.discord.enabled = true' "$OPENCLAW_DIR/openclaw.json" > "$OPENCLAW_DIR/openclaw.json.tmp" 2>/dev/null; then
        $DRY_RUN_CMD mv "$OPENCLAW_DIR/openclaw.json.tmp" "$OPENCLAW_DIR/openclaw.json"
      else
        $DRY_RUN_CMD ${pkgs.jq}/bin/jq -n --arg t "$token" '{gateway: {auth: {token: $t}}, channels: {discord: {enabled: true}}}' > "$OPENCLAW_DIR/openclaw.json"
      fi
    else
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq -n --arg t "$token" '{gateway: {auth: {token: $t}}, channels: {discord: {enabled: true}}}' > "$OPENCLAW_DIR/openclaw.json"
    fi
    $DRY_RUN_CMD printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "$token" > "$ENV_D_DIR/openclaw.conf"
  '';

  # OpenClaw in Walker: script opens dashboard in Chrome; append token to URL (from env or ~/.openclaw/gateway-token).
  home.file.".local/bin/openclaw-dashboard".text = ''
    #!/usr/bin/env bash
    url="''${OPENCLAW_URL:-http://localhost:18789}"
    token="''${OPENCLAW_GATEWAY_TOKEN:-}"
    if [ -z "$token" ] && [ -f "''${HOME}/.openclaw/gateway-token" ]; then
      token=$(cat "''${HOME}/.openclaw/gateway-token")
    fi
    if [ -n "$token" ]; then
      url="$url?token=$token"
    fi
    exec ${pkgs.google-chrome}/bin/google-chrome "$url"
  '';
  home.file.".local/bin/openclaw-dashboard".executable = true;

  # OpenClaw icon (scalable vector) for desktop entry and Walker; full path in Icon= so launchers display it
  xdg.dataFile."icons/hicolor/scalable/apps/openclaw-dashboard.svg".source = ../../icons/openclaw.svg;

  xdg.dataFile."applications/openclaw-dashboard.desktop".text = ''
    [Desktop Entry]
    Name=OpenClaw
    Comment=Open OpenClaw dashboard in browser (sign-in, token)
    Exec=${config.home.homeDirectory}/.local/bin/openclaw-dashboard
    Icon=${config.home.homeDirectory}/.local/share/icons/hicolor/scalable/apps/openclaw-dashboard.svg
    Terminal=false
    Type=Application
    Categories=Network;
    Keywords=openclaw;dashboard;gateway;ai;
  '';

  # Expose Steam to Walker/Elephant; use absolute Exec path so launch from launcher works (no Nix PATH).
  xdg.dataFile."applications/steam.desktop".text = builtins.replaceStrings
    [ "Exec=steam " ]
    [ "Exec=${pkgs.steam}/bin/steam " ]
    (builtins.readFile "${pkgs.steam}/share/applications/steam.desktop");

  # WeChat (Flatpak): --devel + 禁用崩溃上报，避免启动阶段 ptrace/crash 逻辑导致无窗口
  xdg.dataFile."applications/com.tencent.WeChat.desktop".text = ''
    [Desktop Entry]
    Name=WeChat
    Name[zh_CN]=微信
    Exec=${pkgs.flatpak}/bin/flatpak run --devel --env=ELECTRON_DISABLE_CRASH_REPORTER=1 --branch=stable --arch=x86_64 --command=wechat --file-forwarding com.tencent.WeChat @@u %U @@
    Terminal=false
    Type=Application
    Icon=com.tencent.WeChat
    StartupWMClass=WeChat
    Categories=Network;
    Keywords=wechat;weixin;
    Comment=WeChat Desktop
    Comment[zh_CN]=微信桌面版
    X-Flatpak=com.tencent.WeChat
  '';

  # 终端运行 com.tencent.WeChat 时用 wrapper（--devel + 禁用崩溃上报，与 desktop 一致）
  home.file.".local/bin/com.tencent.WeChat".text = ''
    #!/usr/bin/env bash
    exec ${pkgs.flatpak}/bin/flatpak run --devel --env=ELECTRON_DISABLE_CRASH_REPORTER=1 --branch=stable --arch=x86_64 --command=wechat --file-forwarding com.tencent.WeChat "$@"
  '';
  home.file.".local/bin/com.tencent.WeChat".executable = true;

  # WeChat 期望的目录，缺失时可能导致启动异常
  home.file.".xwechat/crashinfo/attachments/.keep".text = "";

  # QQ Music (Flatpak): use absolute path to flatpak so Walker can launch it.
  xdg.dataFile."applications/com.qq.QQmusic.desktop".text = ''
    [Desktop Entry]
    Name=QQ Music
    Name[zh_CN]=QQ音乐
    Exec=${pkgs.flatpak}/bin/flatpak run --branch=stable --arch=x86_64 --command=qqmusic.sh --file-forwarding com.qq.QQmusic @@u %U @@
    Terminal=false
    Type=Application
    Icon=com.qq.QQmusic
    StartupWMClass=QQMusic
    Comment=Tencent QQMusic
    Comment[zh_CN]=QQ音乐
    Categories=AudioVideo;
    X-Flatpak=com.qq.QQmusic
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
