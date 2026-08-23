import QtQuick
import "../../../config"
import "../../../services"
import "../widgets" as W

// Bar icon only — simple DND toggle, nothing else. History lives at the
// bottom-right of the screen now (see modules/NotificationStack.qml), not
// behind this icon, so it doesn't need to do anything but flip dnd.
Item {
    id: root
    implicitWidth: icon.implicitWidth + 20
    implicitHeight: Metrics.barHeight

    W.IconPill {
        anchors.centerIn: parent
        width: icon.implicitWidth + 20
        height: Math.round(root.implicitHeight * 0.74)
        active: Notifications.dnd
        hovered: ma.containsMouse
    }

    Text {
        id: icon
        anchors.centerIn: parent
        color: Colors.text
        font.pixelSize: 15
        text: Notifications.dnd ? "\u{F1F6}" : "\u{F0F3}"
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Notifications.toggleDnd()
    }
}
