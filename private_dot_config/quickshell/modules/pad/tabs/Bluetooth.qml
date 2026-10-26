import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../../ui" as W

// Tab content only — embedded inline under the Bluetooth chip in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
//
// Two pages (W.PageBar, shown while powered): "Devices" is glanceable
// status — known devices, tap to connect/disconnect — and "Pair" lists
// nearby unpaired devices, with the scan button in the header. Forgetting
// lives on the Devices rows as a trash button that only appears while the
// row is hovered, so the everyday view never shows a "forget" icon next to
// a device someone's actively using until they point at it.
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

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

    W.TabHeader {
        title: "Bluetooth"
        W.IconButton {
            visible: Bluetooth.powered && pages.current === 1
            glyph: "\u{F0450}"
            onClicked: Bluetooth.toggleScan()
        }
        W.Toggle {
            checked: Bluetooth.powered
            onToggled: Bluetooth.togglePower()
        }
    }

    W.Section {
        visible: Bluetooth.powered
        W.PageBar {
            id: pages
            model: ["Devices", "Pair"]
        }

        // Devices page — known devices, tap to connect/disconnect
        ColumnLayout {
            visible: pages.current === 0
            Layout.fillWidth: true
            spacing: Metrics.panelSectionListSpacing

            Repeater {
                model: Bluetooth.devices
                delegate: W.ListRow {
                    id: known
                    required property var modelData
                    visible: modelData.paired
                    glyph: modelData.connected ? "\u{F00B1}" : "\u{F00AF}"
                    glyphColor: modelData.connected ? Colors.accent : Colors.text
                    label: modelData.name
                    labelColor: modelData.connected ? Colors.accent : Colors.text
                    status: modelData.connected ? "" : "Not connected"
                    // Hovering previews the consequence of the click, in
                    // destructive red once it would drop a live connection.
                    statusHover: modelData.connected ? "Disconnect" : "Connect"
                    statusHoverColor: modelData.connected
                        ? Colors.destructive : Colors.accent
                    onClicked: modelData.connected
                        ? modelData.disconnect()
                        : modelData.connect()

                    // HoverHandler, not the row's MouseArea: that one stops
                    // reporting hover once the pointer is over the button, which
                    // would hide the button out from under it.
                    HoverHandler { id: rowHover }
                    W.IconButton {
                        // Faded, not hidden: collapsing it reflowed the row under the
                        // cursor. `enabled` reaches IconButton's MouseArea,
                        // so the invisible button takes no clicks.
                        readonly property bool shown: known.highlighted || rowHover.hovered
                        enabled: shown
                        opacity: shown ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Metrics.durationFast } }
                        glyph: "\u{F01B4}"
                        glyphColor: Colors.destructive
                        onClicked: root.forgetDevice(known.modelData)
                    }
                }
            }
            W.EmptyRow {
                visible: !root.hasKnown
                text: "No known devices"
            }
        }

        // Pair page — nearby unpaired devices
        ColumnLayout {
            visible: pages.current === 1
            Layout.fillWidth: true
            spacing: Metrics.panelSectionListSpacing

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
            W.EmptyRow {
                visible: !root.hasNearby
                text: Bluetooth.scanning ? "Searching…" : "No nearby devices"
            }
        }
    }
}
