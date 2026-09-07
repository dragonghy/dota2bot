#!/usr/bin/env bash
# Mutation stand for backlog -115 -- the FIRST early return in X.ConsiderE,
# measured and split into its two halves (hero, 2026-09-07, OWNER_PRIORITIES
# P4.4(ii)).  Run by hand when
# tests/test_lion_considere_earlyreturn_domain.lua, hero_lion.lua's X.ConsiderE
# / X.IsOtherAbilityFullyCastable, the fixture loader's GetNearby* wiring, or
# any Lion fall-through frame is edited -- and before quoting any of that
# file's readings.
#
# WHAT THIS ONE HAS TO PROTECT.  Like -114's stand, this round landed no lever
# and no gate, so there is nothing in bots/ to mutate for behaviour.  What needs
# guarding is a READING plus a NON-DECISION, and they rot differently:
#
#   * the FUNNEL is really reading frames, not restating a constant  -> M1, M2
#   * the SPLIT (castability 15 : level 1) is the round's answer     -> M2, M3
#   * the CEILING's structural premise (lever is downstream)         -> M4, M5
#   * the ABSENCE of a lever on this line                            -> M6, M7
#   * bound (C): the creep zero is the MOCK's, and knows it          -> M8, M9
#   * bound (D): names read here vs indices bound there              -> M10
#
# THE FOUR WORTH READING:
#   * M1 IS THE FUNNEL'S ANTI-TAUTOLOGY.  Every integer in the header is
#     supposed to come off real frames.  Move ONE ability's cooldown on ONE
#     fall-through frame and the counts must move with it -- otherwise the
#     funnel is a hardcoded table wearing a loader.
#   * M6 IS THE REVIVAL TRIPWIRE, and it is the mirror of -114's M9.  Somebody
#     reads this round, disagrees that the line is designed-correct, and gates
#     it.  The round's verdict is that widening this line hands a stationary
#     channel the frames on which Lion still has a disable up, so taking it must
#     go RED and say so, not pass quietly because nothing tested a decision to
#     do nothing.
#   * M8 IS THE ONE THAT CAUGHT A LIVE ERROR IN THE REPO.  Bound (C) says the
#     refill branch's zero comes from the LOADER not wiring GetNearbyCreeps, not
#     from the dumper schema (which is what test_lion_drain_refill_domain.lua
#     records).  Wire it and the file must announce that -114's NOT TAKEN and
#     this file's ceiling both need re-reading.
#   * M4 IS THE CEILING'S PREMISE.  3/27 is a ceiling on `liondrainmi` ONLY
#     because its call site is below the line.  Move it above and the number
#     must stop being quotable.
#
# DISCIPLINE (inherited from tools/agent/mutstand_liondrainrefill.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never
#     score "caught" for having applied to nothing (GH #550);
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507) -- the hero desk did exactly that on 2026-09-07T07:5xZ and had
# to throw the first reading away.
#
# Usage: bash tools/agent/mutstand_lionearlyreturn.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
LOADER=tests/mock/replay_fixture.lua
BOTAPI=tests/mock/bot_api.lua
FRAME=tests/fixtures/f_260819_182323_lion_drain_calm.lua
TEST=tests/test_lion_considere_earlyreturn_domain.lua

FILES=("$HERO" "$LOADER" "$BOTAPI" "$FRAME" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lionearlyreturn.XXXXXX")
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

# The filter is `lion`, not this one file: test_lion_drain_refill_domain.lua and
# test_lion_drain_combat_widen.lua read the same source region and the same
# frames, and a stand scoped to the new file alone would report a collision
# there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua lion > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort on an absent OR ambiguous anchor.
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

# ⚠️ TAB-PREFIXED ON PURPOSE.  hero_lion.lua's t10 talent note quotes this
# line verbatim inside a comment ~980 lines above the code, so the bare
# string is AMBIGUOUS and sub() (correctly) aborts on it -- which scored
# M3/M4/M6 as SURVIVED on the first run of this stand.  The leading tab is
# what tells the statement from the quotation.
EARLY_RETURN=$'\tif X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0 end'
HELPER_BODY='return abilityQ:IsFullyCastable() or abilityW:IsFullyCastable() or abilityR:IsFullyCastable()'
CALLSITE=$'\t\t\tand X.lion_IsDrainCombatTargetCastable( botTarget )'
# M4 hoists the call site above the line; as a bare `and ...` continuation it
# would not parse, so it is hoisted as a standalone statement instead. What the
# mutant has to move is the OFFSET of the call, which this does.
CALLSITE_BARE='local _hoisted = X.lion_IsDrainCombatTargetCastable( botTarget )'
SAFE_START='	if not X.lion_IsDrainSafeToStart( bot ) then return 0 end'
BIND_R='local abilityR = bot:GetAbilityByName( sAbilityList[6] )'
CALM_IMPALE="{ name = 'lion_impale', level = 2, cd = 6.5 }"
CALM_DRAIN="{ name = 'lion_mana_drain', level = 2, cd = 0 }"
NEARBY_DEFAULT="if key:find('^GetNearby') then return {} end"
LOADER_TOWERS='            spec.GetNearbyTowers = nearby_structures('"'"'tower'"'"')'

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
# M1: THE FUNNEL'S ANTI-TAUTOLOGY.  Take Impale off cooldown on one of the three
#     fall-through frames.  That frame stops falling through, so the funnel's
#     bottom row must move 3 -> 2.  If it does not, the header's integers are a
#     table, not a reading.
echo
echo "=== M1: Impale comes off cooldown on a fall-through frame (3 -> 2) ==="
sub "$FRAME" "$CALM_IMPALE" "{ name = 'lion_impale', level = 2, cd = 0 }"
# The message is bound (A)'s, not section 1's: removing a fall-through frame
# moves BOTH counts, and the runner reports that assertion first. Either way
# the signal is funnel-derived, which is what M1 exists to prove.
score "M1 " "fall-through instants are"

# ---------------------------------------------------------------------------
# M2: THE SPLIT'S TRIPWIRE, level side.  Drop Mana Drain to rank 1 on the same
#     frame.  The level half now rejects an instant it did not reject, so the
#     marginal split (15 : 1) -- the round's actual answer -- must move.
echo
echo "=== M2: Mana Drain drops to rank 1 on a fall-through frame ==="
sub "$FRAME" "$CALM_DRAIN" "{ name = 'lion_mana_drain', level = 1, cd = 0 }"
score "M2 " "the level clause"

# ---------------------------------------------------------------------------
# M3: the castability half is REMOVED from the shipped predicate, leaving the
#     level half alone.  Section 6's second assertion exists for exactly this:
#     rewriting the line in place is the OTHER way to make the round's
#     NOT-TAKEN silently false (the first being to gate it -- M6).
echo
echo "=== M3: the castability half is deleted from the early return ==="
sub "$HERO" "$EARLY_RETURN" $'\tif nSkillLV <= 1 then return 0 end'
# M3 deletes the castability half, so the line no longer matches the exact
# text early_return_offset() resolves on. The message that names WHAT changed
# is section 6's line-based one, which survives a rewrite of the predicate.
score "M3 " "CODE line calling X.IsOtherAbilityFullyCastable"

# ---------------------------------------------------------------------------
# M4: THE CEILING'S PREMISE.  Hoist the widened branch's call site ABOVE the
#     early return.  3/27 is a ceiling on `liondrainmi` only while it is below.
echo
echo "=== M4: the liondrainmi call site is hoisted above the early return ==="
sub "$HERO" "$EARLY_RETURN" $'\t'"$CALLSITE_BARE"$'\n'"$EARLY_RETURN"
score "M4 " "is now called ABOVE"

# ---------------------------------------------------------------------------
# M5: one of the three conjuncts between the line and the branch is deleted.
#     The header calls the ceiling "strictly" loose on the strength of all
#     three; drop one and that adverb has to stop being asserted.
echo
echo "=== M5: X.lion_IsDrainSafeToStart is dropped from between line and branch ==="
sub "$HERO" "$SAFE_START" ''
score "M5 " "no longer sits between"

# ---------------------------------------------------------------------------
# M6: THE REVIVAL TRIPWIRE.  Somebody gates the line to widen it.  This round
#     ruled the line designed-correct; taking it must go red and say why.
echo
echo "=== M6: a soak-candidate gate is put on the early return ==="
sub "$HERO" "$EARLY_RETURN" \
    $'\tif ( X.IsOtherAbilityFullyCastable() and not J.IsSoakCandidate( \'lionearly\' ) ) or nSkillLV <= 1 then return 0 end'
score "M6 " "soak-candidate gate on ConsiderE"

# ---------------------------------------------------------------------------
# M7: the helper stops being the three-way disjunction every count was taken on
#     -- here by dropping Finger, the term section 3 measured as the rarest.
echo
echo "=== M7: Finger is dropped from X.IsOtherAbilityFullyCastable ==="
sub "$HERO" "$HELPER_BODY" 'return abilityQ:IsFullyCastable() or abilityW:IsFullyCastable()'
score "M7 " "three-way disjunction"

# ---------------------------------------------------------------------------
# M8: BOUND (C)'s TRIPWIRE, and the reason this stand exists at all.  The
#     fixture loader starts mentioning GetNearbyCreeps.  The creep zero stops
#     being the mock's blanket default, and THREE readings need re-reading --
#     -114's NOT TAKEN, this file's ceiling, and the cause sentence in
#     test_lion_drain_refill_domain.lua that blames the dumper schema.
echo
echo "=== M8: the fixture loader starts wiring GetNearbyCreeps ==="
sub "$LOADER" "$LOADER_TOWERS" "$LOADER_TOWERS"$'\n            spec.GetNearbyCreeps = function() return {} end'
score "M8 " "now mentions GetNearbyCreeps"

# ---------------------------------------------------------------------------
# M9: the blanket default itself is removed from bot_api.  Then the zero has no
#     explanation in this repo at all, and bound (C)'s attribution is void even
#     though the sum is unchanged.  This is the mutant that separates "the
#     number is 0" from "we know why it is 0".
echo
echo "=== M9: bot_api's blanket GetNearby* default is removed ==="
sub "$BOTAPI" "$NEARBY_DEFAULT" "if key:find('^GetNearbyXX') then return {} end"
# Removing the blanket default makes GetNearbyCreeps answer the NUMBER 0
# (bot_api's generic `^Get` fallback). On the stand's first run that raised
# "attempt to get length of a number" out of the funnel in seven tests at once
# and buried section 7's sentence; the test file now asserts the wiring BEFORE
# it reads any frame, and count_creeps() names the cause instead of raising.
score "M9 " "no longer answers unwired"

# ---------------------------------------------------------------------------
# M10: BOUND (D).  This file reads abilities by NAME; the shipped file binds by
#      INDEX.  Re-point the ult's binding and the bridge between the two must
#      collapse rather than silently measuring a different ability.
echo
echo "=== M10: abilityR is re-pointed from sAbilityList[6] to [5] ==="
sub "$HERO" "$BIND_R" 'local abilityR = bot:GetAbilityByName( sAbilityList[5] )'
score "M10" "no longer bound to sAbilityList"

# ---------------------------------------------------------------------------
echo
echo "=== restore check ==="
restore
sha256sum -c "$WORK/sum.txt" > /dev/null && echo "tree restored, checksums match"
echo
echo "SCORE: $CAUGHT/$TOTAL caught"
# Disarm BEFORE removing $WORK: otherwise the EXIT trap runs restore() a
# second time against a directory that is already gone and prints
# "RESTORE FAILED" over a tree that was in fact restored correctly.
trap - EXIT
rm -rf "$WORK"
[ "$CAUGHT" -eq "$TOTAL" ]
