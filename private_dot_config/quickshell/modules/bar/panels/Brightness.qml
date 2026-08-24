import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../widgets" as W

// Panel content only — embedded inline under the Brightness widget in the
// pad overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
ColumnLayout {
    id: root
    spacing: 10

    Text {
        text: "Brightness"
        color: Colors.text
        font.pixelSize: 15
        font.bold: true
        Layout.bottomMargin: 2
        Layout.leftMargin: 2
    }

    W.Section {
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "\u{2600}"
                color: Colors.text
                font.pixelSize: 20
            }

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Colors.base

                Rectangle {
                    width: parent.width * (Brightness.brightness / 100)
                    height: parent.height
                    radius: 4
                    color: Colors.accent
                }
                // Grows on hover/drag: the handle is the grabbable
                // part, so it's what has to look grabbable. Anchored on
                // its own center so it swells in place instead of
                // drifting sideways as the size changes.
                Rectangle {
                    id: handle
                    width: briMa.containsMouse || briMa.pressed ? 18 : 14
                    height: width
                    radius: width / 2
                    color: Colors.text
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(parent.width - width,
                        parent.width * (Brightness.brightness / 100) - width / 2))
                    Behavior on width { NumberAnimation { duration: 100 } }
                }
                MouseArea {
                    id: briMa
                    anchors.fill: parent
                    hoverEnabled: true
                    function apply(mx) {
                        Brightness.setBrightness((mx / width) * 100)
                    }
                    onPressed: (m) => apply(m.x)
                    onPositionChanged: (m) => { if (pressed) apply(m.x) }
                }
            }

            Text {
                text: Brightness.brightness + "%"
                color: Colors.text
                font.pixelSize: 12
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
