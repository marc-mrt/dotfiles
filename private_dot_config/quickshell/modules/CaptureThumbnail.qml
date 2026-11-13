import QtQuick
import QtQuick.Layouts
import Quickshell
import "../config"
import "../services"
import "./ui" as W

// Content only — window/positioning lives in shell.qml (captureThumbWin).
// The floating preview macOS leaves in the corner after a capture: the
// file is already saved and copied, this is just the shortcut to doing
// something with it. Gestures, like a notification card's, say what you
// meant: left click edits (satty) or plays, middle click opens the folder,
// right click or a fling to the right puts it away. It leaves by itself
// after 5s unless the pointer is resting on it.
Item {
    id: root
    implicitWidth: 240
    implicitHeight: card.implicitHeight

    readonly property string path: Capture.thumbnailPath
    readonly property string fileName: root.path.slice(root.path.lastIndexOf("/") + 1)
    readonly property string dir: root.path.slice(0, root.path.lastIndexOf("/"))

    function open() {
        if (Capture.thumbnailIsVideo)
            Quickshell.execDetached(["xdg-open", root.path])
        else
            Quickshell.execDetached(["sh", "-c",
                'command -v satty >/dev/null && exec satty --filename "$1" --output-filename "$1" --copy-command wl-copy; exec xdg-open "$1"',
                "sh", root.path])
        Capture.dismissThumbnail()
    }

    // Capture.showThumbnail blanks the path before setting it, so a new
    // capture flips `running` off and on and gets a fresh 5s.
    Timer {
        interval: 5000
        running: root.path !== "" && !ma.containsMouse
        onTriggered: Capture.dismissThumbnail()
    }

    W.Card {
        id: card
        width: root.width
        implicitHeight: content.implicitHeight + 12
        // Snaps back when a drag falls short of dismissing.
        Behavior on x { enabled: !ma.drag.active; NumberAnimation { duration: Metrics.durationNormal; easing.type: Metrics.easingStandard } }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6

            Image {
                visible: !Capture.thumbnailIsVideo
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 135 : 0
                source: visible && root.path !== "" ? "file://" + root.path : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                // A full-resolution screenshot decoded just to be shown
                // at thumbnail size would be wasted memory.
                sourceSize.width: 480
            }

            RowLayout {
                visible: Capture.thumbnailIsVideo
                Layout.fillWidth: true
                Layout.margins: 6
                spacing: 8
                Text {
                    text: "\u{F0231}"
                    color: Colors.text
                    font.pixelSize: Metrics.iconButtonGlyphSize
                }
                Text {
                    Layout.fillWidth: true
                    text: root.fileName
                    elide: Text.ElideMiddle
                    color: Colors.text
                    font.pixelSize: Metrics.fontSecondary
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        drag.target: card
        drag.axis: Drag.XAxis
        drag.minimumX: 0
        drag.maximumX: root.width
        // clicked still fires at the end of a drag, so remember there was one.
        property bool dragged: false
        onPressed: ma.dragged = false
        onPositionChanged: if (card.x > 4) ma.dragged = true
        onReleased: {
            if (card.x > root.width / 3)
                Capture.dismissThumbnail()
            card.x = 0
        }
        onClicked: (mouse) => {
            if (ma.dragged)
                return
            if (mouse.button === Qt.RightButton)
                Capture.dismissThumbnail()
            else if (mouse.button === Qt.MiddleButton) {
                Quickshell.execDetached(["xdg-open", root.dir])
                Capture.dismissThumbnail()
            } else
                root.open()
        }
    }
}
