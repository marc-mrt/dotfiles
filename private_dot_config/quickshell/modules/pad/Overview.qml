import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../config"
import "../../services"
import "./chips" as C
import "./tabs" as Tabs
import "../ui" as W

// Meta-info at a glance, top to bottom: workspace dots, clock, state chips,
// context row (tray, stats, settings, power), then the tab slot. Every chip
// the old bar showed permanently is one tap/click away from expanding inline
// right here, rather than navigating away to a full-card panel like the old bar/drawer did. Search is one more
// exclusive tab in the same slot (services/PanelState.qml's inlineOpen) —
// typing (captured by Pad.qml's hidden TextInput) selects it the same way
// clicking a widget would, and Pad.qml grows the card width for it so
// results get more room than a collapsed widget tab needs.
ColumnLayout {
    id: root
    width: parent ? parent.width : implicitWidth
    spacing: 14

    // Forwarded from Pad.qml's hidden key-catcher (Up/Down/Left/Right/
    // Enter). Search runs its own selection and gets the calls passed
    // straight through; every other tab shares the generic cursor below.
    function moveSelection(delta) {
        const own = expansionLoader.item
        if (!own)
            return
        if (own.moveSelection) {
            own.moveSelection(delta)
            return
        }
        const items = root.navItems()
        if (items.length === 0)
            return
        const idx = items.indexOf(root.navItem)
        root.navSelect(items[idx === -1 ? (delta > 0 ? 0 : items.length - 1)
            : (idx + delta + items.length) % items.length])
    }

    // ── keyboard cursor for tabs ────────────────────────────────────────
    // No tab declares what is navigable. The open tab's visible tree is
    // walked in order and anything that looks operable is a stop: a row
    // (`selected` + `clicked`: W.ListRow) or something steppable
    // (`nudge()`: W.SliderTrack, W.PageBar). Re-walked on every keypress,
    // so lists that rebuild under the cursor (a wi-fi rescan) just restart
    // from the top instead of holding a dead delegate.
    property var navItem: null
    Connections {
        target: PanelState
        function onInlineOpenChanged() { root.navItem = null }
    }

    function navItems() {
        const out = []
        const walk = (it) => {
            if (!it.visible)
                return
            if (typeof it.nudge === "function"
                    || (it.selected !== undefined && typeof it.clicked === "function"))
                out.push(it)
            for (const child of it.children)
                walk(child)
        }
        if (expansionLoader.item)
            walk(expansionLoader.item)
        return out
    }

    function navSelect(item) {
        try {
            if (root.navItem)
                root.navItem.selected = false
        } catch (e) {
            // delegate already destroyed — nothing to unhighlight
        }
        root.navItem = item
        item.selected = true
        if (!expansionFlick.interactive)
            return
        const top = item.mapToItem(expansionLoader.item, 0, 0).y
        if (top < expansionFlick.contentY)
            expansionFlick.contentY = top
        else if (top + item.height > expansionFlick.contentY + expansionFlick.height)
            expansionFlick.contentY = top + item.height - expansionFlick.height
    }

    // Left/Right. With nothing selected yet it grabs the tab's first
    // steppable control, so "vol, Enter, Left Left" works without an Up/Down
    // first. False = not ours, let the key through.
    function nudge(delta) {
        const own = expansionLoader.item
        if (!own || own.moveSelection)
            return false
        let target = root.navItem
        if (!target) {
            target = root.navItems().find(i => typeof i.nudge === "function")
            if (target)
                root.navSelect(target)
        }
        if (!target || typeof target.nudge !== "function")
            return false
        target.nudge(delta)
        return true
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
        const own = expansionLoader.item
        if (own && own.activateSelected)
            own.activateSelected()
        else if (root.navItem && typeof root.navItem.clicked === "function")
            root.navItem.clicked()
    }

    property var now: new Date()
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Workspace dots, a direct child rather than inside clockRow: clockRow's
    // MouseArea (anchors.fill) would swallow their clicks. Fixed strip of 4
    // dots (the ones actually used), growing to cover any higher workspace
    // that exists (SUPER+5..0 still bind up to 10 in hypr/lua/key_bindings.lua).
    // No app icons, just which one is currently active.
    W.WorkspaceDots {
        id: dotsRow
        Layout.alignment: Qt.AlignHCenter
        onPicked: PadState.close()
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
            radius: Metrics.radiusSection
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
                font.pixelSize: Metrics.fontDisplay
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "dddd, MMMM d")
                color: Colors.alpha(Colors.text, 0.6)
                font.pixelSize: Metrics.fontBody
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

    // Inline-expanded tab, last so opening one grows the card downward and
    // nothing above it moves — exclusive (services/PanelState.qml's
    // inlineOpen: a widget name, "search", or ""), so this is always at
    // most one Rectangle tall.
    //
    // This is the only row that grows without a natural bound (search can
    // match far more than fits, and so can a long network/bluetooth list),
    // so it's where the card's height ceiling is enforced: every other row
    // here is fixed-size chrome, and the rows above it have to stay on
    // screen — scrolling the card as a whole would take them with it, which
    // is exactly what we don't want. So the expansion takes what is left of
    // Metrics.padMaxHeightFraction once the card's own padding, the other
    // rows, and the gaps between all five are subtracted, and scrolls its
    // contents inside that.
    readonly property real expansionMaxHeight: Math.max(0,
        Quickshell.screens[0].height * Metrics.padMaxHeightFraction
            - Metrics.padPaddingTop - Metrics.padPadding
            - clockRow.implicitHeight - dotsRow.implicitHeight
            - stateRow.implicitHeight - contextRow.implicitHeight
            - root.spacing * 5)

    // State row — every live-state chip in one centered strip: the five
    // that open a tab, then the two toggles (caffeine, DND) which select
    // nothing and hide themselves when inactive, so they sit last and never
    // shift the others. spacing: 0 — every chip already carries its own
    // inner padding (see modules/ui/StatusChip.qml).
    RowLayout {
        id: stateRow
        Layout.alignment: Qt.AlignHCenter
        spacing: 0
        C.Recording {}
        C.Media {}
        C.Network {}
        C.Bluetooth {}
        C.Brightness {}
        C.Volume {}
        C.Caffeine {}
        C.Notifications {}
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colors.alpha(Colors.text, 0.08)
    }

    // Context row — where you are and what the machine is doing: tray
    // (left), stats, settings and power (right, power last).
    // Plain Item, not a Layout: both groups use anchors, which is undefined
    // behavior on a direct Layout child (see the clock block above).
    Item {
        id: contextRow
        Layout.fillWidth: true
        implicitHeight: Math.max(leftGroup.implicitHeight, rightGroup.implicitHeight)

        RowLayout {
            id: leftGroup
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            C.Tray {}
        }

        // Bar color escalates with load (Colors.loadColor) so a hot metric
        // stands out at a glance. One compact pill rather than three
        // gauges — it opens the same system tab either way.
        RowLayout {
            id: rightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            W.MiniMetrics {
                cpu: SystemStats.cpuPercent
                ram: SystemStats.ramPercent
                vram: SystemStats.vramPercent
                onClicked: PanelState.toggleInline("system")
            }
            // No live state to render: a static gear and a tab name.
            W.StatusChip {
                text: "\u{F013}"
                active: PanelState.isInlineOpen("settings")
                onClicked: PanelState.toggleInline("settings")
            }
            W.StatusChip {
                text: "\u{F0425}"
                active: PanelState.isInlineOpen("power")
                onClicked: PanelState.toggleInline("power")
            }
        }
    }

    // W.Card's sunken variant rather than W.Section: visually this is a
    // section and used to be a hand-copied duplicate of one, but it holds a
    // Flickable with an overlaid scroll track, not the plain column of
    // controls Section wraps its children in. Same surface, own contents.
    W.Card {
        id: expansion
        sunken: true
        readonly property bool open: PanelState.inlineOpen !== ""
        // What the contents want, before the ceiling is applied.
        readonly property real naturalHeight:
            expansionLoader.item ? expansionLoader.item.implicitHeight + 20 : 0

        Layout.fillWidth: true
        // Skip entirely (no leftover gap either side) when nothing is
        // expanded — Layouts exclude invisible items from sizing.
        visible: expansion.open
        implicitHeight: Math.min(expansion.naturalHeight, root.expansionMaxHeight)

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
                    : PanelState.inlineOpen === "media" ? mediaComp
                    : PanelState.inlineOpen === "search" ? searchComp
                    : PanelState.inlineOpen === "calendar" ? calendarComp
                    : PanelState.inlineOpen === "system" ? systemComp
                    : PanelState.inlineOpen === "settings" ? settingsComp
                    : PanelState.inlineOpen === "power" ? powerComp
                    : PanelState.inlineOpen === "clipboard" ? clipboardComp
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
                Behavior on width { NumberAnimation { duration: Metrics.durationFast } }
                Behavior on color { ColorAnimation { duration: Metrics.durationFast } }
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

    Component { id: networkComp; Tabs.Network {} }
    Component { id: bluetoothComp; Tabs.Bluetooth {} }
    Component { id: brightnessComp; Tabs.Brightness {} }
    Component { id: volumeComp; Tabs.Volume {} }
    Component { id: mediaComp; Tabs.Media {} }
    Component { id: searchComp; Search {} }
    Component { id: calendarComp; Tabs.Calendar {} }
    Component { id: systemComp; SystemMetrics {} }
    Component { id: settingsComp; Tabs.Settings {} }
    Component { id: powerComp; Tabs.Power {} }
    Component { id: clipboardComp; Tabs.Clipboard {} }
}
