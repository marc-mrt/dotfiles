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
        W.SectionLabel { text: "QUICK TOGGLES" }

        // The footer chips for these only show while the state is on, so this
        // is the one place they can be switched from when off.
        Repeater {
            model: [
                { glyph: "\u{F00AF}", label: "Bluetooth" },
                { glyph: "\u{EF59}", label: "Caffeine" },
                { glyph: "\u{F009B}", label: "Do Not Disturb" }
            ]
            delegate: W.ListRow {
                id: row
                required property var modelData
                required property int index
                glyph: row.modelData.glyph
                label: row.modelData.label
                onClicked: tog.toggled()

                W.Toggle {
                    id: tog
                    checked: row.index === 0 ? Bluetooth.powered
                        : row.index === 1 ? Caffeine.active : Notifications.dnd
                    onToggled: row.index === 0 ? Bluetooth.togglePower()
                        : row.index === 1 ? Caffeine.toggle() : Notifications.toggleDnd()
                }
            }
        }
    }

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
