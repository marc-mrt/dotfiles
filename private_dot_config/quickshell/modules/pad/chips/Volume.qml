import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Scroll to adjust the default sink, middle-click to mute.
W.StatusChip {
    text: (Audio.muted ? "\u{F075F} " : "\u{F057E} ") + Audio.volume + "%"
    active: PanelState.isInlineOpen("volume")
    onClicked: PanelState.toggleInline("volume")
    onMiddleClicked: Audio.toggleMute()
    onScrolled: (steps) => Audio.setVolume(Audio.volume + steps * 5)
}
