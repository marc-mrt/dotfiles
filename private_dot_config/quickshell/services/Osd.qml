pragma Singleton
import QtQuick

// Transient feedback for system-critical values that can change without
// going through Quickshell at all — media keys bound straight to wpctl in
// Hyprland (see hypr/lua/key_bindings.lua), hypridle's own ddcutil calls,
// any other app touching the default sink. Audio/Brightness already learn
// about those (pactl subscribe / poll); this just flashes a toast whenever
// their value moves, regardless of what moved it.
QtObject {
    id: root

    property bool visible: false
    property string kind: "" // "volume" | "brightness"
    property int value: 0
    property bool muted: false

    function show(k, v, m) {
        kind = k
        value = v
        muted = !!m
        visible = true
        hideTimer.restart()
    }

    property Timer hideTimer: Timer {
        interval: 1600
        onTriggered: root.visible = false
    }

    // Each singleton's first onXChanged is just its startup poll syncing
    // real system state into a default property value — not a change
    // anyone made. Swallow exactly that one per property, flash every one
    // after it.
    property bool audioSeen: false
    property bool brightnessSeen: false

    property Connections audioConn: Connections {
        target: Audio
        function onVolumeChanged() {
            if (root.audioSeen && !Audio.uiChange)
                root.show("volume", Audio.volume, Audio.muted)
            root.audioSeen = true
        }
        function onMutedChanged() {
            if (root.audioSeen && !Audio.uiChange)
                root.show("volume", Audio.volume, Audio.muted)
            root.audioSeen = true
        }
    }

    property Connections brightnessConn: Connections {
        target: Brightness
        function onBrightnessChanged() {
            if (root.brightnessSeen && !Brightness.uiChange)
                root.show("brightness", Brightness.brightness, false)
            root.brightnessSeen = true
        }
    }
}
