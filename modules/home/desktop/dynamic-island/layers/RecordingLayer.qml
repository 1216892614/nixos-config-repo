import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// 录屏层：检测 wf-recorder + 展示时间 + 卡片控制
Item {
  id: root
  width: 280
  height: 32

  property var colorSync
  property var monitor          // RecordingMonitor 引用

  // 当前展示形态
  property string displayMode: "none"  // "none" | "pill" | "card"
  property bool isRecording: monitor ? monitor.active : false

  onIsRecordingChanged: {
    if (isRecording && displayMode === "none") {
      displayMode = "pill"
      pillShowTimer.running = true
    } else if (!isRecording) {
      displayMode = "none"
    }
  }

  // ── 长胶囊：红点 + 白色时间 ─────────────────────────────────────────
  Item {
    id: pillContent
    anchors.centerIn: parent
    width: 140
    height: 32
    visible: root.displayMode === "pill"

    // 红色脉冲圆点
    Rectangle {
      id: recDot
      x: 10; y: 11
      width: 10; height: 10
      radius: 5
      color: root.colorSync ? root.colorSync.error : "#e06c75"

      SequentialAnimation on opacity {
        running: root.isRecording
        loops: Animation.Infinite
        NumberAnimation { to: 0.3; duration: 300 }
        NumberAnimation { to: 1.0; duration: 300 }
      }
    }

    // 录制时间（白色）
    Text {
      x: 28; y: (32 - height) / 2
      text: formatElapsed(root.monitor ? root.monitor.elapsedSeconds : 0)
      font.family: "MonaspiceNe Nerd Font"
      font.pixelSize: 13
      font.weight: Font.Medium
      color: root.colorSync ? root.colorSync.textColor : "#e0e8d8"

      function formatElapsed(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return String(m).padStart(2, '0') + ":" + String(s).padStart(2, '0')
      }
    }
  }

  // Phase 1 展示 ~2s 后触发收缩
  Timer {
    id: pillShowTimer
    interval: 2000
    running: false
    onTriggered: root.scrollDone()
  }

  // ── 卡片：录屏控制面板 ─────────────────────────────────────────────
  CardView {
    id: card
    anchors.centerIn: parent
    width: 200; height: 160
    visible: root.displayMode === "card"
    bgColor: root.colorSync ? root.colorSync.bg : "#0a0e0a"

    Column {
      anchors.fill: parent
      spacing: 16

      // 标题行：红点 + REC + 时间
      Row {
        spacing: 8
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
          width: 8; height: 8; radius: 4
          color: root.colorSync ? root.colorSync.error : "#e06c75"
          anchors.verticalCenter: parent.verticalCenter

          SequentialAnimation on opacity {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 300 }
            NumberAnimation { to: 1.0; duration: 300 }
          }
        }

        Text {
          text: "REC"
          font.pixelSize: 12
          font.weight: Font.Bold
          color: root.colorSync ? root.colorSync.error : "#e06c75"
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: formatElapsed(root.monitor ? root.monitor.elapsedSeconds : 0)
          font.family: "MonaspiceNe Nerd Font"
          font.pixelSize: 13
          color: root.colorSync ? root.colorSync.textColor : "#e0e8d8"
          anchors.verticalCenter: parent.verticalCenter

          function formatElapsed(secs) {
            var m = Math.floor(secs / 60)
            var s = secs % 60
            return String(m).padStart(2, '0') + ":" + String(s).padStart(2, '0')
          }
        }
      }

      // 操作按钮
      Row {
        spacing: 24
        anchors.horizontalCenter: parent.horizontalCenter

        // 暂停/恢复
        Rectangle {
          width: 48; height: 48
          radius: 12
          color: root.colorSync ? root.colorSync.surface : "#1a1e1a"

          Text {
            anchors.centerIn: parent
            text: root._paused ? "▶" : "⏸"
            font.pixelSize: 18
            color: root.colorSync ? root.colorSync.textColor : "#e0e8d8"
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.togglePause()
          }
        }

        // 结束
        Rectangle {
          width: 48; height: 48
          radius: 12
          color: root.colorSync ? root.colorSync.error : "#e06c75"

          Text {
            anchors.centerIn: parent
            text: "⏹"
            font.pixelSize: 18
            color: "#ffffff"
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.stopRecording()
          }
        }
      }
    }
  }

  // ── 录屏控制 ────────────────────────────────────────────────────────
  property bool _paused: false

  Process { id: pauseProc }
  Process { id: stopProc }

  function togglePause() {
    if (_paused) {
      pauseProc.command = ["pkill", "-CONT", "-x", "wf-recorder"]
      _paused = false
    } else {
      pauseProc.command = ["pkill", "-STOP", "-x", "wf-recorder"]
      _paused = true
    }
    pauseProc.running = true
  }

  function stopRecording() {
    stopProc.command = ["pkill", "-x", "wf-recorder"]
    stopProc.running = true
  }

  // ── 信号 ────────────────────────────────────────────────────────────
  signal scrollDone()

  function expandCard() { displayMode = "card" }
  function collapseCard() { displayMode = "pill" }
}
