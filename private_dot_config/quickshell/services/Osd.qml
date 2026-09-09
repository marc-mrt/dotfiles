pragma Singleton
import QtQuick

// Transient feedback for system-critical values that can change without
// going through Quickshell at all — media keys bound straight to wpctl in
// Hyprland (see hypr/lua/key_bindings.lua), hypridle's own ddcutil calls,
// any other app touching the default sink.
//
// This used to read a `uiChange` flag off each service at exactly the
// right moment and keep its own per-property "swallow the first change"
// bookkeeping, because a startup poll syncing real state onto a default
// looks identical to an external change when all you have is a flag. Both
// services now say what they mean: changedExternally fires for a real
// outside change and for nothing else, so there is nothing left here but
// deciding what to show.
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

    property Connections audioConn: Connections {
        target: Audio
        function onChangedExternally() {
            root.show("volume", Audio.volume, Audio.muted)
        }
    }

    property Connections brightnessConn: Connections {
        target: Brightness
        function onChangedExternally() {
            root.show("brightness", Brightness.brightness, false)
        }
    }
}
