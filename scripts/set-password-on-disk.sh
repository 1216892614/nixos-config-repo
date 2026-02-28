#!/usr/bin/env bash
# 在 NixOS live 环境执行：挂载目标硬盘并为 ep-o1 设置密码（密码不写入任何配置文件）
# 用法：在 live 终端里执行：
#   ./set-password-on-disk.sh '你的密码'
# 或：  NIXOS_LIVE_PASS='你的密码' ./set-password-on-disk.sh

set -euo pipefail

ROOT_UUID="e852f332-37d9-43cc-9363-9e7c4fa2911e"
BOOT_UUID="018C-6411"
USER="ep-o1"
PASS="${1:-${NIXOS_LIVE_PASS:?请提供密码: ./set-password-on-disk.sh \"你的密码\"}}"

echo "→ 挂载根分区到 /mnt"
sudo mkdir -p /mnt
sudo mount "/dev/disk/by-uuid/$ROOT_UUID" /mnt
sudo mkdir -p /mnt/boot
sudo mount "/dev/disk/by-uuid/$BOOT_UUID" /mnt/boot 2>/dev/null || true

echo "→ 在目标系统上设置用户 $USER 密码（仅写入 /mnt/etc/shadow）"
echo "${USER}:${PASS}" | sudo chpasswd -R /mnt

echo "→ 验证（shadow 第二段应为加密哈希而非 !）"
sudo grep "^${USER}:" /mnt/etc/shadow

echo "→ 卸载"
sudo umount /mnt/boot 2>/dev/null || true
sudo umount /mnt

echo "完成。密码已写入目标硬盘，未写入任何 nix 配置。"
