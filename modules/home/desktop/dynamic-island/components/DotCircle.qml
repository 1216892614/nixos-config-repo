import QtQuick

// 缩略圆（离岛）— 32×32 正圆，图标+数字
// 独立生命周期，有自己的消失动画
Item {
  id: root
  width: 32
  height: 32

  property color accentColor: "#a3b56a"
  property string icon: "🔔"
  property int count: 0
  property string type: "notification"  // "notification" | "recording" | "agent"

  // 消失动画
  property real dotScale: 1
  property real dotOpacity: 1
  Behavior on dotScale { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
  Behavior on dotOpacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

  visible: dotOpacity > 0.01

  Rectangle {
    width: 32; height: 32
    radius: 16
    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)
    scale: root.dotScale
    opacity: root.dotOpacity
    transformOrigin: Item.Center

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
        text: root.count > 0 ? root.count.toString() : ""
        font.pixelSize: 8
        font.weight: Font.Bold
        color: root.accentColor
        visible: root.count > 0
      }
    }
  }

  function appear() {
    dotScale = 0
    dotOpacity = 0
    dotScale = 1
    dotOpacity = 1
  }

  function dismiss() {
    dotScale = 0
    dotOpacity = 0
  }
}
