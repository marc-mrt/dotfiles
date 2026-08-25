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
    // Ceiling for the whole card, as a fraction of screen height. Search
    // can return far more rows than fit, and the card used to just keep
    // growing past the bottom of the screen; past this the expanded tab
    // scrolls its contents instead (modules/pad/Overview.qml). Sits
    // comfortably under padTopFraction's remaining 70%.
    readonly property real padMaxHeightFraction: 0.35
    readonly property int padRadius: 20
    readonly property int padPadding: 16
    // Half the usual padding above the first row specifically, for a
    // tighter/more compact top edge than the sides/bottom.
    readonly property int padPaddingTop: 8

    // Notification stack (modules/NotificationStack.qml) — floats
    // independently of the pad at the bottom-right corner (see
    // shell.qml's notifWin).
    readonly property int notifCardWidth: 480

    // Window switcher (modules/WindowSwitcher.qml) — one card per
    // workspace, laid out side-by-side. switcherCanvas* is the layout
    // canvas inside each card (bounding box of that workspace's windows,
    // scaled to fit) — window boxes are screencopy snapshots with a
    // captioned footer, not a separate text list.
    readonly property real switcherTopFraction: 0.12
    readonly property int switcherCanvasWidth: 560
    readonly property int switcherCanvasHeight: 340
    readonly property int switcherFooterHeight: 28
    readonly property int switcherTileRadius: 10
    // Small inset between adjacent window tiles within one workspace —
    // cosmetic breathing room, not a reflection of Hyprland's real gaps_in.
    readonly property int switcherTileGap: 6
    readonly property int switcherRadius: 20
    readonly property int switcherPadding: 16
    // Gap between workspace columns — the only thing delimiting them now
    // that there's one outer card instead of one per workspace.
    readonly property int switcherGroupSpacing: 32
}
