# Noctalia v5 升级 + 灵动岛实现

## TL;DR

> **Quick Summary**: 升级 Noctalia v4 (Quickshell/QML) → v5 (native C++)，并从零构建一个 Quickshell 灵动岛（Dynamic Island），支持时钟、屏幕录制指示、OpenCode 通知、以及解锁后 howdy 成功动画。灵动岛视觉上与 v5 bar 融为一体。
> 
> **Deliverables**:
> - Noctalia v5 完整配置（TOML via Nix，Material You 壁纸取色）
> - 自定义 Quickshell 灵动岛（QML + SpringAnimation）
> - 颜色同步（v5 模板系统 → 灵动岛）
> - howdy 解锁成功动画
> - 屏幕录制状态指示
> - OpenCode 通知显示
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: v5 升级 → 岛骨架 → 状态机 → 颜色集成

---

## Context

### Original Request
用户希望：
1. 升级到 Noctalia v5 以获得 Material You 壁纸取色、浮动圆角栏等 iNiR 风格特性
2. 实现 Apple 灵动岛效果，视觉上与 bar 融为一体
3. 灵动岛支持：时钟（idle）、屏幕录制指示、OpenCode 通知、面部识别动画
4. Spring 弹性动画，Apple 级对齐设计
5. 参考 StatIndet/quickshell 的实现思路

### Interview Summary
**Key Discussions**:
- v5 是 alpha 但日可用，~50MB RAM，7.4k stars，NixOS flake 已有
- v5 不依赖 Quickshell → Quickshell 灵动岛可与 v5 天然共存（不同渲染栈）
- 灵动岛替代 bar 的 Clock widget，视觉上看起来是 bar 的中间部分
- `ext-session-lock-v1` 协议阻止任何非锁屏 surface 渲染在锁屏之上
- Howdy 动画改为**解锁成功后的庆祝动画**（非锁屏上的扫描动画）
- v5 IPC 协议完全改变：`noctalia msg <target> <action>`
- v5 颜色通过 template 系统 + `colors_changed` hook 导出
- 当前 `noctalia-qs` 是死代码，可清理

### Metis Review
**Identified Gaps** (addressed):
- **锁屏渲染不可能** → 改为 post-unlock 动画
- **v5 PAM service 支持未确认** → 加入调研任务
- **IPC 协议完全不同** → 需要完整映射
- **colors.nix 静态主题与动态取色冲突** → Phase 1 保持静态，独立处理
- **noctalia-qs 死代码** → Phase 0 清理
- **Quickshell 打包** → 需要确认 nixpkgs 或独立 flake
- **录屏 QML patch 不兼容 v5** → 迁移到灵动岛录制状态

---

## Work Objectives

### Core Objective
将桌面 shell 从 Noctalia v4 (Quickshell) 升级到 v5 (native C++)，并实现一个与 bar 视觉融合的灵动岛 overlay，提供时钟、录屏指示、通知和 howdy 动画功能。

### Concrete Deliverables
- `flake.nix`: v5 input 替换 v4, Quickshell input 添加
- `modules/home/desktop/noctalia.nix`: 完全重写为 v5 TOML 配置
- `modules/home/desktop/niri.nix`: IPC 命令更新
- `modules/home/desktop/dynamic-island/`: 新 Quickshell QML 项目
- v5 color template: 导出到 `~/.config/dynamic-island/colors.json`
- systemd user service: `dynamic-island.service`

### Definition of Done
- [ ] `nix build` 两个 host 均成功
- [ ] v5 bar 渲染正确（浮动、圆角、Material You 配色）
- [ ] 灵动岛 idle 态显示时间，与 bar 视觉对齐
- [ ] 录制 wf-recorder 时灵动岛展开红色指示 + 计时
- [ ] 壁纸切换后 3 秒内灵动岛颜色同步
- [ ] 解锁后灵动岛播放 howdy 成功动画
- [ ] 所有 niri 快捷键功能正常

### Must Have
- v5 升级完整可日用（锁屏、howdy、media keys、控制中心）
- 灵动岛 spring 弹性动画（不是线性）
- 灵动岛 idle/recording/notification 3 种状态
- 与 bar 视觉融合（同色、同高、对齐）
- 颜色跟随 v5 Material You 动态取色
- `exclusiveZone = 0`（不推窗口）
- systemd service 管理

### Must NOT Have (Guardrails)
- ❌ 锁屏上渲染灵动岛（`ext-session-lock-v1` 协议禁止）
- ❌ 修改 `lib/colors.nix`（保持静态主题，动态取色由 v5 独立处理）
- ❌ Luau 插件开发（Phase 1-2 范围外）
- ❌ GLSL shader（只用 QML 内置动画）
- ❌ 多显示器灵动岛（仅主显示器）
- ❌ 超过 3 种灵动岛状态
- ❌ 媒体控件 / 蓝牙 / WiFi 集成（scope creep）
- ❌ 双 Quickshell 实例（v5 不占 Quickshell）
- ❌ 在 Phase 1 中追求完美录屏指示（v4 QML patch 不迁移）

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (新项目，需建立)
- **Automated tests**: Tests-after (QML 无 TDD 框架，用 QA 场景验证)
- **Framework**: bash scripts + noctalia IPC + systemctl assertions

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Nix build**: `nix build` dry-run + actual build
- **Bar/Island UI**: Playwright with niri screenshot (`grim`) + color picker
- **IPC**: `noctalia msg` commands + exit code assertions
- **Services**: `systemctl --user status` + `journalctl` assertions
- **Animation**: screen recording (`wf-recorder`) + frame count analysis

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 0 (Prep - immediate, parallel):
├── Task 1: 清理 noctalia-qs 死代码 [quick]
├── Task 2: 调研 v5 IPC 命令完整列表 [unspecified-high]
├── Task 3: 调研 v5 PAM/howdy 支持方式 [unspecified-high]
├── Task 4: 确认 Quickshell NixOS 打包方案 [unspecified-high]
└── Task 5: 调研 v5 template 颜色导出格式 [unspecified-high]

Wave 1 (v5 Migration - after Wave 0):
├── Task 6: 添加 v5 flake input + 构建验证 [quick]
├── Task 7: 编写 v5 TOML 配置（bar/wallpaper/lockscreen/general） [unspecified-high]
├── Task 8: 更新 niri.nix IPC 绑定（8 处） [quick]
├── Task 9: 配置 v5 howdy PAM 集成 [deep]
├── Task 10: 移除 v4 模块，切换到 v5 [unspecified-high]
└── Task 11: 双 host 构建验证 + 日用 48h gate [unspecified-high]

Wave 2 (Island Scaffold - after Task 6, parallel with Wave 1 later tasks):
├── Task 12: 打包 Quickshell 为 Nix derivation [unspecified-high]
├── Task 13: 灵动岛骨架 - PanelWindow + idle 时钟 [deep]
├── Task 14: 灵动岛 systemd service + kill switch [quick]
└── Task 15: 灵动岛与 v5 bar 视觉对齐调试 [visual-engineering]

Wave 3 (States + Animation + Integration - after Wave 1 & 2):
├── Task 16: 录制状态 - PID 监控 + red indicator + timer [deep]
├── Task 17: 通知状态 - D-Bus listener + compact 展示 [deep]
├── Task 18: Spring 动画系统 - 状态切换过渡 [visual-engineering]
├── Task 19: Apple 对齐设计 - compact leading/trailing 布局 [visual-engineering]
├── Task 20: v5 颜色模板 + colors_changed hook 集成 [deep]
├── Task 21: Howdy post-unlock 成功动画 [visual-engineering]
└── Task 22: 全屏自动隐藏 + overview 隐藏 [quick]

Wave FINAL (Review - after ALL):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
-> Present results -> Get explicit user okay
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 6 |
| 2 | — | 8 |
| 3 | — | 9 |
| 4 | — | 12 |
| 5 | — | 20 |
| 6 | 1 | 7, 10, 12 |
| 7 | 6 | 10 |
| 8 | 2 | 10 |
| 9 | 3, 6 | 10 |
| 10 | 7, 8, 9 | 11, 15, 20 |
| 11 | 10 | 16-22 |
| 12 | 4 | 13 |
| 13 | 12 | 14, 15, 16-19 |
| 14 | 13 | 16-22 |
| 15 | 10, 13 | 16-22 |
| 16 | 14, 15 | F1-F4 |
| 17 | 14, 15 | F1-F4 |
| 18 | 13 | 16, 17, 21 |
| 19 | 13 | 16, 17, 21 |
| 20 | 5, 10 | F1-F4 |
| 21 | 18, 19 | F1-F4 |
| 22 | 14 | F1-F4 |

### Agent Dispatch Summary

- **Wave 0**: 5 tasks — T1 `quick`, T2-T5 `unspecified-high`
- **Wave 1**: 6 tasks — T6 `quick`, T7/T10/T11 `unspecified-high`, T8 `quick`, T9 `deep`
- **Wave 2**: 4 tasks — T12 `unspecified-high`, T13 `deep`, T14 `quick`, T15 `visual-engineering`
- **Wave 3**: 7 tasks — T16/T17 `deep`, T18/T19/T21 `visual-engineering`, T20 `deep`, T22 `quick`
- **FINAL**: 4 tasks — F1 `oracle`, F2 `unspecified-high`, F3 `unspecified-high`, F4 `deep`

---

## TODOs

- [ ] 1. 清理 noctalia-qs 死代码

  **What to do**:
  - 从 `flake.nix` 移除 `noctalia-qs` input 声明
  - 运行 `nix flake lock` 更新 lock 文件
  - 验证两个 host 仍可构建

  **Must NOT do**:
  - 不要改动 `noctalia` (v4) input
  - 不要改动任何模块文件

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 0 (with Tasks 2, 3, 4, 5)
  - **Blocks**: Task 6
  - **Blocked By**: None

  **References**:
  - `flake.nix:17-25` — 当前 inputs 声明，`noctalia-qs` 在此处但从未在 outputs 中使用
  - Metis 确认 `noctalia-qs` 是死代码

  **Acceptance Criteria**:
  - [ ] `grep -r "noctalia-qs" flake.nix` → 无匹配
  - [ ] `nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run` → 成功
  - [ ] `nix build .#nixosConfigurations.ep-laptop.config.system.build.toplevel --dry-run` → 成功

  **QA Scenarios**:
  ```
  Scenario: flake 构建不受影响
    Tool: Bash
    Steps:
      1. nix flake check --no-build
      2. nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run
    Expected Result: exit code 0, no "noctalia-qs" in evaluation trace
    Evidence: .sisyphus/evidence/task-1-flake-check.txt
  ```

  **Commit**: YES
  - Message: `chore: remove dead noctalia-qs flake input`
  - Files: `flake.nix`, `flake.lock`

- [ ] 2. 调研 v5 IPC 命令完整列表

  **What to do**:
  - 克隆 `github:noctalia-dev/noctalia` 到临时目录
  - 搜索源码中所有 IPC handler/命令注册
  - 查阅 docs.noctalia.dev IPC 文档
  - 建立完整的 v4→v5 IPC 映射表，覆盖当前 niri.nix 中的 8 处调用：
    - `controlCenter toggle`
    - `settings toggle`
    - `lockScreen lock`
    - `volume increase/decrease/muteOutput/muteInput`
  - 输出：映射表文档

  **Must NOT do**:
  - 不要修改任何配置文件
  - 不要安装 v5

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 0 (with Tasks 1, 3, 4, 5)
  - **Blocks**: Task 8
  - **Blocked By**: None

  **References**:
  - `modules/home/desktop/niri.nix` — 8 处 `noctalia-shell ipc call` 调用
  - https://docs.noctalia.dev/v5/configuration/ipc/ — v5 IPC 文档
  - https://github.com/noctalia-dev/noctalia — v5 源码

  **Acceptance Criteria**:
  - [ ] 产出映射表包含所有 8 个 v4 命令的 v5 等价物
  - [ ] 映射表保存到 `.sisyphus/drafts/v5-ipc-mapping.md`

  **QA Scenarios**:
  ```
  Scenario: 映射表完整性
    Tool: Bash
    Steps:
      1. grep "noctalia-shell ipc call" modules/home/desktop/niri.nix | wc -l
      2. cat .sisyphus/drafts/v5-ipc-mapping.md | grep "^|" | wc -l
    Expected Result: 映射表行数 >= niri.nix 中 IPC 调用数
    Evidence: .sisyphus/evidence/task-2-ipc-mapping.md
  ```

  **Commit**: NO (调研产出)

- [ ] 3. 调研 v5 PAM/howdy 支持方式

  **What to do**:
  - 检查 v5 源码中 lock screen PAM 认证实现
  - 确认是否支持 `NOCTALIA_PAM_SERVICE` 环境变量
  - 确认是否有 TOML 配置项指定 PAM service name
  - 检查 v5 lock screen 是否有 widget 扩展点
  - 输出：howdy 集成方案文档

  **Must NOT do**:
  - 不要修改任何文件

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 0 (with Tasks 1, 2, 4, 5)
  - **Blocks**: Task 9
  - **Blocked By**: None

  **References**:
  - `modules/home/desktop/noctalia.nix:225-227` — 当前 v4 的 `NOCTALIA_PAM_SERVICE=noctalia` 设置
  - `pkgs/pam-howdy-animated/default.nix` — 自定义 PAM wrapper
  - https://github.com/noctalia-dev/noctalia — v5 源码 lock screen 实现

  **Acceptance Criteria**:
  - [ ] 产出文档明确回答：v5 是否支持自定义 PAM service
  - [ ] 如果不支持，提供替代方案（upstream issue / patch / workaround）
  - [ ] 文档保存到 `.sisyphus/drafts/v5-howdy-integration.md`

  **QA Scenarios**:
  ```
  Scenario: 方案文档可执行
    Tool: Bash
    Steps:
      1. cat .sisyphus/drafts/v5-howdy-integration.md
      2. grep -c "方案" .sisyphus/drafts/v5-howdy-integration.md
    Expected Result: 文档存在且包含至少一个具体方案
    Evidence: .sisyphus/evidence/task-3-howdy-research.txt
  ```

  **Commit**: NO (调研产出)

- [ ] 4. 确认 Quickshell NixOS 打包方案

  **What to do**:
  - 检查 nixpkgs 是否有 `quickshell` 包
  - 检查 `github:quickshell-mirror/quickshell` 或 `github:outfoxxed/quickshell` flake
  - 确认 Quickshell 版本需求（SpringAnimation 支持、layer-shell overlay）
  - 确定打包路径：nixpkgs / 独立 flake / 本地 derivation
  - 输出：打包方案 + flake input 建议

  **Must NOT do**:
  - 不要实际添加 flake input

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 0 (with Tasks 1, 2, 3, 5)
  - **Blocks**: Task 12
  - **Blocked By**: None

  **References**:
  - https://quickshell.outfoxxed.me/ — Quickshell 官方文档
  - StatIndet/quickshell — 依赖的 Quickshell 版本

  **Acceptance Criteria**:
  - [ ] 产出文档包含具体 flake input URL + 构建验证命令
  - [ ] 文档保存到 `.sisyphus/drafts/quickshell-packaging.md`

  **QA Scenarios**:
  ```
  Scenario: 打包方案可验证
    Tool: Bash
    Steps:
      1. cat .sisyphus/drafts/quickshell-packaging.md
      2. grep -E "(github:|nixpkgs)" .sisyphus/drafts/quickshell-packaging.md
    Expected Result: 包含有效的 flake URL 或 nixpkgs 包名
    Evidence: .sisyphus/evidence/task-4-quickshell-packaging.txt
  ```

  **Commit**: NO (调研产出)

- [ ] 5. 调研 v5 template 颜色导出格式 {#task-5}

  **What to do**:
  - 查阅 docs.noctalia.dev 的 template 文档
  - 确认 `[theme.templates.user.*]` 配置格式
  - 确认可用的模板变量（`{{ colors.primary.dark.hex }}` 等）
  - 确认 `colors_changed` hook 的触发机制和传递的环境变量
  - 设计灵动岛颜色文件格式（JSON，包含 primary/surface/onSurface/error 等）
  - 输出：模板配置 + 颜色 JSON schema

  **Must NOT do**:
  - 不要修改任何文件

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 0 (with Tasks 1, 2, 3, 4)
  - **Blocks**: Task 20
  - **Blocked By**: None

  **References**:
  - https://docs.noctalia.dev/v5/theming/templates/ — v5 模板文档
  - https://docs.noctalia.dev/v5/theming/palette/#color-roles — 16 色色彩角色

  **Acceptance Criteria**:
  - [ ] 产出 TOML 模板配置片段（可直接粘贴到 v5 settings）
  - [ ] 产出 JSON schema 定义灵动岛需要的颜色字段
  - [ ] 文档保存到 `.sisyphus/drafts/v5-color-template.md`

  **QA Scenarios**:
  ```
  Scenario: 模板语法正确
    Tool: Bash
    Steps:
      1. cat .sisyphus/drafts/v5-color-template.md
      2. grep -c "{{" .sisyphus/drafts/v5-color-template.md
    Expected Result: 包含 Noctalia v5 模板变量语法
    Evidence: .sisyphus/evidence/task-5-color-template.txt
  ```

  **Commit**: NO (调研产出)

- [ ] 6. 添加 v5 flake input + 构建验证

  **What to do**:
  - 将 `flake.nix` 中 `noctalia` input 从 `github:noctalia-dev/noctalia-shell` 改为 `github:noctalia-dev/noctalia`（pin 到调研时确认的稳定 commit）
  - 添加 `noctalia.cachix.org` 到 substituters
  - 验证 `nix build inputs.noctalia.packages.x86_64-linux.default` 成功
  - 暂不切换 Home Manager module（保持 v4 运行）

  **Must NOT do**:
  - 不要删除 v4 的 homeModules 引用（Task 10 做）
  - 不要修改 modules/ 下任何文件

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (sequential start)
  - **Blocks**: Tasks 7, 10, 12
  - **Blocked By**: Task 1

  **References**:
  - `flake.nix` — 当前 inputs/outputs 结构
  - Task 1 产出 — 清理后的 flake.nix

  **Acceptance Criteria**:
  - [ ] `nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run` 成功
  - [ ] v5 binary 可从 cachix 或源码构建

  **QA Scenarios**:
  ```
  Scenario: v5 包可构建
    Tool: Bash
    Steps:
      1. nix build github:noctalia-dev/noctalia#default --no-link --print-out-paths
      2. 检查输出路径中 bin/noctalia 存在
    Expected Result: 构建成功，二进制存在
    Evidence: .sisyphus/evidence/task-6-v5-build.txt
  ```

  **Commit**: YES
  - Message: `feat(flake): add noctalia v5 input (pinned)`
  - Files: `flake.nix`, `flake.lock`

- [ ] 7. 编写 v5 TOML 配置

  **What to do**:
  - 创建新的 `modules/home/desktop/noctalia.nix`（完全重写），使用 `programs.noctalia.settings` attrset
  - 配置项：
    - `[bar.main]`: 浮动（`margin_edge=8`）、圆角（`radius=14`）、`background_opacity=1.0`、`density="compact"`、`widgets.center=[]`（留给灵动岛）
    - `[bar.main.widgets.left]`: Workspace（pill dots）
    - `[bar.main.widgets.right]`: Tray、Brightness、Volume、Battery、NotificationHistory、ControlCenter（无 Clock——由灵动岛代替）
    - `[wallpaper]`: enabled、cover、all monitors、overview blur
    - `[theme]`: `source="wallpaper"`、`scheme="m3-tonal-spot"`
    - `[general]`: lockOnSuspend、autoStartAuth
    - `[lockscreen]`: blur、tint
  - 保留 `lib/colors.nix` 作为 fallback（用于 Walker 等未迁移组件）

  **Must NOT do**:
  - 不要写 Luau 插件
  - 不要配置录屏 widget（由灵动岛接管）
  - 不要修改 `lib/colors.nix`

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 8, after Task 6)
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 10
  - **Blocked By**: Task 6

  **References**:
  - `modules/home/desktop/noctalia.nix` — 当前 v4 配置（251 行，需完全替换）
  - https://github.com/noctalia-dev/noctalia/blob/main/example.toml — v5 完整配置参考
  - https://docs.noctalia.dev/v5/configuration/ — v5 配置文档
  - `lib/colors.nix` — 当前 Moss & Fern 主题色

  **Acceptance Criteria**:
  - [ ] `noctalia config validate` 对生成的 TOML 通过
  - [ ] 配置包含 bar（浮动圆角）、wallpaper（Material You）、lockscreen、widgets

  **QA Scenarios**:
  ```
  Scenario: 配置语法有效
    Tool: Bash
    Steps:
      1. nix eval .#nixosConfigurations.desktop.config.programs.noctalia.settings --json | head -c 200
    Expected Result: 输出有效 JSON（可转 TOML），包含 bar/wallpaper/theme 字段
    Evidence: .sisyphus/evidence/task-7-config-eval.json

  Scenario: bar center 为空
    Tool: Bash
    Steps:
      1. nix eval .#nixosConfigurations.desktop.config.programs.noctalia.settings.bar.main.widgets.center --json
    Expected Result: 输出 [] 或 null
    Evidence: .sisyphus/evidence/task-7-center-empty.txt
  ```

  **Commit**: YES (groups with Task 10)
  - Message: `feat(desktop): migrate noctalia v4 → v5`
  - Files: `modules/home/desktop/noctalia.nix`

- [ ] 8. 更新 niri.nix IPC 绑定

  **What to do**:
  - 根据 Task 2 的映射表，替换 `niri.nix` 中所有 `noctalia-shell ipc call` 为 `noctalia msg` 等价命令
  - 如果某些 v5 IPC 不存在（如 volume），改用直接工具（`wpctl`/`brightnessctl`/`playerctl`）
  - 保留所有非 noctalia 快捷键不变

  **Must NOT do**:
  - 不要改动窗口规则、blur、opacity、input 设置
  - 不要添加新快捷键（灵动岛 kill switch 在 Task 14）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 7, after Task 2)
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 10
  - **Blocked By**: Task 2

  **References**:
  - `modules/home/desktop/niri.nix` — 当前 8 处 IPC 调用
  - `.sisyphus/drafts/v5-ipc-mapping.md` — Task 2 产出的映射表

  **Acceptance Criteria**:
  - [ ] `grep "noctalia-shell ipc call" modules/home/desktop/niri.nix` → 0 匹配
  - [ ] 所有替换命令路径存在（`which noctalia` / `which wpctl` 等）

  **QA Scenarios**:
  ```
  Scenario: 无残留 v4 IPC 调用
    Tool: Bash
    Steps:
      1. grep -c "noctalia-shell" modules/home/desktop/niri.nix
    Expected Result: 0
    Evidence: .sisyphus/evidence/task-8-no-v4-ipc.txt
  ```

  **Commit**: YES (groups with Task 10)
  - Message: `feat(desktop): migrate noctalia v4 → v5`
  - Files: `modules/home/desktop/niri.nix`

- [ ] 9. 配置 v5 howdy PAM 集成

  **What to do**:
  - 根据 Task 3 调研结果，实现 v5 锁屏的 howdy 集成
  - 可能方案：
    - A: v5 支持 `NOCTALIA_PAM_SERVICE` → 设置 systemd env
    - B: v5 TOML 有 `[lockscreen] pam_service = "noctalia"` → 配置
    - C: 均不支持 → 提 upstream issue 或用 PAM stack 配置绕过
  - 确保 `pam-howdy-animated` 在 v5 lock screen 中被正确调用
  - 配置 `autoStartAuth = true`（锁屏后立即触发 howdy）

  **Must NOT do**:
  - 不要修改 howdy 本身的配置
  - 不要修改 `hardware-configuration.nix` 中的 PAM service 定义

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 7, 8)
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 10
  - **Blocked By**: Tasks 3, 6

  **References**:
  - `.sisyphus/drafts/v5-howdy-integration.md` — Task 3 产出
  - `modules/home/desktop/noctalia.nix:225-227` — 当前 v4 PAM env 设置
  - `hosts/desktop/hardware-configuration.nix:119-124` — PAM service 定义

  **Acceptance Criteria**:
  - [ ] v5 锁屏时 `pgrep howdy` 在 1 秒内出现
  - [ ] howdy 成功后自动解锁

  **QA Scenarios**:
  ```
  Scenario: howdy 在锁屏时触发
    Tool: Bash
    Steps:
      1. noctalia msg session lock
      2. sleep 1
      3. pgrep howdy
    Expected Result: howdy 进程存在（exit code 0）
    Evidence: .sisyphus/evidence/task-9-howdy-trigger.txt

  Scenario: howdy 成功解锁
    Tool: Bash
    Preconditions: 面对 IR 摄像头
    Steps:
      1. noctalia msg session lock
      2. sleep 4 (howdy timeout)
      3. noctalia msg session-state
    Expected Result: session state = unlocked（如果面部可识别）
    Evidence: .sisyphus/evidence/task-9-howdy-unlock.txt
  ```

  **Commit**: YES (groups with Task 10)
  - Message: `feat(desktop): migrate noctalia v4 → v5`
  - Files: `modules/home/desktop/noctalia.nix`

- [ ] 10. 移除 v4 模块，切换到 v5

  **What to do**:
  - 在 `flake.nix` outputs 中将 `noctalia.homeModules.default` 替换为 v5 的 `noctalia.homeModules.default`
  - 移除旧 `noctalia-dev/noctalia-shell` input（保留 v5 的 `noctalia-dev/noctalia`）
  - 移除 `noctalia-lock-on-start` systemd service（v5 内置）
  - 移除录屏 QML patch 相关代码（`patchedNoctaliaShell`, `patchedScreenRecorder`, `home.file` 插件部署）
  - 确保 `nix build` 两个 host 通过

  **Must NOT do**:
  - 不要删除 `lib/colors.nix`（Walker 仍在用）
  - 不要修改 Walker 配置

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (sequential, after 7+8+9)
  - **Blocks**: Tasks 11, 15, 20
  - **Blocked By**: Tasks 7, 8, 9

  **References**:
  - `flake.nix` — outputs 中 homeModules 引用
  - `modules/home/desktop/noctalia.nix:1-77` — v4 patching 代码（需全部删除）
  - `modules/home/desktop/noctalia.nix:219-250` — v4 插件部署 + lock-on-start（需删除）

  **Acceptance Criteria**:
  - [ ] `nix build .#nixosConfigurations.desktop.config.system.build.toplevel` 成功
  - [ ] `nix build .#nixosConfigurations.ep-laptop.config.system.build.toplevel` 成功
  - [ ] `grep "noctalia-shell" flake.nix` → 0 匹配
  - [ ] `grep "patchedNoctalia" modules/home/desktop/noctalia.nix` → 0 匹配

  **QA Scenarios**:
  ```
  Scenario: 两个 host 均可构建
    Tool: Bash
    Steps:
      1. nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run
      2. nix build .#nixosConfigurations.ep-laptop.config.system.build.toplevel --dry-run
    Expected Result: 两者 exit code 0
    Evidence: .sisyphus/evidence/task-10-dual-build.txt

  Scenario: 无 v4 残留
    Tool: Bash
    Steps:
      1. grep -r "noctalia-shell" flake.nix modules/
      2. grep -r "patchedNoctalia" modules/
    Expected Result: 0 匹配
    Evidence: .sisyphus/evidence/task-10-no-v4.txt
  ```

  **Commit**: YES
  - Message: `feat(desktop): migrate noctalia v4 → v5`
  - Files: `flake.nix`, `flake.lock`, `modules/home/desktop/noctalia.nix`, `modules/home/desktop/niri.nix`

- [ ] 11. 双 host 构建验证 + 日用稳定性 gate

  **What to do**:
  - `nixos-rebuild switch` 应用 v5 到 desktop host
  - 验证所有功能：bar 渲染、锁屏、howdy、media keys、控制中心、wallpaper
  - 测试 suspend/resume 循环（尤其 ep-laptop）
  - 日用 48 小时，记录任何问题
  - 如果发现 blocking issue → 回退到 v4（previous generation）

  **Must NOT do**:
  - 48h 内不要开始 Wave 2 的实际切换（可以准备代码）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (gate task)
  - **Parallel Group**: Wave 1 final
  - **Blocks**: Tasks 16-22 (Wave 3)
  - **Blocked By**: Task 10

  **References**:
  - 所有 Wave 1 产出

  **Acceptance Criteria**:
  - [ ] v5 bar 渲染正确（浮动、圆角、无 Clock widget）
  - [ ] `noctalia msg color-scheme-get` 返回有效 scheme
  - [ ] 所有 niri 快捷键功能正常
  - [ ] suspend/resume 后锁屏正常（desktop host）
  - [ ] howdy 在锁屏时触发并成功解锁
  - [ ] 48h 无 crash

  **QA Scenarios**:
  ```
  Scenario: 完整功能验证
    Tool: Bash
    Steps:
      1. pgrep noctalia
      2. noctalia msg color-scheme-get
      3. noctalia msg control-center toggle && sleep 1 && noctalia msg control-center toggle
      4. noctalia msg session lock && sleep 5
    Expected Result: 所有命令 exit code 0
    Evidence: .sisyphus/evidence/task-11-functional.txt

  Scenario: suspend/resume 存活
    Tool: Bash
    Steps:
      1. systemctl suspend
      2. (resume via power button)
      3. pgrep noctalia
      4. noctalia msg session-state
    Expected Result: noctalia 进程存在，session locked
    Evidence: .sisyphus/evidence/task-11-suspend.txt
  ```

  **Commit**: NO (gate task, no code changes)

- [ ] 12. 打包 Quickshell 为 Nix derivation

  **What to do**:
  - 根据 Task 4 调研结果，添加 Quickshell flake input 或使用 nixpkgs 包
  - 验证 `quickshell --version` 可用
  - 确认 SpringAnimation 和 PanelWindow（layer-shell）功能可用
  - 如果需要自定义 C++ plugin 编译，准备 CMake 构建环境

  **Must NOT do**:
  - 不要启动 Quickshell 实例（Task 13 做）
  - 不要修改 Noctalia 配置

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Wave 1 tasks)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 4, 6

  **References**:
  - `.sisyphus/drafts/quickshell-packaging.md` — Task 4 产出
  - https://quickshell.outfoxxed.me/ — 官方文档

  **Acceptance Criteria**:
  - [ ] `nix build` Quickshell 包成功
  - [ ] 输出包含 `bin/quickshell` 或 `bin/qs`

  **QA Scenarios**:
  ```
  Scenario: Quickshell 二进制可用
    Tool: Bash
    Steps:
      1. nix build <quickshell-derivation> --no-link --print-out-paths
      2. ls $(nix build <quickshell-derivation> --no-link --print-out-paths)/bin/
    Expected Result: 包含 quickshell 或 qs 二进制
    Evidence: .sisyphus/evidence/task-12-qs-binary.txt
  ```

  **Commit**: YES
  - Message: `feat(flake): add quickshell for dynamic island`
  - Files: `flake.nix`, `flake.lock`

- [ ] 13. 灵动岛骨架 - PanelWindow + idle 时钟

  **What to do**:
  - 创建 `modules/home/desktop/dynamic-island/` 目录结构：
    ```
    dynamic-island/
    ├── shell.qml          # Quickshell 入口
    ├── Island.qml         # 主 PanelWindow
    ├── states/
    │   └── IdleClock.qml  # idle 态：显示 HH:MM
    ├── components/
    │   └── Pill.qml       # 药丸形状容器
    └── default.nix        # Nix 模块（home.file 部署 + systemd service 声明）
    ```
  - `Island.qml` 核心属性：
    - `PanelWindow` / `WlrLayershell`
    - `layer: "top"`
    - `exclusiveZone: 0`
    - `anchors: top, horizontalCenter`
    - `margins.top`: 与 v5 bar 的 `margin_edge` 一致
    - 宽度 idle: ~160px，高度与 bar 同
  - `IdleClock.qml`: 显示 `HH:MM`，每分钟更新
  - 背景色、圆角与 v5 bar 一致（初始用静态 `colors.nix`，Task 20 接入动态）

  **Must NOT do**:
  - 不要实现动画（Task 18）
  - 不要实现其他状态（Task 16, 17）
  - 不要使用 GLSL shader
  - 不要超过 200 行 QML

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (after Task 12)
  - **Blocks**: Tasks 14, 15, 16, 17, 18, 19
  - **Blocked By**: Task 12

  **References**:
  - https://quickshell.outfoxxed.me/docs/types/quickshell.wayland/wlrlayershell/ — PanelWindow API
  - StatIndet/quickshell `AppShell.qml` — 结构参考
  - `lib/colors.nix` — 初始静态颜色

  **Acceptance Criteria**:
  - [ ] `quickshell -c ~/.config/quickshell/dynamic-island` 启动无报错
  - [ ] 屏幕顶部中央出现药丸形状显示时间
  - [ ] 窗口不被推下（exclusiveZone=0）
  - [ ] 药丸高度、圆角、背景色与 v5 bar 目视一致

  **QA Scenarios**:
  ```
  Scenario: 岛启动并显示时钟
    Tool: Bash
    Steps:
      1. quickshell -c ~/.config/quickshell/dynamic-island &
      2. sleep 2
      3. grim -g "$(slurp -p -f '%x %y %w %h')" /tmp/island-screenshot.png
      4. pgrep quickshell
    Expected Result: quickshell 进程存在，截图显示药丸
    Evidence: .sisyphus/evidence/task-13-island-screenshot.png

  Scenario: 不占 exclusive zone
    Tool: Bash
    Steps:
      1. niri msg --json windows | jq '.[0].geometry.y'
    Expected Result: y 值为 bar gap 大小，不包含灵动岛高度
    Evidence: .sisyphus/evidence/task-13-no-exclusive.txt
  ```

  **Commit**: YES
  - Message: `feat(island): initial scaffold with idle clock`
  - Files: `modules/home/desktop/dynamic-island/*`

- [ ] 14. 灵动岛 systemd service + kill switch

  **What to do**:
  - 在 `dynamic-island/default.nix` 中添加 `systemd.user.services.dynamic-island`
  - Service 配置：`After=noctalia.service`、`Restart=on-failure`、`MemoryMax=256M`
  - 添加 niri 快捷键 kill switch（如 `Super+Shift+I` toggle island visibility）
  - 实现 toggle 逻辑：发送 `SIGUSR1` 给 island 进程切换可见性

  **Must NOT do**:
  - 不要绑定到 graphical-session.target（用 noctalia.service 做 dependency）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (after Task 13)
  - **Blocks**: Tasks 16-22
  - **Blocked By**: Task 13

  **References**:
  - `modules/home/desktop/noctalia.nix:230-250` — 参考 v4 的 systemd service 模式
  - `modules/home/desktop/niri.nix` — 快捷键添加位置

  **Acceptance Criteria**:
  - [ ] `systemctl --user start dynamic-island` 启动成功
  - [ ] `systemctl --user status dynamic-island` 显示 active
  - [ ] kill switch 快捷键隐藏/显示 island
  - [ ] 进程崩溃后 systemd 自动重启

  **QA Scenarios**:
  ```
  Scenario: service 生命周期
    Tool: Bash
    Steps:
      1. systemctl --user start dynamic-island
      2. systemctl --user is-active dynamic-island
      3. kill -9 $(pgrep -f "quickshell.*dynamic-island")
      4. sleep 3
      5. systemctl --user is-active dynamic-island
    Expected Result: step 2 = "active", step 5 = "active"（自动重启）
    Evidence: .sisyphus/evidence/task-14-service-restart.txt
  ```

  **Commit**: YES
  - Message: `feat(island): systemd service + kill switch`
  - Files: `modules/home/desktop/dynamic-island/default.nix`, `modules/home/desktop/niri.nix`

- [ ] 15. 灵动岛与 v5 bar 视觉对齐调试

  **What to do**:
  - 对齐药丸的 `margin_top` 使其与 bar 看起来在同一水平线
  - 匹配 bar 高度（通过截图 + 像素对比）
  - 匹配 radius 曲率
  - 匹配背景色（从 v5 bar 实际渲染色采样对比）
  - 如果 bar 有 shadow，island 也加相同 shadow
  - 测试多种壁纸下的视觉一致性

  **Must NOT do**:
  - 不要改动 v5 bar 配置来迁就 island

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (after Tasks 10, 13)
  - **Blocks**: Tasks 16-22
  - **Blocked By**: Tasks 10, 13

  **References**:
  - Task 7 中 v5 bar 配置（`margin_edge`, `radius`, `background_opacity`）
  - Task 13 中 island 几何参数

  **Acceptance Criteria**:
  - [ ] 截图中 bar 与 island 在同一水平线（±1px）
  - [ ] 圆角曲率一致（目视）
  - [ ] 背景色一致（color picker 差值 < 5 in RGB）

  **QA Scenarios**:
  ```
  Scenario: 视觉对齐验证
    Tool: Bash
    Steps:
      1. grim /tmp/bar-island-alignment.png
      2. python3 -c "from PIL import Image; img=Image.open('/tmp/bar-island-alignment.png'); print(img.getpixel((960,10)), img.getpixel((960,30)))"
    Expected Result: 两个采样点颜色值接近（差值 < 5 per channel）
    Evidence: .sisyphus/evidence/task-15-alignment.png
  ```

  **Commit**: YES (groups with Task 13)
  - Message: `feat(island): visual alignment with v5 bar`
  - Files: `modules/home/desktop/dynamic-island/Island.qml`

- [ ] 16. 录制状态 - PID 监控 + red indicator + timer

  **What to do**:
  - 创建 `states/RecordingState.qml`
  - 实现进程监控：每 1s 轮询 `pgrep -x "wf-recorder|gpu-screen-recorder"`
  - 检测到录制进程：
    - 药丸展开为 compact trailing 形式（Apple 风格）
    - 左侧：红色圆点（闪烁动画）
    - 右侧：录制时长 `MM:SS`（Timer 每秒 +1）
  - 录制进程消失 → spring 收回到 idle
  - 状态机：`idle ↔ recording`（recording 优先级低于 notification）

  **Must NOT do**:
  - 不要监听 journal（用 PID 轮询）
  - 不要做暂停/停止按钮（只是指示器）
  - 不要超过 150 行 QML

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 17, 18, 19)
  - **Parallel Group**: Wave 3
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 14, 15, 18

  **References**:
  - `modules/home/desktop/noctalia.nix:22-76` — v4 录屏插件逻辑（mm:ss timer 参考）
  - Apple Dynamic Island — compact trailing 对齐模式
  - StatIndet/quickshell `Modules/` — 状态管理模式参考

  **Acceptance Criteria**:
  - [ ] `wf-recorder -f /tmp/t.mp4 &` → 2s 内药丸展开显示红点 + 00:00
  - [ ] 10s 后显示 00:10
  - [ ] `kill %1` → 1s 内 spring 收回 idle
  - [ ] 未录制时无红点残留

  **QA Scenarios**:
  ```
  Scenario: 录制检测 + 展开
    Tool: Bash
    Steps:
      1. wf-recorder -f /tmp/test-recording.mp4 &
      2. sleep 3
      3. grim -g "800,0 400x50" /tmp/island-recording.png
      4. kill %1
      5. sleep 2
      6. grim -g "800,0 400x50" /tmp/island-idle-after.png
    Expected Result: recording 截图可见红色区域；idle 截图无红色
    Evidence: .sisyphus/evidence/task-16-recording-state.png

  Scenario: 计时准确
    Tool: Bash
    Steps:
      1. wf-recorder -f /tmp/t.mp4 &
      2. sleep 65
      3. grim -g "800,0 400x50" /tmp/island-1min.png
      4. kill %1
    Expected Result: 截图显示 "01:0x" 格式时间
    Evidence: .sisyphus/evidence/task-16-timer-accuracy.png
  ```

  **Commit**: YES
  - Message: `feat(island): recording state with PID monitor`
  - Files: `modules/home/desktop/dynamic-island/states/RecordingState.qml`, `modules/home/desktop/dynamic-island/Island.qml`

- [ ] 17. 通知状态 - D-Bus listener + compact 展示

  **What to do**:
  - 创建 `states/NotificationState.qml`
  - 创建 `services/NotificationListener.qml` — 监听 `org.freedesktop.Notifications` D-Bus
  - 过滤：只响应 `app_name` 包含 "opencode" 或 "openclaw" 的通知
  - 展示形式（compact leading/trailing）：
    - 左侧：app icon（小圆图标）
    - 右侧：notification summary（单行，截断 30 字符）
  - 显示 4 秒后自动 spring 收回 idle
  - 优先级：notification > recording > idle

  **Must NOT do**:
  - 不要注册为 notification daemon（会与 v5 冲突）
  - 不要显示 body 内容（只 summary）
  - 不要支持交互（点击、关闭）
  - 不要超过 200 行 QML

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 16, 18, 19)
  - **Parallel Group**: Wave 3
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 14, 15, 18

  **References**:
  - Quickshell D-Bus QML integration文档
  - `org.freedesktop.Notifications` spec — Notify method signature
  - StatIndet/quickshell `Services/` — D-Bus 服务模式参考

  **Acceptance Criteria**:
  - [ ] `notify-send -a "opencode" "Task completed" "build done"` → 药丸展开显示 "Task completed"
  - [ ] 4s 后自动收回
  - [ ] `notify-send "Firefox" "Download done"` → 不触发（过滤非 opencode）
  - [ ] 录制中收到通知 → 通知覆盖录制显示 → 4s 后恢复录制态

  **QA Scenarios**:
  ```
  Scenario: OpenCode 通知触发
    Tool: Bash
    Steps:
      1. notify-send -a "opencode" "Build finished" "All tests pass"
      2. sleep 1
      3. grim -g "800,0 400x50" /tmp/island-notification.png
      4. sleep 5
      5. grim -g "800,0 400x50" /tmp/island-after-notif.png
    Expected Result: step 3 显示通知内容，step 5 回到 idle
    Evidence: .sisyphus/evidence/task-17-notification.png

  Scenario: 非 opencode 通知被忽略
    Tool: Bash
    Steps:
      1. notify-send -a "firefox" "Download complete"
      2. sleep 1
      3. grim -g "800,0 400x50" /tmp/island-ignored.png
    Expected Result: 药丸保持 idle 态（显示时钟）
    Evidence: .sisyphus/evidence/task-17-filter.png
  ```

  **Commit**: YES
  - Message: `feat(island): notification state for OpenCode`
  - Files: `modules/home/desktop/dynamic-island/states/NotificationState.qml`, `modules/home/desktop/dynamic-island/services/NotificationListener.qml`

- [ ] 18. Spring 动画系统 - 状态切换过渡

  **What to do**:
  - 创建 `components/SpringTransition.qml` — 封装 SpringAnimation 配置
  - 动画属性：width、height、radius、opacity
  - Spring 参数（按状态调整）：
    - idle→recording: `spring { mass: 1.0, stiffness: 300, damping: 20 }` (快速弹出)
    - recording→idle: `spring { mass: 1.0, stiffness: 200, damping: 25 }` (平滑收回)
    - idle→notification: `spring { mass: 0.8, stiffness: 350, damping: 18 }` (活泼弹出)
    - notification→idle: `spring { mass: 1.2, stiffness: 180, damping: 28 }` (优雅收回)
  - 内容 crossfade：状态切换时旧内容淡出 + 新内容淡入（200ms）
  - Apple 设计：内容从中心向外生长，不是左右拉伸

  **Must NOT do**:
  - 不要使用 GLSL shader
  - 不要做 3D 变换
  - 不要超过 100 行封装代码

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 16, 17, 19)
  - **Parallel Group**: Wave 3 (but should start earliest in wave)
  - **Blocks**: Tasks 16, 17, 21
  - **Blocked By**: Task 13

  **References**:
  - Qt QML SpringAnimation 文档 — mass/stiffness/damping 参数
  - Apple Human Interface Guidelines — Dynamic Island transitions
  - StatIndet/quickshell — 动画模式参考

  **Acceptance Criteria**:
  - [ ] 状态切换无掉帧（60fps 录制回放确认）
  - [ ] 展开时宽度从中心向两侧增长（不是锚定左边缘）
  - [ ] 收回有明显的弹性过冲（overshoot）
  - [ ] 不同状态的 spring 感觉不同（recording 快，notification 活泼）

  **QA Scenarios**:
  ```
  Scenario: 动画流畅度
    Tool: Bash
    Steps:
      1. wf-recorder -g "700,0 600x60" -f /tmp/anim-test.mp4 --codec=h264 -r 60 &
      2. sleep 1
      3. notify-send -a "opencode" "Test" "msg"
      4. sleep 6
      5. kill %1
      6. ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames /tmp/anim-test.mp4
    Expected Result: frame count / duration ≈ 60fps (±5)
    Evidence: .sisyphus/evidence/task-18-animation-fps.mp4
  ```

  **Commit**: YES
  - Message: `feat(island): spring animation system`
  - Files: `modules/home/desktop/dynamic-island/components/SpringTransition.qml`, `modules/home/desktop/dynamic-island/Island.qml`

- [ ] 19. Apple 对齐设计 - compact leading/trailing 布局

  **What to do**:
  - 实现 Apple Dynamic Island 的 compact 布局系统：
    - **Compact leading**: 左侧内容紧贴药丸左内壁
    - **Compact trailing**: 右侧内容紧贴药丸右内壁
    - **Content gravity**: 内容不居中，而是紧贴各自锚点
  - Idle 态：时间居中（例外：只有 idle 居中）
  - Recording 态：左=红点（leading），右=时间（trailing）
  - Notification 态：左=图标（leading），右=标题（trailing）
  - 内部 padding：与 Apple 一致（~12px 内边距，~8px 元素间距）
  - 文字截断：超长文本用 elide right（...）

  **Must NOT do**:
  - 不要做 expanded 展开态（MVP 只有 compact）
  - 不要做两端独立动画（统一药丸）

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 16, 17, 18)
  - **Parallel Group**: Wave 3
  - **Blocks**: Tasks 16, 17, 21
  - **Blocked By**: Task 13

  **References**:
  - Apple Human Interface Guidelines — Dynamic Island layout
  - Apple WWDC 2022/2023 — Live Activities 对齐原则

  **Acceptance Criteria**:
  - [ ] Recording 态：红点贴左壁，时间贴右壁（截图验证）
  - [ ] Notification 态：图标贴左壁，标题贴右壁
  - [ ] 长标题（>30 字符）正确截断显示 "..."
  - [ ] 内边距均匀（目视 ~12px）

  **QA Scenarios**:
  ```
  Scenario: compact 对齐正确
    Tool: Bash
    Steps:
      1. wf-recorder -f /tmp/t.mp4 & sleep 2
      2. grim -g "800,0 400x50" /tmp/island-compact.png
      3. kill %1
    Expected Result: 截图中红点在药丸最左，时间在最右
    Evidence: .sisyphus/evidence/task-19-compact-alignment.png

  Scenario: 长文本截断
    Tool: Bash
    Steps:
      1. notify-send -a "opencode" "This is an extremely long notification title that should be truncated"
      2. sleep 1
      3. grim -g "800,0 400x50" /tmp/island-elide.png
    Expected Result: 标题末尾显示 "..."
    Evidence: .sisyphus/evidence/task-19-text-elide.png
  ```

  **Commit**: YES (groups with Task 18)
  - Message: `feat(island): Apple compact leading/trailing layout`
  - Files: `modules/home/desktop/dynamic-island/states/*.qml`, `modules/home/desktop/dynamic-island/components/Pill.qml`

- [ ] 20. v5 颜色模板 + colors_changed hook 集成

  **What to do**:
  - 根据 Task 5 产出，在 v5 TOML 中配置颜色导出模板：
    - 输出到 `~/.config/dynamic-island/colors.json`
    - 包含字段：primary、onPrimary、surface、onSurface、error、background
  - 配置 `colors_changed` hook 发送 SIGUSR2 给灵动岛进程
  - 在 `Island.qml` 中实现：
    - FileSystemWatcher 监控 `colors.json`
    - 收到 SIGUSR2 或文件变化时重新加载颜色
    - 颜色变化时用 ColorAnimation（200ms ease）平滑过渡
  - 添加 fallback：如果 `colors.json` 不存在，使用 `lib/colors.nix` 的静态值
  - 添加 2s debounce（壁纸快速切换时不闪烁）

  **Must NOT do**:
  - 不要修改 `lib/colors.nix`
  - 不要轮询文件（用 watcher + signal）
  - 不要让颜色加载失败导致 crash

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 16-19)
  - **Parallel Group**: Wave 3
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 5, 10

  **References**:
  - `.sisyphus/drafts/v5-color-template.md` — Task 5 产出
  - https://docs.noctalia.dev/v5/theming/templates/ — v5 模板语法
  - `lib/colors.nix` — fallback 颜色值

  **Acceptance Criteria**:
  - [ ] 切换壁纸后 3s 内 `~/.config/dynamic-island/colors.json` 更新
  - [ ] 灵动岛背景色与 v5 bar 背景色一致（color picker 差值 < 5）
  - [ ] v5 未运行时灵动岛使用 fallback 颜色（不 crash）
  - [ ] 快速连续切换 3 张壁纸 → 只重新着色 1 次（debounce）

  **QA Scenarios**:
  ```
  Scenario: 颜色同步
    Tool: Bash
    Steps:
      1. noctalia msg wallpaper-set ~/wallpapers/moss-fern.jpg
      2. sleep 4
      3. cat ~/.config/dynamic-island/colors.json | jq .primary
      4. grim /tmp/color-sync.png
    Expected Result: colors.json 包含有效 hex 值；截图中 bar 和 island 颜色一致
    Evidence: .sisyphus/evidence/task-20-color-sync.json

  Scenario: debounce 生效
    Tool: Bash
    Steps:
      1. for f in ~/wallpapers/*.jpg; do noctalia msg wallpaper-set "$f"; sleep 0.3; done
      2. sleep 3
      3. stat -c %Y ~/.config/dynamic-island/colors.json
      4. sleep 3
      5. stat -c %Y ~/.config/dynamic-island/colors.json
    Expected Result: step 3 和 step 5 时间戳相同（文件未再次更新）
    Evidence: .sisyphus/evidence/task-20-debounce.txt
  ```

  **Commit**: YES
  - Message: `feat(island): v5 Material You color sync`
  - Files: `modules/home/desktop/noctalia.nix` (template 配置), `modules/home/desktop/dynamic-island/services/ColorSync.qml`

- [ ] 21. Howdy post-unlock 成功动画（Windows Hello 风格）

  **What to do**:
  - 创建 `states/HowdySuccess.qml`
  - 创建 `components/HelloEyes.qml` — Windows Hello 风格拟人化眼睛角色
  - 监控解锁事件：
    - 方式 A: 监听 `org.freedesktop.login1` D-Bus `Session.Unlock` signal
    - 方式 B: 监听 niri IPC session event
    - 方式 C: 监控 howdy 进程退出（exit code 0 = 成功）
  - 解锁成功时触发动画（1.5s total）：
    - **0-300ms**: 药丸 spring 微扩，两只"眼睛"淡入（Windows Hello 拟人化双眼）
    - **300-800ms**: 眼睛"注视"动画（瞳孔微动→锁定），模拟识别确认
    - **800-1200ms**: 眼睛"微笑"（眯起来，弧线变化），表示确认成功
    - **1200-1500ms**: 眼睛淡出 + 药丸 spring 收回 idle
  - 眼睛设计参考：
    - Windows Hello 的 password reveal icon 演化体（Luke Haddock 设计）
    - 两个椭圆形"眼睛"，内有瞳孔
    - 拟人化、友好感、非机械感
    - 纯 QML 绘制（Canvas/Path），不用外部图片
    - 颜色跟随 Material You primary 色
  - 只在 howdy 成功时触发（不是密码解锁）：检测 howdy 进程 exit code 0

  **Must NOT do**:
  - 不要在锁屏 surface 上渲染（协议不允许）
  - 不要做圆环/圆弧扫描动画（不是 Face ID 风格）
  - 不要用 checkmark 图标
  - 不要用绿色（用主题 primary 色）
  - 不要超过 200 行 QML
  - 不要做失败动画（howdy 失败时静默）

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with other Wave 3 tasks)
  - **Parallel Group**: Wave 3
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 18, 19

  **References**:
  - https://cargocollective.com/lukehaddock/Windows-Hello — Windows Hello 动画原始设计（Luke Haddock）
  - 设计原则："friendly character designed to put users at ease with facial recognition"
  - 状态：Search → Authentication（注视锁定）→ Success（眯眼微笑）
  - `org.freedesktop.login1` D-Bus interface — Session.Unlock signal

  **Acceptance Criteria**:
  - [ ] howdy 成功解锁后 500ms 内眼睛角色出现
  - [ ] 动画总时长 ~1.5s
  - [ ] 眼睛有"注视→微笑"的拟人化状态变化
  - [ ] 密码解锁不触发此动画
  - [ ] 动画结束后回到 idle 态（显示时钟）
  - [ ] 眼睛颜色跟随 Material You 主题 primary 色

  **QA Scenarios**:
  ```
  Scenario: howdy 解锁触发 Windows Hello 眼睛动画
    Tool: Bash
    Steps:
      1. wf-recorder -g "700,0 600x60" -f /tmp/howdy-anim.mp4 -r 60 &
      2. noctalia msg session lock
      3. sleep 5 (等待 howdy 解锁)
      4. sleep 2
      5. kill %1
      6. ffprobe -show_entries format=duration /tmp/howdy-anim.mp4
    Expected Result: 视频中可见拟人化眼睛出现→注视→微笑→消失
    Evidence: .sisyphus/evidence/task-21-howdy-animation.mp4

  Scenario: 密码解锁不触发
    Tool: Bash
    Steps:
      1. 遮住摄像头（阻止 howdy）
      2. noctalia msg session lock
      3. (手动输入密码解锁)
      4. sleep 1
      5. grim -g "800,0 400x50" /tmp/after-password.png
    Expected Result: 药丸直接回到 idle 时钟，无绿色动画
    Evidence: .sisyphus/evidence/task-21-no-anim-password.png
  ```

  **Commit**: YES
  - Message: `feat(island): howdy post-unlock success animation`
  - Files: `modules/home/desktop/dynamic-island/states/HowdySuccess.qml`

- [ ] 22. 全屏自动隐藏 + overview 隐藏

  **What to do**:
  - 监听 niri IPC：检测 focused window 是否全屏
  - 全屏时：island opacity → 0 (fade out 300ms)
  - 退出全屏：island opacity → 1 (fade in 300ms)
  - Niri overview 激活时（Super+O）：同样隐藏 island（避免遮挡 overview UI）
  - 实现方式：`niri msg --json event-stream` 或轮询 `niri msg --json focused-window`

  **Must NOT do**:
  - 不要用 destroy/recreate（用 opacity 动画）
  - 不要影响 systemd service 状态

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with other Wave 3 tasks)
  - **Parallel Group**: Wave 3
  - **Blocks**: F1-F4
  - **Blocked By**: Task 14

  **References**:
  - `modules/home/desktop/niri.nix` — niri IPC 使用模式
  - niri IPC 文档 — `niri msg --json focused-window` 输出格式

  **Acceptance Criteria**:
  - [ ] 全屏应用时 island 不可见
  - [ ] 退出全屏后 island 重新出现
  - [ ] niri overview 时 island 不遮挡

  **QA Scenarios**:
  ```
  Scenario: 全屏隐藏
    Tool: Bash
    Steps:
      1. grim -g "800,0 400x50" /tmp/before-fs.png
      2. niri msg action fullscreen-window
      3. sleep 1
      4. grim -g "800,0 400x50" /tmp/during-fs.png
      5. niri msg action fullscreen-window
      6. sleep 1
      7. grim -g "800,0 400x50" /tmp/after-fs.png
    Expected Result: during-fs 无 island；before/after 有 island
    Evidence: .sisyphus/evidence/task-22-fullscreen-hide.png
  ```

  **Commit**: YES
  - Message: `feat(island): auto-hide on fullscreen and overview`
  - Files: `modules/home/desktop/dynamic-island/services/FullscreenMonitor.qml`

---

## Final Verification Wave

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search codebase for forbidden patterns. Check evidence files exist.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `nix build` both hosts. Review QML for memory leaks (unanchored objects, animation loops). Check Nix for eval errors. Verify no `as any`, no hardcoded paths.
  Output: `Build [PASS/FAIL] | QML Quality [N issues] | Nix Quality [N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Execute EVERY QA scenario from EVERY task. Test cross-task integration. Edge cases: rapid wallpaper change, suspend/resume, fullscreen game, process crash recovery.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1. Check "Must NOT do" compliance. Flag scope creep.
  Output: `Tasks [N/N compliant] | Scope Creep [CLEAN/N issues] | VERDICT`

---

## Commit Strategy

| Wave | Commit | Files |
|------|--------|-------|
| 0 | `chore: remove dead noctalia-qs flake input` | flake.nix, flake.lock |
| 1 | `feat(desktop): migrate noctalia v4 → v5` | flake.nix, modules/home/desktop/noctalia.nix, modules/home/desktop/niri.nix |
| 2 | `feat(desktop): add dynamic island scaffold` | modules/home/desktop/dynamic-island/*, flake.nix |
| 3 | `feat(island): states + animation + color sync` | modules/home/desktop/dynamic-island/* |
| 3 | `feat(island): howdy post-unlock animation` | modules/home/desktop/dynamic-island/* |

---

## Success Criteria

### Verification Commands
```bash
# v5 running
pgrep noctalia && noctalia msg color-scheme-get

# Island running
systemctl --user is-active dynamic-island

# Island layer-shell correct (no exclusive zone)
# Windows start at y=0 (gap only, not pushed down by island)

# Color sync
noctalia msg wallpaper-set ~/wallpapers/moss-fern.jpg
sleep 3
cat ~/.config/dynamic-island/colors.json | jq .primary

# Recording state
wf-recorder -f /tmp/test.mp4 & sleep 2 && kill %1
# Island expanded during recording, contracted after

# Both hosts build
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
nix build .#nixosConfigurations.ep-laptop.config.system.build.toplevel
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] v5 bar + island visually unified
- [ ] Spring animations smooth (60fps, no jank)
- [ ] Survives 1-hour soak test (RSS < 100MB)
- [ ] Suspend/resume works on both hosts
- [ ] All niri keybinds functional
