import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    width: Screen.width
    height: Screen.height

    property string viewState: "select"
    property string selectedUser: ""
    property string selectedIcon: ""
    property int selectedSession: 0

    // ─── Background Image (full screen, cover) ───
    Image {
        id: backgroundImage
        anchors.fill: parent
        source: config.Background
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        mipmap: true
    }

    // ─── Dark scrim overlay (ensures text readability) ───
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.45
    }

    // ─── Clock (top center) ───
    Column {
        id: clockColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.12
        spacing: 2

        Text {
            id: timeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: root.height * 0.1
            font.weight: Font.Light
            color: "#ffffff"
            renderType: Text.NativeRendering

            function updateTime() {
                text = new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
            }
        }

        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: root.height * 0.024
            font.weight: Font.Normal
            color: "#ffffff"
            opacity: 0.8
            renderType: Text.NativeRendering

            function updateDate() {
                text = new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
            }
        }

        Timer {
            interval: 1000
            repeat: true
            running: true
            onTriggered: {
                timeLabel.updateTime()
                dateLabel.updateDate()
            }
        }

        Component.onCompleted: {
            timeLabel.updateTime()
            dateLabel.updateDate()
        }
    }

    // ─── User Selection View ───
    Item {
        id: selectView
        anchors.fill: parent
        visible: opacity > 0
        opacity: viewState === "select" ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.22
            spacing: 40

            Repeater {
                model: userModel
                delegate: Item {
                    width: 110
                    height: 120

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            id: avatarCircle
                            width: 56
                            height: 56
                            radius: 28
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: avatarMouse.containsMouse ? "#50ffffff" : "#30ffffff"
                            border.color: avatarMouse.containsMouse ? "#f38ba8" : "#60ffffff"
                            border.width: 2

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: avatarMouse.containsMouse ? 1.06 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: model.name ? model.name.charAt(0).toUpperCase() : "?"
                                font.pixelSize: 22
                                font.weight: Font.Medium
                                color: "#ffffff"
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: model.name
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: "#ffffff"
                            opacity: 0.9
                        }
                    }

                    MouseArea {
                        id: avatarMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selectedUser = model.name
                            selectedIcon = model.icon || ""
                            viewState = "login"
                            passwordInput.text = ""
                            passwordInput.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ─── Login View (password entry) ───
    Item {
        id: loginView
        anchors.fill: parent
        visible: opacity > 0
        opacity: viewState === "login" ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.24
            spacing: 12

            Rectangle {
                width: 72
                height: 72
                radius: 36
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#35ffffff"
                border.color: "#90ffffff"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: selectedUser ? selectedUser.charAt(0).toUpperCase() : "?"
                    font.pixelSize: 30
                    font.weight: Font.Medium
                    color: "#ffffff"
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: selectedUser
                font.pixelSize: 16
                font.weight: Font.Medium
                color: "#ffffff"
            }

            Item { width: 1; height: 4 }

            Rectangle {
                id: passwordPill
                width: 220
                height: 36
                radius: 18
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#25ffffff"
                border.color: passwordInput.activeFocus ? "#f38ba8" : "#40ffffff"
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: 150 } }

                TextField {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 36
                    verticalAlignment: TextInput.AlignVCenter

                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 800
                    placeholderText: "Password"
                    placeholderTextColor: "#70ffffff"
                    color: "#ffffff"
                    font.pixelSize: 13
                    selectByMouse: true

                    background: Rectangle { color: "transparent" }

                    Keys.onReturnPressed: sddm.login(selectedUser, passwordInput.text, selectedSession)
                    Keys.onEnterPressed: sddm.login(selectedUser, passwordInput.text, selectedSession)
                    Keys.onEscapePressed: { viewState = "select"; errorMsg.text = "" }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: passwordInput.text.length > 0 ? "#f38ba8" : "#25ffffff"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\u2192"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: passwordInput.text.length > 0 ? "#1e1e2e" : "#60ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sddm.login(selectedUser, passwordInput.text, selectedSession)
                    }
                }
            }

            Text {
                id: errorMsg
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                font.pixelSize: 11
                color: "#f38ba8"
                opacity: text !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Switch User"
                font.pixelSize: 11
                color: "#a0ffffff"
                opacity: switchMouse.containsMouse ? 1.0 : 0.7
                Behavior on opacity { NumberAnimation { duration: 120 } }

                MouseArea {
                    id: switchMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { viewState = "select"; errorMsg.text = "" }
                }
            }
        }
    }

    // ─── Bottom power buttons ───
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        spacing: 28

        Repeater {
            model: ListModel {
                ListElement { label: "Sleep"; act: "suspend" }
                ListElement { label: "Restart"; act: "reboot" }
                ListElement { label: "Shut Down"; act: "poweroff" }
            }
            delegate: Text {
                text: model.label
                font.pixelSize: 11
                color: "#a0ffffff"
                opacity: pwrMouse.containsMouse ? 1.0 : 0.65
                Behavior on opacity { NumberAnimation { duration: 120 } }

                MouseArea {
                    id: pwrMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (model.act === "suspend") sddm.suspend()
                        else if (model.act === "reboot") sddm.reboot()
                        else sddm.powerOff()
                    }
                }
            }
        }
    }

    // ─── Login handlers ───
    Connections {
        target: sddm
        function onLoginSucceeded() { errorMsg.text = "" }
        function onLoginFailed() {
            errorMsg.text = "Incorrect password"
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
    }

    // ─── Single user: skip to login ───
    Component.onCompleted: {
        if (userModel.count === 1) {
            selectedUser = userModel.data(userModel.index(0, 0), Qt.UserRole + 1)
            selectedIcon = userModel.data(userModel.index(0, 0), Qt.UserRole + 4)
            viewState = "login"
            passwordInput.forceActiveFocus()
        }
    }
}
