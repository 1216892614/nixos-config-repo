#!/usr/bin/env fish
set -l src /home/ep-o1/nixos-config-repo
set -l dst /etc/nixos

if test (id -u) -eq 0
  echo "Run this script as your normal user, not via sudo."
  exit 1
end

if not test -d $src
  echo "Source repo not found: $src"
  exit 1
end

sudo rsync -a --delete \
  --exclude .git \
  --exclude result \
  --exclude 'result-*' \
  --exclude .direnv \
  $src/ $dst/

sudo systemctl stop nixos-rebuild-switch-to-configuration.service >/dev/null 2>&1
sudo systemctl reset-failed nixos-rebuild-switch-to-configuration.service >/dev/null 2>&1
sudo systemctl daemon-reload >/dev/null 2>&1

set -l host (hostname)
sudo nixos-rebuild switch --flake $dst#$host
and begin
  # ── 重启可能被 rebuild 中断的用户服务 ──────────────────────────────────
  # home-manager 重载 systemd user units 时会 stop 正在运行的服务，
  # 但 graphical-session.target 不会重新触发，导致桌面组件消失。
  systemctl --user daemon-reload
  systemctl --user restart noctalia-shell 2>/dev/null
  systemctl --user restart pipewire wireplumber 2>/dev/null
  systemctl --user restart service-plane 2>/dev/null

  # 重启 fcitx5：rebuild 可能更新了二进制路径或配置，
  # 干净重启避免 D-Bus name 冲突或 Wayland IM 前端断连
  pkill -u (id -u) fcitx5 2>/dev/null
  sleep 1
  fcitx5 -d 2>/dev/null
  echo "✓ rebuild complete, services restarted"
end
