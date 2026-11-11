import QtQuick
import QtQuick.Layouts
import "../../config"

// The "nothing here" line of a list — No known devices, No nearby devices,
// No saved networks. These were bare muted Texts, which sat flush against
// the list's left edge and at whatever height the font gave them, while
// the rows around them are 40px tall with content inset 8px.
// The 40 and 8 are ListRow's own (its implicitHeight floor and its
// RowLayout leftMargin); change them together.
Text {
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    leftPadding: 8
    verticalAlignment: Text.AlignVCenter
    color: Colors.alpha(Colors.text, 0.5)
    font.pixelSize: Metrics.fontSecondary
}
