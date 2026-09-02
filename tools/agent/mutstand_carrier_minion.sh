#!/usr/bin/env bash
# Mutation stand for tools/batch_test/soak/carrier_terms.py: the minion_lib
# carrier resolution (N1-N5, GH #402 (a), director 2026-09-01) and the
# OVER-BROAD draft gate (O1-O6, GH #402 (b), director 2026-09-02).
# Run by hand when either of those or tests/test_carrier_terms.py is edited.
#
# The filename still says "minion" because reports and issue comments already
# cite it by that name; the stand covers the whole file, not one half of it.
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

# A stand that is interrupted between `apply_mutant` and `restore` leaves the
# MUTANT in the working tree, where the next `git add -A` commits it. That is
# not hypothetical: see GH #418 and iterations/state.json:slotdust_gh418_20260902
# -- an un-gated `<` -> `<=` reached main as part of a gated fix, and the round's
# own mutation log names that exact edit as a mutant it had applied. The trap
# makes the restore unconditional; the loop still calls restore explicitly, which
# is harmless because restore is idempotent.
trap restore EXIT

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
    # --- the OVER-BROAD gate (GH #402 (b)) --------------------------------
    # O1: the gate never fires -- every term is called missable, which is the
    #     pre-fix world where a 128-hero disjunction read satisfied=4/4.
    "O1": ("    try:\n        rows = [(name, list(positions)) for name, positions in pool]",
           "    return True\n    try:\n        rows = [(name, list(positions)) for name, positions in pool]"),
    # O2: Hall degrades to a bare width count (only the all-positions subset).
    #     This is the `len(heroes) > N` design the issue proposed, and the
    #     stand exists partly to show what it stops seeing: a term covering one
    #     whole position is frozen TRUE at twelve heroes.
    "O2": ("    for mask in range(1, 1 << 5):", "    for mask in (31,):"),
    # O3: each position demanded once instead of twice.  Every position is
    #     filled for BOTH teams, so this quietly forgives a term that leaves a
    #     single free hero for two slots.
    "O3": ("PER_POSITION = 2", "PER_POSITION = 1"),
    # O4: the verdict still prints, the exit code no longer moves -- the gate
    #     becomes a comment.  A check that cannot fail looks exactly like a
    #     check that passes.
    "O4": ("            worst = max(worst, 2)", "            worst = max(worst, 0)"),
    # O5: only the "cannot say" branch survives; OVER-BROAD itself is dead.
    "O5": ("        if missable is not True:", "        if missable is None:"),
    # O6: the LIMIT guard is disabled -- a pool thin enough for the drafter's
    #     dead-end fallback to fire gets a confident answer from a model that
    #     no longer describes it.
    "O6": ("    if any(len(by_pos[p]) <= DRAFT_SLOTS for p in range(1, 6)):",
           "    if False:"),
    # O7: the unusable-pool branch turns optimistic instead of loud.
    "O7": ("    except (TypeError, ValueError):\n        return None",
           "    except (TypeError, ValueError):\n        return True"),
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

# The OVER-BROAD half.  Without these probes every O-mutant would fingerprint
# identically to the baseline and be scored INERT -- a fingerprint that does not
# reach the mutated code cannot tell a no-op from a change.
sys.path.insert(0, os.path.join(os.getcwd(), "tools", "batch_test", "soak"))
import io
import seed_draft
pool = seed_draft.load_pool()
mids = [n for n, ps in pool if 2 in ps]
thin = [(n, ps) for n, ps in pool if 2 not in ps] + [(n, ps) for n, ps in pool if 2 in ps][:4]
probes = [
    ("wholepool", [n for n, _ in pool], pool),
    ("allmid", mids, pool),
    ("allmid_but_one", mids[1:], pool),
    ("allmid_but_two", mids[2:], pool),
    ("one_hero", ["crystal_maiden"], pool),
    ("nopos", ["crystal_maiden"], [n for n, _ in pool]),
    ("thinpool", ["crystal_maiden"], thin),
]
for label, carriers, p in probes:
    print("dcm_%s=%s" % (label, ct.draft_can_miss(set(carriers), p)))
    buf = io.StringIO()
    rc = ct.assert_carrier_ids([2745, 2838], [{"id": label, "kind": "hero",
                                               "heroes": set(carriers), "sites": [],
                                               "why": "fp"}], p, out=buf)
    text = buf.getvalue()
    print("gate_%s=rc%d:%s" % (label, rc, "OVER-BROAD" if "OVER-BROAD" in text
                               else ("UNCHECKED" if "UNCHECKED" in text else "-")))
PY
}

purge_pyc
fingerprint > "$WORK/fp.base" 2>&1

echo "== mutation stand: $SRC / $TEST"
worst=0
for m in N1 N2 N3 N4 N5 O1 O2 O3 O4 O5 O6 O7; do
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
