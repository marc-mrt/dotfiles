import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import "../config"
import "../services"
import "./ui" as W

// SUPER+Tab window switcher — open windows grouped by workspace, laid out
// side-by-side left-to-right, each window shown as a live-position
// screencopy snapshot with its title captioned in a bottom footer. All
// selection/cycling state lives in SwitcherState; this is display plus the
// key/focus handling it doesn't already cover.
//
// Interaction: SUPER+Tab (see shell.qml/SwitcherState.cycle()) only moves
// the highlight — holding SUPER and tapping Tab repeatedly just walks it
// along. Releasing SUPER is what commits: this window already holds real
// Wayland keyboard focus while shown (same as modules/Pad.qml), so the
// bare modifier key's release lands here like any other key event even
// though nothing was bound to it directly.
Item {
    id: root

    // modelData throughout this file is a raw `hyprctl clients -j` object
    // (see services/SwitcherState.qml) — class/title/address/at/size are
    // all top-level fields, no lastIpcObject indirection needed. Icon
    // lookup and the address/handle dance both live in services/Hypr.qml.

    // Bounding box of a workspace's windows, in compositor pixels — stands
    // in for the monitor's usable area without needing real monitor
    // geometry. Ponytail: works because a tiled workspace's windows
    // already span it; floating layouts with lots of empty space around
    // them would preview mis-scaled.
    function windowBounds(windows) {
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
        for (const c of windows) {
            const at = c.at || [0, 0]
            const sz = c.size || [0, 0]
            minX = Math.min(minX, at[0])
            minY = Math.min(minY, at[1])
            maxX = Math.max(maxX, at[0] + sz[0])
            maxY = Math.max(maxY, at[1] + sz[1])
        }
        if (!isFinite(minX))
            return { minX: 0, minY: 0, w: 1, h: 1 }
        return { minX: minX, minY: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) }
    }

    // Close (no side effect — navigating never moved real focus) as soon
    // as the compositor gives focus to anything else, e.g. clicking a
    // window that isn't covered by this overlay. Same trick and same
    // reason as modules/Pad.qml's everActive guard.
    property bool everActive: false
    readonly property bool windowActive: root.Window.active
    onWindowActiveChanged: {
        if (root.windowActive)
            root.everActive = true
        else if (root.everActive)
            SwitcherState.cancel()
    }

    // Click on empty space (outside every tile): cancel, same as Escape.
    MouseArea {
        anchors.fill: parent
        onClicked: SwitcherState.cancel()
    }

    // Always focused while shown. SUPER+Tab itself never reaches here —
    // Hyprland's bind consumes Tab globally and drives
    // SwitcherState.cycle() via the IPC call in shell.qml — but the bare
    // SUPER key isn't bound to anything, so its release is delivered here
    // like any other key and is what actually commits the selection.
    TextInput {
        id: keyCatcher
        visible: false
        focus: SwitcherState.shown
        Keys.onEscapePressed: SwitcherState.cancel()
        Keys.onReturnPressed: SwitcherState.commit()
        Keys.onEnterPressed: SwitcherState.commit()
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) {
                SwitcherState.commit()
                event.accepted = true
            }
        }
    }

    // Single outer card for the whole switcher — workspaces are delimited
    // by plain gap (contentRow's spacing), not separate bordered boxes.
    W.Card {
        id: board
        anchors.top: parent.top
        anchors.topMargin: parent.height * Metrics.switcherTopFraction
        anchors.horizontalCenter: parent.horizontalCenter
        width: contentRow.implicitWidth + Metrics.switcherPadding * 2
        height: contentRow.implicitHeight + Metrics.switcherPadding * 2
        radius: Metrics.switcherRadius

        Row {
            id: contentRow
            x: Metrics.switcherPadding
            y: Metrics.switcherPadding
            spacing: Metrics.switcherGroupSpacing

            Repeater {
                model: SwitcherState.groups
                delegate: Column {
                    id: group
                    required property var modelData
                    readonly property var bounds: root.windowBounds(group.modelData.windows)
                    // Uniform scale (not independent X/Y) so each window's
                    // snapshot keeps its real aspect ratio — canvas is
                    // letterboxed within the Metrics.switcherCanvas* box
                    // rather than stretched to fill it exactly.
                    readonly property real scale: Math.min(Metrics.switcherCanvasWidth / group.bounds.w, Metrics.switcherCanvasHeight / group.bounds.h)

                    // Layout canvas — every window in this workspace drawn
                    // to scale at its actual tiled position/size, each one
                    // a screencopy snapshot with its title captioned along
                    // the bottom and the selected one accent-bordered.
                    Item {
                        id: canvas
                        width: group.bounds.w * group.scale
                        height: group.bounds.h * group.scale

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Colors.alpha(Colors.text, 0.04)
                        }

                        Repeater {
                            model: group.modelData.windows
                            delegate: Item {
                                id: tile
                                required property var modelData
                                readonly property bool isSelected: tile.modelData.address === SwitcherState.selectedAddress
                                readonly property var at: tile.modelData.at || [0, 0]
                                readonly property var sz: tile.modelData.size || [0, 0]
                                // Metrics.switcherTileGap inset on every
                                // side gives adjacent tiles breathing room
                                // without touching the real position/scale
                                // math above.
                                x: (tile.at[0] - group.bounds.minX) * group.scale + Metrics.switcherTileGap / 2
                                y: (tile.at[1] - group.bounds.minY) * group.scale + Metrics.switcherTileGap / 2
                                width: Math.max(8, tile.sz[0] * group.scale - Metrics.switcherTileGap)
                                height: Math.max(8, tile.sz[1] * group.scale - Metrics.switcherTileGap)

                                // Snapshot at the very back, clipped to the
                                // tile's rounded corners, with a very slight
                                // blur so it reads as a positional cue
                                // rather than a precise mirror. A plain
                                // Rectangle border drawn on top of a
                                // full-bleed child would get covered by it
                                // (children paint over their parent's own
                                // border) — that's why this is a separate
                                // overlay below instead of border on this
                                // same item.
                                Rectangle {
                                    id: bg
                                    anchors.fill: parent
                                    radius: Metrics.switcherTileRadius
                                    clip: true
                                    color: Colors.alpha(Colors.text, 0.10)

                                    ScreencopyView {
                                        id: shot
                                        anchors.fill: parent
                                        visible: false
                                        live: false
                                        captureSource: Hypr.waylandHandle(tile.modelData.address)
                                    }
                                    MultiEffect {
                                        anchors.fill: parent
                                        source: shot
                                        blurEnabled: true
                                        blur: 0.15
                                        blurMax: 12
                                    }
                                }

                                Rectangle {
                                    id: footer
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: Metrics.switcherFooterHeight
                                    visible: tile.height > height * 1.5
                                    color: Qt.rgba(0, 0, 0, 0.55)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 6

                                        IconImage {
                                            Layout.preferredWidth: 19
                                            Layout.preferredHeight: 19
                                            source: Hypr.iconForClass(tile.modelData.class || "")
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: tile.modelData.title || "Window"
                                            color: "#ffffff"
                                            font.pixelSize: Metrics.fontSecondary
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // Border drawn last (on top of the snapshot
                                // and footer) so it's always crisp instead
                                // of getting covered.
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Metrics.switcherTileRadius
                                    color: "transparent"
                                    border.width: tile.isSelected ? 3 : 1
                                    border.color: tile.isSelected ? Colors.accent : Colors.alpha(Colors.text, 0.18)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: SwitcherState.select(tile.modelData.address)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
