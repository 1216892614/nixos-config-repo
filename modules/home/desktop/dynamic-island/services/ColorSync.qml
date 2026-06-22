import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: colorSync

    // Current colors (with fallbacks from Moss & Fern)
    property color primary: "#a3b56a"
    property color onPrimary: "#0a0e0a"
    property color surface: "#0a0e0a"
    property color onSurface: "#e0e8d8"
    property color error: "#e06c75"
    property color outline: "#3a4a2a"
    property color background: "#0a0e0a"
    property color onBackground: "#e0e8d8"

    FileView {
        id: colorsFile

        path: Quickshell.env("HOME") + "/.config/dynamic-island/colors.json"
        watchChanges: true
        printErrors: false

        onLoaded: colorSync.applyColors(text())
        onFileChanged: debounce.restart()
    }

    Timer {
        id: debounce

        interval: 2000
        repeat: false
        onTriggered: colorsFile.reload()
    }

    function applyColors(raw) {
        try {
            if (!raw || raw.trim() === "")
                return

            var data = JSON.parse(raw)
            primary = data.primary || primary
            onPrimary = data.onPrimary || onPrimary
            surface = data.surface || surface
            onSurface = data.onSurface || onSurface
            error = data.error || error
            outline = data.outline || outline
            background = data.background || background
            onBackground = data.onBackground || onBackground
        } catch (e) {
            // Keep fallback/current colors on missing, partial, or invalid JSON.
        }
    }

    function loadColors() {
        try {
            if (colorsFile.loaded)
                applyColors(colorsFile.text())
        } catch (e) {
            // Keep fallback colors.
        }
    }

    Component.onCompleted: loadColors()
}
