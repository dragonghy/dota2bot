#!/usr/bin/env bash
# Mutation stand for GH #418 -- the un-gated `dist < closestDist` ->
# `dist <= closestDist` that rode in with the 'slotdust' commit, its restoration
# in bots/FunLib/jmz_func.lua (J.IsClosestToDustLocation), and the three
# assertions added for it in tests/test_slotdust_dust_arbitration.lua
# ([tie], [domain price], [source-parity]).
# Run by hand when any of those is edited.
#
# WHAT THIS STAND IS ACTUALLY FOR, beyond scoring the fix. The defect it is
# built around survived a parity harness that was working correctly:
# [off-candidate] compares the live helper against a faithful transcription of
# the pre-fix body over 60 real cases, and it passed on all 60 while the tree
# carried the flipped operator -- because unarmed the scan reaches at most ONE
# dust carrier anywhere in the corpus, and `<` and `<=` cannot disagree with
# fewer than two. So M1 below is not a hypothetical: it is the exact edit that
# shipped, and the stand's job is to show the new assertions see it where the
# old one structurally could not. M6 is the follow-up question -- if the source
# check is bribed into allowing the line, does anything else still catch it?
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c` -- a stand that
#     cannot prove it put the tree back is a stand that may have eaten the fix;
#   * bare exit codes: the runner writes a log to a file and `$?` is read with
#     NO pipe in between (evidence discipline 3, mutstand_pipe_guard.sh);
#   * a mutant whose target string is absent ABORTS instead of scoring as
#     caught -- a mutation that did not apply is not evidence about the tests;
#   * the baseline is proven GREEN before the first mutant (0CORP: a stand that
#     starts red reports every mutant as CAUGHT, by the red it started with);
#   * do NOT run this in parallel with anything that reads the tree (0MUTPAR):
#     it edits bots/ in place, and a concurrent self-check will read the mutant.
#
# Usage: bash tools/agent/mutstand_dusttie.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    bots/FunLib/jmz_func.lua
    bots/ability_item_usage_generic.lua
    tests/test_slotdust_dust_arbitration.lua
)
TESTS=(
    test_slotdust_dust_arbitration
    test_slotarb_camp_arbitration
    test_gate_claim_consistency
    test_smoke_load
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_dt.XXXXXX")
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
    # M1: THE DEFECT ITSELF, verbatim -- the un-gated operator flip that GH #418
    #     found live on main. It changes who holds a tie, in unarmed games as
    #     well as armed ones, and it is invisible to [off-candidate].
    "M1": [("bots/FunLib/jmz_func.lua",
            "\t\t\tif dist < closestDist\n", "\t\t\tif dist <= closestDist\n")],
    # M2: the same line, a louder edit. `>` inverts the search from nearest to
    #     furthest -- caught by the decision assertions, and the control that
    #     tells us M1's survival was about the TIE domain, not about the line
    #     being untested in general.
    "M2": [("bots/FunLib/jmz_func.lua",
            "\t\t\tif dist < closestDist\n", "\t\t\tif dist > closestDist\n")],
    # M3: the gate becomes a no-op -- armed collapses onto shipped. The lever
    #     would then measure as "tested, no effect" in a wave (the pullcad
    #     shape) with nothing raising a hand.
    "M3": [("bots/FunLib/jmz_func.lua",
            "\t\tif bSlotDust then nSlot = i end\n", "\t\tif false then nSlot = i end\n")],
    # M4: the fix stops being dark -- the slot scan runs whether or not the
    #     candidate is armed. This is the one thing a gated fix may never do,
    #     and it is a ONE-WORD edit away at all times.
    "M4": [("bots/FunLib/jmz_func.lua",
            "\t\tlocal nSlot = id\n", "\t\tlocal nSlot = i\n")],
    # M5: the [tie] frame stops being a tie -- the location moves onto one
    #     carrier. Scores whether that test asserts a tie or merely assumes one;
    #     the premise assertion (dES == dJA) is what must fire.
    "M5": [("tests/test_slotdust_dust_arbitration.lua",
            "    local mid = Vector((pa.x + pb.x) / 2, (pa.y + pb.y) / 2, (pa.z + pb.z) / 2)\n",
            "    local mid = Vector(pa.x, pa.y, pa.z)\n")],
    # M6: DEFENCE IN DEPTH. Re-apply the real defect (M1) AND bribe the source
    #     check into allowing it, by listing the flipped line as gate-owned.
    #     [source-parity] now passes by construction; if the stand still catches
    #     this, the catch belongs to [tie] -- i.e. the behavioural assertion is
    #     not decorative on top of the textual one.
    "M6": [("bots/FunLib/jmz_func.lua",
            "\t\t\tif dist < closestDist\n", "\t\t\tif dist <= closestDist\n"),
           ("tests/test_slotdust_dust_arbitration.lua",
            "    'local member = GetTeamMember(nSlot)',\n",
            "    'local member = GetTeamMember(nSlot)',\n    'if dist <= closestDist',\n"),
           ("tests/test_slotdust_dust_arbitration.lua",
            "    'local member = GetTeamMember(id)',\n",
            "    'local member = GetTeamMember(id)',\n    'if dist < closestDist',\n")],
    # M7: the corpus histogram is edited to claim the discriminating input
    #     EXISTS unarmed (shipped[2] == 1). The [domain price] reading is the
    #     load-bearing half of this round's argument -- if it can be restated
    #     freely, it is prose, not a measurement.
    "M7": [("tests/test_slotdust_dust_arbitration.lua",
            "    assert(shipped[0] == 101 and shipped[1] == 6 and shipped[2] == nil,\n",
            "    assert(shipped[0] == 101 and shipped[1] == 6 and shipped[2] == 1,\n")],
}
edits = PAIRS[mut]
for path, old, new in edits:
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
for m in M1 M2 M3 M4 M5 M6 M7; do
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

echo "=== $CAUGHT caught / $SURVIVED survived / $ABORTED aborted (of 7) ==="
[ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ]
