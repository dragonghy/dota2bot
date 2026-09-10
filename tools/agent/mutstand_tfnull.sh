#!/usr/bin/env bash
# Mutation stand for the `tfnull` lever (strategy desk 2026-09-10).
# Not part of any suite -- run by hand when J.GetTeamFightLocation or
# tests/test_teamfight_location_origin.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while moving
# nothing, or moving the wrong thing:
#   * M3 is DEAD WIRING: gate, id and call site all present, armed hands back
#     the shipped sentinel. check_armed_wiring.py would still call it WIRED and
#     a wave would read back "tested, no effect".
#   * M4 is the WIDENING: the emptiness test stops being a test. The lever then
#     rewrites the answer on frames whose centroid HAS contributors -- i.e. it
#     stops being a sentinel repair and becomes a policy change to
#     "the fight is at the member", which is NOT what was argued or measured.
#   * M5 keeps everything (gate, id, emptiness test, direction) and only swaps
#     the anchor for another plausible-looking location. The fountain is the
#     specific wrong answer the sibling helper J.GetNearbyLocationToTp already
#     falls back to, so it is the one a reader would least suspect.
#   * M6 is the pullcad trap (AGENTS.md): conjoining an id that is already
#     PROMOTED freezes the gate FALSE forever, because a promoted id appears in
#     no armed string. `fight` is a real promoted id.
#   * M7 does not touch bots/ at all -- it moves one of the readings this round
#     published. A stand that cannot go red on a moved reading is not a stand.
#
# Usage: bash tools/agent/mutstand_tfnull.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/FunLib/jmz_func.lua
TEST=tests/test_teamfight_location_origin.lua

FILES=("$SRC" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tfnull.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
}

trap restore EXIT

run_tests() {
    lua5.1 tests/run_tests.lua teamfight_location_origin > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
n = s.count(old)
if n == 0:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
if n != 1:
    sys.stderr.write("ANCHOR AMBIGUOUS (%d hits) in %s: %r\n" % (n, f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

GATE="			if #allyList == 0
				and J.IsModeTurbo() and J.IsSoakCandidate( 'tfnull' )
			then
				targetLocation = member:GetLocation()
			end"

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the candidate check is dropped -- a defaults change wearing a gate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$SRC" "				and J.IsModeTurbo() and J.IsSoakCandidate( 'tfnull' )" \
           "				and J.IsModeTurbo()"
score "M1" "unarmed must keep the shipped sentinel"

# ---------------------------------------------------------------------------
# M2: turbo-only dropped, candidate check kept -- the narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$SRC" "				and J.IsModeTurbo() and J.IsSoakCandidate( 'tfnull' )" \
           "				and J.IsSoakCandidate( 'tfnull' )"
score "M2" "the fix must be turbo-only"

# ---------------------------------------------------------------------------
# M3: DEAD WIRING -- armed recomputes the shipped answer.
echo
echo "=== M3: the armed path hands back the shipped sentinel ==="
sub "$SRC" "				targetLocation = member:GetLocation()" \
           "				targetLocation = J.GetCenterOfUnits( allyList )"
score "M3" "armed still answers the sentinel"

# ---------------------------------------------------------------------------
# M4: THE WIDENING -- the emptiness test stops being a test, so the lever also
#     rewrites frames whose ally centroid is real.
echo
echo "=== M4: the emptiness test is dropped ==="
sub "$SRC" "			if #allyList == 0
				and J.IsModeTurbo()" \
           "			if #allyList >= 0
				and J.IsModeTurbo()"
score "M4" "armed moved a frame whose centroid HAS contributors"

# ---------------------------------------------------------------------------
# M5: THE OTHER PLAUSIBLE ANCHOR -- gate, id, emptiness test and direction all
#     intact; only the place is wrong.
echo
echo "=== M5: the fallback anchors on the fountain instead of the member ==="
sub "$SRC" "				targetLocation = member:GetLocation()" \
           "				targetLocation = J.GetTeamFountain()"
score "M5" "member is at"

# ---------------------------------------------------------------------------
# M6: THE PULLCAD TRAP -- conjoining an already-PROMOTED id freezes the gate
#     FALSE in every wave while every wiring checker still calls it wired.
echo
echo "=== M6: the gate is conjoined with the promoted id 'fight' ==="
sub "$SRC" "				and J.IsModeTurbo() and J.IsSoakCandidate( 'tfnull' )" \
           "				and J.IsModeTurbo() and J.IsSoakCandidate( 'tfnull' )
				and J.IsSoakCandidate( 'fight' )"
score "M6" "armed still answers the sentinel"

# ---------------------------------------------------------------------------
# M7: a published READING is moved, in the test file only.  bots/ is untouched.
echo
echo "=== M7: one recorded distance is moved by 100 units ==="
sub "$TEST" "      member = 'npc_dota_hero_chaos_knight',       moved = 8017, gap = 307 }," \
            "      member = 'npc_dota_hero_chaos_knight',       moved = 8117, gap = 307 },"
score "M7" "the fabricated answer sits"

# ---------------------------------------------------------------------------
# M8: the other published reading -- how far the substitute anchor sits from
#     the centroid the branch would have answered with data.  That number is the
#     whole case that the anchor is a good one, so it is on the bench too.
echo
echo "=== M8: the recorded substitute-anchor gap is moved by 100 units ==="
sub "$TEST" "      member = 'npc_dota_hero_earthshaker',        moved = 6007, gap = 259 }," \
            "      member = 'npc_dota_hero_earthshaker',        moved = 6007, gap = 359 },"
score "M8" "from the populated centroid"

# ---------------------------------------------------------------------------
echo
echo "=== STAND: $CAUGHT/$TOTAL caught ==="
if [ "$CAUGHT" -ne "$TOTAL" ]; then
    echo "STAND NOT GREEN -- read the SURVIVED lines above before believing any"
    echo "reading this lever published."
    exit 1
fi
echo "STAND GREEN"
