import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Keep-awake toggle — same steaming mug in both states: bright when the
// inhibitor is held, dimmed when not. No accent pill.
W.StatusChip {
    text: "\u{EF59}"
    dimmed: !Caffeine.active
    onClicked: Caffeine.toggle()
}
