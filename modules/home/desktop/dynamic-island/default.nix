{ config, lib, pkgs, ... }:

let
  # ── Dynamic Island Rust 二进制 ──
  dynamic-island = pkgs.rustPlatform.buildRustPackage {
    pname = "dynamic-island";
    version = "0.1.0";
    src = ../../../../pkgs/dynamic-island;
    cargoLock.lockFile = ../../../../pkgs/dynamic-island/Cargo.lock;

    nativeBuildInputs = with pkgs; [
      pkg-config
    ];

    buildInputs = with pkgs; [
      wayland
      wayland-protocols
      libxkbcommon
      dbus
    ];

    meta = {
      description = "Wayland Dynamic Island – layer-shell status overlay";
      platforms = [ "x86_64-linux" ];
      mainProgram = "dynamic-island";
    };
  };

  # ── opencode island-agent 插件源码 ──
  pluginSrc = ./scripts/island-agent-opencode;

  # ── omp hook 文件 ──
  ompHookJs = ./scripts/island-agent-hook-omp.js;

  # ── claude-code-hooks shell hook ──
  hookScript = ./scripts/island-agent-hook.sh;
in
{
  # ── 安装 Dynamic Island 二进制 ──
  home.packages = [ dynamic-island ];

  # ── systemd 用户服务 ──
  systemd.user.services.dynamic-island = {
    Unit = {
      Description = "Dynamic Island – Wayland layer-shell overlay";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dynamic-island}/bin/dynamic-island";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [
        "RUST_LOG=info"
        "WAYLAND_DISPLAY=wayland-1"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ── opencode island-agent 插件部署 ──
  # 将插件文件放到 opencode 的 node_modules 目录供加载
  xdg.configFile."opencode/node_modules/island-agent-opencode/index.js".source =
    "${pluginSrc}/index.js";
  xdg.configFile."opencode/node_modules/island-agent-opencode/package.json".source =
    "${pluginSrc}/package.json";

  # ── omp hook 部署 ──
  xdg.configFile."dynamic-island/island-agent-hook-omp.js".source = ompHookJs;
  xdg.configFile."dynamic-island/island-agent-hook.sh" = {
    source = hookScript;
    executable = true;
  };

  # ── claude-code-hooks 配置（oh-my-openagent 读取 ~/.claude/settings.json） ──
  home.file.".claude/settings.json".text = builtins.toJSON {
    hooks = {
      UserPromptSubmit = [{
        matcher = "";
        hooks = [{
          type = "command";
          command = "${config.home.homeDirectory}/.config/dynamic-island/island-agent-hook.sh";
        }];
      }];
      Stop = [{
        matcher = "";
        hooks = [{
          type = "command";
          command = "${config.home.homeDirectory}/.config/dynamic-island/island-agent-hook.sh";
        }];
      }];
    };
    mcpServers = {
      context7 = {
        url = "https://mcp.context7.com/mcp";
      };
      nixos = {
        command = "nix";
        args = [ "run" "github:utensils/mcp-nixos" "--" ];
      };
      rust-docs = {
        command = "${config.home.homeDirectory}/.cargo/bin/rust-docs-mcp";
        transport = "stdio";
      };
      chrome-agent = {
        command = "${config.home.homeDirectory}/.cargo/bin/chrome-agent";
        args = [ "pipe" ];
        transport = "stdio";
      };
    };
  };

  # ── 颜色配置目录（由 noctalia 模板生成） ──
  xdg.configFile."dynamic-island/colors.json".text = builtins.toJSON {
    primary = "#a3b56a";
    surface = "#0a0e0a";
    text = "#e0e8d8";
    error = "#e06c75";
    background = "#050805";
  };
}
