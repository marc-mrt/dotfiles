import QtQuick
import QtQuick.Layouts
import "../../config"

// Compact stand-in for the three separate ring gauges this replaced (see
// modules/pad/Overview.qml) — same CPU/RAM/GPU-at-a-glance info, same
// escalating Colors.loadColor tint per bar, but as one small pill instead
// of three ~38px hover discs sitting side by side. A tooltip carries the
// exact numbers that the old rings never showed either (icon-only), since
// the smaller footprint loses even more room for digits.
Item {
    id: root

    property real cpu: 0
    property real ram: 0
    property real vram: 0
    readonly property real barMaxHeight: 16

    signal clicked

    implicitWidth: pill.implicitWidth
    implicitHeight: 30

    component Bar: Item {
        property real value: 0
        Layout.preferredWidth: 4
        Layout.fillHeight: true
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            radius: 2
            color: Colors.loadColor(value)
            height: Math.max(2, root.barMaxHeight * Math.max(0, Math.min(100, value)) / 100)
            Behavior on height { NumberAnimation { duration: Metrics.durationValue; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Metrics.durationValue } }
        }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: ma.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: Metrics.durationFast } }
        implicitWidth: bars.implicitWidth + 20

        RowLayout {
            id: bars
            anchors.centerIn: parent
            height: root.barMaxHeight
            spacing: 4
            Bar { value: root.cpu }
            Bar { value: root.ram }
            Bar { value: root.vram }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    ToolTip {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 6
        show: ma.containsMouse
        text: "CPU " + Math.round(root.cpu) + "% · RAM " + Math.round(root.ram)
            + "% · GPU " + Math.round(root.vram) + "%"
    }
}
