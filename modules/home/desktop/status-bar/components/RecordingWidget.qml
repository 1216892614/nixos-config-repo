import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Screen recording indicator + toggle
Item {
    id: root

    property bool isRecording: false
    property int elapsedSeconds: 0
    property color indicatorColor: "#e06c75"
    property color textColor: "#e0e8d8"

    width: row.width
    height: row.height

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter

        // Blinking red dot
        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: root.indicatorColor
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }
        }

        // Elapsed time
        Text {
            text: formatTime(root.elapsedSeconds)
            color: root.textColor
            font.pixelSize: 12
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Click to stop recording
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: stopRecording.running = true
    }

    Process {
        id: stopRecording
        command: ["pkill", "-x", "wf-recorder"]
    }

    // Monitor recording state
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checker.running)
                checker.running = true
            if (root.isRecording)
                root.elapsedSeconds++
        }
    }

    Process {
        id: checker
        command: ["sh", "-c", "pgrep -x wf-recorder >/dev/null || pgrep -f '(^|/)gpu-screen-recorder( |$)' >/dev/null"]
        onExited: exitCode => {
            const recording = exitCode === 0
            if (!root.isRecording && recording)
                root.elapsedSeconds = 0
            root.isRecording = recording
        }
    }

    function formatTime(seconds) {
        const m = Math.floor(seconds / 60)
        const s = seconds % 60
        return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }
}
