import QtQuick
import QtQuick.Effects
import "../../config"

// A vendored Lucide icon (see icons/ beside this file, ISC-licensed).
// Lucide strokes with `currentColor`, which Qt paints black, and
// MultiEffect colorization multiplies the source luminance by the
// color — black × anything stays black. So brightness:1 first turns
// the black strokes into a white alpha mask, and colorization then
// yields the mask × color. Dimming cannot ride on the color's alpha
// (colorization would blend toward the mask instead), so it goes
// through the effect's opacity.
Item {
    id: root

    property string name: ""
    property color color: Colors.text
    property int size: Metrics.fontBody

    implicitWidth: root.size
    implicitHeight: root.size

    // Empty name renders nothing and logs nothing — an unset icon is a
    // choice (ListRow's glyph fallback), not an error.
    visible: root.name !== ""

    Image {
        id: source

        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectFit
        smooth: true
        source: root.name !== ""
            ? Qt.resolvedUrl("icons/" + root.name + ".svg") : ""
        sourceSize.width: root.size
        sourceSize.height: root.size
    }

    MultiEffect {
        anchors.fill: source
        source: source
        brightness: 1
        colorization: 1
        colorizationColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 1)
        opacity: root.color.a
    }
}
