import Quickshell
import Quickshell.Io
import QtQuick
import "../components"

// Agent 层：多实例管理 + 执行历史卡片
Item {
  id: root
  width: 280
  height: 32

  property var colorSync
  property var monitor          // AgentMonitor 引用

  property string displayMode: "none"  // "none" | "pill" | "card"
  property int activeCount: monitor ? monitor.activeCount : 0
  property var agents: monitor ? monitor.agents : []

  // 最新事件的消息（用于滚动展示）
  property string latestMessage: ""

  onActiveCountChanged: {
    if (activeCount > 0 && displayMode === "none") {
      updateLatestMessage()
      displayMode = "pill"
      pill.startScroll()
    } else if (activeCount === 0 && displayMode !== "card") {
      displayMode = "none"
    }
  }

  // 监听 agents 变化，检测新事件
  onAgentsChanged: {
    if (agents.length === 0) return
    updateLatestMessage()
    // 有新事件时展开胶囊
    if (displayMode !== "card") {
      displayMode = "pill"
      pill.stopScroll()
      pill.startScroll()
    }
  }

  function updateLatestMessage() {
    if (agents.length === 0) { latestMessage = ""; return }
    // 找最新的 agent 事件
    var sorted = agents.slice().sort((a, b) => b.ts - a.ts)
    var latest = sorted[0]
    if (latest.state === "done") {
      latestMessage = latest.source + " • " + (latest.result || "done")
    } else if (latest.state === "error" || latest.state === "dead") {
      latestMessage = latest.source + " • " + (latest.result || "error")
    } else {
      // running
      var parts = [latest.source]
      if (latest.model) parts.push(latest.model)
      if (latest.task) parts.push(latest.task.substring(0, 30))
      latestMessage = parts.join(" • ")
    }
  }

  // ── 长胶囊 ─────────────────────────────────────────────────────────
  LongPill {
    id: pill
    anchors.centerIn: parent
    visible: root.displayMode === "pill"
    icon: "⟳"
    count: root.activeCount
    message: root.latestMessage
    iconColor: root.colorSync ? root.colorSync.primary : "#a3b56a"
    textColor: root.colorSync ? root.colorSync.textColor : "#e0e8d8"

    onScrollFinished: root.scrollDone()
  }

  // ── 卡片：执行历史 ─────────────────────────────────────────────────
  CardView {
    id: card
    anchors.centerIn: parent
    width: 220; height: Math.min(40 + root.agents.length * 48, 260)
    visible: root.displayMode === "card"
    bgColor: root.colorSync ? root.colorSync.bg : "#0a0e0a"

    Column {
      anchors.fill: parent
      spacing: 4

      // 标题
      Text {
        text: "⟳ " + root.activeCount + " Active"
        font.family: "MonaspiceNe Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Bold
        color: root.colorSync ? root.colorSync.textColor : "#e0e8d8"
      }

      // 历史列表
      Repeater {
        model: root.agents

        Rectangle {
          width: card.width - 32
          height: 44
          radius: 8
          color: "transparent"

          Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 4
            spacing: 2

            Row {
              spacing: 6
              Text {
                text: modelData.state === "done" ? "✓" :
                      modelData.state === "running" ? "⟳" :
                      modelData.state === "dead" ? "✗" : "✗"
                font.pixelSize: 11
                color: modelData.state === "done" ? (root.colorSync ? root.colorSync.primary : "#a3b56a") :
                       modelData.state === "running" ? (root.colorSync ? root.colorSync.primary : "#a3b56a") :
                       (root.colorSync ? root.colorSync.error : "#e06c75")
              }
              Text {
                text: (modelData.source || "") + "  " + (modelData.model || "")
                font.pixelSize: 11
                font.weight: Font.Medium
                color: root.colorSync ? root.colorSync.textColor : "#e0e8d8"
              }
            }

            Text {
              text: {
                var task = modelData.task || ""
                var suffix = ""
                if (modelData.state === "running") suffix = " • running"
                else if (modelData.state === "dead") suffix = " • killed"
                else if (modelData.result) suffix = " • " + modelData.result
                else {
                  var ago = Math.floor((Date.now() / 1000 - modelData.ts))
                  suffix = " • " + ago + "s ago"
                }
                return task.substring(0, 25) + suffix
              }
              font.pixelSize: 10
              color: root.colorSync ? root.colorSync.dim : "#4a5a4a"
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.focusAgent(modelData)
          }
        }
      }
    }
  }

  // ── Agent 聚焦 ──────────────────────────────────────────────────────
  Process { id: focusProc }

  function focusAgent(agent) {
    // niri IPC 聚焦窗口
    var appId = agent.source || "opencode"
    focusProc.command = ["niri", "msg", "action", "focus-window", "--app-id", appId]
    focusProc.running = true
  }

  // ── 信号 ────────────────────────────────────────────────────────────
  signal scrollDone()

  function expandCard() { displayMode = "card" }
  function collapseCard() {
    displayMode = activeCount > 0 ? "pill" : "none"
  }
}
