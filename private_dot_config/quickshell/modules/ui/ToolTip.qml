import QtQuick
import "../../config"

// Bespoke hover label matching the pad's own surface styling (Colors.surface
// + hairline border, see e.g. modules/Pad.qml's card) instead of
// QtQuick.Controls' ToolTip, which renders in the OS/Qt style and looks out
// of place floating over this bespoke UI (see pad/chips/Tray.qml).
Card {
    id: root
    property alias text: label.text
    property bool show: false
    property int delay: 400

    radius: 8
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 8

    opacity: 0
    visible: opacity > 0 && root.text !== ""
    z: 1000

    Behavior on opacity { NumberAnimation { duration: Metrics.durationFast } }

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: root.opacity = 1
    }

    onShowChanged: {
        if (root.show) {
            showTimer.start()
        } else {
            showTimer.stop()
            root.opacity = 0
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Colors.text
        font.pixelSize: Metrics.fontSecondary
    }
}
