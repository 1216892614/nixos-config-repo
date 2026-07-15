import Quickshell
import Quickshell.Io
import QtQuick

// 配色同步：读取 ~/.config/dynamic-island/colors.json
Item {
  id: colorSync
  visible: false
  width: 0; height: 0

  property color primary: "#a3b56a"
  property color fgPrimary: "#0a0e0a"
  property color surface: "#1a1e1a"
  property color textColor: "#e0e8d8"
  property color error: "#e06c75"
  property color dim: "#4a5a4a"
  property color bg: "#0a0e0a"

  FileView {
    id: colorsFile
    path: Quickshell.env("HOME") + "/.config/dynamic-island/colors.json"
    watchChanges: true
    printErrors: false
  }

  Timer {
    interval: 5000
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
      if (!raw || raw.trim() === "") return
      var data = JSON.parse(raw)
      primary = data.accent || data.primary || primary
      surface = data.surface || surface
      textColor = data.text || data.onSurface || textColor
      error = data.error || error
      dim = data.dim || dim
      bg = data.bg || data.background || bg
    } catch (e) {}
  }

  Component.onCompleted: {
    if (colorsFile.loaded)
      applyColors(colorsFile.text())
  }
}
