#!/usr/bin/env bash
# Mutation stand for the `overchase` PURSUIT-TENSE pricing (strategy desk
# 2026-09-12, GH #760). Not part of any suite -- run by hand when leg (a) of
# J.ShouldPunishOverchase (bots/FunLib/jmz_func.lua), the census
# tests/_overchase_sweep.lua, or tests/test_overchase_pursuit_tense.lua is
# edited.
#
# ⛔ WHAT IS ON THE BENCH IS NOT A BEHAVIOUR CHANGE. Four narrowings were priced
# and NONE landed -- three read as a no-op or an artefact and the fourth is not
# measurable at all. What landed is a census extension plus one source
# registration. So the mutants are not "does the fix still fire"; they are "can
# this file still be trusted to say what it says".
#
# ⭐⭐ AND THAT IS WHY THE ORACLE MUTANTS ARE THE POINT. Every load-bearing
# conclusion in the pinned file is NEGATIVE:
#     "the tightened lookback refuses NOTHING"
#     "GetVelocity is blind"      "IsChasingTarget cannot answer"
# A degenerate instrument proves all three FOR FREE -- a lookback argument that
# is ignored makes the tightened reading equal the loose one by construction,
# which is exactly the no-op the file reports. M1/M2 aim there, and the
# assertion that catches them is the 0.2 s PROBE (a reading that must come back
# strictly smaller), not any of the no-op assertions themselves. M3/M4 aim at
# the blindness claims, which have the same defect in the other direction: a
# stub that answers nothing satisfies "is blind" without being evidence of it.
#
# ⚠️ M5 IS THE ONE THIS ROUND ADDED BECAUSE IT ALREADY BIT. On its first run the
# pinned file printed 13 ok lines and exited 0 while §6 and §7 WENT UNREPORTED:
# tests/mock/bot_api.lua sets `G.print = function() end` when a fixture loads,
# so every line after the first rf.load -- including a FAIL line -- is swallowed.
# A swallowed FAIL with os.exit(0) is a file that reads green. M5 restores that
# defect on purpose.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# ⚠️ Do NOT run this while the start-of-shift self-check is running: they share
# the worktree, and a half-written mutant reads as a real regression.
#
# Usage: bash tools/agent/mutstand_overchase_tense.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/FunLib/jmz_func.lua
SWEEP=tests/_overchase_sweep.lua
TEST=tests/test_overchase_pursuit_tense.lua
MOCK=tests/mock/replay_fixture.lua
FILES=("$SRC" "$SWEEP" "$TEST" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_overchase_tense.XXXXXX")
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

# Bare exit code: the test writes to a file, nothing is piped between it and $?.
run_test() {
    lua5.1 "$TEST" > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex). Abort if the anchor is missing OR ambiguous.
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
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ANCHOR PROBLEM -- stand aborted rather than scoring a no-op"
        exit 2
    fi
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_test; BASE=$?
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
    run_test; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail\|assert\|error' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

echo
echo "=== mutants ==="

# M1: the tightened lookback stops being tighter -- the single edit that would
# make this round's whole no-op conclusion VACUOUS while leaving every no-op
# assertion satisfied. Only the 0.2 s probe can see it.
sub "$SWEEP" 'a:WasRecentlyDamagedByHero(e, 0.2)' 'a:WasRecentlyDamagedByHero(e, 2.0)'
score "M1 probe lookback widened to the shipped one " "probe below the witness dts"

# M2: the damage oracle ignores its lookback argument entirely (the degenerate
# instrument the probe exists to catch). Same target, different mechanism: M1
# breaks the census's call, M2 breaks the mock underneath it.
sub "$MOCK" $'                WasRecentlyDamagedByHero = function(_, hUnit, f)' \
            $'                WasRecentlyDamagedByHero = function(_, hUnit, f)\n                    f = 6.0'
score "M2 mock ignores the lookback argument       " "probe below the witness dts"

# M3: the blindness claim about GetVelocity degenerates into a claim about a
# stub. If the mock grew a real velocity the file must go RED, not quietly keep
# reporting "blind" -- that is the whole point of asserting it on a live frame.
sub "$MOCK" 'GetVelocity = function(_self) return api.Vector(0, 0, 0) end,' \
            'GetVelocity = function(_self) return api.Vector(250, 250, 0) end,'
score "M3 mock grows a real velocity               " "dumper has grown the field"

# M4: the census's pursuit-disjunct attribution degenerates -- oc_a_ischasing
# reports a hit where the dump cannot support one. This is the reading that
# justifies calling narrowing (2) an artefact.
sub "$SWEEP" 'local bChase = J.IsChasingTarget(e, a)' 'local bChase = true'
score "M4 census claims IsChasingTarget answers    " "PAST-TENSE pursuit disjunct"

# M5: reporting routes back through the global print, which tests/mock/bot_api.lua
# blanks on fixture load. The file then reads GREEN while its last two sections
# go unreported -- the defect this file was actually born with.
#
# ⭐⭐ THIS MUTANT CANNOT BE SCORED ON THE EXIT CODE, AND SAYING SO IS THE POINT.
# A swallowed FAIL line is swallowed together with nothing else: `fail` still
# counts, os.exit still answers 0 when the assertions pass, and `score` would
# print SURVIVED for a mutant that is in fact catastrophic for the reader.
# Scoring it on exit code and then calling the stand green would be the stand
# lying. So it is scored on the ABSENCE OF THE COMPLETION MARKER -- which is why
# the pinned file emits one at all.
score_absent() {
    local name="$1" marker="$2"
    TOTAL=$((TOTAL + 1))
    run_test
    if grep -qF "$marker" "$WORK/run.log"; then
        echo "$name  SURVIVED -- the marker still printed, so this stand cannot"
        echo "        tell a reported run from a silent one"
    else
        echo "$name  caught (marker absent), and that is the whole failure mode:"
        echo "        '$marker' never reached stdout; exit code was $? -- unchanged"
        CAUGHT=$((CAUGHT + 1))
    fi
    restore > /dev/null
}
sub "$TEST" $'local say = print' $'local say = function(...) return print(...) end'
score_absent "M5 reporting swallowed after mock load     " "OVERCHASE-TENSE-REPORT-COMPLETE"

# M6: the source registration is deleted. A census whose finding is no longer
# written where the next reader of the code will see it has lost half its value.
# ⚠️ The anchor NAMES #760: the same phrase also appears in the tpdeftower
# registration from the same day, so an un-qualified anchor is ambiguous and the
# stand would abort (it did, on this mutant's first run) -- and worse, the
# pinned assertion used to search for the bare phrase, which the OTHER comment
# satisfied. Both were narrowed together; this mutant is what found it.
sub "$SRC" 'GH #760] REGISTERED, NOT REPAIRED' 'GH #760] registered'
score "M6 source registration removed             " "registration comment is gone"

# M7: the witness-set guard. Every no-op reading is scoped to the two frames
# this corpus carries; if that set moves, the readings must be re-taken rather
# than inherited.
sub "$SWEEP" "bump('oc_fires')" "bump('oc_fires', 3)"
score "M7 witness set silently grows              " "witness set moved"

echo
echo "=== stand result ==="
echo "caught $CAUGHT / $TOTAL"
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN -- every mutant on the bench is visible to the pinned file."
    echo
    echo "⚠️ Read M5's scoring rule before quoting this line: it is scored on the"
    echo "   ABSENCE OF A MARKER, not on an exit code, because the defect it"
    echo "   restores cannot move an exit code. The other six are exit-code"
    echo "   mutants in the ordinary way."
    exit 0
fi
echo "STAND RED -- $((TOTAL - CAUGHT)) mutant(s) invisible. A conclusion drawn"
echo "from this file is only as good as the mutants it can see."
exit 1
