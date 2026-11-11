pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// How often each app has been launched from the pad, keyed by desktop-entry
// id, so search can float the apps you actually use. A service and not state
// inside Search because Search is recreated every time the tab opens.
// Persisted as a small JSON object under ~/.local/state so it survives
// restarts; a missing or corrupt file just means starting from zero.
Singleton {
    id: root

    // Replaced wholesale on every bump so bindings reading it re-evaluate.
    property var counts: ({})

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/quickshell"

    function bump(id) {
        if (!id)
            return
        const next = Object.assign({}, root.counts)
        next[id] = (next[id] || 0) + 1
        root.counts = next
        // One shell so the directory is guaranteed to exist before the
        // write (FileView won't create it, and two detached commands race).
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$1" && printf %s "$2" > "$1/launches.json"',
            "sh", root.dir, JSON.stringify(next)])
    }

    FileView {
        id: file
        path: root.dir + "/launches.json"
        // Counts must be there before the first search is typed.
        blockLoading: true
        onLoaded: {
            try {
                const v = JSON.parse(file.text())
                if (v && typeof v === "object" && !Array.isArray(v))
                    root.counts = v
            } catch (e) {
                // Corrupt file: ignore, the next bump overwrites it.
            }
        }
        // Missing file is the normal first run.
        onLoadFailed: {}
    }
}
