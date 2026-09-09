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
// apps) only used to reach the chip via the poll below, so the shell could
// lag well behind what you just heard change. `pactl subscribe` streams
// sink change events in real time, so refresh() also runs the instant
// something else moves the volume.
//
// Volume and mute are both LiveSettings — see services/LiveSetting.qml for
// the debounce/serialize/who-changed-it machinery that used to be written
// out here by hand. Mute goes through it too rather than staying a
// "toggle" subcommand: sending an explicit 1/0 means the write can't race
// its own read of the current state.
QtObject {
    id: root

    readonly property int volume: level.value
    readonly property bool muted: mute.value
    property string defaultSink: ""
    property string defaultSource: ""
    // [{ name, description, index }]
    property var sinks: []
    property var sources: []

    // Per-application playback streams (pactl's "sink inputs"), split in
    // two on purpose:
    //
    //   streams     — identity only, [{ index, name }]
    //   streamState — index -> { volume, muted }
    //
    // The mixer's Repeater binds to `streams`, so its delegates are torn
    // down and rebuilt only when an app actually starts or stops playing.
    // Folding the volume into that array instead would rebuild every
    // delegate — MouseArea included — on every volume change, and since
    // setting a stream's volume makes `pactl subscribe` fire, that means
    // dragging a slider would destroy the very MouseArea being dragged.
    // Same trap modules/NotificationStack.qml documents for its cards.
    property var streams: []
    property var streamState: ({})

    // Built here rather than in the mixer so pactl stays inside this file;
    // the mixer hands it to a LiveSetting as that value's write command.
    function streamVolumeCommand(index, pct) {
        return ["pactl", "set-sink-input-volume", String(index),
            Math.max(0, Math.min(100, Math.round(pct))) + "%"]
    }
    function setStreamMute(index, muted) {
        run(["pactl", "set-sink-input-mute", String(index), muted ? "1" : "0"])
    }

    // Re-exposed so Osd.qml has one signal per service to subscribe to
    // rather than reaching into either LiveSetting itself.
    signal changedExternally

    function refresh() {
        streamsProc.running = true
        volProc.running = true
        defSinkProc.running = true
        defSourceProc.running = true
        sinksProc.running = true
        sourcesProc.running = true
    }
    function setVolume(pct) {
        level.set(Math.max(0, Math.min(100, Math.round(pct))))
    }
    function toggleMute() {
        mute.set(!root.muted)
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

    property LiveSetting level: LiveSetting {
        value: 0
        command: (v) => ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]
        onChangedExternally: root.changedExternally()
    }
    property LiveSetting mute: LiveSetting {
        value: false
        command: (v) => ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", v ? "1" : "0"]
        onChangedExternally: root.changedExternally()
    }

    property Process volProc: Process {
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Volume:\s*([\d.]+)/)
                if (m)
                    root.level.report(Math.round(parseFloat(m[1]) * 100))
                root.mute.report(text.includes("MUTED"))
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
    // An app's own name first; media.name comes through as the literal
    // string "(null)" for apps that don't set one, so it can't just be
    // truthiness-tested.
    function streamName(props) {
        const candidates = [props["application.name"], props["media.name"],
            props["application.process.binary"]]
        for (const c of candidates)
            if (c && c !== "(null)")
                return c
        return "Audio"
    }

    // "" when nothing resolves, which the mixer renders as a speaker glyph
    // rather than a blank. A literal theme icon name is checked first —
    // Quickshell.iconPath passes an unresolved name straight through, so an
    // unchecked guess comes back looking valid and fails to load later
    // (same trap Notifications.resolveIcon documents) — then the desktop
    // entry heuristic, which is what matches "zen" to Zen Browser.
    function streamIcon(props) {
        const candidates = [props["application.icon_name"],
            props["application.process.binary"], props["application.name"]]
        for (const c of candidates) {
            if (!c || c === "(null)")
                continue
            if (Quickshell.hasThemeIcon(c))
                return Quickshell.iconPath(c)
            const viaEntry = Hypr.iconForClass(c)
            if (viaEntry)
                return viaEntry
        }
        return ""
    }

    property Process streamsProc: Process {
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []
                try {
                    list = JSON.parse(text)
                } catch (e) {
                    list = []
                }
                const ids = []
                const state = ({})
                for (const s of list) {
                    const props = s.properties || ({})
                    ids.push({
                        index: s.index,
                        name: root.streamName(props),
                        icon: root.streamIcon(props)
                    })
                    // Volume is keyed by channel ("front-left", ...); every
                    // channel carries the same figure for our purposes, so
                    // read the first and drop the trailing %.
                    const channels = s.volume ? Object.keys(s.volume) : []
                    const pct = channels.length > 0
                        ? parseInt(String(s.volume[channels[0]].value_percent).replace("%", ""))
                        : 0
                    state[s.index] = {
                        volume: isNaN(pct) ? 0 : pct,
                        muted: !!s.mute
                    }
                }
                root.streamState = state
                // Only reassign the identity list when it genuinely
                // differs — see the comment on `streams` above.
                if (JSON.stringify(ids) !== JSON.stringify(root.streams))
                    root.streams = ids
            }
        }
    }

    // Doesn't refresh() on exit: pactl subscribe (below) already catches
    // every change this causes — sink/mute/default-sink changes all emit a
    // "sink"-containing event, verified live. A second trigger here would
    // just race it for no gain.
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
    // Skips while a write is queued or in flight: refreshing then would
    // only read back the value we're in the middle of replacing.
    property Timer poll: Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.level.busy && !root.mute.busy)
                root.refresh()
        }
    }
}
