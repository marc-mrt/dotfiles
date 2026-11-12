pragma Singleton
import QtQuick

// Whether the pad is shown, and the live search query text. Replaces
// BarVisibility — the pad is invoke-then-dismiss (SUPER+SPACE), not a
// persistent strip, so there's no OLED-driven auto-hide timer to carry
// over. Which overview tab is selected (including "search" itself) lives in
// PanelState.inlineOpen, not here — see modules/Pad.qml for how the two
// stay in sync. SUPER+Tab no longer touches this at all — that's
// services/SwitcherState.qml's own window now.
QtObject {
    id: root

    property bool shown: false
    property string searchQuery: ""

    // Toggling while already shown always closes.
    function toggle() {
        if (shown) {
            close()
            return
        }
        searchQuery = ""
        shown = true
    }

    // The query is left alone here: the card is still fading out with the
    // results on it. modules/Pad.qml's reset() clears it once that is over.
    function close() {
        shown = false
    }
}
