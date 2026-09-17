#!/usr/bin/env bash
# Mutation stand for tests/test_wk_q_teamfight_reach_pricing.lua -- the file
# that PRICES GH #873 §四 (X.ConsiderQ's teamfight firing point runs its argmax
# over nCastRange + 43 and never bounds the winner) and answers DO-NOT-ARM
# (hero, 2026-09-17, OWNER_PRIORITIES P4.4 (ii)).
#
# WHY A STAND FOR A FILE THAT LANDS NOTHING.  A verdict file has the same
# failure mode as a lever file and a nastier one on top: it is quoted by later
# rounds as the reason NOT to do something, so a reading it can no longer make
# is worse than a missing file.  The three legs of the verdict are a source
# arithmetic (§2), a corpus census (§3) and an attribution driven through the
# real dispatch (§4), and each of those can rot silently:
#   * M1/M2/M3 move the SHAPE the verdict is about -- the ring, how many firing
#     points share the list, whether the leg bounds its winner at all.
#   * M4/M5 move the ARITHMETIC leg 1 rests on: that +80 is one constant shared
#     by the bounded points, and that 43 is inside it.
#   * M6 is a CONTROL ON THE STAND ITSELF: a census that cannot go red is a
#     sentence, not a limit.
#   * M10 was written as a second such control and turned out to be a MEASURED
#     EQUIVALENT MUTANT -- see its block below.  It is reported, never scored,
#     and it is the reason the total reads 9 and not 10.
#   * M7 is the one that would REVIVE the candidate: it makes the teamfight
#     predicate true, which is exactly the witness frame leg 3 says the archive
#     does not hold.  If §3/§4 cannot see it, "empty domain" is unfalsifiable.
#   * M8 breaks the ATTRIBUTION: the cast is the catch-all's only because
#     X.wk_IsCatchAllOddsOk is consulted at that branch and nowhere else.
#   * M9 is the retirement guard -- a later round landing a gate here while
#     this file still reads DO-NOT-ARM.
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
TEST=tests/test_wk_q_teamfight_reach_pricing.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkqr.XXXXXX")
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

# The filter is `wk_q`, not this one file: every mutant below edits X.ConsiderQ
# or a file that reads it, and the sibling ConsiderQ assertions load the same
# hero module -- a stand scoped to the new file alone would report a collision
# there as SURVIVED.  77 cases, ~92s a run, 11 runs.
#
# ⚠️ WHY NOT `wk`, and what that costs.  The wider filter was measured first and
# is NOT affordable here: seven Wraith King tests are recorded `timed_out` in
# tools/agent/lua_gate_manifest.json (they exceed its 6s measurement cap), and a
# single `wk` run had not finished after 10 minutes -- 11 of them is a work unit
# on its own.  What `wk_q` therefore does NOT cover is the Bone Guard family
# (X.ConsiderW), the reincarnation/mana-reserve files and the level-supply
# census.  That is a real gap and it is stated rather than papered over: a
# mutant here that broke ONLY an X.ConsiderW assertion would score SURVIVED.  It
# is a narrow gap by construction -- no mutant below touches X.ConsiderW, the W
# helpers, or anything they read -- but "narrow" is an argument, not a
# measurement, and it is recorded as the former.
run_tests() {
    lua5.1 tests/run_tests.lua wk_q > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of four identical loops scores "survived" for the
# wrong reason.  This file needs the ambiguity guard badly -- X.ConsiderQ walks
# nEnemysHerosInRange from four byte-identical `for` headers.
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
# M1: THE FIX, APPLIED SILENTLY.  Somebody takes GH #873 §四 at face value and
#     tightens the search ring.  That is a behaviour change to a shipped default
#     with no gate and no wave -- and this file's entire subject disappears.
echo
echo "=== M1: the +43 search ring is tightened to the cast range ==="
sub "$HERO" "	local nEnemysHerosInRange = J.GetNearbyHeroes(bot, nCastRange + 43, true, BOT_MODE_NONE )" \
            "	local nEnemysHerosInRange = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )"
score "M1 " "search ring is no longer nCastRange + 43"

# ---------------------------------------------------------------------------
# M2: ONE OF THE FOUR SHARERS LEAVES THE LIST.  Leg 2 -- the relocation argument
#     -- is COUNTED off "four firing points walk this list".  If that count can
#     drift without anything going red, leg 2 is prose.
echo
echo "=== M2: the retreat firing point stops sharing nEnemysHerosInRange ==="
sub "$HERO" "	if J.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( nEnemysHerosInRange )" \
            "	if J.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( nEnemysHerosInBonus )"
score "M2 " "firing points, was 4"

# ---------------------------------------------------------------------------
# M3: THE LEG GROWS A DISTANCE TERM.  The absence of one IS the GH #873 §四
#     finding; a file that prices an absence must go red when it ends.
echo
echo "=== M3: the teamfight leg bounds its argmax winner after all ==="
sub "$HERO" "		if ( npcMostDangerousEnemy ~= nil )
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy" \
            "		if ( npcMostDangerousEnemy ~= nil )
			and J.IsInRange( npcMostDangerousEnemy, bot, nCastRange )
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy"
score "M3 " "now HAS a distance term"

# ---------------------------------------------------------------------------
# M4: THE TWO BOUNDED POINTS STOP SHARING ONE CONSTANT.  Leg 1 says +80 is
#     "this function's own slack".  That sentence needs there to BE one.
echo
echo "=== M4: the kill-confirm gate drifts off the shared +80 ==="
sub "$HERO" "			if GetUnitToUnitDistance( bot, npcEnemy ) <= nCastRange + 80" \
            "			if GetUnitToUnitDistance( bot, npcEnemy ) <= nCastRange + 43"
score "M4 " "no longer share one admission constant"

# ---------------------------------------------------------------------------
# M5: THE CONTAINMENT INVERTS.  Both bounded points tighten below 43, so the
#     band this candidate would refuse is no longer inside what the function
#     calls in range -- leg 1 is simply false and the candidate is repriceable.
echo
echo "=== M5: both bounded points tighten below the +43 ring ==="
sub "$HERO" "			if GetUnitToUnitDistance( bot, npcEnemy ) <= nCastRange + 80" \
            "			if GetUnitToUnitDistance( bot, npcEnemy ) <= nCastRange + 20"
sub "$HERO" "			and J.IsInRange( npcTarget, bot, nCastRange + 80 )" \
            "			and J.IsInRange( npcTarget, bot, nCastRange + 20 )"
score "M5 " "no longer inside this function"

# ---------------------------------------------------------------------------
# M6: A CONTROL ON THE STAND ITSELF.  The §3 census stops distinguishing the
#     43u band from the whole +330 ring.  If this survives, every domain number
#     quoted in §0.3 is a sentence rather than a reading.
echo
echo "=== M6: the census stops distinguishing the band from the bonus ring ==="
sub "$TEST" "                elseif d <= CAST_RANGE + eps then" \
            "                elseif d <= CAST_RANGE + bonus then"
score "M6 " "the band domain moved"

# ---------------------------------------------------------------------------
# M7: THE MUTANT THAT WOULD REVIVE THE CANDIDATE.  With the teamfight predicate
#     always true, the band-only frames DO reach firing point 3 -- the witness
#     frame leg 3 says the archive does not hold.  A stand that cannot see this
#     makes "empty domain" unfalsifiable, which is the one thing a DO-NOT-ARM
#     must never be.
echo
echo "=== M7: the teamfight predicate is always true ==="
sub "$HERO" "	if J.IsInTeamFight( bot, 1200 )" \
            "	if true"
# ⭐ THE READING THAT MATTERS IS NOT THIS `want` STRING.  The want below is §1.2's
# parse anchor, which is unique to this mutant and so makes a clean score -- but a
# parse anchor is the WEAK half (the `-197` lesson: true of the function, silent
# about the scene).  What actually answers M7's question is that §4.2 fires too,
# on the drive: with the gate forced true and the catch-all shut, the dispatch
# blasts lion anyway -- i.e. the band-only frames DO reach firing point 3 once the
# predicate lets them, which is exactly the witness leg 3 says the archive lacks.
# MEASURED 2026-09-17, this mutant against the file alone: `8 tests, 3 failures`,
# §1.2 + §4.2 + §5.  ⚠️ §3's census does NOT fire and cannot: it calls
# J.IsInTeamFight itself rather than observing the source's gate, so it measures
# the PREDICATE's domain, not the BRANCH's reachability.  That is a real limit of
# leg 3's ratchet and it is recorded here rather than hidden by the score.
score "M7 " "no longer gates on J.IsInTeamFight"

# ---------------------------------------------------------------------------
# M8: THE ATTRIBUTION BREAKS.  §4.2 pins the cast on the catch-all by shutting a
#     conjunct that lives at that branch and nowhere else.  Remove the call site
#     and shutting it proves nothing -- the cast could be any of the four.
echo
echo "=== M8: the catch-all stops consulting its own odds conjunct ==="
sub "$HERO" "		and X.wk_IsCatchAllOddsOk( allyList, nEnemysHerosInView )
" \
            ""
score "M8 " "the dispatch still blasted"

# ---------------------------------------------------------------------------
# M9: THE RETIREMENT GUARD.  A later round lands a gate on the very leg this
#     file priced DO-NOT-ARM, while this file still reads as the verdict.
echo
echo "=== M9: a soak candidate is landed on the teamfight leg ==="
sub "$HERO" "		if ( npcMostDangerousEnemy ~= nil )
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy" \
            "		if ( npcMostDangerousEnemy ~= nil )
			and not J.IsSoakCandidate( 'wkqreach' )
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy"
score "M9 " "soak candidate now sits on the"

# ---------------------------------------------------------------------------
# M10: THE SECOND CONTROL ON THE STAND.  inject() stops dropping the lazily
#      materialised method, so the injection silently does not take and every
#      §4 reading becomes a statement about tests/mock's zero defaults.  This is
#      the exact hazard §4.3 exists for; if §4.3 cannot see it, it is decoration.
echo
echo "=== M10: the injection helper drops its cache-clearing line ==="
echo "M10  EXPECTED EQUIVALENT -- not scored.  MEASURED, not assumed:"
echo "        rawget(h,'__spec')[k] = v takes effect even on an ALREADY"
echo "        materialised method, so rawset(h,k,nil) is dead defensive code."
echo "        tests/mock/bot_api.lua:188-203 -- unit_mt.__index builds the method"
echo "        once and rawsets it, but that closure reads spec[key] AT CALL TIME."
echo "        Driven on a real handle: GetCastRange reads 0, then spec-only write,"
echo "        then 525 WITHOUT dropping the cache, then 525 again after dropping."
echo "        First run of this stand scored it SURVIVED; that was the stand"
echo "        pricing a line that cannot change behaviour, not a hole in section 4.3."
echo "        ⚠️ SO THE COMMENT ON inject() IS WRONG WHEREVER IT APPEARS -- it is"
echo "        copied from tests/test_wk_q_lane_reach.lua, and the same mechanism"
echo "        claim sits at tests/mock/replay_fixture.lua:1534.  NOT edited here:"
echo "        tests/mock/ is shared and a behaviour-neutral edit to it is its"
echo "        owner's call.  Filed rather than patched."
echo "        ⛔ This is an exemption for THIS mutant on a measured ground, never"
echo "        for a no-verdict: a mutant the stand did not RUN is not equivalent."

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
