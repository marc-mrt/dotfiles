pragma Singleton
import QtQuick

// Shared layout constants needed by more than one top-level window.
QtObject {
    readonly property int chipHeight: 34

    // Pad — floating card, positioned by modules/Pad.qml.
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

    // Shared motion constants, so every open/close/hover transition across
    // the shell eases the same way instead of each surface picking its own
    // feel. durationFast for small hover/press feedback, durationNormal for
    // a surface appearing/resizing, durationValue for a *measurement*
    // easing to a new reading (a load bar, a ring gauge, a fill).
    //
    // These three existed and were then bypassed 25 times across 7 raw
    // values (100/120/150/160/200/250/300) — Pad.qml even used
    // durationNormal for its opacity/scale and a hardcoded 150 for its
    // width/height fifteen lines below, giving one surface two feels for
    // one gesture. durationValue is the genuinely missing role: 300 had
    // been invented independently four times for exactly it.
    readonly property int durationFast: 120
    readonly property int durationNormal: 160
    readonly property int durationValue: 300
    readonly property int easingStandard: Easing.OutCubic

    // Type scale. There were ten distinct pixel sizes in use (11, 13, 15,
    // 16, 17, 18, 20, 21, 22, 50) for what is really five roles — 15/16/17
    // is far too fine a gradation to have been deliberate, and it is how
    // the search list ended up at 18px for the same kind of row label that
    // every tab renders at 17. Named by role, so a new label picks a
    // meaning rather than a number.
    readonly property int fontSmall: 13      // uppercase section captions, chevrons
    readonly property int fontSecondary: 15  // status under a label, readouts, placeholders
    readonly property int fontBody: 17       // labels, list rows, menu entries — the default
    readonly property int fontLarge: 20      // notification app name and message text
    readonly property int fontDisplay: 50    // the pad clock, and nothing else

    // Shared spacing for a tab's own layout. The eighteen tokens that
    // used to sit here — panelRow*, panelSectionLabel*, slider* — are gone:
    // they existed only to keep three copies of a slider and seven copies
    // of a list row agreeing with each other, and now that a slider and a
    // list row are each one module (modules/ui/Slider.qml,
    // modules/ui/ListRow.qml) those numbers are that module's own business.
    // Publishing sliderHandleHoverSize was the tell that the module was
    // missing.
    readonly property int panelSpacing: 10           // root ColumnLayout / control-row spacing
    readonly property int panelHeaderSpacing: 10     // spacing inside a title row (label + trailing toggle/buttons)
    readonly property int panelSectionListSpacing: 4 // spacing between rows inside a W.Section list

    // Icon-button glyph/backing — see modules/ui/IconButton.qml
    readonly property int iconButtonGlyphSize: 22
    readonly property int iconButtonSize: 34
}
