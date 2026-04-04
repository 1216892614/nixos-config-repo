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

sudo nixos-rebuild switch --flake $dst#desktop
and systemctl --user restart pipewire wireplumber 2>/dev/null
