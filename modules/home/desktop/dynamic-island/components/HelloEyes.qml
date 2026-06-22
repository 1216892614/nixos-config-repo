import QtQuick

Item {
    id: eyes
    width: 60; height: 28

    property string eyeState: "neutral"  // "neutral" | "gazing" | "smiling"
    property color eyeColor: "#e0e8d8"

    opacity: 0

    Row {
        anchors.centerIn: parent
        spacing: 12

        Rectangle {
            id: leftEye
            width: 16; height: leftH
            radius: width / 2
            color: eyes.eyeColor
            anchors.verticalCenter: parent.verticalCenter

            property real leftH: eyes.eyeState === "smiling" ? 6 : 16
            Behavior on leftH { SpringAnimation { spring: 200; damping: 15 } }

            Rectangle {
                width: 6; height: 6; radius: 3
                color: "#0a0e0a"
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: eyes.eyeState === "gazing" ? 2 : 0
                visible: eyes.eyeState !== "smiling"
                Behavior on anchors.horizontalCenterOffset {
                    NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                }
            }
        }

        Rectangle {
            id: rightEye
            width: 16; height: rightH
            radius: width / 2
            color: eyes.eyeColor
            anchors.verticalCenter: parent.verticalCenter

            property real rightH: eyes.eyeState === "smiling" ? 6 : 16
            Behavior on rightH { SpringAnimation { spring: 200; damping: 15 } }

            Rectangle {
                width: 6; height: 6; radius: 3
                color: "#0a0e0a"
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: eyes.eyeState === "gazing" ? 2 : 0
                visible: eyes.eyeState !== "smiling"
                Behavior on anchors.horizontalCenterOffset {
                    NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                }
            }
        }
    }
}
