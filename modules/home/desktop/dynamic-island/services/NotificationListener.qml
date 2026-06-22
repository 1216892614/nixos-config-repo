import QtQuick
import Quickshell.Io

QtObject {
    id: listener

    property string lastAppName: ""
    property string lastSummary: ""
    property string lastIcon: ""
    property bool hasNotification: false
    property bool _capturing: false
    property var _strings: []

    Timer {
        id: dismissTimer
        interval: 4000
        onTriggered: listener.hasNotification = false
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: monitor.running = true
    }

    Process {
        id: monitor
        running: true
        command: ["dbus-monitor", "--session", "interface='org.freedesktop.Notifications',member='Notify'"]

        stdout: SplitParser {
            onRead: line => listener.parseLine(line)
        }

        onExited: restartTimer.restart()
    }

    function parseLine(line) {
        if (line.indexOf("interface=org.freedesktop.Notifications") !== -1 && line.indexOf("member=Notify") !== -1) {
            _capturing = true
            _strings = []
            return
        }

        if (!_capturing)
            return

        const stringMatch = line.match(/^\s*string "(.*)"$/)
        if (stringMatch && _strings.length < 4)
            _strings.push(stringMatch[1].replace(/\\"/g, "\""))

        if (line.match(/^\s*int32 /)) {
            _capturing = false
            if (_strings.length >= 3)
                // D-Bus Notify strings: [0]=app_name, [1]=app_icon, [2]=summary, [3]=body
                onNotification(_strings[0], _strings[2], _strings[1])
        }
    }

    function onNotification(appName, summary, icon) {
        const lowerAppName = appName.toLowerCase()
        if (lowerAppName.indexOf("opencode") === -1 && lowerAppName.indexOf("openclaw") === -1)
            return

        lastAppName = appName
        lastSummary = summary
        lastIcon = icon
        hasNotification = true
        dismissTimer.restart()
    }
}
