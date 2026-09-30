import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Connection type + signal strength, icon only — no SSID label.
W.StatusChip {
    text: Network.ethernetConnected ? "\u{F0200}"
        : !Network.wifiEnabled ? "\u{F092F}"
        : !Network.connected ? "\u{F0922}"
        : Network.activeSignal >= 70 ? "\u{F0928}"
        : Network.activeSignal >= 45 ? "\u{F0925}"
        : Network.activeSignal >= 20 ? "\u{F0922}"
        : "\u{F092F}"
    active: PanelState.isInlineOpen("network")
    onClicked: PanelState.toggleInline("network")
}
