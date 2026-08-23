pragma Singleton
import QtQuick
import Quickshell.Io

// CPU/RAM/VRAM percentages for the pad overview's purely-informative corner
// (see modules/pad/Overview.qml) — polled, not event-driven, since none of
// these have a change-notification mechanism worth hooking into.
QtObject {
    id: root

    property real cpuPercent: 0
    property real ramPercent: 0
    property real vramPercent: 0

    property real prevIdle: 0
    property real prevTotal: 0

    function refresh() {
        cpuProc.running = true
        memProc.running = true
        vramProc.running = true
    }

    // /proc/stat's first line: "cpu  user nice system idle iowait irq softirq steal guest guest_nice".
    // %busy = 1 - (idle delta / total delta) between two polls.
    property Process cpuProc: Process {
        command: ["head", "-n1", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/).slice(1).map(Number)
                const idle = parts[3] + (parts[4] || 0)
                const total = parts.reduce((a, b) => a + b, 0)
                const dIdle = idle - root.prevIdle
                const dTotal = total - root.prevTotal
                if (root.prevTotal > 0 && dTotal > 0)
                    root.cpuPercent = Math.round((1 - dIdle / dTotal) * 100)
                root.prevIdle = idle
                root.prevTotal = total
            }
        }
    }

    property Process memProc: Process {
        command: ["grep", "-E", "^(MemTotal|MemAvailable):", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const total = Number((text.match(/MemTotal:\s*(\d+)/) || [])[1] || 0)
                const avail = Number((text.match(/MemAvailable:\s*(\d+)/) || [])[1] || 0)
                root.ramPercent = total > 0 ? Math.round((1 - avail / total) * 100) : 0
            }
        }
    }

    // Picks whichever DRM card reports the largest VRAM total (the discrete
    // GPU, on hybrid setups) rather than hardcoding a card index — PCI
    // enumeration order isn't guaranteed stable across reboots/driver updates.
    property Process vramProc: Process {
        command: ["bash", "-c",
            "best=0; bestdir=; " +
            "for f in /sys/class/drm/card*/device/mem_info_vram_total; do " +
            "  t=$(cat \"$f\" 2>/dev/null || echo 0); " +
            "  if [ \"$t\" -gt \"$best\" ]; then best=$t; bestdir=$(dirname \"$f\"); fi; " +
            "done; " +
            "[ -n \"$bestdir\" ] && cat \"$bestdir/mem_info_vram_used\" \"$bestdir/mem_info_vram_total\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").map(Number)
                if (lines.length === 2 && lines[1] > 0)
                    root.vramPercent = Math.round((lines[0] / lines[1]) * 100)
            }
        }
    }

    property Timer poll: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
