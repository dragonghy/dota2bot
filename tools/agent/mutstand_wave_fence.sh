#!/usr/bin/env bash
# Mutation stand for tests/test_wave_fence.py (GH #504, director 2026-09-05).
# Run by hand when that file or tools/batch_test/soak/wave_fence.py is edited.
#
# WHAT IS UNDER TEST AND WHY IT NEEDS A STAND.  The tool computes a fence, and
# the fence it computes today ($50) happens to equal the fence a correct
# implementation computes today.  That is not the property being bought.  The
# property is that the fence is RE-DERIVED -- that the same code, unedited,
# answers $80 on 2026-08-31 and $50 on 2026-09-01, because the only thing that
# changed is an input it reads every run.
#
# A test suite can be green on a tool that returns a constant.  For the whole of
# August, `return 80.0` and the correct derivation are BYTE-IDENTICAL in output;
# that is precisely how the defect survived a rewrite whose stated purpose was
# to remove this exact free parameter.  So M1 is the mutant that matters: it is
# the bug as it actually shipped -- the answer cached instead of derived.
#
# The mutants attack the DERIVATION, not the arithmetic:
#   * can the suite tell a derived fence from a cached one?           (M1) ⭐
#   * ...from one cached at the OTHER end, i.e. always-lowest?        (M2)
#   * does GREATER_THAN stay strict, so sitting on a line is not over it? (M3)
#   * is PERCENTAGE-vs-ABSOLUTE decided by reading, not by the $100
#     coincidence that makes both readings agree today?               (M4)
#   * does a disagreement with AWS's own NotificationState still refuse? (M5)
#   * ...without the suite crying wolf at a comment that merely says 80 (M6,
#     the control, which MUST survive)
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * `trap - EXIT` BEFORE `rm -rf "$WORK"` (GH #492 §EL.7: a 5/5 stand exiting
#     2 because its own cleanup outran its trap);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠ WHAT THIS STAND DELIBERATELY DOES NOT ATTACK.  No mutant weakens an expected
# constant inside the test file itself; a file cannot catch its own assertion
# being loosened, so a SURVIVED there would be a statement about mutation
# testing rather than about this suite.  Every mutant edits the TOOL.
#
# Usage: bash tools/agent/mutstand_wave_fence.sh
set -u
cd "$(dirname "$0")/../.."

TOOL=tools/batch_test/soak/wave_fence.py

FILES=("$TOOL")
TEST=tests/test_wave_fence.py

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wf.XXXXXX")
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
    python3 "$TEST" > "$WORK/run.log" 2>&1
    return $?
}

apply_mutant() {
    MUT="$1" TOOL="$TOOL" python3 - <<'PY'
import os, sys

mut  = os.environ["MUT"]
TOOL = os.environ["TOOL"]

PICK = '''def pick_fence(thresholds, actual):
    """Ruling 1: the lowest ACTUAL threshold not yet crossed (T >= actual)."""
    for t in thresholds:
        if t["amount"] >= actual:
            return t
    return None
'''

MUTANTS = {
    # M1: ⭐ THE LOAD-BEARING ONE, AND IT IS THE BUG AS SHIPPED.  The fence is
    #     the cached August answer instead of a derivation.  Note what this
    #     mutant does NOT break: every August reading, every printed line, the
    #     brake, the disagreement check.  For one whole month it is
    #     indistinguishable from correct.  If the suite cannot catch this, it
    #     is testing arithmetic that was never in doubt.
    "M1": [(TOOL, PICK,
            'def pick_fence(thresholds, actual):\n'
            '    for t in thresholds:\n'
            '        if t["amount"] == 80.0:\n'
            '            return t\n'
            '    return None\n')],
    # M2: cached at the other end -- always the lowest threshold.  This one is
    #     CONSERVATIVE (it under-spends), which is why it needs its own mutant:
    #     a suite that only checks "the fence is never too high" would let it
    #     through, and the ruling is that the fence is the RULE's output, not
    #     the safest number available.
    "M2": [(TOOL, PICK,
            'def pick_fence(thresholds, actual):\n'
            '    return thresholds[0] if thresholds else None\n')],
    # M3: GREATER_THAN read as GREATER_THAN_OR_EQUAL.  Sitting exactly on $50
    #     now counts as crossed and the fence jumps to $80 -- over-permissive by
    #     $30 at the one instant the fence is doing its job.
    "M3": [(TOOL, '        if t["amount"] >= actual:\n',
                  '        if t["amount"] > actual:\n')],
    # M4: the PERCENTAGE branch takes the raw number.  On the real budget
    #     (limit $100) this changes NOTHING -- 50% of $100 is $50 -- so it is
    #     invisible against production data and only a limit change reveals it.
    "M4": [(TOOL, "            amount = limit * raw / 100.0\n",
                  "            amount = raw\n")],
    # M5: the disagreement check is downgraded to a warning that still passes.
    #     A plausible "don't block launches on a lagging alarm state" edit.
    "M5": [(TOOL, '        lines.append("WAVE_FENCE: UNCERTIFIABLE (exit 2)")\n'
                  '        return 2, lines\n',
                  '        lines.append("WAVE_FENCE: warning only")\n')],
    # M6: ⚠ THE CONTROL, AND IT MUST SURVIVE.  The number 80 appears in a
    #     COMMENT -- which is where it genuinely does appear, all over this
    #     repo's charters and reports, as the archived August answer.  A stand
    #     that greps for the literal instead of exercising the derivation would
    #     score this CAUGHT and start failing every time somebody quotes the
    #     history.  Expected SURVIVED.
    "M6": [(TOOL, "BUDGET_NAME = \"dota2bot-batch\"\n",
                  "# August's archived fence was $80.0; September's is not.\n"
                  "BUDGET_NAME = \"dota2bot-batch\"\n")],
}

if mut not in MUTANTS:
    sys.stderr.write("unknown mutant %s\n" % mut)
    sys.exit(2)

for path, old, new in MUTANTS[mut]:
    with open(path) as f:
        src = f.read()
    if old not in src:
        sys.stderr.write("ABORT %s: target absent in %s\n" % (mut, path))
        sys.exit(3)
    with open(path, "w") as f:
        f.write(src.replace(old, new, 1))
PY
}

echo "=== baseline (must be GREEN before any mutant is trusted) ==="
run_tests
BASE=$?
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- nothing below means anything"
    cat "$WORK/run.log"
    exit 2
fi
echo "baseline: GREEN"
echo

# M6 is the control: it is EXPECTED to survive.  Everything else must be caught.
EXPECT_SURVIVE=" M6 "
FAILED=0
for m in M1 M2 M3 M4 M5 M6; do
    restore
    apply_mutant "$m"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "$m: ABORTED (target string absent, exit $rc) -- the stand is stale"
        FAILED=1
        continue
    fi
    run_tests
    rc=$?
    if [ "$rc" -ne 0 ]; then verdict=CAUGHT; else verdict=SURVIVED; fi
    case "$EXPECT_SURVIVE" in
        *" $m "*) want=SURVIVED ;;
        *)        want=CAUGHT ;;
    esac
    if [ "$verdict" = "$want" ]; then
        echo "$m: $verdict (expected)"
    else
        echo "$m: $verdict -- EXPECTED $want"
        FAILED=1
    fi
done

restore
echo
echo "=== restored; re-running baseline ==="
run_tests
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "POST-RESTORE BASELINE RED (exit $rc)"
    cat "$WORK/run.log"
    exit 2
fi
echo "post-restore baseline: GREEN"
trap - EXIT
rm -rf "$WORK"
if [ "$FAILED" -ne 0 ]; then
    echo "STAND: FAILED"
    exit 1
fi
echo "STAND: OK"
