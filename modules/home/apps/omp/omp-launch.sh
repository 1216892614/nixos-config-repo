    #!/usr/bin/env bash
    set -euo pipefail

    if [ "$#" -gt 1 ]; then
      echo "usage: omp-launch [<cols>x<rows>]" >&2
      exit 1
    fi

    for cmd in zellij omp mktemp; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "omp-launch: required command not found: $cmd" >&2
        exit 127
      fi
    done

    cols=1
    rows=1
    if [ "$#" -eq 1 ]; then
      spec="$1"
      if [[ ! "$spec" =~ ^([1-9][0-9]*)x([1-9][0-9]*)$ ]]; then
        echo "omp-launch: invalid layout spec: $spec" >&2
        echo "usage: omp-launch [<cols>x<rows>]" >&2
        exit 1
      fi
      cols="${BASH_REMATCH[1]}"
      rows="${BASH_REMATCH[2]}"
    fi

    cwd="$PWD"
    layout_file="$(mktemp /tmp/omp-layout-XXXXXX.kdl)"
    cleanup() {
      rm -f "$layout_file"
    }
    trap cleanup EXIT

    OMP_CWD="$cwd" OMP_COLS="$cols" OMP_ROWS="$rows" "@python3@/bin/python3" - <<'PY' >"$layout_file"
import os

cwd = os.environ["OMP_CWD"]
cols = int(os.environ["OMP_COLS"])
rows = int(os.environ["OMP_ROWS"])

def q(value: str) -> str:
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

def emit_grid(indent: str, cols: int, rows: int) -> None:
    print(f'{indent}pane split_direction="horizontal" {{')
    for _ in range(cols):
        print(f'{indent}    pane split_direction="vertical" {{')
        for _ in range(rows):
            print(f'{indent}        pane command="omp" close_on_exit=true')
        print(f'{indent}    }}')
    print(f'{indent}}}')

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
print(f'    tab name="pi" focus=true cwd={q(cwd)} {{')
emit_grid("        ", cols, rows)
print("    }")
print("}")
PY

    if [ -n "${ZELLIJ:-}" ]; then
      command zellij action new-tab --layout "$layout_file" --cwd "$cwd"
    else
      command zellij --layout "$layout_file"
    fi
