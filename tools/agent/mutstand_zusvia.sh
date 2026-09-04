#!/usr/bin/env bash
# Mutation stand for the CONSUMER ATTRIBUTION in zusult_gate.py (`consumer()`)
# and its pins in tests/test_zusult_gate_liveness.py §5
# (replay-check, W45, 2026-09-04).  Run by hand when either file is edited, and
# before quoting any `in_domain via:` split that file produces.
#
# DISCIPLINE (inherited verbatim from tools/agent/mutstand_zusmana.sh):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor string is absent or NOT UNIQUE aborts instead of
#     scoring caught;
#   * the baseline is proven GREEN before the first mutant;
#   * `trap - EXIT` BEFORE `rm -rf "$WORK"` (the teardown bug this stand's
#     sibling caught on its own first run).
#
# WHAT THIS STAND IS FOR.  The attribution's claim is a DISJUNCTION with an
# explicit hole: an entity cast is ConsiderW; a point cast below hero level 10
# is ConsiderW2 because no talent can exist yet; a point cast at or above level
# 10 is neither -- it is AMBIGUOUS, because `talent7:IsTrained()` makes
# ConsiderW point-cast too.  Three limbs, and the dangerous one is the hole:
# collapsing `ambiguous` into `considerW2` turns an unknown into an exoneration
# and would read "the gate is inert here" off frames where the gate was live.
# So there is one mutant per limb (M1 entity, M2 the level boundary, M4 the
# hole), one for the direction of the boundary (M3), and one for the promise
# that the split explains the SAME casts rather than narrowing the domain (M5).
#
# Usage: bash tools/agent/mutstand_zusvia.sh
set -u
cd "$(dirname "$0")/../.."

TOOL=tools/batch_test/behavioral/zusult_gate.py
TEST=tests/test_zusult_gate_liveness.py

FILES=("$TOOL" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zusvia.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
}

trap restore EXIT

run_tests() {
    python3 tests/test_zusult_gate_liveness.py > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex); abort if the anchor is absent OR not unique.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
n = s.count(old)
if n == 0:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
if n > 1:
    sys.stderr.write("ANCHOR NOT UNIQUE in %s (%d sites): %r\n" % (f, n, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the entity limb collapses -- every cast is called a point cast.  An
#     ENTITY cast is the one form that reaches a LIVE gate with a target, so
#     calling it ConsiderW2 would exonerate exactly the casts that ARE misses.
echo
echo "=== M1: entity casts are misread as point casts ==="
sub "$TOOL" "        point = not str(ev.get('target', '')).startswith('npc_dota_hero_')" \
            "        point = True" || exit 3
score "M1" "5c"

# M2: the level test is deleted, so every point cast becomes ConsiderW2.  This
#     is the pre-attribution shortcut -- "point cast means the exempt branch" --
#     and it is the reading that would have been true on W45 by luck (all 7
#     casts were level 7-9) and wrong on any corpus with a level-10+ Zeus.
echo
echo "=== M2: the level boundary is dropped -- every point cast is ConsiderW2 ==="
sub "$TOOL" "        if zlvl is not None and zlvl < TALENT_LEVEL:" \
            "        if True:" || exit 3
score "M2" "5d"

# M3: the boundary flips.  Below level 10 -- where the exclusion is EXACT -- the
#     casts become ambiguous, and the one place the instrument can actually
#     decide stops deciding.  Opposite direction to M2, same boundary.
echo
echo "=== M3: the boundary is inverted -- the exact region stops being decided ==="
sub "$TOOL" "        if zlvl is not None and zlvl < TALENT_LEVEL:" \
            "        if zlvl is not None and zlvl > TALENT_LEVEL:" || exit 3
score "M3" "5b"

# M4: THE MUTANT THIS STAND EXISTS FOR.  The hole is filled in with the
#     flattering answer: an ambiguous cast is reported as ConsiderW2, i.e. as
#     the exemption working as written.  Nothing in a total count moves; the
#     split silently starts exonerating frames it cannot see.
echo
echo "=== M4: the ambiguous limb is laundered into ConsiderW2 ==="
sub "$TOOL" "        return 'ambiguous'" "        return 'considerW2'" || exit 3
score "M4" "5d"

# M5: the attribution starts NARROWING the domain instead of explaining it --
#     ConsiderW2 casts are dropped from `dom` outright.  That is the promise
#     §5f pins: this function must not move a single existing reading.
echo
echo "=== M5: attribution silently narrows the domain ==="
sub "$TOOL" "    dom = [r for r in flagged if r['spent'] is not False]" \
            "    dom = [r for r in flagged if r['spent'] is not False and r.get('consumer') != 'considerW2']" || exit 3
score "M5" "5a"

# ---------------------------------------------------------------------------
echo
echo "=== score ==="
echo "mutants: $TOTAL   caught: $CAUGHT   survived: $((TOTAL - CAUGHT))"
restore
sha256sum -c "$WORK/sum.txt" > /dev/null && echo "restore verified (sha256sum -c OK)"
run_tests; FINAL=$?
echo "post-restore baseline EXIT=$FINAL"
trap - EXIT
rm -rf "$WORK"
[ "$CAUGHT" -eq "$TOTAL" ] && [ "$FINAL" -eq 0 ] && exit 0
exit 1
