import QtQuick

QtObject {
    id: springTransition

    property string fromState: "idle"
    property string toState: "idle"

    // Spring parameters — dynamically resolved per transition
    readonly property real mass: _params.mass
    readonly property real springValue: _params.spring
    readonly property real damping: _params.damping

    // Content crossfade timing
    readonly property int fadeOutDuration: 200
    readonly property int fadeInDuration: 200
    readonly property int fadeInDelay: 100

    // Width targets per state
    function widthForState(state) {
        switch (state) {
        case "recording":    return 240
        case "notification": return 300
        case "howdy":        return 200
        default:             return 160  // idle
        }
    }

    function transitionTo(newState) {
        fromState = toState
        toState = newState
    }

    // Private: resolved spring config for current transition
    readonly property var _params: {
        var key = fromState + "→" + toState
        switch (key) {
        case "idle→recording":
            return { mass: 1.0, spring: 300, damping: 20 }
        case "recording→idle":
            return { mass: 1.0, spring: 200, damping: 25 }
        case "idle→notification":
            return { mass: 0.8, spring: 350, damping: 18 }
        case "notification→idle":
            return { mass: 1.2, spring: 180, damping: 28 }
        case "idle→howdy":
            return { mass: 0.8, spring: 280, damping: 22 }
        case "howdy→idle":
            return { mass: 1.0, spring: 220, damping: 24 }
        default:
            // Fallback: generic smooth settle
            return { mass: 1.0, spring: 250, damping: 22 }
        }
    }
}
