import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../../ui" as W

// Tab content only — embedded inline under the Bluetooth chip in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
//
// Two sub-views sharing one tab: "primary" is glanceable status —
// connected/known devices, tap to connect/disconnect, power toggle. The gear
// switches to "manage" — forgetting known devices and pairing new ones —
// so the everyday view never has to show a "forget" trash icon next to a
// device someone's actively using.
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

    // Resets to primary each time the tab is reloaded (Loader in
    // Overview.qml recreates this component on open), same as
    // Network.qml's pwPromptSsid reset.
    property bool managing: false

    readonly property bool hasKnown: Bluetooth.devices
        && Bluetooth.devices.values.some(d => d.paired)
    readonly property bool hasNearby: Bluetooth.devices
        && Bluetooth.devices.values.some(d => !d.paired)

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

    // Not a W.TabHeader: this one carries a leading back button and swaps
    // its own title between the two sub-views.
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        Layout.leftMargin: 2
        spacing: Metrics.panelHeaderSpacing

        W.IconButton {
            visible: root.managing
            glyph: "\u{F0141}"
            onClicked: root.managing = false
        }
        Text {
            Layout.fillWidth: true
            text: root.managing ? "Manage Devices" : "Bluetooth"
            color: Colors.text
            font.pixelSize: Metrics.fontBody
            font.bold: true
        }
        W.IconButton {
            visible: root.managing && Bluetooth.powered
            glyph: "\u{F0450}"
            onClicked: Bluetooth.toggleScan()
        }
        W.IconButton {
            visible: !root.managing && Bluetooth.powered
            glyph: "\u{F0493}"
            onClicked: root.managing = true
        }
        W.Toggle {
            checked: Bluetooth.powered
            onToggled: Bluetooth.togglePower()
        }
    }

    // Primary view — known devices, tap to connect/disconnect
    W.Section {
        visible: !root.managing && Bluetooth.powered

        Repeater {
            model: Bluetooth.devices
            delegate: W.ListRow {
                required property var modelData
                visible: modelData.paired
                glyph: modelData.connected ? "\u{F00B1}" : "\u{F00AF}"
                glyphColor: modelData.connected ? Colors.accent : Colors.text
                label: modelData.name
                status: modelData.connected ? "Connected" : "Not connected"
                statusColor: modelData.connected
                    ? Colors.accent : Colors.alpha(Colors.text, 0.5)
                // Hovering previews the consequence of the click, in
                // destructive red once it would drop a live connection.
                statusHover: modelData.connected ? "Disconnect" : "Connect"
                statusHoverColor: modelData.connected
                    ? Colors.destructive : Colors.accent
                onClicked: modelData.connected
                    ? modelData.disconnect()
                    : modelData.connect()
            }
        }
        Text {
            visible: !root.hasKnown
            text: "No known devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: Metrics.fontSecondary
        }
    }

    // Manage view — forget known devices; pair nearby ones
    W.Section {
        visible: root.managing && Bluetooth.powered

        W.SectionLabel { text: "KNOWN DEVICES" }
        Repeater {
            model: Bluetooth.devices
            delegate: W.ListRow {
                required property var modelData
                visible: modelData.paired
                glyph: modelData.connected ? "\u{F00B1}" : "\u{F00AF}"
                glyphColor: modelData.connected ? Colors.accent : Colors.text
                label: modelData.name
                status: modelData.connected ? "Connected" : ""
                statusColor: Colors.accent

                W.IconButton {
                    glyph: "\u{F01B4}"
                    onClicked: root.forgetDevice(modelData)
                }
            }
        }
        Text {
            visible: !root.hasKnown
            text: "No known devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: Metrics.fontSecondary
        }

        W.SectionLabel {
            text: "NEARBY DEVICES"
            Layout.topMargin: 6
        }
        Repeater {
            model: Bluetooth.devices
            delegate: W.ListRow {
                id: nearby
                required property var modelData
                visible: !modelData.paired
                glyph: "\u{F00AF}"
                label: modelData.name
                status: modelData.pairing ? "Pairing…" : "Pair"
                onClicked: modelData.pair()

                // Sits in the trailing slot only because that is where a
                // ListRow's extra children go; it draws nothing. Once a
                // fresh pair succeeds, trust the device (so it reconnects
                // on its own later) and connect right away.
                Connections {
                    target: nearby.modelData
                    function onPairedChanged() {
                        if (nearby.modelData.paired) {
                            nearby.modelData.trusted = true
                            nearby.modelData.connect()
                        }
                    }
                }
            }
        }
        Text {
            visible: !root.hasNearby
            text: Bluetooth.scanning ? "Searching…" : "No nearby devices"
            color: Colors.alpha(Colors.text, 0.5)
            font.pixelSize: Metrics.fontSecondary
        }
    }
}
