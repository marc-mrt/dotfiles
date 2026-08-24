import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../widgets" as W

// Panel content only — embedded inline under the Bluetooth widget in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
ColumnLayout {
    id: root
    spacing: 10

    Component.onCompleted: Bluetooth.refresh()

    Text {
        text: "Bluetooth"
        color: Colors.text
        font.pixelSize: 15
        font.bold: true
        Layout.bottomMargin: 2
        Layout.leftMargin: 2
    }

    // Header: state + rescan + power toggle
    W.Section {
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: Bluetooth.powered ? "On" : "Off"
                color: Colors.text
                font.pixelSize: 13
            }
            W.IconButton {
                visible: Bluetooth.powered
                glyph: "\u{F0450}"
                glyphSize: 14
                onClicked: Bluetooth.refresh()
            }
            W.Toggle {
                checked: Bluetooth.powered
                onToggled: Bluetooth.togglePower()
            }
        }
    }

    // Known devices, connected first
    W.Section {
        visible: Bluetooth.powered
        spacing: 2

        Repeater {
            model: Bluetooth.devices
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 8
                color: rowMa.containsMouse
                    ? Colors.alpha(Colors.text, 0.06)
                    : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        text: modelData.connected ? "\u{F00B1}" : "\u{F00AF}"
                        color: modelData.connected ? Colors.accent : Colors.text
                        font.pixelSize: 15
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Colors.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: modelData.connected
                        text: "Connected"
                        color: Colors.accent
                        font.pixelSize: 11
                    }
                }
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modelData.connected
                        ? Bluetooth.disconnectFrom(modelData.mac)
                        : Bluetooth.connectTo(modelData.mac)
                }
            }
        }
        Text {
            visible: Bluetooth.devices.length === 0
            text: "No known devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: 12
        }
    }
}
