#!/usr/bin/env bash
export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset WAYLAND_DISPLAY
export DISPLAY="${DISPLAY:-:0}"
exec "$HOME/.local/lib/jdk21/bin/java" "$@"
