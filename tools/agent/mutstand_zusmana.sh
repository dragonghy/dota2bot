#!/usr/bin/env bash
# Mutation stand for the STALE-MANA guard in zusult_gate.py and its pins in
# tests/test_zusult_gate_liveness.py §4 (replay-check, W46, 2026-09-04).
# Run by hand when either file is edited, and before quoting any in-domain
# count that file produces.
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusboltdom.sh):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor string is absent or NOT UNIQUE aborts instead of
#     scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS FOR.  The guard's claim is narrow and entirely about a
# WINDOW: a mana-restoring item used by ZEUS, at or after the snapshot the row
# was read from, at or before the cast, means the `unaff` flag on that row was
# computed from mana the bot no longer held when it decided.  Each of the four
# words in that sentence carries the guard, and a §4 case that would still pass
# with one of them deleted is not pinning anything -- so there is one mutant per
# word: the window START (M1, M5), the reporting (M2), the ITEM SET (M3), and
# the ACTOR (M4).
#
# Usage: bash tools/agent/mutstand_zusmana.sh
set -u
cd "$(dirname "$0")/../.."

TOOL=tools/batch_test/behavioral/zusult_gate.py
TEST=tests/test_zusult_gate_liveness.py

FILES=("$TOOL" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zusmana.XXXXXX")
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
# A mutant that silently applied to nothing -- or to one of N identical sites --
# scores "caught" for a reason the score line cannot show.
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

WINDOW="        return any(prev[-1]['t'] <= it <= t for it in mana_items)"

# ---------------------------------------------------------------------------
# M1: THE MUTANT THIS STAND EXISTS FOR.  The window start moves from "the
#     snapshot this row was read from" to the cast itself, so the gap the whole
#     defect lives in has zero width and nothing is ever stale.  This is the
#     pre-fix behaviour; if §4 cannot see it, it is pinning nothing.
echo
echo "=== M1: the sample gap collapses to zero width (pre-fix behaviour) ==="
sub "$TOOL" "$WINDOW" "        return any(t <= it <= t for it in mana_items)" || exit 3
score "M1" "4a"

# M2: the rows are still excluded from the domain but no longer REPORTED.  The
#     count silently gets better and no reader can tell why -- the exact shape
#     the missing-ability guard above this one was written to avoid.
echo
echo "=== M2: stale rows are dropped silently instead of reported ==="
sub "$TOOL" "    stale = [r for r in flagged if r['stale']]" "    stale = []" || exit 3
score "M2" "4b"

# M3: the item set stops being about mana.  Any item in the gap now excuses the
#     cast, which would quietly disarm the flag on every blink, wand-less bottle
#     use and boot toggle in the corpus.
echo
echo "=== M3: the guard fires on ANY item, not only mana income ==="
sub "$TOOL" "                  and e.get('inflictor') in MANA_RESTORE_ITEMS]" \
            "                  ]" || exit 3
score "M3" "4f"

# M4: the refill no longer has to be Zeus's own.  An ally drinking a mango
#     900 units away would excuse a leak by Zeus.
echo
echo "=== M4: anybody's mana item counts, not just Zeus's ==="
sub "$TOOL" "                  and e.get('actor') == 'npc_dota_hero_zuus'" \
            "                  and True" || exit 3
score "M4" "4h"

# M5: the window start runs 5 s early, swallowing refills the sampled mana
#     ALREADY includes.  This is the over-correction that would hide real leaks
#     -- the opposite direction from M1, and the reason 4d/4e are a control pair
#     rather than a single case.
echo
echo "=== M5: the window over-reaches backwards and hides real leaks ==="
sub "$TOOL" "$WINDOW" \
            "        return any(prev[-1]['t'] - 5 <= it <= t for it in mana_items)" || exit 3
score "M5" "4d"

# ---------------------------------------------------------------------------
echo
echo "=== score ==="
echo "mutants: $TOTAL   caught: $CAUGHT   survived: $((TOTAL - CAUGHT))"
restore
sha256sum -c "$WORK/sum.txt" > /dev/null && echo "restore verified (sha256sum -c OK)"
run_tests; FINAL=$?
echo "post-restore baseline EXIT=$FINAL"
# Disarm the trap BEFORE the workdir goes away.  With it still armed, the EXIT
# handler runs `restore` against a directory `rm -rf` has just deleted, every
# `cp` fails, and the stand prints "RESTORE FAILED -- the working tree still
# holds a mutant" and exits 2 -- on a run whose tree is provably clean (the
# `sha256sum -c` three lines up passed).  Caught on this stand's own first run:
# a teardown that reports the one failure the operator must never ignore, for a
# reason that is not about the tree at all.
trap - EXIT
rm -rf "$WORK"
[ "$CAUGHT" -eq "$TOTAL" ] && [ "$FINAL" -eq 0 ] && exit 0
exit 1
