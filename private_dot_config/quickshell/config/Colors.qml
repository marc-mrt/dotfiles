pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    property var palette: ({})

    readonly property color base: palette.base ?? "#1a1b26"
    readonly property color surface: palette.surface ?? "#24283b"
    readonly property color text: palette.text ?? "#c0caf5"
    readonly property color accent: palette.accent ?? "#7aa2f7"

    function alpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a)
    }

    property FileView view: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/generated/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            palette = JSON.parse(text())
        }
    }
}
