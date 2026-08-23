pragma Singleton
import QtQuick

// Two different panel models live here:
//
// - `open` — exclusive, whole-pad-card panels (just calendar now — see
//   modules/NotificationStack.qml for where notifications live). Only one
//   at a time, same as the old bar/drawer.
// - `inlineOpen` — the network/bluetooth/brightness/volume widgets embed
//   their panel directly in the overview instead of taking over the card.
//   Tab-like: also exclusive, one at a time — picking a different widget
//   swaps which one is expanded rather than stacking them.
QtObject {
    id: root

    property string open: ""

    // Center-x (in the pad's own coordinate space) of the chip that opened
    // the current exclusive panel — unused by the fixed-position pad today,
    // kept for parity with the old anchored-drawer chips that still pass it.
    property real anchorX: 0

    function toggle(name, x) {
        open = (open === name) ? "" : name
        anchorX = x
    }

    property string inlineOpen: ""

    function isInlineOpen(name) {
        return root.inlineOpen === name
    }

    function toggleInline(name) {
        root.inlineOpen = (root.inlineOpen === name) ? "" : name
    }

    function close() {
        open = ""
        inlineOpen = ""
    }
}
