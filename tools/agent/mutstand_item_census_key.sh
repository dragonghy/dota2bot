#!/usr/bin/env bash
# Mutation stand for the ITEM-NAME census KEY SHAPE (GH #442 item 4).
#
# WHAT IT IS FOR.  `tests/test_item_name_census.lua` froze 11 sites by
# `KIND name path:LINE`.  A line number is a property of everything ABOVE the
# site, so any edit earlier in the file -- a pure comment will do -- pushed a pin
# out and turned the ratchet red with nothing wrong in `bots/`.  The file itself
# records FOURTEEN such re-anchorings between 08-26 and 09-02 against those 11
# pins, six of them from rounds that never read `bots/`.  The repair moves the
# key onto the pinned line's own normalized text.
#
# A content key buys insertion-proofing, and what it could quietly sell in
# exchange is worse than what it buys: a real finding absorbed into an old
# judgement and never printed -- a false alarm traded for a silent miss.  So the
# cells that matter are the ones where the ratchet must still be RED.
#
#   M0  unmutated                        -> exit 0, 10 tests 0 failures, no notes
#   M1  the literal 09-02 event          -> exit 0 + LINE NOTE, no NEW
#   M1b the SAME tree, PRE-FIX ratchet   -> exit 1  (the stand can see the defect)
#   M2  a genuinely new unknown name     -> exit 1 + NEW, and NO ambiguity
#   M3  two registered rows, one key     -> exit 1 + AMBIGUOUS ANCHOR
#   M4  two live findings, one key       -> exit 1 + AMBIGUOUS ANCHOR
#   M5  a pinned LINE is rewritten       -> exit 1 + NEW + GONE
#
# ⭐ M2 and M5 are the load-bearing cells.  M1 only shows the ratchet can stay
# green; M2 shows it does not stay green when it should not, and M5 shows the
# anchor is READING THE TEXT -- a constant anchor would pass M0 and M1 and be
# not insertion-proof but deaf.
#
# Restore discipline (evidence-discipline skill): every mutated file is copied
# FIRST, `trap restore EXIT` is installed BEFORE the first apply, and the restore
# is verified with sha256 -- not with `git checkout`, which would also quietly
# revert unrelated work in the tree.
#
# Read-only with respect to git, zero AWS, ~15s.

set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 2

RATCHET="tests/test_item_name_census.lua"
AIUG="bots/ability_item_usage_generic.lua"
RETREAT="bots/mode_retreat_generic.lua"
DEADFILE="bots/FunLib/advanced_item_strategy.lua"
WORK="$(mktemp -d /tmp/mutstand_item_census_key.XXXXXX)"
FILES=("$RATCHET" "$AIUG" "$RETREAT" "$DEADFILE")

for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)" || exit 2
done
sha256sum "${FILES[@]}" > "$WORK/before.sha256"

restore() {
    local rc=$?
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    if sha256sum -c "$WORK/before.sha256" --status; then
        echo "RESTORE   ok (all ${#FILES[@]} files byte-identical to the start)"
    else
        echo "RESTORE   *** FAILED *** -- inspect $WORK before doing anything else"
        rc=2
    fi
    exit $rc
}
trap restore EXIT

revert() { cp "$WORK/$(echo "$1" | tr / _)" "$1"; }

FAILS=0
cell() {  # cell <name> <want_exit> <must_contain...> ; reads MUST_NOT via env
    local name="$1" want="$2"; shift 2
    local out rc
    # No pipe between the command and `$?` (evidence discipline 3).
    out="$(lua5.1 tests/run_tests.lua item_name_census 2>&1)"; rc=$?
    local bad=0
    [ "$rc" = "$want" ] || { bad=1; echo "  exit $rc, wanted $want"; }
    for needle in "$@"; do
        grep -qF -- "$needle" <<<"$out" || { bad=1; echo "  missing: $needle"; }
    done
    for needle in ${MUST_NOT:-}; do
        grep -qF -- "$needle" <<<"$out" && { bad=1; echo "  present but must not be: $needle"; }
    done
    if [ "$bad" = 0 ]; then
        echo "$name  CAUGHT/OK   exit $rc"
    else
        echo "$name  *** SURVIVED/WRONG ***   exit $rc"
        FAILS=$((FAILS + 1))
        grep -E 'FAIL|AMBIGUOUS|NEW|LINE NOTE|tests,' <<<"$out" | sed -n '1,12p' | sed 's/^/      | /'
    fi
}

echo "=== M0  baseline, nothing mutated ==="
MUST_NOT='LINE_NOTE AMBIGUOUS' \
    cell "M0 " 0 "10 tests, 0 failures"

echo "=== M1  the literal 2026-09-02 event: 10 comment lines at $AIUG:3406 ==="
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
ins = ["    -- mutstand_item_census_key.sh: a comment, exactly like 77e18be9's ten."] * 10
open(p, "w", encoding="utf-8").write("\n".join(lines[:3405] + ins + lines[3405:]))
PY
MUST_NOT='AMBIGUOUS' \
    cell "M1 " 0 "10 tests, 0 failures" "LINE NOTE" "6886 -> :6896"

echo "=== M1b the SAME mutated tree, read by the PRE-FIX ratchet (line-keyed) ==="
git show HEAD:"$RATCHET" > "$WORK/prefix_ratchet.lua" 2>/dev/null
if [ -s "$WORK/prefix_ratchet.lua" ] && grep -q '^local tRegistered = {' "$WORK/prefix_ratchet.lua"; then
    cp "$WORK/prefix_ratchet.lua" "$RATCHET"
    out="$(lua5.1 tests/run_tests.lua item_name_census 2>&1)"; rc=$?
    if [ "$rc" = 1 ] && grep -qF 'MOVED' <<<"$out"; then
        echo "M1b CAUGHT/OK   exit 1 (pre-fix ratchet calls the moved pin MOVED and fails)"
    else
        echo "M1b *** WRONG ***   exit $rc, wanted 1 with MOVED"
        FAILS=$((FAILS + 1))
    fi
    revert "$RATCHET"
else
    echo "M1b SKIPPED (HEAD's $RATCHET is not the pre-fix line-keyed one) -- this"
    echo "    is a SKIP, not a pass: once this change lands, HEAD carries the fix"
    echo "    and the comparison has to be made against the commit before it."
fi
revert "$AIUG"

echo "=== M2  a genuinely NEW unknown item name, at a site no row judges ==="
python3 - "$RETREAT" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
i = next(i for i, l in enumerate(lines) if l.startswith("function "))
lines.insert(i + 1, "    if not HasItem(bot, 'item_mutstand_not_a_real_item') then return end")
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
MUST_NOT='AMBIGUOUS' \
    cell "M2 " 1 "1 NEW unknown item name" "item_mutstand_not_a_real_item"
revert "$RETREAT"

echo "=== M3  two registered rows under one key (a dict literal would eat one) ==="
python3 - "$RATCHET" <<'PY'
import sys
p = sys.argv[1]
src = open(p, encoding="utf-8").read()
row = ("    { 'PROBE', 'item_double', 'bots/FunLib/aba_item.lua', 'a11a9143', 1239,\n"
       "        'IDEMPOTENT.  a second row, same key.' },\n")
marker = "    { 'PROBE', 'item_double', 'bots/FunLib/aba_item.lua', 'a11a9143', 1239,\n"
open(p, "w", encoding="utf-8").write(src.replace(marker, row + marker, 1))
PY
cell "M3 " 1 "AMBIGUOUS ANCHOR" "judged row written twice"
revert "$RATCHET"

echo "=== M4  two LIVE findings under one key (a pinned line written twice) ==="
python3 - "$RETREAT" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
# :1053 is the registered `item_recipe` probe; duplicating it makes two findings
# whose normalized text -- and therefore whose key -- is identical.
lines.insert(1053, lines[1052])
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
cell "M4 " 1 "AMBIGUOUS ANCHOR" "two findings, one key"
revert "$RETREAT"

echo "=== M5  a pinned LINE is REWRITTEN (the anchor must notice) ==="
python3 - "$DEADFILE" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
# :315 is the registered item_battlefury lookup.  Same file, same kind, same
# name, same line number -- only the TEXT of the line changes.  A key that did
# not read the text would stay green here, which is the whole question.
assert "item_battlefury" in lines[314], lines[314]
lines[314] = lines[314].replace("illusion_heavy", "illusion_heavy_rebuilt")
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
MUST_NOT='AMBIGUOUS' \
    cell "M5 " 1 "1 NEW unknown item name" "1 registered site(s) no longer present"
revert "$DEADFILE"

echo
if [ "$FAILS" = 0 ]; then
    echo "MUTSTAND  all cells behaved as specified"
else
    echo "MUTSTAND  $FAILS cell(s) did NOT -- a surviving mutant means the"
    echo "          assertion, not the mutation, is what to suspect first"
fi
exit $((FAILS == 0 ? 0 : 3))
