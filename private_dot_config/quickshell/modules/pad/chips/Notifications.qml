import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// A DND indicator, present only while DND is on; the switch lives in the
// Settings tab's quick toggles. History lives at the bottom-right of the
// screen (modules/NotificationStack.qml), not behind this glyph.
W.StatusChip {
    visible: Notifications.dnd
    text: "\u{F009B}"
    onClicked: Notifications.toggleDnd()
}
