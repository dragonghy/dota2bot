#!/usr/bin/env bash
# Mutation stand for the B3 tightening (GH #445):
# tools/batch_test/behavioral/slotdust_arbitration.py's B3 clause and its
# ratchet tests/test_slotdust_b3_perframe.py.  Run by hand when either is
# edited, and before quoting a B3 column in a ruling.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418: an
#     interrupted stand otherwise leaves the MUTANT in the working tree);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant;
#   * ⚠ EVERY MUTANT EDITS THE TOOL, NEVER THE TEST.  The oracle this stand
#     scores against IS the test file, so a mutant that weakens an assertion
#     survives by construction and says nothing.  Break what the assertion is
#     ABOUT.
#
# WHAT THIS STAND IS ESPECIALLY FOR.  The defect being repaired was SILENT: a
# census that was individually conservative per cast, and whose truth value was
# nevertheless decided by the draft rather than by the frame.  It printed a
# clean table for six runs.  So the three ways this repair dies quietly are:
#   (1) B3 goes back to being decided by something other than THIS caster at
#       THIS instant -- the census returns, or the window widens until any tick
#       in the game blocks, or any body's burn counts.  M1, M2, M4, M12.
#   (2) The window stops being slack in the SAFE direction, so the clause
#       starts inventing survivors in the column whose baseline is structurally
#       zero (LIMIT 6).  M3, M11.
#   (3) The reading loses the thing that makes it auditable: the domain price
#       of the carrier, the loud line when that price is zero, or the contrast
#       column that says how much the retired rule was erasing.  M5, M6, M7,
#       M8, M9, M10.
#
# Usage: bash tools/agent/mutstand_slotdustb3.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    tools/batch_test/behavioral/slotdust_arbitration.py
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_sdb3.XXXXXX")
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

# Both ratchets run: the B3 file is the oracle for the clause, and the
# reachability-fit file is the parity oracle that says the OTHER eight cascade
# columns did not move while B3 was being changed.
run_tests() {
    python3 tests/test_slotdust_b3_perframe.py > "$WORK/run.log" 2>&1
    local a=$?
    python3 tests/test_slotdust_reachability_fit.py >> "$WORK/run.log" 2>&1
    local b=$?
    [ "$a" -eq 0 ] && [ "$b" -eq 0 ]
}

apply_mutant() {
    MUT="$1" python3 - <<'PY'
import os, sys
mut = os.environ["MUT"]
T = "tools/batch_test/behavioral/slotdust_arbitration.py"

MUTANTS = {
    # ---- B3 stops being about THIS caster at THIS instant ----------------
    # M1: the retired draft census is restored as the exclusion.  This is the
    #     defect itself, and it is the one that printed a clean table for six
    #     runs while erasing one side of it.
    "M1": [(T, '                   "b3" if burning else',
            '                   "b3" if census else')],
    # M2: any body's burn blocks any caster.  Per-frame in form, team-wide in
    #     effect -- a burning teammate silences everyone's dust.
    "M2": [(T, '        burning = any(abs(bt - e["t"]) <= B3_BURN_WINDOW\n'
               '                      for bt in burn.get(e.get("actor"), ()))',
            '        burning = any(abs(bt - e["t"]) <= B3_BURN_WINDOW\n'
            '                      for v in burn.values() for bt in v)')],
    # M4: the window swallows the game.  One radiance tick anywhere in the
    #     caster's match blocks every cast he makes -- the census again, now
    #     wearing the carrier's clothes.
    "M4": [(T, '        burning = any(abs(bt - e["t"]) <= B3_BURN_WINDOW',
            '        burning = any(True or abs(bt - e["t"]) <= B3_BURN_WINDOW')],
    # M12: the carrier is respelled into the SNAPSHOT vocabulary.  LIMIT 9 in
    #      the other direction: no combat-log inflictor is ever `radiance`, so
    #      B3 becomes structurally dead and silent, exactly like the bug this
    #      whole family was opened by.
    "M12": [(T, 'RADIANCE_BURN = "item_radiance"', 'RADIANCE_BURN = "radiance"')],
    # ---- the slack points the wrong way ---------------------------------
    # M3: the window collapses to the event grid.  A debuff that is on but
    #     whose tick landed 0.2 s off the cast stops blocking, and the cast
    #     lands in the column whose baseline is structurally zero (LIMIT 6).
    "M3": [(T, "B3_BURN_WINDOW = 1.5", "B3_BURN_WINDOW = 0.0")],
    # M11: B4 is consulted before B3.  Every burn is also a DAMAGE event, so
    #      the blocks still happen and the totals still add up -- only the
    #      attribution is wrong, and a reader diagnosing "which clause is
    #      eating the casts" is sent to the wrong branch.
    "M11": [(T,
             '        blocked = ("b2" if sandking else\n'
             '                   "b3" if burning else\n'
             '                   "b4" if dmg else None)',
             '        blocked = ("b2" if sandking else\n'
             '                   "b4" if dmg else\n'
             '                   "b3" if burning else None)')],
    # ---- the reading stops being auditable ------------------------------
    # M5: the MODIFIER_ADD carrier starts blocking.  Whether this corpus emits
    #     that event is a fact nobody has bought; blocking on it changes the
    #     answer on corpora that do and leaves corpora that do not looking
    #     identical -- the window's correctness becomes unfalsifiable.
    "M5": [(T,
            '            mod_events[(e.get("target"), et)] += 1',
            '            mod_events[(e.get("target"), et)] += 1\n'
            '            burn[e.get("target")].append(e["t"])')],
    # M6: the contrast column is dropped.  The whitewash is repaired and the
    #     size of what it was erasing becomes unmeasurable, so no later run can
    #     say whether this change mattered.
    "M6": [(T, '        if census and not burning:',
            '        if False and census and not burning:')],
    # M7: the carrier's domain price stops being counted.  Every corpus now
    #     looks like a corpus with no radiance in it (LIMIT 13(c)).
    "M7": [(T, '        out[leg]["radiance_burn_ticks"] += len(ticks)',
            '        out[leg]["radiance_burn_ticks"] += 0')],
    # M8: the loud line goes away.  A corpus where B3 could not fire at all
    #     prints a clean zero and reads exactly like one where it never needed
    #     to -- the failure mode this whole family exists to prevent.
    "M8": [(T, "    if ticks == 0:", "    if False:")],
    # M9: the carrier block is not printed.  Every unit assertion still passes;
    #     only an end-to-end reader notices the product is missing.
    "M9": [(T,
            '    print("B3 CARRIER -- the tightened clause reads the CASTER\'s own burn tick,")',
            '    pass')],
    # M10: main stops aggregating the B3 columns, so they leave scan_game and
    #      never reach the report.  Every cell reads 0 and the absent-carrier
    #      banner fires on a corpus that is full of burns.
    "M10": [(T, "            for k in KEYS + FIT_KEYS + B3_KEYS:",
             "            for k in KEYS + FIT_KEYS:")],
}

edits = MUTANTS[mut]
for path, old, new in edits:
    src = open(path, encoding="utf-8").read()
    if old not in src:
        sys.stderr.write("ABORT: %s target absent in %s\n" % (mut, path))
        sys.exit(3)
    if src.count(old) != 1:
        sys.stderr.write("ABORT: %s target is AMBIGUOUS in %s (%d hits) -- a\n"
                         "       replace(...,1) here would mutate whichever\n"
                         "       occurrence comes first and score the wrong\n"
                         "       function\n" % (mut, path, src.count(old)))
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
        echo "ABORT   $m -- target string absent or ambiguous; NOT scored"
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
