pragma Singleton
import QtQuick
import Quickshell.Hyprland

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
    property string kind: "" // "volume" | "brightness" | "mic" | "workspace"
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

    property Connections micConn: Connections {
        target: Audio
        function onSourceChangedExternally() {
            // `muted` carries the mic state; value is unused for this kind.
            root.show("mic", 0, Audio.sourceMuted)
        }
    }

    // With no bar there is nothing else on screen saying which workspace
    // you just landed on. Skipped while the pad is up: its footer already
    // shows the same dots. lastWs keeps the startup/reload assignment from
    // counting as a switch.
    property int lastWs: -1
    property Connections workspaceConn: Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            const ws = Hyprland.focusedWorkspace
            if (!ws)
                return
            if (root.lastWs !== -1 && ws.id !== root.lastWs && !PadState.shown)
                root.show("workspace", ws.id, false)
            root.lastWs = ws.id
        }
    }

    property Connections brightnessConn: Connections {
        target: Brightness
        function onChangedExternally() {
            root.show("brightness", Brightness.brightness, false)
        }
    }
}
