pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Owns screen brightness via ddcutil (DDC/CI over I2C — for an external
// monitor, not a laptop panel). VCP feature 0x10 is the standard "luminance"
// control; ddcutil's --brief getvcp output is `VCP 10 C <current> <max>`.
QtObject {
    id: root

    property int brightness: 100
    property bool available: true
    // True only for the setBrightness() call that just assigned
    // root.brightness — lets Osd.qml tell a slider drag here apart from an
    // external ddcutil change picked up by the poll below.
    property bool uiChange: false

    // ddcutil round-trips over I2C, which routinely takes several hundred ms
    // per call — far slower than a slider drag or a burst of scroll ticks
    // fires setBrightness(). Setting `setProc.running = true` while it's
    // still busy from the last call is a no-op (true -> true), so most
    // in-flight values used to just get silently dropped. Debounce to the
    // last value in a burst, then serialize: only ever run one ddcutil call
    // at a time, and immediately fire the next pending value once it exits.
    property int pendingBrightness: -1
    property bool applying: false

    function refresh() {
        getProc.running = true
    }
    function setBrightness(pct) {
        const v = Math.max(0, Math.min(100, Math.round(pct)))
        root.uiChange = true
        root.brightness = v
        root.uiChange = false
        root.pendingBrightness = v
        debounce.restart()
    }
    function apply() {
        if (root.applying || root.pendingBrightness < 0)
            return
        root.applying = true
        setProc.command = ["ddcutil", "setvcp", "10", String(root.pendingBrightness)]
        root.pendingBrightness = -1
        setProc.running = true
    }

    property Timer debounce: Timer {
        interval: 60
        onTriggered: root.apply()
    }

    property Process getProc: Process {
        command: ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/)
                if (m) {
                    root.available = true
                    root.brightness = Math.round((parseInt(m[1]) / parseInt(m[2])) * 100)
                } else {
                    root.available = false
                }
            }
        }
    }
    property Process setProc: Process {
        onExited: {
            root.applying = false
            if (root.pendingBrightness >= 0)
                root.apply()
        }
    }

    property Timer poll: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
