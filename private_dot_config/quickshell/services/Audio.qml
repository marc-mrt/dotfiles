pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Owns ALL audio state via wpctl (volume/mute on the default device) and
// pactl (device enumeration + default selection). The volume slider always
// targets @DEFAULT_AUDIO_SINK@, so switching the default sink makes the
// slider follow it — matching GNOME/KDE quick-settings behaviour.
//
// Volume/mute changes made outside this app (keyboard media keys, other
// apps) only used to reach the widget via the 3s poll below, so the bar
// could lag well behind what you just heard change. `pactl subscribe`
// streams sink change events in real time, so refresh() also runs the
// instant something else moves the volume.
QtObject {
    id: root

    property int volume: 0
    property bool muted: false
    property string defaultSink: ""
    property string defaultSource: ""
    // True while a change made through this API hasn't yet been confirmed
    // by a real read — lets Osd.qml tell "I changed this" apart from
    // "wpctl/another app changed this".
    property bool uiChange: false
    // [{ name, description, index }]
    property var sinks: []
    property var sources: []

    // setVolume() during a fast drag/scroll fires far more often than wpctl
    // round-trips complete. actionProc only starts a new spawn once idle, so
    // a rapid burst collapses to "run the first value now, then whatever's
    // pending once that exits" — meaning a stray *second* completion for the
    // burst's final value can land well after the calls themselves, with no
    // further setVolume() call around to keep uiChange armed for it. Same
    // fix as Brightness.setBrightness: assign optimistically and bracket
    // uiChange synchronously around just that assignment, so Osd only ever
    // has to judge a single-JS-turn change with no async gap to race. The
    // actual wpctl call is then serialized separately (pendingVolume/
    // applyingVolume) and, since it converges on the same value we already
    // set, its eventual confirmation read fires no further change signal.
    property int pendingVolume: -1
    property bool applyingVolume: false

    function refresh() {
        volProc.running = true
        defSinkProc.running = true
        defSourceProc.running = true
        sinksProc.running = true
        sourcesProc.running = true
    }
    function setVolume(pct) {
        const v = Math.max(0, Math.min(100, Math.round(pct)))
        root.uiChange = true
        root.volume = v
        root.uiChange = false
        root.pendingVolume = v
        volumeDebounce.restart()
    }
    function applyVolume() {
        if (root.applyingVolume || root.pendingVolume < 0)
            return
        root.applyingVolume = true
        volumeSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", root.pendingVolume + "%"]
        root.pendingVolume = -1
        volumeSetProc.running = true
    }
    function toggleMute() {
        root.uiChange = true
        run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
    }
    function setDefaultSink(name) {
        run(["pactl", "set-default-sink", name])
    }
    function setDefaultSource(name) {
        run(["pactl", "set-default-source", name])
    }
    function run(cmd) {
        actionProc.command = cmd
        actionProc.running = true
    }

    property Timer volumeDebounce: Timer {
        interval: 60
        onTriggered: root.applyVolume()
    }
    property Process volumeSetProc: Process {
        onExited: {
            root.applyingVolume = false
            if (root.pendingVolume >= 0)
                root.applyVolume()
        }
    }

    property Process volProc: Process {
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Volume:\s*([\d.]+)/)
                if (m)
                    root.volume = Math.round(parseFloat(m[1]) * 100)
                root.muted = text.includes("MUTED")
                root.uiChange = false
            }
        }
    }
    property Process defSinkProc: Process {
        command: ["pactl", "get-default-sink"]
        stdout: StdioCollector {
            onStreamFinished: root.defaultSink = text.trim()
        }
    }
    property Process defSourceProc: Process {
        command: ["pactl", "get-default-source"]
        stdout: StdioCollector {
            onStreamFinished: root.defaultSource = text.trim()
        }
    }
    property Process sinksProc: Process {
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sinks = JSON.parse(text).map(s => ({
                        name: s.name,
                        description: s.description,
                        index: s.index
                    }))
                } catch (e) {
                    root.sinks = []
                }
            }
        }
    }
    property Process sourcesProc: Process {
        command: ["pactl", "-f", "json", "list", "sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sources = JSON.parse(text)
                        .filter(s => !s.name.endsWith(".monitor"))
                        .map(s => ({
                            name: s.name,
                            description: s.description,
                            index: s.index
                        }))
                } catch (e) {
                    root.sources = []
                }
            }
        }
    }
    // Doesn't refresh() on exit: pactl subscribe (below) already catches
    // every change this causes — sink/mute/default-sink changes all emit a
    // "sink"-containing event, verified live. A second trigger here would
    // just race it for no gain (see uiChange's comment above).
    property Process actionProc: Process {}

    // Long-running: emits a line per change (volume, mute, default sink,
    // device plug/unplug, ...) as it happens.
    property Process subscribeProc: Process {
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                if (line.includes("sink") || line.includes("source"))
                    root.refresh()
            }
        }
    }

    // Fallback safety net in case the subscribe stream ever dies quietly.
    // Skips while uiChange is set: firing here would call refresh() outside
    // pactl subscribe's single trigger path and could resolve before the
    // real completion for that change does, resetting uiChange early.
    property Timer poll: Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.uiChange)
                root.refresh()
        }
    }
}
