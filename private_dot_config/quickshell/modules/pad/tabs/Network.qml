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

    Component.onCompleted: {
        Network.refresh()
        pwPromptSsid = ""
    }

    W.TabHeader {
        title: "Wi-Fi"
        W.Toggle {
            checked: Network.wifiEnabled
            onToggled: Network.toggleWifi()
        }
    }

    // Visible networks, strongest first
    W.Section {
        visible: Network.wifiEnabled

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
                    status: entry.modelData.active ? "Connected"
                        : entry.modelData.secured ? "Secured" : "Open"
                    statusColor: entry.modelData.active
                        ? Colors.accent : Colors.alpha(Colors.text, 0.5)
                    // Same action preview as the bluetooth device rows —
                    // Disconnect in destructive red once hovering would
                    // drop the connection.
                    statusHover: entry.modelData.active ? "Disconnect" : "Connect"
                    statusHoverColor: entry.modelData.active
                        ? Colors.destructive : Colors.accent
                    onClicked: {
                        if (entry.modelData.active)
                            Network.disconnectFrom(entry.modelData.ssid)
                        else if (entry.modelData.secured)
                            root.pwPromptSsid = (root.pwPromptSsid === entry.modelData.ssid
                                ? "" : entry.modelData.ssid)
                        else
                            Network.connectTo(entry.modelData.ssid, "")
                    }

                    Text {
                        visible: entry.modelData.secured
                        text: "\u{F033E}"
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
}
