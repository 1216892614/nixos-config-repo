#!/usr/bin/env fish
set -l src /home/ep-o1/nixos-config-repo
set -l dst /etc/nixos

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

sudo nixos-rebuild switch --flake $dst#desktop
