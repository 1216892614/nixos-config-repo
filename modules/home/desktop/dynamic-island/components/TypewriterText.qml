import QtQuick

// 打字效果组件：逐字出现，每字 spring opacity + translateX
Item {
  id: root
  width: textRow.width
  height: 32

  property string text: ""
  property color textColor: "#e0e8d8"
  property int letterDelay: 60          // 每字间隔 ms
  property real letterOffset: 8         // 初始 X 偏移
  property bool playing: false

  // 触发播放
  onPlayingChanged: {
    if (playing) startAnimation()
    else resetAll()
  }

  Row {
    id: textRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Repeater {
      id: letterRepeater
      model: root.text.split("")

      Text {
        id: letterItem
        text: modelData
        font.family: "MonaspiceNe Nerd Font"
        font.pixelSize: 14
        font.weight: Font.Bold
        color: root.textColor
        opacity: 0
        transform: Translate { id: letterTranslate; x: root.letterOffset }

        Behavior on opacity { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }

        Connections {
          target: letterTranslate
          // Spring on translate.x
        }

        property bool revealed: false
        onRevealedChanged: {
          if (revealed) {
            opacity = 1
            letterTranslate.x = 0
          } else {
            opacity = 0
            letterTranslate.x = root.letterOffset
          }
        }

        Behavior on transform { SpringAnimation { spring: 4.0; damping: 0.82; epsilon: 0.5 } }
      }
    }
  }

  Timer {
    id: revealTimer
    interval: root.letterDelay
    repeat: true
    property int currentIdx: 0
    onTriggered: {
      if (currentIdx < letterRepeater.count) {
        letterRepeater.itemAt(currentIdx).revealed = true
        currentIdx++
      } else {
        running = false
      }
    }
  }

  function startAnimation() {
    resetAll()
    revealTimer.currentIdx = 0
    revealTimer.running = true
  }

  function resetAll() {
    revealTimer.running = false
    for (var i = 0; i < letterRepeater.count; i++) {
      letterRepeater.itemAt(i).revealed = false
    }
  }
}
