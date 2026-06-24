#!/usr/bin/env bash
set -euo pipefail

echo "=== NixOS 配置完整性测试 ==="
echo

# 1. Desktop host 构建测试
echo "▶ 测试 1: Desktop host 构建"
if nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run 2>&1 | tee /tmp/desktop-build.log; then
  echo "✓ Desktop 配置语法正确"
else
  echo "✗ Desktop 配置有错误"
  cat /tmp/desktop-build.log
  exit 1
fi
echo

# 2. Laptop host 构建测试
echo "▶ 测试 2: Laptop host 构建"
if nix build .#nixosConfigurations.ep-laptop.config.system.build.toplevel --dry-run 2>&1 | tee /tmp/laptop-build.log; then
  echo "✓ Laptop 配置语法正确"
else
  echo "✗ Laptop 配置有错误"
  cat /tmp/laptop-build.log
  exit 1
fi
echo

# 3. Noctalia 模块检查
echo "▶ 测试 3: Noctalia v5 配置"
if nix eval .#nixosConfigurations.desktop.config.programs.noctalia.enable --raw 2>/dev/null | grep -q "true"; then
  echo "✓ Noctalia 已启用"
  
  # 检查配置文件生成
  if nix eval .#nixosConfigurations.desktop.config.programs.noctalia.settings --json >/dev/null 2>&1; then
    echo "✓ Noctalia TOML 配置可以求值"
  else
    echo "⚠ Noctalia 配置求值失败"
  fi
else
  echo "⚠ Noctalia 未启用"
fi
echo

# 4. Dynamic Island 模块检查
echo "▶ 测试 4: Dynamic Island 配置"
if nix eval .#nixosConfigurations.desktop.config.home-manager.users.ep-o1.programs.dynamic-island.enable --raw 2>/dev/null | grep -q "true"; then
  echo "✓ Dynamic Island 已启用"
else
  echo "⚠ Dynamic Island 未找到（可能路径不同）"
fi
echo

# 5. Niri 配置检查
echo "▶ 测试 5: Niri 窗口管理器"
if nix eval .#nixosConfigurations.desktop.config.programs.niri.enable --raw 2>/dev/null | grep -q "true"; then
  echo "✓ Niri 已启用"
else
  echo "⚠ Niri 未启用"
fi
echo

# 6. 关键服务检查
echo "▶ 测试 6: 系统服务配置"
services=("howdy" "greetd")
for svc in "${services[@]}"; do
  if nix eval ".#nixosConfigurations.desktop.config.services.$svc.enable" --raw 2>/dev/null | grep -q "true"; then
    echo "✓ $svc 已配置"
  else
    echo "⚠ $svc 未启用或未找到"
  fi
done
echo

# 7. 模块导入完整性
echo "▶ 测试 7: 模块导入检查"
if nix eval .#nixosConfigurations.desktop.config.system.stateVersion --raw >/dev/null 2>&1; then
  echo "✓ 模块导入链正确"
else
  echo "✗ 模块导入有问题"
  exit 1
fi
echo

# 8. Home Manager 配置
echo "▶ 测试 8: Home Manager 集成"
if nix eval .#nixosConfigurations.desktop.config.home-manager.users.ep-o1.home.stateVersion --raw >/dev/null 2>&1; then
  echo "✓ Home Manager 配置正确"
else
  echo "✗ Home Manager 配置有问题"
  exit 1
fi
echo

# 9. 依赖解析测试
echo "▶ 测试 9: Flake 输入完整性"
inputs=("noctalia" "niri" "home-manager" "walker")
for input in "${inputs[@]}"; do
  if nix flake metadata ".#$input" >/dev/null 2>&1; then
    echo "✓ $input 输入可访问"
  else
    echo "⚠ $input 输入检查失败"
  fi
done
echo

echo "=== 测试总结 ==="
echo "✓ 配置语法检查通过"
echo "⚠ 部分功能需要实际部署后验证"
echo
echo "下一步: sudo nixos-rebuild switch --flake .#desktop"
