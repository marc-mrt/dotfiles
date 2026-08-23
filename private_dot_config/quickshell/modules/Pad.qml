import QtQuick
import Quickshell
import "../config"
import "../services"
import "./bar/panels" as Panels
import "./pad" as PadViews

// Pad content — a single fixed-position card floating ~30% from the top,
// horizontally centered (window/positioning chrome lives in shell.qml).
// Replaces Bar.qml + Drawer.qml: one surface, always showing the meta-info
// overview (network/bluetooth/brightness/volume — and now search too — are
// exclusive tabs embedded right there, see modules/pad/Overview.qml),
// except for calendar, which doesn't have an overview widget of its own to
// embed under and still takes over the whole card the way the old drawer
// did. Notifications live entirely outside the pad now (see
// modules/NotificationStack.qml).
Item {
    id: root

    readonly property bool panelOpen: PanelState.open !== ""
    readonly property real cardWidth: root.panelOpen
        ? (Metrics.padPanelWidths[PanelState.open] ?? Metrics.padWidth)
        : (PanelState.inlineOpen === "search" ? Metrics.padSearchWidth : Metrics.padWidth)

    // Reset to a clean overview every time the pad closes, so it never
    // reopens mid-search or mid-panel (SUPER+SPACE/SUPER+Tab always land
    // exactly where PadState.toggle() asked).
    Connections {
        target: PadState
        function onShownChanged() {
            if (!PadState.shown) {
                PanelState.close()
                keyCatcher.text = ""
            } else if (PadState.searchBias === "windows") {
                // SUPER+Tab: land straight on the search tab, pre-biased to
                // open windows (see Search.qml's windows-first ordering).
                PanelState.inlineOpen = "search"
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
        // parent.height is fine (padWin is full height), but NOT
        // parent.width — padWin is narrower than the screen (see its
        // comment in shell.qml), so centering against it would pull the
        // card left of true screen-center.
        anchors.topMargin: parent.height * Metrics.padTopFraction
        x: (Quickshell.screens[0].width - width) / 2
        width: root.cardWidth
        height: inner.implicitHeight + Metrics.padPaddingTop + Metrics.padPadding
        radius: Metrics.padRadius
        color: Colors.alpha(Colors.surface, 0.9)
        // Matches modules/NotificationStack.qml's card border, for a
        // consistent look across every floating surface this shell shows.
        border.width: 2
        border.color: Colors.accent

        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // Click on empty card space: step back from a drill-down panel to
        // the overview it was opened from (same gesture the old bar used to
        // close whichever panel was open) — also collapses any open
        // overview tab, since PanelState.close() clears inlineOpen too.
        MouseArea {
            anchors.fill: parent
            onClicked: PanelState.close()
        }

        // Always focused while the pad is shown, so Escape works from any
        // view. Only actually accepts typed text in the overview — while a
        // full-card panel is open it's read-only so background typing can't
        // quietly change the search query you'll land on when you back out.
        // Typing always means "search": it takes over whichever overview
        // tab was selected, same as clicking a different tab would.
        TextInput {
            id: keyCatcher
            visible: false
            focus: PadState.shown
            readOnly: root.panelOpen
            Keys.onEscapePressed: PadState.close()
            Keys.onUpPressed: if (loader.item && loader.item.moveSelection) loader.item.moveSelection(-1)
            Keys.onDownPressed: if (loader.item && loader.item.moveSelection) loader.item.moveSelection(1)
            Keys.onReturnPressed: if (loader.item && loader.item.activateSelected) loader.item.activateSelected()
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
            implicitHeight: loader.item ? loader.item.implicitHeight : 0

            Loader {
                id: loader
                width: parent.width
                sourceComponent: PanelState.open === "calendar" ? calendarComp
                    : overviewComp
            }
        }
    }

    Component { id: overviewComp; PadViews.Overview {} }
    Component { id: calendarComp; Panels.Calendar {} }
}
