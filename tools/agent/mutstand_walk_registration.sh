#!/usr/bin/env bash
# Mutation stand for tests/test_walk_registration_static.py (GH #839 / RULING 77
# option 甲).  Asks the only question that matters about a new guard: CAN IT GO
# RED, and red for the RIGHT reason?
#
# Restore is by FILE COPY + `sha256sum -c`, never by re-applying an inverse edit
# (evidence-discipline rule 1), and every exit code is read BARE -- no pipe
# stands between a command and `$?` (rule 3).
#
# CONTROL must be green before any mutant is believed: a stand whose control is
# red proves nothing, and a mutant that "dies" under a broken control is a
# did-not-run wearing a kill (rule 2).
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 2

CENSUS=tests/test_bots_walk_farm_only.py
SUBSET=tests/test_walk_registration_static.py
BAK="$(mktemp -d)"
cp "$CENSUS" "$BAK/census.py" || exit 2
cp "$SUBSET" "$BAK/subset.py" || exit 2
( cd "$BAK" && sha256sum census.py subset.py > sums.txt ) || exit 2

caught=0
survived=0
aborted=0

restore() {
    cp "$BAK/census.py" "$CENSUS" || exit 2
    cp "$BAK/subset.py" "$SUBSET" || exit 2
    ( cd "$BAK" && sha256sum -c --status sums.txt ) || {
        echo "ABORT: restore did not reproduce the original bytes"
        exit 2
    }
}

# GH #418: the copy-back is the ONLY thing standing between this stand and a
# committed mutant, so it must survive a ^C, a timeout, an OOM or a reclaimed
# container -- not just the straight-line path.  Armed BEFORE the first mutation
# and left armed until the last restore has run.
trap restore EXIT

run_subset() {
    python3 "$SUBSET" > "$BAK/out.txt" 2>&1
    echo $?
}

mutate() {  # mutate <label> <file> <python snippet that edits it>
    local label="$1" file="$2" code="$3"
    python3 - "$file" <<PY
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
orig = s
$code
if s == orig:
    sys.exit(7)
open(p, "w", encoding="utf-8").write(s)
PY
    local rc=$?
    if [ "$rc" -eq 7 ]; then
        echo "ABORT $label: byte-identical file -- the anchor is gone, not the mutant"
        aborted=$((aborted + 1))
        return 1
    fi
    if [ "$rc" -ne 0 ]; then
        echo "ABORT $label: mutator failed with $rc"
        aborted=$((aborted + 1))
        return 1
    fi
    return 0
}

verdict() {  # verdict <label> <exit code>
    local label="$1" rc="$2"
    if [ "$rc" -ne 0 ]; then
        echo "CAUGHT   $label (subset exit $rc)"
        caught=$((caught + 1))
    else
        echo "SURVIVED $label (subset exit 0) -- suspect the ASSERTION, not the mutant"
        survived=$((survived + 1))
    fi
}

# --- CONTROL -----------------------------------------------------------------
rc=$(run_subset)
if [ "$rc" -ne 0 ]; then
    echo "ABORT: CONTROL is red (exit $rc); nothing below would mean anything"
    cat "$BAK/out.txt"
    restore
    exit 2
fi
echo "CONTROL  green (exit 0)"

# --- M1: the recurring defect itself -----------------------------------------
# An unregistered parameter-built walk.  This is the exact shape that reddened
# trunk on 09-12, 09-13, 09-16 (x3) and 09-18 (x2).
if mutate M1 "$CENSUS" '
import re
k = "tests/test_wk_q_flee_reach.lua"
lines = s.split("\n")
start = next(i for i, l in enumerate(lines) if k in l and l.startswith("    \"\"\""))
end = start + 1
while not (lines[end].startswith("    \"\"\"") or lines[end].startswith("    #")):
    end += 1
s = "\n".join(lines[:start] + lines[end:])
'; then
    verdict "M1 an unregistered walk is not a finding" "$(run_subset)"
fi
restore

# --- M2: the mode stops saying what it skipped -------------------------------
# Skipped read as passed -- the defect this repo files under GH #384.
if mutate M2 "$CENSUS" '
s = s.replace("""    NOT_RUN = [
        "the farm-only reach check (needs the 89 walks executed)",
        "the READ_SIDE_FILTERED still-reaches checks (%d of them, same reason)"
        % (2 * len(READ_SIDE_FILTERED)),
    ]""", "    NOT_RUN = []")
'; then
    verdict "M2 --static-only claims the checks it did not run" "$(run_subset)"
fi
restore

# --- M3: a duplicate key, i.e. a hand read discarded silently ----------------
if mutate M3 "$CENSUS" '
anchor = "    \"\"\"tests/test_wk_q_flee_reach.lua  ::  \x27ls \x27 .. dir .. \x27 2>/dev/null\x27\"\"\":"
assert s.count(anchor) == 1, s.count(anchor)
s = s.replace(anchor, anchor + "\n        \"a second, contradictory hand read\",\n" + anchor, 1)
'; then
    verdict "M3 the same key hand-read twice, one value discarded" "$(run_subset)"
fi
restore

# --- M4: the extractor stops matching (vacuous clean) ------------------------
if mutate M4 "$CENSUS" '
s = s.replace("out, key = [], \"io.popen\"", "out, key = [], \"io.popen_NOPE\"", 1)
'; then
    verdict "M4 nothing scanned reads as no findings" "$(run_subset)"
fi
restore

# --- M5: M1's finding, plus a census that swallows its own exit code ---------
# Two channels carry a red: the exit code and the printed FAIL lines.  A guard
# that reads only the first reports green on a tree the census itself calls
# broken, so the mutant removes the entry AND the exit code in one go.
if mutate M5 "$CENSUS" '
import re
k = "tests/test_wk_q_flee_reach.lua"
lines = s.split("\n")
start = next(i for i, l in enumerate(lines) if k in l and l.startswith("    \"\"\""))
end = start + 1
while not (lines[end].startswith("    \"\"\"") or lines[end].startswith("    #")):
    end += 1
s = "\n".join(lines[:start] + lines[end:])
s = s.replace("sys.exit(1 if failures else 0)", "sys.exit(0)", 1)
'; then
    verdict "M5 a real finding whose exit code was swallowed" "$(run_subset)"
fi
restore

echo
echo "CONTROL green | $caught CAUGHT / $survived SURVIVED / $aborted ABORTED"
restore
trap - EXIT          # the pristine copies are about to go; disarm first
rm -rf "$BAK"
[ "$survived" -eq 0 ] && [ "$aborted" -eq 0 ] && exit 0
exit 3
