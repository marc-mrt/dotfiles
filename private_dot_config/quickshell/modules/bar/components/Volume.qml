import QtQuick
import "../../../config"
import "../../../services"
import "../widgets" as W

// Bar icon only — renders Audio service state, toggles its inline panel in
// the pad overview on click. Scroll to adjust the default sink, middle-click
// to mute.
Item {
    id: root
    implicitWidth: icon.implicitWidth + 20
    implicitHeight: Metrics.barHeight

    W.IconPill {
        anchors.centerIn: parent
        width: icon.implicitWidth + 20
        height: Math.round(root.implicitHeight * 0.74)
        active: PanelState.isInlineOpen("volume")
        hovered: ma.containsMouse
    }

    Text {
        id: icon
        anchors.centerIn: parent
        color: Colors.text
        font.pixelSize: 15
        text: (Audio.muted ? "\u{F075F} " : "\u{F057E} ") + Audio.volume + "%"
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                Audio.toggleMute()
            else
                PanelState.toggleInline("volume")
        }
        onWheel: (wheel) => {
            Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 5 : -5))
        }
    }
}
