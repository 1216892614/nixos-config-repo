argparse 'n/name=' -- $argv
or begin
  echo "usage: lo [-n|--name <name>] [<cols>x<rows>]" >&2
  return 1
end

if test (count $argv) -gt 1
  echo "usage: lo [-n|--name <name>] [<cols>x<rows>]" >&2
  return 1
end

if not command -sq zellij
  echo "lo: zellij not found in PATH" >&2
  return 127
end

set -l spec 2x2
if test (count $argv) -gt 0
  set spec $argv[1]
end

if not string match -rq '^[1-9][0-9]*x[1-9][0-9]*$' -- "$spec"
  echo "lo: invalid layout spec: $spec" >&2
  echo "usage: lo [-n|--name <name>] [<cols>x<rows>]" >&2
  return 1
end

# 默认名称: "布局 <spec>"
set -l session_name "布局 $spec"
if set -q _flag_name
  set session_name "$_flag_name"
end

set -l launcher "$HOME/.local/bin/lo-launch"
if not test -x "$launcher"
  echo "lo: helper not found or not executable: $launcher" >&2
  return 1
end

command "$launcher" "$spec" "$session_name"
return $status
