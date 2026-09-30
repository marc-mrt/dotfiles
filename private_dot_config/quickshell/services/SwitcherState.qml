pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

// SUPER+Tab window switcher — separate from the pad entirely (see
// modules/WindowSwitcher.qml for the card, shell.qml for the toplevel).
//
// Window/workspace data comes straight from `hyprctl clients -j`, not
// Quickshell's Hyprland.toplevels — its per-window lastIpcObject turned out
// stale/unpopulated for windows that hadn't triggered a fresh IPC event
// recently, which showed up as a real window on workspace 1 landing in a
// bogus "workspace 0" bucket. hyprctl is cheap enough to shell out to on
// every keypress.
//
// Navigating only moves the highlight; nothing is focused until commit()
// (Enter) or select() (clicking a tile directly). cancel() (Escape /
// click-outside / losing focus) and idleTimer both just close with no
// side effect, since navigation never touched real focus to begin with.
QtObject {
    id: root

    property bool shown: false
    property string selectedAddress: ""

    // Windows grouped by workspace (ascending id), each group's windows in
    // reading order — top-to-bottom, then left-to-right — of their actual
    // tiled position, not focus history. Rows are clustered within a 20px
    // band; ponytail: a flat two-key sort, not real layout awareness, good
    // enough for typical tiling grids. Set from listProc below, not
    // computed inline, since it's sourced from an async process.
    property var groups: []

    // Flat cycle sequence: every group's windows, in group (workspace)
    // order — this is what SUPER+Tab actually walks through.
    property var order: []

    property bool _busy: false
    // Bare-hex address of whatever was actually focused right before this
    // opened, captured synchronously in cycle() below — see there for why
    // this can't just be read back out of the hyprctl snapshot.
    property string _originAddress: ""

    function _buildGroups(clients) {
        const byWs = {}
        for (const c of clients) {
            if (!c || c.class === "org.quickshell" || c.pinned)
                continue
            const ws = (c.workspace && typeof c.workspace.id === "number") ? c.workspace.id : 0
            if (!byWs[ws])
                byWs[ws] = []
            byWs[ws].push(c)
        }
        const wsIds = Object.keys(byWs).map(Number).sort((a, b) => a - b)
        return wsIds.map(ws => ({
            wsId: ws,
            windows: byWs[ws].slice().sort((a, b) => {
                const ay = a.at ? a.at[1] : 0
                const by = b.at ? b.at[1] : 0
                if (Math.abs(ay - by) > 20)
                    return ay - by
                const ax = a.at ? a.at[0] : 0
                const bx = b.at ? b.at[0] : 0
                return ax - bx
            })
        }))
    }

    function _flatten(groupList) {
        const out = []
        for (const g of groupList)
            out.push(...g.windows.map(c => c.address))
        return out
    }

    property Process listProc: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let clients = []
                try {
                    clients = JSON.parse(text)
                } catch (e) {
                    clients = []
                }
                const groupList = root._buildGroups(clients)
                const seq = root._flatten(groupList)
                root.groups = groupList
                root.order = seq
                if (seq.length === 0) {
                    root.selectedAddress = ""
                } else {
                    const cur = seq.indexOf(root.selectedAddress)
                    if (cur !== -1) {
                        root.selectedAddress = seq[(cur + 1 + seq.length) % seq.length]
                    } else if (root._originAddress) {
                        // First open (or the previous selection vanished
                        // mid-cycle) — start from whatever was genuinely
                        // focused before we opened (captured in cycle()),
                        // not this snapshot's own "active" window, which by
                        // now is frequently this overlay itself.
                        const originIdx = seq.indexOf("0x" + root._originAddress)
                        root.selectedAddress = seq[(originIdx + 1 + seq.length) % seq.length]
                    } else {
                        root.selectedAddress = seq[0]
                    }
                }
                root._busy = false
            }
        }
    }

    property Timer idleTimer: Timer {
        interval: 2000
        onTriggered: root.close()
    }

    // Called on every SUPER+Tab press. Re-queries hyprctl each time so the
    // groups/order reflect whatever's actually on screen right now, then
    // steps the highlight one further through the sequence. Real focus
    // never moves here — see commit()/select().
    function cycle() {
        if (root._busy)
            return
        if (!root.shown) {
            // Capture what's really focused right now, synchronously,
            // before this overlay maps and Hyprland focuses it instead —
            // by the time the async hyprctl query below resolves, the
            // "currently focused" window it would report is frequently
            // this very switcher, not whatever the user was actually on.
            const active = Hyprland.activeToplevel
            root._originAddress = active ? active.address : ""
        }
        root._busy = true
        root.shown = true
        root.idleTimer.restart()
        root.listProc.running = true
    }

    // Enter: focus whatever is currently highlighted.
    function commit() {
        if (!root.shown)
            return
        if (root.selectedAddress)
            Hypr.focusWindow(root.selectedAddress)
        root.close()
    }

    // Clicking a tile: highlight and commit it in one step.
    function select(address) {
        root.selectedAddress = address
        root.commit()
    }

    // Escape / click-outside / focus lost to something else: abort with no
    // side effect, since navigating alone never moved real focus.
    function cancel() {
        root.close()
    }

    function close() {
        root.shown = false
        root.idleTimer.stop()
        root.selectedAddress = ""
        root.groups = []
        root.order = []
        root._originAddress = ""
    }
}
