import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../services"
import "../../ui" as W

// Tab content only — embedded inline under the power chip in the pad
// overview (see modules/pad/Overview.qml).
//
// Lock and suspend are recoverable, so they run on the first click. The
// other three end the session, so the first click arms the row as an action
// preview ("Click again to reboot", destructive red) and only a second
// click inside 3s runs it. Arming one row disarms any other: one pending
// confirmation at a time.
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

    // Name of the armed action, or "".
    property string armed: ""

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    function run(name, confirm) {
        if (confirm && root.armed !== name) {
            root.armed = name
            disarm.restart()
            return
        }
        disarm.stop()
        root.armed = ""
        Session[name]()
        PadState.close()
    }

    W.TabHeader { title: "Power" }

    W.Section {
        Repeater {
            model: [
                { name: "lock", glyph: "\u{F033E}", label: "Lock", confirm: false, verb: "lock" },
                { name: "suspend", glyph: "\u{F04B2}", label: "Suspend", confirm: false, verb: "suspend" },
                { name: "logout", glyph: "\u{F0343}", label: "Log out", confirm: true, verb: "log out" },
                { name: "reboot", glyph: "\u{F0709}", label: "Reboot", confirm: true, verb: "reboot" },
                { name: "poweroff", glyph: "\u{F0425}", label: "Power off", confirm: true, verb: "power off" }
            ]
            delegate: W.ListRow {
                id: row
                required property var modelData
                readonly property bool isArmed: root.armed === row.modelData.name

                glyph: row.modelData.glyph
                glyphColor: row.isArmed ? Colors.destructive : Colors.text
                label: row.modelData.label
                labelColor: row.isArmed ? Colors.destructive : Colors.text
                status: row.isArmed ? "Click again to " + row.modelData.verb : ""
                statusColor: Colors.destructive
                onClicked: root.run(row.modelData.name, row.modelData.confirm)
            }
        }
    }
}
