#!/usr/bin/env bash
# Mutation stand for the minion_lib carrier resolution in
# tools/batch_test/soak/carrier_terms.py (GH #402, director 2026-09-01).
# Run by hand when that resolution or tests/test_carrier_terms.py is edited.
#
# DISCIPLINE: out-of-tree `cp` restore verified with `sha256sum -c`; bare exit
# codes (the test writes a log, `$?` is read with no pipe in between); a mutant
# whose target string is absent ABORTS rather than scoring as caught; and
# __pycache__ is purged between mutants -- the sibling stand
# (mutstand_pending_rulings.sh) once reported a mutant as caught by ANOTHER
# mutant's failure signature because the test imports the module under test.
#
# Usage: bash tools/agent/mutstand_carrier_minion.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/batch_test/soak/carrier_terms.py
TEST=tests/test_carrier_terms.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cm.XXXXXX")
cp "$SRC" "$WORK/orig.py"
sha256sum "$SRC" > "$WORK/sum.txt"

purge_pyc() { find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null; }
restore() {
    cp "$WORK/orig.py" "$SRC"
    sha256sum -c "$WORK/sum.txt" > /dev/null || { echo "RESTORE FAILED"; exit 2; }
}

apply_mutant() {
    MUT="$1" python3 - "$SRC" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
mut = os.environ["MUT"]
PAIRS = {
    # N1: revert the fix -- minion files fall back to the reachability walk,
    #     which re-answers "every hero" through aba_minion.lua.
    "N1": ('''        if parent.endswith("minion_lib"):''', "        if False:"),
    # N2: a WRONG owner that a Dota player might well type from memory.
    "N2": ('"primal_split.lua": "brewmaster"', '"primal_split.lua": "juggernaut"'),
    # N3: an unmapped summon file walks on instead of going loud.
    "N3": ('    if os.path.dirname(rel).endswith("minion_lib"):', "    if False:"),
    # N4: the generic-by-construction set empties -- correct ids start
    #     refusing launches as `unresolved`.  Loud, and wrong.
    "N4": ('MINION_GENERIC = {"illusions.lua"}', "MINION_GENERIC = set()"),
    # N5: the optimistic escape -- call the single-owner summon generic, which
    #     exempts it from the carrier gate entirely.  This is the ORIGINAL
    #     defect wearing a different hat, and it must not pass.
    #
    #     ⚠️ The first cut of N5 only ADDED primal_split.lua to MINION_GENERIC
    #     and scored SURVIVED.  It was INERT: `hero_of` consults MINION_OWNER
    #     first and returns brewmaster before MINION_GENERIC is ever read, so
    #     the mutant changed the text and not the behaviour.  A no-op scored as
    #     a surviving mutant is the same lie as a no-op scored as a caught one,
    #     just pointed at the tests instead of the source -- which is why this
    #     stand now fingerprints behaviour (below) instead of trusting that an
    #     edited string is an edited program.
    "N5": ('MINION_OWNER = {\n    "primal_split.lua": "brewmaster",',
           'MINION_GENERIC.add("primal_split.lua")\nMINION_OWNER = {'),
}
old, new = PAIRS[mut]
if old not in src:
    sys.exit("MUTATION TARGET ABSENT for %s -- this stand cannot claim that mutant" % mut)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

# Behavioural fingerprint: what the module ANSWERS, not what its source says.
# A mutant whose fingerprint equals the baseline's changed no program, and
# calling that "SURVIVED" would blame the tests for the stand's own no-op.
fingerprint() {
    python3 - <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.getcwd(), "tools", "batch_test", "soak"))
import carrier_terms as ct
tree = ct.Tree(os.getcwd())
for cand in ("immguard", "tormself", "illumove", "illureal", "aimguard"):
    r = ct.derive_id(tree, cand)
    print("%s=%s:%s" % (cand, r["kind"], ",".join(sorted(r["heroes"]))))
k, h, _t = ct._resolve_site(tree, "bots/FunLib/minion_lib/jugg.lua", 7, 0, frozenset(), [])
print("jugg=%s:%s" % (k, ",".join(sorted(h))))
PY
}

purge_pyc
fingerprint > "$WORK/fp.base" 2>&1

echo "== mutation stand: $SRC / $TEST"
worst=0
for m in N1 N2 N3 N4 N5; do
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
    grep -E "^carrier_terms: |^FAIL " "$WORK/$m.log" | sed 's/^/       /'
    restore
done

purge_pyc
python3 "$TEST" > "$WORK/baseline.log" 2>&1
rc=$?
echo "baseline after restore: exit $rc :: $(grep -E '^carrier_terms: ' "$WORK/baseline.log")"
[ "$rc" -eq 0 ] || { echo "BASELINE RED after restore"; exit 2; }
exit $worst
