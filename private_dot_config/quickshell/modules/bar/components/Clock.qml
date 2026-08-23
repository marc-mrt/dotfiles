import QtQuick
import "../../../config"
import "../../../services"
import "../widgets" as W

// Bar clock — click opens the calendar drawer panel.
Item {
    id: root
    implicitWidth: label.implicitWidth + 20
    implicitHeight: Metrics.barHeight

    W.IconPill {
        anchors.centerIn: parent
        width: label.implicitWidth + 20
        height: Math.round(root.implicitHeight * 0.74)
        active: PanelState.open === "calendar"
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
        onClicked: PanelState.toggle("calendar", root.mapToItem(null, root.width / 2, 0).x)
    }
}
