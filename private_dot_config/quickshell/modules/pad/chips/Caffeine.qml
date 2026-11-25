import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Keep-awake indicator — only present while the inhibitor is held; the
// switch lives in the Settings tab's quick toggles. Click still releases it.
W.StatusChip {
    visible: Caffeine.active
    icon: "coffee"
    onClicked: Caffeine.toggle()
}
