import QtQuick

// 时间显示：HH:MM • ddd dd
// 绝对定位，不缩放
Item {
  id: root
  width: 140
  height: 32

  property color textColor: "#e0e8d8"

  Text {
    id: clockText
    anchors.centerIn: parent
    font.family: "MonaspiceNe Nerd Font"
    font.pixelSize: 13
    font.weight: Font.Medium
    color: root.textColor
    text: formatTime()

    function formatTime() {
      var now = new Date()
      var h = String(now.getHours()).padStart(2, '0')
      var m = String(now.getMinutes()).padStart(2, '0')
      var days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
      var d = days[now.getDay()]
      var dd = String(now.getDate()).padStart(2, '0')
      return h + ":" + m + " • " + d + " " + dd
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: clockText.text = clockText.formatTime()
  }
}
