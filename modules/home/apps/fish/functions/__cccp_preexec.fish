# cccp 本身不能覆盖上一条命令的输出边界，允许连续复制。
if string match -qr '^\s*cccp(?:\s|$)' -- "$argv[1]"
  return
end
# 记录命令执行前日志文件的字节偏移
if set -q __CCCP_SCRIPT_LOG; and test -f $__CCCP_SCRIPT_LOG
  set -g __CCCP_PRE_OFFSET (command wc -c < $__CCCP_SCRIPT_LOG | string trim)
end
