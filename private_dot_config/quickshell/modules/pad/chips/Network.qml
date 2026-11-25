import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Connection type + signal strength, icon only — no SSID label.
W.StatusChip {
    icon: Network.ethernetConnected ? "ethernet-port"
        : !Network.wifiEnabled ? "wifi-off"
        : !Network.connected ? "wifi-zero"
        : Network.activeSignal >= 70 ? "wifi"
        : Network.activeSignal >= 45 ? "wifi-high"
        : Network.activeSignal >= 20 ? "wifi-low"
        : "wifi-zero"
    // Dim full wifi behind the levelled glyph, so every strength reads
    // as a cutout of the same shape; ethernet and radio-off keep a
    // single icon.
    iconBack: Network.ethernetConnected || !Network.wifiEnabled ? "" : "wifi"
    // No ethernet and no wifi link (radio off or not associated).
    alert: !Network.ethernetConnected && (!Network.wifiEnabled || !Network.connected)
    active: PanelState.isInlineOpen("network")
    onClicked: PanelState.toggleInline("network")
}
