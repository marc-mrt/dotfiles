import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../config"
import "../services"

// Window/positioning (bottom-right, Overlay layer) lives in shell.qml.
// Independent of pad visibility, mirroring the existing Osd.qml split.
//
// Grouped by consecutive arrival, not by app overall — same visual card
// style a lone toast used to have, but one card per run of same-app
// notifications: icon + app name in the header, then each message as
// "<b>summary</b>: body" (a leading "-" only when the group holds more
// than one message). A second Zen Browser burst after a Ghostty
// notification gets its own card rather than merging back into the first
// — matches the order things actually arrived in.
//
// No close button — the whole card is one big click target that dismisses
// its group, simpler than hunting for a specific icon.
//
// While the pad is closed, a card auto-hides itself from view 6s after its
// newest message (services/Notifications.qml's `groups[].expiresAt`) —
// but stays in history, so opening the pad reveals it again alongside
// everything else, in order, with no timeout at all while it's open. Only
// clicking a card actually removes it from history.
ColumnLayout {
    id: root
    spacing: 8

    // Ticks so each card's time-based `visible` binding below actually
    // re-evaluates as wall-clock time passes, not just when history
    // changes. Deliberately NOT part of displayGroups below — folding it
    // in there meant the whole array (and every group object in it) got
    // rebuilt from scratch every single tick, which tore down and
    // recreated every card delegate — MouseArea included — once a second
    // regardless of whether anything had actually changed. A real click
    // landing during that churn could easily get lost. Each card now
    // reads `root.now` directly in its own `visible` binding instead, so
    // only that one property toggles per tick — the delegate itself (and
    // its MouseArea) stays put.
    property real now: Date.now()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // Newest-first from the service; reversed here so the newest group is
    // the last (bottom-most) child — pinned at the corner shell.qml anchors
    // this stack to, with older groups pushed upward above it. Stable
    // aside from actual notification changes — no time dependency here.
    property var displayGroups: [...Notifications.groups].reverse().map(
        g => Object.assign({}, g, root.animMeta[g.id]))

    // Tracks what's already been seen (by group id -> message count) so a
    // brand-new group can slide in while a burst added to an existing one
    // just blinks its border — only while the pad is closed; arrivals
    // while it's open (see `groups[].expiresAt` never applying then) don't
    // need either, they're just part of the list you're already looking
    // at. Keyed by id, not groupKey — a group's id stays fixed as it
    // grows (see services/Notifications.qml), so growth is detected
    // correctly; groupKey would falsely look "new" every time two
    // unrelated groups from the same app happen to share it. nonce
    // dedupes so a delegate that gets recreated for an unrelated reason
    // doesn't replay an animation it already played.
    property var seenCounts: ({})
    property var animMeta: ({})
    property int nonceCounter: 0

    Connections {
        target: Notifications
        function onGroupsChanged() {
            const counts = {}
            const meta = {}
            for (const g of Notifications.groups) {
                const prevCount = root.seenCounts[g.id]
                if (!PadState.shown) {
                    if (prevCount === undefined) {
                        root.nonceCounter++
                        meta[g.id] = { kind: "slide", nonce: root.nonceCounter }
                    } else if (g.messages.length > prevCount) {
                        root.nonceCounter++
                        meta[g.id] = { kind: "blink", nonce: root.nonceCounter }
                    }
                }
                counts[g.id] = g.messages.length
            }
            root.animMeta = meta
            root.seenCounts = counts
        }
    }

    // summary is plain text per the notification spec — escape it before
    // wrapping in <b> below. body may legitimately already contain markup
    // (bodyMarkupSupported: true in services/Notifications.qml), so it's
    // used as-is.
    function escapeHtml(s) {
        return (s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    Repeater {
        model: root.displayGroups
        delegate: Rectangle {
            id: card
            required property var modelData
            // Layouts exclude invisible items from sizing, so this both
            // hides the card and closes the gap it would otherwise leave.
            visible: PadState.shown || root.now < card.modelData.expiresAt
            Layout.preferredWidth: Metrics.notifCardWidth
            implicitHeight: content.implicitHeight + 20
            radius: 14
            color: Colors.alpha(Colors.surface, 0.92)
            border.width: 2
            border.color: Colors.accent

            // Purely visual offset layered on top of the ColumnLayout's own
            // positioning — animating x/y directly would fight the Layout
            // (same pitfall noted elsewhere in this codebase), a transform
            // doesn't.
            transform: Translate { id: slideOffset }

            property int playedNonce: -1
            function playPendingAnim() {
                const anim = card.modelData
                if (!anim.kind || anim.nonce === card.playedNonce)
                    return
                card.playedNonce = anim.nonce
                if (anim.kind === "slide")
                    slideIn.start()
                else if (anim.kind === "blink")
                    blink.start()
            }
            Component.onCompleted: card.playPendingAnim()
            onModelDataChanged: card.playPendingAnim()

            NumberAnimation {
                id: slideIn
                target: slideOffset
                property: "x"
                from: 340
                to: 0
                duration: 200
                easing.type: Easing.OutCubic
            }

            // Three flashes at a ~0.5s cadence to say "new content" on a
            // card that's already visible, without needing to re-read it.
            SequentialAnimation {
                id: blink
                loops: 3
                ColorAnimation { target: card; property: "border.color"; to: Colors.text; duration: 250 }
                ColorAnimation { target: card; property: "border.color"; to: Colors.accent; duration: 250 }
            }

            // Whole-card dismiss — no visible siblings intercept mouse
            // events (plain Text/ColumnLayout, no MouseAreas of their
            // own), so z doesn't matter here.
            MouseArea {
                anchors.fill: parent
                onClicked: Notifications.dismissGroup(card.modelData.messages)
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    IconImage {
                        visible: !!card.modelData.appIcon
                        implicitSize: 18
                        source: card.modelData.appIcon ?? ""
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.appName
                        color: Colors.text
                        font.pixelSize: 19
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }

                Repeater {
                    model: card.modelData.messages
                    delegate: RowLayout {
                        id: msgRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            visible: card.modelData.messages.length > 1
                            Layout.alignment: Qt.AlignTop
                            text: "–"
                            color: Colors.alpha(Colors.text, 0.5)
                            font.pixelSize: 16
                        }
                        // Wraps instead of eliding — the card grows taller
                        // rather than cutting content off.
                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            textFormat: Text.RichText
                            wrapMode: Text.Wrap
                            text: "<b>" + root.escapeHtml(msgRow.modelData.summary || card.modelData.appName) + "</b>"
                                + (msgRow.modelData.body ? ": " + msgRow.modelData.body : "")
                            color: Colors.alpha(Colors.text, 0.85)
                            font.pixelSize: 16
                        }
                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: msgRow.modelData.time
                            color: Colors.alpha(Colors.text, 0.5)
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
