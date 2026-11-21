#!/bin/bash
# The sandboxed half of bar/voxtype-tray.test.sh: runs inside common/sandbox.sh, never on its own.
# voxtype-tray-inner.sh RUN_FOLDER BAR_FOLDER
# The private test desktop and its session bus, the harness (offscreen, the tree's real tray), and two stand-in tray
# items: one named like Voxtype's and one of another app. The script plays the outside world phase by phase (a config
# file rewritten, Voxtype's item registering again after a restart) and tells the harness each phase through a file; the
# harness answers with one "SNAP <phase> <json>" line in qs.log, which the outer script checks.
set -uo pipefail
D=$1
B=$2
# the private test desktop (common/ui/session.sh: a headless compositor and a private session bus at $D/bus); nothing
# is drawn on the user's screen
. "$KIT/common/ui/session.sh"
ui_start "$D" || { echo "inner: the private test desktop did not start"; exit 1; }
export QT_QPA_PLATFORMTHEME=gtk3
trap 'kill $(jobs -p) 2>/dev/null; ui_stop' EXIT

# Voxtype's own config, where the setting's default points: no settings file, so the switches are at their defaults
mkdir -p "$HOME/.config/voxtype"
CONF=$HOME/.config/voxtype/config.toml
config() { printf '[hotkey]\nkey = "SCROLLLOCK"\n\n[whisper]\nlanguage = "%s"\n\n[output.notification]\non_recording_start = false\n' "$1" >"$CONF"; }
config_nolang() { printf '[hotkey]\nkey = "SCROLLLOCK"\n\n[whisper]\nmodel = "base"\n' >"$CONF"; }
config sr
# the switch script the language rows need, in the config's folder (a stand-in: the test never runs it)
echo "# stand-in" >"$HOME/.config/voxtype/ptt.py"

echo -1 >"$D/phase"
export T5_PHASE=$D/phase
export SLEEPYSHELL_APPS_LOG=$D/apps.log
qs -p "$D/shell/voxtype-tray-harness.qml" >"$D/qs.log" 2>&1 &
QS=$!

for _ in $(seq 150); do
    names=$(gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.ListNames 2>/dev/null)
    case "$names" in *StatusNotifierWatcher*) break ;; esac
    sleep 0.1
done

# start_item ID LOG: a stand-in tray item; waits until it has registered
start_item() {
    python3 -I "$B/sni_item.py" "$1" sleepyshell-test-no-such-icon "" >"$2" 2>&1 &
    ITEM_PID=$!
    for _ in $(seq 100); do grep -q "registered as" "$2" 2>/dev/null && return 0; sleep 0.1; done
    return 1
}
start_item voxtype "$D/sni-voxtype-1.log"
VOX=$ITEM_PID
start_item other-app "$D/sni-other.log"

# phase N: tell the harness, wait for its answer
phase() {
    echo "$1" >"$D/phase"
    for _ in $(seq 150); do grep -q "SNAP $1 " "$D/qs.log" 2>/dev/null && return 0; sleep 0.1; done
    echo "inner: no answer for phase $1" >>"$D/inner.log"
}

phase 0 # both switches off, as shipped: the file says sr and nothing shows
phase 1 # the badge switched on: SR
config en
sleep 1
phase 2 # the file rewritten: EN
# Voxtype restarts after `voxtype config set`: its item goes and a new one registers, the file says sr again
kill "$VOX"
wait "$VOX" 2>/dev/null
sleep 0.5
config sr
start_item voxtype "$D/sni-voxtype-2.log"
sleep 1
phase 3 # the item registered again keeps its badge: SR
phase 4 # the tint switched on
phase 5 # both off again
phase 6 # picking the language already set runs nothing, the other one runs the switch script once
rm "$HOME/.config/voxtype/ptt.py"
sleep 1
phase 7 # the switch script gone: no language rows
echo "# stand-in" >"$HOME/.config/voxtype/ptt.py"
sleep 1
phase 8 # the script back: the rows are back
config_nolang
sleep 1
phase 9 # the language cannot be read: no rows
echo 99 >"$D/phase"
wait "$QS"
