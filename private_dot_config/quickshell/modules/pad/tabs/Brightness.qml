import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../../ui" as W

// Tab content only — embedded inline under the Brightness chip in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

    W.TabHeader { title: "Brightness" }

    W.Section {
        W.Slider {
            fraction: Brightness.brightness / 100
            onMoved: (f) => Brightness.setBrightness(f * 100)
            readout: Brightness.brightness + "%"

            Text {
                anchors.centerIn: parent
                text: "\u{2600}"
                color: Colors.text
                font.pixelSize: Metrics.iconButtonGlyphSize
            }
        }
    }
}
