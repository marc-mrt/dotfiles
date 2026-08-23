import QtQuick
import QtQuick.Controls
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
                // menu, native platform behavior rather than us
                // reconstructing it as a custom list.
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        trayItem.modelData.activate()
                    else if (trayItem.modelData.hasMenu)
                        menuAnchor.open()
                    else
                        trayItem.modelData.display(null, 0, 0)
                }
            }

            ToolTip.visible: ma.containsMouse
            ToolTip.delay: 400
            ToolTip.text: trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id || ""

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.rect.y: trayItem.height
            }
        }
    }
}
