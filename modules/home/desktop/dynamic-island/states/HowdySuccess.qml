import QtQuick
import "../components"

Item {
    id: howdyState

    property alias eyeColor: helloEyes.eyeColor

    signal animationComplete()

    HelloEyes {
        id: helloEyes
        anchors.centerIn: parent
    }

    SequentialAnimation {
        id: successSequence

        // Eyes appear neutral
        PropertyAction { target: helloEyes; property: "opacity"; value: 1 }
        PropertyAction { target: helloEyes; property: "eyeState"; value: "neutral" }
        PauseAnimation { duration: 300 }

        // Pupils shift — locking on
        PropertyAction { target: helloEyes; property: "eyeState"; value: "gazing" }
        PauseAnimation { duration: 500 }

        // Eyes squish — confirmed
        PropertyAction { target: helloEyes; property: "eyeState"; value: "smiling" }
        PauseAnimation { duration: 400 }

        // Fade out
        NumberAnimation { target: helloEyes; property: "opacity"; to: 0; duration: 300 }

        ScriptAction { script: howdyState.animationComplete() }
    }

    function play() {
        helloEyes.opacity = 0
        helloEyes.eyeState = "neutral"
        successSequence.start()
    }
}
