import QtQuick

// 卡片容器 — squircle + 烟熏渐变
// 内容通过 children/default property 填入
Item {
  id: root
  width: 200
  height: 200

  property color bgColor: "#0a0e0a"

  default property alias content: contentArea.data

  Rectangle {
    id: cardBg
    anchors.fill: parent
    radius: 24  // squircle 近似（后续替换 SDF）
    color: root.bgColor

    // 径向渐变近似：上部不透明，下部透明
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.92) }
      GradientStop { position: 0.7; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.6) }
      GradientStop { position: 1.0; color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.2) }
    }
  }

  Item {
    id: contentArea
    anchors.fill: parent
    anchors.margins: 16
  }
}
