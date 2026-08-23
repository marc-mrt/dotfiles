import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../config"
import "../../services"
import "../bar/components" as C
import "../bar/panels" as Panels
import "../bar/widgets" as W

// Meta-info at a glance — every chip the old bar showed permanently, now one
// tap/click away from expanding inline right here, rather than navigating
// away to a full-card panel like the old bar/drawer did. Search is one more
// exclusive tab in the same slot (services/PanelState.qml's inlineOpen) —
// typing (captured by Pad.qml's hidden TextInput) selects it the same way
// clicking a widget would, and Pad.qml grows the card width for it so
// results get more room than a collapsed widget tab needs.
ColumnLayout {
    id: root
    width: parent ? parent.width : implicitWidth
    spacing: 14

    // Forwarded from Pad.qml's hidden key-catcher (Up/Down/Enter) — only
    // meaningful while the search tab is the one showing.
    function moveSelection(delta) {
        if (expansionLoader.item && expansionLoader.item.moveSelection)
            expansionLoader.item.moveSelection(delta)
    }
    function activateSelected() {
        if (expansionLoader.item && expansionLoader.item.activateSelected)
            expansionLoader.item.activateSelected()
    }

    property var now: new Date()
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Top row — purely informative stats (top-left) and the interactive
    // widgets (top-right), pinned to opposite corners. Plain Item, not a
    // Layout: both groups use anchors, which is undefined behavior on a
    // direct Layout child (see the clock block below for the same reason).
    Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(statsRow.implicitHeight, widgetsRow.implicitHeight)

        // Display only — no click handlers, no hover states, on purpose.
        // Ring color escalates with load so a hot metric stands out at a
        // glance, not just on close reading of the number.
        RowLayout {
            id: statsRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            function colorFor(percent) {
                return percent >= 85 ? "#f7768e" // red — under real pressure
                    : percent >= 60 ? "#e0af68" // amber — worth a glance
                    : Colors.accent
            }

            W.RingMeter {
                icon: "\u{F2DB}"
                value: SystemStats.cpuPercent
                ringColor: statsRow.colorFor(SystemStats.cpuPercent)
            }
            W.RingMeter {
                icon: "\u{EFC5}" // fa-memory
                value: SystemStats.ramPercent
                ringColor: statsRow.colorFor(SystemStats.ramPercent)
            }
            W.RingMeter {
                icon: "\u{EF61}" // fa-sd-card — closest fit, Font Awesome has no dedicated gpu icon
                value: SystemStats.vramPercent
                ringColor: statsRow.colorFor(SystemStats.vramPercent)
            }
        }

        // spacing: 0 — each widget already carries its own inner padding
        // (see e.g. bar/components/Network.qml's implicitWidth), so no
        // extra gap is needed between them.
        RowLayout {
            id: widgetsRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            C.Network {}
            C.Bluetooth {}
            C.Brightness {}
            C.Volume {}
            C.Notifications {}
        }
    }

    // Clock — the one thing worth showing big, since it's the reason you
    // opened the pad half the time. Bespoke rather than reusing bar
    // components' Clock (that one's a small bar-chip pill, not this).
    // Plain Item, not a Layout — the MouseArea below needs anchors.fill,
    // which is undefined behavior on a direct Layout child.
    Item {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: clockColumn.implicitWidth
        implicitHeight: clockColumn.implicitHeight

        Column {
            id: clockColumn
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "hh:mm")
                color: Colors.text
                font.pixelSize: 44
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "dddd, MMMM d")
                color: Colors.alpha(Colors.text, 0.6)
                font.pixelSize: 14
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: PanelState.toggle("calendar", 0)
        }
    }

    // Inline-expanded tab — exclusive (services/PanelState.qml's
    // inlineOpen: a widget name, "search", or ""), so this is always at
    // most one Rectangle tall.
    Rectangle {
        id: expansion
        readonly property bool open: PanelState.inlineOpen !== ""

        Layout.fillWidth: true
        // Skip entirely (no leftover gap either side) when nothing is
        // expanded — Layouts exclude invisible items from sizing.
        visible: expansion.open
        implicitHeight: expansionLoader.item ? expansionLoader.item.implicitHeight + 20 : 0
        radius: 12
        color: Colors.alpha(Colors.base, 0.45)
        border.width: 1
        border.color: Colors.alpha(Colors.text, 0.06)

        Loader {
            id: expansionLoader
            x: 10
            y: 10
            width: parent.width - 20
            active: expansion.open
            sourceComponent: PanelState.inlineOpen === "network" ? networkComp
                : PanelState.inlineOpen === "bluetooth" ? bluetoothComp
                : PanelState.inlineOpen === "brightness" ? brightnessComp
                : PanelState.inlineOpen === "volume" ? volumeComp
                : PanelState.inlineOpen === "search" ? searchComp
                : null
        }
    }

    // Bottom row — tray (left), workspace dots (center). Tray's corner is a
    // placement guess (nothing was specified for it) rather than a settled
    // call — say if you want it elsewhere. Plain Item for the same
    // anchors-vs-Layout reason as the rows above.
    Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(trayRow.implicitHeight, dotsRow.implicitHeight)

        RowLayout {
            id: trayRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            C.Tray {}
        }

        // One dot per configured workspace (SUPER+1..0 in
        // hypr/lua/key_bindings.lua binds exactly 10), not per workspace
        // that happens to have windows open — a fixed strip like the old
        // bar's, just dots instead of numbered pills. No app icons, just
        // which one is currently active.
        RowLayout {
            id: dotsRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: 10
                Rectangle {
                    id: dot
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool active: Hyprland.workspaces.values
                        .some(w => w.id === dot.wsId && w.active)

                    implicitWidth: active ? 10 : 6
                    implicitHeight: active ? 10 : 6
                    radius: width / 2
                    color: active ? Colors.accent : Colors.alpha(Colors.text, 0.3)
                    Behavior on implicitWidth { NumberAnimation { duration: 100 } }
                    Behavior on implicitHeight { NumberAnimation { duration: 100 } }
                }
            }
        }
    }

    Component { id: networkComp; Panels.Network {} }
    Component { id: bluetoothComp; Panels.Bluetooth {} }
    Component { id: brightnessComp; Panels.Brightness {} }
    Component { id: volumeComp; Panels.Volume {} }
    Component { id: searchComp; Search {} }
}
