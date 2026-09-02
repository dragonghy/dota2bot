#!/usr/bin/env bash
# Mutation stand for the dead-rung census: tools/agent/threshold_chain_census.py
# and its ratchet tests/test_threshold_chain_census.py.  Run by hand when either
# is edited, and before quoting either in a ruling.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418: an
#     interrupted stand otherwise leaves the MUTANT in the working tree);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS ESPECIALLY FOR.  This round's product is a READING, not a
# behaviour change: "exactly one dead rung in bots/, and it is unbuyable on this
# corpus."  A reading fails silently in two ways a behaviour change cannot.
#   (1) The SCANNER goes blind -- points at nothing, or stops understanding the
#       one syntax the finding is written in (the turbo ternary) -- and then
#       `FINDINGS 0` is indistinguishable from a clean corpus.  M4-M8.
#   (2) The DOMAIN reading goes blind -- the fixture scan stops parsing
#       inventories, and "no enhancement in the archive" becomes a statement
#       about an empty set that is trivially true.  M9-M12.
# Both are the failure mode that stays GREEN, which is why they get eight of the
# twelve mutants and the shipped-defect mutants get four.
#
# ⚠ THE READING THIS STAND IS PROTECTING WAS WRONG ONCE ALREADY, THIS ROUND.
# The first draft of section 3 asserted the archive held no blink and no frame
# past 750 s.  Both were false -- eight fixtures hold `blink_dagger`, and two
# frames reach 790.4 s -- and both survived being written down because the
# measurement grepped `'blink'` (the archive spells it `blink_dagger`) and
# `item_blink` (the archive strips the `item_` prefix).  The test caught its own
# author.  M11/M12 exist so that the corrected numbers cannot rot back.
#
# Usage: bash tools/agent/mutstand_deadrung.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    tools/agent/threshold_chain_census.py
    tests/test_threshold_chain_census.py
    bots/ability_item_usage_generic.lua
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_dr.XXXXXX")
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
    python3 tests/test_threshold_chain_census.py > "$WORK/run.log" 2>&1
    return $?
}

apply_mutant() {
    MUT="$1" python3 - <<'PY'
import os, sys
mut = os.environ["MUT"]
TOOL = "tools/agent/threshold_chain_census.py"
TEST = "tests/test_threshold_chain_census.py"
SITE = "bots/ability_item_usage_generic.lua"

MUTANTS = {
    # ---- the shipped defect itself -------------------------------------
    # M1: the ladder is silently REPAIRED (rungs swapped into descending
    #     order).  That is a real behaviour change, ungated, on a lever this
    #     round deliberately registered rather than fixed -- exactly the drift
    #     the registration is meant to make impossible.
    "M1": [(SITE,
            "\t\tif DotaTime() >= (J.IsModeTurbo() and 7.5*60 or 15*60) then\n"
            "\t\t\tnCastRange = nCastRange + 125\n"
            "\t\telseif DotaTime() >= (J.IsModeTurbo() and 12.5*60 or 25*60) then\n"
            "\t\t\tnCastRange = nCastRange + 135\n",
            "\t\tif DotaTime() >= (J.IsModeTurbo() and 12.5*60 or 25*60) then\n"
            "\t\t\tnCastRange = nCastRange + 135\n"
            "\t\telseif DotaTime() >= (J.IsModeTurbo() and 7.5*60 or 15*60) then\n"
            "\t\t\tnCastRange = nCastRange + 125\n")],
    # M2: the dead rung is deleted instead of repaired.  The census then reads
    #     a clean corpus, and the tier the author intended is gone with no
    #     ruling anywhere -- a "fix" that removes the evidence.
    "M2": [(SITE,
            "\t\telseif DotaTime() >= (J.IsModeTurbo() and 12.5*60 or 25*60) then\n"
            "\t\t\tnCastRange = nCastRange + 135\n",
            "")],
    # M3: the enclosing branch changes item, so the ladder stops being the
    #     keen-eyed ladder while every line of prose about it still says it is.
    "M3": [(SITE,
            "\tif J.HasItemInInventory('item_enhancement_keen_eyed') then\n",
            "\tif J.HasItemInInventory('item_enhancement_mystical') then\n")],
    # ---- the scanner goes blind (the green-failure family) ---------------
    # M4: the corpus walk is pointed at a directory that does not exist.  The
    #     census then reports FINDINGS 0 on an empty scan.  Only the chain
    #     DENOMINATOR can tell that apart from a clean tree.
    "M4": [(TOOL,
            "    for path in lua_corpus.bots_lua_files(root):",
            "    for path in lua_corpus.bots_lua_files(root)[:0]:")],
    # M5: the turbo ternary stops being understood, so every time threshold in
    #     the repo becomes unparseable and the one finding disappears -- while
    #     the scanner still walks all 275 files and still counts 4000 chains.
    #     This is the mutant M4's denominator CANNOT catch.
    "M5": [(TOOL,
            "    m = TURBO_TERNARY.match(e)\n    if m:",
            "    m = None\n    if m:")],
    # M6: subsumption loses its equality, so a ladder whose rungs are ordered
    #     ascending but only just (or repeated) reads as live.
    "M6": [(TOOL,
            "        return later_val >= first_val",
            "        return later_val > first_val")],
    # M7: the two directions are conflated -- a `>=` rung followed by a `<=`
    #     rung (a legitimate BAND) starts reporting.  The false-positive
    #     direction: this is how a working ladder gets "fixed" into a broken one.
    "M7": [(TOOL,
            "    if first_op in (\"<=\", \"<\") and later_op in (\"<=\", \"<\"):\n"
            "        return later_val <= first_val\n    return False",
            "    if first_op in (\"<=\", \"<\") and later_op in (\"<=\", \"<\"):\n"
            "        return later_val <= first_val\n    return True")],
    # M8: the left-hand sides stop being compared, so two DIFFERENT quantities
    #     count as one ladder.  Also a false-positive mutant.
    "M8": [(TOOL,
            "                    if not prev or prev[0] != rung[0]:",
            "                    if not prev:")],
    # ---- the domain reading goes blind ----------------------------------
    # M9: the fixture glob matches nothing.  "No enhancement in the archive"
    #     becomes true of the empty set, and the whole justification for
    #     registering-instead-of-fixing evaporates while the file stays green.
    "M9": [(TEST,
            "fixtures = sorted(glob.glob(os.path.join(REPO, \"tests\", \"fixtures\", \"*.lua\")))",
            "fixtures = sorted(glob.glob(os.path.join(REPO, \"tests\", \"fixtures\", \"*.luaX\")))")],
    # M10: inventories stop being parsed (the `items = {...}` shape changes), so
    #      the token set empties.  Same vacuity as M9, one layer lower down --
    #      and this is the layer the round's own first draft got wrong.
    "M10": [(TEST,
             "for m in re.finditer(r\"items\\s*=\\s*\\{([^}]*)\\}\", blob):",
             "for m in re.finditer(r\"itemsX\\s*=\\s*\\{([^}]*)\\}\", blob):")],
    # M11: the corrected blink reading is rotted back to the round's own first,
    #      WRONG draft -- searching the quoted token the archive does not use.
    #      If this survives, the near-miss is not actually pinned.
    "M11": [(TEST,
             "blink = sorted(t for t in inv_tokens if \"blink\" in t)",
             "blink = sorted(t for t in inv_tokens if t == \"blink\")")],
    # M12: the frame-time reading is rotted back to the other half of the same
    #      wrong draft -- "the archive never reaches 750 s".
    "M12": [(TEST,
             "late = [t for t in times if t >= 750.0]",
             "late = [t for t in times if t >= 7500.0]")],
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
