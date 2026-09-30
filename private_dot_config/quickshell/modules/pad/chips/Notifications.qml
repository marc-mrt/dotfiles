import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// A DND toggle and nothing else — history lives at the bottom-right of the
// screen (modules/NotificationStack.qml), not behind this glyph. The only
// chip whose `active` isn't a tab selection.
W.StatusChip {
    text: Notifications.dnd ? "\u{F1F6}" : "\u{F0F3}"
    active: Notifications.dnd
    onClicked: Notifications.toggleDnd()
}
