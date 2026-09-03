#!/usr/bin/env bash
# Mutation stand for the slotdust REACHABILITY FIT (GH #441):
# tools/batch_test/behavioral/slotdust_arbitration.py and its ratchet
# tests/test_slotdust_reachability_fit.py.  Run by hand when either is edited,
# and before quoting the fit table in a ruling.
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
#     scores against IS that test file, so a mutant that weakens an assertion
#     survives by construction and says nothing (mutstand_chainmember.sh
#     M10-M12 learned this the expensive way).  Break what the assertion is
#     ABOUT.
#
# WHAT THIS STAND IS ESPECIALLY FOR.  This round's product is a MEASUREMENT
# THAT MAKES A MODEL REFUTABLE, and there are three ways it dies quietly:
#   (1) The fit stops being reachability-agnostic and silently becomes the
#       exclusive column again -- the decisive cell (dire baseline slot 5) goes
#       back to not existing, and the table still prints.  M1, M2, M6, M11.
#   (2) The pre-existing columns move.  The patch CLAIMS they are untouched;
#       M3 is the mutant that proves the parity oracle in section 0 is real
#       rather than a paraphrase of the code it judges.
#   (3) The epistemics rot -- a hypothesis nothing refuted gets reported as
#       confirmed, or the model in HYPOTHESES drifts away from the model in
#       `reachable_unarmed` that it is supposed to BE.  M4, M5, M7, M8, M12.
#
# Usage: bash tools/agent/mutstand_slotdustfit.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    tools/batch_test/behavioral/slotdust_arbitration.py
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_sdf.XXXXXX")
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
    python3 tests/test_slotdust_reachability_fit.py > "$WORK/run.log" 2>&1
    return $?
}

apply_mutant() {
    MUT="$1" python3 - <<'PY'
import os, sys
mut = os.environ["MUT"]
T = "tools/batch_test/behavioral/slotdust_arbitration.py"

MUTANTS = {
    # ---- the fit collapses back into the exclusive column ---------------
    # M1: the cascade is run only for slots the hypothesis calls unreachable --
    #     i.e. exactly the pre-#441 behaviour, wearing the new table's clothes.
    #     The table still prints; the one cell that discriminates is empty.
    "M1": [(T,
            '        out[leg]["fit_casts_s%d" % slot] += 1\n'
            '        if blocked is None:\n'
            '            out[leg]["fit_survive_s%d" % slot] += 1\n',
            '        if not reachable_unarmed(team, slot):\n'
            '            out[leg]["fit_casts_s%d" % slot] += 1\n'
            '            if blocked is None:\n'
            '                out[leg]["fit_survive_s%d" % slot] += 1\n')],
    # M2: every cast counts as a survivor.  B2/B3/B4 stop meaning anything and
    #     every slot on every leg refutes every hypothesis -- a table that is
    #     loud, consistent, and content-free.
    "M2": [(T,
            '        if blocked is None:\n'
            '            out[leg]["fit_survive_s%d" % slot] += 1\n',
            '        if True:\n'
            '            out[leg]["fit_survive_s%d" % slot] += 1\n')],
    # M6: the ARMED leg is folded into the fit.  Armed reads the loop INDEX, so
    #     every slot is reachable there under all three hypotheses; mixing it in
    #     refutes everything from a leg that carries no information.
    "M6": [(T,
            '            if leg == "baseline":\n'
            '                baseline_survivors.setdefault(team, {}).update(',
            '            if True:\n'
            '                baseline_survivors.setdefault(team, {}).update(')],
    # M11: main aggregates the old columns only, so the fit counters never
    #      leave scan_game.  Every cell reads 0/0 and nothing is ever refuted:
    #      the report looks like a corpus that agrees with the shipped model.
    "M11": [(T, "            for k in KEYS + FIT_KEYS + B3_KEYS:",
             "            for k in KEYS + B3_KEYS:")],
    # ---- the pre-existing columns move ----------------------------------
    # M3: B4 drops out of the shared cascade.  This is the mutant the parity
    #     oracle in section 0 exists for: if it survives, that section is
    #     paraphrasing the code instead of judging it, and the patch's
    #     "every pre-existing column keeps its exact value" is unbacked.
    "M3": [(T, '                   "b4" if dmg else None)',
            '                   None)')],
    # ---- the epistemics rot ---------------------------------------------
    # M4: `reachable_unarmed` quietly adopts H1 for dire.  The model under test
    #     becomes the hypothesis under test, and H0 can never be refuted again.
    "M4": [(T, "    return slot == 5                  # ids 6..9 are out of range",
            "    return slot in (1, 2, 3, 4)")],
    # M5: H1 is widened to cover dire slot 5, so the ONE cell that could refute
    #     it stops being able to.  A hypothesis that cannot lose.
    "M5": [(T, '    "H1-leak-radiant-cached": {RADIANT: (1, 2, 3, 4), DIRE: (1, 2, 3, 4)},',
            '    "H1-leak-radiant-cached": {RADIANT: (1, 2, 3, 4), DIRE: (1, 2, 3, 4, 5)},')],
    # M7: the subset test is dropped -- every non-zero cell refutes every
    #     hypothesis, including the one it is consistent with.
    "M7": [(T, "            if n > 0 and slot not in hypothesis[team]:",
            "            if n > 0 or slot not in hypothesis[team]:")],
    # M8: the layer/leg -> team map is flipped on one layer.  Survivors get
    #     booked against the wrong team and the refutation reads backwards --
    #     the 4(i-a) split is exactly what this mutant abuses.
    "M8": [(T, '    return DIRE if leg == "armed" else RADIANT',
            '    return RADIANT if leg == "armed" else DIRE')],
    # M12: an unrefuted hypothesis is reported as CONFIRMED.  Nothing else
    #      changes -- no count moves, no column shifts -- and the whole LIMIT 12
    #      discipline ("this test refutes only") is gone from the only place a
    #      reader meets it.
    "M12": [(T, '            print("  %-24s not refuted by this corpus (LIMIT 12: not confirmed)"',
             '            print("  %-24s CONFIRMED by this corpus"')],
    # ---- the report goes silent -----------------------------------------
    # M9: the table is computed and never printed.  Every unit assertion still
    #     passes; only an end-to-end reader notices the product is missing.
    "M9": [(T,
            '    print("REACHABILITY FIT -- casts / survivors of B2+B3+B4, by team slot")',
            '    pass')],
    # M10: the verdict lines are dropped, so the table prints and no hypothesis
    #      is ever named refuted.  The reading survives; the ruling does not.
    "M10": [(T, "    for name in sorted(HYPOTHESES):", "    for name in ():"),],
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
