import QtQuick
import QtQuick.Layouts
import Quickshell
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

    // Keeps a keyboard-moved selection inside the clipped area. The loaded
    // item sits at y = 0 in the Flickable's content, so the selection
    // coordinates it publishes are already content coordinates. Panels that
    // don't publish any (network, bluetooth, ...) simply never trigger this.
    function revealSelection() {
        const item = expansionLoader.item
        if (!item || item.selectionY === undefined || !expansionFlick.interactive)
            return
        const top = item.selectionY
        const bottom = top + item.selectionHeight
        if (top < expansionFlick.contentY)
            expansionFlick.contentY = top
        else if (bottom > expansionFlick.contentY + expansionFlick.height)
            expansionFlick.contentY = bottom - expansionFlick.height
    }
    Connections {
        target: expansionLoader.item
        ignoreUnknownSignals: true
        function onSelectionYChanged() { root.revealSelection() }
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

    // Top row — settings + stats (top-left) and the status widgets
    // (top-right), pinned to opposite corners. Plain Item, not a Layout:
    // both groups use anchors, which is undefined behavior on a direct
    // Layout child (see the clock block below for the same reason).
    Item {
        id: topRow
        Layout.fillWidth: true
        implicitHeight: Math.max(statsRow.implicitHeight, widgetsRow.implicitHeight)

        // Bar color escalates with load (Colors.loadColor) so a hot metric
        // stands out at a glance, not just on close reading of the number.
        // One compact pill rather than three separate gauges — it opens the
        // same system tab either way, so there was never a reason to send
        // each metric somewhere different.
        RowLayout {
            id: statsRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            C.Settings {}
            W.MiniMetrics {
                cpu: SystemStats.cpuPercent
                ram: SystemStats.ramPercent
                vram: SystemStats.vramPercent
                onClicked: PanelState.toggleInline("system")
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
        id: clockRow
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: clockColumn.implicitWidth
        implicitHeight: clockColumn.implicitHeight

        // Hover pill behind the clock, sized to the text rather than the
        // full-width row, so the target reads as the clock itself.
        W.IconPill {
            anchors.centerIn: clockColumn
            width: clockColumn.width + 24
            height: clockColumn.height + 10
            radius: 12
            hovered: clockMa.containsMouse
        }

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

        // Expands the calendar in the same slot as the widget tabs rather
        // than taking over the card — clicking the clock is just another
        // way of picking a tab.
        MouseArea {
            id: clockMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: PanelState.toggleInline("calendar")
        }
    }

    // Inline-expanded tab — exclusive (services/PanelState.qml's
    // inlineOpen: a widget name, "search", or ""), so this is always at
    // most one Rectangle tall.
    //
    // This is the only row that grows without a natural bound (search can
    // match far more than fits, and so can a long network/bluetooth list),
    // so it's where the card's height ceiling is enforced: every other row
    // here is fixed-size chrome, and the footer below it has to stay on
    // screen — scrolling the card as a whole would take the footer with
    // it, which is exactly what we don't want. So the expansion takes what
    // is left of Metrics.padMaxHeightFraction once the card's own padding,
    // the other rows, and the gaps between all four are subtracted, and
    // scrolls its contents inside that.
    readonly property real expansionMaxHeight: Math.max(0,
        Quickshell.screens[0].height * Metrics.padMaxHeightFraction
            - Metrics.padPaddingTop - Metrics.padPadding
            - topRow.implicitHeight - clockRow.implicitHeight - footerRow.implicitHeight
            - root.spacing * 3)

    Rectangle {
        id: expansion
        readonly property bool open: PanelState.inlineOpen !== ""
        // What the contents want, before the ceiling is applied.
        readonly property real naturalHeight:
            expansionLoader.item ? expansionLoader.item.implicitHeight + 20 : 0

        Layout.fillWidth: true
        // Skip entirely (no leftover gap either side) when nothing is
        // expanded — Layouts exclude invisible items from sizing.
        visible: expansion.open
        implicitHeight: Math.min(expansion.naturalHeight, root.expansionMaxHeight)
        radius: 12
        color: Colors.alpha(Colors.base, 0.45)
        border.width: 1
        border.color: Colors.alpha(Colors.text, 0.06)

        Flickable {
            id: expansionFlick
            x: 10
            y: 10
            width: parent.width - 20
            height: parent.height - 20
            clip: true
            contentWidth: width
            contentHeight: expansionLoader.height
            boundsBehavior: Flickable.StopAtBounds
            // Nothing to drag when it all fits: leaving this interactive
            // would let a stray drag rubber-band content that isn't
            // clipped, for no reason.
            interactive: expansionFlick.contentHeight > expansionFlick.height

            Loader {
                id: expansionLoader
                width: expansionFlick.width
                // Explicit, not implicit: contentHeight above reads this,
                // and a Loader left to size itself reports 0 until its item
                // has settled.
                height: expansionLoader.item ? expansionLoader.item.implicitHeight : 0
                active: expansion.open
                sourceComponent: PanelState.inlineOpen === "network" ? networkComp
                    : PanelState.inlineOpen === "bluetooth" ? bluetoothComp
                    : PanelState.inlineOpen === "brightness" ? brightnessComp
                    : PanelState.inlineOpen === "volume" ? volumeComp
                    : PanelState.inlineOpen === "search" ? searchComp
                    : PanelState.inlineOpen === "calendar" ? calendarComp
                    : PanelState.inlineOpen === "system" ? systemComp
                    : PanelState.inlineOpen === "settings" ? settingsComp
                    : null
            }
        }

        // Scroll indicator — click-to-jump and drag-to-scroll, not just a
        // passive hint that content is cut off. The hit area (14px) is much
        // wider than the painted line (3px) so it doesn't take pixel-perfect
        // aim to grab, and pressing anywhere on the track jumps straight to
        // that position instead of requiring a drag from the handle's
        // current spot. Hand-rolled rather than QtQuick.Controls' ScrollBar
        // purely so it picks up Colors like everything else here.
        Item {
            id: scrollTrack
            visible: expansionFlick.interactive
            x: parent.width - 14
            y: 10
            width: 14
            height: parent.height - 20

            readonly property real handleHeight:
                Math.max(24, expansionFlick.visibleArea.heightRatio * height)
            readonly property real maxScroll:
                expansionFlick.contentHeight - expansionFlick.height
            readonly property real usableTrack: height - handleHeight

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: trackMa.containsMouse || trackMa.pressed ? 5 : 3
                radius: width / 2
                color: trackMa.pressed
                    ? Colors.alpha(Colors.text, 0.5)
                    : Colors.alpha(Colors.text, 0.25)
                y: scrollTrack.usableTrack > 0
                    ? expansionFlick.visibleArea.yPosition * expansionFlick.height : 0
                height: scrollTrack.handleHeight
                Behavior on width { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            MouseArea {
                id: trackMa
                anchors.fill: parent
                hoverEnabled: true
                function apply(my) {
                    if (scrollTrack.usableTrack <= 0)
                        return
                    const frac = Math.max(0, Math.min(1,
                        (my - scrollTrack.handleHeight / 2) / scrollTrack.usableTrack))
                    expansionFlick.contentY = frac * scrollTrack.maxScroll
                }
                onPressed: (m) => apply(m.y)
                onPositionChanged: (m) => { if (pressed) apply(m.y) }
            }
        }
    }

    // Bottom row — tray (left), workspace dots (center). Tray's corner is a
    // placement guess (nothing was specified for it) rather than a settled
    // call — say if you want it elsewhere. Plain Item for the same
    // anchors-vs-Layout reason as the rows above.
    Item {
        id: footerRow
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
    Component { id: calendarComp; Panels.Calendar {} }
    Component { id: systemComp; SystemMetrics {} }
    Component { id: settingsComp; Panels.Settings {} }
}
