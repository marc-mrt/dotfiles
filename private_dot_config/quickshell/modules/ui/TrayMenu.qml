import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../config"

// Custom-rendered replacement for QsMenuAnchor's native platform popup menu
// (pad/chips/Tray.qml's right-click menu) — restyled to match the rest
// of the tray/pad instead of the OS/Qt menu theme, same motivation as
// ToolTip.qml for hover tooltips. Built on Quickshell's own PopupWindow
// primitive (what QsMenuAnchor uses internally), so positioning and
// click-outside-to-dismiss behavior come for free instead of being
// reimplemented by hand.
PopupWindow {
    id: root
    property var menu: null       // QsMenuHandle
    property Item anchorItem: null

    anchor.item: root.anchorItem
    anchor.rect.y: root.anchorItem ? root.anchorItem.height + 4 : 0
    color: "transparent"
    implicitWidth: card.width
    implicitHeight: card.height

    // Only resolved while open — a closed menu has no reason to keep
    // walking a live QsMenuHandle's children.
    QsMenuOpener {
        id: opener
        menu: root.visible ? root.menu : null
    }

    // PopupWindow's own `grabFocus` is documented as unreliable for
    // outside-click dismissal specifically under Hyprland — HyprlandFocusGrab
    // is what it recommends instead, and what the pad itself used before it
    // became a real toplevel (see modules/Pad.qml's history).
    //
    // `active` is set imperatively here, not bound to root.visible: Hyprland
    // writes `active` back to false itself once a grab is dismissed, and a
    // C++-side write to a QML-bound property silently breaks the binding.
    // With `active: root.visible`, the first outside-click close would kill
    // the binding, leaving every later open() with a permanently-false
    // `active` that never grabs again — the menu would open but silently
    // stop closing on outside clicks after its first use.
    //
    // Deliberately NOT whitelisting the pad's own window here too (so a
    // click on another tray icon or pad widget could pass straight through
    // instead of just dismissing): that let a click's grab-clearing get
    // redelivered as a synthetic click on Pad.qml's full-window "click
    // outside the card" MouseArea even when the real click landed on a
    // widget inside the card — a rare but nasty compositor-level glitch.
    // One click to dismiss, a second to act is the trade accepted instead.
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        onCleared: root.visible = false
    }
    onVisibleChanged: if (root.visible) Qt.callLater(() => { grab.active = true })

    Card {
        id: card
        width: implicitWidth
        height: implicitHeight
        radius: 10
        implicitWidth: Math.max(160, list.implicitWidth + 16)
        implicitHeight: list.implicitHeight + 12

        ColumnLayout {
            id: list
            x: 8
            y: 6
            width: card.width - 16
            spacing: 2
            Repeater {
                model: opener.children
                // No `modelData` redeclaration here — MenuEntry.qml already
                // declares it `required` on its own root, and Qt binds a
                // model's `modelData` role onto whatever property of that
                // name a delegate already has. Redeclaring it here would
                // shadow that property instead (see MenuEntry.qml).
                delegate: MenuEntry {
                    Layout.fillWidth: true
                    onActivated: root.visible = false
                }
            }
        }
    }
}
