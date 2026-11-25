import QtQuick
import "../../config"

// A pilled status chip in the overview's top-right row: it renders one
// piece of live system state as a Lucide icon, a text label or both, and,
// clicked, selects the tab that expands underneath
// (services/PanelState.qml's inlineOpen).
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
    // A vendored Lucide icon name — rendered instead of, or beside, the
    // text (see Icon.qml beside this file).
    property string icon: ""
    property int iconSize: Metrics.fontBody
    // A second vendored Lucide name drawn behind `icon` in the same slot,
    // at the same size and alignment — a dim full-strength shape that gives
    // a levelled glyph its context (the wifi signal levels read as cutouts
    // of one full wifi). Empty draws nothing.
    property string iconBack: ""
    property color iconBackColor: Colors.alpha(Colors.text, 0.25)
    property bool active: false
    // A toggle that is off but keeps its ink: dims the chip, no pill.
    property bool dimmed: false
    // Something wrong worth noticing (muted, offline): lifts the glyph to
    // full contrast like hover/active do, without adding a pill.
    property bool alert: false

    signal clicked
    signal middleClicked
    signal scrolled(int steps)

    // Idle glyphs recede so the row reads as quiet until something is
    // hovered, open or alerting; one color for icon and label alike.
    readonly property color inkColor: root.dimmed ? Colors.alpha(Colors.text, 0.4)
        : (root.active || root.alert || ma.containsMouse) ? Colors.text
        : Colors.alpha(Colors.text, 0.6)

    // Lucide SVGs share one canvas, so a chip's width no longer moves with
    // the glyph; the floor keeps icon-only chips constant while text chips
    // still size to their content.
    implicitWidth: Math.max(
        label.implicitWidth
            + (root.icon !== "" ? root.iconSize + row.spacing : 0),
        Metrics.fontBody) + 20
    implicitHeight: Metrics.chipHeight

    IconPill {
        anchors.centerIn: parent
        width: root.implicitWidth
        height: Math.round(root.implicitHeight * 0.74)
        active: root.active
        hovered: ma.containsMouse
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        // Row top-aligns its children, so a glyph beside a taller text
        // line box reads low; centring both keeps the flow horizontal.
        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            color: root.inkColor
            size: root.iconSize
            Behavior on color { ColorAnimation { duration: Metrics.durationFast } }

            // z: -1 puts it behind this Icon's own MultiEffect, so the
            // main glyph's strokes land on top of the dim shape.
            Icon {
                visible: root.iconBack !== ""
                z: -1
                name: root.iconBack
                color: root.iconBackColor
                size: root.iconSize
            }
        }

        Text {
            id: label
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.inkColor
            Behavior on color { ColorAnimation { duration: Metrics.durationFast } }
            font.pixelSize: Metrics.fontBody
        }
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
