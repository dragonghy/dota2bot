#!/usr/bin/env bash
# Mutation stand for tests/test_wk_q_aim_preflight.lua -- the PRE-FLIGHT that
# explains why the `wkqaim` candidate (aim X.ConsiderQ's catch-all at the
# lowest-health enemy in nEnemysHerosInRange instead of the nearest) was never
# written (hero, queue.json hero-1, re-taken 2026-09-18).
#
# WHY A STAND FOR A FILE THAT LANDS NOTHING.  Same reason as
# tools/agent/mutstand_wkqreach.sh: a verdict file is quoted by later rounds as
# the reason NOT to do something, so a reading it can no longer make is worse
# than a missing file.  This one had already failed that way once -- its
# universal ("not one frame reaches the branch") was a statement about
# tests/fixtures/ while tests/frames/ held 32 frames the enumerator could not
# see, and THREE of them reach the branch.  The mutants are sorted by which part
# of the repair they price:
#   * M1/M6 attack THE ENUMERATION -- the defect that actually happened.  A
#     universal is only as wide as what it ranges over, and narrowing it back
#     has to be loud.
#   * M2/M3/M4 attack THE WITNESS DEFINITION -- reaching the branch is not the
#     same as witnessing the candidate, and each of the three conjuncts that
#     separate them has to be load-bearing.
#   * M5 is a CONTROL and is a MEASURED EQUIVALENT MUTANT -- see its block.  It
#     is reported, never scored, and it is why the total reads 7 and not 8.
#   * M7 re-takes the reading FROM THE SHIPPED SOURCE: the level gate is parsed,
#     not quoted, so moving it in bots/ must move the verdict.
#   * M8 is the retirement guard -- a later round landing the gate for real
#     while this file goes on explaining that nobody has.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkqlane.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507, GH #848).

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_wk_q_aim_preflight.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkqaim.XXXXXX")
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

# The filter is `wk_q`, not this one file: M7 and M8 edit X.ConsiderQ itself, and
# the sibling ConsiderQ files read the same function -- a stand scoped to the new
# file alone would report a collision there as SURVIVED.  79 cases, ~123s a run.
#
# ⚠️ WHAT `wk_q` DOES NOT COVER, stated rather than papered over: the Bone Guard
# family (X.ConsiderW), the reincarnation/mana-reserve files and the level-supply
# census, all of which are outside the filter because seven Wraith King tests are
# recorded `timed_out` in tools/agent/lua_gate_manifest.json and a bare `wk` run
# does not finish inside a work unit.  No mutant below touches X.ConsiderW or
# anything it reads -- but that is an argument, not a measurement.
run_tests() {
    lua5.1 tests/run_tests.lua wk_q > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the wrong of two identical loop headers scores "survived" for
# the wrong reason.  This file needs the ambiguity guard: `for _, dir in
# ipairs(CORPUS_DIRS) do` occurs twice.
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
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# --------------------------------------------------------------- M1 --------
# THE DEFECT THAT ACTUALLY HAPPENED.  Narrow the corpus back to the single
# directory this file read until 2026-09-18.  Every number in the header moves
# and the file must refuse to be quoted.
echo
sub "$TEST" \
    "local CORPUS_DIRS = { 'tests/fixtures', 'tests/frames' }" \
    "local CORPUS_DIRS = { 'tests/fixtures' }" || exit 3
score "M1 corpus narrowed back to tests/fixtures only" "supply now refuses all"

# --------------------------------------------------------------- M2 --------
# The witness definition, conjunct 1: drop the branch's own level gate.  Two of
# the three reaching frames are below it, and one of those two has a real aim
# delta -- so without this conjunct the tripwire fires on a frame the branch
# cannot reach.
sub "$TEST" \
    "if r.blocked_by == nil and (r.hero_level or 0) >= gate and r.aim_delta then" \
    "if r.blocked_by == nil and r.aim_delta then" || exit 3
score "M2 witness test drops the nLV gate" "domain is no longer empty"

# --------------------------------------------------------------- M3 --------
# The witness definition, conjunct 2: drop the aim delta.  The level-20 frame
# reaches the branch with nearest == weakest, where the candidate is a no-op;
# counting it as a witness is the reading this round exists to refuse.
sub "$TEST" \
    "if r.blocked_by == nil and (r.hero_level or 0) >= gate and r.aim_delta then" \
    "if r.blocked_by == nil and (r.hero_level or 0) >= gate then" || exit 3
score "M3 witness test drops the aim delta" "domain is no longer empty"

# --------------------------------------------------------------- M4 --------
# CONTROL ON THE TRIPWIRE ITSELF.  Force every ring frame to claim an aim delta.
# If this does not go red, "witnesses = 0" is unfalsifiable and the whole file is
# a sentence.
sub "$TEST" \
    "aim_delta = (ring[1] ~= weakest)," \
    "aim_delta = true," || exit 3
score "M4 control: every ring frame claims an aim delta" "domain is no longer empty"

# --------------------------------------------------------------- M5 --------
# MEASURED EQUIVALENT MUTANT -- reported, never scored.  Forcing aim_delta false
# changes nothing, and that survival is not a gap: it IS the finding.  No frame
# in either corpus directory both clears the level gate and holds a lowest-health
# enemy that is not the nearest one, so the true and the forced-false readings
# agree on every row.  ⛔ Do not read this SURVIVED as "the aim delta is not
# covered" -- M4 covers it in the direction the corpus can price.
sub "$TEST" \
    "aim_delta = (ring[1] ~= weakest)," \
    "aim_delta = false," || exit 3
run_tests; M5RC=$?
if [ "$M5RC" -eq 0 ]; then
    echo "M5 equivalent (aim_delta forced false)  SURVIVED as recorded -- no frame past"
    echo "        the level gate carries a delta, so both readings agree row for row."
else
    echo "M5 equivalent (aim_delta forced false)  RED (exit $M5RC) -- ⛔ THE EQUIVALENCE"
    echo "        CLAIM IS STALE: a frame past the level gate now carries an aim delta."
    echo "        Re-read the pre-flight; this is the witness queue.json hero-1 asked for."
    grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
fi
restore > /dev/null

# --------------------------------------------------------------- M6 --------
# The enumeration again, this time behind the constant's back: CORPUS_DIRS still
# names both directories, but fixture_files() only walks the first.  This is the
# shape a refactor produces, and the COVERAGE test is the only thing that sees it.
sub "$TEST" \
    "    for _, dir in ipairs(CORPUS_DIRS) do
        -- Not \`assert\`ed per-directory" \
    "    for _, dir in ipairs({ CORPUS_DIRS[1] }) do
        -- Not \`assert\`ed per-directory" || exit 3
score "M6 enumerator silently walks only the first directory" "enumerated 0 frames out of tests/frames"

# --------------------------------------------------------------- M7 --------
# THE READING IS TAKEN FROM THE SHIPPED SOURCE, NOT QUOTED.  Move the catch-all's
# own level gate in bots/ and the verdict must move with it: at nLV >= 1 the
# level-3 frame becomes a genuine witness and the candidate is revivable.
sub "$HERO" \
    "		and nLV >= 7" \
    "		and nLV >= 1" || exit 3
score "M7 shipped catch-all level gate moved 7 -> 1" "domain is no longer empty"

# --------------------------------------------------------------- M8 --------
# RETIREMENT GUARD.  A later round lands the gate for real while this file goes
# on explaining why nobody did.
sub "$HERO" \
    "		and X.wk_IsCatchAllOddsOk( allyList, nEnemysHerosInView )" \
    "		and X.wk_IsCatchAllOddsOk( allyList, nEnemysHerosInView )
		and J.IsSoakCandidate( 'wkqaim' )" || exit 3
score "M8 a wkqaim gate is landed while the pre-flight still refuses it" "gate, while this file is still the standing"

# ---------------------------------------------------------------------------
echo
echo "MUTATION STAND: $CAUGHT/$TOTAL caught (M5 is a measured equivalent and is not scored)"
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
