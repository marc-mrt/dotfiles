import QtQuick
import QtQuick.Shapes
import "../../../config"

// Small ring gauge — icon centered inside a circular progress arc. Used by
// the pad overview's CPU/RAM/VRAM stats (see modules/pad/Overview.qml),
// which used to be plain "icon percent%" text with no visual weight.
Item {
    id: root

    property real value: 0 // 0-100
    property string icon: ""
    property color ringColor: Colors.accent
    property int size: 30
    readonly property real strokeWidth: 3

    implicitWidth: size
    implicitHeight: size

    Behavior on value { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

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
