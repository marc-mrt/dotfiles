import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../../../config"
import "../widgets" as W

// Tray icons — pilled and hover-tooltipped to match every other overview
// widget (see W.IconPill usage in bar/components/Network.qml etc.), rather
// than bare icons floating with no feedback.
RowLayout {
    spacing: 4
    Repeater {
        model: SystemTray.items
        Item {
            id: trayItem
            required property var modelData
            // nm-applet's tray icon duplicates the pad's own Network widget
            // (bar/components/Network.qml) — hide it rather than showing
            // the same status twice.
            readonly property bool isNmApplet: (trayItem.modelData.id ?? "").toLowerCase().includes("nm-applet")

            visible: !trayItem.isNmApplet
            implicitWidth: 26
            implicitHeight: 26

            W.IconPill {
                anchors.fill: parent
                hovered: ma.containsMouse
            }

            IconImage {
                anchors.centerIn: parent
                source: trayItem.modelData.icon
                implicitSize: 16
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // Left activates the app itself (SNI's primary action —
                // typically show/raise); right opens the tray item's own
                // menu — custom-rendered (W.TrayMenu) to match the rest of
                // the pad rather than the OS/Qt menu theme.
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        trayItem.modelData.activate()
                    else if (trayItem.modelData.hasMenu)
                        trayMenu.visible = true
                    else
                        trayItem.modelData.display(null, 0, 0)
                }
            }

            W.ToolTip {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                show: ma.containsMouse
                text: trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id || ""
            }

            W.TrayMenu {
                id: trayMenu
                anchorItem: trayItem
                menu: trayItem.modelData.menu
            }
        }
    }
}
