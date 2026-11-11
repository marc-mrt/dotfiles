import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import "../../config"
import "../../services"
import "../ui" as W
import "searchScore.js" as Score

// Unified search — apps, open windows, and pad shortcuts in one filtered,
// keyboard-navigable list. Pad.qml forwards Up/Down/Enter from its hidden
// key-catcher into moveSelection()/activateSelected() below; query text
// itself is owned by PadState.searchQuery (Pad.qml writes it as you type).
ColumnLayout {
    id: root
    spacing: 8

    // Raw (trimmed) text: the scorer lowercases for itself, and the run
    // fallback and calculator need what was actually typed.
    readonly property string query: PadState.searchQuery.trim()

    // Every one of these is an inline overview tab now — the calendar was
    // the last exclusive full-card panel and moved in with the rest — so
    // there's no per-entry mode flag to carry anymore.
    readonly property var shortcuts: [
        { id: "network", name: "Network", target: "network" },
        { id: "bluetooth", name: "Bluetooth", target: "bluetooth" },
        { id: "volume", name: "Volume", target: "volume" },
        { id: "brightness", name: "Brightness", target: "brightness" },
        { id: "calendar", name: "Calendar", target: "calendar" },
        { id: "system", name: "System", target: "system" },
        { id: "settings", name: "Settings", target: "settings" },
        { id: "media", name: "Media", target: "media" },
        { id: "power", name: "Power", target: "power" }
    ]

    // Session actions are results only while you are searching for them —
    // never on an empty query, where one stray Enter must not offer a
    // reboot. `verb` is non-empty for the ones that ask for a second Enter.
    readonly property var sessionEntries: [
        { id: "lock", name: "Lock", glyph: "\u{F033E}", verb: "", keywords: ["screen"] },
        { id: "suspend", name: "Suspend", glyph: "\u{F04B2}", verb: "", keywords: ["sleep"] },
        { id: "logout", name: "Log out", glyph: "\u{F0343}", verb: "log out", keywords: ["logout", "sign out", "exit"] },
        { id: "reboot", name: "Reboot", glyph: "\u{F0709}", verb: "reboot", keywords: ["restart"] },
        { id: "poweroff", name: "Power off", glyph: "\u{F0425}", verb: "power off", keywords: ["shutdown", "shut down"] }
    ]

    // Window match is on title OR class, so "firefox" finds a window whose
    // title is the page name.
    readonly property var windowResults: Score.rank(
        Hyprland.toplevels.values.map(t => {
            const cls = (t.lastIpcObject && t.lastIpcObject.class) || ""
            return {
                id: t.address, kind: "window", toplevel: t,
                name: t.title || cls || "Window", alt: cls,
                iconPath: Hypr.iconForClass(cls)
            }
        }), root.query, {}, 5)

    // Counts are read here so a launch re-ranks the next search.
    readonly property var appResults: Score.rank(
        DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
            .map(e => ({
                id: e.id, kind: "app", entry: e, name: e.name,
                generic: e.genericName ?? "", keywords: e.keywords ?? [],
                iconPath: Quickshell.iconPath(e.icon, "")
            })), root.query, LaunchHistory.counts, 8)

    readonly property var shortcutResults: Score.rank(
        root.shortcuts.map(s => ({ id: s.id, kind: "panel", name: s.name, iconPath: "", target: s.target })),
        root.query, {}, 0)

    readonly property var sessionResults: root.query === "" ? []
        : Score.rank(root.sessionEntries.map(s => Object.assign({ kind: "session", iconPath: "" }, s)),
                     root.query, {}, 0)

    // "= 14" on top; Enter copies. Null for anything that isn't arithmetic.
    readonly property var calcValue: Score.calc(root.query)
    readonly property var calcResults: root.calcValue === null ? []
        : [{ kind: "calc", name: "= " + String(+root.calcValue.toPrecision(12)),
             value: String(+root.calcValue.toPrecision(12)), iconPath: "" }]

    // Apps lead, matching the old drun muscle memory — window switching has
    // its own dedicated SUPER+Tab overlay now (modules/WindowSwitcher.qml),
    // so this list no longer needs a windows-first bias.
    readonly property var matches: [...calcResults, ...appResults, ...windowResults,
                                    ...shortcutResults, ...sessionResults]

    // Nothing matched: offer to run what was typed instead of a dead end.
    readonly property var results: (matches.length === 0 && root.query !== "")
        ? [{ kind: "run", name: "Run '" + root.query + "'", iconPath: "" }]
        : matches

    property int selected: 0
    // Reset on a new query only. Live window titles change `results` while
    // you arrow through it; snapping to 0 then made the highlight jump.
    onQueryChanged: { selected = 0; armed = "" }
    onResultsChanged: selected = Math.max(0, Math.min(selected, results.length - 1))

    // Id of the session entry waiting for its confirming second Enter.
    property string armed: ""
    Timer {
        id: armTimer
        interval: 3000
        onTriggered: root.armed = ""
    }

    // Copying needs wl-copy; without it the calculator row just shows.
    property bool canCopy: false
    Process {
        running: true
        command: ["sh", "-c", "command -v wl-copy"]
        onExited: code => root.canCopy = code === 0
    }

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
        root.armed = ""
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
            LaunchHistory.bump(r.id)
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
        } else if (r.kind === "session") {
            // Destructive ones need Enter twice within 3s; the row text
            // says so (see label below). Lock/suspend are harmless.
            if (r.verb !== "" && root.armed !== r.id) {
                root.armed = r.id
                armTimer.restart()
                return
            }
            armTimer.stop()
            root.armed = ""
            Session[r.id]()
            PadState.close()
        } else if (r.kind === "calc") {
            if (!root.canCopy)
                return
            Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", r.value])
            PadState.close()
        } else if (r.kind === "run") {
            // sh -c so pipes and args work like a terminal line; from $HOME
            // because the shell's own cwd is meaningless to the user.
            Quickshell.execDetached({ command: ["sh", "-c", root.query],
                                      workingDirectory: Quickshell.env("HOME") })
            PadState.close()
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
            visible: PadState.searchQuery !== ""
            Layout.maximumWidth: root.width - 60
            text: PadState.searchQuery
            color: Colors.text
            font.pixelSize: Metrics.fontBody
            elide: Text.ElideRight
        }
        // The hidden TextInput owns the real cursor; this one just shows
        // where typing lands, blinking like a normal field.
        Rectangle {
            Layout.preferredWidth: 2
            Layout.preferredHeight: Metrics.fontBody + 2
            color: Colors.accent
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: PadState.shown
                NumberAnimation { to: 0; duration: 500 }
                NumberAnimation { to: 1; duration: 500 }
            }
        }
        Text {
            visible: PadState.searchQuery === ""
            Layout.fillWidth: true
            text: "Type to search apps, windows, settings\u2026"
            color: Colors.alpha(Colors.text, 0.4)
            font.pixelSize: Metrics.fontBody
            elide: Text.ElideRight
        }
        Item { Layout.fillWidth: PadState.searchQuery !== "" }
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
                : row.modelData.kind === "session" ? row.modelData.glyph
                : row.modelData.kind === "calc" ? "\u{F00EC}"
                : row.modelData.kind === "run" ? "\u{F018D}"
                : "\u{F0493}"
            glyphColor: Colors.alpha(Colors.text, 0.6)
            // Armed session rows become the confirmation prompt, in the
            // same destructive red as ListRow's action preview.
            readonly property bool armed: row.modelData.kind === "session"
                && root.armed === row.modelData.id
            label: row.armed ? "Press Enter again to " + row.modelData.verb : row.modelData.name
            labelColor: row.armed ? Colors.destructive : Colors.text
            status: row.modelData.kind === "calc" && root.canCopy ? "Enter to copy" : ""
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
