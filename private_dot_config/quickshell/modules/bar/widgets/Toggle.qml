import QtQuick
import "../../../config"

// Small iOS-style switch. Emits toggled(); the parent owns the state.
//
// Hover has to work in both states, so it can't just be a tint: against the
// accent-filled "on" track a faint overlay is invisible. Instead the track
// lightens either way — the off track brightens toward the text color, the
// on track brightens the accent — plus a ring around the knob, which reads
// on both.
Rectangle {
    id: root
    property bool checked: false
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: root.checked
        ? (ma.containsMouse ? Qt.lighter(Colors.accent, 1.25) : Colors.accent)
        : Colors.alpha(Colors.text, ma.containsMouse ? 0.32 : 0.2)
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.toggled()
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: Colors.base
        y: (parent.height - height) / 2
        x: root.checked ? root.width - width - 3 : 3
        border.width: ma.containsMouse ? 2 : 0
        border.color: Colors.alpha(Colors.text, 0.35)
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on border.width { NumberAnimation { duration: 120 } }
    }
}
