import QtQuick

Item {
    id: recordingState

    property int elapsed: 0
    property color indicatorColor: "#e06c75"
    property color textColor: "#e0e8d8"

    property Component leading: Component {
        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: recordingState.indicatorColor

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
            }
        }
    }

    property Component trailing: Component {
        Text {
            text: recordingState.formatTime(recordingState.elapsed)
            color: recordingState.textColor
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    function formatTime(seconds) {
        const minutes = Math.floor(seconds / 60)
        const remainingSeconds = seconds % 60
        return String(minutes).padStart(2, "0") + ":" + String(remainingSeconds).padStart(2, "0")
    }
}
