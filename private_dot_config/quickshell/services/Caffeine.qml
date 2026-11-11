pragma Singleton
import QtQuick
import Quickshell.Io

// Keeps the machine awake by holding a logind idle inhibitor while active.
// hypridle.conf has ignore_systemd_inhibit = false, so one held inhibitor
// blocks every hypridle listener (dim, lock, suspend). The child dies with
// the shell, so nothing outlives it; not persisted, off on every start.
QtObject {
    id: root

    property bool active: false

    function toggle() {
        root.active = !root.active
    }

    property Process inhibitor: Process {
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell",
            "--why=Caffeine", "sleep", "infinity"]
        running: root.active
    }
}
