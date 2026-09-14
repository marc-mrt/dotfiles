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
QtObject {
    id: root

    readonly property int brightness: level.value
    readonly property bool synced: level.synced
    property bool available: true

    // Re-exposed so Osd.qml has one signal per service to subscribe to
    // rather than reaching into the LiveSetting itself.
    signal changedExternally

    function refresh() {
        getProc.running = true
    }
    function setBrightness(pct) {
        level.set(Math.max(0, Math.min(100, Math.round(pct))))
    }

    property LiveSetting level: LiveSetting {
        value: 100
        command: (v) => ["ddcutil", "setvcp", "10", String(v)]
        onChangedExternally: root.changedExternally()
    }

    property Process getProc: Process {
        command: ["ddcutil", "getvcp", "10", "--brief"]
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
        triggeredOnStart: true
        onTriggered: {
            if (!root.level.busy)
                root.refresh()
        }
    }
}
