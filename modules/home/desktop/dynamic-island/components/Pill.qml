import QtQuick

Rectangle {
    id: pill

    property string layoutMode: "center"
    property alias leadingContent: leadingLoader.sourceComponent
    property alias trailingContent: trailingLoader.sourceComponent
    property alias centerContent: centerLoader.sourceComponent
    readonly property real trailingMaxWidth: width - leadingLoader.width - 32

    radius: 14
    color: "#0a0e0a"

    Behavior on color {
        ColorAnimation { duration: 200 }
    }

    Loader {
        id: centerLoader
        anchors.centerIn: parent
        visible: pill.layoutMode === "center"
        active: visible
    }

    Loader {
        id: leadingLoader
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: pill.layoutMode === "leading-trailing"
        active: visible
    }

    Loader {
        id: trailingLoader
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        visible: pill.layoutMode === "leading-trailing"
        active: visible
    }
}
