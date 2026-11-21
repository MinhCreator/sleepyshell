#!/bin/bash
# bar/voxtype-tray.test.sh [TREE]: the tray's Voxtype badge and tint, and only on Voxtype's item.
#
# Tier 3 (cosmetic, with one wrong-answer risk: a badge that names the wrong language while the user dictates). The tree
# (default: the live shell) is copied into a run folder without the user's settings; inside one sandbox a private session
# bus carries two stand-in tray items (one with Voxtype's id, one of another app) to the tree's real tray, drawn
# offscreen. Checks: as shipped (both switches off) nothing is added to any icon; with the badge on, Voxtype's item shows
# the language of its config file and a rewrite of the file changes it; Voxtype's item registering again (what a restart
# after `voxtype config set` does) keeps the badge; the tint switch turns the tint layer on for Voxtype's icon and no other (the colour itself is judged on the live bar); with both off
# again the tray is as before. Voxtype's menu lists EN and SR with the file's language selected, badge on or off, and picking
# the other language runs `ptt.py lang` from the config's folder once (DefaultApps' test log); without that script, or
# with an unreadable language, there are no rows. The other app's item never gets a badge, a tint or those entries.
# Prints PASS or FAIL per check; exits 1 on any FAIL.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../common/env.sh"
TREE=$(readlink -f "${1:-$LIVE}")
NAME=voxtype-tray-$$
D=$RUN/$NAME
mkdir -p "$D"
trap 'bash "$KIT/common/cleanup.sh" "$D" >/dev/null' EXIT

python3 -I "$KIT/common/guard.py" snapshot "$NAME" >/dev/null
copy_tree "$TREE" "$D/shell"
rm -f "$D"/shell/sleepysettings.toml* "$D"/shell/settings.json*
cp "$KIT/bar/voxtype-tray-harness.qml" "$D/shell/"

timeout 120 bash "$KIT/common/sandbox.sh" "$D" bash "$KIT/bar/voxtype-tray-inner.sh" "$D" "$KIT/bar"

python3 -I - "$D" <<'CHECK_VOXTYPE_TRAY_PY'
import json, sys
from pathlib import Path
D = Path(sys.argv[1])
fails = 0
def check(ok, what, detail=""):
    global fails
    print(("PASS " if ok else "FAIL ") + what + ("" if ok or not detail else f": {detail}"))
    fails += 0 if ok else 1

log = (D / "qs.log").read_text(errors="replace") if (D / "qs.log").exists() else ""
snaps = {}
for l in log.splitlines():
    if "SNAP " in l:
        phase, rest = l.split("SNAP ", 1)[1].split(" ", 1)
        snaps[int(phase)] = {i["id"]: i for i in json.loads(rest)}
inner = (D / "inner.log").read_text(errors="replace") if (D / "inner.log").exists() else ""
check(sorted(snaps) == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "the tray answered every phase", f"phases {sorted(snaps)} {inner} {log[-300:]}")

def item(phase, id_):
    return snaps.get(phase, {}).get(id_)
def only_voxtype(phase):
    s = snaps.get(phase, {})
    return sorted(s) == ["other-app", "voxtype"]

for p in range(10):
    check(only_voxtype(p), f"phase {p}: both tray items are there, Voxtype's once", str(sorted(snaps.get(p, {}))))

v0 = item(0, "voxtype")
check(v0 is not None and v0["badge"] is False and v0["tint"] is False, "as shipped Voxtype's icon has no badge and no tint (the config says sr)", str(v0))
v1 = item(1, "voxtype")
check(v1 is not None and v1["badge"] is True and v1["badgeText"] == "SR" and v1["tint"] is False, "the badge on: SR from the file, no tint", str(v1))
v2 = item(2, "voxtype")
check(v2 is not None and v2["badge"] is True and v2["badgeText"] == "EN", "the file rewritten: the badge follows to EN", str(v2))
v3 = item(3, "voxtype")
check(v3 is not None and v3["badge"] is True and v3["badgeText"] == "SR", "Voxtype's item registered again keeps its badge, with the new language", str(v3))
v4 = item(4, "voxtype")
check(v4 is not None and v4["tint"] is True and v4["badge"] is True and v4["badgeText"] == "SR", "the tint on: Voxtype's icon is tinted and keeps its badge", str(v4))
v5 = item(5, "voxtype")
check(v5 is not None and v5["badge"] is False and v5["tint"] is False, "both switches off again: as before", str(v5))
others = [item(p, "other-app") for p in range(10)]
check(all(o is not None and o["badge"] is False and o["tint"] is False and o["menu"] == [] for o in others), "the other app's item never gets a badge, a tint or language entries", str(others))

# the language entries of Voxtype's menu: there with the badge on or off, the language from the file shown as selected, and
# only the other language pickable, and none when the switch script is missing or the language unreadable
def marks(v):
    return {e["code"]: (e["checked"], e["enabled"]) for e in (v or {}).get("menu") or []}
SR, EN = {"en": (False, True), "sr": (True, False)}, {"en": (True, False), "sr": (False, True)}
check(marks(v0) == SR, "badge off, file says sr: the menu lists EN and SR, SR selected, EN pickable", str(marks(v0)))
check(marks(v1) == SR, "badge on: the same entries", str(marks(v1)))
check(marks(v2) == EN, "the file rewritten to en: the selection follows to EN", str(marks(v2)))
check(marks(v3) == SR, "Voxtype's item registered again: the entries are there, SR selected", str(marks(v3)))
check(marks(v5) == SR, "both switches off again: the language entries stay", str(marks(v5)))
v6 = item(6, "voxtype")
check(marks(v6) == SR, "the entries after the picks: unchanged, the test never runs the script", str(marks(v6)))
runs = [l for l in (D / "apps.log").read_text().splitlines()] if (D / "apps.log").exists() else []
check(len(runs) == 1 and runs[0].startswith('RUN ["python3","-I","') and runs[0].endswith('/.config/voxtype/ptt.py","lang"]') and "~" not in runs[0],
      "picking SR (set) ran nothing, picking EN ran ptt.py lang from the config's folder once, and only that", str(runs))
check(marks(item(7, "voxtype")) == {}, "the switch script removed: no language rows", str(marks(item(7, "voxtype"))))
check(marks(item(8, "voxtype")) == SR, "the script back: the rows are back", str(marks(item(8, "voxtype"))))
check(marks(item(9, "voxtype")) == {}, "the language unreadable: no language rows", str(marks(item(9, "voxtype"))))
sys.exit(1 if fails else 0)
CHECK_VOXTYPE_TRAY_PY
rc=$?

if python3 -I "$KIT/common/guard.py" verify "$NAME" >/dev/null; then
    echo "PASS no real file changed"
else
    echo "FAIL a real file changed:"
    python3 -I "$KIT/common/guard.py" verify "$NAME" | sed 's/^/    /'
    rc=1
fi
trap - EXIT
bash "$KIT/common/cleanup.sh" "$D" >/dev/null && echo "PASS nothing left running, run folder deleted" || { echo "FAIL processes, windows or files left"; rc=1; }
exit $rc
