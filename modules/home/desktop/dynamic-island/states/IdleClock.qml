import QtQuick

Item {
    property color textColor: "#e0e8d8"

    width: clockText.width
    height: clockText.height

    Text {
        id: clockText

        text: Qt.formatDateTime(new Date(), "HH:mm")
        color: textColor
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
    }
}
