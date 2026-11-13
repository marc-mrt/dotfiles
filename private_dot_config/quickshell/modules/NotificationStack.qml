import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../config"
import "../services"
import "./ui" as W

// Window/positioning (bottom-right, Overlay layer) lives in shell.qml.
// Independent of pad visibility, mirroring the existing Osd.qml split.
//
// Grouped by consecutive arrival, not by app overall — same visual card
// style a lone toast used to have, but one card per run of same-app
// notifications: icon + app name (+ count) + newest time in the header,
// then each message as a bold summary line over its body, oldest first,
// split by hairlines. A second Zen Browser burst after a Ghostty
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
        // `now` only matters while some group can still expire: both
        // consumers (card visibility, waiting pill) are time-independent
        // once every expiresAt is past, and critical / pad-shown don't read
        // it. Reading `root.now` here re-evaluates each tick, so the timer
        // stops itself after the last expiry and restarts when a group
        // arrives or the pad closes; triggeredOnStart refreshes a stale `now`.
        running: !PadState.shown && Notifications.groups.some(g => root.now < g.expiresAt)
        repeat: true
        triggeredOnStart: true
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

    Repeater {
        model: root.displayGroups
        delegate: W.Card {
            id: card
            required property var modelData
            // Layouts exclude invisible items from sizing, so this both
            // hides the card and closes the gap it would otherwise leave.
            // cardMa.pressed keeps a card you're mid-swipe from vanishing
            // underneath the cursor when its 6s auto-hide happens to land
            // during the drag — releasing then either dismisses it or
            // settles it back, and the timeout applies again from there.
            // Critical cards skip both the timeout and DND; DND otherwise
            // keeps new arrivals out of the corner until the pad opens.
            visible: PadState.shown || cardMa.pressed || card.modelData.critical
                || (!Notifications.dnd && root.now < card.modelData.expiresAt)
            Layout.preferredWidth: Metrics.notifCardWidth
            implicitHeight: content.implicitHeight + 28
            // Neutral by default, deliberately NOT accent: an accent border
            // means "this surface holds Hyprland's focus", which is the
            // pad's alone (see modules/Pad.qml). Notifications never take
            // focus — their layer is unfocusable — so they only ever borrow it for
            // the two cases below, where it reads as "look here" rather
            // than "focused".
            //
            // Both go through W.Card's `accented`, never through
            // border.color directly. The blink used to be a ColorAnimation
            // driving border.color, which silently destroyed the binding
            // that keyboard selection depends on: after a card's first
            // blink, selecting it with Tab could never tint it again.
            // Driving a bool that `accented` reads leaves the binding
            // intact, so the two cues genuinely can't collide.
            readonly property bool selected: card.modelData.id === Notifications.selectedGroupId
            property bool blinking: false
            accented: card.selected || card.blinking

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
                duration: Metrics.durationNormal
                easing.type: Easing.OutCubic
            }

            // Three flashes at a ~0.5s cadence to say "new content" on a
            // card that's already visible, without needing to re-read it.
            SequentialAnimation {
                id: blink
                loops: 3
                PropertyAction { target: card; property: "blinking"; value: true }
                PauseAnimation { duration: Metrics.durationValue }
                PropertyAction { target: card; property: "blinking"; value: false }
                PauseAnimation { duration: Metrics.durationValue }
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
                    duration: Metrics.durationNormal; easing.type: Easing.OutCubic
                }
                NumberAnimation { target: card; property: "opacity"; to: 0; duration: Metrics.durationNormal }
                onFinished: Notifications.dismissGroup(card.modelData.messages)
            }

            ParallelAnimation {
                id: settle
                NumberAnimation {
                    target: slideOffset; property: "x"; to: 0
                    duration: Metrics.durationNormal; easing.type: Easing.OutCubic
                }
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: Metrics.durationNormal }
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
                    // Not `cardMa.dragging` — that latches permanently on
                    // the first 8px crossing and never resets, so ordinary
                    // mouse tremor during a plain click (easy to hit across
                    // a press-hold-release) got misclassified as an
                    // abandoned swipe: the card visibly nudged/faded for
                    // the duration of the press, then the click was
                    // swallowed on release. Judge intent by where the card
                    // actually ended up instead — if it drifted back near
                    // home before release, it was always just a click.
                    if (Math.abs(slideOffset.x) > 8)
                        return
                    Notifications.activateGroup(card.modelData.messages)
                    // Jumping to another window means the pad is in the
                    // way; harmless no-op when it was never open.
                    PadState.close()
                }
            }

            // Critical marker, not accent (accent means focus). Clipped to the
            // card's rounded inner edge so the bar can't poke past the corners.
            ClippingRectangle {
                visible: card.modelData.critical
                anchors.fill: parent
                anchors.margins: 1
                radius: Metrics.radiusCard - 1
                color: "transparent"
                Rectangle {
                    width: 3
                    height: parent.height
                    color: Colors.destructive
                }
            }

            // Messages oldest-first for display (the service keeps newest at
            // [0]; activate/dismiss still get the original array). In the
            // corner only the newest 2 show, with a "+N more" line on top.
            readonly property var shownMessages: {
                const r = [...card.modelData.messages].reverse()
                return !PadState.shown && r.length > 2 ? r.slice(-2) : r
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconImage {
                        visible: !!card.modelData.appIcon
                        implicitSize: 20
                        source: card.modelData.appIcon ?? ""
                    }
                    Rectangle {
                        visible: !card.modelData.appIcon
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: 10
                        color: Colors.alpha(Colors.text, 0.15)
                        Text {
                            anchors.centerIn: parent
                            text: (card.modelData.appName || "?").charAt(0).toUpperCase()
                            color: Colors.text
                            font.pixelSize: Metrics.fontSmall
                            font.bold: true
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.appName
                            + (card.modelData.messages.length > 1 ? " · " + card.modelData.messages.length : "")
                        color: Colors.alpha(Colors.text, 0.6)
                        font.pixelSize: Metrics.fontSmall
                        elide: Text.ElideRight
                    }
                    Text {
                        text: card.modelData.messages[0].time
                        color: Colors.alpha(Colors.text, 0.5)
                        font.pixelSize: Metrics.fontSmall
                    }
                }

                Text {
                    visible: card.shownMessages.length < card.modelData.messages.length
                    text: "+" + (card.modelData.messages.length - card.shownMessages.length) + " more"
                    color: Colors.alpha(Colors.text, 0.5)
                    font.pixelSize: Metrics.fontSmall
                }

                Repeater {
                    model: card.shownMessages
                    delegate: ColumnLayout {
                        id: msgRow
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            visible: msgRow.index > 0
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Colors.alpha(Colors.text, 0.08)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Fixed thumbnail, not a full-width preview — keeps
                            // a screenshot notification from towering over its
                            // text. Hidden until the pixels actually load (the
                            // image URL can outlive its source), so a dead
                            // image leaves no empty frame. Only content images
                            // get here (Notifications.contentImageOf); the
                            // header's app icon is the one identity icon.
                            ClippingRectangle {
                                id: thumbBox
                                readonly property var contentImage: Notifications.contentImageOf(msgRow.modelData)
                                visible: !!contentImage && thumb.status === Image.Ready
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: 56
                                implicitHeight: 56
                                radius: Metrics.radiusControl
                                color: "transparent"

                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    source: thumbBox.contentImage || ""
                                    // 2x the 56px box for HiDPI; avoids decoding full screenshots.
                                    sourceSize: Qt.size(112, 112)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            // Wraps instead of eliding — the card grows taller
                            // rather than cutting content off, except the
                            // body in the corner (3 lines).
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 2

                                Text {
                                    visible: !!msgRow.modelData.summary
                                    Layout.fillWidth: true
                                    text: msgRow.modelData.summary
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    color: Colors.text
                                    font.pixelSize: Metrics.fontLarge
                                    font.bold: true
                                }
                                // StyledText (b, i, u, a) so maximumLineCount works.
                                Text {
                                    visible: !!msgRow.modelData.body
                                    Layout.fillWidth: true
                                    text: msgRow.modelData.body
                                    textFormat: Text.StyledText
                                    wrapMode: Text.Wrap
                                    maximumLineCount: PadState.shown ? 99999 : 3
                                    elide: Text.ElideRight
                                    color: Colors.alpha(Colors.text, 0.7)
                                    font.pixelSize: Metrics.fontSecondary
                                }
                            }
                        }

                        // Only for a live notification — see
                        // Notifications.actionsOf.
                        Repeater {
                            model: Notifications.actionsOf(msgRow.modelData)
                            delegate: W.MenuEntry {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }

    // What arrived since the pad was last open and is no longer (or, under
    // DND, never was) on screen. With no bar this pill is the only trace of
    // it; clicking opens the pad, which shows the whole history.
    readonly property int waiting: {
        if (PadState.shown)
            return 0
        let n = 0
        for (const g of Notifications.groups) {
            if (g.critical || (!Notifications.dnd && root.now < g.expiresAt))
                continue
            for (const m of g.messages)
                if (m.receivedAtMs > Notifications.seenAtMs)
                    n++
        }
        return n
    }

    W.Card {
        visible: root.waiting > 0
        Layout.alignment: Qt.AlignRight
        implicitWidth: hintRow.implicitWidth + 20
        implicitHeight: hintRow.implicitHeight + 10
        opacity: hintMa.containsMouse ? 1 : 0.6
        Behavior on opacity { NumberAnimation { duration: Metrics.durationFast } }

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: Notifications.dnd ? "\u{F009B}" : "\u{F009A}"
                color: Colors.text
                font.pixelSize: Metrics.fontSmall
            }
            Text {
                text: root.waiting
                color: Colors.text
                font.pixelSize: Metrics.fontSmall
            }
        }

        MouseArea {
            id: hintMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: PadState.toggle()
        }
    }
}
