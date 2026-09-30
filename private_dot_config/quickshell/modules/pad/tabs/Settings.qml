import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../../ui" as W

// Tab content only — embedded inline under the Settings chip in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
// Rudimentary on purpose: just the settings that get touched often, not a
// full control-center clone.
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

    W.TabHeader { title: "Settings" }

    W.Section {
        W.SectionLabel { text: "MOUSE SENSITIVITY" }

        // sensitivity is -1..1 (Hyprland's own libinput accel-speed range);
        // W.Slider is always 0..1, so the mapping lives here where the
        // reason for it is visible.
        W.Slider {
            fraction: (Mouse.sensitivity + 1) / 2
            onMoved: (f) => Mouse.setSensitivity(f * 2 - 1)
            readout: Mouse.sensitivity.toFixed(2)

            Text {
                anchors.centerIn: parent
                text: "\u{F8CC}"
                color: Colors.text
                font.pixelSize: Metrics.iconButtonGlyphSize
            }
        }
    }
}
