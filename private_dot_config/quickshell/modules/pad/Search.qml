import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../config"
import "../../services"

// Unified search — apps, open windows, and pad shortcuts in one filtered,
// keyboard-navigable list. Pad.qml forwards Up/Down/Enter from its hidden
// key-catcher into moveSelection()/activateSelected() below; query text
// itself is owned by PadState.searchQuery (Pad.qml writes it as you type).
ColumnLayout {
    id: root
    spacing: 8

    readonly property string query: PadState.searchQuery.toLowerCase()

    // Every one of these is an inline overview tab now — the calendar was
    // the last exclusive full-card panel and moved in with the rest — so
    // there's no per-entry mode flag to carry anymore.
    readonly property var shortcuts: [
        { name: "Network", target: "network" },
        { name: "Bluetooth", target: "bluetooth" },
        { name: "Volume", target: "volume" },
        { name: "Brightness", target: "brightness" },
        { name: "Calendar", target: "calendar" }
    ]

    // Icon lookup by window class, same heuristic Workspaces.qml already
    // uses for taskbar-style icons: class -> desktop entry -> theme path.
    function windowIconPath(t) {
        const cls = (t.lastIpcObject && t.lastIpcObject.class) || ""
        if (!cls)
            return ""
        const entry = DesktopEntries.heuristicLookup(cls)
        return entry ? Quickshell.iconPath(entry.icon, "") : ""
    }

    readonly property var windowResults: {
        const q = root.query
        return Hyprland.toplevels.values
            .map(t => ({
                kind: "window",
                name: t.title || (t.lastIpcObject && t.lastIpcObject.class) || "Window",
                iconPath: root.windowIconPath(t),
                toplevel: t
            }))
            .filter(r => !q || r.name.toLowerCase().includes(q))
    }

    readonly property var appResults: {
        const q = root.query
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
            .filter(e => !q
                || e.name.toLowerCase().includes(q)
                || (e.genericName ?? "").toLowerCase().includes(q))
            .slice(0, 8)
            .map(e => ({ kind: "app", name: e.name, iconPath: Quickshell.iconPath(e.icon, ""), entry: e }))
    }

    readonly property var shortcutResults: root.shortcuts
        .filter(s => !root.query || s.name.toLowerCase().includes(root.query))
        .map(s => ({ kind: "panel", name: s.name, iconPath: "", target: s.target }))

    // SUPER+Tab (searchBias === "windows") biases open windows to the top;
    // SUPER+SPACE leads with apps, matching the old drun muscle memory.
    readonly property var results: PadState.searchBias === "windows"
        ? [...windowResults, ...appResults, ...shortcutResults]
        : [...appResults, ...windowResults, ...shortcutResults]

    property int selected: 0
    onResultsChanged: selected = 0

    // Where the current selection sits within this list, in this item's own
    // coordinates. Published so whatever is scrolling us can keep it in
    // view — the list is clipped now (modules/pad/Overview.qml), and
    // Up/Down would otherwise happily walk the selection straight off the
    // bottom of the visible area with nothing appearing to happen.
    property real selectionY: 0
    property real selectionHeight: 0

    function moveSelection(delta) {
        if (root.results.length === 0)
            return
        root.selected = (root.selected + delta + root.results.length) % root.results.length
    }

    function activateSelected() {
        activate(root.selected)
    }

    function activate(index) {
        const r = root.results[index]
        if (!r)
            return
        // Apps/windows hand off to another window entirely, so get out of
        // the way. Panels are the opposite — the point is to keep using
        // them, so stay open and drop back to the overview instead of
        // closing right after picking one.
        if (r.kind === "app") {
            r.entry.execute()
            PadState.close()
        } else if (r.kind === "window") {
            // Was Hyprland.dispatch("focuswindow address:" + address),
            // which this Hyprland's Lua config parser rejects outright —
            // so picking a window here closed the pad and left focus
            // exactly where it was, silently. See the matching comment on
            // services/Notifications.qml's focusApp() for the details.
            Hyprland.dispatch('hl.dsp.focus({ window = "address:0x' + r.toplevel.address + '" })')
            PadState.close()
        } else if (r.kind === "panel") {
            // Leaves the query/PadState cleanup to Pad.qml's reactive
            // handler (fires off inlineOpen leaving "search") — no direct
            // call here, same as clicking a widget tile wouldn't need one.
            PanelState.toggleInline(r.target)
        }
    }

    // Search field — display only, the hidden TextInput in Pad.qml is what
    // actually owns keyboard focus and writes PadState.searchQuery.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: "\u{F0349}"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: 15
        }
        Text {
            Layout.fillWidth: true
            text: PadState.searchQuery
            color: Colors.text
            font.pixelSize: 15
            elide: Text.ElideRight
        }
    }

    Text {
        visible: root.results.length === 0
        text: "No matches"
        color: Colors.alpha(Colors.text, 0.5)
        font.pixelSize: 13
    }

    Repeater {
        model: root.results
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool isSelected: row.index === root.selected
            Layout.fillWidth: true
            implicitHeight: 40
            radius: 8
            color: (row.isSelected || rowMa.containsMouse)
                ? Colors.alpha(Colors.text, 0.08) : "transparent"

            // y is only final once the layout has run, so report on both
            // "I became the selection" and "I moved".
            function reportIfSelected() {
                if (!row.isSelected)
                    return
                root.selectionY = row.y
                root.selectionHeight = row.height
            }
            onIsSelectedChanged: row.reportIfSelected()
            onYChanged: row.reportIfSelected()
            Component.onCompleted: row.reportIfSelected()

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 10

                // Real app/window icon when one resolves; a generic glyph
                // (never blank) for pad shortcuts or when lookup fails.
                IconImage {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    visible: row.modelData.iconPath.length > 0
                    source: row.modelData.iconPath
                }
                Text {
                    visible: row.modelData.iconPath.length === 0
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignHCenter
                    text: row.modelData.kind === "app" ? "\u{F0614}"
                        : row.modelData.kind === "window" ? "\u{F05B4}"
                        : "\u{F0493}"
                    color: Colors.alpha(Colors.text, 0.6)
                    font.pixelSize: 18
                }
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    color: Colors.text
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.activate(row.index)
            }
        }
    }
}
