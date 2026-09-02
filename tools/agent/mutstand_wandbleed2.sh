#!/usr/bin/env bash
# Mutation stand for the soak candidate 'wandbleed2': J.IsWandBleedSourcePresent
# (bots/FunLib/jmz_func.lua), its single call site in the 'wandbleed' branch of
# X.ConsiderItemDesire['item_magic_wand'] (bots/ability_item_usage_generic.lua)
# and the assertions in tests/test_replay_437_wandbleed_source.lua.  Run by hand
# when any of those is edited.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418: an
#     interrupted stand otherwise leaves the MUTANT in the working tree);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant (0CORP);
#   * every mutant that would trip a SOURCE-TEXT assertion also BRIBES that
#     assertion, so "caught" means a behaviour/measurement assertion caught it
#     and not that a string pin noticed a string changing (§DJ / 0EQUIV).
#
# THE ONE EXCEPTION, DECLARED RATHER THAN HIDDEN: M1 (the call site loses the
# conjunct) is caught ONLY by the wiring pin, and it cannot be otherwise,
# because this branch has NO behavioural path in this repo.  Measured, not
# assumed: on the real jugg frame with six charges on the wand -- and with
# IsTrained/IsActivated supplied the way tests/_itemdesire_sweep.lua supplies
# them for the TP scroll -- `ItemUsageThink` logs 0 actions in all four arming
# configurations (wandbleed / wandbleed+wandbleed2, near / far).  Without the
# two bribes J.CanCastAbility(wand) is false outright.  So there is no
# end-to-end observation of ANY ConsiderItemDesire branch to attach a
# behavioural assertion to; the residual is real and belongs to the mock, not
# to this file.
#
# Usage: bash tools/agent/mutstand_wandbleed2.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    bots/FunLib/jmz_func.lua
    bots/ability_item_usage_generic.lua
    tests/test_replay_437_wandbleed_source.lua
)
TESTS=(
    test_replay_437_wandbleed_source
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wb2.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null || { echo "RESTORE FAILED"; exit 2; }
}

trap restore EXIT

run_tests() {
    local rc=0
    for t in "${TESTS[@]}"; do
        lua5.1 tests/run_tests.lua "$t" > "$WORK/run.log" 2>&1
        local one=$?
        if [ "$one" -ne 0 ]; then rc=$one; fi
    done
    return $rc
}

apply_mutant() {
    MUT="$1" python3 - <<'PY'
import os, sys

mut = os.environ["MUT"]
JMZ = "bots/FunLib/jmz_func.lua"
GEN = "bots/ability_item_usage_generic.lua"
TEST = "tests/test_replay_437_wandbleed_source.lua"

TURBO_LINE = "\tif not J.IsModeTurbo() then return true end\n\tif not J.IsSoakCandidate( 'wandbleed2' ) then return true end\n"
RING_LINE = "\treturn #J.GetNearbyHeroes( bot, 4000, true, BOT_MODE_NONE ) >= 1\n"

# Source-text pins in the test file.  A mutant that edits the shipped line a pin
# quotes must delete the pin in the same edit, or the pin -- not a behavioural
# assertion -- is what scores the catch.
PIN_TURBO = ("    assert(body:find('if not J.IsModeTurbo() then return true end', 1, true),\n"
             "        'turbo-only, and non-turbo must be the NO-OP answer')\n")
PIN_ARMED = ("    assert(body:find(\"if not J.IsSoakCandidate( 'wandbleed2' ) then return true end\", 1, true),\n"
             "        'unarmed must be the NO-OP answer -- a narrowing fails open')\n")
PIN_RING = ("    assert(body:find('J.GetNearbyHeroes( bot, 4000, true, BOT_MODE_NONE ) >= 1', 1, true),\n"
            "        'the armed answer is \"a live enemy inside 4000\"')\n")

MUTANTS = {
    # M1: the wiring goes away -- the branch is back to what GH #437 reported.
    #     Caught by the wiring pin ONLY; see the header for why no behavioural
    #     assertion can exist here today.
    "M1": [(GEN,
            "\tand bot:WasRecentlyDamagedByAnyHero(2.0)\n\tand J.IsWandBleedSourcePresent( bot )\n",
            "\tand bot:WasRecentlyDamagedByAnyHero(2.0)\n")],
    # M2: the gate goes away -- the narrowing ships to every real turbo game
    #     while every comment still calls it a soak candidate.  This is GH #418
    #     exactly, in the direction a narrowing fails: quieter, not louder.
    "M2": [(JMZ, "\tif not J.IsSoakCandidate( 'wandbleed2' ) then return true end\n", ""),
           (TEST, PIN_ARMED, "")],
    # M3: the gate loses its turbo half, so a normal-mode game can arm it.
    #     ANCHORED ON THE FUNCTION HEADER ON PURPOSE: the bare line is not
    #     unique -- J.ShouldAllowDefendTp ('teambrain') opens with the same one,
    #     it comes first in the file, and `replace(..., 1)` hit THAT.  The
    #     mutant then edited a different helper, this file's tests could not see
    #     it, and it scored SURVIVED for a reason that had nothing to do with a
    #     missing assertion.  A mutation stand whose target string is ambiguous
    #     measures the wrong function and reports it as a gap in the tests.
    "M3": [(JMZ,
            "function J.IsWandBleedSourcePresent( bot )\n\tif not J.IsModeTurbo() then return true end\n",
            "function J.IsWandBleedSourcePresent( bot )\n"),
           (TEST, PIN_TURBO, "")],
    # M4: the ring becomes the 2000 the issue suggested.  Nothing about the
    #     gating changes; the only thing that notices is the frame that MEASURED
    #     the constant -- crystal_maiden at 60 HP under a maledict from 3011.
    "M4": [(JMZ, RING_LINE, "\treturn #J.GetNearbyHeroes( bot, 2000, true, BOT_MODE_NONE ) >= 1\n"),
           (TEST, PIN_RING, "")],
    # M5: the ring is widened past every residue distance on record, so the
    #     narrowing is armed, wired, green -- and blocks nothing, ever.
    "M5": [(JMZ, RING_LINE, "\treturn #J.GetNearbyHeroes( bot, 9000, true, BOT_MODE_NONE ) >= 1\n"),
           (TEST, PIN_RING, "")],
    # M6: `>= 1` -> `>= 0`.  The predicate is now a constant TRUE wearing a
    #     measurement's clothes -- the same no-op-that-looks-armed shape the
    #     'pullcad' lesson is about, reached from the arithmetic side.
    "M6": [(JMZ, RING_LINE, "\treturn #J.GetNearbyHeroes( bot, 4000, true, BOT_MODE_NONE ) >= 0\n"),
           (TEST, PIN_RING, "")],
    # M7: the gate fails CLOSED instead of open.  Unarmed, the helper now says
    #     "no source present", so 'wandbleed' -- a candidate the desk judged
    #     WORKING -- is silently switched OFF in every wave that does not arm
    #     wandbleed2.  A narrowing's no-op answer is load-bearing.
    "M7": [(JMZ, TURBO_LINE,
            "\tif not J.IsModeTurbo() then return false end\n\tif not J.IsSoakCandidate( 'wandbleed2' ) then return false end\n"),
           (TEST, PIN_TURBO, ""), (TEST, PIN_ARMED, "")],
    # M8: the enemy flag flips, so the ring counts ALLIES.  "Is anyone near me"
    #     is not the question; "is an ENEMY near me" is.
    "M8": [(JMZ, RING_LINE, "\treturn #J.GetNearbyHeroes( bot, 4000, false, BOT_MODE_NONE ) >= 1\n"),
           (TEST, PIN_RING, "")],
    # M9: THE CENSUS GOES BLIND.  The corpus listing is pointed at a directory
    #     that does not exist, so 993 / 80 / 101 all become statements about an
    #     empty set -- and "the narrowing blocked nothing with a live attacker"
    #     would be vacuously true.  The denominators are the only thing standing
    #     here.
    "M9": [(TEST, "io.popen('ls tests/fixtures')", "io.popen('ls tests/fixturesX 2>/dev/null')")],
    # M10: the census stops asking whether the attacker is alive and calls every
    #      attacker live.  The corpus assertion that the ONLY blocked frames are
    #      ones nothing alive hit then has nothing behind it -- the measurement
    #      half of this file's claim, attacked from the data side.
    "M10": [(TEST, "                            if a.alive then live_attackers = live_attackers + 1 end",
             "                            live_attackers = live_attackers + 1")],
    # M11: the census's freshness window stops matching the shipped predicate's
    #      2.0s.  The corpus would then be measuring a different question than
    #      the one bot:WasRecentlyDamagedByAnyHero(2.0) asks, and every
    #      denominator quoted in the header and in jmz_func would be about that
    #      other question.
    "M11": [(TEST, "if d.kind == 'hero' and d.dt <= 2.0 then",
             "if d.kind == 'hero' and d.dt <= 6.0 then")],
    # M12: the ruler itself is broken -- the census's distance loses its square
    #      root, so "the furthest a live attacker gets" is measured in squared
    #      units.  The constant 4000 is read off that number; if this survives,
    #      the number is decorative.
    "M12": [(TEST, "        return math.sqrt(dx * dx + dy * dy)", "        return dx * dx + dy * dy")],
}

edits = MUTANTS[mut]
for path, old, new in edits:
    src = open(path, encoding="utf-8").read()
    if old not in src:
        sys.stderr.write("ABORT: %s target absent in %s\n" % (mut, path))
        sys.exit(3)
for path, old, new in edits:
    src = open(path, encoding="utf-8").read()
    open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

echo "=== baseline (must be GREEN before any mutant is scored) ==="
run_tests
BASE=$?
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- every mutant below would score CAUGHT on this red."
    tail -20 "$WORK/run.log"
    exit 2
fi
echo "baseline GREEN"

CAUGHT=0; SURVIVED=0; ABORTED=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12; do
    restore
    apply_mutant "$m"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ABORT   $m -- target string absent; NOT scored"
        ABORTED=$((ABORTED + 1))
        continue
    fi
    run_tests
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "CAUGHT  $m"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "SURVIVED $m  <-- an assertion is missing"
        SURVIVED=$((SURVIVED + 1))
    fi
done
restore

echo "=== $CAUGHT caught / $SURVIVED survived / $ABORTED aborted (of 12) ==="
[ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ]
