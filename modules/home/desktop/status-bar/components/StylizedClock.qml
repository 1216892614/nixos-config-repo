import QtQuick
import QtQuick.Layouts

// iNiR-style stylized clock: time • date
Item {
    id: root

    property color timeColor: "#e0e8d8"
    property color dateColor: Qt.rgba(1, 1, 1, 0.6)
    property color dotColor: "#a3b56a"

    width: row.width
    height: row.height

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter

        // Time (bold, slightly larger)
        Text {
            id: timeText
            text: Qt.formatDateTime(new Date(), "HH:mm")
            color: root.timeColor
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
            anchors.verticalCenter: parent.verticalCenter
        }

        // Dot separator
        Text {
            text: "•"
            color: root.dotColor
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        // Date (smaller, muted)
        Text {
            id: dateText
            text: Qt.formatDateTime(new Date(), "ddd dd")
            color: root.dateColor
            font.pixelSize: 11
            font.weight: Font.Normal
            font.letterSpacing: 0.3
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            timeText.text = Qt.formatDateTime(now, "HH:mm")
            dateText.text = Qt.formatDateTime(now, "ddd dd")
        }
    }
}
