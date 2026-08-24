import QtQuick
import QtQuick.Window
import Quickshell
import "../config"
import "../services"
import "./pad" as PadViews

// Pad content — a single fixed-position card floating ~30% from the top,
// horizontally centered (window/positioning chrome lives in shell.qml).
// Replaces Bar.qml + Drawer.qml: one surface, always showing the meta-info
// overview, with everything else — network, bluetooth, brightness, volume,
// search and the calendar — as exclusive tabs embedded right there (see
// modules/pad/Overview.qml). Nothing takes over the whole card the way the
// old drawer did anymore, so there's exactly one view to reason about.
// Notifications live entirely outside the pad (see
// modules/NotificationStack.qml).
Item {
    id: root

    // Search is the only tab that needs more room than a collapsed widget.
    readonly property real cardWidth: PanelState.inlineOpen === "search"
        ? Metrics.padSearchWidth : Metrics.padWidth

    // Close as soon as the compositor gives focus to anything else. This
    // only became necessary once the pad turned into a real toplevel
    // (shell.qml): it's pinned and screen-sized, so a window spawning or
    // being picked behind it would end up focused but completely covered,
    // with the pad still swallowing every click. A layer surface never had
    // this problem because it was never in the running for focus.
    //
    // everActive guards the gap between mapping and Hyprland actually
    // focusing us — without it the pad would see its own not-yet-focused
    // state on open and immediately close itself again.
    property bool everActive: false

    readonly property bool windowActive: root.Window.active
    onWindowActiveChanged: {
        if (root.windowActive)
            root.everActive = true
        else if (root.everActive)
            PadState.close()
    }

    // Reset to a clean overview every time the pad closes, so it never
    // reopens mid-search or mid-panel (SUPER+SPACE/SUPER+Tab always land
    // exactly where PadState.toggle() asked).
    Connections {
        target: PadState
        function onShownChanged() {
            if (!PadState.shown) {
                // Turned off *before* PanelState.close() below, so the
                // resulting inlineOpen/layout change writes straight to
                // width/height with no animation in the way — no race to
                // lose. A hidden window's animation clock never ticks (Qt
                // suspends it while unexposed), so a Behavior left enabled
                // here starts a collapse animation that never advances until
                // the pad is shown again, which is what made it look like it
                // "folds" open: reopening resumes that stalled animation
                // from wherever it was frozen instead of showing the settled
                // size.
                widthBehavior.enabled = false
                heightBehavior.enabled = false
                root.everActive = false
                PanelState.close()
                keyCatcher.text = ""
            } else {
                // Back on now that the card is settled and about to show
                // again, so in-session changes (expanding a tab, growing for
                // search) still animate normally.
                widthBehavior.enabled = true
                heightBehavior.enabled = true
                if (PadState.searchBias === "windows") {
                    // SUPER+Tab: land straight on the search tab, pre-biased
                    // to open windows (see Search.qml's windows-first
                    // ordering).
                    PanelState.inlineOpen = "search"
                }
            }
        }
    }

    // inlineOpen is the single source of truth for which overview tab is
    // selected, including "search" — whenever it moves away from "search"
    // (a widget tab was clicked, or everything closed), drop the leftover
    // query too so resuming typing later starts fresh instead of resuming
    // whatever was typed before you navigated away.
    Connections {
        target: PanelState
        function onInlineOpenChanged() {
            if (PanelState.inlineOpen !== "search" && PadState.searchQuery !== "") {
                PadState.searchQuery = ""
                keyCatcher.text = ""
            }
        }
    }

    // Click outside the card: fully close the pad.
    MouseArea {
        anchors.fill: parent
        onClicked: PadState.close()
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: parent.height * Metrics.padTopFraction
        // padWin is the full screen now, so plain centering against the
        // parent is true screen-centering (it used to be narrower than the
        // screen, which is why this went through Quickshell.screens[0]).
        x: (parent.width - width) / 2
        width: root.cardWidth
        height: inner.implicitHeight + Metrics.padPaddingTop + Metrics.padPadding
        radius: Metrics.padRadius
        color: Colors.alpha(Colors.surface, 0.9)
        // Accent border = "this surface has the compositor's focus", which
        // the pad genuinely does now (shell.qml holds a HyprlandFocusGrab
        // for as long as it's open). It's the only surface that wears it —
        // modules/NotificationStack.qml's cards used to match this for
        // looks alone and have gone neutral so the cue stays meaningful.
        border.width: 2
        border.color: Colors.accent

        // id'd so onShownChanged above can turn these off before closing —
        // see the comment there for why. Starts disabled to match
        // PadState.shown's initial false; onShownChanged takes over toggling
        // it imperatively from the first shown change onward.
        Behavior on width { id: widthBehavior; enabled: false; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on height { id: heightBehavior; enabled: false; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // Click on empty card space: step back from a drill-down panel to
        // the overview it was opened from (same gesture the old bar used to
        // close whichever panel was open) — also collapses any open
        // overview tab, since PanelState.close() clears inlineOpen too.
        MouseArea {
            anchors.fill: parent
            onClicked: PanelState.close()
        }

        // Always focused while the pad is shown, so Escape works from any
        // view. Typing always means "search": it takes over whichever
        // overview tab was selected, same as clicking a different tab
        // would. (It used to go read-only while a full-card panel was up,
        // so background typing couldn't quietly rewrite the query you'd
        // land on when backing out — there is no such panel anymore.)
        TextInput {
            id: keyCatcher
            visible: false
            focus: PadState.shown
            Keys.onEscapePressed: PadState.close()
            Keys.onUpPressed: overview.moveSelection(-1)
            Keys.onDownPressed: overview.moveSelection(1)
            Keys.onReturnPressed: overview.activateSelected()
            onTextEdited: {
                PadState.searchQuery = text
                if (text.length > 0)
                    PanelState.inlineOpen = "search"
                else if (PanelState.inlineOpen === "search")
                    PanelState.inlineOpen = ""
            }
        }

        Item {
            id: inner
            x: Metrics.padPadding
            y: Metrics.padPaddingTop
            width: parent.width - Metrics.padPadding * 2
            implicitHeight: overview.implicitHeight

            // Instantiated directly, not through a Loader: the Loader only
            // existed to swap the overview out for the full-card calendar
            // panel, and the calendar is an inline tab now like everything
            // else, so there's only ever one thing to show here.
            PadViews.Overview {
                id: overview
                width: parent.width
            }
        }
    }
}
