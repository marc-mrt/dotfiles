pragma Singleton
import QtQuick

// Shared layout constants needed by more than one top-level window.
QtObject {
    readonly property int barHeight: 34

    // Pad — floating rectangle, positioned by modules/Pad.qml.
    readonly property int padWidth: 576
    // Search needs more room for a results list than a collapsed widget
    // tab does — grown instead of giving search its own separate view, so
    // there's a single overview UI at all times (see Overview.qml).
    readonly property int padSearchWidth: 768
    readonly property real padTopFraction: 0.30
    readonly property int padRadius: 20
    readonly property int padPadding: 16
    // Half the usual padding above the first row specifically, for a
    // tighter/more compact top edge than the sides/bottom.
    readonly property int padPaddingTop: 8

    // Width of the one remaining exclusive full-card panel — network,
    // bluetooth, brightness and volume embed inline in the overview instead
    // (see modules/pad/Overview.qml) and just use padWidth.
    readonly property var padPanelWidths: ({
        "calendar": 336
    })

    // Notification stack (modules/NotificationStack.qml) — floats
    // independently of the pad at the bottom-right corner (see
    // shell.qml's notifWin).
    readonly property int notifCardWidth: 480

    // shell.qml's padWin/padCornerCatcher reserve this much screen space
    // so they never geometrically overlap notifWin — a full-screen pad
    // surface would otherwise remap on top of it and swallow clicks meant
    // for a notification. Derived from notifCardWidth (+ its own margins
    // and window margin, ~32px, + a buffer) rather than an independent
    // number, so the two stay in sync if the card ever gets wider.
    // notifReserveHeight has no equivalent card measurement to derive
    // from — the stack's total height depends on how many groups/messages
    // are showing, which is unbounded in principle — so it's a flat,
    // deliberately generous ceiling instead: comfortably fits several
    // stacked cards, not a guarantee for arbitrarily many.
    readonly property int notifReserveWidth: notifCardWidth + 70
    readonly property int notifReserveHeight: 920
}
