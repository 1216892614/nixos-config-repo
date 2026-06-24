import QtQuick

// Capsule wrapper — transparent, content floats directly on wallpaper
// Children are auto-centered; capsule sizes to content implicitWidth/Height
Rectangle {
    id: capsule

    default property alias content: inner.data

    property real padding: 10

    implicitWidth: inner.childrenRect.width + padding * 2
    implicitHeight: 28

    radius: 14
    color: "transparent"
    border.width: 0
    border.color: "transparent"

    Item {
        id: inner
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}
