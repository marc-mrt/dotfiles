import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Shown only while powered (an off radio is not news; the Settings tab has
// the switch), plus how many devices are connected when any are.
W.StatusChip {
    id: root
    visible: Bluetooth.powered
    readonly property int connectedCount: Bluetooth.devices
        ? Bluetooth.devices.values.filter(d => d.connected).length : 0

    text: "\u{F00AF}"
        + (root.connectedCount > 0 ? " " + root.connectedCount : "")
    centreOnAdvance: true
    active: PanelState.isInlineOpen("bluetooth")
    onClicked: PanelState.toggleInline("bluetooth")
}
