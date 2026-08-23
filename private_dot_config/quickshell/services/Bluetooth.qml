pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Owns ALL Bluetooth state and bluetoothctl calls.
QtObject {
    id: root

    property bool powered: false
    // [{ mac, name, connected, paired }]
    property var devices: []

    function refresh() {
        showProc.running = true
        listProc.running = true
    }
    function togglePower() {
        run(["bluetoothctl", "power", powered ? "off" : "on"])
    }
    function connectTo(mac) {
        run(["bluetoothctl", "connect", mac])
    }
    function disconnectFrom(mac) {
        run(["bluetoothctl", "disconnect", mac])
    }
    function run(cmd) {
        actionProc.command = cmd
        actionProc.running = true
    }

    property Process showProc: Process {
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Powered:\s*(yes|no)/)
                root.powered = m ? m[1] === "yes" : false
            }
        }
    }

    // `bluetoothctl devices Connected` support varies by bluez version, so we
    // resolve per-device state via `bluetoothctl info` in one shell pass.
    // Output line format:  MAC|<connected 0/1>|<paired 0/1>|Name
    property Process listProc: Process {
        command: ["bash", "-c",
            "bluetoothctl devices | while read -r _ mac name; do " +
            "info=$(bluetoothctl info \"$mac\"); " +
            "c=$(echo \"$info\" | grep -q 'Connected: yes' && echo 1 || echo 0); " +
            "p=$(echo \"$info\" | grep -q 'Paired: yes' && echo 1 || echo 0); " +
            "echo \"$mac|$c|$p|$name\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    if (line.length === 0)
                        continue
                    const p = line.split("|")
                    if (p.length < 4)
                        continue
                    out.push({
                        mac: p[0],
                        connected: p[1] === "1",
                        paired: p[2] === "1",
                        name: p.slice(3).join("|")
                    })
                }
                // Connected devices first, then alphabetical.
                out.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
                root.devices = out
            }
        }
    }

    property Process actionProc: Process {
        onExited: root.refresh()
    }

    property Timer poll: Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
