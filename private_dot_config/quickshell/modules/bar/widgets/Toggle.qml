import QtQuick
import "../../../config"

// Small iOS-style switch. Emits toggled(); the parent owns the state.
Rectangle {
    id: root
    property bool checked: false
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: checked ? Colors.accent
                   : Colors.alpha(Colors.text, 0.2)
    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: Colors.base
        y: (parent.height - height) / 2
        x: root.checked ? root.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled()
    }
}
