import QtQuick
import Quickshell.Services.Mpris
import "../../../config"
import "../../../services"
import "../../ui" as W

// Only exists while an MPRIS player does — an always-present chip with
// nothing to show would be a dead target. Zero width when hidden: RowLayout
// skips invisible children, so the row doesn't leave a gap.
W.StatusChip {
    icon: Mpris.players.values.some(p => p.isPlaying) ? "play" : "pause"
    visible: Mpris.players.values.length > 0
    active: PanelState.isInlineOpen("media")
    onClicked: PanelState.toggleInline("media")
}
