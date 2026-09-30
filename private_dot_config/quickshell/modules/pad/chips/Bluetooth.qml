import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Powered state, plus how many devices are connected when any are.
W.StatusChip {
    id: root
    readonly property int connectedCount: Bluetooth.devices
        ? Bluetooth.devices.values.filter(d => d.connected).length : 0

    text: (Bluetooth.powered ? "\u{F00AF}" : "\u{F00B2}")
        + (root.connectedCount > 0 ? " " + root.connectedCount : "")
    active: PanelState.isInlineOpen("bluetooth")
    onClicked: PanelState.toggleInline("bluetooth")
}
