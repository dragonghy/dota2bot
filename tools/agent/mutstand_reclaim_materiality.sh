#!/usr/bin/env bash
# Mutation stand for the GH #699 materiality rule in
# tools/batch_test/soak/reclaim_blind.py.  Director 2026-09-10.
# Run by hand when that rule or tests/test_reclaim_blind.py is edited.
#
# Sibling stand: mutstand_reclaim_market.sh covers the `market` key (GH #408)
# and the write-side diagnosis (GH #412).  This one covers only the rule added
# to break the W62 absorbing state:
#
#     A gate may not demand a datum its own answer does not depend on.
#
# Why this needs its own stand.  The market stand's mutants all move an EXIT
# CODE, which any acceptance test notices.  The dangerous mutants HERE mostly
# do not: a build that fills the hole with a benign reading, or prints a
# fabricated count, or drops the disclosure, answers exit 0 on W62 exactly like
# the real one.  What separates them is what the output SAYS about how the
# answer was reached -- so every mutant below is aimed at a sentence, and the
# stand's job is to prove those sentences are load bearing rather than decorative.
# That is the same shape as the #661 defect this rule had to avoid re-opening:
# "did not read" recorded as "read", invisible on the exit code.
#
# DISCIPLINE (inherited from mutstand_reclaim_market.sh):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`, under a trap so an
#     interrupted stand cannot leave the mutant in the tree (GH #418);
#   * bare exit codes -- the test writes a log and `$?` is read with no pipe;
#   * a mutant whose target string is absent ABORTS rather than scoring caught
#     (that clause fired for real on 2026-09-10: this rule moved P3's anchor in
#     the sibling stand, and the stand refused to score it);
#   * __pycache__ purged between mutants;
#   * a behavioural fingerprint decides INERT, and the probes below all carry
#     unread fields -- a fingerprint that never reaches a hole cannot tell a
#     no-op from a change.
#
# Usage: bash tools/agent/mutstand_reclaim_materiality.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/batch_test/soak/reclaim_blind.py
TEST=tests/test_reclaim_blind.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_rbm.XXXXXX")
cp "$SRC" "$WORK/orig.py"
sha256sum "$SRC" > "$WORK/sum.txt"

purge_pyc() { find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null; }
restore() {
    cp "$WORK/orig.py" "$SRC"
    sha256sum -c "$WORK/sum.txt" > /dev/null || { echo "RESTORE FAILED"; exit 2; }
}
trap restore EXIT

apply_mutant() {
    MUT="$1" python3 - "$SRC" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
mut = os.environ["MUT"]
PAIRS = {
    # Q1: the adversarial reading leaves the extension set.  This is THE mutant
    #     of this rule: with only the benign code explored, every hole becomes
    #     immaterial by construction, the gate answers 0 on every wave whose
    #     code nobody read, and a genuinely reclaimed BLINDED wave is silently
    #     handed back to spot.  It is exactly the hole GH #661 closed, re-opened
    #     through the door this rule had to cut.
    "Q1": ("_CODE_EXTENSIONS = (RECLAIMED, SELF_TERMINATED)",
           "_CODE_EXTENSIONS = (SELF_TERMINATED,)"),
    # Q2: the extensions are scored and their DISAGREEMENT is ignored -- the
    #     tool answers from whichever point happened to be enumerated first.
    #     "Materiality" degenerates into a coin flip that never says it flipped.
    "Q2": ("    if len(agreed) > 1:", "    if False:"),
    # Q3: the attribution count collapses from the span the input supports to a
    #     single number taken off one invented extension.  The verdict is still
    #     right; the line above it now reports a measurement that was never made.
    "Q3": ('        spans = sorted(set(o["early_n"] for o in outcomes))',
           '        spans = [res["early_n"], res["early_n"]]'),
    # Q4: the bracket gauge still declines to run on unreadable rows, but stops
    #     saying so.  A gauge that quietly opts out is the shape of lie this
    #     file's own header calls out for the lower-bound case.
    "Q4": ('            skipped.append("seed %s: %s not read, so neither direction of "',
           '            _ = ("seed %s: %s not read, so neither direction of "'),
    # Q5: a hole renders as a real termination code on the per-machine line --
    #     the line a reader scans to decide whether the wave was read at all.
    #     The disclosure block further down is untouched, so this mutant answers
    #     correctly, discloses correctly, and still tells the reader the field
    #     was read.  It is the cheapest mutant here and the hardest to see.
    "Q5": ('        shown_code = "(unread)" if is_unread(row["code"]) else row["code"]',
           '        shown_code = SELF_TERMINATED if is_unread(row["code"]) else row["code"]'),
    # Q6: an absent survival becomes a number instead of a hole.  0.0 is under
    #     the flip, so on W62 every paired machine now looks like it paired
    #     before the changeover -- the tool reports BRACKET VIOLATED and refuses,
    #     i.e. the farm stays shut, for a reason invented by the reader.
    #     NOTE the spelling: `0.0 or Unread(...)` was the first attempt and it is
    #     a NO-OP, because 0.0 is falsy and `or` hands back the Unread.  The
    #     stand scored it INERT rather than CAUGHT -- which is the fingerprint
    #     clause earning its place: a mutant that does not mutate would
    #     otherwise have been recorded as evidence that the tests are strong.
    "Q6": ('    return Unread("%s: survival was not read',
           '    return 0.0 if True else Unread("%s: survival was not read'),
}
old, new = PAIRS[mut]
if old not in src:
    sys.exit("MUTATION TARGET ABSENT for %s -- this stand cannot claim that mutant" % mut)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

# Behavioural fingerprint.  Every probe carries at least one unread field, and
# the tags include the SENTENCES the rule is made of, because most mutants here
# move prose rather than an exit code.
fingerprint() {
    python3 - <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.getcwd(), "tools", "batch_test", "soak"))
import reclaim_blind as rb

SELF, GONE = rb.SELF_TERMINATED, rb.RECLAIMED


def od(seed, ab, ba, depth=None, **extra):
    row = {"seed": seed, "market": "on-demand", "status_code": None,
           "ab": ab, "ba": ba}
    if depth is not None:
        row["arm_depth"] = depth
    row.update(extra)
    return row


PROBES = {
    # W62 itself: the wave that closed the farm.  Both fields unread on all four
    # machines, yield healthy, so every hole is immaterial.
    "w62": [od(10601, 42, 16, 23.17), od(10607, 31, 14, 19.29),
            od(10803, 34, 24, 28.14), od(10813, 30, 12, 17.14)],
    # the same rows starved down to one paired seed: the holes become load
    # bearing and the answer must go back to exit 2.
    "starved": [od(10601, 26, 0, 0.0), od(10607, 22, 0, 0.0),
                od(10803, 19, 0, 0.0), od(10813, 30, 12, 17.14)],
    # one on-demand row, no code, PAST the flip: unreadable but immaterial,
    # because no reading of the code makes a 50-minute machine an early reclaim.
    "past": [{"seed": 1, "market": "on-demand", "survival_min": 50.0,
              "ab": 20, "ba": 10}],
    # the same row SUB-flip and unpaired: the two readings straddle the verdict.
    "sub": [{"seed": 1, "market": "on-demand", "survival_min": 5.4,
             "ab": 20, "ba": 0}],
    # a spot row whose code was never written (the mislabel direction's twin)
    "spothole": [{"seed": 1, "survival_min": 5.4, "ab": 26, "ba": 0},
                 {"seed": 2, "survival_min": 55.0, "status_code": SELF,
                  "ab": 30, "ba": 15, "arm_depth": 18.0}],
    # a fully-read wave: nothing in this rule may move here
    "readable": [{"seed": 1, "survival_min": 55.0, "status_code": SELF,
                  "ab": 30, "ba": 15, "arm_depth": 18.0},
                 {"seed": 2, "survival_min": 54.0, "status_code": SELF,
                  "ab": 28, "ba": 14, "arm_depth": 17.0}],
}

for name, machines in PROBES.items():
    code, lines = rb.evaluate({"wave": name, "machines": machines})
    text = "\n".join(lines)
    tags = [t for t in ("BLINDED", "not blinded", "UNDECIDABLE",
                        "CHANGES the verdict", "immaterial", "unread     :",
                        "bracket    : SKIPPED", "BRACKET VIOLATED",
                        "GH #699", "(unread)")
            if t in text]
    # The per-machine lines are matched on their RAW two-space indent.  Written
    # as `ln.strip().startswith(("yield", "attribution", "  seed"))` the third
    # prefix can never match -- a stripped line has no leading spaces -- so the
    # machine lines dropped out of the fingerprint entirely and Q6 (an unread
    # survival rendered as `0.0 min`) scored INERT.  Same slip as test 26k's
    # first version, found the same way: the stand disagreeing with itself.
    facts = [ln.strip() for ln in lines
             if ln.startswith("  seed ")
             or ln.startswith(("yield", "attribution"))]
    print("%s=%d:%s:%s" % (name, code, "|".join(tags), "||".join(facts)))
PY
}

purge_pyc
fingerprint > "$WORK/fp.base" 2>&1

echo "== mutation stand (GH #699 materiality): $SRC / $TEST"
worst=0
for m in Q1 Q2 Q3 Q4 Q5 Q6; do
    purge_pyc
    if ! apply_mutant "$m"; then
        echo "$m  APPLY-FAILED -- stand aborted rather than score a no-op as caught"
        restore; exit 2
    fi
    fingerprint > "$WORK/fp.$m" 2>&1
    if cmp -s "$WORK/fp.base" "$WORK/fp.$m"; then
        echo "$m  INERT -- the source changed and the behaviour did not; this is a"
        echo "       DEFECT IN THE STAND, not a finding about the tests"
        restore; worst=2; continue
    fi
    python3 "$TEST" > "$WORK/$m.log" 2>&1
    rc=$?
    sha=$(sha256sum "$SRC" | cut -c1-12)
    if [ "$rc" -eq 0 ]; then
        echo "$m  SURVIVED (sha=$sha) -- behaviour moved and no test noticed"
        worst=3
    else
        echo "$m  CAUGHT   (sha=$sha, exit $rc)"
    fi
    # A mutant that CRASHES the test file scores caught without any assertion
    # having run -- that measures the interpreter, not the tests.  Print the
    # FAIL summary so an empty one is visible.
    grep -E "^FAIL " "$WORK/$m.log" | head -4 | sed 's/^/       /'
    restore
done

purge_pyc
python3 "$TEST" > "$WORK/baseline.log" 2>&1
rc=$?
echo "baseline after restore: exit $rc :: $(tail -1 "$WORK/baseline.log")"
[ "$rc" -eq 0 ] || { echo "BASELINE RED after restore"; exit 2; }
exit $worst
