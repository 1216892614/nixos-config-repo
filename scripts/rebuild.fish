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

# 记录 clash-verge.service 当前启动时间戳，rebuild 后对比决定是否重启 GUI
set -l clash_active_pre (systemctl show clash-verge.service --property=ActiveEnterTimestamp --value 2>/dev/null)
set -l host (hostname)
sudo NIXOS_NO_CHECK=1 nixos-rebuild switch --flake $dst#$host
and begin
  # ── 重启可能被 rebuild 中断的用户服务 ──────────────────────────────────
  # home-manager 重载 systemd user units 时会 stop 正在运行的服务，
  # 但 graphical-session.target 不会重新触发，导致桌面组件消失。
  systemctl --user daemon-reload
  systemctl --user restart noctalia-shell 2>/dev/null
  systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null
  systemctl --user restart service-plane 2>/dev/null

  # 仅在 clash-verge.service 被 rebuild 重启时才重启 GUI
  # 比较 service 启动时间戳：rebuild 前记录的 vs 当前的
  set -l clash_active_new (systemctl show clash-verge.service --property=ActiveEnterTimestamp --value 2>/dev/null)
  if test "$clash_active_pre" != "$clash_active_new"
    # service 确实重启了，GUI 失去连接需要杀掉重来
    pkill -u (id -u) -f clash-verge 2>/dev/null
    sleep 1
    nohup clash-verge &>/dev/null &
    echo "  clash-verge: service restarted, GUI relaunched"
  else
    echo "  clash-verge: service unchanged, skipping GUI restart"
  end

  # 重启 fcitx5：rebuild 可能更新了二进制路径或配置，
  # 干净重启避免 D-Bus name 冲突或 Wayland IM 前端断连
  pkill -u (id -u) fcitx5 2>/dev/null
  sleep 1
  fcitx5 -d 2>/dev/null
  echo "✓ rebuild complete, services restarted"
end
