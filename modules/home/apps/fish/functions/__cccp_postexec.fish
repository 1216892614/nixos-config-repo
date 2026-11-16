if string match -qr '^\s*cccp(?:\s|$)' -- "$argv[1]"
  return
end
# 记录命令执行后日志文件的字节偏移
if set -q __CCCP_SCRIPT_LOG; and test -f $__CCCP_SCRIPT_LOG
  set -g __CCCP_POST_OFFSET (command wc -c < $__CCCP_SCRIPT_LOG | string trim)
end
