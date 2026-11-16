if test (count $argv) -ne 0
  echo "usage: omo" >&2
  return 1
end

for cmd in zellij opencode
  if not command -sq $cmd
    echo "omo: required command not found: $cmd" >&2
    return 127
  end
end

set -l launcher "$HOME/.local/bin/omo-launch"
if not test -x "$launcher"
  echo "omo: helper not found or not executable: $launcher" >&2
  return 1
end

command "$launcher"
return $status
