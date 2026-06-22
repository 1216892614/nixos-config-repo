import QtQuick

Item {
    id: notifState

    property string summary: ""
    property string appName: ""
    property real trailingMaxWidth: 200
    property color indicatorColor: "#a3b56a"
    property color textColor: "#e0e8d8"

    property Component leading: Component {
        Rectangle {
            width: 12
            height: 12
            radius: 3
            color: notifState.indicatorColor
        }
    }

    property Component trailing: Component {
        Text {
            text: notifState.summary
            color: notifState.textColor
            font.pixelSize: 13
            font.weight: Font.Regular
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, notifState.trailingMaxWidth)
        }
    }
}
