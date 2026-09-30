import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../config"

// One row of a custom tray context menu (see TrayMenu.qml). A submenu
// (hasChildren) expands inline underneath, indented, rather than opening a
// second flyout popup — SNI menus here are short enough that a nested
// popup window's positioning isn't worth the complexity, and this file can
// just recurse into itself for however deep it goes.
ColumnLayout {
    id: root
    // Declared once, here, and never redeclared at any instantiation site
    // (TrayMenu.qml's Repeater, or the recursive Loader below) — QML
    // resolves a bare model role like `modelData` onto whatever property of
    // that name the delegate type already declares. Redeclaring
    // `required property var modelData` again at a call site creates a
    // *second*, shadow property instead of binding this one: every
    // internal binding here kept reading this original property (stuck at
    // its unset default), while the shadow silently received the real
    // data. That was today's "menu entries render empty" bug.
    required property var modelData
    property bool expanded: false
    spacing: 2

    // Bubbles up from a leaf entry being triggered, so TrayMenu.qml can
    // close the whole popup regardless of how deep the entry was nested.
    signal activated()

    Rectangle {
        visible: root.modelData.isSeparator
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Colors.alpha(Colors.text, 0.1)
    }

    Rectangle {
        id: row
        visible: !root.modelData.isSeparator
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 6
        color: rowMa.containsMouse ? Colors.alpha(Colors.text, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: Metrics.durationFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            IconImage {
                visible: !!root.modelData.icon
                implicitSize: 17
                source: root.modelData.icon ?? ""
            }
            Text {
                Layout.fillWidth: true
                text: root.modelData.text
                color: root.modelData.enabled ? Colors.text : Colors.alpha(Colors.text, 0.4)
                font.pixelSize: Metrics.fontBody
                elide: Text.ElideRight
            }
            Text {
                visible: root.modelData.hasChildren
                text: root.expanded ? "\u{F077}" : "\u{F078}"
                color: Colors.alpha(Colors.text, 0.6)
                font.pixelSize: Metrics.fontSmall
            }
        }

        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.modelData.enabled
            onClicked: {
                if (root.modelData.hasChildren)
                    root.expanded = !root.expanded
                else {
                    root.modelData.triggered()
                    root.activated()
                }
            }
        }
    }

    QsMenuOpener {
        id: childOpener
        menu: root.expanded ? root.modelData : null
    }

    Repeater {
        model: root.expanded ? childOpener.children : []
        // A QML file can't directly instantiate itself as a static child
        // type — the compiler rejects that as recursive at compile time
        // (confirmed: "MenuEntry is instantiated recursively"). A
        // URL-based Loader.source resolves the type at runtime instead,
        // sidestepping the compile-time cycle; the tradeoff is that
        // `modelData`/`activated` have to be wired up imperatively in
        // onLoaded rather than as plain declarative bindings.
        delegate: Loader {
            id: subLoader
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: 14
            // setSource's initial-properties form (not plain `source:`)
            // supplies `modelData` before the loaded MenuEntry finishes
            // constructing — required, since its `modelData` is a
            // `required property` that has to be satisfied at creation.
            Component.onCompleted: subLoader.setSource(
                Qt.resolvedUrl("MenuEntry.qml"), { modelData: subLoader.modelData })
            onLoaded: subLoader.item.activated.connect(root.activated)
        }
    }
}
