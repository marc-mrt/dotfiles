import QtQuick
import QtQuick.Shapes
import "../../../config"

// Small ring gauge — icon centered inside a circular progress arc. Used by
// the pad overview's CPU/RAM/VRAM stats (see modules/pad/Overview.qml),
// which used to be plain "icon percent%" text with no visual weight.
//
// Clickable: the hover disc is the round counterpart of W.IconPill's hover
// tint, at the same strength, so a gauge reads as "you can press this" the
// same way every other control in the pad does.
Item {
    id: root

    property real value: 0 // 0-100
    property string icon: ""
    property color ringColor: Colors.accent
    property int size: 30
    readonly property real strokeWidth: 3

    signal clicked

    implicitWidth: size
    implicitHeight: size

    Behavior on value { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // Declared first so the hover binding below doesn't evaluate against an
    // id that doesn't exist yet. Being first costs nothing for input: the
    // arc and icon that follow are a Shape and a Text, neither of which
    // accepts mouse events, so clicks fall straight through to this.
    // Sized to the hover disc, not the ring, so the whole tinted area is
    // pressable rather than just the arc itself.
    MouseArea {
        id: ma
        anchors.centerIn: parent
        width: root.size + 8
        height: root.size + 8
        hoverEnabled: true
        onClicked: root.clicked()
    }

    // Sits behind the arc and slightly outside it, so the tint reads as a
    // target around the gauge rather than as a change to the gauge itself.
    Rectangle {
        anchors.centerIn: parent
        width: root.size + 8
        height: root.size + 8
        radius: width / 2
        color: ma.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.strokeWidth
            strokeColor: Colors.alpha(Colors.text, 0.15)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.strokeWidth) / 2
                radiusY: (root.size - root.strokeWidth) / 2
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeWidth: root.strokeWidth
            strokeColor: root.ringColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.strokeWidth) / 2
                radiusY: (root.size - root.strokeWidth) / 2
                startAngle: -90
                // Floor of 2deg so a 0% ring still shows a dot instead of
                // vanishing entirely (RoundCap needs some sweep to render).
                sweepAngle: 360 * Math.max(0.006, root.value / 100)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: Colors.text
        font.pixelSize: 12
    }
}
