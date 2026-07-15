import Quickshell
import Quickshell.Io
import QtQuick

// 录屏检测：pgrep -x wf-recorder，1s 轮询
Item {
  id: root
  visible: false
  width: 0; height: 0

  property bool active: false         // wf-recorder 正在运行
  property int elapsedSeconds: 0      // 已录制秒数

  Process {
    id: pgrepProc
    command: ["pgrep", "-x", "wf-recorder"]
    onExited: (code, status) => {
      var wasActive = root.active
      root.active = (code === 0)

      if (!wasActive && root.active) {
        // 刚开始录制
        root.elapsedSeconds = 0
        elapsedTimer.running = true
      } else if (wasActive && !root.active) {
        // 录制结束
        elapsedTimer.running = false
      }
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: pgrepProc.running = true
  }

  Timer {
    id: elapsedTimer
    interval: 1000
    running: false
    repeat: true
    onTriggered: root.elapsedSeconds += 1
  }
}
