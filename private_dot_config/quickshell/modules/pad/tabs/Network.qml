import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../../ui" as W

// Tab content only — embedded inline under the Network chip in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

    // SSID of the network whose inline password prompt is open ("" = none).
    property string pwPromptSsid: ""
    // UUID of the saved network whose password row is open ("" = none).
    property string pskRowUuid: ""

    Component.onCompleted: Network.refresh()
    // The revealed password shouldn't outlive the tab that asked for it.
    Component.onDestruction: Network.revealed = ({ uuid: "", psk: "" })

    W.TabHeader {
        title: "Wi-Fi"
        W.Toggle {
            checked: Network.wifiEnabled
            onToggled: Network.toggleWifi()
        }
    }

    W.Section {
        visible: Network.wifiEnabled
        W.PageBar {
            id: pages
            model: ["Nearby", "Known"]
        }

        // Nearby — visible networks, strongest first
        ColumnLayout {
            visible: pages.current === 0
            Layout.fillWidth: true
            spacing: Metrics.panelSectionListSpacing

            Repeater {
                model: Network.networks
                delegate: ColumnLayout {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0

                    W.ListRow {
                        glyph: entry.modelData.signal >= 70 ? "\u{F0928}"
                            : entry.modelData.signal >= 45 ? "\u{F0925}"
                            : entry.modelData.signal >= 20 ? "\u{F0922}" : "\u{F092F}"
                        glyphColor: entry.modelData.active ? Colors.accent : Colors.text
                        label: entry.modelData.ssid
                        labelColor: entry.modelData.active ? Colors.accent : Colors.text
                        status: entry.modelData.active ? ""
                            : entry.modelData.secured ? "Secured" : "Open"
                        // Same action preview as the bluetooth device rows —
                        // Disconnect in destructive red once hovering would
                        // drop the connection.
                        statusHover: entry.modelData.active ? "Disconnect" : "Connect"
                        statusHoverColor: entry.modelData.active
                            ? Colors.destructive : Colors.accent
                        onClicked: {
                            if (entry.modelData.active)
                                Network.disconnectFrom(entry.modelData.ssid)
                            else if (entry.modelData.secured && Network.knownUuid(entry.modelData.ssid).length === 0)
                                root.pwPromptSsid = (root.pwPromptSsid === entry.modelData.ssid
                                    ? "" : entry.modelData.ssid)
                            else
                                Network.connectTo(entry.modelData.ssid, "")
                        }

                        Text {
                            visible: entry.modelData.secured
                            // lock-check when a saved profile holds the password
                            text: Network.knownUuid(entry.modelData.ssid).length > 0 ? "\u{F139A}" : "\u{F033E}"
                            color: Colors.alpha(Colors.text, 0.5)
                            font.pixelSize: Metrics.fontSecondary
                        }
                    }

                    // Inline password prompt for secured networks
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 30
                        Layout.rightMargin: 6
                        Layout.topMargin: 2
                        Layout.bottomMargin: 4
                        visible: root.pwPromptSsid === entry.modelData.ssid
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 8
                            color: Colors.base
                            TextInput {
                                id: pwInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.text
                                font.pixelSize: Metrics.fontBody
                                echoMode: TextInput.Password
                                clip: true
                                focus: root.pwPromptSsid === entry.modelData.ssid
                                onAccepted: {
                                    Network.connectTo(entry.modelData.ssid, text)
                                    root.pwPromptSsid = ""
                                    text = ""
                                }
                            }
                        }
                        Rectangle {
                            implicitWidth: 70
                            implicitHeight: 34
                            radius: 8
                            // Lightened rather than tinted: a faint overlay is
                            // invisible on an accent-filled button.
                            color: connectMa.containsMouse
                                ? Qt.lighter(Colors.accent, 1.2) : Colors.accent
                            Behavior on color { ColorAnimation { duration: Metrics.durationFast } }
                            Text {
                                anchors.centerIn: parent
                                text: "Connect"
                                color: Colors.base
                                font.pixelSize: Metrics.fontSecondary
                            }
                            MouseArea {
                                id: connectMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    Network.connectTo(entry.modelData.ssid, pwInput.text)
                                    root.pwPromptSsid = ""
                                    pwInput.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }

        // Known — saved networks in autoconnect priority order, top first.
        // Manage-only: connecting happens on Nearby (or by autoconnect), so a
        // row click does nothing.
        ColumnLayout {
            visible: pages.current === 1
            Layout.fillWidth: true
            spacing: Metrics.panelSectionListSpacing

            Repeater {
                model: Network.known
                delegate: ColumnLayout {
                    id: saved
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0

                    W.ListRow {
                        glyph: "\u{F0928}"
                        glyphColor: saved.modelData.active ? Colors.accent : Colors.text
                        label: saved.modelData.name
                        labelColor: saved.modelData.active ? Colors.accent : Colors.text
                        status: saved.modelData.active ? ""
                            : saved.modelData.autoconnect ? "Auto" : "Manual"

                        // Dimmed rather than hidden at the ends, so the
                        // controls stay in columns down the list.
                        W.IconButton {
                            glyph: "\u{F0143}"
                            enabled: saved.index > 0
                            opacity: enabled ? 1 : 0.3
                            onClicked: Network.move(saved.modelData.uuid, -1)
                        }
                        W.IconButton {
                            glyph: "\u{F0140}"
                            enabled: saved.index < Network.known.length - 1
                            opacity: enabled ? 1 : 0.3
                            onClicked: Network.move(saved.modelData.uuid, 1)
                        }
                        W.Toggle {
                            checked: saved.modelData.autoconnect
                            onToggled: Network.setAutoconnect(saved.modelData.uuid, !saved.modelData.autoconnect)
                        }
                        W.IconButton {
                            readonly property bool open: root.pskRowUuid === saved.modelData.uuid
                            glyph: open ? "\u{F0209}" : "\u{F0208}"
                            onClicked: {
                                if (!open)
                                    Network.revealPassword(saved.modelData.uuid)
                                root.pskRowUuid = open ? "" : saved.modelData.uuid
                            }
                        }
                        W.IconButton {
                            glyph: "\u{F01B4}"
                            glyphColor: Colors.destructive
                            onClicked: Network.forget(saved.modelData.uuid)
                        }
                    }

                    // Revealed password, editable; same look as Nearby's prompt
                    RowLayout {
                        id: pskRow
                        Layout.fillWidth: true
                        Layout.leftMargin: 30
                        Layout.rightMargin: 6
                        Layout.topMargin: 2
                        Layout.bottomMargin: 4
                        visible: root.pskRowUuid === saved.modelData.uuid
                        spacing: 6

                        function save() {
                            if (pskInput.text.length > 0)
                                Network.setPassword(saved.modelData.uuid, pskInput.text)
                            root.pskRowUuid = ""
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 8
                            color: Colors.base
                            TextInput {
                                id: pskInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.text
                                font.pixelSize: Metrics.fontBody
                                clip: true
                                focus: root.pskRowUuid === saved.modelData.uuid
                                text: Network.revealed.uuid === saved.modelData.uuid ? Network.revealed.psk : ""
                                onAccepted: pskRow.save()
                            }
                        }
                        Rectangle {
                            implicitWidth: 70
                            implicitHeight: 34
                            radius: 8
                            color: saveMa.containsMouse
                                ? Qt.lighter(Colors.accent, 1.2) : Colors.accent
                            Behavior on color { ColorAnimation { duration: Metrics.durationFast } }
                            Text {
                                anchors.centerIn: parent
                                text: "Save"
                                color: Colors.base
                                font.pixelSize: Metrics.fontSecondary
                            }
                            MouseArea {
                                id: saveMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: pskRow.save()
                            }
                        }
                    }
                }
            }
            W.EmptyRow {
                visible: Network.known.length === 0
                text: "No saved networks"
            }
        }
    }
}
