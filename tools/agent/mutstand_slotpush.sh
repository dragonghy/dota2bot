#!/usr/bin/env bash
# Mutation stand for the soak candidate 'slotpush' (GH #415): the pid-vs-slot
# fix in bots/FunLib/utils.lua (IsTeamPushingSecondTierOrHighGround), its one
# gate-resolution wrapper J.IsTeamPushingHighGround in bots/FunLib/jmz_func.lua,
# and the assertions in tests/test_slotpush_highground_scan.lua.
# Run by hand when any of those is edited.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c` -- a stand that
#     cannot prove it put the tree back is a stand that may have eaten the fix;
#   * bare exit codes: the runner writes a log to a file and `$?` is read with
#     NO pipe in between (evidence discipline 3, mutstand_pipe_guard.sh);
#   * a mutant whose target string is absent ABORTS instead of scoring as
#     caught -- a mutation that did not apply is not evidence about the tests;
#   * the baseline is proven GREEN before the first mutant (0CORP: a stand that
#     starts red reports every mutant as CAUGHT, by the red it started with).
#
# Usage: bash tools/agent/mutstand_slotpush.sh
set -u
cd "$(dirname "$0")/../.."

# ⚠ EVERY FILE ANY MUTANT TOUCHES MUST BE LISTED HERE, or the restore silently
#   skips it and the MUTANT STAYS IN THE WORKING TREE -- the GH #418 hazard the
#   trap below is about, reached from the other direction. Measured 2026-09-07:
#   M14 was added targeting tests/test_slotpush_highground_scan.lua while this
#   list still lacked it, and the mutant survived the run, the trap, and the
#   final restore. The next run then read BASELINE RED and, had it not, the next
#   `git add -A` would have committed it. The backup is keyed off this list, so
#   a mutant's target file being absent from it is not a smaller mistake than a
#   missing trap -- it is the same one.
FILES=(
    bots/FunLib/utils.lua
    bots/FunLib/jmz_func.lua
    bots/mode_ward_generic.lua
    typescript/bots/FunLib/utils.ts
    tests/test_slotarb_camp_arbitration.lua
    tests/test_slotpush_highground_scan.lua
)
TESTS=(
    test_slotpush_highground_scan
    test_slotarb_camp_arbitration
    test_slotdust_dust_arbitration
    test_gated_helper_nesting_census
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_sp.XXXXXX")
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

# A stand that is interrupted between `apply_mutant` and `restore` leaves the
# MUTANT in the working tree, where the next `git add -A` commits it. That is
# not hypothetical: see GH #418 and iterations/state.json:slotdust_gh418_20260902
# -- an un-gated `<` -> `<=` reached main as part of a gated fix, and the round's
# own mutation log names that exact edit as a mutant it had applied. The trap
# makes the restore unconditional; the loop still calls restore explicitly, which
# is harmless because restore is idempotent.
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
    # M1: revert the fix itself -- armed goes back to the player id.
    "M1": ("bots/FunLib/utils.lua",
           "                    nSlot = i\n", "                    nSlot = playerdId\n"),
    # M2: arm unconditionally.  The lever stops being dark; [off-candidate
    #     equivalence] is the only thing standing between this and a shipped
    #     behaviour change nobody voted for.
    "M2": ("bots/FunLib/utils.lua",
           "                if bSlotPush then\n", "                if true then\n"),
    # M3: drop the memo fork.  Both legs share a cache key again, so whichever
    #     is called first in a given second answers for the other too.
    "M3": ("bots/FunLib/utils.lua",
           '        cacheKey = cacheKey .. "byslot"\n', "        cacheKey = cacheKey\n"),
    # M4: an off-by-one INSIDE the fix -- armed scans slots 2..6 instead of
    #     1..5, which still "scans more" on radiant and would read as a win to
    #     anything that only counted members.
    "M4": ("bots/FunLib/utils.lua",
           "                    nSlot = i\n", "                    nSlot = i + 1\n"),
    # M5: the plausible ALTERNATIVE fix -- move the guard instead of the
    #     accessor.  Armed it is equivalent; UN-armed it silently changes the
    #     shipped answer, which is the one thing a dark lever may never do.
    "M5": ("bots/FunLib/utils.lua",
           "            if IsHeroAlive(playerdId) then\n",
           "            if IsHeroAlive(nSlot) then\n"),
    # ---- M6/M7/M8 RE-ANCHORED 2026-09-07 BY THE PROMOTE (test_set.md §FT). ----
    # All three used to target the gate conjunction
    # `J.IsModeTurbo() and J.IsSoakCandidate( 'slotpush' )`.  That string no
    # longer exists, so left alone all three would ABORT -- scoring nothing while
    # the stand still printed a verdict, which is the GH #550 / mutstand_ckpush
    # M11 shape (an anchor that no longer matches changes nothing and the stand
    # keeps talking).  They now attack the promoted form.
    #
    # M6: the wrapper loses its turbo half, so NORMAL-MODE games get the repair
    #     too.  This repo rules on turbo only, and §FT bought no evidence
    #     whatsoever about normal mode; the flag parameter is kept downstream
    #     precisely so the non-turbo leg can stay byte-identical to what the tree
    #     inherited from upstream OHA.
    "M6": ("bots/FunLib/jmz_func.lua",
           "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot, J.IsModeTurbo() )\n",
           "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot, true )\n"),
    # M7: ⭐ THE PROMOTE IS SILENTLY UNDONE.  Somebody re-gates the wrapper on the
    #     promoted id.  Nothing looks wrong -- the header still says PROMOTED and
    #     check_armed_wiring.py still reads WIRED, because it asks whether a call
    #     site exists, not whether the predicate can ever be true -- but
    #     `slotpush` is in no armed string ever again, so the conjunct is frozen
    #     FALSE (the `pullcad` trap, AGENTS.md) and every real turbo game quietly
    #     returns to the shipped pid-shaped scan.
    #     ⛔ CAUGHT BY A SOURCE-TEXT ASSERTION, AND THAT IS A LIMITATION.  House
    #     rule is to bribe the string pin so "CAUGHT" means a behaviour assertion
    #     caught it.  Here that is impossible and it was MEASURED, not assumed:
    #     the bribed version of this mutant was run first and SURVIVED, because
    #     the fixture corpus never flips this decision (nFlip == 0 over 94
    #     subject-loads -- the [domain price] premise), so shipped and by-slot
    #     answer identically on every frame this repo owns and no behavioural
    #     assertion over this corpus can separate them.  Recorded in full at
    #     test_set.md §FT.4 and above the [promote] case in the test file.
    "M7": ("bots/FunLib/jmz_func.lua",
           "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot, J.IsModeTurbo() )\n",
           "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot,\n"
           "\t\tJ.IsModeTurbo() and J.IsSoakCandidate( 'slotpush' ) )\n"),
    # M8: the wrapper accepts the job and drops the flag -- still the pullcad
    #     shape (wired, called, inert), and post-promote it is also the plain
    #     REVERT: bSlotPush arrives nil, so turbo is back on the shipped scan
    #     while every comment in the tree says the lever shipped.
    "M8": ("bots/FunLib/jmz_func.lua",
           "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot, J.IsModeTurbo() )\n",
           "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot )\n"),
    # M13: [ADDED BY THE PROMOTE] THE MODE SELECTION IS INVERTED -- turbo keeps
    #      the defect and normal mode gets the repair.  The tree reads exactly as
    #      intended and every corpus battery agrees (see M7 on why).  Caught by
    #      the same string pin, with the same caveat.
    "M13": ("bots/FunLib/jmz_func.lua",
            "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot, J.IsModeTurbo() )\n",
            "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot, not J.IsModeTurbo() )\n"),
    # M14: [ADDED BY THE PROMOTE] THE [domain price] RATCHET LOSES ITS SUBJECT.
    #      That ratchet is the only thing in this repo that will ever announce a
    #      fixture capable of separating the two legs -- and by M7/M13 above it is
    #      therefore the only route by which this lever can ever acquire a real
    #      behavioural guard.  This drops the single subject-load in the whole
    #      corpus where either leg answers TRUE, so the ratchet would be watching
    #      an all-FALSE corpus and notice nothing ever again.
    #      ⚠ ATTACKED FROM THE DATA SIDE ON PURPOSE.  The first draft bribed the
    #      flip counter itself (`if shipped ~= armed` -> `if false`) and SURVIVED:
    #      `nFlip == 0` cannot detect its own instrument being switched off,
    #      because zero is what it asserts.  Same class as mutstand_ckpush.sh
    #      M9/M10 -- a file cannot catch its own assertion being loosened.
    #      ⛔ RESIDUAL GAP, STATED RATHER THAN PAPERED OVER: nothing in this repo
    #      catches a future edit that merely relaxes `nFlip == 0` or `nTrue == 1`.
    "M14": ("tests/test_slotpush_highground_scan.lua",
            "        for _, name in pairs(subs) do\n",
            "        for _, name in pairs(path:find('es_blink_init_621', 1, true) and {} or subs) do\n"),
    # M9: one mode script goes back around the wrapper.  Six of seven call
    #     sites still gated; this is the miss the single-wrapper rule exists
    #     to make impossible to hide.
    "M9": ("bots/mode_ward_generic.lua",
           "\tif J.IsTeamPushingHighGround(bot) then\n",
           "\tif J.Utils.IsTeamPushingSecondTierOrHighGround(bot) then\n"),
    # M10: the TypeScript source drifts from the Lua it generates.
    "M10": ("typescript/bots/FunLib/utils.ts",
            "GetTeamMember(bSlotPush ? i : playerdId)", "GetTeamMember(playerdId)"),
    # M11: the one-lever ratchet stops moving -- the count claims a site that has
    #      already been converted is still pid-shaped.
    # ⚠ RE-ANCHORED 2026-09-07, AND THE RE-ANCHOR IS THE POINT.  The old target
    #   was `assert(pidShaped == 7,`.  That 7 became 5 on 2026-09-03 when the
    #   'slotwait' lever converted the last two live utils.lua sites, so the
    #   target string went ABSENT and M11 has been ABORTing ever since -- scoring
    #   nothing, taking this stand's exit code to 1, while the round that read it
    #   still had 12 mutants' worth of confidence.  Identical to what
    #   mutstand_ckpush.sh M11 recorded on the same date, from a different cause:
    #   THE RATCHET'S OWN NUMBER IS A MOVING ANCHOR, so any mutant that pins it
    #   goes stale the next time the ratchet legitimately moves.  Caught here only
    #   because ABORT is scored separately from CAUGHT -- if a stale mutant scored
    #   as caught, neither round would have noticed.
    "M11": ("tests/test_slotarb_camp_arbitration.lua",
            "    assert(pidShaped == 5,", "    assert(pidShaped == 6,"),
    # M12: the predicate stops looking at the roster at all and answers off the
    #      subject alone.  A "simplification" that passes any test which only
    #      checks that armed and shipped differ.
    "M12": ("bots/FunLib/utils.lua",
            "                local teamMember = GetTeamMember(nSlot)\n",
            "                local teamMember = bot\n"),
}
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
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13 M14; do
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

echo "=== $CAUGHT caught / $SURVIVED survived / $ABORTED aborted (of 14) ==="
[ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ]
