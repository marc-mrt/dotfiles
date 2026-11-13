pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"
import "./ui" as W

// Content only — window/positioning lives in shell.qml (captureToolbarWin),
// same split as OsdToast.qml. The macOS Cmd+Shift+5 bar: pick a mode, then
// Capture (or Enter). Picking a mode never captures on its own, so arrow
// keys can walk the row without firing anything. While a recording runs
// the whole row is just Stop, since starting a second one makes no sense.
FocusScope {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: row.implicitHeight + 16

    readonly property var modes: [
        { kind: "shot", target: "screen", glyph: "\u{F0379}", label: "Screen" },
        { kind: "shot", target: "window", glyph: "\u{F05AF}", label: "Window" },
        { kind: "shot", target: "area", glyph: "\u{F019F}", label: "Area" },
        { kind: "record", target: "screen", glyph: "\u{F0567}", label: "Record screen" },
        { kind: "record", target: "area", glyph: "\u{F044A}", label: "Record area" }
    ]
    readonly property int selected: root.modes.findIndex(m =>
        m.kind === Capture.kind && m.target === Capture.target)

    function select(i) {
        const m = root.modes[(i + root.modes.length) % root.modes.length]
        Capture.kind = m.kind
        Capture.target = m.target
    }

    focus: true
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape)
            Capture.toolbarShown = false
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            Capture.recording ? Capture.stopRecording() : Capture.capture()
        else if (event.key === Qt.Key_Left && !Capture.recording)
            root.select(root.selected - 1)
        else if (event.key === Qt.Key_Right && !Capture.recording)
            root.select(root.selected + 1)
        else
            return
        event.accepted = true
    }

    // Glyph over a caption, accent pill when selected — a toolbar mode or
    // action. IconButton has no caption or selected state, and those are
    // the whole point here.
    component ToolButton: Item {
        id: btn
        property string glyph: ""
        property string label: ""
        property bool selected: false
        property color tint: Colors.text
        signal clicked

        implicitWidth: Math.max(col.implicitWidth + 16, 64)
        implicitHeight: col.implicitHeight + 12

        W.IconPill {
            anchors.fill: parent
            radius: Metrics.radiusControl
            active: btn.selected
            hovered: ma.containsMouse
        }
        ColumnLayout {
            id: col
            anchors.centerIn: parent
            spacing: 2
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: btn.glyph !== ""
                text: btn.glyph
                color: btn.tint
                font.pixelSize: Metrics.iconButtonGlyphSize
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: btn.label
                color: btn.selected ? Colors.text : Colors.alpha(Colors.text, 0.7)
                font.pixelSize: Metrics.fontSmall
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }

    component ModeButton: ToolButton {
        id: mb
        required property int index
        property int offset: 0
        readonly property int mode: mb.index + mb.offset
        glyph: root.modes[mb.mode].glyph
        label: root.modes[mb.mode].label
        selected: mb.mode === root.selected
        onClicked: root.select(mb.mode)
    }

    component Divider: Rectangle {
        Layout.fillHeight: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        implicitWidth: 1
        color: Colors.alpha(Colors.text, 0.12)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        // Screenshots | recordings, as on macOS.
        Repeater {
            model: Capture.recording ? 0 : 3
            delegate: ModeButton {}
        }
        Divider { visible: !Capture.recording }
        Repeater {
            model: Capture.recording ? 0 : 2
            delegate: ModeButton { offset: 3 }
        }
        Divider { visible: !Capture.recording }
        ToolButton {
            visible: !Capture.recording
            glyph: "\u{F051B}"
            label: Capture.delay === 0 ? "No delay" : Capture.delay + "s delay"
            onClicked: Capture.cycleDelay()
        }
        ToolButton {
            visible: !Capture.recording
            label: "Capture"
            selected: true
            onClicked: Capture.capture()
        }
        ToolButton {
            visible: Capture.recording
            glyph: "\u{F04DB}"
            tint: Colors.destructive
            label: "Stop recording"
            onClicked: Capture.stopRecording()
        }
        W.IconButton {
            glyph: "\u{F0156}"
            onClicked: Capture.toolbarShown = false
        }
    }
}
