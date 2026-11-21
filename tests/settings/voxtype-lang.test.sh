#!/bin/bash
# settings/voxtype-lang.test.sh [TREE]: the Voxtype language badge only ever says what Voxtype's config says.
#
# Tier 3 (a core everyday function that is cosmetic when it fails, but a wrong badge says the wrong language while the
# user dictates): services/VoxtypeLang.qml reads whisper.language from Voxtype's config. In one sandbox, with the real
# service of the tree: "en" and "sr" are read (also in capitals), a rewrite of the file is noticed whether it is made
# in place or by replacing the file (`voxtype config set` does one of them), and an array, a missing key, another
# language, a value that is not text, a [whisper] table that does not parse and a file that is not there all give no language; the rest of the file (lists of
# tables, broken lines) never matters.
# With the badge off the file is not opened: a rewrite while it is off never shows a stale answer once it is on.
# Prints PASS or FAIL per check; exits 1 on any FAIL.
set -uo pipefail
. "$(dirname "$(readlink -f "$0")")/../common/env.sh"
TREE=$(readlink -f "${1:-$LIVE}")
NAME=voxtype-lang-$$
D=$RUN/$NAME
mkdir -p "$D"
trap 'bash "$KIT/common/cleanup.sh" "$D" >/dev/null' EXIT

python3 -I "$KIT/common/guard.py" snapshot "$NAME" >/dev/null
copy_tree "$TREE" "$D/s"
rm -f "$D"/s/sleepysettings.toml* "$D"/s/settings.json*
cp "$KIT/settings/voxtype-lang-harness.qml" "$D/s/"

timeout 60 bash "$KIT/common/sandbox.sh" "$D" env VT_FILE="$D/voxtype.toml" VT_GONE="$D/not-there.toml" QT_QPA_PLATFORM=offscreen \
    qs -p "$D/s/voxtype-lang-harness.qml" >"$D/out.log" 2>&1

python3 -I - "$D" <<'CHECK_VOXTYPE_LANG_PY'
import json, sys
from pathlib import Path
D = Path(sys.argv[1])
fails = 0
def check(ok, what, detail=""):
    global fails
    print(("PASS " if ok else "FAIL ") + what + ("" if ok or not detail else f": {detail}"))
    fails += 0 if ok else 1

log = (D / "out.log").read_text(errors="replace")
line = next((l for l in log.splitlines() if "RESULT " in l), None)
check(line is not None, "the harness ran and reported", log[-300:])
if line is None:
    sys.exit(1)
got = {e["name"]: e["language"] for e in json.loads(line.split("RESULT ", 1)[1])}

expected = [
    ("off", "", "with the badge off nothing is read, although the file says sr"),
    ("on", "sr", "switched on, the language in the file shows"),
    ("rewritten-atomic", "en", "a file replaced by a new one is noticed"),
    ("rewritten-in-place", "sr", "a file rewritten in place is noticed"),
    ("uppercase", "en", "EN in capitals reads as en"),
    ("array", "", "a list of languages gives none"),
    ("no-key", "", "a file without a language gives none"),
    ("other-language", "", "a language the badge has no name for gives none"),
    ("not-a-string", "", "a language that is a number gives none"),
    ("broken", "", "a file that does not parse gives none"),
    ("valid-again", "en", "the file mended, the language is back"),
    ("lists-of-tables-elsewhere", "sr", "lists of tables in other parts of the file do not hide the language"),
    ("broken-elsewhere", "en", "a line that does not parse in another table does not hide the language"),
    ("whisper-broken", "", "a [whisper] table that does not parse gives none"),
    ("whisper-twice", "", "a [whisper] table named twice gives none"),
    ("dotted-key-outside-table", "", "a language written as a dotted key outside the table is not read (the reader has no dotted keys)"),
    ("mended", "en", "the file mended again, the language is back"),
    ("missing-file", "", "a file that is not there gives none"),
    ("back-to-the-file", "en", "pointed at the file again, the language is back"),
    ("off-again", "", "switched off again, the old answer is forgotten"),
    ("rewritten-while-off", "", "a rewrite while the badge is off shows nothing"),
    ("on-after-rewrite", "sr", "switched on again, the new content shows, not the old one"),
]
for name, want, what in expected:
    check(got.get(name) == want, what, f"{name}: got {got.get(name)!r}, want {want!r}")
check(len(got) == len(expected), "every step ran", f"{len(got)} of {len(expected)}")
# the IPC socket may not start in the sandbox; the harness has no IPC target
errors = [l for l in log.splitlines() if "ERROR" in l and "quickshell.ipc" not in l and "quickshell.paths" not in l]
check(not errors, "no errors in the log", "; ".join(errors)[:300])
sys.exit(1 if fails else 0)
CHECK_VOXTYPE_LANG_PY
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
