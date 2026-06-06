# NixOS Desktop 配置

基于 Flake 的 NixOS 桌面配置，包含 Home Manager 用户环境。当前仅包含主机 `desktop`（x86_64-linux）。

## 前置要求

- 已安装 NixOS，并启用 [Flakes](https://nixos.wiki/wiki/Flakes) 与 `nix-command`
- 本配置通过 `nixos-rebuild switch --flake` 应用

## 快速开始

### 部署到本机（推荐）

若仓库在 `/home/ep-o1/nixos-config-repo`，可直接执行：

```bash
sudo fish ./scripts/rebuild.fish
```

脚本会：将当前仓库同步到 `/etc/nixos`（排除 `.git`、`result*` 等），然后执行 `nixos-rebuild switch --flake /etc/nixos#desktop`。

### 手动重建

在仓库根目录或 `/etc/nixos` 下：

```bash
# 系统 + Home Manager 一并切换
sudo nixos-rebuild switch --flake .#desktop

# 仅切换当前用户 Home Manager
home-manager switch --flake .#desktop
```

### 首次使用 / 无 env.nix

部分模块（代理、Git、用户、Flatpak 等）依赖 `env.nix` 中的变量。若不存在该文件，会回退到 `env.nix.example`。请复制并按需修改：

```bash
cp env.nix.example env.nix
# 编辑 env.nix，填入用户名、Git 信息、mihomo 订阅、SSH 公钥等
```

`env.nix` 已加入 `.gitignore`，不会提交到仓库。

AI 相关 base URL / API key（Claude Code、Codex、Gemini CLI、OpenCode）请按你自己的使用方式手动配置；默认不在 `env.nix` 中设置环境变量。

## 目录结构

```
.
├── flake.nix              # Flake 入口与 inputs/outputs
├── env.nix.example        # 环境变量模板（复制为 env.nix 使用）
├── env.nix                # 本地环境配置（不提交）
├── hosts/
│   └── desktop/           # 主机 desktop 的配置
│       ├── default.nix    # 引入所有 NixOS 模块 + hardware-configuration
│       └── hardware-configuration.nix  # 硬件相关（通常由 nixos-generate-config 生成）
├── modules/
│   ├── nixos/             # NixOS 系统模块（hosts/desktop 自动引入全部）
│   │   ├── audio.nix
│   │   ├── boot.nix
│   │   ├── desktop.nix    # GDM、niri、Steam、图形相关
│   │   ├── docker.nix
│   │   ├── flatpak.nix
│   │   ├── ime.nix
│   │   ├── keyremap.nix
│   │   ├── locale.nix
│   │   ├── networking.nix
│   │   ├── nix-ld.nix
│   │   ├── nix-settings.nix
│   │   ├── proxy.nix      # mihomo (Clash Meta) 代理
│   │   ├── ssh.nix
│   │   ├── users.nix
│   │   └── ...
│   └── home/              # Home Manager 用户模块
│       ├── default.nix    # 主配置：包、服务、桌面项等
│       ├── desktop/       # niri、noctalia、walker
│       ├── dev/           # git、zed、languages (python/node)
│       ├── shell/         # fish
│       ├── terminal.nix
│       ├── rime-custom.nix
│       └── ...
├── scripts/
│   └── rebuild.fish       # 同步到 /etc/nixos 并 rebuild
└── lib/
    └── colors.nix
```

## 主要组件

| 组件 | 说明 |
|------|------|
| **niri** | Wayland  compositor（niri-flake，unstable） |
| **noctalia** | 状态栏 / shell |
| **walker** | 应用启动器（依赖 elephant） |
| **OpenClaw** | AI 助手 gateway，登录图形会话后以后台服务运行，访问地址：`http://localhost:18789`，环境变量 `OPENCLAW_URL` 已设置 |
| **mihomo** | 代理（Clash Meta），配置来自 `env.nix` 中的订阅等 |
| **nix-flatpak** | Flatpak 集成 |
| **Home Manager** | 用户级包、dotfiles、systemd user 服务 |

## OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) 为 AI 助手网关，本配置通过 [nix-openclaw](https://github.com/openclaw/nix-openclaw) 以声明方式集成。

### 运行方式

- **Gateway** 以 systemd 用户服务 `openclaw-gateway` 运行，在登录图形会话后随 `graphical-session.target` 自动启动；使用 `Restart=always`，以便配置重载后 process 退出时 systemd 会再次拉起。
- 二进制来自 flake 输入 `nix-openclaw` 的 default 包，**未**加入 `home.packages`（避免与 profile 中的 nodejs 产生 `bin/node` 冲突），仅由该服务直接调用 store 路径。
- 启动参数带 **`--allow-unconfigured`**，未做 `openclaw setup` 或未配置 `~/.openclaw` 时也会启动，便于先访问再配对；完成配置后可去掉该参数。

### 访问地址

- **HTTP**：<http://localhost:18789>（gateway 默认端口）
- 环境变量 **`OPENCLAW_URL`** 已设为 `http://localhost:18789`，供依赖该变量的客户端使用。
- **Walker**：在启动器里输入 **openclaw** 并选择「OpenClaw」会用 Chrome 打开 Dashboard。若在 `env.nix` 中配置了 `openclawGatewayToken`，每次启动都会在 URL 后附带 `?token=...`，Dashboard 即可自动完成认证，无需再手动粘贴 token。

### 配置与配对

- 运行时配置与状态目录默认在 `~/.openclaw`（可通过 `OPENCLAW_CONFIG_PATH`、`OPENCLAW_STATE_DIR` 等覆盖）。
- 首次使用需在 OpenClaw 官方文档或客户端中完成配对/登录；若需 Telegram 等集成，需自行配置 bot token 与密钥。

**Token 来源（均在 env.nix）**：Gateway token 每次 rebuild 自动生成并写回；Discord 使用 `discordBotToken`；OpenRouter 使用 `openrouterApiKey`。以上均从 `env.nix` 读入，由 Nix 写入 `~/.config/nix/*.json` 或 systemd 环境，再在 activation 时合并进 `~/.openclaw/openclaw.json` 与 auth-profiles。

**Rebuild 与从零构建**：Activation 在**从零**（无 `openclaw.json`）时生成最小配置后做与 rebuild 相同的合并；在**已有配置**（例如执行过 `openclaw onboard`）时，会先把 JSON5 转为 JSON 再合并，只更新 gateway token、Discord、OpenRouter、agents.defaults 等 Nix 管理的项，不覆盖 onboard 生成的其它选项。

### Gateway 令牌配对（unauthorized: gateway token missing）

**本配置会在每次 rebuild 时自动生成新的 gateway token**，并写入：
- `~/.openclaw/gateway-token`（供 dashboard 脚本拼到 URL）
- `~/.openclaw/openclaw.json` 的 `gateway.auth.token`（gateway 使用）
- `~/.config/environment.d/openclaw.conf`（`OPENCLAW_GATEWAY_TOKEN`，新会话会加载）

从 Walker 启动「OpenClaw」时，脚本会从环境变量或 `~/.openclaw/gateway-token` 读取 token 并拼到 Dashboard URL（`?token=...`），无需再手动粘贴。若希望客户端（如 Cursor）也自动带 token，**重新登录图形会话**一次以加载 `environment.d`，或可在 `env.nix` 中手动设置 `openclawGatewayToken` 覆盖自动生成的 token。

### 服务管理

```bash
# 查看 gateway 状态
systemctl --user status openclaw-gateway

# 重启 gateway
systemctl --user restart openclaw-gateway

# 查看最近日志
journalctl --user -u openclaw-gateway -n 50
```

### 无法访问时排查

1. **确认服务在跑**（在登录图形会话的用户下执行）：
   ```bash
   systemctl --user status openclaw-gateway
   ```
   若为 `inactive` 或 `failed`，执行 `systemctl --user start openclaw-gateway` 后再看日志：
   ```bash
   journalctl --user -u openclaw-gateway -n 80 --no-pager
   ```

2. **确认端口在监听**：
   ```bash
   ss -tlnp | grep 18789
   # 或
   curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/
   ```
   有输出或返回非 000 即表示有进程在监听。

3. **确认环境**：服务会使用 `HOME=当前用户家目录` 与 `WorkingDirectory=%h`，以便读取 `~/.openclaw`。若曾改过家目录或用 sudo 测，请用当前登录用户测。

4. **首次使用**：未配对/未配置时，gateway 可能只返回简单页或需先完成客户端配对，属正常；先确认上述 1、2 通过再按 OpenClaw 文档做配对。

5. **重新应用配置**：改过 Nix 配置后请执行 `home-manager switch --flake .#desktop` 或 `sudo fish ./scripts/rebuild.fish`，**务必再执行** `systemctl --user restart openclaw-gateway`，否则 gateway 不会加载新生成的 token 与 `openclaw.json`，会导致无法访问。

6. **「No API key found for provider anthropic」**：说明 agent 在用直连 anthropic 而非 OpenRouter。本配置会在每次 rebuild 时向 `openclaw.json` 写入 `env.OPENROUTER_API_KEY`、`agents.defaults.model.primary`（来自 env.nix 的 `openclawDefaultModel`），并向 `~/.openclaw/agents/main/agent/auth-profiles.json` 写入 `openrouter:default` 的 API key。若仍报错，可手动执行一次：`openclaw onboard --auth-choice apiKey --token-provider openrouter --token "$(jq -r '.openrouter.apiKey' ~/.config/nix/openclaw-openrouter-provider.json)"`，然后重启 gateway。

### Discord Bot

Gateway 支持 Discord 频道。已启用 `channels.discord.enabled`，token 在 **`env.nix`** 中配置：

- 在 **`env.nix`** 里设置 **`discordBotToken = "你的Bot Token";`**（`env.nix.example` 有示例）。
- rebuild 后重启 gateway：`systemctl --user restart openclaw-gateway`。
- 在 Discord 开发者后台为 Bot 开启 **Message Content Intent**（及按需 **Server Members Intent**），将 Bot 邀请到服务器后，在 OpenClaw 中完成配对。

`env.nix` 已加入 `.gitignore`，不会提交；注意 build 后 token 会进入 Nix store，仅本机重建时勿泄露 store。

### 使用 openclaw CLI

因未装入用户 profile，终端中不会直接有 `openclaw` 命令。若需在命令行使用，可临时用 flake 提供的路径，或自行在 `~/.local/bin` 下做 wrapper 指向该路径。

## Flake 输入摘要

- `nixpkgs` (nixos-unstable)
- `home-manager`
- `niri` (sodiboo/niri-flake)
- `noctalia` / `noctalia-qs`
- `walker` + `elephant`
- `nix-flatpak`
- `nix-openclaw`（OpenClaw 打包，供 gateway 服务使用）

缓存：除默认 substituters 外，使用 `walker.cachix.org`、`cache.garnix.io`。

## 常用命令

```bash
# 更新 flake 输入
nix flake update

# 仅更新指定输入
nix flake lock --update-input nix-openclaw

# 查看当前配置会安装的包（示例）
nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run
```

## 许可证与隐私

- 配置为个人使用；`env.nix`、`hosts/*/hardware-configuration.nix`、`hosts/*/mihomo-config.yaml` 等含本机/账号相关信息，已忽略或需自行从 example 生成。
- 克隆或 fork 后请根据自己机器与账号修改 `env.nix` 及硬件配置。
