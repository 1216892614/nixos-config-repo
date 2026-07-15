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

  // ── 灵动岛窗口 ────────────────────────────────────────────────────────
  PanelWindow {
    id: islandWindow

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dynamic-island"
    exclusionMode: ExclusionMode.Ignore

    // 仅锚定顶部，不锚定左右 → wlr-layer-shell 自动水平居中
    anchors.top: true

    // 窗口尺寸紧贴灵动岛内容，避免液态玻璃覆盖全屏
    width: island.totalWidth + 12   // 6px padding each side
    height: island.targetH + 12     // 6px top + 6px bottom
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
