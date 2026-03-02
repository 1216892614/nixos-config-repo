{ config, lib, pkgs, inputs, ... }:

let
  env = if builtins.pathExists ../../env.nix then import ../../env.nix else {};
  openclawGatewayToken = env.openclawGatewayToken or "";
  discordBotToken = env.discordBotToken or "";
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
    google-chrome
    code-cursor
    claude-code
    gemini-cli
    docker-buildx
    wl-clipboard
    cliphist
    uv  # provides uvx for running Python tools
    wechat  # nixpkgs package, https://mynixos.com/nixpkgs/package/wechat
    qqmusic
    # OpenClaw not in profile (would conflict with nodejs bin/node); gateway runs via systemd below.
  ];

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
