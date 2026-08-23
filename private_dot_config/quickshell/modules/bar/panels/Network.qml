import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../widgets" as W

// Panel content only — embedded inline under the Network widget in the pad
// overview (see modules/pad/Overview.qml), chrome lives in its wrapper.
ColumnLayout {
    id: root
    spacing: 10

    // SSID of the network whose inline password prompt is open ("" = none).
    property string pwPromptSsid: ""

    Component.onCompleted: {
        Network.refresh()
        pwPromptSsid = ""
    }

    Text {
        text: "Wi-Fi"
        color: Colors.text
        font.pixelSize: 15
        font.bold: true
        Layout.bottomMargin: 2
        Layout.leftMargin: 2
    }

    // Header: state + rescan + radio toggle
    W.Section {
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: !Network.wifiEnabled ? "Wi-Fi off"
                    : Network.connected ? Network.activeSsid : "Not connected"
                color: Colors.text
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 8
                visible: Network.wifiEnabled
                color: rescanMa.containsMouse ? Colors.base : "transparent"
                Text { anchors.centerIn: parent; text: "\u{F0450}"; color: Colors.text; font.pixelSize: 14 }
                MouseArea {
                    id: rescanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Network.refresh()
                }
            }

            W.Toggle {
                checked: Network.wifiEnabled
                onToggled: Network.toggleWifi()
            }
        }
    }

    // Visible networks, strongest first
    W.Section {
        visible: Network.wifiEnabled
        spacing: 2

        Repeater {
            model: Network.networks
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
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
                            text: modelData.signal >= 70 ? "\u{F0928}"
                                : modelData.signal >= 45 ? "\u{F0925}"
                                : modelData.signal >= 20 ? "\u{F0922}" : "\u{F092F}"
                            color: modelData.active ? Colors.accent : Colors.text
                            font.pixelSize: 15
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: modelData.ssid
                                color: Colors.text
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.active ? "Connected"
                                    : modelData.secured ? "Secured" : "Open"
                                color: modelData.active ? Colors.accent
                                    : Colors.alpha(Colors.text, 0.5)
                                font.pixelSize: 11
                            }
                        }
                        Text {
                            visible: modelData.secured
                            text: "\u{F033E}"
                            color: Colors.alpha(Colors.text, 0.5)
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.active)
                                Network.disconnectFrom(modelData.ssid)
                            else if (modelData.secured)
                                root.pwPromptSsid = (root.pwPromptSsid === modelData.ssid ? "" : modelData.ssid)
                            else
                                Network.connectTo(modelData.ssid, "")
                        }
                    }
                }

                // Inline password prompt for secured networks
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 30
                    Layout.rightMargin: 6
                    Layout.topMargin: 2
                    Layout.bottomMargin: 4
                    visible: root.pwPromptSsid === modelData.ssid
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 8
                        color: Colors.base
                        TextInput {
                            id: pwInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.text
                            font.pixelSize: 13
                            echoMode: TextInput.Password
                            clip: true
                            focus: root.pwPromptSsid === modelData.ssid
                            onAccepted: {
                                Network.connectTo(modelData.ssid, text)
                                root.pwPromptSsid = ""
                                text = ""
                            }
                        }
                    }
                    Rectangle {
                        implicitWidth: 58
                        implicitHeight: 28
                        radius: 8
                        color: Colors.accent
                        Text { anchors.centerIn: parent; text: "Connect"; color: Colors.base; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Network.connectTo(modelData.ssid, pwInput.text)
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
