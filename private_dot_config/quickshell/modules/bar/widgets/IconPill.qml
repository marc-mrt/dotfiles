import QtQuick
import "../../../config"

// Capsule-shaped bar widget background — noctalia gives each bar module a
// pill rather than a bare icon sitting directly on the bar surface. Hover
// gets a faint tint, `active` (e.g. popout open, radio powered on) gets an
// accent tint.
Rectangle {
    property bool active: false
    property bool hovered: false

    radius: height / 2
    color: active
        ? Colors.alpha(Colors.accent, 0.18)
        : hovered
            ? Colors.alpha(Colors.text, 0.08)
            : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }
}
