pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Owns screen brightness via ddcutil (DDC/CI over I2C — for an external
// monitor, not a laptop panel). VCP feature 0x10 is the standard "luminance"
// control; ddcutil's --brief getvcp output is `VCP 10 C <current> <max>`.
//
// The debounce/serialize/who-changed-it machinery all lives in
// LiveSetting; what's left here is the two things that are actually about
// brightness — the command that writes it and the regex that reads it.
//
// Every call is pinned to one bus and one MCCS version, which is the
// difference between a slider that tracks and one that doesn't. A bare
// `ddcutil getvcp 10` re-probes every I2C bus in the machine and then
// round-trips for the display's MCCS version before it even asks for the
// feature: 3.5s measured here against 0.12s pinned. --noverify drops the
// read-back after a write, which we don't need because the poll re-reads
// anyway.
QtObject {
    id: root

    readonly property int brightness: level.value
    readonly property bool synced: level.synced
    // Nothing to talk to until detect has found a bus, so the chip stays
    // hidden rather than appearing and then vanishing.
    property bool available: false

    // The DDC monitor's I2C bus, found once at startup. Costs one slow
    // probe; every call after it is fast.
    property int bus: -1
    readonly property var ddc: (args) => ["ddcutil", "--bus", String(root.bus),
                                          "--mccs", "2.2"].concat(args)

    // Re-exposed so Osd.qml has one signal per service to subscribe to
    // rather than reaching into the LiveSetting itself.
    signal changedExternally

    function refresh() {
        if (root.bus >= 0)
            getProc.running = true
    }
    function setBrightness(pct) {
        level.set(Math.max(0, Math.min(100, Math.round(pct))))
    }

    property LiveSetting level: LiveSetting {
        value: 100
        command: (v) => root.ddc(["--noverify", "setvcp", "10", String(v)])
        onChangedExternally: root.changedExternally()
    }

    property Process detectProc: Process {
        running: true
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/\/dev\/i2c-(\d+)/)
                if (m) {
                    root.bus = parseInt(m[1])
                    root.available = true
                    root.refresh()
                }
            }
        }
    }

    property Process getProc: Process {
        command: root.ddc(["getvcp", "10", "--brief"])
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/)
                if (m) {
                    root.available = true
                    root.level.report(Math.round((parseInt(m[1]) / parseInt(m[2])) * 100))
                } else {
                    root.available = false
                }
            }
        }
    }

    property Timer poll: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!root.level.busy)
                root.refresh()
        }
    }
}
