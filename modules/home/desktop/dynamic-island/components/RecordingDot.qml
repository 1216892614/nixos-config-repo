import QtQuick

// 录屏专用缩略圆 — 60min 进度环 + 中心 REC
Item {
  id: root
  width: 32
  height: 32

  property color ringColor: "#e06c75"
  property color dimColor: "#4a5a4a"
  property int elapsedSeconds: 0
  property real progress: elapsedSeconds / 3600.0  // 60min 一圈

  // 消失动画
  property real dotScale: 1
  property real dotOpacity: 1
  Behavior on dotScale { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
  Behavior on dotOpacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

  visible: dotOpacity > 0.01

  Item {
    width: 32; height: 32
    scale: root.dotScale
    opacity: root.dotOpacity
    transformOrigin: Item.Center

    // 进度环 canvas
    Canvas {
      id: ringCanvas
      anchors.fill: parent

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var cx = 16, cy = 16, r = 13, lw = 2

        // 背景环
        ctx.beginPath()
        ctx.strokeStyle = root.dimColor
        ctx.lineWidth = lw
        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
        ctx.stroke()

        // 进度环
        if (root.progress > 0) {
          ctx.beginPath()
          ctx.strokeStyle = root.ringColor
          ctx.lineWidth = lw
          ctx.lineCap = "round"
          ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + root.progress * 2 * Math.PI)
          ctx.stroke()
        }
      }
    }

    // 中心 REC 文字
    Text {
      anchors.centerIn: parent
      text: "REC"
      font.pixelSize: 7
      font.weight: Font.Bold
      color: root.ringColor
    }
  }

  onProgressChanged: ringCanvas.requestPaint()

  function appear() {
    dotScale = 0; dotOpacity = 0
    dotScale = 1; dotOpacity = 1
  }

  function dismiss() {
    dotScale = 0; dotOpacity = 0
  }
}
