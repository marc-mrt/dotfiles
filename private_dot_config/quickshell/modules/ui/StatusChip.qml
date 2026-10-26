import QtQuick
import "../../config"

// A pilled status glyph in the overview's top-right row: it renders one
// piece of live system state and, clicked, selects the tab that expands
// underneath (services/PanelState.qml's inlineOpen).
//
// Seven files carried this same Item/IconPill/Text/MouseArea skeleton,
// each writing `icon.implicitWidth + 20` twice, `implicitHeight * 0.74`
// once and a bare `17` once. Two consequences worth recording: Clock.qml
// sat there dead — its own comment said so — while still needing those
// numbers kept in step by hand, and Tray.qml, which wanted a slightly
// different chip, gave up and hand-rolled a fourth variant instead.
//
// The three interactions are separate signals rather than one handler that
// inspects the mouse, because they mean unrelated things: a click picks a
// tab, a middle-click mutes, a scroll nudges a value.
Item {
    id: root

    property string text: ""
    property bool active: false
    // A toggle that is off but keeps its glyph: dims the label, no pill.
    property bool dimmed: false
    // For an on/off glyph pair sharing a base shape but not ink width: centring the advance pins the shared shape so only the overflow (e.g. a slash) changes.
    property bool centreOnAdvance: false

    signal clicked
    signal middleClicked
    signal scrolled(int steps)

    // Nerd Font glyphs share an advance width but their ink boxes differ, so
    // label.implicitWidth would move with each icon swap and shift the row.
    // Floor at the font size so icon-only chips stay constant; text chips
    // are wider than that and still size to their content.
    // ponytail: an icon wider than fontBody would still shift the row; raise the floor or measure per glyph if one appears.
    implicitWidth: Math.max(label.implicitWidth, Metrics.fontBody) + 20
    implicitHeight: Metrics.chipHeight

    IconPill {
        anchors.centerIn: parent
        width: root.implicitWidth
        height: Math.round(root.implicitHeight * 0.74)
        active: root.active
        hovered: ma.containsMouse
    }

    // Advance width of the current glyph, used only by centreOnAdvance.
    TextMetrics {
        id: ink
        font: label.font
        text: root.text
    }

    Text {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.centreOnAdvance ? (label.implicitWidth - ink.advanceWidth) / 2 : 0
        text: root.text
        color: root.dimmed ? Colors.alpha(Colors.text, 0.4) : Colors.text
        font.pixelSize: Metrics.fontBody
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton)
                root.middleClicked()
            else
                root.clicked()
        }
        onWheel: (wheel) => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
