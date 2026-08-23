import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

// Content only — window/positioning lives in shell.qml, same split as
// Pad.qml/NotificationStack.qml. Driven entirely by services/Osd.qml.
RowLayout {
    id: root
    spacing: 10

    readonly property bool isVolume: Osd.kind === "volume"
    readonly property bool muted: root.isVolume && Osd.muted
    readonly property real frac: root.muted ? 0 : Osd.value / 100

    Text {
        text: root.isVolume
            ? (root.muted ? "\u{F075F}" : "\u{F057E}")
            : "\u{2600}"
        color: Colors.text
        font.pixelSize: 18
    }

    Rectangle {
        id: track
        Layout.preferredWidth: 140
        implicitHeight: 8
        radius: 4
        color: Colors.base

        Rectangle {
            width: parent.width * root.frac
            height: parent.height
            radius: 4
            color: root.muted
                ? Colors.alpha(Colors.text, 0.3)
                : Colors.accent
        }
    }

    Text {
        text: root.muted ? "Muted" : (Osd.value + "%")
        color: Colors.text
        font.pixelSize: 11
        Layout.preferredWidth: 40
        horizontalAlignment: Text.AlignRight
    }
}
