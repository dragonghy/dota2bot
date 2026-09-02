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

FILES=(
    bots/FunLib/utils.lua
    bots/FunLib/jmz_func.lua
    bots/mode_ward_generic.lua
    typescript/bots/FunLib/utils.ts
    tests/test_slotarb_camp_arbitration.lua
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
    # M6: the wrapper loses its turbo half.
    "M6": ("bots/FunLib/jmz_func.lua",
           "\t\tJ.IsModeTurbo() and J.IsSoakCandidate( 'slotpush' ) )\n",
           "\t\tJ.IsSoakCandidate( 'slotpush' ) )\n"),
    # M7: the wrapper hard-arms.  Reads as "the gate is right there" to a grep
    #     and to check_armed_wiring.py alike.
    "M7": ("bots/FunLib/jmz_func.lua",
           "\t\tJ.IsModeTurbo() and J.IsSoakCandidate( 'slotpush' ) )\n",
           "\t\ttrue )\n"),
    # M8: the wrapper accepts the job and drops the flag -- the pullcad shape:
    #     wired, armed, inert.
    "M8": ("bots/FunLib/jmz_func.lua",
           "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot,\n"
           "\t\tJ.IsModeTurbo() and J.IsSoakCandidate( 'slotpush' ) )\n",
           "\treturn J.Utils.IsTeamPushingSecondTierOrHighGround( bot )\n"),
    # M9: one mode script goes back around the wrapper.  Six of seven call
    #     sites still gated; this is the miss the single-wrapper rule exists
    #     to make impossible to hide.
    "M9": ("bots/mode_ward_generic.lua",
           "\tif J.IsTeamPushingHighGround(bot) then\n",
           "\tif J.Utils.IsTeamPushingSecondTierOrHighGround(bot) then\n"),
    # M10: the TypeScript source drifts from the Lua it generates.
    "M10": ("typescript/bots/FunLib/utils.ts",
            "GetTeamMember(bSlotPush ? i : playerdId)", "GetTeamMember(playerdId)"),
    # M11: the one-lever ratchet stops moving -- the count says three levers
    #      have landed while the cluster still claims eight sites.
    "M11": ("tests/test_slotarb_camp_arbitration.lua",
            "    assert(pidShaped == 7,", "    assert(pidShaped == 8,"),
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
