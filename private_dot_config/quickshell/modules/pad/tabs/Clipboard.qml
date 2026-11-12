import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../services"
import "../../ui" as W

// Recent clipboard history from cliphist (fed by the `wl-paste --watch`
// lines in hypr/lua/autostart.lua). Picking a row puts it back on the
// clipboard and closes the pad. Read once per open — the Overview Loader
// recreates this each time the tab is selected.
// ponytail: newest 40 only, no filtering; add a query once that is not enough.
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

    property var entries: []
    property bool loaded: false

    Process {
        running: true
        command: ["sh", "-c", "cliphist list | head -n 40"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.length > 0)
                root.loaded = true
            }
        }
    }

    W.TabHeader { title: "Clipboard" }

    W.Section {
        Repeater {
            model: root.entries
            delegate: W.ListRow {
                id: row
                required property string modelData
                glyph: "\u{F0192}"
                glyphColor: Colors.alpha(Colors.text, 0.6)
                // cliphist lines are "<id>\t<preview>"; decode wants the
                // whole line back.
                label: row.modelData.replace(/^\d+\t/, "")
                onClicked: {
                    Quickshell.execDetached(["sh", "-c",
                        'printf "%s\\n" "$1" | cliphist decode | wl-copy', "sh", row.modelData])
                    PadState.close()
                }
            }
        }
        W.EmptyRow {
            visible: root.loaded && root.entries.length === 0
            text: "No clipboard history"
        }
    }
}
