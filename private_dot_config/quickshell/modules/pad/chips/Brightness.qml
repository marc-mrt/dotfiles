import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Hidden entirely on hardware with no DDC/CI monitor to talk to. Scroll to
// adjust; a Layout excludes an invisible child from sizing, so hiding is
// all it takes to leave no gap behind.
W.StatusChip {
    visible: Brightness.available
    text: "\u{2600} " + Brightness.brightness + "%"
    active: PanelState.isInlineOpen("brightness")
    onClicked: PanelState.toggleInline("brightness")
    onScrolled: (steps) => Brightness.setBrightness(Brightness.brightness + steps * 5)
}
