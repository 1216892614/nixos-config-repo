#!/bin/bash
set -eu
export HOME="/home/user"
WORKSPACE="$HOME/comfy/workspace"
VENV="$WORKSPACE/.venv"

# 补全依赖（pytorch 镜像缺 git 和 python3-venv）
if ! command -v git &>/dev/null || [ ! -f /usr/lib/python3.12/ensurepip/__init__.py ]; then
  apt-get update -qq && apt-get install -y -qq git python3.12-venv >/dev/null
fi

# 激活 workspace venv（如存在）
if [ -f "$VENV/bin/activate" ]; then
  source "$VENV/bin/activate"
fi

# 确保 comfy-cli 可用（workspace venv 持久化，只需装一次）
if ! command -v comfy &>/dev/null; then
  echo "[comfyui] 安装 comfy-cli 到 workspace venv..."
  pip install --break-system-packages comfy-cli 2>/dev/null || pip install comfy-cli
fi

# 首次启动：安装 ComfyUI
if [ ! -f "$HOME/comfy/.installed" ]; then
  echo "[comfyui] 首次启动，安装 ComfyUI（最新版）..."
  comfy --workspace="$WORKSPACE" install --nvidia --skip-manager
  touch "$HOME/comfy/.installed"
fi

# 每次启动检查更新
echo "[comfyui] 检查更新..."
comfy --workspace="$WORKSPACE" update 2>/dev/null || true

echo "[comfyui] 启动 ComfyUI..."
exec comfy --workspace="$WORKSPACE" launch -- --listen 0.0.0.0 --port 8188
