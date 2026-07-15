import Quickshell
import QtQuick
import "../components"

// Howdy 层：四子状态动画（scanning-start, scanning, success, error）
Item {
  id: root
  width: 160
  height: 200

  property var colorSync
  property var monitor          // HowdyMonitor 引用

  property string subState: "idle"  // "idle" | "scanning-start" | "scanning" | "success" | "error"

  property bool isActive: monitor ? monitor.active : false
  property bool hasResult: monitor ? monitor.hasResult : false

  onIsActiveChanged: {
    if (isActive) {
      subState = "scanning-start"
      scanStartTimer.running = true
    }
  }

  onHasResultChanged: {
    if (hasResult && monitor) {
      if (monitor.exitCode === 0) {
        subState = "success"
      } else {
        subState = "error"
      }
      resultTimer.running = true
    }
  }

  // ── 符号（居中大号）─────────────────────────────────────────────────
  Text {
    id: symbol
    anchors.horizontalCenter: parent.horizontalCenter
    y: subState === "success" || subState === "error" ? 90 : 70
    font.pixelSize: subState === "success" || subState === "error" ? 24 : 48
    text: currentGlyph()
    color: symbolColor()

    // 位置动画
    property real targetX: (subState === "success" || subState === "error") ? 30 : parent.width / 2 - width / 2
    x: targetX

    Behavior on x { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
    Behavior on y { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
    Behavior on font.pixelSize { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

    // scanning-start 时从 scale 0 出现
    scale: subState === "idle" ? 0 : 1
    Behavior on scale { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
  }

  // ── 脉冲动画 ────────────────────────────────────────────────────────
  property var glyphs: ["·", "○", "◉", "✱", "◉", "○"]
  property int pulseFrame: 0

  Timer {
    id: pulseTimer
    interval: 100
    running: root.subState === "scanning"
    repeat: true
    onTriggered: {
      root.pulseFrame = (root.pulseFrame + 1) % root.glyphs.length
      symbol.text = root.glyphs[root.pulseFrame]
    }
  }

  // ── SCANNING 文字 ───────────────────────────────────────────────────
  Text {
    id: scanLabel
    anchors.horizontalCenter: parent.horizontalCenter
    y: 130
    text: "SCANNING"
    font.family: "MonaspiceNe Nerd Font"
    font.pixelSize: 12
    font.weight: Font.Medium
    color: root.colorSync ? root.colorSync.dim : "#4a5a4a"
    opacity: root.subState === "scanning" ? 1 : 0
    Behavior on opacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
  }

  // ── 结果打字效果 ────────────────────────────────────────────────────
  TypewriterText {
    id: resultText
    x: 60
    y: 90
    text: root.subState === "success" ? "SUCCESS" : "FAIL"
    textColor: root.subState === "success"
      ? (root.colorSync ? root.colorSync.primary : "#a3b56a")
      : (root.colorSync ? root.colorSync.error : "#e06c75")
    playing: root.subState === "success" || root.subState === "error"
    visible: root.subState === "success" || root.subState === "error"
  }

  // ── 定时器 ──────────────────────────────────────────────────────────
  // scanning-start → scanning
  Timer {
    id: scanStartTimer
    interval: 300
    onTriggered: root.subState = "scanning"
  }

  // 结果展示后回 idle
  Timer {
    id: resultTimer
    interval: root.subState === "success" ? 800 : 500
    onTriggered: {
      root.subState = "idle"
      if (root.monitor) root.monitor.clearResult()
      root.finished()
    }
  }

  // ── 辅助函数 ────────────────────────────────────────────────────────
  function currentGlyph() {
    switch (subState) {
      case "scanning-start": return "◉"
      case "scanning": return glyphs[pulseFrame]
      case "success": return "●"
      case "error": return "○"
      default: return ""
    }
  }

  function symbolColor() {
    switch (subState) {
      case "success": return root.colorSync ? root.colorSync.primary : "#a3b56a"
      case "error": return root.colorSync ? root.colorSync.error : "#e06c75"
      default: return root.colorSync ? root.colorSync.textColor : "#e0e8d8"
    }
  }

  // ── 信号 ────────────────────────────────────────────────────────────
  signal finished()  // Howdy 完整流程结束，可收回
}
