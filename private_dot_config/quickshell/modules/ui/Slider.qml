import QtQuick
import QtQuick.Layouts
import "../../config"

// The standard slider arrangement: leading icon, track, trailing readout.
// Volume, Brightness and mouse sensitivity each carried a byte-for-byte
// copy of this — right down to the comment explaining the tall hit area,
// whose third copy admitted the fix "didn't before". Seven slider* tokens
// existed in Metrics.qml purely to keep those three copies agreeing.
//
// The drag mechanism itself lives in W.SliderTrack, so an arrangement this
// one doesn't fit (the per-app mixer's row) can compose its own without
// copying it.
//
// `fraction` is always 0..1. A value that isn't naturally on that scale
// (sensitivity runs -1..1) converts at its own call site, where the reason
// for the mapping is visible, rather than becoming a mode in here.
RowLayout {
    id: root

    property real fraction: 0
    property color fillColor: Colors.accent
    property string readout: ""
    signal moved(real fraction)

    // The leading icon. A fixed square slot whether it holds an
    // interactive button (Volume's mute toggle) or a plain decorative
    // glyph, so every slider's track starts at the same x and gets the
    // same width — three sliders stacked in one tab have to line up.
    default property alias icon: iconSlot.data

    Layout.fillWidth: true
    spacing: Metrics.panelSpacing

    Item {
        id: iconSlot
        implicitWidth: 41
        implicitHeight: 41
    }

    SliderTrack {
        Layout.fillWidth: true
        fraction: root.fraction
        fillColor: root.fillColor
        onMoved: (f) => root.moved(f)
    }

    Text {
        text: root.readout
        color: Colors.text
        font.pixelSize: Metrics.fontSecondary
        Layout.preferredWidth: 41
        horizontalAlignment: Text.AlignRight
    }
}
