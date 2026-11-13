pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screenshots and screen recordings, macOS-style: the capture toolbar picks
// what to grab, the `capture` script (dot_local/bin/executable_capture) does
// the grabbing, and reports back through shell.qml's "capture" IPC target —
// thumbnail after a screenshot, recordingStarted/recordingStopped around a
// recording. The script owns every file and process; this only holds what
// the surfaces show and which command to run next.
QtObject {
    id: root

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/capture"

    property bool toolbarShown: false
    property string toolbarScreen: ""  // monitor name the toolbar was opened on
    property string kind: "shot"    // "shot" | "record"
    property string target: "area"  // "screen" | "window" | "area"
    property int delay: 0           // seconds: 0 | 5 | 10

    property bool recording: false
    property real recordStartedAt: 0 // epoch seconds, from the script

    // mm:ss since the recording started, for the recording indicator and
    // the pad chip. Ticks only while recording.
    property real now: Date.now() / 1000
    readonly property string elapsed: {
        const s = Math.max(0, Math.floor(root.now - root.recordStartedAt))
        return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
    }
    property Timer clock: Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.recording
        onTriggered: root.now = Date.now() / 1000
    }

    // The last capture, shown in the corner until it times out or is
    // dismissed. "" when there is none.
    property string thumbnailPath: ""
    readonly property bool thumbnailIsVideo: root.thumbnailPath.endsWith(".mp4")

    // Opening pins the toolbar to the monitor focused right now, and re-asks
    // the script what state it is in, so a recording started or stopped
    // outside the shell is picked up.
    function toggleToolbar() {
        root.toolbarShown = !root.toolbarShown
        if (root.toolbarShown) {
            root.toolbarScreen = Hyprland.focusedMonitor?.name ?? ""
            root.statusProc.running = true
        }
    }

    function cycleDelay() {
        root.delay = root.delay === 0 ? 5 : root.delay === 5 ? 10 : 0
    }

    // The toolbar and a lingering thumbnail would both end up in the shot,
    // so both go first and the script starts once the compositor has had a
    // frame or two to unmap them.
    function capture() {
        root.toolbarShown = false
        root.thumbnailPath = ""
        launchTimer.restart()
    }

    function stopRecording() {
        root.toolbarShown = false
        Quickshell.execDetached([root.bin, "stop"])
    }

    function showThumbnail(path) {
        // Cleared first so a repeated path still restarts the thumbnail's
        // hide timer.
        root.thumbnailPath = ""
        root.thumbnailPath = path
    }

    function dismissThumbnail() {
        root.thumbnailPath = ""
    }

    function recordingStarted(epoch) {
        root.recordStartedAt = Number(epoch)
        root.recording = true
    }

    function recordingStopped(path) {
        root.recording = false
        root.showThumbnail(path)
    }

    property Timer launchTimer: Timer {
        interval: 200
        onTriggered: Quickshell.execDetached([root.bin, root.kind, root.target]
            .concat(root.delay > 0 ? ["--delay", String(root.delay)] : []))
    }

    // A recording outlives a shell restart (wf-recorder is the script's
    // child, not ours), so ask once at startup. If the script is missing the
    // shell just starts idle.
    property Process statusProc: Process {
        running: true
        command: ["sh", "-c", '[ -x "$1" ] && exec "$1" status', "sh", root.bin]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^recording (\d+)/)
                if (m)
                    root.recordingStarted(Number(m[1]))
                else
                    root.recording = false
            }
        }
    }
}
