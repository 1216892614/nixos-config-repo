import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "../components"

// 通知层：监听 DBus 通知，管理通知队列
Item {
  id: root
  width: 280
  height: 32

  property var colorSync
  property var notifications: []      // 通知队列
  property int unreadCount: 0
  property var currentNotif: null     // 当前展示的通知

  // 当前展示形态："pill" | "card" | "none"
  property string displayMode: "none"
  property bool shouldDismiss: false

  // ── DBus 通知服务器 ─────────────────────────────────────────────────
  // Quickshell 0.2.1 NotificationServer API
  NotificationServer {
    id: notifServer
    onNotification: (notification) => {
      root.addNotification(notification)
    }
  }

  // ── 通知管理 ────────────────────────────────────────────────────────
  function addNotification(notif) {
    var item = {
      id: notif.id || Date.now(),
      appName: notif.appName || "",
      summary: notif.summary || "",
      body: notif.body || "",
      icon: notif.appIcon || "🔔",
      timestamp: Date.now(),
      shouldDismiss: false
    }
    var updated = notifications.slice()
    updated.push(item)
    notifications = updated
    unreadCount = notifications.length
    currentNotif = item
    displayMode = "pill"
    // 通知胶囊展示
    pill.message = item.summary
    pill.icon = "🔔"
    pill.count = unreadCount
    pill.startScroll()
  }

  function dismissCurrent() {
    if (!currentNotif) return
    var updated = notifications.filter(n => n.id !== currentNotif.id)
    notifications = updated
    unreadCount = notifications.length
    if (notifications.length > 0) {
      currentNotif = notifications[notifications.length - 1]
    } else {
      currentNotif = null
      displayMode = "none"
    }
  }

  // ── 长胶囊 ─────────────────────────────────────────────────────────
  LongPill {
    id: pill
    anchors.centerIn: parent
    visible: root.displayMode === "pill"
    iconColor: root.colorSync ? root.colorSync.primary : "#a3b56a"
    textColor: root.colorSync ? root.colorSync.textColor : "#e0e8d8"

    onScrollFinished: {
      root.shouldDismiss = true
      // 通知三段式 Phase 1 → Phase 2 信号
      root.scrollDone()
    }
  }

  // ── 卡片（通知全文）─────────────────────────────────────────────────
  CardView {
    id: card
    anchors.centerIn: parent
    width: 200; height: 180
    visible: root.displayMode === "card"
    bgColor: root.colorSync ? root.colorSync.bg : "#0a0e0a"

    Column {
      anchors.fill: parent
      spacing: 8

      // 标题
      Text {
        width: parent.width
        text: root.currentNotif ? root.currentNotif.summary : ""
        font.family: "MonaspiceNe Nerd Font"
        font.pixelSize: 13
        font.weight: Font.Bold
        color: root.colorSync ? root.colorSync.textColor : "#e0e8d8"
        elide: Text.ElideRight
      }

      // 正文
      Text {
        width: parent.width
        height: parent.height - 30
        text: root.currentNotif ? root.currentNotif.body : ""
        font.family: "MonaspiceNe Nerd Font"
        font.pixelSize: 12
        color: root.colorSync ? root.colorSync.textColor : "#e0e8d8"
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 8
      }
    }
  }

  // ── 信号 ────────────────────────────────────────────────────────────
  signal scrollDone()         // 滚动结束，可收缩
  signal requestCard()        // 请求展开卡片
  signal cardClosed()         // 卡片关闭

  function expandCard() {
    displayMode = "card"
  }

  function collapseCard() {
    displayMode = "pill"
    // 检查是否应该消失
    if (shouldDismiss) {
      dismissCurrent()
    }
  }
}
