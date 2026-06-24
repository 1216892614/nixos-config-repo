import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

// Collapsible system tray: collapsed by default, click chevron to expand
Item {
    id: root

    property bool expanded: false
    property color iconColor: "#e0e8d8"

    width: row.width
    height: row.height

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        // Chevron toggle
        Text {
            text: root.expanded ? "◂" : "▸"
            color: Qt.rgba(root.iconColor.r, root.iconColor.g, root.iconColor.b, 0.6)
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }

        // Tray icons (hidden when collapsed)
        Row {
            spacing: 4
            visible: root.expanded
            opacity: root.expanded ? 1 : 0
            anchors.verticalCenter: parent.verticalCenter

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Repeater {
                model: SystemTray.items

                Image {
                    required property SystemTrayItem modelData
                    source: modelData.icon
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton)
                                modelData.activate()
                            else
                                modelData.secondaryActivate()
                        }
                    }
                }
            }
        }
    }
}
