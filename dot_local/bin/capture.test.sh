#!/usr/bin/env bash
# Behaviour test for `capture`: stubs every external tool on a temp PATH and
# asserts on what they were called with. Run: bash dot_local/bin/capture.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
script=$here/executable_capture
fails=0
ok()   { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else fail "$1"; fi; }

setup() {
  T=$(mktemp -d)
  export HOME=$T/home XDG_RUNTIME_DIR=$T/run LOG=$T/log
  mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$T/bin"
  : > "$LOG"
  unset QS_FAIL SLURP_FAIL WF_FAIL
  # Stubs log "<name> <argv>" and, where it matters, behave.
  for t in wl-copy notify-send; do
    printf '#!/bin/sh\necho "%s $*" >> "$LOG"\ncat >/dev/null 2>&1 </dev/null\n' "$t" > "$T/bin/$t"
  done
  cat > "$T/bin/grim" <<'S'
#!/bin/sh
echo "grim $*" >> "$LOG"
for a; do f=$a; done; echo png > "$f"
S
  cat > "$T/bin/slurp" <<'S'
#!/bin/sh
echo "slurp $*" >> "$LOG"
cat > "$LOG.slurp-stdin"
[ -n "${SLURP_FAIL:-}" ] && exit 1
echo "10,20 300x200"
S
  cat > "$T/bin/qs" <<'S'
#!/bin/sh
echo "qs $*" >> "$LOG"
[ -n "${QS_FAIL:-}" ] && exit 1
exit 0
S
  cat > "$T/bin/hyprctl" <<'S'
#!/bin/sh
case "$*" in
  *monitors*) echo '[{"name":"DP-1","focused":false,"activeWorkspace":{"id":1}},{"name":"HDMI-A-1","focused":true,"activeWorkspace":{"id":2}}]' ;;
  *clients*)  echo '[{"mapped":true,"at":[0,0],"size":[100,50],"workspace":{"id":1}},{"mapped":true,"at":[5,6],"size":[70,80],"workspace":{"id":2}},{"mapped":true,"at":[9,9],"size":[1,1],"workspace":{"id":7}}]' ;;
esac
S
  cat > "$T/bin/wf-recorder" <<'S'
#!/bin/bash
echo "wf-recorder $*" >> "$LOG"
[ -n "${WF_FAIL:-}" ] && exit 1
while [ $# -gt 0 ]; do [ "$1" = -f ] && f=$2; shift; done
echo mp4 > "$f"
trap 'echo "wf-recorder got INT" >> "$LOG"; exit 0' INT
while :; do sleep 0.05; done
S
  chmod +x "$T"/bin/*
  export PATH=$T/bin:$PATH
}

# --- shot screen
setup
bash "$script" shot screen; rc=$?
png=$(ls "$HOME"/Pictures/Screenshots/Screenshot_*.png 2>/dev/null | head -n1)
check "shot screen exits 0"                "[ $rc -eq 0 ]"
check "shot screen saves a png"            "[ -n '$png' ]"
check "shot screen targets focused monitor" "[ \"\$(grep '^grim ' '$LOG')\" = 'grim -o HDMI-A-1 $png' ]"
check "shot screen copies to clipboard"    "grep -q '^wl-copy' '$LOG'"
check "shot screen sends thumbnail"        "grep -qxF 'qs ipc call capture thumbnail $png' '$LOG'"
check "shot screen no notify-send on success" "! grep -q '^notify-send' '$LOG'"

# --- shot area, cancelled
setup; export SLURP_FAIL=1
bash "$script" shot area; rc=$?
check "cancelled area exits 0"             "[ $rc -eq 0 ]"
check "cancelled area leaves no file"      "[ -z \"\$(ls '$HOME'/Pictures/Screenshots 2>/dev/null)\" ]"
check "cancelled area calls no grim/qs/notify" "! grep -qE '^(grim|qs|notify-send|wl-copy)' '$LOG'"

# --- shot area, selected: slurp without -r, fed window boxes
setup
bash "$script" shot area
png=$(ls "$HOME"/Pictures/Screenshots/Screenshot_*.png 2>/dev/null | head -n1)
check "area slurp has no -r"               "grep -qx 'slurp ' '$LOG'"
check "area grim gets the geometry"        "[ \"\$(grep '^grim ' '$LOG')\" = 'grim -g 10,20 300x200 $png' ]"
check "area boxes only from visible workspaces" "[ \"\$(cat '$LOG.slurp-stdin')\" = \"\$(printf '0,0 100x50\n5,6 70x80')\" ]"

# --- shot window
setup
bash "$script" shot window
png=$(ls "$HOME"/Pictures/Screenshots/Screenshot_*.png 2>/dev/null | head -n1)
check "window grim argv is exactly -g geom file" "[ \"\$(grep '^grim ' '$LOG')\" = 'grim -g 10,20 300x200 $png' ]"
check "window passes -r to slurp"          "grep -qx 'slurp -r' '$LOG'"
check "window boxes on stdin"              "grep -qx '5,6 70x80' '$LOG.slurp-stdin'"

# --- qs failure falls back to notify-send
setup; export QS_FAIL=1
bash "$script" shot screen; rc=$?
png=$(ls "$HOME"/Pictures/Screenshots/Screenshot_*.png | head -n1)
check "qs failure still exits 0"           "[ $rc -eq 0 ]"
check "qs failure falls back to notify-send -i png" "grep -q '^notify-send.* -i $png\|^notify-send -i $png' '$LOG'"

# --- record / stop
setup
pid=$XDG_RUNTIME_DIR/capture-record.pid
check "status idle before recording"       "[ \"\$(bash '$script' status)\" = idle ]"
bash "$script" record screen; rc=$?
check "record exits 0"                     "[ $rc -eq 0 ]"
check "record creates pidfile"             "[ -s '$pid' ]"
check "record starts on focused monitor"   "grep -qE '^wf-recorder -o HDMI-A-1 -f $HOME/Videos/Screencasts/Recording_.*\.mp4\$' '$LOG'"
check "record calls recordingStarted"      "grep -qE '^qs ipc call capture recordingStarted [0-9]+$' '$LOG'"
check "status reports recording"           "bash '$script' status | grep -qE '^recording [0-9]+$'"
wpid=$(head -n1 "$pid")
# second `record` acts as stop
bash "$script" record screen
mp4=$(ls "$HOME"/Videos/Screencasts/Recording_*.mp4 2>/dev/null | head -n1)
check "record-while-recording signals wf-recorder" "grep -q 'wf-recorder got INT' '$LOG'"
check "process is gone"                    "! kill -0 $wpid 2>/dev/null"
check "stop calls recordingStopped with mp4" "[ -n '$mp4' ] && grep -qxF 'qs ipc call capture recordingStopped $mp4' '$LOG'"
check "stop removes pidfile"               "[ ! -e '$pid' ]"
check "status idle after stop"             "[ \"\$(bash '$script' status)\" = idle ]"
check "only one wf-recorder was started"   "[ \$(grep -c '^wf-recorder -' '$LOG') -eq 1 ]"

# --- record area: exact wf-recorder argv
setup
bash "$script" record area
check "area record argv is exactly -g geom -f file" "grep -qE '^wf-recorder -g 10,20 300x200 -f $HOME/Videos/Screencasts/Recording_.*\.mp4\$' '$LOG'"
bash "$script" stop

# --- wf-recorder dies immediately: no recording state, user told
setup; export WF_FAIL=1
bash "$script" record screen; rc=$?
check "failed record exits non-zero"       "[ $rc -ne 0 ]"
check "failed record never says recordingStarted" "! grep -q 'recordingStarted' '$LOG'"
check "failed record leaves no pidfile"    "[ ! -e '$XDG_RUNTIME_DIR/capture-record.pid' ]"
check "failed record notifies"             "grep -q '^notify-send' '$LOG'"

# --- explicit stop with nothing recording clears a stale shell indicator
setup
bash "$script" stop; rc=$?
check "stop while idle exits 0"            "[ $rc -eq 0 ]"
check "stop while idle tells shell recordingStopped" "grep -qxF 'qs ipc call capture recordingStopped ' '$LOG'"

[ $fails -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
