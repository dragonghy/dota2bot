#!/usr/bin/env bash
# Mutation stand for the `cmrsolo` candidate -- the ALLY term on X.ConsiderR's
# branch 1, the crowd/teamfight release path in Crystal Maiden's Freezing Field
# that never reads the 1200u ally list the function computes three lines above it
# (hero, 2026-09-12, OWNER_PRIORITIES P4.4 (i)).  Run by hand when
# X.cm_IsFieldSoloReleaseOk, X.ConsiderR or tests/test_cm_r_solo_release.lua are
# edited, and before quoting any of that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmrcrowd.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick (command substitution);
#   * every `want` is the FIRST thing the mutant makes the suite say.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, and the armed path hands back the shipped answer.
#   * M5 removes the CALL SITE.  Helper, id, note and gate tests all survive.
#   * M6 is THE SCOPE MUTANT and the reason this id exists at all: move the
#     conjunct inside the head-count disjunct and the lever becomes a second,
#     redundant copy of `cmrcrowd`'s scope -- the es_aftershock witness (2 heads
#     / 2 hurt / 0 allies) stops being covered, and every gate test still passes.
#   * M7 raises the floor 1 -> 2, i.e. "one ally is not enough", which is a
#     different (c) argument nobody has made.
#   * M8 is the pullcad trap (AGENTS.md): conjoining `cmrcrowd` -- the tempting
#     way to write "this rides on top of that" -- freezes this gate FALSE the day
#     cmrcrowd is promoted, and check_armed_wiring.py still calls it WIRED.
#   * M9 is a control on the STAND ITSELF: the two-frame domain census must be
#     able to go red, or "2 of 10" is a sentence rather than a limit.
#   * M10 is a control on the SEPARATION claim: if widening cmrcrowd's floor so
#     that it swallows this lever's witness cell does not turn §3.3 red, then
#     "neither lever contains the other" was never being checked.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_r_solo_release.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmrsolo.XXXXXX")
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

# The filter is `cm_r_`, not the whole `cm` family: this stand mutates shipped
# source that the sibling CM assertions also read, and the `cm` filter carries a
# pre-existing trunk red (test_cm_pos5_boots.lua, corpus arms) that would make
# every baseline abort.  The two cm_r_ files ARE the pair this lever must stay
# separable from, which is the collision that matters here.
run_tests() {
    lua5.1 tests/run_tests.lua cm_r_ > "$WORK/run.log" 2>&1
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

# ---------------------------------------------------------------------------
# M1: the candidate check is dropped.  The narrowing becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrsolo' )" \
            "	if J.IsModeTurbo()"
score "M1" "gate OFF must answer the shipped"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrsolo' )" \
            "	if J.IsSoakCandidate( 'cmrsolo' )"
score "M2" "outside Turbo the helper must answer the shipped"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed withholds the channel exactly when
#     allies ARE present and releases it when she is alone.
echo
echo "=== M3: the ally floor is inverted ==="
sub "$HERO" "		return nAllyCount >= X.nRSoloAllyFloor" \
            "		return nAllyCount < X.nRSoloAllyFloor"
score "M3" "armed, allies=0 must be refused"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path hands back the shipped answer anyway.
echo
echo "=== M4: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "		return nAllyCount >= X.nRSoloAllyFloor" \
            "		return true"
score "M4" "armed, allies=0 must be refused"

# ---------------------------------------------------------------------------
# M5: THE CALL SITE IS REMOVED.
echo
echo "=== M5: X.ConsiderR stops routing through the helper ==="
sub "$HERO" "			 or aoeCanHurtCount >= 2 )
			and X.cm_IsFieldSoloReleaseOk( #nAllies )" \
            "			 or aoeCanHurtCount >= 2 )"
score "M5" "no longer conjoins X.cm_IsFieldSoloReleaseOk"

# ---------------------------------------------------------------------------
# M6: THE SCOPE MUTANT.  Move the conjunct inside the HEAD-COUNT disjunct.  Same
#     helper, same id, same gate, same floor -- and the lever silently becomes a
#     redundant copy of cmrcrowd's scope: the es_aftershock witness (2 heads / 2
#     hurt / 0 allies) fires the OTHER disjunct and is no longer covered, so the
#     "two independent frames" claim in the note quietly becomes one.
echo
echo "=== M6: the conjunct moved INSIDE the head-count disjunct (scope) ==="
sub "$HERO" "		if ( ( #nEnemysHeroesInRange >= 3 and X.cm_IsFieldCrowdReleaseOk( aoeCanHurtCount ) )
			 or aoeCanHurtCount >= 2 )
			and X.cm_IsFieldSoloReleaseOk( #nAllies )" \
            "		if ( ( #nEnemysHeroesInRange >= 3 and X.cm_IsFieldCrowdReleaseOk( aoeCanHurtCount )
			 and X.cm_IsFieldSoloReleaseOk( #nAllies ) )
			 or aoeCanHurtCount >= 2 )"
score "M6" "no longer conjoins X.cm_IsFieldSoloReleaseOk"

# ---------------------------------------------------------------------------
# M7: the floor is raised from 1 to 2.  "One ally is not enough to peel" is a
#     different (c) argument and nobody has made it; every gate test passes.
echo
echo "=== M7: the ally floor raised 1 -> 2 ==="
sub "$HERO" "X.nRSoloAllyFloor = 1" "X.nRSoloAllyFloor = 2"
score "M7" "armed, allies=1 must pass"

# ---------------------------------------------------------------------------
# M8: THE PULLCAD TRAP.  Conjoin `cmrcrowd` into this gate -- the tempting way to
#     write "this rides on top of that".  The gate freezes FALSE the day cmrcrowd
#     is promoted, and check_armed_wiring.py still calls it WIRED.
echo
echo "=== M8: cmrcrowd is conjoined into the gate (pullcad trap) ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrsolo' )" \
            "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrsolo' ) and J.IsSoakCandidate( 'cmrcrowd' )"
score "M8" "must name exactly one candidate id"

# ---------------------------------------------------------------------------
# M9 (control on the stand): the domain census claims 2 of 10 CM frames carry the
#     shape.  Drop the hurt-count witness out of the listed corpus.
echo
echo "=== M9 (control): the hurt-count witness is dropped from the listed corpus ==="
sub "$TEST" "    'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
    'tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua'," \
            "    'tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua',"
score "M9" "the CM-subject frame list is 9 long"

# ---------------------------------------------------------------------------
# M10 (control on the SEPARATION claim): widen cmrcrowd's floor so that it also
#     removes the cell this lever claims as its own witness.  If §3.3 cannot go
#     red, "neither lever contains the other" was never being checked.
echo
echo "=== M10 (control): cmrcrowd's floor widened to swallow this lever's witness ==="
sub "$HERO" "X.nRCrowdHurtFloor = 1" "X.nRCrowdHurtFloor = 2"
score "M10" "cmrcrowd keeps this cell"

# ---------------------------------------------------------------------------
echo
echo "=== summary ==="
echo "$CAUGHT/$TOTAL mutants CAUGHT"
if [ "$CAUGHT" -ne "$TOTAL" ]; then
    echo "NOT ALL CAUGHT -- do not quote this stand as clean"
    exit 1
fi
exit 0
