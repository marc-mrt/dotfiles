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
// No close button — the whole card is the target, and which gesture you
// use says what you meant: fling it off either edge to dismiss it and be
// done, or click it to be taken to whatever posted it (the exact Zen tab
// where the app offers a default action — see Notifications.activateGroup)
// with the card dismissed on the way out. Simpler than hunting for a
// specific icon, and no gesture leaves the card sitting there unread.
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
            // cardMa.pressed keeps a card you're mid-swipe from vanishing
            // underneath the cursor when its 6s auto-hide happens to land
            // during the drag — releasing then either dismisses it or
            // settles it back, and the timeout applies again from there.
            visible: PadState.shown || cardMa.pressed
                || root.now < card.modelData.expiresAt
            Layout.preferredWidth: Metrics.notifCardWidth
            implicitHeight: content.implicitHeight + 20
            radius: 14
            color: Colors.alpha(Colors.surface, 0.92)
            // Neutral, deliberately NOT accent anymore: an accent border
            // now means "this surface holds Hyprland's focus", which is
            // the pad's alone (see modules/Pad.qml and shell.qml's
            // HyprlandFocusGrab). Notifications never take focus — they're
            // in the grab for clicks only — so they never wear it, apart
            // from the blink below, where a *flash* of accent reads as
            // "new content" rather than "focused".
            readonly property color baseBorder: Colors.alpha(Colors.text, 0.14)
            border.width: 2
            border.color: card.baseBorder

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
                ColorAnimation { target: card; property: "border.color"; to: Colors.accent; duration: 250 }
                ColorAnimation { target: card; property: "border.color"; to: card.baseBorder; duration: 250 }
            }

            // Swipe-away, reusing the same Translate the slide-in
            // animation drives rather than touching x — the card is a
            // ColumnLayout child, so an animated/assigned x would just be
            // overwritten by the next layout pass (see slideOffset above).
            // Either direction dismisses: there's nothing behind a
            // notification to reveal, so left vs right carries no meaning
            // worth forcing the user to remember.
            function flingAway() {
                card.flingTo = slideOffset.x > 0
                    ? card.width + 80 : -(card.width + 80)
                fling.start()
            }
            property real flingTo: 0

            ParallelAnimation {
                id: fling
                NumberAnimation {
                    target: slideOffset; property: "x"; to: card.flingTo
                    duration: 160; easing.type: Easing.OutCubic
                }
                NumberAnimation { target: card; property: "opacity"; to: 0; duration: 160 }
                onFinished: Notifications.dismissGroup(card.modelData.messages)
            }

            ParallelAnimation {
                id: settle
                NumberAnimation {
                    target: slideOffset; property: "x"; to: 0
                    duration: 150; easing.type: Easing.OutCubic
                }
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 150 }
            }

            // Whole-card gesture surface — no visible siblings intercept
            // mouse events (plain Text/ColumnLayout, no MouseAreas of
            // their own), so z doesn't matter here.
            //
            // Drag is tracked by hand instead of via `drag.target`: that
            // needs an Item to move, and the only thing safe to move here
            // is the Translate, which isn't one. `dragging` latches past a
            // small threshold so a click with a shaky hand still counts as
            // a click, and — since onClicked fires after onReleased with
            // the flag still set — is also what keeps a completed swipe
            // from being treated as a click and jumping to the app.
            MouseArea {
                id: cardMa
                anchors.fill: parent
                property real pressX: 0
                property bool dragging: false

                onPressed: mouse => {
                    settle.stop()
                    cardMa.pressX = mouse.x
                    cardMa.dragging = false
                }
                onPositionChanged: mouse => {
                    const dx = mouse.x - cardMa.pressX
                    if (!cardMa.dragging && Math.abs(dx) > 8)
                        cardMa.dragging = true
                    if (!cardMa.dragging)
                        return
                    slideOffset.x = dx
                    // Fades toward, never to, invisible — the card has to
                    // stay grabbable all the way to the release point.
                    card.opacity = Math.max(0.2, 1 - Math.abs(dx) / card.width)
                }
                onReleased: {
                    if (!cardMa.dragging)
                        return
                    if (Math.abs(slideOffset.x) > card.width * 0.3)
                        card.flingAway()
                    else
                        settle.start()
                }
                onClicked: {
                    if (cardMa.dragging)
                        return
                    Notifications.activateGroup(card.modelData.messages)
                    // Jumping to another window means the pad is in the
                    // way; harmless no-op when it was never open.
                    PadState.close()
                }
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
