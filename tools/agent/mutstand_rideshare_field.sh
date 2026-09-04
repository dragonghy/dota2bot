#!/usr/bin/env bash
# Mutation stand for the RIDESHARE classification leg of
# tools/agent/pending_rulings.py and its assertions in
# tests/test_pending_rulings.py (director 2026-09-04; the leg deferred eight
# rounds, deadline set in director.md's 2026-09-04T01:00Z entry, item ⑤).
#
# WHAT IT IS FOR. The defect being fixed here is invisible to an outcome test:
# `is_rideshare` read `question` alone, the bucket printed `none`, and a `none`
# from a leg that cannot see its subject is byte-identical to a `none` from a
# clean queue.  That is the same shape as GH #317 (`is_open` blind to a drifted
# status) and GH #332 / §DR.  So every claim the fix makes is put back under a
# mutant a correct assertion MUST catch -- in BOTH directions, because the
# obvious over-correction (read every field in the row) arrives looking exactly
# like the fix and would classify a dedicated-wave ask as a rideshare on the
# strength of the batch desk's own cost note.
#
# ⚠️ M2 is the one worth having.  M1/M4 only prove the assertions notice a
# NARROWER predicate; a stand made only of those is passed by
# `is_rideshare = lambda req: True`, which would empty the OTHER bucket
# entirely and call it a fix.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every single mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_rideshare_field.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (per rule 2, suspect
# the assertion before the mutation). No AWS, no network.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TOOL=tools/agent/pending_rulings.py
TEST=tests/test_pending_rulings.py

TMP=$(mktemp -d)

nrun=0; ncaught=0

# INFLIGHT names the file that is mutated RIGHT NOW, or is empty when the tree
# is clean.  See the EXIT trap below.
INFLIGHT=""

save() {
    cp "$1" "$TMP/$(basename "$1").orig"
    sha256sum "$1" > "$TMP/$(basename "$1").sha"
    INFLIGHT="$1"
}
restore() {
    cp "$TMP/$(basename "$1").orig" "$1"
    if ! sha256sum -c "$TMP/$(basename "$1").sha" >/dev/null; then
        echo "FATAL: restore of $1 did not verify -- stopping before anything else runs"
        exit 2
    fi
    INFLIGHT=""
}

# GH #418 / #468's trap.  `trap 'rm -rf "$TMP"' EXIT` is WORSE than no trap at
# all: on an interrupt it leaves the mutant in the working tree AND deletes
# $TMP, the only copy of the original.  Order inside the handler is content,
# not style: restore first, remove the copies second.
on_exit() {
    if [ -n "$INFLIGHT" ]; then
        echo "INTERRUPTED with $INFLIGHT mutated -- restoring before exit"
        restore "$INFLIGHT"
    fi
    rm -rf "$TMP"
}
trap on_exit EXIT

# Run the test file and report its BARE exit code (rule 3: never through a pipe).
run_test() {
    python3 "$TEST" > "$TMP/out.log" 2>&1
    echo $?
}

mutant() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-56s (the sed matched nothing -- the mutant never existed)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" -ne 0 ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-56s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-56s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first."
    fi
}

# --- M0: baseline -------------------------------------------------------------
# The unmutated tree must be green, or every CAUGHT below is meaningless.
m0rc=$(run_test)
echo "M0 baseline (unmutated tree)                                   exit=$m0rc"
if [ "$m0rc" -ne 0 ]; then
    echo "FATAL: the tree is already red; a mutation stand on a red tree measures nothing."
    sed -n '$p' "$TMP/out.log"
    exit 2
fi

# --- M1: the whole fix, reverted ---------------------------------------------
# The state of the tree before this round: `question` only.  It must be caught
# by the rows that put the declaration where the streams actually put it
# (hero-23's `axis`, strategy-6's `acceptance`) AND by the real-queue invariant,
# not by some incidental string.
m1() { perl -0pi -e 's/    text = " "\.join\(str\(req\.get\(field\) or ""\) for field in DECLARATION_FIELDS\)/    text = req.get("question", "") or ""/' "$TOOL"; }
mutant "M1 is_rideshare reads \`question\` alone (pre-fix)" "$TOOL" m1

# --- M2: the over-correction --------------------------------------------------
# ⭐ The mutant that makes this stand worth running.  "Read every field" is the
# tempting shape and it is WRONG in a way no `none`-vs-`some` comparison can
# see: `result` carries the batch desk's cost bookkeeping ("零 EC2 泄漏") and
# `director` carries rulings ("APPROVED -- 搭 W45"), so a dedicated-wave ask
# acquires a rideshare declaration it never made, written by somebody else,
# usually AFTER it was scheduled.  Only the converse row can catch this.
m2() { perl -0pi -e 's/for field in DECLARATION_FIELDS\)/for field in req)/' "$TOOL"; }
mutant "M2 reads every field incl. director/result (over-wide)" "$TOOL" m2

# --- M3: any -> all -----------------------------------------------------------
# A row must declare ONE marker, not all seven.  `all` reads as a fix (it is
# "stricter") and would empty the bucket again -- no real row carries all of
# 搭车 + 零 AWS 增量 + 不申请专波 + 不申请新波 + NO NEW WAVE NEEDED + NO WAVE
# + 零 EC2.  Same silent-`none` failure as M1, reached from the other side.
m3() { perl -0pi -e 's/    return any\(marker in text for marker in RIDESHARE_MARKERS\)/    return all(marker in text for marker in RIDESHARE_MARKERS)/' "$TOOL"; }
mutant "M3 requires ALL markers instead of any" "$TOOL" m3

# --- M4: the half-landed fix --------------------------------------------------
# `axis` added, `acceptance` forgotten.  23 of the 59 real declarations live
# outside `question`; strategy-6 is the one that lives in `acceptance`, and a
# stand without this mutant would let the fix ship covering 22 of the 23.
m4() { perl -0pi -e 's/^DECLARATION_FIELDS = \("axis", "question", "acceptance"\)$/DECLARATION_FIELDS = ("axis", "question")/m' "$TOOL"; }
mutant "M4 axis added but acceptance forgotten (half-landed)" "$TOOL" m4

echo "mutants: $ncaught/$nrun CAUGHT"
[ "$ncaught" -eq "$nrun" ] || exit 1
