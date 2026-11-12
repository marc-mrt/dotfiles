import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../config"
import "../../services"

// One dot per workspace: accent for the active one, bright for one that
// holds windows, dim for an empty slot. Hyprland only keeps a workspace
// alive while it is occupied or active, so "exists in the list" is the
// occupied test. Shared by the pad footer and the workspace-switch OSD.
RowLayout {
    id: root
    spacing: 0

    // Emitted after a dot switched workspace, so the pad can close.
    signal picked

    Repeater {
        model: Math.max(4, ...Hyprland.workspaces.values.map(w => w.id))
        Item {
            id: dot
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === dot.wsId) ?? null
            readonly property bool active: !!dot.ws && dot.ws.active

            implicitWidth: 16
            implicitHeight: 16

            Rectangle {
                anchors.centerIn: parent
                width: dot.active ? 10 : 6
                height: width
                radius: width / 2
                color: dot.active ? Colors.accent
                    : Colors.alpha(Colors.text, dot.ws ? 0.65 : 0.2)
                Behavior on width { NumberAnimation { duration: Metrics.durationFast } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Hypr.focusWorkspace(dot.wsId)
                    root.picked()
                }
            }
        }
    }
}
