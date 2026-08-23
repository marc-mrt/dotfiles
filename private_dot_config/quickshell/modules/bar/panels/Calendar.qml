import QtQuick
import QtQuick.Layouts
import "../../../config"

// Panel content only — month grid with today highlighted. Chrome (card
// background, radius, padding) lives in Pad.qml's card.
ColumnLayout {
    id: root
    spacing: 10

    readonly property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property var dayNames: ["M", "T", "W", "T", "F", "S", "S"]

    // Monday-first 6x7 grid of dates for the viewed month, padded with the
    // trailing/leading days of neighboring months so every week is full.
    function buildGrid() {
        const first = new Date(viewYear, viewMonth, 1)
        // getDay(): 0=Sun..6=Sat: shift so Monday=0.
        const leading = (first.getDay() + 6) % 7
        const start = new Date(viewYear, viewMonth, 1 - leading)
        const cells = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            cells.push(d)
        }
        return cells
    }
    property var grid: buildGrid()
    onViewYearChanged: grid = buildGrid()
    onViewMonthChanged: grid = buildGrid()

    function isToday(d) {
        return d.getFullYear() === today.getFullYear()
            && d.getMonth() === today.getMonth()
            && d.getDate() === today.getDate()
    }
    function isCurrentMonth(d) {
        return d.getMonth() === viewMonth
    }
    function shiftMonth(delta) {
        let m = viewMonth + delta
        let y = viewYear
        if (m < 0) { m = 11; y -= 1 }
        else if (m > 11) { m = 0; y += 1 }
        viewMonth = m
        viewYear = y
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "\u{F0141}"
            color: Colors.text
            font.pixelSize: 18
            MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(-1) }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
            color: Colors.text
            font.pixelSize: 15
            font.bold: true
        }
        Text {
            text: "\u{F0142}"
            color: Colors.text
            font.pixelSize: 18
            MouseArea { anchors.fill: parent; onClicked: root.shiftMonth(1) }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 4
        columnSpacing: 4

        Repeater {
            model: root.dayNames
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Colors.alpha(Colors.text, 0.5)
                font.pixelSize: 11
            }
        }

        Repeater {
            model: root.grid
            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                radius: 13
                color: root.isToday(modelData) ? Colors.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData.getDate()
                    font.pixelSize: 13
                    color: root.isToday(modelData)
                        ? Colors.base
                        : root.isCurrentMonth(modelData)
                            ? Colors.text
                            : Colors.alpha(Colors.text, 0.3)
                }
            }
        }
    }
}
