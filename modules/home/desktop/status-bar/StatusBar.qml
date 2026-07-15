import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "components"
import "services"

PanelWindow {
    id: bar

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "status-bar"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 44

    anchors.top: true
    anchors.left: true
    anchors.right: true

    height: 44
    color: "transparent"

    ColorSync {
        id: colorSync
    }

    // Main layout: left group | stretch | right group
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 8

        // === LEFT: Workspaces + Recording ===
        RowLayout {
            spacing: 6

            Capsule {
                Layout.alignment: Qt.AlignVCenter
                WorkspaceIndicator {
                    id: workspaces
                    accentColor: colorSync.primary
                    inactiveColor: Qt.rgba(colorSync.textColor.r, colorSync.textColor.g, colorSync.textColor.b, 0.3)
                }
            }

            Capsule {
                Layout.alignment: Qt.AlignVCenter
                visible: recordingWidget.isRecording
                RecordingWidget {
                    id: recordingWidget
                    indicatorColor: colorSync.error
                    textColor: colorSync.textColor
                }
            }
        }

        // === STRETCH ===
        Item { Layout.fillWidth: true }

        // === RIGHT: Tray ===
        RowLayout {
            spacing: 6

            Capsule {
                Layout.alignment: Qt.AlignVCenter
                TrayCollapsible {
                    id: tray
                    iconColor: colorSync.textColor
                }
            }
        }
    }
}
