{ config, lib, pkgs, inputs, ... }:

let
  env = if builtins.pathExists ../../env.nix then import ../../env.nix else {};
  openclawGatewayToken = env.openclawGatewayToken or "";
  discordBotToken = env.discordBotToken or "";
  claudeCodeBaseUrl = env.claudeCodeBaseUrl or "";
  claudeCodeApiKey = env.claudeCodeApiKey or "";
  codexBaseUrl = env.codexBaseUrl or "";
  codexApiKey = env.codexApiKey or "";
  geminiBaseUrl = env.geminiBaseUrl or "";
  geminiApiKey = env.geminiApiKey or "";
  # OpenRouter: one API key, model IDs from openrouter.ai (e.g. anthropic/claude-opus-4.6)
  openrouterApiKey = env.openrouterApiKey or "";
  openclawOpenRouterModels = env.openclawOpenRouterModels or [
    "anthropic/claude-opus-4.6"
    "google/gemini-3.1-pro-preview"
    "openai/gpt-5.2-codex"
    "openai/gpt-5.2-chat"
    "openai/gpt-5.2-pro"
  ];
  openclawHasOpenRouter = openrouterApiKey != "";
  openclawDefaultModel = env.openclawDefaultModel or "anthropic/claude-opus-4.6";
  openclawDiscordAllowFrom = env.openclawDiscordAllowFrom or [];
  openclawDiscordDmConfig = if openclawDiscordAllowFrom != [] then {
    policy = "allowlist";
    allowFrom = openclawDiscordAllowFrom;
  } else null;
  w11CursorTheme = pkgs.runCommand "w11-cc-v2.2-dark-default-wayland" {} ''
    mkdir -p $out/share/icons
    cp -R ${../../icons/W11-CC-V2.2-Dark-Default-wayland} $out/share/icons/W11-CC-V2.2-Dark-Default-wayland
  '';
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
    claude-code
    gemini-cli
    docker-buildx
    wl-clipboard
    cliphist
    uv  # provides uvx for running Python tools
    # OpenClaw not in profile (would conflict with nodejs bin/node); gateway runs via systemd below.
  ];

  # Claude Code: only when claudeCodeApiKey is set (no key → no config)
  home.file.".claude/settings.json" = lib.mkIf (claudeCodeApiKey != "") {
    text = builtins.toJSON {
      env = {
        ANTHROPIC_AUTH_TOKEN = claudeCodeApiKey;
        ANTHROPIC_BASE_URL = claudeCodeBaseUrl;
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
      };
      permissions = { allow = [ ]; deny = [ ]; };
    };
  };

  # Codex: only when codexApiKey is set; key only in auth.json, never in env
  home.file.".codex/config.toml" = lib.mkIf (codexApiKey != "") {
    text = ''
      disable_response_storage = true
      model = "gpt-5.2"
      model_reasoning_effort = "high"
      model_provider = "bytecatcode"

      [model_providers.bytecatcode]
      base_url = "${codexBaseUrl}/v1"
      name = "bytecatcode"
      requires_openai_auth = true
      wire_api = "responses"
    '';
  };
  home.file.".codex/auth.json" = lib.mkIf (codexApiKey != "") {
    text = builtins.toJSON { OPENAI_API_KEY = codexApiKey; };
  };

  # Gemini CLI: only when geminiApiKey is set
  home.file.".gemini/config.json" = lib.mkIf (geminiApiKey != "") {
    text = builtins.toJSON {
      CODE_ASSIST_ENDPOINT = geminiBaseUrl + "/";
      GOOGLE_CLOUD_ACCESS_TOKEN = geminiApiKey;
      GOOGLE_GENAI_USE_GCA = "true";
    };
  };

  # OpenClaw: OpenRouter provider (replaces previous ByteCatCode per-model config)
  xdg.configFile."nix/openclaw-openrouter-provider.json" = lib.mkIf openclawHasOpenRouter {
    text = builtins.toJSON {
      openrouter = {
        baseUrl = "https://openrouter.ai/api/v1";
        apiKey = openrouterApiKey;
        api = "openai-completions";
        models = map (id: { id = id; name = id; }) openclawOpenRouterModels;
      };
    };
  };

  # OpenClaw Discord: pre-approved DM user IDs from env.nix (channels.discord.dm allowlist)
  xdg.configFile."nix/openclaw-discord-dm.json" = lib.mkIf (openclawDiscordDmConfig != null) {
    text = builtins.toJSON openclawDiscordDmConfig;
  };

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

  # OpenClaw: on each rebuild, generate gateway token and merge Nix options into ~/.openclaw (tokens from env.nix).
  # Works from zero (no openclaw.json) and with existing config (e.g. after openclaw onboard). If openclaw.json is JSON5, convert to JSON first so jq merges succeed.
  home.activation.openclawGenToken = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    OPENCLAW_DIR="''${HOME}/.openclaw"
    ENV_D_DIR="''${HOME}/.config/environment.d"
    $DRY_RUN_CMD mkdir -p "$OPENCLAW_DIR" "$ENV_D_DIR"
    # Normalise existing openclaw.json from JSON5 to JSON so jq merges work (onboard writes JSON5)
    if [ -f "$OPENCLAW_DIR/openclaw.json" ] && [ -s "$OPENCLAW_DIR/openclaw.json" ]; then
      $DRY_RUN_CMD ${pkgs.python3.withPackages (p: [ p.json5 ])}/bin/python -c '
import json, json5, sys
path = sys.argv[1]
try:
  with open(path) as f: d = json5.load(f)
  with open(path, "w") as f: json.dump(d, f, indent=2)
except Exception:
  pass
' "$OPENCLAW_DIR/openclaw.json" 2>/dev/null || true
    fi
    token="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
    $DRY_RUN_CMD printf '%s' "$token" > "$OPENCLAW_DIR/gateway-token"
    if [ -f "$OPENCLAW_DIR/openclaw.json" ] && [ -s "$OPENCLAW_DIR/openclaw.json" ]; then
      if $DRY_RUN_CMD ${pkgs.jq}/bin/jq --arg t "$token" '.gateway.auth.token = $t | .channels.discord = ((.channels.discord // {}) | .enabled = true)' "$OPENCLAW_DIR/openclaw.json" > "$OPENCLAW_DIR/openclaw.json.tmp" 2>/dev/null; then
        $DRY_RUN_CMD mv "$OPENCLAW_DIR/openclaw.json.tmp" "$OPENCLAW_DIR/openclaw.json"
      fi
    else
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq -n --arg t "$token" '{gateway: {auth: {token: $t}}, channels: {discord: {enabled: true}}}' > "$OPENCLAW_DIR/openclaw.json"
    fi
    # Discord: merge pre-approved DM allowlist from env.nix (openclawDiscordAllowFrom) into channels.discord.dm
    DISCORD_DM_FILE="''${HOME}/.config/nix/openclaw-discord-dm.json"
    if [ -f "$DISCORD_DM_FILE" ] && [ -s "$DISCORD_DM_FILE" ]; then
      if $DRY_RUN_CMD ${pkgs.jq}/bin/jq --slurpfile d "$DISCORD_DM_FILE" '.channels.discord = ((.channels.discord // {}) | .dm = $d[0])' "$OPENCLAW_DIR/openclaw.json" > "$OPENCLAW_DIR/openclaw.json.tmp" 2>/dev/null; then
        $DRY_RUN_CMD mv "$OPENCLAW_DIR/openclaw.json.tmp" "$OPENCLAW_DIR/openclaw.json"
      fi
    fi
    $DRY_RUN_CMD printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "$token" > "$ENV_D_DIR/openclaw.conf"
    for PROVIDER_FILE in "''${HOME}/.config/nix/openclaw-openrouter-provider.json" "''${HOME}/.config/nix/openclaw-bytecatcode-provider.json"; do
      if [ -f "$PROVIDER_FILE" ] && [ -s "$PROVIDER_FILE" ]; then
        if $DRY_RUN_CMD ${pkgs.jq}/bin/jq --slurpfile p "$PROVIDER_FILE" '.models.providers = ((.models.providers // {}) + $p[0])' "$OPENCLAW_DIR/openclaw.json" > "$OPENCLAW_DIR/openclaw.json.tmp" 2>/dev/null; then
          $DRY_RUN_CMD mv "$OPENCLAW_DIR/openclaw.json.tmp" "$OPENCLAW_DIR/openclaw.json"
        fi
      fi
    done
    # OpenRouter: set env.OPENROUTER_API_KEY and agents.defaults.model so agent uses provider "openrouter" (avoids "No API key for provider anthropic")
    OPENROUTER_FILE="''${HOME}/.config/nix/openclaw-openrouter-provider.json"
    if [ -f "$OPENROUTER_FILE" ] && [ -s "$OPENROUTER_FILE" ]; then
      OR_KEY="$(${pkgs.jq}/bin/jq -r '.openrouter.apiKey // empty' "$OPENROUTER_FILE" 2>/dev/null)"
      if [ -n "$OR_KEY" ]; then
        if $DRY_RUN_CMD ${pkgs.jq}/bin/jq --arg k "$OR_KEY" '.env.OPENROUTER_API_KEY = $k | .agents.defaults = ((.agents.defaults // {}) | .model = ((.model // {}) | .primary = "openrouter/${openclawDefaultModel}"))' "$OPENCLAW_DIR/openclaw.json" > "$OPENCLAW_DIR/openclaw.json.tmp" 2>/dev/null; then
          $DRY_RUN_CMD mv "$OPENCLAW_DIR/openclaw.json.tmp" "$OPENCLAW_DIR/openclaw.json"
        fi
        # Persist OpenRouter key to main agent auth-profiles.json (required for agent resolution)
        AGENT_DIR="''${OPENCLAW_DIR}/agents/main/agent"
        $DRY_RUN_CMD mkdir -p "$AGENT_DIR"
        AUTH_FILE="$AGENT_DIR/auth-profiles.json"
        if [ -f "$AUTH_FILE" ]; then
          $DRY_RUN_CMD ${pkgs.jq}/bin/jq --arg k "$OR_KEY" '.profiles["openrouter:default"] = (.profiles["openrouter:default"] // {} | .provider = "openrouter" | .mode = "api_key" | .apiKey = $k)' "$AUTH_FILE" > "$AUTH_FILE.tmp" 2>/dev/null && $DRY_RUN_CMD mv "$AUTH_FILE.tmp" "$AUTH_FILE"
        else
          $DRY_RUN_CMD ${pkgs.jq}/bin/jq -n --arg k "$OR_KEY" '{profiles: {"openrouter:default": {provider: "openrouter", mode: "api_key", apiKey: $k}}}' > "$AUTH_FILE"
        fi
      fi
    fi
  '';

  # openclaw CLI (wrapper so PATH has "openclaw" without adding the package to profile, which would conflict with nodejs bin/node)
  home.file.".local/bin/openclaw".text = ''
    #!/usr/bin/env bash
    exec "${inputs.nix-openclaw.packages.${pkgs.system}.default}/bin/openclaw" "''$@"
  '';
  home.file.".local/bin/openclaw".executable = true;

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
