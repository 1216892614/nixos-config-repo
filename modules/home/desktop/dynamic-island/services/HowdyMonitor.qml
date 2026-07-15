import Quickshell
import Quickshell.Io
import QtQuick

// Howdy 进程检测：pgrep -x howdy，500ms 轮询
Item {
  id: root
  visible: false
  width: 0; height: 0

  property bool active: false      // howdy 正在运行
  property int exitCode: -1        // 上次退出码（0=成功, 其他=失败）
  property bool hasResult: false   // 刚刚结束，有结果待展示

  Process {
    id: pgrepProc
    command: ["pgrep", "-x", "howdy"]
    onExited: (code, status) => {
      var wasActive = root.active
      root.active = (code === 0)

      // 从 active → inactive：howdy 结束
      if (wasActive && !root.active) {
        root.hasResult = true
        // 需要另一种方式获取退出码 — howdy 本身的退出码
        // pgrep 只能告知进程是否存在
        // 使用 howdy exit 轮询获取结果
        checkResult.running = true
      }
    }
  }

  Timer {
    interval: 500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: pgrepProc.running = true
  }

  // howdy 退出后检查结果文件（pam-howdy-animated 写入）
  Process {
    id: checkResult
    command: ["cat", "/tmp/howdy-result"]
    running: false
    onExited: (code, status) => {
      if (code === 0) {
        // 文件存在，内容是 "0" 或 "1"
        var text = checkResult.stdout.trim()
        root.exitCode = parseInt(text) || 1
      } else {
        root.exitCode = 1  // 文件不存在，假定失败
      }
    }
  }

  function clearResult() {
    hasResult = false
    exitCode = -1
  }
}
