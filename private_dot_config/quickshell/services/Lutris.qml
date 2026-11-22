pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lutris library state, independent of the pad and its tabs.
QtObject {
    id: root

    property bool shown: false
    property var games: []
    property bool loading: false
    property string error: ""

    property string _stdout: ""
    property string _stderr: ""

    function open() {
        shown = true
        refresh()
    }

    function close() {
        shown = false
    }

    function toggle() {
        if (shown)
            close()
        else
            open()
    }

    function refresh() {
        if (loading)
            return
        loading = true
        error = ""
        _stdout = ""
        _stderr = ""
        libraryProc.running = true
    }

    function launch(id) {
        if (!Number.isInteger(id) || id <= 0)
            return
        close()
        Quickshell.execDetached(["/home/marc/.local/bin/lutris-library", "--launch", String(id)])
    }

    property Process libraryProc: Process {
        command: ["/home/marc/.local/bin/lutris-library"]
        stdout: StdioCollector {
            onStreamFinished: root._stdout = text
        }
        stderr: StdioCollector {
            onStreamFinished: root._stderr = text
        }
        onExited: code => {
            root.loading = false
            if (code !== 0) {
                root.error = root._stderr.trim() || "Lutris library exited with code " + code
                return
            }
            try {
                const result = JSON.parse(root._stdout)
                if (!Array.isArray(result)) {
                    root.error = "Lutris library did not return an array"
                    return
                }
                root.games = result
                root.error = ""
            } catch (e) {
                root.error = "Could not parse Lutris library: " + e.message
            }
        }
    }
}
