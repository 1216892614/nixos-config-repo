# cccp — 复制上一条命令的输出到剪贴板
# 依赖 script 会话录制和 preexec/postexec 记录的偏移量

if not set -q __CCCP_SCRIPT_LOG; or not test -f $__CCCP_SCRIPT_LOG
  echo "cccp: 未检测到 script 会话录制，无法捕获输出" >&2
  return 1
end

if not set -q __CCCP_PRE_OFFSET; or not set -q __CCCP_POST_OFFSET
  echo "cccp: 没有可用的上一条命令输出" >&2
  return 1
end

if test "$__CCCP_PRE_OFFSET" -ge "$__CCCP_POST_OFFSET"
  echo "cccp: 上一条命令没有产生输出" >&2
  return 1
end

set -l count (math $__CCCP_POST_OFFSET - $__CCCP_PRE_OFFSET)

# 提取并清理：dd 取字节切片 → 去 ANSI/CR → 去首尾空行 → 写入临时文件
set -l tmpf (mktemp -t cccp_out.XXXXXX)
command dd if=$__CCCP_SCRIPT_LOG bs=1 skip=$__CCCP_PRE_OFFSET count=$count 2>/dev/null \
  | command sed -E 's/\x1b\][^\x07\x1b]*(\x07|\x1b[\\])//g; s/\x1b\[[0-?]*[ -/]*[@-~]//g; s/\r//g' \
  | command sed '/./,$!d' \
  | command sed -e :a -e '/^$/{ $d; N; ba; }' > $tmpf

if not test -s $tmpf
  command rm -f $tmpf
  echo "cccp: 上一条命令没有可复制的输出" >&2
  return 1
end

wl-copy < $tmpf
set -l lines (command wc -l < $tmpf | string trim)
command rm -f $tmpf
echo "cccp: 已复制 $lines 行到剪贴板 ✓"
