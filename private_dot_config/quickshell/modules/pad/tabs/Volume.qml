import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../../config"
import "../../../services"
import "../../ui" as W

// Tab content only — embedded inline under the Volume chip in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
// Header and master slider stay put; a PageBar switches the body between
// Output, Input and Apps (per-application mixer).
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

    Component.onCompleted: Audio.refresh()

    W.TabHeader { title: "Sound" }

    // Master slider — always drives @DEFAULT_AUDIO_SINK@, so it follows
    // whichever output device is currently selected as default.
    W.Section {
        W.Slider {
            fraction: Audio.volume / 100
            onMoved: (f) => Audio.setVolume(f * 100)
            fillColor: Audio.muted ? Colors.alpha(Colors.text, 0.3) : Colors.accent
            readout: Audio.volume + "%"

            W.IconButton {
                anchors.fill: parent
                glyph: Audio.muted ? "\u{F075F}" : "\u{F057E}"
                glyphColor: Audio.muted ? Colors.alpha(Colors.text, 0.5) : Colors.text
                onClicked: Audio.toggleMute()
            }
        }
    }

    W.Section {
        W.PageBar { id: pages; model: ["Output", "Input", "Apps"] }

        // Per-application mixer. One row per app: icon, name, mute, track,
        // value. It composes W.SliderTrack directly rather than using W.Slider,
        // whose icon/track/readout arrangement has no room for the app's name
        // — the drag mechanism is shared either way.
        //
        // One LiveSetting per stream rather than writing pactl on every drag
        // pixel: it debounces and serializes the write, and — more importantly
        // — holds the value optimistically, so the handle tracks the cursor
        // instead of waiting for pactl to answer.
        ColumnLayout {
            visible: pages.current === 2
            Layout.fillWidth: true
            spacing: Metrics.panelSectionListSpacing

            Repeater {
                model: Audio.streams
                delegate: RowLayout {
                    id: row
                    required property var modelData
                    // Deliberately not called `state`: that is a built-in Item
                    // property, and shadowing it here would quietly break any
                    // later use of QML states on this row.
                    readonly property var vol: Audio.streamState[row.modelData.index]
                        ?? ({ volume: 0, muted: false })

                    Layout.fillWidth: true
                    spacing: 8

                    // Feed pactl's own reading in whenever the service
                    // refreshes. LiveSetting ignores it while a write of ours
                    // is still in flight, which is what stops a drag from
                    // fighting the value it just sent.
                    onVolChanged: level.report(row.vol.volume)
                    Component.onCompleted: level.report(row.vol.volume)

                    LiveSetting {
                        id: level
                        command: (v) => Audio.streamVolumeCommand(row.modelData.index, v)
                    }

                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26

                        IconImage {
                            anchors.fill: parent
                            visible: row.modelData.icon.length > 0
                            source: row.modelData.icon
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: row.modelData.icon.length === 0
                            text: "\u{F057E}"
                            color: Colors.alpha(Colors.text, 0.6)
                            font.pixelSize: Metrics.fontBody
                        }
                    }

                    // Fixed rather than fillWidth, so every app's track starts
                    // at the same x however long the names are.
                    Text {
                        Layout.preferredWidth: 115
                        text: row.modelData.name
                        color: Colors.text
                        font.pixelSize: Metrics.fontSecondary
                        elide: Text.ElideRight
                    }

                    W.IconButton {
                        glyph: row.vol.muted ? "\u{F075F}" : "\u{F057E}"
                        glyphColor: row.vol.muted
                            ? Colors.alpha(Colors.text, 0.5) : Colors.text
                        onClicked: Audio.setStreamMute(row.modelData.index, !row.vol.muted)
                    }

                    W.SliderTrack {
                        Layout.fillWidth: true
                        fraction: level.value / 100
                        onMoved: (f) => level.set(f * 100)
                        fillColor: row.vol.muted
                            ? Colors.alpha(Colors.text, 0.3) : Colors.accent
                    }

                    Text {
                        text: Math.round(level.value) + "%"
                        color: Colors.text
                        font.pixelSize: Metrics.fontSecondary
                        Layout.preferredWidth: 41
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            W.EmptyRow {
                visible: Audio.streams.length === 0
                text: "Nothing playing"
            }
        }

        // Output devices
        ColumnLayout {
            visible: pages.current === 0
            Layout.fillWidth: true
            spacing: Metrics.panelSectionListSpacing
            Repeater {
                model: Audio.sinks
                delegate: W.ListRow {
                    required property var modelData
                    glyph: modelData.name === Audio.defaultSink ? "\u{F012C}" : "\u{F0130}"
                    glyphColor: modelData.name === Audio.defaultSink
                        ? Colors.accent : Colors.alpha(Colors.text, 0.4)
                    label: modelData.description
                    labelColor: modelData.name === Audio.defaultSink ? Colors.accent : Colors.text
                    onClicked: Audio.setDefaultSink(modelData.name)
                }
            }
        }

        // Input devices
        ColumnLayout {
            visible: pages.current === 1
            Layout.fillWidth: true
            spacing: Metrics.panelSectionListSpacing
            Repeater {
                model: Audio.sources
                delegate: W.ListRow {
                    required property var modelData
                    glyph: modelData.name === Audio.defaultSource ? "\u{F012C}" : "\u{F0130}"
                    glyphColor: modelData.name === Audio.defaultSource
                        ? Colors.accent : Colors.alpha(Colors.text, 0.4)
                    label: modelData.description
                    labelColor: modelData.name === Audio.defaultSource ? Colors.accent : Colors.text
                    onClicked: Audio.setDefaultSource(modelData.name)
                }
            }
        }
    }
}
