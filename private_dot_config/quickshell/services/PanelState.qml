pragma Singleton
import QtQuick

// Which overview tab is expanded, if any: a widget name
// (network/bluetooth/brightness/volume), "calendar", "search", or "".
// Tab-like and exclusive — picking a different one swaps which is expanded
// rather than stacking them.
//
// There used to be a second, separate model alongside this (`open`, plus an
// anchorX for the old anchored-drawer chips) for panels that took over the
// whole pad card. The calendar was the last thing using it and is an inline
// tab now, so that half is gone: one expansion slot, one way in.
QtObject {
    id: root

    property string inlineOpen: ""

    function isInlineOpen(name) {
        return root.inlineOpen === name
    }

    function toggleInline(name) {
        root.inlineOpen = (root.inlineOpen === name) ? "" : name
    }

    function close() {
        inlineOpen = ""
    }
}
