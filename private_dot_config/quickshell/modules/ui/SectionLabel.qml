import QtQuick
import QtQuick.Layouts
import "../../config"

// Uppercase sub-header inside a W.Section (OUTPUT, INPUT, KNOWN DEVICES,
// MOUSE SENSITIVITY). Five copies of the same four properties, one of
// which had lost its left margin along the way.
Text {
    color: Colors.alpha(Colors.text, 0.6)
    font.pixelSize: Metrics.fontSmall
    font.letterSpacing: 1
    Layout.leftMargin: 4
}
