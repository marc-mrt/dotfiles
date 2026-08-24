pragma Singleton
import QtQuick
import Quickshell.Io

// CPU/RAM/VRAM for the pad overview's ring gauges, plus the detail behind
// them (modules/pad/SystemMetrics.qml, opened by clicking a ring). Polled,
// not event-driven, since none of these have a change notification worth
// hooking into.
//
// One process for the lot, rather than the three it used to take for the
// three percentages alone: the extra detail comes from the same files that
// were already being read (/proc/stat, /proc/meminfo, the DRM card's
// mem_info_*), so splitting it up would have meant five polls every two
// seconds to read overlapping data. The script prints flat key=value lines
// and anything it can't find is simply absent — every consumer treats a
// missing value as 0 and hides that row, so this stays honest on hardware
// that doesn't expose a sensor rather than reporting a confident zero.
QtObject {
    id: root

    // --- ring gauges ---
    property real cpuPercent: 0
    property real ramPercent: 0
    property real vramPercent: 0

    // --- detail ---
    property string cpuModel: ""
    property int cpuCores: 0
    property real cpuFreqMhz: 0
    property real cpuTempC: 0
    property string loadAvg: ""

    property real ramTotalKb: 0
    property real ramAvailableKb: 0
    readonly property real ramUsedKb: Math.max(0, root.ramTotalKb - root.ramAvailableKb)
    property real swapTotalKb: 0
    property real swapFreeKb: 0
    readonly property real swapUsedKb: Math.max(0, root.swapTotalKb - root.swapFreeKb)

    property real gpuBusyPercent: 0
    property real gpuTempC: 0
    property real gpuPowerW: 0
    property real gpuClockMhz: 0
    property real gpuFanRpm: 0
    property real vramUsedBytes: 0
    property real vramTotalBytes: 0

    function refresh() {
        statsProc.running = true
    }

    // %busy = 1 - (idle delta / total delta) between two polls, so the first
    // poll after startup only establishes the baseline.
    property real prevIdle: 0
    property real prevTotal: 0

    function num(v) {
        const n = Number(v)
        return isNaN(n) ? 0 : n
    }

    function apply(text) {
        const v = {}
        for (const line of text.trim().split("\n")) {
            const eq = line.indexOf("=")
            if (eq > 0)
                v[line.slice(0, eq)] = line.slice(eq + 1)
        }

        // /proc/stat's first line: "cpu user nice system idle iowait ...".
        const parts = (v.cpustat || "").trim().split(/\s+/).slice(1).map(Number)
        if (parts.length >= 5) {
            const idle = parts[3] + parts[4]
            const total = parts.reduce((a, b) => a + b, 0)
            const dIdle = idle - root.prevIdle
            const dTotal = total - root.prevTotal
            if (root.prevTotal > 0 && dTotal > 0)
                root.cpuPercent = Math.round((1 - dIdle / dTotal) * 100)
            root.prevIdle = idle
            root.prevTotal = total
        }

        root.cpuModel = v.cpumodel || ""
        root.cpuCores = root.num(v.cpucores)
        root.cpuFreqMhz = root.num(v.cpufreq)
        // Sensors report millidegrees / microwatts.
        root.cpuTempC = root.num(v.cputemp) / 1000
        root.loadAvg = v.load || ""

        root.ramTotalKb = root.num(v.memtotal)
        root.ramAvailableKb = root.num(v.memavailable)
        root.swapTotalKb = root.num(v.swaptotal)
        root.swapFreeKb = root.num(v.swapfree)
        root.ramPercent = root.ramTotalKb > 0
            ? Math.round((1 - root.ramAvailableKb / root.ramTotalKb) * 100) : 0

        root.gpuBusyPercent = root.num(v.gpubusy)
        root.gpuTempC = root.num(v.gputemp) / 1000
        root.gpuPowerW = root.num(v.gpupower) / 1000000
        root.gpuClockMhz = root.num(v.gpuclock) / 1000000
        root.gpuFanRpm = root.num(v.gpufan)
        root.vramUsedBytes = root.num(v.vramused)
        root.vramTotalBytes = root.num(v.vramtotal)
        root.vramPercent = root.vramTotalBytes > 0
            ? Math.round((root.vramUsedBytes / root.vramTotalBytes) * 100) : 0
    }

    // The GPU block picks whichever DRM card reports the largest VRAM total
    // (the discrete one, on hybrid setups — this machine also exposes a
    // 512MB iGPU) rather than hardcoding a card index: PCI enumeration order
    // isn't stable across reboots or driver updates. Every sensor read is
    // guarded, since which of temp/power/clock/fan a card exposes varies —
    // here card0 has neither power nor fan, card1 has both.
    property Process statsProc: Process {
        command: ["bash", "-c", `
printf 'cpumodel=%s\\n' "$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -n1)"
printf 'cpucores=%s\\n' "$(nproc)"
printf 'cpustat=%s\\n' "$(head -n1 /proc/stat)"
printf 'load=%s\\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
printf 'cpufreq=%s\\n' "$(awk '/^cpu MHz/{s+=$4;n++} END{if(n)printf "%.0f", s/n}' /proc/cpuinfo)"
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    k10temp|coretemp|zenpower) printf 'cputemp=%s\\n' "$(cat "$h/temp1_input" 2>/dev/null)"; break ;;
  esac
done
grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo \
  | awk '{printf "%s=%s\\n", tolower(substr($1,1,length($1)-1)), $2}'
best=0; bestdir=
for f in /sys/class/drm/card*/device/mem_info_vram_total; do
  t=$(cat "$f" 2>/dev/null || echo 0)
  if [ "$t" -gt "$best" ]; then best=$t; bestdir=$(dirname "$f"); fi
done
if [ -n "$bestdir" ]; then
  printf 'vramtotal=%s\\n' "$(cat "$bestdir/mem_info_vram_total" 2>/dev/null)"
  printf 'vramused=%s\\n'  "$(cat "$bestdir/mem_info_vram_used" 2>/dev/null)"
  printf 'gpubusy=%s\\n'   "$(cat "$bestdir/gpu_busy_percent" 2>/dev/null)"
  for h in "$bestdir"/hwmon/hwmon*; do
    printf 'gputemp=%s\\n'  "$(cat "$h/temp1_input" 2>/dev/null)"
    printf 'gpupower=%s\\n' "$(cat "$h/power1_average" 2>/dev/null)"
    printf 'gpuclock=%s\\n' "$(cat "$h/freq1_input" 2>/dev/null)"
    printf 'gpufan=%s\\n'   "$(cat "$h/fan1_input" 2>/dev/null)"
  done
fi
`]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
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
