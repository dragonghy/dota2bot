#!/usr/bin/env bash
# Mutation stand for the `overchase` PURSUIT-TENSE pricing (strategy desk
# 2026-09-12, GH #760; rebuilt for the runner protocol 2026-09-12T22:xxZ,
# GH #790). Not part of any suite -- run by hand when leg (a) of
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
# ⛔ THE FILE UNDER TEST IS DRIVEN THROUGH tests/run_tests.lua, NOT DIRECTLY.
# [GH #790] The pinned file used to carry a private harness ending in os.exit.
# That is the shape tests/test_run_tests_guard.py names and GH #200/#387
# measured: one process loads every tests/test_*.lua, so a file that exits
# DECAPITATES the suite at itself and the truncated `N tests, 0 failures` reads
# exactly like a complete pass. The harness is gone. Two consequences for this
# stand, and both change how it scores:
#   * run directly, the file now merely returns its table and exits 0 in
#     silence -- which would score EVERY mutant as SURVIVED. So every run below
#     goes through the runner, under a filter.
#   * the runner exits non-zero for a run that executed zero test bodies (GH
#     #200), so a filter typo cannot read as a pass. Scoring therefore demands
#     BOTH a non-zero exit AND the runner's own summary line; a run missing the
#     summary is scored NOT-RUN rather than passed.
#
# ⚠️ M5 CHANGED WITH THE PROTOCOL, AND THE OLD ONE'S SUBJECT DID NOT SURVIVE IT.
# The old M5 restored the defect this file was born with: reporting routed
# through the global `print`, which tests/mock/bot_api.lua blanks on fixture
# load, so the last two sections went unreported while the exit code stayed 0.
# It could not be scored on an exit code (a swallowed FAIL moves nothing), so it
# was scored on the absence of a completion marker the file printed for that
# purpose. Under the runner BOTH halves of that are gone: reporting goes through
# io.write, which the mock does not touch, and a completion marker has no place
# in a file that does not report for itself. The defect is fixed structurally
# rather than watched. What replaced M5 is the mutant for the structure itself:
# give the file a private harness back and check the RUNNER names the breach.
# (The os.exit variant of the same shape is unreportable by construction -- it
# kills the runner -- and is covered statically by tests/test_run_tests_guard.py
# instead. A stand can only score what can be reported.)
#
# ⭐ M8 IS THE OTHER HALF OF THE CONVERSION, and it is the sharper one. The old
# harness bailed with os.exit(1) when the census subprocess died. With the
# counts nil, `C.oc_a_pass_tight == C.oc_a_pass` reads nil == nil = TRUE -- a
# DEAD INSTRUMENT SATISFIES THIS FILE'S LOAD-BEARING CONCLUSION FOR FREE (the GH
# #171 shape, and the reason the bail existed). The runner has no escape hatch,
# so every count-reading case calls census_or_die() first instead. M8 kills the
# census and demands that the failure list name the NO-OP case by name -- not
# merely the census case, which would go red either way. That is the difference
# between the guard being present and the guard being load bearing.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * the EXIT trap reaches a restore FUNCTION DEFINED IN THIS FILE and is armed
#     BEFORE the first mutation (tests/test_mutstand_restore_trap.py, GH #418);
#   * exit codes are read BARE -- no pipe between the runner and `$?`;
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
FILTER=overchase_pursuit_tense
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

# Bare exit code: the runner writes to a file, nothing is piped between it and $?.
run_test() {
    lua5.1 tests/run_tests.lua "$FILTER" > "$WORK/run.log" 2>&1
    return $?
}

# The runner's own summary line. Its ABSENCE means the run did not complete, and
# a run that did not complete is never scored as a catch.
ran() {
    grep -qE '[0-9]+ tests, [0-9]+ failures' "$WORK/run.log"
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
if ! ran; then
    echo "BASELINE DID NOT RUN -- no summary line from the runner (exit $BASE)."
    echo "Nothing below would be meaningful; stand aborted."
    exit 2
fi
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green, and the runner said so)"

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_test; local rc=$?
    if ! ran; then
        echo "$name  NOT-RUN (exit $rc) -- the runner printed no summary line, so"
        echo "        this is not a catch; treat as survived:"
        tail -3 "$WORK/run.log" | sed 's/^/        /'
    elif [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 '^FAIL' "$WORK/run.log" | sed 's/^/        /'
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

# M5: the private harness comes back. The file runs its own bodies, prints its
# own summary and returns nothing -- the GH #387 contract breach, and the exact
# shape this round removed. The runner must FAIL THE FILE and say what it
# returned; the danger it is guarding is that the file looks fine standalone.
#
# ⚠️ The mutant deliberately does NOT call os.exit, even though the original did.
# A stand writes a real defect into a tracked file, and an os.exit left behind by
# an interrupted run is the GH #418 leak with the worst possible payload. The
# unreportable variant is covered statically by tests/test_run_tests_guard.py;
# this one is covered here because it is the one the runner can name.
sub "$TEST" $'return tests\n' \
            $'local pass, fail = 0, 0\nfor name, fn in pairs(tests) do\n    if pcall(fn) then pass = pass + 1 else fail = fail + 1 end\nend\nio.write(string.format("%d run, %d failed\\n", pass, fail))\n'
score "M5 the private harness comes back           " "contract error"

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

# M8: the census dies. What is scored is NOT that the file notices -- the census
# case would go red on its own. It is that the LOAD-BEARING NO-OP CASE is named
# in the failure list, because with the counts nil that case's own comparison
# (nil == nil) is TRUE and it would otherwise report a clean no-op off a dead
# instrument. This is what census_or_die() replaced the old os.exit(1) with, and
# the only mutant that can tell the guard apart from decoration.
sub "$TEST" $'local SWEEP = \'tests/_overchase_sweep.lua\'' \
            $'local SWEEP = \'tests/_overchase_sweep_NOT_THERE.lua\''
score "M8 census dies; no-op case must go red too  " "[no-op] the tightened pursuit lookback refuses NOTHING"

echo
echo "=== stand result ==="
echo "caught $CAUGHT / $TOTAL"
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN -- every mutant on the bench is visible to the pinned file."
    echo
    echo "⚠️ Read M5 and M8 before quoting this line. Both are about the RUNNER"
    echo "   PROTOCOL rather than about overchase: M5 restores the private"
    echo "   harness this file was born with, M8 kills the census and demands"
    echo "   that the no-op case -- not merely the census case -- be named."
    exit 0
fi
echo "STAND RED -- $((TOTAL - CAUGHT)) mutant(s) invisible. A conclusion drawn"
echo "from this file is only as good as the mutants it can see."
exit 1
