#!/usr/bin/env bash
# 在 live 环境挂载硬盘并检查用户 ep-o1 密码是否设置成功
# 用法: ./scripts/live-check-password.sh [user@live-host]
# 示例: ./scripts/live-check-password.sh nixos@192.168.1.100

set -euo pipefail

LIVE_HOST="${1:-${LIVE_HOST:?指定 live 主机，例如: nixos@192.168.1.100}}"
ROOT_UUID="e852f332-37d9-43cc-9363-9e7c4fa2911e"
BOOT_UUID="018C-6411"
MOUNT="/mnt"
USER="ep-o1"

echo "→ SSH 到 live: $LIVE_HOST"
ssh "$LIVE_HOST" bash -s -- "$ROOT_UUID" "$BOOT_UUID" "$MOUNT" "$USER" << 'REMOTE'
set -euo pipefail
ROOT_UUID=$1
BOOT_UUID=$2
MOUNT=$3
USER=$4

ROOT_DEV="/dev/disk/by-uuid/$ROOT_UUID"
BOOT_DEV="/dev/disk/by-uuid/$BOOT_UUID"

if [[ ! -b "$ROOT_DEV" ]]; then
  echo "错误: 未找到根分区 $ROOT_DEV"
  ls -la /dev/disk/by-uuid/ 2>/dev/null || true
  exit 1
fi

echo "→ 挂载根分区 $ROOT_DEV -> $MOUNT"
sudo mkdir -p "$MOUNT"
sudo mount "$ROOT_DEV" "$MOUNT"

if [[ -b "$BOOT_DEV" ]]; then
  echo "→ 挂载 boot $BOOT_DEV -> $MOUNT/boot"
  sudo mkdir -p "$MOUNT/boot"
  sudo mount "$BOOT_DEV" "$MOUNT/boot"
fi

echo "→ 绑定 dev/sys/proc 以便 chroot"
sudo mount --bind /dev  "$MOUNT/dev"
sudo mount --bind /proc "$MOUNT/proc"
sudo mount --bind /sys  "$MOUNT/sys"

cleanup() {
  echo "→ 卸载并清理"
  sudo umount -R "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT

echo "→ 在 chroot 中检查用户 $USER 密码状态"
sudo chroot "$MOUNT" passwd -S "$USER" 2>/dev/null || {
  echo "用户 $USER 可能不存在于已安装系统中"
  sudo chroot "$MOUNT" cat /etc/passwd | grep -E "^$USER:" || true
  exit 1
}
REMOTE

echo ""
echo "说明: passwd -S 输出中 P = 已设置密码, NP = 未设置密码, L = 锁定"
