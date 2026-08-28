import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../widgets" as W

// Panel content only — embedded inline under the Bluetooth widget in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
//
// Two sub-views sharing one panel: "primary" is glanceable status —
// connected/known devices, tap to connect/disconnect, power toggle. The gear
// switches to "manage" — forgetting known devices and pairing new ones —
// so the everyday view never has to show a "forget" trash icon next to a
// device someone's actively using.
ColumnLayout {
    id: root
    spacing: 10

    // Resets to primary each time the panel is reloaded (Loader in
    // Overview.qml recreates this component on open), same as
    // Network.qml's pwPromptSsid reset.
    property bool managing: false

    // Device currently mid-disconnect on the way to being forgotten.
    // forget() only fires once BlueZ confirms the link actually dropped, so
    // a connected device isn't yanked out from under an active session —
    // just removed as soon as it's safe to.
    property var pendingForget: null
    Connections {
        target: root.pendingForget
        ignoreUnknownSignals: true
        function onConnectedChanged() {
            if (root.pendingForget && !root.pendingForget.connected) {
                root.pendingForget.forget()
                root.pendingForget = null
            }
        }
    }
    function forgetDevice(device) {
        if (device.connected) {
            root.pendingForget = device
            device.disconnect()
        } else {
            device.forget()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        Layout.leftMargin: 2
        spacing: 4

        W.IconButton {
            visible: root.managing
            glyph: "\u{F0141}"
            glyphSize: 14
            size: 22
            onClicked: root.managing = false
        }
        Text {
            Layout.fillWidth: true
            text: root.managing ? "Manage Devices" : "Bluetooth"
            color: Colors.text
            font.pixelSize: 15
            font.bold: true
        }
        W.IconButton {
            visible: root.managing && Bluetooth.powered
            glyph: "\u{F0450}"
            glyphSize: 14
            size: 22
            onClicked: Bluetooth.toggleScan()
        }
        W.IconButton {
            visible: !root.managing && Bluetooth.powered
            glyph: "\u{F0493}"
            glyphSize: 14
            size: 22
            onClicked: root.managing = true
        }
        W.Toggle {
            checked: Bluetooth.powered
            onToggled: Bluetooth.togglePower()
        }
    }

    // Primary view — known devices, connected first, tap to connect/disconnect
    W.Section {
        visible: !root.managing && Bluetooth.powered
        spacing: 2

        Repeater {
            model: Bluetooth.devices
            delegate: Rectangle {
                required property var modelData
                visible: modelData.paired
                Layout.fillWidth: true
                implicitHeight: visible ? 36 : 0
                radius: 8
                color: rowMa.containsMouse
                    ? Colors.alpha(Colors.text, 0.06)
                    : "transparent"

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modelData.connected
                        ? modelData.disconnect()
                        : modelData.connect()
                }

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
                        text: modelData.connected ? "Connected" : "Not connected"
                        color: modelData.connected ? Colors.accent : Colors.alpha(Colors.text, 0.5)
                        font.pixelSize: 11
                    }
                }
            }
        }
        Text {
            visible: !Bluetooth.devices || !Bluetooth.devices.values.some(d => d.paired)
            text: "No known devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: 12
        }
    }

    // Manage view — forget known devices; pair nearby ones
    W.Section {
        visible: root.managing && Bluetooth.powered
        spacing: 2

        Text {
            text: "Known devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: 11
            Layout.leftMargin: 4
        }
        Repeater {
            model: Bluetooth.devices
            delegate: Rectangle {
                required property var modelData
                visible: modelData.paired
                Layout.fillWidth: true
                implicitHeight: visible ? 36 : 0
                radius: 8
                color: knownMa.containsMouse
                    ? Colors.alpha(Colors.text, 0.06)
                    : "transparent"

                MouseArea {
                    id: knownMa
                    anchors.fill: parent
                    hoverEnabled: true
                }

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
                    W.IconButton {
                        glyph: "\u{F01B4}"
                        glyphSize: 14
                        size: 22
                        onClicked: root.forgetDevice(modelData)
                    }
                }
            }
        }
        Text {
            visible: !Bluetooth.devices || !Bluetooth.devices.values.some(d => d.paired)
            text: "No known devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: 12
        }

        Text {
            text: "Nearby devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: 11
            Layout.leftMargin: 4
            Layout.topMargin: 6
        }
        Repeater {
            model: Bluetooth.devices
            delegate: Rectangle {
                required property var modelData
                visible: !modelData.paired
                Layout.fillWidth: true
                implicitHeight: visible ? 36 : 0
                radius: 8
                color: nearbyMa.containsMouse
                    ? Colors.alpha(Colors.text, 0.06)
                    : "transparent"

                // Once a fresh pair succeeds, trust the device (so it
                // reconnects on its own later) and connect right away.
                Connections {
                    target: modelData
                    function onPairedChanged() {
                        if (modelData.paired) {
                            modelData.trusted = true
                            modelData.connect()
                        }
                    }
                }

                MouseArea {
                    id: nearbyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modelData.pair()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8
                    Text {
                        text: "\u{F00AF}"
                        color: Colors.text
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
                        text: modelData.pairing ? "Pairing…" : "Pair"
                        color: Colors.alpha(Colors.text, 0.5)
                        font.pixelSize: 11
                    }
                }
            }
        }
        Text {
            visible: !Bluetooth.devices || !Bluetooth.devices.values.some(d => !d.paired)
            text: Bluetooth.scanning ? "Searching…" : "No nearby devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: 12
        }
    }
}
