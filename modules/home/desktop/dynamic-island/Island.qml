import QtQuick
import "components"
import "layers"

// ── 灵动岛主组件 ──────────────────────────────────────────────────────────
// 遮罩模式：不是容器，内容绝对定位
// 遮罩 width/height spring 动画决定裁切区域
// 整体（主岛 + 离岛）spring 居中
Item {
  id: island
  width: totalWidth
  height: targetH

  // 外部注入
  property var colorSync
  property var howdyMonitor
  property var recordingMonitor
  property var agentMonitor

  // ── 布局：整体 spring 居中 ─────────────────────────────────────────────
  property real totalWidth: mainIslandW + dotsRowWidth + (dotsRowWidth > 0 ? 4 : 0)
  property real mainIslandW: targetW
  property real dotsRowWidth: {
    if (phase === "card") return 0  // 卡片态离岛隐藏
    var w = 0
    if (showNotifDot) w += 36       // 32 + 4 gap
    if (showRecDot) w += 36
    if (showAgentDot) w += 36
    return w
  }

  Behavior on totalWidth { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

  // ── 状态 ─────────────────────────────────────────────────────────────
  property real targetW: 140
  property real targetH: 32
  property string phase: "idle"
    // "idle"         — 显示时间
    // "pill"         — 长胶囊展示内容
    // "dot-idle"     — 时间 + 离岛（Phase 2）
    // "card"         — 卡片展开
    // "collapsing"   — 消失阶段 A（→圆）
    // "vanishing"    — 消失阶段 B（scale→0）

  property string activeContent: "idle"
    // "idle" | "notification" | "recording" | "agent" | "howdy"

  // 优先级：howdy=4, recording=3, notification=2, agent=1
  property int activePriority: priorityOf(activeContent)

  // 离岛可见性
  property bool showNotifDot: notifLayer.unreadCount > 0 && activeContent !== "notification" && phase !== "card"
  property bool showRecDot: recordingMonitor && recordingMonitor.active && activeContent !== "recording" && phase !== "card"
  property bool showAgentDot: agentMonitor && agentMonitor.activeCount > 0 && activeContent !== "agent" && phase !== "card"

  // 两步展开追踪
  property string lastClicked: ""  // 最后点击的内容类型
  property int clickCount: 0

  // shouldDismiss 延迟
  property bool notifShouldDismiss: false

  // ── 优先级函数 ─────────────────────────────────────────────────────────
  function priorityOf(content) {
    switch (content) {
      case "howdy": return 4
      case "recording": return 3
      case "notification": return 2
      case "agent": return 1
      default: return 0
    }
  }

  // ── 主岛容器（圆角矩形 + clip 裁切内容）──────────────────────────────────
  Rectangle {
    id: mask
    width: island.targetW
    height: island.targetH
    x: (island.width - totalWidth) / 2
    y: 0
    radius: Math.min(width, height) / 2
    clip: true
    scale: island.phase === "vanishing" ? 0 : 1
    opacity: island.phase === "vanishing" ? 0 : 1
    visible: island.phase !== "hidden"

    Behavior on width { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
    Behavior on height { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
    Behavior on x { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
    Behavior on scale { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
    Behavior on opacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.92) }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.4) }
    }

    // 主岛点击 → 两步展开
    MouseArea {
      anchors.fill: parent
      onClicked: island.handleMainClick()
    }

    // ── 内容层 ──────────────────────────────────────────────────────────
    IdleClock {
      id: idleClock
      anchors.centerIn: parent
      opacity: island.activeContent === "idle" || island.phase === "dot-idle" ? 1 : 0
      textColor: island.colorSync ? island.colorSync.textColor : "#e0e8d8"
      Behavior on opacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
    }

    NotificationLayer {
      id: notifLayer
      anchors.centerIn: parent
      opacity: island.activeContent === "notification" && island.phase !== "dot-idle" ? 1 : 0
      colorSync: island.colorSync
      Behavior on opacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

      onScrollDone: island.enterDotIdle()
    }

    RecordingLayer {
      id: recLayer
      anchors.centerIn: parent
      opacity: island.activeContent === "recording" && island.phase !== "dot-idle" ? 1 : 0
      colorSync: island.colorSync
      monitor: island.recordingMonitor
      Behavior on opacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

      onScrollDone: island.enterDotIdle()
    }

    AgentLayer {
      id: agentLayer
      anchors.centerIn: parent
      opacity: island.activeContent === "agent" && island.phase !== "dot-idle" ? 1 : 0
      colorSync: island.colorSync
      monitor: island.agentMonitor
      Behavior on opacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

      onScrollDone: island.enterDotIdle()
    }

    HowdyLayer {
      id: howdyLayer
      anchors.centerIn: parent
      opacity: island.activeContent === "howdy" ? 1 : 0
      colorSync: island.colorSync
      monitor: island.howdyMonitor
      Behavior on opacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

      onFinished: island.howdyDone()
    }
  }

  // ── 离岛区域 ────────────────────────────────────────────────────────────
  Row {
    id: dotsRow
    x: mask.x + mask.width + 4
    y: 0
    spacing: 4
    visible: island.phase !== "card"

    Behavior on x { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

    DotCircle {
      id: notifDotCircle
      visible: island.showNotifDot
      icon: "🔔"
      count: notifLayer.unreadCount
      accentColor: island.colorSync ? island.colorSync.primary : "#a3b56a"

      MouseArea {
        anchors.fill: parent
        onClicked: island.dotClicked("notification")
      }
    }

    RecordingDot {
      id: recDotCircle
      visible: island.showRecDot
      elapsedSeconds: island.recordingMonitor ? island.recordingMonitor.elapsedSeconds : 0
      ringColor: island.colorSync ? island.colorSync.error : "#e06c75"
      dimColor: island.colorSync ? island.colorSync.dim : "#4a5a4a"

      MouseArea {
        anchors.fill: parent
        onClicked: island.dotClicked("recording")
      }
    }

    DotCircle {
      id: agentDotCircle
      visible: island.showAgentDot
      icon: "⟳"
      count: island.agentMonitor ? island.agentMonitor.activeCount : 0
      accentColor: island.colorSync ? island.colorSync.primary : "#a3b56a"

      MouseArea {
        anchors.fill: parent
        onClicked: island.dotClicked("agent")
      }
    }
  }

  // ── 卡片外部点击区域 ────────────────────────────────────────────────────
  MouseArea {
    anchors.fill: parent
    enabled: island.phase === "card"
    z: -1  // 低于卡片内部
    onClicked: island.closeCard()
  }

  // ── 状态调度：监听 monitors ──────────────────────────────────────────────

  // Howdy（最高优先级）
  Connections {
    target: howdyMonitor
    function onActiveChanged() {
      if (howdyMonitor.active) {
        island.activateContent("howdy", 160, 200)
      }
    }
  }

  // 录屏
  Connections {
    target: recordingMonitor
    function onActiveChanged() {
      if (recordingMonitor.active && island.activePriority < 3) {
        island.activateContent("recording", 140, 32)
      }
    }
  }

  // 通知
  Connections {
    target: notifLayer
    function onUnreadCountChanged() {
      if (notifLayer.unreadCount > 0 && island.activePriority < 2) {
        island.activateContent("notification", 280, 32)
      }
    }
  }

  // Agent
  Connections {
    target: agentMonitor
    function onActiveCountChanged() {
      if (agentMonitor.activeCount > 0 && island.activePriority < 1) {
        island.activateContent("agent", 280, 32)
      } else if (agentMonitor.activeCount === 0 && island.activeContent === "agent") {
        island.returnToIdle()
      }
    }
  }

  // ── 状态转移函数 ────────────────────────────────────────────────────────

  function activateContent(content, w, h) {
    activeContent = content
    targetW = w
    targetH = h
    phase = content === "howdy" ? "card" : "pill"
    clickCount = 0
  }

  function enterDotIdle() {
    // Phase 1 → Phase 2
    phase = "dot-idle"
    targetW = 140  // 回到 idle pill 尺寸
    targetH = 32
    // Phase 2 timeout（通知 3s，agent 不 timeout）
    if (activeContent === "notification") {
      dotIdleTimer.interval = 3000
      dotIdleTimer.running = true
    }
    // 录屏不进 Phase 3，常驻
  }

  function returnToIdle() {
    phase = "idle"
    activeContent = "idle"
    targetW = 140
    targetH = 32
    clickCount = 0
  }

  function howdyDone() {
    // Howdy 结束，检查是否有其他内容
    if (showRecDot || showNotifDot || showAgentDot) {
      phase = "dot-idle"
      activeContent = "idle"
      targetW = 140
      targetH = 32
    } else {
      returnToIdle()
    }
  }

  // Phase 2 → Phase 3 计时器
  Timer {
    id: dotIdleTimer
    interval: 3000
    running: false
    onTriggered: {
      if (island.phase === "dot-idle" && island.activeContent === "notification") {
        island.notifShouldDismiss = true
        notifLayer.dismissCurrent()
        if (notifLayer.unreadCount === 0) {
          island.returnToIdle()
        }
      }
    }
  }

  // ── 点击处理 ────────────────────────────────────────────────────────────

  // 离岛点击 → 第一步：展开为胶囊
  function dotClicked(content) {
    clickCount = 1
    lastClicked = content
    var w = content === "recording" ? 140 : 280
    activateContent(content, w, 32)
    // 启动对应层的滚动
    if (content === "notification") notifLayer.pill.startScroll()
    else if (content === "agent") agentLayer.pill.startScroll()
  }

  // 主岛点击 → 两步展开
  function handleMainClick() {
    if (phase === "idle" || phase === "dot-idle") return
    if (phase === "card") return  // 卡片内部点击由各层处理

    // 第一次点击已经是胶囊了（从 dot 来），第二次展开卡片
    clickCount++
    if (clickCount >= 2) {
      expandToCard()
    }
    // 如果 clickCount === 1（直接在 pill 态点击），展开卡片
    if (phase === "pill") {
      expandToCard()
    }
  }

  function expandToCard() {
    phase = "card"
    // 卡片尺寸
    switch (activeContent) {
      case "notification":
        targetW = 200; targetH = 180
        notifLayer.expandCard()
        break
      case "recording":
        targetW = 200; targetH = 160
        recLayer.expandCard()
        break
      case "agent":
        targetW = 220; targetH = Math.min(40 + agentMonitor.agents.length * 48, 260)
        agentLayer.expandCard()
        break
    }
  }

  function closeCard() {
    // 卡片 → 回胶囊
    var w = activeContent === "recording" ? 140 : 280
    targetW = w
    targetH = 32
    phase = "pill"
    clickCount = 1  // 回胶囊后再点击才能再开卡片

    // 通知各层
    if (activeContent === "notification") notifLayer.collapseCard()
    else if (activeContent === "recording") recLayer.collapseCard()
    else if (activeContent === "agent") agentLayer.collapseCard()

    // 检查 shouldDismiss
    if (activeContent === "notification" && notifShouldDismiss) {
      notifLayer.dismissCurrent()
      notifShouldDismiss = false
      if (notifLayer.unreadCount === 0) returnToIdle()
    }
  }

  // ── 消失阶段判定 ─────────────────────────────────────────────────────
  Connections {
    target: mask
    function onWidthChanged() {
      if (island.phase === "collapsing" && Math.abs(mask.width - 32) < 1 && Math.abs(mask.height - 32) < 1) {
        island.phase = "vanishing"
      }
    }
    function onScaleChanged() {
      if (island.phase === "vanishing" && mask.scale < 0.02) {
        island.phase = "hidden"
      }
    }
  }

  // 初始化
  Component.onCompleted: {
    phase = "idle"
    activeContent = "idle"
  }
}
