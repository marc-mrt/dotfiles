import QtQuick
import "../../config"

// Small square icon button — a glyph on a hover-tinted rounded backing.
// The network and bluetooth rescan buttons were each hand-rolling this, and
// the calendar's month arrows were bare glyphs with a MouseArea stuck on and
// no hover feedback at all. Tint matches the list rows in those same panels
// (Colors.alpha(text, ...)), so every pressable thing in a panel highlights
// the same way rather than each picking its own.
Item {
    id: root

    property string glyph: ""
    // Dimmed by callers that use this as a toggle — a muted speaker reads
    // as off rather than merely as a different glyph.
    property color glyphColor: Colors.text
    property int glyphSize: Metrics.iconButtonGlyphSize
    property int size: Metrics.iconButtonSize
    signal clicked

    implicitWidth: root.size
    implicitHeight: root.size

    // First, so the hover binding below has an id to resolve against; the
    // Rectangle and Text that follow accept no mouse events, so clicks fall
    // straight through to here.
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: ma.containsMouse ? Colors.alpha(Colors.text, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: Metrics.durationFast } }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.glyphColor
        font.pixelSize: root.glyphSize
        scale: ma.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: Metrics.durationFast; easing.type: Metrics.easingStandard } }
    }
}
