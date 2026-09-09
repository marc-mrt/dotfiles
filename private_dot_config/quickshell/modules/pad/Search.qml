import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../config"
import "../../services"
import "../ui" as W

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

    readonly property var windowResults: {
        const q = root.query
        return Hyprland.toplevels.values
            .map(t => ({
                kind: "window",
                name: t.title || (t.lastIpcObject && t.lastIpcObject.class) || "Window",
                iconPath: Hypr.iconForClass((t.lastIpcObject && t.lastIpcObject.class) || ""),
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

    // Apps lead, matching the old drun muscle memory — window switching has
    // its own dedicated SUPER+Tab overlay now (modules/WindowSwitcher.qml),
    // so this list no longer needs a windows-first bias.
    readonly property var results: [...appResults, ...windowResults, ...shortcutResults]

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
            Hypr.focusWindow(r.toplevel.address)
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
            font.pixelSize: Metrics.fontBody
        }
        Text {
            Layout.fillWidth: true
            text: PadState.searchQuery
            color: Colors.text
            font.pixelSize: Metrics.fontBody
            elide: Text.ElideRight
        }
    }

    Text {
        visible: root.results.length === 0
        text: "No matches"
        color: Colors.alpha(Colors.text, 0.5)
        font.pixelSize: Metrics.fontSecondary
    }

    Repeater {
        model: root.results
        delegate: W.ListRow {
            id: row
            required property var modelData
            required property int index

            selected: row.index === root.selected
            // A real app/window icon when one resolves; a generic glyph
            // (never blank) for pad shortcuts or when lookup fails.
            iconSource: row.modelData.iconPath
            glyph: row.modelData.kind === "app" ? "\u{F0614}"
                : row.modelData.kind === "window" ? "\u{F05B4}"
                : "\u{F0493}"
            glyphColor: Colors.alpha(Colors.text, 0.6)
            label: row.modelData.name
            onClicked: root.activate(row.index)

            // y is only final once the layout has run, so report on both
            // "I became the selection" and "I moved".
            function reportIfSelected() {
                if (!row.selected)
                    return
                root.selectionY = row.y
                root.selectionHeight = row.height
            }
            onSelectedChanged: row.reportIfSelected()
            onYChanged: row.reportIfSelected()
            Component.onCompleted: row.reportIfSelected()
        }
    }
}
