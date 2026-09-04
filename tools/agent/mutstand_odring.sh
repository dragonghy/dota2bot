#!/usr/bin/env bash
# Mutation stand for tests/test_od_eclipse_ring_conjunct_domain.lua -- the
# GH #488 source-level answer (hero, 2026-09-04).  Run by hand when that file,
# X.ConsiderSanitysEclipse's shipped loop, or the loader's GetNearbyHeroes is
# edited, and before quoting any of its readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusboltdom.sh):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS FOR.  This file's whole claim is that ONE COMPARISON
# OPERATOR decides GH #488's frame: `#nInRangeAlly >= #nTargetInRangeAlly` is a
# `>=`, so with an isolated enemy both sides are the same number and the
# conjunct is TRUE -- including, and especially, when OD has zero allies.  Every
# case in the file is worthless if it would pass with that operator changed, so
# M1 is the mutant the stand exists for.  M2/M3 attack the OTHER half of the
# argument (that (K), not (R), is the barrier).  M4 is the return-value fact
# GH #488's own non-hero-centre discriminator rests on.  M5/M6 are controls on
# the INSTRUMENT rather than the code: they check that the file's numbers come
# from driving the frame and not from arithmetic copied into the assertions.
#
# Usage: bash tools/agent/mutstand_odring.sh
set -u
cd "$(dirname "$0")/../.."

TEST=tests/test_od_eclipse_ring_conjunct_domain.lua
HERO=bots/BotLib/hero_obsidian_destroyer.lua
MOCK=tests/mock/replay_fixture.lua

FILES=("$TEST" "$HERO" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_odring.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_od_eclipse_ring_conjunct_domain > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex), and abort if the anchor is gone -- a mutant
# that silently applied to nothing scores "caught" for the wrong reason.
#
# ...AND ABORT IF THE ANCHOR IS NOT UNIQUE, which is not a theoretical hazard
# here: hero_obsidian_destroyer.lua contains the SAME ally-ring comparison
# THREE times (:242 in the arcane-orb handler, :403, :558 in the eclipse), so
# the first draft of M1/M2 below mutated the arcane orb and scored SURVIVED --
# a clean exit 0 that looked exactly like "the file cannot see its own subject".
# `replace(..., 1)` hitting the wrong one of N identical sites is invisible from
# the score line, so uniqueness is checked rather than assumed.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
n = s.count(old)
if n == 0:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
if n > 1:
    sys.stderr.write("ANCHOR NOT UNIQUE in %s (%d sites): %r\n" % (f, n, old[:70]))
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
# M1: THE MUTANT THIS STAND EXISTS FOR.  `>=` becomes `>`.  That is exactly the
#     predicate GH #488 assumed it was reading: a strict majority, which a lone
#     OD can never satisfy against anyone.  If the file cannot see this, its
#     whole finding is unfalsifiable.
echo
echo "=== M1: the ring conjunct becomes a STRICT majority (#488's implicit reading) ==="
sub "$HERO" 'and #nInRangeAlly >= #nTargetInRangeAlly
                and J.CanKillTarget(enemyHero,' \
            'and #nInRangeAlly > #nTargetInRangeAlly
                and J.CanKillTarget(enemyHero,'
score "M1" "it casts: 1 >= 1. The conjunct never asked for a majority."

# ---------------------------------------------------------------------------
# M2: the ring conjunct is deleted outright.  Only 2d can see this: it is the
#     one case in the file where (R) is the thing that refuses.  The first draft
#     of this file had no such case -- every case ran on a topology where (R)
#     was true -- so deleting the conjunct changed nothing and M2 scored
#     SURVIVED.  2d/2e exist because of that hole.
echo
echo "=== M2: the ring conjunct is removed from the shipped loop ==="
sub "$HERO" 'and #nInRangeAlly >= #nTargetInRangeAlly
                and J.CanKillTarget(enemyHero, nBaseDamage + nDamage, DAMAGE_TYPE_MAGICAL)' \
            'and J.CanKillTarget(enemyHero, nBaseDamage + nDamage, DAMAGE_TYPE_MAGICAL)'
score "M2" "no cast: 0 >= 1 is FALSE"

# ---------------------------------------------------------------------------
# M3: the kill-confirm is deleted instead.  This is the complement of M2 and it
#     is what proves the file's central claim is a claim about (K): with (K)
#     gone the shipped exit must fire on the untouched frame, where it refuses.
echo
echo "=== M3: the kill-confirm (K) is removed from the shipped loop ==="
sub "$HERO" 'and J.CanKillTarget(enemyHero, nBaseDamage + nDamage, DAMAGE_TYPE_MAGICAL)
                then' \
            'then'
score "M3" "so the shipped exit casts nothing"

# ---------------------------------------------------------------------------
# M4: the shipped branch returns OD's OWN location instead of the enemy's.
#     GH #488 builds its strongest discriminator (">=2 hero victims that no
#     enemy-centred circle covers") on the source fact that the shipped centre
#     is always ON an enemy hero.  If that fact drifts, the discriminator
#     silently stops meaning what the issue says it means.
echo
echo "=== M4: the shipped centre moves off the enemy hero ==="
sub "$HERO" 'return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()' \
            'return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()'
score "M4" "and the circle is centred exactly on the enemy hero"

# ---------------------------------------------------------------------------
# M5: INSTRUMENT CONTROL.  The loader stops excluding the querying unit from its
#     own GetNearbyHeroes result, i.e. it switches to the OTHER self-convention.
#     Section 2b claims the finding is invariant under that switch; sections 1b
#     and 2 quote ring SIZES, which are not.  A stand that scored this "caught"
#     without saying which half moved would be hiding the distinction, so the
#     expected message is the ring-size one.
echo
echo "=== M5: the loader counts the querying unit inside its own ring ==="
sub "$MOCK" 'if other ~= self and v.alive' 'if v.alive'
score "M5" "OD really does have 3 allies inside 1200 here"

# ---------------------------------------------------------------------------
# M6: INSTRUMENT CONTROL, the important one.  The test's own KV supply for
#     base_damage is bumped past the box.  If section 4's verdict came from
#     arithmetic transcribed into the assertions rather than from driving the
#     real predicate, this changes nothing.  It must change section 4.
echo
echo "=== M6: the test supplies a base_damage far outside the datafeed box ==="
sub "$TEST" 'local KV_BASE_DAMAGE_MAX   = 400' \
            'local KV_BASE_DAMAGE_MAX   = 2600'
score "M6" "best-case raw damage 903.2"

# ---------------------------------------------------------------------------
echo
echo "=== SCORE: $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || echo "(a SURVIVED line above is a hole in the file, not a pass)"
