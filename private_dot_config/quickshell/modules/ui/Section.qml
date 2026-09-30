import QtQuick
import QtQuick.Layouts
import "../../config"

// Grouped sub-card inside a tab — noctalia/caelestia group related
// controls into distinct rounded cards with gaps between them, rather than
// one continuous GNOME-style quick-settings sheet.
//
// The surface itself is Card's sunken variant; all this adds is the column
// the controls sit in. A sunken surface that *isn't* a plain column of
// controls (the overview's expansion slot, which holds a Flickable and an
// overlaid scroll track) uses Card directly instead of contorting to fit
// this shape.
Card {
    default property alias content: inner.data
    property alias spacing: inner.spacing

    sunken: true
    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 16

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: 8
        spacing: Metrics.panelSectionListSpacing
    }
}
