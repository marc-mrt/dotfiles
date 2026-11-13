import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../../config"
import "../../../services"
import "../../ui" as W

// Tab content only — embedded inline under the Media chip in the pad
// overview (see modules/pad/Overview.qml).
//
// Shows one player at a time. The playing one wins by default; a PageBar
// appears only when several exist, and `picked` (a manual choice) overrides
// the default until that player goes away.
ColumnLayout {
    id: root
    spacing: Metrics.panelSpacing

    readonly property var players: Mpris.players.values
    property int picked: -1
    readonly property int index: {
        if (root.picked >= 0 && root.picked < root.players.length)
            return root.picked
        const playing = root.players.findIndex(p => p.isPlaying)
        return playing >= 0 ? playing : 0
    }
    readonly property var player: root.players.length > 0 ? root.players[root.index] : null

    // position only ticks on request; poll while the tab is open and the
    // player is playing, rather than binding it (it isn't notifiable).
    Timer {
        interval: 1000
        running: root.player !== null && root.player.isPlaying
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    W.TabHeader { title: "Media" }

    W.Section {
        W.PageBar {
            visible: root.players.length > 1
            model: root.players.map(p => p.identity)
            current: root.index
            onCurrentChanged: root.picked = current
        }

        W.EmptyRow {
            visible: root.player === null
            text: "Nothing playing"
        }

        RowLayout {
            visible: root.player !== null
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                radius: Metrics.radiusControl
                color: Colors.base
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    sourceSize: Qt.size(144, 144)  // 2x the 72px box for HiDPI
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.player ? root.player.trackTitle : ""
                    color: Colors.text
                    font.pixelSize: Metrics.fontBody
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.player ? root.player.trackArtist : ""
                    color: Colors.alpha(Colors.text, 0.6)
                    font.pixelSize: Metrics.fontSecondary
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            visible: root.player !== null
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            W.IconButton {
                glyph: "\u{F04AE}"
                onClicked: root.player.previous()
            }
            W.IconButton {
                glyph: root.player && root.player.isPlaying ? "\u{F03E4}" : "\u{F040A}"
                onClicked: root.player.togglePlaying()
            }
            W.IconButton {
                glyph: "\u{F04AD}"
                onClicked: root.player.next()
            }
        }

        // Read-only when the player can't seek: the bar still shows
        // progress, it just doesn't answer drags.
        W.SliderTrack {
            visible: root.player !== null
            Layout.fillWidth: true
            enabled: root.player !== null && root.player.canSeek
            fraction: root.player && root.player.length > 0
                ? root.player.position / root.player.length : 0
            onMoved: (f) => { root.player.position = f * root.player.length }
        }
    }
}
