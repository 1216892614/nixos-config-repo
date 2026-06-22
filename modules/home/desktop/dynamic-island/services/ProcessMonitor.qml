import QtQuick
import Quickshell.Io

QtObject {
    id: monitor

    property bool isRecording: false
    property int elapsedSeconds: 0

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!checker.running)
                checker.running = true
            if (monitor.isRecording)
                monitor.elapsedSeconds++
        }
    }

    Process {
        id: checker

        command: ["sh", "-c", "pgrep -x wf-recorder >/dev/null || pgrep -f '(^|/)gpu-screen-recorder( |$)' >/dev/null"]

        onExited: exitCode => {
            const recording = exitCode === 0
            if (!monitor.isRecording && recording)
                monitor.elapsedSeconds = 0
            monitor.isRecording = recording
        }
    }
}
