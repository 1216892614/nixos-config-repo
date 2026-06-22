import Quickshell
import Quickshell.Wayland
import QtQuick
import "components"
import "services"
import "states"

PanelWindow {
    id: island

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dynamic-island"
    exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    margins.top: 8

    // --- State management ---
    property string currentState: "idle"
    property string previousState: "idle"

    width: springConfig.widthForState(currentState)
    height: 28
    // Center growth: width changes cause x to recompute → pill expands from center
    x: Math.round((screen.width - width) / 2)
    color: "transparent"

    // --- Fullscreen auto-hide ---
    opacity: fullscreenMonitor.isFullscreen ? 0 : 1
    Behavior on opacity {
        NumberAnimation { duration: 300 }
    }

    // --- Spring animation config ---
    SpringTransition {
        id: springConfig
    }

    ColorSync {
        id: colorSync
    }

    ProcessMonitor {
        id: processMonitor

        onIsRecordingChanged: island.refreshState()
    }

    FullscreenMonitor {
        id: fullscreenMonitor
    }

    // --- Howdy face unlock monitor ---
    property bool howdyActive: false

    Process {
        id: howdyChecker

        command: ["pgrep", "-x", "howdy"]

        onExited: exitCode => {
            const running = exitCode === 0
            if (island.howdyActive && !running) {
                // howdy just disappeared — trigger success animation
                island.howdyActive = false
                island.previousState = island.currentState
                island.currentState = "howdy"
            }
            island.howdyActive = running
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (!howdyChecker.running)
                howdyChecker.running = true
        }
    }

    NotificationListener {
        id: notificationListener

        onHasNotificationChanged: island.refreshState()
    }

    RecordingState {
        id: recordingState

        elapsed: processMonitor.elapsedSeconds
        indicatorColor: colorSync.error
        textColor: colorSync.onSurface
    }

    NotificationState {
        id: notificationState

        appName: notificationListener.lastAppName
        summary: notificationListener.lastSummary
        trailingMaxWidth: pill.trailingMaxWidth
        indicatorColor: colorSync.primary
        textColor: colorSync.onSurface
    }

    function refreshState() {
        const nextState = notificationListener.hasNotification ? "notification" : processMonitor.isRecording ? "recording" : "idle"
        if (nextState !== currentState) {
            previousState = currentState
            currentState = nextState
        }
    }

    // --- Elastic width animation ---
    Behavior on width {
        SpringAnimation {
            mass: springConfig.mass
            spring: springConfig.springValue
            damping: springConfig.damping
        }
    }

    // --- State change handler ---
    onCurrentStateChanged: {
        springConfig.transitionTo(currentState)
        if (currentState === "howdy") {
            // Skip crossfade — howdy handles its own animation
            pill.opacity = 1
            howdySuccess.play()
        } else {
            crossfade.restart()
        }
    }

    // --- Content crossfade sequencer ---
    SequentialAnimation {
        id: crossfade

        NumberAnimation {
            target: pill
            property: "opacity"
            to: 0
            duration: springConfig.fadeOutDuration
            easing.type: Easing.InQuad
        }
        PauseAnimation {
            duration: springConfig.fadeInDelay
        }
        NumberAnimation {
            target: pill
            property: "opacity"
            to: 1
            duration: springConfig.fadeInDuration
            easing.type: Easing.OutQuad
        }
    }

    Pill {
        id: pill

        anchors.fill: parent
        layoutMode: (island.currentState === "idle" || island.currentState === "howdy") ? "center" : "leading-trailing"
        leadingContent: island.currentState === "notification" ? notificationState.leading : recordingState.leading
        trailingContent: island.currentState === "notification" ? notificationState.trailing : recordingState.trailing
        color: colorSync.background
        centerContent: Component {
            Item {
                width: childrenRect.width
                height: childrenRect.height

                IdleClock {
                    textColor: colorSync.onSurface
                    visible: island.currentState === "idle"
                }
            }
        }

        // Howdy success animation rendered inside pill
        HowdySuccess {
            id: howdySuccess
            anchors.centerIn: parent
            eyeColor: colorSync.onSurface
            visible: island.currentState === "howdy"

            onAnimationComplete: {
                island.previousState = "howdy"
                island.currentState = "idle"
            }
        }
    }
}
