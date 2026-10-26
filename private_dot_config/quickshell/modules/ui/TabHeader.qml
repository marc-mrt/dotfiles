import QtQuick
import QtQuick.Layouts
import "../../config"

// The title row at the top of a tab, plus whatever control belongs beside
// it (Network's wi-fi toggle, added as a plain child at the call site and
// laid out after the title). Five tabs each wrote out the same
// bold-17-with-a-2px-margin Text; this is that, named.
//
// Calendar's header is the one exception — it is centered between two month
// arrows, which is different chrome rather than a different string.
RowLayout {
    property string title: ""

    Layout.fillWidth: true
    Layout.bottomMargin: 2
    Layout.leftMargin: 2
    // Same height as a header carrying an IconButton (Bluetooth's scan),
    // so the title-to-section gap matches across tabs.
    Layout.minimumHeight: Metrics.iconButtonSize
    spacing: Metrics.panelHeaderSpacing

    Text {
        Layout.fillWidth: true
        text: title
        color: Colors.text
        font.pixelSize: Metrics.fontBody
        font.bold: true
    }
}
