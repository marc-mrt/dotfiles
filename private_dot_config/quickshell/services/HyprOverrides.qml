pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistence for the two settings the pad can change that otherwise only
// live in RAM. Mouse.qml patches Hyprland through `hyprctl eval` and
// Brightness.qml writes the monitor over DDC/CI; neither touches a config
// file, so a reboot took the value back to whatever lua/options.lua said.
//
// The fix is lua/user-overrides.lua, required last by hyprland.lua and so
// winning over lua/options.lua. It sits with the rest of the hypr lua by
// design: it is the machine's own layer over the tracked config, which is
// why chezmoi ignores it and why nothing syncs it to another device. In
// practice Quickshell writes every line of it — hand edits are lost on the
// next slider move. Hyprland is the only reader, which is why there is no
// parser here — at startup each service reads real system state back
// (hyprctl getoption, ddcutil getvcp) and that state is already whatever
// this file put there.
//
// Sensitivity is a config option, so it goes in as one. Brightness isn't
// Hyprland's to hold at all, so it goes in as the ddcutil call that
// restores it, on the same hyprland.start event autostart.lua uses.
QtObject {
    id: root

    readonly property string path: Quickshell.env("HOME")
        + "/.config/hypr/lua/user-overrides.lua"

    // Both services start on a default (0, 100%) and only learn the real
    // value once their first poll lands. Writing before that would put the
    // default into the file and, for the seconds until the poll returns,
    // the file would be a worse record than the one it replaced.
    readonly property bool ready: Mouse.synced
        && (Brightness.synced || !Brightness.available)

    readonly property string content:
        "-- This machine's own Hyprland overrides. Written by Quickshell\n"
        + "-- (services/HyprOverrides.qml) whenever a pad slider moves, so hand\n"
        + "-- edits are lost. Not tracked by chezmoi. Required last from\n"
        + "-- hyprland.lua so it wins over lua/options.lua.\n"
        + "\n"
        + `hl.config({ input = { sensitivity = ${Mouse.sensitivity.toFixed(2)} } })\n`
        // ponytail: fires alongside Quickshell's own startup ddcutil poll,
        // so two processes may hit the same I2C bus within a second of each
        // other. Harmless in practice (the poll just reads); serialize
        // through a wrapper if a monitor ever reports garbage at login.
        + (Brightness.available
            ? "\nhl.on(\"hyprland.start\", function()\n"
                + `    hl.exec_cmd("ddcutil setvcp 10 ${Brightness.brightness}")\n`
                + "end)\n"
            : "")

    onContentChanged: {
        if (root.ready)
            root.debounce.restart()
    }
    onReadyChanged: {
        if (root.ready)
            root.debounce.restart()
    }

    // The slider already debounces the device write; this debounces the
    // disk write behind it, so a drag is one file rewrite and not fifty.
    property Timer debounce: Timer {
        interval: 500
        onTriggered: root.file.setText(root.content)
    }

    property FileView file: FileView {
        path: root.path
        atomicWrites: true
        // Never read: this file is output only. blockAllReads doesn't stop
        // the load the initial path assignment kicks off, so on a machine
        // that hasn't written it yet that load fails and prints — hence
        // printErrors off, and a save failure reported by hand instead so
        // silencing the noise doesn't silence the one error that matters.
        blockAllReads: true
        printErrors: false
        onSaveFailed: (error) => console.warn(
            "HyprOverrides: could not write " + root.path + ": " + error)
    }
}
