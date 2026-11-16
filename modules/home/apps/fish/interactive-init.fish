# Zellij completions (dynamic subcommands like `zellij attach <tab>`)
eval (zellij setup --generate-completion fish | string collect)

# howdy 已安装但未录入人脸时提醒初始化
if command -sq howdy
  and test -d /var/lib/howdy/models
  and test (count (fd -e dat . /var/lib/howdy/models/ 2>/dev/null)) -eq 0
  set_color yellow
  echo "[howdy] 未录入人脸模型，面部识别不可用。请运行："
  echo "  ir-emitter-cfg  # 如果 IR emitter 需要配置"
  echo "  sudo howdy add"
  set_color normal
end

# ── cccp: 捕获上一条命令输出 ──
# 利用 script 录制终端输出到日志文件，preexec/postexec 记录偏移量
if not set -q __CCCP_SCRIPT_LOG
  set -gx __CCCP_SCRIPT_LOG (mktemp -t "fish_cccp.XXXXXX")
  # 在非嵌套 script 时，重新 exec 进 script 会话
  if not set -q __CCCP_INSIDE_SCRIPT
    set -gx __CCCP_INSIDE_SCRIPT 1
    exec script -q -f $__CCCP_SCRIPT_LOG
  end
end
