import QtQuick
import QtQuick.Layouts
import "../../config"

// The draggable part of a slider on its own: track, fill, handle, and the
// press/drag arithmetic. Split out from W.Slider once the per-app mixer
// needed a track in a row of its own shape ({icon} {name} {mute} {track}
// {value}) rather than Slider's fixed icon/track/readout arrangement.
//
// Slider is still the thing to reach for — this exists so that a different
// arrangement can be composed without copying the one genuinely fiddly
// part, which is the clamp and the hit area rather than the rectangles.
Item {
    id: root

    property real fraction: 0
    property color fillColor: Colors.accent
    signal moved(real fraction)

    readonly property real clamped: Math.max(0, Math.min(1, root.fraction))

    // Hit area is much taller than the visible track, so grabbing the
    // slider doesn't require pixel-precise aim at an 8px bar.
    implicitHeight: 24
    implicitWidth: 80

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: Colors.base

        Rectangle {
            width: parent.width * root.clamped
            height: parent.height
            radius: 4
            color: root.fillColor
        }
    }

    // Grows on hover/drag: the handle is the grabbable part, so it's what
    // has to look grabbable. Positioned from its own centre so it swells in
    // place instead of drifting sideways as the size changes.
    Rectangle {
        width: ma.containsMouse || ma.pressed ? 18 : 14
        height: width
        radius: width / 2
        color: Colors.text
        y: (parent.height - height) / 2
        x: Math.max(0, Math.min(parent.width - width,
            parent.width * root.clamped - width / 2))
        Behavior on width { NumberAnimation { duration: Metrics.durationFast } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        function apply(mx) {
            root.moved(Math.max(0, Math.min(1, mx / width)))
        }
        onPressed: (m) => ma.apply(m.x)
        onPositionChanged: (m) => { if (ma.pressed) ma.apply(m.x) }
    }
}
