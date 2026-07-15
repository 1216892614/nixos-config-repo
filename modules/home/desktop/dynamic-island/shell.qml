import Quickshell
import Quickshell.Wayland
import QtQuick
import "services"
import "layers"

ShellRoot {
  id: root

  // ── 全局服务 ──────────────────────────────────────────────────────────
  ColorSync { id: colorSync }
  HowdyMonitor { id: howdyMonitor }
  RecordingMonitor { id: recordingMonitor }
  AgentMonitor { id: agentMonitor }

  // ── 每个显示器一个灵动岛 ──────────────────────────────────────────────
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: islandWindow
        property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dynamic-island"
        exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.left: true
        anchors.right: true

        implicitHeight: island.targetH + 12
        color: "transparent"

        Island {
          id: island
          anchors.centerIn: parent

          colorSync: colorSync
          howdyMonitor: howdyMonitor
          recordingMonitor: recordingMonitor
          agentMonitor: agentMonitor
        }
      }
    }
  }
}
