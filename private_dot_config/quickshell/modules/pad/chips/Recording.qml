import QtQuick
import "../../../config"
import "../../../services"
import "../../ui" as W

// Screen recording in progress — the pad's copy of the recording
// indicator, so the stop is reachable from here too. Only present while
// recording; click stops it rather than opening a tab, there being
// nothing more to show.
W.StatusChip {
    visible: Capture.recording
    icon: "circle-dot"
    text: Capture.elapsed
    alert: true
    onClicked: Capture.stopRecording()
}
