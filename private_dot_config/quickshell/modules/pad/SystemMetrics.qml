import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../services"
import "../bar/widgets" as W

// Panel content only — the inline tab behind the overview's three ring
// gauges (click any of them, see modules/pad/Overview.qml). One section per
// ring, in the same order, each leading with the same percentage its ring
// shows in the same escalating color (Colors.loadColor), so what you clicked
// and what you're now reading are visibly the same measurement.
//
// Rows the machine doesn't expose hide themselves rather than showing a
// confident 0 — services/SystemStats.qml leaves anything it couldn't read at
// 0, and which sensors exist genuinely varies (this box's iGPU reports
// neither fan nor power draw, its discrete card reports both).
ColumnLayout {
    id: root
    spacing: 10

    function formatKb(kb) {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + " GiB"
            : kb >= 1024 ? Math.round(kb / 1024) + " MiB"
            : Math.round(kb) + " KiB"
    }
    function formatBytes(b) {
        return root.formatKb(b / 1024)
    }

    // Section heading: name, the headline percentage, and a thin bar saying
    // the same thing again without needing digits parsed.
    component Header: ColumnLayout {
        property string title: ""
        property real percent: 0
        readonly property color tint: Colors.loadColor(percent)

        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: title
                color: Colors.text
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                text: Math.round(percent) + "%"
                color: tint
                font.pixelSize: 13
                font.bold: true
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            implicitHeight: 4
            radius: 2
            color: Colors.alpha(Colors.text, 0.12)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, percent / 100))
                height: parent.height
                radius: 2
                color: tint
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
    }

    // One label/value line. `visible` is left to each call site so a sensor
    // that isn't there drops out entirely, its gap included.
    component Row: RowLayout {
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.fillWidth: true
            text: label
            color: Colors.alpha(Colors.text, 0.55)
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        Text {
            text: value
            color: Colors.text
            font.pixelSize: 12
        }
    }

    W.Section {
        spacing: 3
        Header { title: "CPU"; percent: SystemStats.cpuPercent }
        Row {
            label: "Clock"
            value: Math.round(SystemStats.cpuFreqMhz) + " MHz"
            visible: SystemStats.cpuFreqMhz > 0
        }
        Row {
            label: "Temperature"
            value: SystemStats.cpuTempC.toFixed(1) + " °C"
            visible: SystemStats.cpuTempC > 0
        }
        Row {
            label: "Load (1/5/15m)"
            value: SystemStats.loadAvg
            visible: SystemStats.loadAvg !== ""
        }
    }

    W.Section {
        spacing: 3
        Header { title: "Memory"; percent: SystemStats.ramPercent }
        Row {
            label: "Used"
            value: root.formatKb(SystemStats.ramUsedKb) + " / " + root.formatKb(SystemStats.ramTotalKb)
            visible: SystemStats.ramTotalKb > 0
        }
        Row {
            label: "Available"
            value: root.formatKb(SystemStats.ramAvailableKb)
            visible: SystemStats.ramTotalKb > 0
        }
        Row {
            label: "Swap"
            value: SystemStats.swapUsedKb > 0
                ? root.formatKb(SystemStats.swapUsedKb) + " / " + root.formatKb(SystemStats.swapTotalKb)
                : "unused (" + root.formatKb(SystemStats.swapTotalKb) + ")"
            visible: SystemStats.swapTotalKb > 0
        }
    }

    W.Section {
        spacing: 3
        // The ring tracks VRAM, so that stays the headline here too; the
        // core's own busy figure is a row rather than a second competing
        // number in the heading.
        Header { title: "GPU"; percent: SystemStats.vramPercent }
        Row {
            label: "VRAM"
            value: root.formatBytes(SystemStats.vramUsedBytes)
                + " / " + root.formatBytes(SystemStats.vramTotalBytes)
            visible: SystemStats.vramTotalBytes > 0
        }
        Row {
            label: "Temperature"
            value: SystemStats.gpuTempC.toFixed(1) + " °C"
            visible: SystemStats.gpuTempC > 0
        }
        Row {
            label: "Power draw"
            value: SystemStats.gpuPowerW.toFixed(1) + " W"
            visible: SystemStats.gpuPowerW > 0
        }
        Row {
            label: "Fan speed"
            value: Math.round(SystemStats.gpuFanRpm) + " RPM"
            visible: SystemStats.gpuFanRpm > 0
        }
    }
}
