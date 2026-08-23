pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Owns ALL Wi-Fi state and nmcli calls. Both the bar component and the
// popout bind to this singleton so they can never disagree or double-poll.
QtObject {
    id: root

    property bool wifiEnabled: false
    property bool connected: false
    property string activeSsid: ""
    property int activeSignal: 0
    property bool ethernetConnected: false
    // [{ ssid, signal, security, secured, active }]
    property var networks: []

    function refresh() {
        radioProc.running = true
        listProc.running = true
        ethernetProc.running = true
    }
    function toggleWifi() {
        run(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"])
    }
    function connectTo(ssid, password) {
        if (password && password.length > 0)
            run(["nmcli", "dev", "wifi", "connect", ssid, "password", password])
        else
            run(["nmcli", "dev", "wifi", "connect", ssid])
    }
    function disconnectFrom(ssid) {
        run(["nmcli", "con", "down", "id", ssid])
    }
    function run(cmd) {
        actionProc.command = cmd
        actionProc.running = true
    }

    property Process radioProc: Process {
        command: ["nmcli", "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }

    // SSID is put last so its value (which may contain colons) is the remainder.
    property Process listProc: Process {
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = ({})
                const out = []
                let active = ""
                let activeSignal = 0
                for (const line of text.split("\n")) {
                    if (line.length === 0)
                        continue
                    const p = line.split(":")
                    if (p.length < 4)
                        continue
                    const inUse = p[0].trim() === "*"
                    const signal = parseInt(p[1]) || 0
                    const security = p[2].trim()
                    const ssid = p.slice(3).join(":")
                    if (ssid.length === 0)
                        continue
                    if (inUse) {
                        active = ssid
                        activeSignal = signal
                    }
                    // Collapse duplicate BSSIDs, keep the strongest signal.
                    if (seen[ssid] !== undefined) {
                        const e = out[seen[ssid]]
                        if (signal > e.signal)
                            e.signal = signal
                        if (inUse)
                            e.active = true
                        continue
                    }
                    seen[ssid] = out.length
                    out.push({
                        ssid: ssid,
                        signal: signal,
                        security: security,
                        secured: security.length > 0,
                        active: inUse
                    })
                }
                out.sort((a, b) => b.signal - a.signal)
                root.networks = out
                root.activeSsid = active
                root.activeSignal = activeSignal
                root.connected = active.length > 0
            }
        }
    }

    // Any nmcli device of type "ethernet" in the "connected" state — good
    // enough to tell wired from wireless without needing the interface name.
    property Process ethernetProc: Process {
        command: ["bash", "-c", "nmcli -t -f TYPE,STATE dev status | grep -q '^ethernet:connected' && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: root.ethernetConnected = text.trim() === "yes"
        }
    }

    property Process actionProc: Process {
        onExited: root.refresh()
    }

    property Timer poll: Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
