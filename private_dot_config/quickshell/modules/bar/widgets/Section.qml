import QtQuick
import QtQuick.Layouts
import "../../../config"

// Grouped sub-card inside a popout — noctalia/caelestia group related
// controls into distinct rounded cards with gaps between them, rather than
// one continuous GNOME-style quick-settings sheet.
Rectangle {
    default property alias content: inner.data
    property alias spacing: inner.spacing

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 16
    radius: 12
    color: Colors.alpha(Colors.base, 0.45)
    border.width: 1
    border.color: Colors.alpha(Colors.text, 0.06)

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6
    }
}
