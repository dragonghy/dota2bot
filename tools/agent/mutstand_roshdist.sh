#!/usr/bin/env bash
# Mutation stand for the soak candidate 'roshdist': the dropped comparison in
# bots/mode_retreat_generic.lua:426, its worker + one gate-resolution wrapper in
# bots/FunLib/jmz_func.lua (J.RoshanPitProximity / J.IsAtRoshanPit), and the
# assertions in tests/test_roshdist_pit_truth_operand.lua.
# Run by hand when any of those is edited.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c` -- a stand that
#     cannot prove it put the tree back is a stand that may have eaten the fix;
#   * `trap restore EXIT` BEFORE the first mutant is applied -- any exit that
#     does not walk the straight-line path (a ^C, a `set -e` death, a failed
#     python) otherwise leaves the MUTANT in the working tree for the next
#     `git add -A` to commit as work.  That is GH #418, and this stand's M1 is
#     the same shape of edit;
#   * bare exit codes: the runner writes a log to a file and `$?` is read with
#     NO pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring as
#     caught -- a mutation that did not apply is not evidence about the tests;
#   * the baseline is proven GREEN before the first mutant (0CORP: a stand that
#     starts red reports every mutant as CAUGHT, by the red it started with);
#   * TWO mutants (M5, M6) BRIBE the source-text assertion they would otherwise
#     trip, so that "caught" means a behaviour assertion caught it and not that
#     a string pin noticed a string changing (§DJ/0EQUIV: a text assertion is
#     not evidence about behaviour).
#
# Usage: bash tools/agent/mutstand_roshdist.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    bots/FunLib/jmz_func.lua
    bots/mode_retreat_generic.lua
    tests/test_roshdist_pit_truth_operand.lua
    tests/mock/bot_api.lua
)
TESTS=(
    test_roshdist_pit_truth_operand
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_rd.XXXXXX")
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

WORKER_CMP = "\treturn nDistance <= ( nRadius or 1600 )\n"
GATE_PIN = "    assert(worker:find('nDistance <= %( nRadius or 1600 %)'),\n"

MUTANTS = {
    # M1: the revert -- this round's call-site edit undone, byte for byte.  The
    #     tree goes back to spelling a distance as a truth operand.
    "M1": [("bots/mode_retreat_generic.lua",
            "        and J.IsAtRoshanPit(bot, vRoshanLocation)\n",
            "        and GetUnitToLocationDistance(bot, vRoshanLocation)\n")],
    # M2: the wrapper hard-arms.  The lever stops being dark and ships to every
    #     real game -- the one thing a gated fix may never do.
    "M2": [("bots/FunLib/jmz_func.lua",
            "\t\tJ.IsModeTurbo() and J.IsSoakCandidate( 'roshdist' ) )\n",
            "\t\ttrue )\n")],
    # M3: the wrapper loses its turbo half.
    "M3": [("bots/FunLib/jmz_func.lua",
            "\t\tJ.IsModeTurbo() and J.IsSoakCandidate( 'roshdist' ) )\n",
            "\t\tJ.IsSoakCandidate( 'roshdist' ) )\n")],
    # M4: unarmed answers `true` instead of the distance.  TRUTHINESS IS
    #     UNCHANGED -- every boolean use of the shipped expression behaves
    #     identically -- so only the value-for-value [off-candidate] assertion
    #     can see it.  This is the mutant that says whether "byte-for-byte the
    #     shipped function" was measured or merely written in a comment.
    "M4": [("bots/FunLib/jmz_func.lua",
            "\tif not bRoshDist\n\tthen\n\t\treturn nDistance\n\tend\n",
            "\tif not bRoshDist\n\tthen\n\t\treturn true\n\tend\n")],
    # M5: `<=` -> `<`, AND the [gate] text pin edited to match so the string
    #     assertion is bribed.  Only [boundary] -- built from a real frame's own
    #     geometry -- can still call this out.
    "M5": [("bots/FunLib/jmz_func.lua", WORKER_CMP,
            "\treturn nDistance < ( nRadius or 1600 )\n"),
           ("tests/test_roshdist_pit_truth_operand.lua", GATE_PIN,
            "    assert(worker:find('nDistance < %( nRadius or 1600 %)'),\n")],
    # M6: the radius is loosened to 6000 -- past every hero position in the
    #     corpus -- with the same text pin bribed.  Armed becomes a guard that
    #     still cannot refuse anybody, i.e. the original defect wearing the
    #     fix's clothes.  [flip] is what is left to catch it.
    "M6": [("bots/FunLib/jmz_func.lua", WORKER_CMP,
            "\treturn nDistance <= ( nRadius or 6000 )\n"),
           ("tests/test_roshdist_pit_truth_operand.lua", GATE_PIN,
            "    assert(worker:find('nDistance <= %( nRadius or 6000 %)'),\n")],
    # M7: the worker ignores the flag it was given -- wired, armed, inert.  The
    #     'pullcad' shape: check_armed_wiring.py would still call this WIRED.
    "M7": [("bots/FunLib/jmz_func.lua",
            "\tif not bRoshDist\n", "\tif true\n")],
    # M8: the census ratchet is bribed to claim two bare operands are expected.
    #     A ratchet that passes on the wrong number is a constant, not a
    #     measurement.
    "M8": [("tests/test_roshdist_pit_truth_operand.lua",
            "    assert(#bare == 1, 'expected exactly one bare operand left, found '",
            "    assert(#bare == 2, 'expected exactly one bare operand left, found '")],
    # M9: the wrapper stops passing the gate at all.
    "M9": [("bots/FunLib/jmz_func.lua",
            "\treturn J.RoshanPitProximity( hUnit, vRoshanLocation,\n"
            "\t\tJ.IsModeTurbo() and J.IsSoakCandidate( 'roshdist' ) )\n",
            "\treturn J.RoshanPitProximity( hUnit, vRoshanLocation )\n")],
    # M10: the call site goes AROUND the wrapper and hard-arms the worker.  This
    #      is exactly GH #418: an un-gated behaviour change riding inside a
    #      gated fix, under a comment that still claims the gate.
    "M10": [("bots/mode_retreat_generic.lua",
             "        and J.IsAtRoshanPit(bot, vRoshanLocation)\n",
             "        and J.RoshanPitProximity(bot, vRoshanLocation, true)\n")],
    # M11: the instrument goes blind -- the mock answers 0 for every distance.
    #      Every corpus reading in the file would then be unanimous garbage that
    #      still looks like data.  [premise] is the only thing standing there,
    #      and this says whether it is load-bearing.
    "M11": [("tests/mock/bot_api.lua",
             "    G.GetUnitToLocationDistance = function(u, loc) return dist2d(u:GetLocation(), loc) end\n",
             "    G.GetUnitToLocationDistance = function(u, loc) return 0 end\n")],
    # M12: the census stops seeing the tree (the file glob matches nothing).
    #      Its "one bare operand left" would then be a statement about an empty
    #      scan.  The anti-vacuity floor is what has to catch this.
    "M12": [("tests/test_roshdist_pit_truth_operand.lua",
             "io.popen('find bots -name \"*.lua\" | sort')",
             "io.popen('find bots -name \"*.luaX\" | sort')")],
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
