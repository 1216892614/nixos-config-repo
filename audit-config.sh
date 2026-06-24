#!/usr/bin/env bash
set -euo pipefail

echo "=== 深度配置审计 ==="
echo

# 1. Noctalia 配置详情
echo "▶ Noctalia v5 配置详情"
echo "检查 modules/home/desktop/noctalia.nix..."
if [ -f modules/home/desktop/noctalia.nix ]; then
  echo "✓ 文件存在"
  
  # 检查关键配置项
  if grep -q "programs.noctalia.enable = true" modules/home/desktop/noctalia.nix; then
    echo "✓ Noctalia 已启用"
  fi
  
  if grep -q "settings =" modules/home/desktop/noctalia.nix; then
    echo "✓ TOML 设置已定义"
  fi
  
  if grep -q "templates" modules/home/desktop/noctalia.nix; then
    echo "✓ 模板系统已配置"
  fi
  
  if grep -q "color" modules/home/desktop/noctalia.nix; then
    echo "✓ 颜色系统已配置"
  fi
else
  echo "✗ Noctalia 配置文件缺失"
fi
echo

# 2. Dynamic Island 配置
echo "▶ Dynamic Island 配置审计"
if [ -d modules/home/desktop/dynamic-island ]; then
  echo "✓ Dynamic Island 目录存在"
  
  echo "  文件结构:"
  tree -L 2 modules/home/desktop/dynamic-island/ || find modules/home/desktop/dynamic-island/ -type f
  
  echo
  echo "  QML 组件:"
  find modules/home/desktop/dynamic-island/ -name "*.qml" | while read f; do
    echo "    - $(basename $f)"
  done
  
  echo
  echo "  关键配置:"
  if [ -f modules/home/desktop/dynamic-island/default.nix ]; then
    if grep -q "systemd.user.services.dynamic-island" modules/home/desktop/dynamic-island/default.nix; then
      echo "    ✓ systemd service 已定义"
    fi
  fi
else
  echo "✗ Dynamic Island 目录不存在"
fi
echo

# 3. Niri 配置检查
echo "▶ Niri 配置审计"
if [ -f modules/home/desktop/niri.nix ]; then
  echo "✓ Niri 配置文件存在"
  
  # 检查 v5 IPC 命令
  if grep -q "noctalia msg" modules/home/desktop/niri.nix; then
    echo "✓ v5 IPC 命令已更新"
    echo "  发现的命令:"
    grep -o "noctalia msg [a-z-]*" modules/home/desktop/niri.nix | sort -u | head -5
  else
    echo "⚠ 未找到 v5 IPC 命令（可能使用其他调用方式）"
  fi
else
  echo "✗ Niri 配置文件缺失"
fi
echo

# 4. 颜色同步检查
echo "▶ 颜色同步机制"
echo "检查模板文件..."
if [ -f modules/home/desktop/noctalia.nix ]; then
  if grep -A 5 "templates" modules/home/desktop/noctalia.nix | grep -q "dynamic-island"; then
    echo "✓ Dynamic Island 颜色模板已配置"
  else
    echo "⚠ Dynamic Island 模板未明确配置"
  fi
fi
echo

# 5. Systemd 服务检查
echo "▶ Systemd 服务配置"
services=(
  "dynamic-island"
  "noctalia"
)

for svc in "${services[@]}"; do
  if grep -r "systemd.user.services.$svc" modules/ >/dev/null 2>&1; then
    echo "✓ $svc.service 已定义"
    
    # 检查依赖关系
    if grep -A 10 "systemd.user.services.$svc" modules/ | grep -q "after"; then
      echo "  - 包含依赖关系"
    fi
    
    if grep -A 10 "systemd.user.services.$svc" modules/ | grep -q "wantedBy"; then
      echo "  - 自动启动已配置"
    fi
  else
    echo "⚠ $svc.service 未找到"
  fi
done
echo

# 6. Howdy 集成检查
echo "▶ Howdy 解锁动画"
if [ -d modules/home/desktop/dynamic-island ]; then
  if find modules/home/desktop/dynamic-island -name "*howdy*" -o -name "*Howdy*" | grep -q .; then
    echo "✓ Howdy 相关文件存在"
    find modules/home/desktop/dynamic-island -name "*howdy*" -o -name "*Howdy*" | while read f; do
      echo "  - $f"
    done
  else
    echo "⚠ 未找到 Howdy 动画文件"
  fi
fi
echo

# 7. 录屏状态指示
echo "▶ 屏幕录制状态"
if find modules/home/desktop/dynamic-island -type f -exec grep -l "wf-recorder\|recording\|Recording" {} \; | grep -q .; then
  echo "✓ 录屏状态监控已实现"
  echo "  相关文件:"
  find modules/home/desktop/dynamic-island -type f -exec grep -l "recording" {} \; | head -3
else
  echo "⚠ 未找到录屏状态代码"
fi
echo

# 8. 配置冲突检查
echo "▶ 配置冲突检查"
conflicts=0

# 检查是否有遗留的 v4 配置
if grep -r "noctalia-v4\|noctalia.*v4" modules/ 2>/dev/null; then
  echo "⚠ 发现 v4 遗留引用"
  conflicts=$((conflicts + 1))
fi

# 检查是否有多个 bar 配置
bar_count=$(grep -r "programs.noctalia" modules/ 2>/dev/null | grep -c "enable" || true)
if [ "$bar_count" -gt 1 ]; then
  echo "⚠ 发现多个 noctalia 启用点 ($bar_count)"
  conflicts=$((conflicts + 1))
fi

if [ $conflicts -eq 0 ]; then
  echo "✓ 未发现明显冲突"
fi
echo

# 9. 构建缓存检查
echo "▶ 构建缓存状态"
if [ -d result ]; then
  echo "✓ 存在构建结果链接"
  ls -lh result/
else
  echo "⚠ 未找到构建结果（需要运行 nix build）"
fi
echo

# 10. Git 状态
echo "▶ Git 工作树状态"
git status --short | head -20
echo "  变更文件数: $(git status --short | wc -l)"
echo

echo "=== 审计完成 ==="
echo
echo "建议操作："
echo "1. 提交当前变更: git add -A && git commit -m 'feat: noctalia v5 + dynamic island'"
echo "2. 备份当前配置: cp -r /etc/nixos /tmp/nixos-backup-\$(date +%Y%m%d)"
echo "3. 部署测试: sudo nixos-rebuild test --flake .#desktop"
echo "4. 正式部署: sudo nixos-rebuild switch --flake .#desktop"
