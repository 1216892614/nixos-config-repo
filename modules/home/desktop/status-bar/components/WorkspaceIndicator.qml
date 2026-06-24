import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Workspace indicator: solid color dots, active workspace highlighted
Item {
    id: root

    property color accentColor: "#a3b56a"
    property color inactiveColor: Qt.rgba(1, 1, 1, 0.3)
    property int activeWorkspace: 1
    property int workspaceCount: 5

    width: row.width
    height: row.height

    Row {
        id: row
        spacing: 5

        Repeater {
            model: root.workspaceCount

            Rectangle {
                width: (index + 1) === root.activeWorkspace ? 16 : 6
                height: 6
                radius: 3
                color: (index + 1) === root.activeWorkspace ? root.accentColor : root.inactiveColor

                Behavior on width {
                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }

    // Poll niri for workspace state
    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!wsChecker.running)
                wsChecker.running = true
        }
    }

    Process {
        id: wsChecker
        command: ["sh", "-c", "niri msg --json workspaces"]

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.parseWorkspaces(data)
        }
    }

    function parseWorkspaces(raw) {
        try {
            var workspaces = JSON.parse(raw)
            // Filter to current output only
            var current = workspaces.filter(function(ws) { return ws.is_focused || ws.output === workspaces.find(function(w) { return w.is_focused; }).output; })
            root.workspaceCount = Math.max(current.length, 1)
            for (var i = 0; i < current.length; i++) {
                if (current[i].is_focused) {
                    root.activeWorkspace = i + 1
                    break
                }
            }
        } catch (e) {
            // Keep defaults
        }
    }
}
