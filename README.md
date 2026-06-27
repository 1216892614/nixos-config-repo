# NixOS Config

基于 Nix Flakes 的个人 NixOS 桌面配置，包含系统级 NixOS 模块与用户级 Home Manager 环境。

## 主机

| 主机 | 平台 | 说明 |
|------|------|------|
| `desktop` | x86_64-linux | 主力台式机，stateVersion 24.11 |
| `ep-laptop` | x86_64-linux | 笔记本，stateVersion 25.11 |

两台主机共享相同的 NixOS 模块与 Home Manager 配置，仅硬件相关配置各自独立。

## 快速开始

```bash
# 推荐：一键同步到 /etc/nixos 并 rebuild
sudo fish ./scripts/rebuild.fish

# 手动
sudo nixos-rebuild switch --flake .#desktop   # 或 .#ep-laptop
```

### 首次使用

```bash
cp env.nix.example env.nix
# 编辑 env.nix：用户名、Git、代理订阅、SSH 公钥、AI API keys 等
```

`env.nix` 不提交（.gitignore），包含所有个人敏感配置。AI 工具（OpenCode、Claude Code、Codex、Gemini CLI、omp）的 API key 按各自方式配置。

## 桌面环境

| 组件 | 说明 |
|------|------|
| **niri** | Wayland tiling compositor（unstable） |
| **noctalia** | 状态栏 / shell（QuickShell 实现） |
| **walker** | 应用启动器（依赖 elephant） |
| **Clash Verge Rev** | 代理客户端（TUN 模式，ServiceMode） |
| **howdy** | IR 面部识别登录（PAM 集成） |
| **fcitx5 + Rime** | 中文输入法 |

主题：Adwaita-dark + WhiteSur 图标 + W11 鼠标光标，自定义 moss-fern 配色。

## 开发工具

- **编辑器**：Zed（nightly via flake）、Cursor（AppImage）
- **AI 编码**：OpenCode + oh-my-openagent 插件、omp (oh-my-pi)、Claude Code、Codex、Gemini CLI
- **终端**：Kitty + Zellij + Fish + Starship
- **语言**：Python (uv)、Node.js、Rust (sccache → Dragonfly)
- **容器**：Docker + Docker Compose（rootless 用户服务）
- **文件管理**：Yazi（终端）、FileBrowser（Web）

### omo / omp 启动器

`omo` 和 `omp-launch` 是基于 Zellij 的多面板 AI 编码会话启动器：

```bash
omo              # 启动 4 面板 OpenCode 会话（自动分配端口 + server/client 架构）
omp-launch 2x2   # 启动 2×2 网格 omp 面板
lo 3x2           # 通用 Zellij 网格布局
```

## Service Plane

基于 Docker Compose 的容器化服务栈，通过 `systemctl --user` 管理。配置由 Nix 声明式生成到 `~/.config/service-plane/`。

### 服务架构

| 服务 | 类型 | 端口 | 说明 |
|------|------|------|------|
| Traefik | 常驻 | 80, 8070 | HTTP 反向代理 + Sablier 插件 |
| Sablier | 常驻 | — | HTTP scale-to-zero 生命周期管理 |
| Unbound | 常驻 | 5353 | `.local` 权威 DNS |
| tcp-gate | 常驻 | 6399 | TCP 代理 + 按需唤醒 |
| Dragonfly | 按需 | — | sccache Redis 后端，空闲停止 |
| FileBrowser | 按需 | — | Web 文件浏览，空闲停止 |
| RustDesk | 常驻 | 21115-21117 | 远程桌面信号/中继 |
| Pi Agent | 常驻 | 3001 | AI 助手（opencode serve） |

### 访问地址

所有 HTTP 服务通过 `.local` 域名统一路由：

- `http://files.local` — 文件浏览（首次访问自动唤醒）
- `http://agent.local` — AI 助手
- `http://traefik.local` — 路由状态
- `redis://127.0.0.1:6399` — Dragonfly（sccache 自动使用）

本机通过 `/etc/hosts` 解析 `*.local`；LAN 设备可配置 DNS 指向 `:5353`。

### 管理命令

```bash
systemctl --user status service-plane
systemctl --user restart service-plane
docker compose -f ~/.config/service-plane/docker-compose.yml ps
docker compose -f ~/.config/service-plane/docker-compose.yml logs -f
```

### 添加服务

- **TCP scale-to-zero**：`service-plane.nix` → `tcpServices` attrset
- **HTTP scale-to-zero**：compose service + Sablier 标签 + Traefik 路由
- **常驻**：直接添加 compose service

## 网络

- **Clash Verge Rev**：TUN 模式全局透明代理，ServiceMode 免 sudo
- **Cloudflare Zero Trust**：可选 WARP 隧道（`env.nix` 配置 token）
- **OpenCode Server**：系统级 systemd 服务，通过 Zero Trust 远程访问

## 目录结构

```
.
├── flake.nix                 # Flake 入口
├── env.nix.example           # 环境变量模板
├── hosts/
│   ├── desktop/              # 台式机配置 + hardware-configuration
│   └── ep-laptop/            # 笔记本配置 + hardware-configuration
├── modules/
│   ├── nixos/                # 系统模块（全部自动引入）
│   │   ├── audio.nix         # PipeWire
│   │   ├── boot.nix          # systemd-boot
│   │   ├── cloudflared.nix   # Cloudflare 隧道
│   │   ├── desktop.nix       # niri、GDM、Steam、图形
│   │   ├── docker.nix        # Docker + rootless
│   │   ├── howdy.nix         # 面部识别
│   │   ├── ime.nix           # fcitx5
│   │   ├── local-dns.nix     # /etc/hosts *.local 解析
│   │   ├── opencode-server.nix  # OpenCode 远程服务
│   │   ├── proxy.nix         # Clash Verge Rev
│   │   └── ...
│   └── home/                 # Home Manager 模块
│       ├── default.nix       # 主入口：包、服务、桌面项、AI 工具配置
│       ├── desktop/          # niri、noctalia、walker、clash-verge、heroic
│       ├── dev/              # git、zed、cursor、languages、service-plane、skills-manager
│       ├── shell/            # fish
│       ├── terminal.nix      # kitty
│       ├── zellij.nix        # zellij
│       ├── yazi.nix          # yazi 文件管理
│       └── rime-custom.nix   # Rime 输入法方案
├── pkgs/                     # 自定义包（clash-verge-rev、clipsync、omp 等）
├── overlays/                 # nixpkgs 覆盖
├── lib/                      # 共享库（colors.nix）
├── scripts/                  # 辅助脚本
├── appimages/                # AppImage 源文件（rebuild 自动解压安装）
├── debs/                     # Deb 包源文件（rebuild 自动解包安装）
├── wallpapers/               # 壁纸
└── docs/                     # 额外文档
```

## Flake 输入

| 输入 | 来源 |
|------|------|
| nixpkgs | nixos-unstable |
| home-manager | nix-community |
| niri | sodiboo/niri-flake |
| noctalia / noctalia-qs | noctalia-dev |
| walker + elephant | abenz1267 |
| nix-flatpak | gmodena |
| maccel | Gnarus-G/maccel |
| zed | zed-industries/zed |

缓存：`walker.cachix.org`、`cache.garnix.io`

## 应用管理

除 nixpkgs 外，本配置还管理：

- **Flatpak**：通过 nix-flatpak 声明式安装
- **AppImage**：放入 `appimages/` 目录，rebuild 时自动解压到 `~/.local/opt/`
- **Deb**：放入 `debs/<app-name>/` 目录，rebuild 时自动解包安装
- **Skills**：通过 skills-manager 管理 AI agent skills（首次 rebuild 安装所有 official skills）

## 常用命令

```bash
nix flake update                           # 更新所有输入
nix flake lock --update-input nixpkgs      # 仅更新 nixpkgs
sudo fish ./scripts/rebuild.fish           # 重建系统
systemctl --user restart service-plane     # 重启服务栈
```

## 许可与隐私

个人配置仓库。`env.nix`、`hardware-configuration.nix`、API keys 等敏感信息已 gitignore。Fork 后需按自己的机器与账号修改。
