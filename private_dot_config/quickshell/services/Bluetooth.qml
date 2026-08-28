pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Thin re-export of Quickshell's native BlueZ D-Bus binding.
//
// Previously this shelled out to bluetoothctl and scraped its text output on
// a poll timer. That fought BlueZ's own device cache: a fixed-length scan
// window would surface nearby devices, but as soon as the scan process
// exited they'd vanish from `bluetoothctl devices` before the next poll
// caught them, and "scan on" passed as a bare CLI arg didn't even start
// discovery in the first place. The native binding gets device add/remove
// and property changes straight off D-Bus signals, so the panel just reads
// live state — no polling, no parsing, no scan-window bookkeeping to get
// out of sync with BlueZ.
QtObject {
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool scanning: adapter ? adapter.discovering : false
    // ObjectModel of BluetoothDevice — bind straight to it as a Repeater model.
    readonly property var devices: adapter ? adapter.devices : null

    function togglePower() {
        if (adapter)
            adapter.enabled = !adapter.enabled
    }
    function toggleScan() {
        if (adapter)
            adapter.discovering = !adapter.discovering
    }
}
