#!/usr/bin/env bash
# Mutation stand for the 2026-09-11 double promote (test_set.md §GU):
#   `tpdeathbuy`     -> turbo default in bots/item_purchase_generic.lua
#   `liondrainstop`  -> turbo default in bots/BotLib/hero_lion.lua
# and the assertions that were FLIPPED to hold them there
# (tests/test_tpdeathbuy_dead_conjunct.lua, tests/test_replay_260819_lion_drain_stop.lua).
# Run by hand when any of those is edited.
#
# WHY ONE STAND FOR TWO IDS.  The two levers share nothing in bots/ -- different
# files, different subsystems, disjoint domains.  What they DO share is the only
# thing this stand is about: the promote-day failure modes (§DU.6's red line, the
# pullcad trap's mirror, and "the test now asks for the defect back").  Those are
# properties of the ACT, not of either lever, so scoring them together is the
# honest grouping.  Every mutant below names which id it attacks.
#
# DISCIPLINE (house rules, inherited verbatim from mutstand_slotpush.sh):
#   * out-of-tree `cp` restore, verified with `sha256sum -c` -- a stand that
#     cannot prove it put the tree back is a stand that may have eaten the fix;
#   * bare exit codes: the runner writes its log to a file and `$?` is read with
#     NO pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring as
#     caught -- a mutation that did not apply is not evidence about the tests;
#   * the baseline is proven GREEN before the first mutant (0CORP: a stand that
#     starts red reports every mutant as CAUGHT, by the red it started with).
#
# Usage: bash tools/agent/mutstand_promote_20260911.sh
set -u
cd "$(dirname "$0")/../.."

# ⚠ EVERY FILE ANY MUTANT TOUCHES MUST BE LISTED HERE, or the restore silently
#   skips it and the MUTANT STAYS IN THE WORKING TREE (GH #418).
FILES=(
    bots/item_purchase_generic.lua
    bots/BotLib/hero_lion.lua
    tests/test_tpdeathbuy_dead_conjunct.lua
    tests/test_replay_260819_lion_drain_stop.lua
)
TESTS=(
    test_tpdeathbuy_dead_conjunct
    test_replay_260819_lion_drain_stop
    test_replay_260820_lion_drain_stop_pair
    test_lion_drainstop_vision_domain
    test_gate_claim_consistency
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_pr911.XXXXXX")
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
PAIRS = {
    # ---------------------------------------------------- tpdeathbuy ----
    # M1: THE PROMOTE IS SILENTLY UNDONE.  Somebody re-gates the block on the
    #     promoted id.  Nothing looks wrong -- the header still says PROMOTED,
    #     check_armed_wiring.py would still read WIRED (it asks whether a call
    #     site exists, not whether the predicate can ever be true) -- but
    #     `tpdeathbuy` is in no armed string ever again, so the conjunct is
    #     frozen FALSE (the pullcad trap, AGENTS.md) and every real turbo game
    #     quietly returns to running the dead block.
    "M1": ("bots/item_purchase_generic.lua",
           "\tif J.IsModeTurbo() then\n\t\tbDyingWithDoomedGold = botHP < 0.08\n",
           "\tif J.IsModeTurbo() and J.IsSoakCandidate('tpdeathbuy') then\n"
           "\t\tbDyingWithDoomedGold = botHP < 0.08\n"),
    # M2: the promote loses its turbo half, so NORMAL-MODE games get it too.
    #     This repo rules on turbo only and §GU.1 bought no evidence whatsoever
    #     about normal mode.
    "M2": ("bots/item_purchase_generic.lua",
           "\tif J.IsModeTurbo() then\n\t\tbDyingWithDoomedGold = botHP < 0.08\n",
           "\tif true then\n\t\tbDyingWithDoomedGold = botHP < 0.08\n"),
    # M3: the threshold moves while the stray bound is dropped.  This lever
    #     drops ONE conjunct and nothing else; a moved threshold is a second
    #     lever riding in on the first one's evidence.
    "M3": ("bots/item_purchase_generic.lua",
           "\t\tbDyingWithDoomedGold = botHP < 0.08\n",
           "\t\tbDyingWithDoomedGold = botHP < 0.25\n"),
    # M4: the shipped default is "fixed" outright instead of behind turbo.  The
    #     non-turbo leg is what makes this promote turbo-only; deleting the
    #     stray bound from the DEFAULT ships an unmeasured change to every
    #     other game mode while every turbo-side assertion stays green.
    "M4": ("\tlocal bDyingWithDoomedGold = botHP < 0.08 and botHP >= 1\n",),
    # M5: the use site re-inlines the comparison, so the local is computed and
    #     ignored.  Declaration-side assertions stay green while the promoted
    #     branch stops deciding anything.
    "M5": ("bots/item_purchase_generic.lua",
           "\t\tand bDyingWithDoomedGold\n", "\t\tand botHP < 0.08 and botHP >= 1\n"),
    # ------------------------------------------------- liondrainstop ----
    # M6: the same silent un-promote, on the other id.
    "M6": ("bots/BotLib/hero_lion.lua",
           "\tif not J.IsModeTurbo() then return false end\n",
           "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainstop' ) )"
           " then return false end\n"),
    # M7: the turbo restriction is dropped -- every game mode releases.
    "M7": ("bots/BotLib/hero_lion.lua",
           "\tif not J.IsModeTurbo() then return false end\n", ""),
    # M8: the two-clause AND collapses to one.  Lion would break the channel on
    #     hero damage alone, with no enemy inside the danger radius -- a strictly
    #     wider lever than the one §GU.2 priced.
    "M8": ("bots/BotLib/hero_lion.lua",
           "\tif not hBot:WasRecentlyDamagedByAnyHero( 2.0 ) then return false end\n", ""),
    # M9: the danger radius is retuned under cover of the promote.  The whole
    #     point of reusing lion_IsDrainSafeToStart's constant is that a retune
    #     self-reports on BOTH sides; this checks that it actually does.
    #     ⚠ THIS MUTANT LANDS ON THE **START** GUARD (hero_lion.lua:1886), NOT
    #     THE STOP ONE, and that is deliberate now though it was an accident
    #     first.  The line is byte-identical in both guards and the replace
    #     below takes the first occurrence.  Leaving it pointed here is worth
    #     more than "fixing" it: M13 covers the stop side with a unique anchor,
    #     so the pair measures BOTH use sites instead of one twice.  The round
    #     that wrote this stand found the second unpinned site only because the
    #     mutant kept surviving a fix aimed at the other function.
    "M9": ("bots/BotLib/hero_lion.lua",
           "\tlocal nCloseEnemyList = J.GetNearbyHeroes( hBot, X.nEDrainDangerRadius,"
           " true, BOT_MODE_NONE )\n",
           "\tlocal nCloseEnemyList = J.GetNearbyHeroes( hBot, 2000,"
           " true, BOT_MODE_NONE )\n"),
    # M13: the same retune, on the STOP guard.  Anchored on the turbo test that
    #      only the promoted helper carries, so it cannot drift onto the start
    #      guard the way M9 does.
    "M13": ("bots/BotLib/hero_lion.lua",
            "\tif not J.IsModeTurbo() then return false end\n"
            "\n\tif not hBot:WasRecentlyDamagedByAnyHero( 2.0 ) then return false end\n"
            "\n\tlocal nCloseEnemyList = J.GetNearbyHeroes( hBot, X.nEDrainDangerRadius,"
            " true, BOT_MODE_NONE )\n",
            "\tif not J.IsModeTurbo() then return false end\n"
            "\n\tif not hBot:WasRecentlyDamagedByAnyHero( 2.0 ) then return false end\n"
            "\n\tlocal nCloseEnemyList = J.GetNearbyHeroes( hBot, 2000,"
            " true, BOT_MODE_NONE )\n"),
    # -------------------------------------------- the flipped assertions ----
    # M10: the [promote] case's id ban is loosened back to a tautology.
    #      ⛔ SURVIVES, AND IT IS LEFT IN THE STAND SAYING SO.  This attacks the
    #      ASSERTION, not the source -- the class mutstand_ckpush M9/M10 and
    #      mutstand_slotpush M7/M8 both recorded as structurally hard: a file
    #      cannot catch its own assertion being relaxed, and no neighbour in
    #      TESTS[] re-derives this particular ban.
    #      ⚠ WHAT IT IS *NOT*: it is not the un-promote going unnoticed.  M1 is
    #      that mutant and M1 is CAUGHT.  M10 is strictly second order -- it
    #      needs someone to re-gate the id AND relax the guard that forbids it,
    #      in the same edit.  Stated rather than papered over (§FT.4's wording,
    #      deliberately reused); deleting the mutant to make the stand read
    #      12/12 would delete the only record that this gap exists.
    #      RESIDUAL GAP, REGISTERED: nothing in this repo catches a future edit
    #      that merely loosens this ban.
    "M10": ("tests/test_tpdeathbuy_dead_conjunct.lua",
            "            assert(line:find('tpdeathbuy', 1, true) == nil,\n",
            "            assert(true,\n"),
    # M11: the non-turbo defect witness is quietly re-pointed at turbo.  It
    #      would then assert that TURBO does not clear actions -- i.e. that the
    #      promote did not happen -- and go red for the right reason.  If it
    #      does NOT go red, the witness was never witnessing.
    "M11": ("tests/test_replay_260819_lion_drain_stop.lua",
            "    local log = run_skills(FOCUSED, false, true, true, false)\n",
            "    local log = run_skills(FOCUSED, false, true, true, true)\n"),
    # M12: run_skills forgets to forward bTurbo, so every end-to-end case runs
    #      on the loader's default.  A plumbing slip that makes the non-turbo
    #      witness silently test turbo -- and this is the shape that actually
    #      happens, unlike M11's deliberate edit.
    "M12": ("tests/test_replay_260819_lion_drain_stop.lua",
            "    local X, J, bot, heroes, fx = load_lion(path, bArmed, bChanneling,"
            " bTargetHasMod, bTurbo)\n",
            "    local X, J, bot, heroes, fx = load_lion(path, bArmed, bChanneling,"
            " bTargetHasMod)\n"),
}
if mut == "M4":
    # M4 is a DELETION of a whole line, expressed as a one-tuple so it cannot be
    # confused with the replacements above.
    path = "bots/item_purchase_generic.lua"
    old = PAIRS["M4"][0]
    new = "\tlocal bDyingWithDoomedGold = botHP < 0.08\n"
else:
    path, old, new = PAIRS[mut]
src = open(path, encoding="utf-8").read()
if old not in src:
    sys.stderr.write("ABORT: %s target absent in %s\n" % (mut, path))
    sys.exit(3)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

echo "=== baseline (must be GREEN before any mutant is scored) ==="
run_tests
BASE=$?
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- every mutant below would score CAUGHT on this red."
    tail -20 "$WORK/run.log"
    restore
    exit 2
fi
echo "baseline GREEN"

CAUGHT=0; SURVIVED=0; ABORTED=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13; do
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

echo "=== $CAUGHT caught / $SURVIVED survived / $ABORTED aborted (of 13) ==="
# ⚠ M10 is a KNOWN, REGISTERED survivor (see its comment): a test file cannot
# catch its own assertion being relaxed, and no neighbour re-derives that ban.
# The stand still fails on it rather than whitelisting it -- a whitelist would
# make the gap invisible, which is the whole thing this stand exists to prevent.
# Expected reading today: 12 caught / 1 survived (M10) / 0 aborted.
[ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ]
