import QtQuick

// 长胶囊：左侧缩略圆(32×32) + 右侧滚动区(渐隐两侧)
// 绝对定位，外部控制 x/y/opacity
Item {
  id: root
  width: scrollAreaWidth + 32  // 圆宽 + 滚动区宽
  height: 32

  property color iconColor: "#a3b56a"
  property color textColor: "#e0e8d8"
  property string icon: "🔔"
  property int count: 1
  property string message: ""
  property real scrollAreaWidth: 248    // spring 驱动收缩/展开

  Behavior on scrollAreaWidth { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

  // ── 左侧缩略圆 ────────────────────────────────────────────────────
  Rectangle {
    id: dotArea
    width: 32; height: 32
    radius: 16
    color: Qt.rgba(root.iconColor.r, root.iconColor.g, root.iconColor.b, 0.15)

    Column {
      anchors.centerIn: parent
      spacing: 1
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.icon
        font.pixelSize: 12
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.count > 1 ? root.count.toString() : ""
        font.pixelSize: 8
        font.weight: Font.Bold
        color: root.iconColor
      }
    }
  }

  // ── 右侧滚动区 ────────────────────────────────────────────────────
  Item {
    id: scrollArea
    x: 32
    width: root.scrollAreaWidth
    height: 32
    clip: true


    // 滚动文字
    Text {
      id: marqueeText
      y: (32 - height) / 2
      x: marqueeX
      text: root.message
      font.family: "MonaspiceNe Nerd Font"
      font.pixelSize: 13
      color: root.textColor
      width: implicitWidth

      property real marqueeX: 8  // 初始位置
    }
  }

  // ── Marquee 动画 ────────────────────────────────────────────────────
  property bool scrolling: false
  property bool scrollNeeded: marqueeText.implicitWidth > (scrollAreaWidth - 16)

  signal scrollFinished()

  SequentialAnimation {
    id: marqueeAnim
    running: false

    // 停留 1s
    PauseAnimation { duration: 1000 }

    // 滚动到末尾
    NumberAnimation {
      target: marqueeText
      property: "marqueeX"
      from: 8
      to: -(marqueeText.implicitWidth - scrollAreaWidth + 24)
      duration: marqueeText.implicitWidth / 0.04  // 40px/s
      easing.type: Easing.Linear
    }

    // 末尾停留 0.5s
    PauseAnimation { duration: 500 }

    ScriptAction { script: root.scrollFinished() }
  }

  // 短文字不滚动，3s 后直接完成
  Timer {
    id: shortTimer
    interval: 3000
    running: root.visible && !root.scrollNeeded
    onTriggered: root.scrollFinished()
  }

  function startScroll() {
    marqueeText.marqueeX = 8
    if (scrollNeeded) {
      marqueeAnim.running = true
    } else {
      shortTimer.running = true
    }
  }

  function stopScroll() {
    marqueeAnim.running = false
    shortTimer.running = false
    marqueeText.marqueeX = 8
  }
}
