import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"
import "./ui" as W

// Content only — window/positioning lives in shell.qml (recordingWin).
// With no bar there is no menu-bar stop button like macOS has, so this
// pill is it: always on screen while a recording runs, and clicking it
// stops the recording.
W.Card {
    id: root
    radius: height / 2
    implicitWidth: row.implicitWidth + 24
    implicitHeight: row.implicitHeight + 12

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            implicitWidth: 10
            implicitHeight: 10
            radius: 5
            color: Colors.destructive
        }
        Text {
            text: Capture.elapsed
            color: Colors.text
            font.pixelSize: Metrics.fontSecondary
            font.features: { "tnum": 1 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Capture.stopRecording()
    }
}
