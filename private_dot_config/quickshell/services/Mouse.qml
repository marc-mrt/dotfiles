pragma Singleton
import QtQuick
import Quickshell.Io

// Owns live mouse sensitivity via hyprctl eval + hl.config() (-1.0..1.0,
// Hyprland's own libinput accel-speed range — see
// ~/.config/hypr/lua/options.lua). This build's config is Lua-parsed, so
// plain `hyprctl keyword` refuses ("keyword can't work with non-legacy
// parsers") — hl.config({input={sensitivity=v}}) via `hyprctl eval` is the
// equivalent live patch for the new parser. Same live-only model as
// services/Brightness.qml: it doesn't write back to the lua source, so a
// Hyprland reload/restart reverts to whatever options.lua says.
//
// The third slider-backed value in the shell, and so the third to go
// through LiveSetting. It used to spawn a hyprctl per drag position — fine
// on a fast call, but there was no reason for it to be the one setter that
// didn't debounce.
QtObject {
    id: root

    readonly property real sensitivity: level.value
    readonly property bool synced: level.synced

    function refresh() {
        getProc.running = true
    }
    function setSensitivity(v) {
        level.set(Math.max(-1, Math.min(1, v)))
    }

    property LiveSetting level: LiveSetting {
        value: 0
        command: (v) => ["hyprctl", "eval",
            `hl.config({input={sensitivity=${v.toFixed(2)}}})`]
    }

    property Process getProc: Process {
        command: ["hyprctl", "getoption", "input:sensitivity", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/"float":\s*(-?[\d.]+)/)
                if (m)
                    root.level.report(parseFloat(m[1]))
            }
        }
    }

    Component.onCompleted: root.refresh()
}
