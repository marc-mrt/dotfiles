import QtQuick
import "../../../config"
import "../../../services"
import "../widgets" as W

// Bar clock — click expands the calendar tab. Not instantiated anywhere
// right now (the pad draws its own big clock, see modules/pad/Overview.qml);
// kept working against the current PanelState so it isn't quietly broken if
// a bar ever comes back.
Item {
    id: root
    implicitWidth: label.implicitWidth + 20
    implicitHeight: Metrics.barHeight

    W.IconPill {
        anchors.centerIn: parent
        width: label.implicitWidth + 20
        height: Math.round(root.implicitHeight * 0.74)
        active: PanelState.isInlineOpen("calendar")
        hovered: ma.containsMouse
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Colors.text
        font.pixelSize: 14
        property var now: new Date()
        text: Qt.formatDateTime(now, "hh:mm")
        Timer {
            interval: 10000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: label.now = new Date()
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: PanelState.toggleInline("calendar")
    }
}
