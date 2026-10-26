import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// A DND toggle and nothing else — history lives at the bottom-right of the
// screen (modules/NotificationStack.qml), not behind this glyph. State shows
// in the glyph only: no `active`, so no accent pill.
W.StatusChip {
    text: Notifications.dnd ? "\u{F009B}" : "\u{F009A}"
    onClicked: Notifications.toggleDnd()
}
