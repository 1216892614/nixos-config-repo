# Noctalia v5 + Dynamic Island 部署指南

## 快速开始

```bash
# 1. 部署到当前系统
sudo nixos-rebuild switch --flake .#desktop

# 2. 验证服务
systemctl --user status dynamic-island
systemctl --user status noctalia

# 3. 测试功能
# - Super+P: 打开控制中心
# - Super+Ctrl+L: 锁屏（触发 howdy）
# - 切换壁纸: 观察颜色同步
```

## 详细步骤

### 前置检查

```bash
# 确认配置有效
nix flake check

# 预览将要构建的内容
nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run
```

### 安全部署流程

```bash
# 1. 备份当前配置
sudo cp -r /etc/nixos /etc/nixos.backup.$(date +%Y%m%d)

# 2. 测试构建（不激活）
sudo nixos-rebuild test --flake .#desktop
# 此时可以观察效果，但重启后会回滚

# 3. 确认测试通过后，正式部署
sudo nixos-rebuild switch --flake .#desktop
```

### 验证清单

#### 基础功能
- [ ] Noctalia v5 bar 显示（屏幕顶部）
- [ ] Dynamic Island 显示时钟（中央）
- [ ] 快捷键响应（Super+P, 音量键等）

#### Dynamic Island 功能
- [ ] 空闲态: 显示时间
- [ ] 录屏态: `wf-recorder -f /tmp/test.mp4` 触发红色指示
- [ ] Howdy 动画: 锁屏解锁后出现绿色眼睛
- [ ] 颜色同步: 切换壁纸后 3 秒内 island 颜色更新
- [ ] 全屏隐藏: 全屏应用时 island 自动隐藏

#### 服务状态
```bash
# 检查服务运行状态
systemctl --user status dynamic-island
systemctl --user status noctalia

# 查看日志
journalctl --user -u dynamic-island -n 50
journalctl --user -u noctalia -n 50
```

## 故障排查

### Island 未显示

```bash
# 检查 Quickshell 是否安装
which quickshell

# 手动启动查看错误
quickshell -c ~/.config/dynamic-island/shell.qml

# 检查 layer-shell 协议支持
echo $XDG_SESSION_TYPE  # 应该是 wayland
```

### 颜色不同步

```bash
# 检查模板文件
cat ~/.config/dynamic-island/colors.json

# 手动触发颜色更新
noctalia msg wallpaper-set ~/wallpapers/test.jpg
sleep 3
cat ~/.config/dynamic-island/colors.json  # 应该已更新
```

### Howdy 动画不出现

```bash
# 检查 howdy 是否工作
sudo howdy test

# 检查信号文件
ls -la /tmp/howdy-unlock-success

# 查看 PAM 模块日志
journalctl -u systemd-logind | grep howdy
```

### 性能问题

```bash
# 检查内存使用
ps aux | grep quickshell
# Island 应该 < 100MB

# 检查 CPU 使用
top -p $(pgrep quickshell)

# 如果占用过高，检查动画循环
journalctl --user -u dynamic-island | grep -i error
```

## 回滚步骤

如果出现严重问题：

```bash
# 方法 1: 回滚到上一代
sudo nixos-rebuild switch --rollback

# 方法 2: 选择特定代数
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <N>

# 方法 3: 从启动菜单选择旧配置
# 重启 → GRUB → 选择 "NixOS - Old" 条目
```

## 性能监控

### 首次部署后 48 小时监控

```bash
# 实时内存监控
watch -n 5 'ps aux | grep -E "noctalia|quickshell" | grep -v grep'

# 日志监控
journalctl --user -u dynamic-island -f

# 颜色同步压力测试
for i in {1..10}; do
  noctalia msg wallpaper-set ~/wallpapers/$(ls ~/wallpapers | shuf -n1)
  sleep 5
done
```

### 长期稳定性检查

```bash
# 每天检查一次
systemctl --user is-active dynamic-island noctalia

# 每周查看崩溃记录
journalctl --user -u dynamic-island --since "1 week ago" | grep -i "error\|crash\|fail"
```

## 已知限制

1. **锁屏渲染限制**: Howdy 动画只能在解锁后播放，无法在锁屏上显示（ext-session-lock-v1 协议限制）

2. **颜色同步延迟**: 首次切换壁纸后需要 2-3 秒完成取色，这是 Material You 算法的正常行为

3. **全屏检测延迟**: 全屏状态检测基于 Niri IPC，可能有 100-200ms 延迟

4. **内存占用**: Quickshell + QML 运行时约 50-80MB，这是预期行为

## 配置调整

### 修改 Island 位置

编辑 `modules/home/desktop/dynamic-island/shell.qml`:
```qml
anchors.top: parent.top  // 改为 bottom 可移到底部
anchors.topMargin: 5     // 调整垂直间距
```

### 修改动画速度

编辑 `modules/home/desktop/dynamic-island/components/SpringTransition.qml`:
```qml
duration: 800  // 毫秒，降低数值加快速度
```

### 禁用特定功能

编辑 `modules/home/desktop/dynamic-island/Island.qml`:
```qml
// 注释掉不需要的状态
// RecordingState { id: recordingState }
```

## 获取帮助

1. 查看完整测试报告: `.sisyphus/evidence/CONFIGURATION-TEST-REPORT.md`
2. 查看实现计划: `.sisyphus/plans/noctalia-v5-dynamic-island.md`
3. 查看已知问题: `.sisyphus/notepads/noctalia-v5-dynamic-island/issues.md`

## 成功标志

部署成功后，你应该看到：
- ✅ 顶部浮动圆角 bar（Noctalia v5）
- ✅ Bar 中央的药丸状 island 显示时间
- ✅ 颜色随壁纸自动调整
- ✅ 录屏时 island 变红并计时
- ✅ 解锁时短暂的绿色眼睛动画
- ✅ 流畅的弹性动画（60fps）

祝部署成功！🎉
