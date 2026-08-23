pragma Singleton
import QtQuick

// Whether the pad is shown, and the live search query text. Replaces
// BarVisibility — the pad is invoke-then-dismiss (SUPER+SPACE / SUPER+Tab),
// not a persistent strip, so there's no OLED-driven auto-hide timer to carry
// over. Which overview tab is selected (including "search" itself) lives in
// PanelState.inlineOpen, not here — see modules/Pad.qml for how the two
// stay in sync.
QtObject {
    id: root

    property bool shown: false
    property string searchQuery: ""
    // "" (overview default) or "windows" (SUPER+Tab biases search results
    // toward open windows first).
    property string searchBias: ""

    // bias: "" opens straight to the overview, "windows" opens straight to
    // search pre-biased toward open windows (SUPER+Tab). Toggling while
    // already shown always closes, regardless of which key triggered it.
    function toggle(bias) {
        if (shown) {
            close()
            return
        }
        searchQuery = ""
        searchBias = bias ?? ""
        shown = true
    }

    function close() {
        shown = false
        searchQuery = ""
        searchBias = ""
    }
}
