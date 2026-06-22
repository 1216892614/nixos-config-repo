import QtQuick
import Quickshell.Io

QtObject {
    id: monitor
    property bool isFullscreen: false

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: checker.running = true
    }

    Process {
        id: checker
        command: ["sh", "-c", "niri msg --json focused-window | grep -q '\"is_fullscreen\":true'"]
        onExited: (exitCode) => {
            monitor.isFullscreen = (exitCode === 0)
        }
    }
}
