pragma Singleton
import QtQuick
import Quickshell.Io

// CPU/RAM/VRAM for the pad overview's ring gauges, plus the detail behind
// them (modules/pad/SystemMetrics.qml, opened by clicking a ring). Polled,
// not event-driven, since none of these have a change notification worth
// hooking into.
//
// One poll process for the lot, rather than the three it used to take for the
// three percentages alone: the extra detail comes from the same files that
// were already being read (/proc/stat, /proc/meminfo, the DRM card's
// mem_info_*), so splitting it up would have meant five polls every two
// seconds to read overlapping data. Facts that can't change at runtime are
// read once by a separate one-shot (staticProc). The scripts print flat
// key=value lines and anything they can't find is simply absent — every
// consumer treats a missing value as 0 and hides that row, so this stays
// honest on hardware that doesn't expose a sensor rather than reporting a
// confident zero.
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
        if (root.staticReady)
            statsProc.running = true
        else
            staticProc.running = true
    }

    // %busy = 1 - (idle delta / total delta) between two polls, so the first
    // poll after startup only establishes the baseline.
    property real prevIdle: 0
    property real prevTotal: 0

    function num(v) {
        const n = Number(v)
        return isNaN(n) ? 0 : n
    }

    function parseKv(text) {
        const v = {}
        for (const line of text.trim().split("\n")) {
            const eq = line.indexOf("=")
            if (eq > 0)
                v[line.slice(0, eq)] = line.slice(eq + 1)
        }
        return v
    }

    function apply(text) {
        const v = root.parseKv(text)

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

    // Facts that cannot change while the shell runs, read once on the first
    // refresh so the per-tick script never touches /proc/cpuinfo's model line,
    // forks nproc, or re-scans hwmon/drm to find the right sensor again.
    //
    // The GPU pick is whichever DRM card reports the largest VRAM total (the
    // discrete one, on hybrid setups — this machine also exposes a 512MB
    // iGPU) rather than a hardcoded card index: PCI enumeration order isn't
    // stable across reboots or driver updates. Same for the CPU hwmon, which
    // is found by driver name. Forks here are fine; this runs once.
    property string cpuHwmon: ""
    property string gpuDir: ""
    property bool staticReady: false

    property Process staticProc: Process {
        command: ["bash", "-c", `
printf 'cpumodel=%s\\n' "$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -n1)"
printf 'cpucores=%s\\n' "$(nproc)"
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    k10temp|coretemp|zenpower) printf 'cpuhwmon=%s\\n' "$h"; break ;;
  esac
done
best=0; bestdir=
for f in /sys/class/drm/card*/device/mem_info_vram_total; do
  t=$(cat "$f" 2>/dev/null || echo 0)
  if [ "$t" -gt "$best" ]; then best=$t; bestdir=$(dirname "$f"); fi
done
[ -n "$bestdir" ] && printf 'gpudir=%s\\n' "$bestdir"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = root.parseKv(text)
                root.cpuModel = v.cpumodel || ""
                root.cpuCores = root.num(v.cpucores)
                root.cpuHwmon = v.cpuhwmon || ""
                root.gpuDir = v.gpudir || ""
                root.staticReady = true
                root.refresh()
            }
        }
    }

    // The per-tick script: builtins only (read, globs, parameter expansion)
    // except one awk for the cpuinfo MHz average, which is the only place a
    // fork buys exactness (bash can't average floats). $1/$2 are the
    // hwmon/drm paths resolved by staticProc; an empty one just skips that
    // block. Every sensor read is guarded, since which of temp/power/clock/
    // fan a card exposes varies — here card0 has neither power nor fan,
    // card1 has both.
    property Process statsProc: Process {
        command: ["bash", "-c", `
val() { local x; [ -r "$2" ] && read -r x < "$2" && printf '%s=%s\\n' "$1" "$x"; }
read -r line < /proc/stat;           printf 'cpustat=%s\\n' "$line"
read -r l1 l5 l15 _ < /proc/loadavg; printf 'load=%s %s %s\\n' "$l1" "$l5" "$l15"
awk '/^cpu MHz/{s+=$4;n++} END{if(n)printf "cpufreq=%.0f\\n", s/n}' /proc/cpuinfo
[ -n "$1" ] && val cputemp "$1/temp1_input"
while IFS=': ' read -r k v _; do
  case $k in
    MemTotal|MemAvailable|SwapTotal|SwapFree) printf '%s=%s\\n' "\${k,,}" "$v" ;;
  esac
done < /proc/meminfo
if [ -n "$2" ]; then
  val vramtotal "$2/mem_info_vram_total"
  val vramused  "$2/mem_info_vram_used"
  val gpubusy   "$2/gpu_busy_percent"
  for h in "$2"/hwmon/hwmon*; do
    val gputemp  "$h/temp1_input"
    val gpupower "$h/power1_average"
    val gpuclock "$h/freq1_input"
    val gpufan   "$h/fan1_input"
  done
fi
`, "_", root.cpuHwmon, root.gpuDir]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
    }

    // Only the pad shows these numbers, so poll only while it is up. Each
    // tick spawns a shell script that reads /proc and sysfs; running it
    // every 2s behind a closed pad is pure waste. triggeredOnStart makes
    // opening the pad refresh immediately instead of showing stale values.
    property Timer poll: Timer {
        interval: 2000
        running: PadState.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
