#!/usr/bin/env bash
# Mutation stand for the `cmrcrowd` candidate -- the escape term on X.ConsiderR's
# HEAD-COUNT disjunct, the one release path in Crystal Maiden's Freezing Field
# branch 1 that never asks whether the crowd can be hit (hero, 2026-09-09,
# OWNER_PRIORITIES P4.4 (i)).  Run by hand when X.cm_IsFieldCrowdReleaseOk,
# X.ConsiderR or tests/test_cm_r_crowd_release.lua are edited, and before quoting
# any of that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axebhreach.sh):
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
#     present, and the armed path hands back the shipped answer -- inert in every
#     wave, and the verdict reads back "tested, no effect".
#   * M3 is the INVERSION: armed withholds exactly the crowds the note says it
#     releases, while staying gated, wired and turbo-only.
#   * M6 raises the floor from 1 to 2, which is the SUBTLE one: it makes the
#     head-count disjunct redundant with the quality disjunct it sits beside, so
#     the lever stops being "the crowd must contain someone who cannot leave" and
#     becomes "delete the head-count path".  Every gate test still passes; only
#     the removed-cell set in §3.2 can see it.
#   * M5 removes the CALL SITE.  Helper, id, note and unit tests all survive.
#   * M7 moves the conjunct onto the OTHER disjunct -- same helper, same id, same
#     gate, and the lever now narrows the path that already earns the channel
#     while leaving the defective one untouched.  It is another lever wearing
#     this one's name and its whole (c) argument.
#   * M8 is a control on the STAND ITSELF: the domain census must be able to go
#     red, or "1 of 10" is a sentence rather than a limit.
#   * M9 is the pullcad trap (AGENTS.md): conjoining a sibling id that lives in
#     the same function (cmrguard / cmrself are three helpers away) would freeze
#     this gate FALSE the day that sibling is promoted.
#   * M10 is the ANCHOR control: the 835 in the test is load-bearing, and a stand
#     that cannot see it move is not testing the reading it prints.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_r_crowd_release.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmrcrowd.XXXXXX")
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

# The filter is `cm`, not this one file: the sibling Crystal Maiden assertions
# (cmrguard / cmrself / cmrcap / cmfarcreep / cmrangedhp / cmlaneband / cmqreach)
# read the same hero module, and a stand scoped to the new file alone would
# report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua cm > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of several identical sites scores "survived" for the
# wrong reason.
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
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrcrowd' )" \
            "	if J.IsModeTurbo()"
score "M1" "gate OFF must answer the shipped"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1;
#     only the explicit non-turbo cases in 2.2 / 4.3 can see it.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrcrowd' )" \
            "	if J.IsSoakCandidate( 'cmrcrowd' )"
score "M2" "outside Turbo the helper must answer the shipped"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed withholds the crowds that DO contain
#     someone who cannot leave and releases the ones that do not.
echo
echo "=== M3: the hurt-count floor is inverted ==="
sub "$HERO" "		return nAoeCanHurtCount >= X.nRCrowdHurtFloor" \
            "		return nAoeCanHurtCount < X.nRCrowdHurtFloor"
score "M3" "armed, hurt=0 must be refused"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path hands back the shipped answer anyway.  check_armed_wiring.py
#     still says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M4: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "		return nAoeCanHurtCount >= X.nRCrowdHurtFloor" \
            "		return true"
score "M4" "armed, hurt=0 must be refused"

# ---------------------------------------------------------------------------
# M5: THE CALL SITE IS REMOVED.  The helper, its note, its id registration and
#     its unit tests all survive; branch 1 goes back to releasing on a bare head
#     count.
echo
echo "=== M5: X.ConsiderR stops routing through the helper ==="
sub "$HERO" "		if ( ( #nEnemysHeroesInRange >= 3 and X.cm_IsFieldCrowdReleaseOk( aoeCanHurtCount ) )
			 or aoeCanHurtCount >= 2 )" \
            "		if ( #nEnemysHeroesInRange >= 3 or aoeCanHurtCount >= 2 )"
score "M5" "no longer routes the head-count disjunct"

# ---------------------------------------------------------------------------
# M6: the floor is raised from 1 to 2.  Armed, the head-count disjunct then
#     implies the quality disjunct beside it, so branch 1 collapses to
#     `aoeCanHurtCount >= 2` and the lever silently becomes "delete the crowd
#     path" instead of "make the crowd path check reach".  Gate tests all pass.
echo
echo "=== M6: the hurt floor raised 1 -> 2 (the crowd path collapses) ==="
sub "$HERO" "X.nRCrowdHurtFloor = 1" "X.nRCrowdHurtFloor = 2"
score "M6" "armed, hurt=1 must pass"

# ---------------------------------------------------------------------------
# M7: THE CONJUNCT MOVES TO THE OTHER DISJUNCT.  Same helper, same id, same gate,
#     same note -- and the lever now narrows the path that already earns the
#     channel while leaving the defective one untouched.  Every gate test and
#     every wiring check still pass; only the removed-cell set can see it.
echo
echo "=== M7: the conjunct moved onto the quality disjunct ==="
sub "$HERO" "		if ( ( #nEnemysHeroesInRange >= 3 and X.cm_IsFieldCrowdReleaseOk( aoeCanHurtCount ) )
			 or aoeCanHurtCount >= 2 )" \
            "		if ( #nEnemysHeroesInRange >= 3
			 or ( aoeCanHurtCount >= 2 and X.cm_IsFieldCrowdReleaseOk( aoeCanHurtCount ) ) )"
score "M7" "no longer routes the head-count disjunct"

# ---------------------------------------------------------------------------
# M8: CONTROL ON THE STAND.  The domain census claims 1 of 10 CM frames carries
#     the shape.  Drop the pin frame out of the listed corpus: if the census
#     cannot go red, "1 of 10" is a sentence, not a limit.
echo
echo "=== M8 (control): the pin frame is dropped from the listed CM corpus ==="
sub "$TEST" "    'tests/fixtures/f_260820_043039_cm_cask_close.lua',
    'tests/fixtures/f_260820_102645_cm_es_reach.lua'," \
            "    'tests/fixtures/f_260820_102645_cm_es_reach.lua',"
score "M8" "the CM-subject frame list is 9 long"

# ---------------------------------------------------------------------------
# M9: THE PULLCAD TRAP.  Conjoin a sibling id that lives in the same function
#     family.  The gate then freezes FALSE the day cmrguard is promoted, and
#     check_armed_wiring.py still calls it WIRED.
echo
echo "=== M9: a sibling id is conjoined into the gate (pullcad trap) ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrcrowd' )" \
            "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrcrowd' ) and J.IsSoakCandidate( 'cmrguard' )"
score "M9" "must name exactly one candidate id"

# ---------------------------------------------------------------------------
# M10: CONTROL ON THE ANCHOR.  Every distance in the test rides FIELD_RADIUS 835.
#      Move it: if nothing goes red, the readings printed above were never
#      anchored to anything.
echo
echo "=== M10 (control): the 835 Liquipedia anchor is moved ==="
sub "$TEST" "local FIELD_RADIUS = 835" "local FIELD_RADIUS = 600"
score "M10" "the anchored field radius"

# ---------------------------------------------------------------------------
echo
echo "=== summary ==="
echo "$CAUGHT/$TOTAL mutants CAUGHT"
if [ "$CAUGHT" -ne "$TOTAL" ]; then
    echo "NOT ALL CAUGHT -- do not quote this stand as clean"
    exit 1
fi
exit 0
