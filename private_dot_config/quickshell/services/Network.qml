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
    // Saved Wi-Fi connections, highest autoconnect priority first (ties by
    // name): [{ uuid, name, ssid, priority, autoconnect, active }]. Every
    // write below is keyed by uuid — a name is free text and needn't be the
    // SSID, which is why `ssid` is fetched separately (ssidProc).
    property var known: []
    // Last revealPassword() result; psk is "" for an open network.
    property var revealed: ({ uuid: "", psk: "" })

    function refresh() {
        radioProc.running = true
        listProc.running = true
        ethernetProc.running = true
        knownProc.running = true
    }
    function toggleWifi() {
        run(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"])
    }
    // uuid of the saved connection for this SSID, "" if none. Reads `known`,
    // so a binding calling it re-evaluates when the list changes.
    function knownUuid(ssid) {
        const k = root.known.find(k => k.ssid === ssid)
        return k ? k.uuid : ""
    }
    // A saved network is brought up by its profile — `dev wifi connect` can
    // pick or create a different profile for the same SSID.
    function connectTo(ssid, password) {
        const uuid = root.knownUuid(ssid)
        if (password && password.length > 0)
            run(["nmcli", "dev", "wifi", "connect", ssid, "password", password])
        else if (uuid.length > 0)
            run(["nmcli", "con", "up", "uuid", uuid])
        else
            run(["nmcli", "dev", "wifi", "connect", ssid])
    }
    function disconnectFrom(ssid) {
        run(["nmcli", "con", "down", "id", ssid])
    }
    function forget(uuid) {
        run(["nmcli", "con", "delete", "uuid", uuid])
    }
    function setAutoconnect(uuid, on) {
        run(["nmcli", "con", "modify", "uuid", uuid, "connection.autoconnect", on ? "yes" : "no"])
    }
    // ponytail: the psk is visible in argv (ps) while nmcli runs, same as connectTo.
    function setPassword(uuid, psk) {
        run(["nmcli", "con", "modify", "uuid", uuid, "wifi-sec.psk", psk])
        if (root.revealed.uuid === uuid)
            root.revealed = { uuid: uuid, psk: psk }
    }
    function revealPassword(uuid) {
        pskProc.uuid = uuid
        pskProc.command = ["nmcli", "-s", "-e", "no", "-g", "802-11-wireless-security.psk", "con", "show", "uuid", uuid]
        pskProc.running = true
    }
    // Moves one network `delta` places in the list, then rewrites the whole
    // list's priorities as N..1 by position — a list that starts all-0 (the
    // NetworkManager default) still reorders, and a position that already
    // holds its value is not rewritten. Applied to `known` straight away so
    // a second click before nmcli finishes builds on this order, not the
    // stale one.
    function move(uuid, delta) {
        const order = root.known.slice()
        const i = order.findIndex(k => k.uuid === uuid)
        const j = i + delta
        if (i < 0 || j < 0 || j >= order.length)
            return
        order.splice(j, 0, order.splice(i, 1)[0])
        const args = []
        root.known = order.map((k, n) => {
            const p = order.length - n
            if (k.priority !== p)
                args.push(k.uuid, String(p))
            return Object.assign({}, k, { priority: p })
        })
        // One process for every write; uuids and values arrive as "$@",
        // never spliced into the script.
        if (args.length > 0)
            run(["sh", "-c", 'while [ $# -gt 0 ]; do nmcli con modify uuid "$1" connection.autoconnect-priority "$2" || exit; shift 2; done', "sh"].concat(args))
    }

    // Writes run one at a time, in order. `running = true` on a busy
    // Process is a silent no-op, so a second action used to be dropped
    // whenever the first was still in flight.
    property bool busy: false
    property var queue: []
    function run(cmd) {
        if (root.busy) {
            root.queue.push(cmd)
            return
        }
        root.busy = true
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

    // NAME is put last and escaping is off, so the name (which may contain
    // colons) is exactly the remainder, as in listProc.
    property Process knownProc: Process {
        command: ["nmcli", "-t", "-e", "no", "-f", "ACTIVE,AUTOCONNECT,AUTOCONNECT-PRIORITY,UUID,TYPE,NAME", "con", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Mid-write, this reads back what we are replacing; the
                // refresh after the last queued write brings the real state.
                if (root.busy)
                    return
                const ssids = ({})
                for (const k of root.known)
                    ssids[k.uuid] = k.ssid
                const out = []
                for (const line of text.split("\n")) {
                    const p = line.split(":")
                    if (p.length < 6 || p[4] !== "802-11-wireless")
                        continue
                    out.push({
                        uuid: p[3],
                        name: p.slice(5).join(":"),
                        // Last known value until ssidProc refreshes it, so
                        // the Nearby lock icon doesn't blink every poll.
                        ssid: ssids[p[3]] || "",
                        priority: parseInt(p[2]) || 0,
                        autoconnect: p[1] === "yes",
                        active: p[0] === "yes"
                    })
                }
                out.sort((a, b) => b.priority - a.priority || a.name.localeCompare(b.name))
                root.known = out
                if (out.length > 0) {
                    // Bare uuids: nmcli takes several, and a "uuid" keyword
                    // would only name the next one.
                    root.ssidProc.command = ["nmcli", "-t", "-e", "no", "-g",
                        "connection.uuid,802-11-wireless.ssid", "con", "show"].concat(out.map(k => k.uuid))
                    root.ssidProc.running = true
                }
            }
        }
    }

    // One record per profile: the uuid line, the SSID line (escaping is off, so
    // colons are literal), a blank line.
    property Process ssidProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const ssids = ({})
                for (const rec of text.split("\n\n")) {
                    const l = rec.trim().split("\n")
                    if (l.length >= 2)
                        ssids[l[0]] = l.slice(1).join("\n")
                }
                root.known = root.known.map(k => Object.assign({}, k, { ssid: ssids[k.uuid] || k.ssid }))
            }
        }
    }

    property Process pskProc: Process {
        property string uuid: ""
        stdout: StdioCollector {
            // Only the trailing newline goes: a passphrase may end in spaces.
            onStreamFinished: root.revealed = { uuid: root.pskProc.uuid, psk: text.replace(/\n$/, "") }
        }
    }

    property Process actionProc: Process {
        onExited: {
            if (root.queue.length > 0) {
                root.actionProc.command = root.queue.shift()
                root.actionProc.running = true
            } else {
                root.busy = false
                root.refresh()
            }
        }
    }

    property Timer poll: Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
