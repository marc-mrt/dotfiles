import QtQuick
import QtQuick.Layouts
import "../../config"

// Segmented control that switches between the pages inside one tab (see
// CONTEXT.md: a tab is the pad slot, a page is a body within it). Give it
// `model` (page titles); `current` is the selected index, starting at 0 and
// changed only by clicking a segment, so a tab that recreates its body
// reopens on the first page. It sits at the top of the Section that also
// holds its pages.
//
// Selected segment is a light-grey tint with accent text, inset in a faint
// track; the others stay subdued with no fill and gain a faint tint on hover.
Rectangle {
    id: root
    property var model: []
    property int current: 0

    // Keyboard cursor (modules/pad/Overview.qml): Left/Right step the page.
    property bool selected: false
    function nudge(delta) {
        root.current = Math.max(0, Math.min(root.model.length - 1, root.current + delta))
    }
    border.width: root.selected ? 1 : 0
    border.color: Colors.accent

    Layout.fillWidth: true
    implicitHeight: Metrics.fontSecondary + 12  // label plus 6px above and below
    radius: Metrics.radiusControl + 2  // segment radius plus the 2px inset, so corners stay concentric
    color: Colors.alpha(Colors.text, 0.05)

    Row {
        anchors.fill: parent
        anchors.margins: 2
        Repeater {
            model: root.model
            delegate: Rectangle {
                required property int index
                required property string modelData
                readonly property bool selected: index === root.current

                width: (root.width - 4) / root.model.length
                height: root.height - 4
                radius: Metrics.radiusControl
                color: Colors.alpha(Colors.text, selected ? 0.12 : (ma.containsMouse ? 0.07 : 0))
                Behavior on color { ColorAnimation { duration: Metrics.durationFast } }

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: selected ? Colors.accent : Colors.alpha(Colors.text, 0.7)
                    font.pixelSize: Metrics.fontSecondary
                    Behavior on color { ColorAnimation { duration: Metrics.durationFast } }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.current = index
                }
            }
        }
    }
}
