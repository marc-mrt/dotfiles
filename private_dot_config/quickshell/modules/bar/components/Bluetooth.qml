import QtQuick
import "../../../config"
import "../../../services"
import "../widgets" as W

// Bar icon only — renders Bluetooth service state, toggles its inline panel
// in the pad overview on click (see services/PanelState.qml's inlineOpen).
Item {
    id: root
    readonly property int connectedCount: Bluetooth.devices
        ? Bluetooth.devices.values.filter(d => d.connected).length : 0

    implicitWidth: icon.implicitWidth + 20
    implicitHeight: Metrics.barHeight

    W.IconPill {
        anchors.centerIn: parent
        width: icon.implicitWidth + 20
        height: Math.round(root.implicitHeight * 0.74)
        active: PanelState.isInlineOpen("bluetooth")
        hovered: ma.containsMouse
    }

    Text {
        id: icon
        anchors.centerIn: parent
        color: Colors.text
        font.pixelSize: 15
        text: (Bluetooth.powered ? "\u{F00AF}" : "\u{F00B2}")
            + (root.connectedCount > 0 ? " " + root.connectedCount : "")
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: PanelState.toggleInline("bluetooth")
    }
}
