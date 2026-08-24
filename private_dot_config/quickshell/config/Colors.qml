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

    // Escalating tint for a 0-100 load figure, so a hot metric stands out at
    // a glance rather than only on close reading of the number. Shared by
    // the overview's ring gauges and the system detail tab behind them, which
    // have to agree — the same CPU reading turning amber in one and accent in
    // the other would read as two different measurements.
    function loadColor(percent) {
        return percent >= 85 ? "#f7768e" // red — under real pressure
            : percent >= 60 ? "#e0af68"  // amber — worth a glance
            : accent
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
