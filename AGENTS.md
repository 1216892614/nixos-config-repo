# AGENTS.md

本文件为 AI 编码助手（Claude Code、OpenCode、Cursor、Codex 等）提供项目上下文和操作指引。

## 项目概述

这是一个基于 Nix Flakes 的 NixOS 桌面配置仓库，管理两台 x86_64-linux 主机（`desktop`、`ep-laptop`）的系统配置与用户环境。

## 技术栈

- **语言**：Nix（声明式配置语言）
- **框架**：NixOS + Home Manager + Flakes
- **桌面**：niri (Wayland compositor) + noctalia (状态栏) + walker (启动器)
- **容器**：Docker Compose（Service Plane 服务栈）
- **代理**：Clash Verge Rev（TUN 模式）

## 关键约定

### 目录结构规则

- `modules/nixos/` — 系统级模块，由 `hosts/*/default.nix` 自动引入目录下所有 `.nix` 文件
- `modules/home/` — 用户级模块，需在 `modules/home/default.nix` 手动 import
- `hosts/*/` — 主机专用配置（hardware-configuration 等）
- `pkgs/` — 自定义包定义
- `overlays/default.nix` — nixpkgs 覆盖

### 编码风格

- Nix 文件使用 2 空格缩进
- 模块参数解构写在第一行：`{ config, lib, pkgs, ... }:`
- 环境变量从 `env.nix` 导入，使用 `or` 提供默认值：`env.foo or "default"`
- 注释使用中文（与项目 owner 语言一致）
- 长块注释使用 `# ── 标题 ──` 格式分隔

### env.nix 模式

```nix
let
  env = if builtins.pathExists ../../env.nix then import ../../env.nix else import ../../env.nix.example;
in
```

所有敏感配置（API key、订阅 URL、token）必须放在 `env.nix`，绝不硬编码。

### 新增系统模块

1. 在 `modules/nixos/` 创建 `.nix` 文件
2. 无需其他操作 — `hosts/*/default.nix` 会自动扫描引入

### 新增 Home Manager 模块

1. 在 `modules/home/` 合适子目录创建 `.nix` 文件
2. 在 `modules/home/default.nix` 的 `imports` 列表中添加路径

### Service Plane 新增服务

- TCP scale-to-zero：`modules/home/dev/service-plane.nix` → `tcpServices` attrset
- HTTP scale-to-zero：添加 compose service + Sablier 标签 + Traefik 动态配置
- 常驻服务：直接在 compose services 中添加

## 构建与测试

```bash
# 重建系统（推荐）
sudo fish ./scripts/rebuild.fish

# 手动重建
sudo nixos-rebuild switch --flake .#desktop
sudo nixos-rebuild switch --flake .#ep-laptop

# 仅构建不切换（验证无编译错误）
nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run

# 更新 flake 输入
nix flake update
```

## 注意事项

- `env.nix` 不在版本控制中，修改后需 rebuild 生效
- `hardware-configuration.nix` 由 `nixos-generate-config` 生成，通常不手动编辑
- AppImage/Deb 应用通过 `home.activation` 脚本在 rebuild 时自动解压，不需要 `nix-env`
- Overlay 修改影响全局包版本，谨慎变更
- Clash Verge Rev 在 overlay 中 pin 了特定版本（nixpkgs 版本可能无法编译）
- AI 工具配置（opencode.json、oh-my-openagent.json、omp models.yml）在 `modules/home/default.nix` 声明式生成

## 文件关系图

```
flake.nix
├── hosts/desktop/default.nix
│   ├── modules/nixos/*.nix (自动扫描)
│   └── home-manager → modules/home/default.nix
│       ├── desktop/ (niri, noctalia, walker, clash-verge, heroic)
│       ├── dev/ (git, zed, cursor, languages, service-plane, skills-manager)
│       ├── shell/ (fish)
│       ├── terminal.nix, zellij.nix, yazi.nix, recording.nix, rime-custom.nix
│       └── [inline] AI tools config, desktop entries, activation scripts
└── hosts/ep-laptop/default.nix
    └── (同上，共享相同模块)
```

## 常见任务模板

### 添加新系统包

```nix
# modules/nixos/相关模块.nix 或新建模块
environment.systemPackages = with pkgs; [ 包名 ];
```

### 添加新用户包

```nix
# modules/home/default.nix → home.packages
home.packages = with pkgs; [ 包名 ];
```

### 添加新 systemd 用户服务

```nix
# modules/home/default.nix 或相关子模块
systemd.user.services.服务名 = {
  Unit = { Description = "..."; After = [ "graphical-session.target" ]; };
  Service = { ExecStart = "..."; Restart = "on-failure"; };
  Install.WantedBy = [ "graphical-session.target" ];
};
```

### 添加新桌面应用入口

```nix
# modules/home/default.nix
xdg.desktopEntries.应用名 = {
  name = "...";
  exec = "...";
  terminal = false;
  icon = "...";
  categories = [ "..." ];
};
```
