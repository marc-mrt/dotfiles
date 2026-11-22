import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell.Widgets
import "../config"
import "../services"
import "./ui" as W

Item {
    id: root

    property int selectedIndex: -1
    readonly property var filteredGames: {
        const query = searchInput.text.trim().toLowerCase()
        if (query === "")
            return Lutris.games
        return Lutris.games.filter(game => game.name.toLowerCase().includes(query))
    }

    function revealSelection() {
        if (selectedIndex >= 0)
            grid.positionViewAtIndex(selectedIndex, GridView.Contain)
    }

    function select(index) {
        selectedIndex = index
        revealSelection()
    }

    function selectFirst() {
        select(filteredGames.length > 0 ? 0 : -1)
    }

    function moveSelection(delta) {
        if (grid.count === 0)
            return
        select(Math.max(0, Math.min(grid.count - 1, selectedIndex + delta)))
    }

    function launchSelected() {
        if (selectedIndex >= 0 && selectedIndex < filteredGames.length)
            Lutris.launch(filteredGames[selectedIndex].id)
    }

    onFilteredGamesChanged: selectFirst()

    // A real toplevel must close on focus loss, or it can cover the window
    // that now owns focus while continuing to swallow its clicks.
    property bool everActive: false
    readonly property bool windowActive: root.Window.active
    onWindowActiveChanged: {
        if (root.windowActive) {
            root.everActive = true
            if (Lutris.shown)
                searchInput.forceActiveFocus()
        } else if (root.everActive) {
            Lutris.close()
        }
    }

    Connections {
        target: Lutris
        function onShownChanged() {
            root.everActive = Lutris.shown && root.windowActive
            if (Lutris.shown) {
                searchInput.text = ""
                root.selectFirst()
                searchInput.forceActiveFocus()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.alpha(Colors.base, 0.76)
        MouseArea {
            anchors.fill: parent
            onClicked: Lutris.close()
        }
    }

    W.Card {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.64, 1240)
        height: Math.min(parent.height * 0.76, 860)
        radius: Metrics.radiusLarge

        MouseArea {
            anchors.fill: parent
            onClicked: mouse.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: Metrics.panelSpacing

            Text {
                text: "Library"
                color: Colors.text
                font.pixelSize: Metrics.fontBody
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: Metrics.radiusControl
                color: Colors.alpha(Colors.base, 0.65)
                border.width: searchInput.activeFocus ? 1 : 0
                border.color: Colors.accent

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colors.text
                    selectionColor: Colors.accent
                    selectedTextColor: Colors.base
                    font.pixelSize: Metrics.fontBody
                    clip: true
                    selectByMouse: true
                    focus: Lutris.shown
                    Keys.onEscapePressed: Lutris.close()
                    Keys.onLeftPressed: root.moveSelection(-1)
                    Keys.onRightPressed: root.moveSelection(1)
                    Keys.onUpPressed: root.moveSelection(-6)
                    Keys.onDownPressed: root.moveSelection(6)
                    Keys.onReturnPressed: root.launchSelected()
                    Keys.onEnterPressed: root.launchSelected()
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text === ""
                    text: "Filter games…"
                    color: Colors.alpha(Colors.text, 0.45)
                    font.pixelSize: Metrics.fontBody
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    visible: root.filteredGames.length > 0
                    model: root.filteredGames
                    cellWidth: Math.floor(width / 6)
                    cellHeight: cellWidth * 1.5 + 46
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onCountChanged: root.revealSelection()

                    delegate: Item {
                        id: tile
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight

                        ClippingRectangle {
                            id: plate
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 6
                            height: width * 1.5
                            radius: Metrics.radiusControl
                            color: Colors.alpha(Colors.base, 0.8)

                            Image {
                                id: artImage
                                anchors.fill: parent
                                source: tile.modelData.art ? tile.modelData.art.url : ""
                                asynchronous: true
                                fillMode: tile.modelData.art && tile.modelData.art.kind === "cover"
                                    ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                visible: tile.modelData.art && status !== Image.Error
                            }

                            Text {
                                anchors.fill: parent
                                anchors.margins: 12
                                visible: !tile.modelData.art || artImage.status !== Image.Ready
                                text: tile.modelData.name
                                color: Colors.alpha(Colors.text, 0.75)
                                font.pixelSize: Metrics.fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            anchors.fill: plate
                            radius: Metrics.radiusControl
                            color: "transparent"
                            border.width: tile.index === root.selectedIndex ? 3 : 1
                            border.color: tile.index === root.selectedIndex
                                ? Colors.accent : Colors.alpha(Colors.text, 0.12)
                        }

                        Text {
                            anchors.top: plate.bottom
                            anchors.topMargin: 4
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            height: 34
                            text: tile.modelData.name
                            color: tile.index === root.selectedIndex ? Colors.text : Colors.alpha(Colors.text, 0.75)
                            font.pixelSize: Metrics.fontSmall
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.select(tile.index)
                            onClicked: Lutris.launch(tile.modelData.id)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, 560)
                    visible: root.filteredGames.length === 0
                    text: Lutris.loading ? "Loading library…"
                        : Lutris.error !== "" ? Lutris.error
                        : Lutris.games.length === 0 ? "No installed Lutris games found."
                        : "No games match your search."
                    color: Lutris.error !== "" ? Colors.destructive : Colors.alpha(Colors.text, 0.6)
                    font.pixelSize: Metrics.fontBody
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.panelSpacing

                Text {
                    Layout.fillWidth: true
                    text: Lutris.error !== "" ? Lutris.error
                        : Lutris.loading ? "Refreshing library…"
                        : root.filteredGames.length + " games"
                    color: Lutris.error !== "" ? Colors.destructive : Colors.alpha(Colors.text, 0.5)
                    font.pixelSize: Metrics.fontSmall
                    elide: Text.ElideRight
                }
                Text {
                    text: "Arrows select · Enter/click launches · Esc closes"
                    color: Colors.alpha(Colors.text, 0.5)
                    font.pixelSize: Metrics.fontSmall
                }
            }
        }
    }
}
