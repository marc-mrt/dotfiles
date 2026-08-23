import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../widgets" as W

// Panel content only — embedded inline under the Volume widget in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
ColumnLayout {
    id: root
    spacing: 10

    Component.onCompleted: Audio.refresh()

    Text {
        text: "Sound"
        color: Colors.text
        font.pixelSize: 15
        font.bold: true
        Layout.bottomMargin: 2
        Layout.leftMargin: 2
    }

    // Master slider — always drives @DEFAULT_AUDIO_SINK@, so it follows
    // whichever output device is currently selected as default.
    W.Section {
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: Audio.muted ? "\u{F075F}" : "\u{F057E}"
                color: Audio.muted ? Colors.alpha(Colors.text, 0.5) : Colors.text
                font.pixelSize: 20
                MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() }
            }

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Colors.base

                Rectangle {
                    width: parent.width * (Audio.volume / 100)
                    height: parent.height
                    radius: 4
                    color: Audio.muted
                        ? Colors.alpha(Colors.text, 0.3)
                        : Colors.accent
                }
                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: Colors.text
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(parent.width - width,
                        parent.width * (Audio.volume / 100) - width / 2))
                }
                MouseArea {
                    anchors.fill: parent
                    function apply(mx) {
                        Audio.setVolume((mx / width) * 100)
                    }
                    onPressed: (m) => apply(m.x)
                    onPositionChanged: (m) => { if (pressed) apply(m.x) }
                }
            }

            Text {
                text: Audio.volume + "%"
                color: Colors.text
                font.pixelSize: 12
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // Output devices
    W.Section {
        Text {
            text: "OUTPUT"
            color: Colors.alpha(Colors.text, 0.6)
            font.pixelSize: 10
            font.letterSpacing: 1
        }
        Repeater {
            model: Audio.sinks
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: ma.containsMouse
                    ? Colors.alpha(Colors.text, 0.06)
                    : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        text: modelData.name === Audio.defaultSink ? "\u{F012C}" : "\u{F0130}"
                        color: modelData.name === Audio.defaultSink
                            ? Colors.accent
                            : Colors.alpha(Colors.text, 0.4)
                        font.pixelSize: 14
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.description
                        color: Colors.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Audio.setDefaultSink(modelData.name)
                }
            }
        }
    }

    // Input devices
    W.Section {
        Text {
            text: "INPUT"
            color: Colors.alpha(Colors.text, 0.6)
            font.pixelSize: 10
            font.letterSpacing: 1
        }
        Repeater {
            model: Audio.sources
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 8
                color: sma.containsMouse
                    ? Colors.alpha(Colors.text, 0.06)
                    : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        text: modelData.name === Audio.defaultSource ? "\u{F012C}" : "\u{F0130}"
                        color: modelData.name === Audio.defaultSource
                            ? Colors.accent
                            : Colors.alpha(Colors.text, 0.4)
                        font.pixelSize: 14
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.description
                        color: Colors.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: sma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Audio.setDefaultSource(modelData.name)
                }
            }
        }
    }
}
