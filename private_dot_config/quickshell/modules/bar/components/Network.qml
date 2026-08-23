import QtQuick
import "../../../config"
import "../../../services"
import "../widgets" as W

// Bar icon only — renders Network service state, toggles its inline panel
// in the pad overview on click (see services/PanelState.qml's inlineOpen).
Item {
    id: root
    implicitWidth: icon.implicitWidth + 20
    implicitHeight: Metrics.barHeight

    W.IconPill {
        anchors.centerIn: parent
        width: icon.implicitWidth + 20
        height: Math.round(root.implicitHeight * 0.74)
        active: PanelState.isInlineOpen("network")
        hovered: ma.containsMouse
    }

    Text {
        id: icon
        anchors.centerIn: parent
        color: Colors.text
        font.pixelSize: 15
        // Icon only — connection type + signal strength, no SSID label.
        text: Network.ethernetConnected ? "\u{F0200}"
            : !Network.wifiEnabled ? "\u{F092F}"
            : !Network.connected ? "\u{F0922}"
            : Network.activeSignal >= 70 ? "\u{F0928}"
            : Network.activeSignal >= 45 ? "\u{F0925}"
            : Network.activeSignal >= 20 ? "\u{F0922}"
            : "\u{F092F}"
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: PanelState.toggleInline("network")
    }
}
