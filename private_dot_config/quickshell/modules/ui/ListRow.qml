import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../config"

// One row of a list inside a tab — a bluetooth device, a wi-fi network, an
// audio sink, a search result. There were seven hand-built copies of this
// (three of them inside bar/panels/Bluetooth.qml alone), which is how the
// hover tint ended up at 0.06 in tabs, 0.08 in search and 0.10 in
// IconButton, and how the search list ended up rendering the same kind of
// row label at 18px where every tab rendered it at 17.
//
// Label and status share a line, and wrap as a pair: the status sits right
// after the name ("Fairbuds  Connect"), and only drops to a second line
// when the two genuinely don't fit. This was stacked label-over-status at
// first, which overflowed the fixed 40px row — 17px label plus 15px status
// doesn't fit in 40 — and left the status jammed against the row below.
// The row is content-sized now, with 40 as a floor rather than a ceiling.
//
// ── the action preview ──────────────────────────────────────────────────
// `statusHover` is the row's most interesting property and the reason this
// is a module rather than a snippet. A row that is *about* to do something
// destructive says so before the click, not after: hovering a connected
// device swaps "Connected" for "Disconnect" in destructive red, so the row
// previews the consequence rather than only naming the current state. That
// treatment was invented in Bluetooth's device rows and hand-carried into
// Network's, with a comment there pointing back at the original — the
// clearest possible sign it wanted a name. Leave statusHover unset and the
// status simply doesn't change on hover.
Rectangle {
    id: root

    // Icon slot: a real icon when one resolves (search results), otherwise
    // a glyph. Never both, never neither — every row leads with something.
    property url iconSource: ""
    property string glyph: ""
    property color glyphColor: Colors.text

    property string label: ""

    property string status: ""
    property color statusColor: Colors.alpha(Colors.text, 0.5)
    // The action preview — see above. Empty means "this row's status says
    // the same thing whether or not you're pointing at it".
    property string statusHover: ""
    property color statusHoverColor: Colors.accent

    // Keyboard selection reads the same as hover on purpose: both mean
    // "this is the row a keypress or click would act on".
    property bool selected: false
    readonly property bool highlighted: root.selected || ma.containsMouse

    signal clicked

    // Trailing controls — a forget button, a lock glyph. Anything that has
    // its own MouseArea sits later in the tree than the row's own, so it
    // takes its clicks before the row does.
    default property alias trailing: trailingRow.data

    Layout.fillWidth: true
    implicitHeight: Math.max(40, textFlow.implicitHeight + 14)
    radius: 8
    color: root.highlighted ? Colors.alpha(Colors.text, 0.08) : "transparent"
    Behavior on color { ColorAnimation { duration: Metrics.durationFast } }

    // First, and accepting no events itself beyond hover/click: the Text
    // and IconImage that follow accept none, so clicks fall through to
    // here, while the trailing slot's own MouseAreas sit above it.
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Item {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            Layout.alignment: Qt.AlignVCenter

            IconImage {
                anchors.fill: parent
                visible: root.iconSource.toString().length > 0
                source: root.iconSource
            }
            Text {
                anchors.centerIn: parent
                visible: root.iconSource.toString().length === 0
                text: root.glyph
                color: root.glyphColor
                font.pixelSize: Metrics.fontBody
            }
        }

        // Flow, not a Layout: it puts the two texts side by side and
        // pushes the status onto its own line only when there isn't room,
        // which is exactly the wrap behaviour wanted here. Each text caps
        // its width at the flow's, so a pathologically long name elides
        // instead of running off the row.
        Flow {
            id: textFlow
            Layout.fillWidth: true
            Layout.preferredHeight: textFlow.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            Text {
                id: labelText
                width: Math.min(implicitWidth, textFlow.width)
                text: root.label
                color: Colors.text
                font.pixelSize: Metrics.fontBody
                elide: Text.ElideRight
            }
            Text {
                visible: root.status !== "" || root.statusHover !== ""
                width: Math.min(implicitWidth, textFlow.width)
                // Matched to the label's line box so the smaller status
                // text sits on its line rather than riding high against it.
                height: labelText.height
                verticalAlignment: Text.AlignVCenter
                text: (ma.containsMouse && root.statusHover !== "")
                    ? root.statusHover : root.status
                color: (ma.containsMouse && root.statusHover !== "")
                    ? root.statusHoverColor : root.statusColor
                font.pixelSize: Metrics.fontSecondary
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: Metrics.durationFast } }
            }
        }

        RowLayout {
            id: trailingRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 8
        }
    }
}
