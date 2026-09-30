import QtQuick
import QtQuick.Layouts
import "../../config"

// The title row at the top of a tab, plus whatever control belongs beside
// it (Network's wi-fi toggle, added as a plain child at the call site and
// laid out after the title). Five tabs each wrote out the same
// bold-17-with-a-2px-margin Text; this is that, named.
//
// Bluetooth's header deliberately doesn't use this — it carries a leading
// back button and switches its own title between two sub-views, which is
// genuinely different chrome rather than the same chrome with a different
// string. Calendar's is centered between two month arrows, likewise.
RowLayout {
    property string title: ""

    Layout.fillWidth: true
    Layout.bottomMargin: 2
    Layout.leftMargin: 2
    spacing: Metrics.panelHeaderSpacing

    Text {
        Layout.fillWidth: true
        text: title
        color: Colors.text
        font.pixelSize: Metrics.fontBody
        font.bold: true
    }
}
