import QtQuick
import "../../../config"
import "../../../services"
import "../widgets" as W

// Bar icon only — renders Brightness service state, toggles its inline panel
// in the pad overview on click. Scroll to adjust.
Item {
    id: root
    visible: Brightness.available
    implicitWidth: visible ? icon.implicitWidth + 20 : 0
    implicitHeight: Metrics.barHeight

    W.IconPill {
        anchors.centerIn: parent
        width: icon.implicitWidth + 20
        height: Math.round(root.implicitHeight * 0.74)
        active: PanelState.isInlineOpen("brightness")
        hovered: ma.containsMouse
    }

    Text {
        id: icon
        anchors.centerIn: parent
        color: Colors.text
        font.pixelSize: 15
        text: "\u{2600} " + Brightness.brightness + "%"
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: PanelState.toggleInline("brightness")
        onWheel: (wheel) => {
            Brightness.setBrightness(Brightness.brightness + (wheel.angleDelta.y > 0 ? 5 : -5))
        }
    }
}
