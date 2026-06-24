import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: colorSync
    visible: false
    width: 0; height: 0

    // Current colors (with fallbacks)
    property color primary: "#a3b56a"
    property color fgPrimary: "#0a0e0a"
    property color surface: "#0a0e0a"
    property color textColor: "#e0e8d8"
    property color error: "#e06c75"
    property color outline: "#3a4a2a"
    property color bg: "#0a0e0a"
    property color fg: "#e0e8d8"

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.config/dynamic-island/colors.json"
        watchChanges: true
        printErrors: false
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (colorsFile.loaded)
                colorSync.applyColors(colorsFile.text())
        }
    }

    function applyColors(raw) {
        try {
            if (!raw || raw.trim() === "")
                return
            var data = JSON.parse(raw)
            primary = data.primary || primary
            fgPrimary = data.onPrimary || fgPrimary
            surface = data.surface || surface
            textColor = data.onSurface || textColor
            error = data.error || error
            outline = data.outline || outline
            bg = data.background || bg
            fg = data.onBackground || fg
        } catch (e) {}
    }

    Component.onCompleted: {
        if (colorsFile.loaded)
            applyColors(colorsFile.text())
    }
}
