    #!/usr/bin/env bash
    set -euo pipefail

    if [ "$#" -ne 0 ]; then
      echo "usage: omo" >&2
      exit 1
    fi

    for cmd in zellij mktemp ss awk grep; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "omo: required command not found: $cmd" >&2
        exit 127
      fi
    done

    cwd="$PWD"
    helper_dir="@home@/.local/bin"
    for helper in "$helper_dir/omo-server" "$helper_dir/omo-client" "$helper_dir/omo-supervisor"; do
      if [ ! -x "$helper" ]; then
        echo "omo: helper not found or not executable: $helper" >&2
        exit 1
      fi
    done

    layout_file="$(mktemp /tmp/omo-layout-XXXXXX.kdl)"
    cleanup() {
      rm -f "$layout_file"
    }
    trap cleanup EXIT

    find_port() {
      local candidate
      for _ in $(seq 1 200); do
        candidate="$(shuf -i 20000-65000 -n 1)"
        if ! ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$candidate$"; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
      return 1
    }

    port="$(find_port)" || {
      echo "omo: failed to find a free TCP port" >&2
      exit 1
    }

    OMO_CWD="$cwd" OMO_PORT="$port" OMO_HOME="@home@" "@python3@/bin/python3" - <<'PY' >"$layout_file"
import os

cwd = os.environ["OMO_CWD"]
port = os.environ["OMO_PORT"]
home = os.environ["OMO_HOME"]

client = f'{home}/.local/bin/omo-client'
supervisor = f'{home}/.local/bin/omo-supervisor'

def q(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

print("layout {")
print("    default_tab_template {")
print('        pane size=1 borderless=true {')
print('            plugin location="zellij:tab-bar"')
print("        }")
print("        children")
print('        pane size=1 borderless=true {')
print('            plugin location="zellij:status-bar"')
print("        }")
print("    }")
print(f'    tab name="omo" focus=true cwd={q(cwd)} {{')
print('        pane split_direction="horizontal" {')
print('            pane split_direction="vertical" {')
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print("            }")
print('            pane split_direction="vertical" {')
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print("            }")
print("        }")
print("    }")
print(f'    tab name="fish" cwd={q(cwd)} {{')
print('        pane split_direction="horizontal" {')
print('            pane split_direction="vertical" {')
print(f'                pane command={q(supervisor)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print("            }")
print('            pane split_direction="vertical" {')
print(f'                pane command={q(client)} {{')
print(f'                    args {q(port)} {q(cwd)}')
print("                }")
print("                pane")
print("            }")
print("        }")
print("    }")
print("}")
PY

    command zellij --layout "$layout_file"
