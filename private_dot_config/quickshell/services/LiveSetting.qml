import QtQuick
import Quickshell.Io

// A value that a slow external device owns, which both this shell and the
// outside world can change. Not a singleton — one instance per value
// (Audio has two, Brightness one).
//
// Audio and Brightness each hand-rolled this same four-part mechanism, and
// Audio.qml's comment said as much outright: "Same fix as
// Brightness.setBrightness." It is the subtlest code in the repository and
// it existed twice, with the contract for using it correctly written in
// prose across a third file (Osd.qml).
//
// ── the two problems it solves ──────────────────────────────────────────
// 1. The device is far slower than the input. ddcutil round-trips over I2C
//    take several hundred ms; a slider drag or a burst of scroll ticks
//    fires far faster than that. Setting `running = true` on a Process
//    that is still busy is a silent no-op (true -> true), so in-flight
//    values used to be dropped on the floor. So: throttle a burst to one
//    write per debounceMs, then serialize — one call at a time, holding
//    only the newest pending value and firing it the instant the current
//    call exits. The device ends up trailing the cursor at whatever rate
//    it can manage instead of waiting for the drag to finish.
//
// 2. Telling "the user moved this" apart from "something outside moved
//    it", which is the entire basis for whether an OSD toast should
//    flash. That used to be a `uiChange` bool that callers had to bracket
//    their assignment with *synchronously*, and that a third file had to
//    read at exactly the right moment — plus a per-property "swallow the
//    first change" hack in Osd.qml, because the startup poll looks like an
//    external change to a flag-based scheme.
//
//    Here it is structural instead: an optimistic assignment from set()
//    simply never emits changedExternally, and report() knows a device
//    read is only news if it disagrees with us while we have nothing in
//    flight. There is no window for anyone to sample the wrong state,
//    because there is no flag to sample.
QtObject {
    id: root

    // Current value — bool or number; both are just `===` compared.
    property var value: 0
    // function(v) -> string[]: the command that writes v to the device.
    property var command: null
    property int debounceMs: 60

    // A real change made by something that isn't us. This is the signal an
    // OSD wants; an optimistic assignment from set() never fires it.
    signal changedExternally(var value)

    // True while a write is queued or in flight. A poll that fires now
    // would only read back a value we are in the middle of replacing.
    readonly property bool busy: root._pending !== undefined || root._applying

    // True once report() has seen the device at least once, so the value
    // is real state rather than the declared default. Anything persisting
    // the value to disk has to wait for this.
    readonly property bool synced: root._synced

    // Called by the UI. Assigns straight away so the slider tracks the
    // cursor rather than the device, then queues the real write.
    //
    // start(), not restart(): a restart on every move is a debounce that
    // never fires during a drag, so the device only moved once the drag
    // ended. Coalescing is already the serializer's job — _pending holds
    // one value and _apply fires the moment the last write exits — so
    // this only has to open the window once per burst and let the device
    // run at its own speed behind the cursor.
    function set(v) {
        root.value = v
        root._pending = v
        if (!root._debounce.running)
            root._debounce.start()
    }

    // Called by whatever parses the device's own output (a poll, a
    // subscribe stream). Idempotent and safe to call as often as you like.
    function report(v) {
        if (v === root.value) {
            root._synced = true
            return
        }
        // We're mid-write: the device is still reporting the value we are
        // in the process of replacing. Not news.
        if (root.busy)
            return

        root.value = v
        // The very first read is the startup sync — real system state
        // landing on a default, not a change anyone made. Swallow exactly
        // that one, report every one after it.
        if (root._synced)
            root.changedExternally(v)
        root._synced = true
    }

    property var _pending: undefined
    property bool _applying: false
    property bool _synced: false

    function _apply() {
        if (root._applying || root._pending === undefined)
            return
        root._applying = true
        root._proc.command = root.command(root._pending)
        root._pending = undefined
        root._proc.running = true
    }

    property Timer _debounce: Timer {
        interval: root.debounceMs
        onTriggered: root._apply()
    }

    property Process _proc: Process {
        onExited: {
            root._applying = false
            if (root._pending !== undefined)
                root._apply()
        }
    }
}
