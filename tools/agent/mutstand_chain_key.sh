#!/usr/bin/env bash
# Mutation stand for the chain-member census KEY SHAPE (GH #442).
#
# WHAT IT IS FOR.  On 2026-09-02 ten inserted COMMENT lines took four
# assertions red with nothing in `bots/` changed: the judgement table was keyed
# by a LINE NUMBER.  The repair moves the key onto the chain text.  A content
# key buys insertion-proofing, and the thing it could quietly sell in exchange
# is worse than what it buys: a genuinely NEW duplicate absorbed into an old
# judgement and never printed.  So the stand asserts BOTH directions, and the
# cells that matter are the ones where the tool must still be RED.
#
#   M0  unmutated                      -> exit 0, 13 judged, 0 new, 0 ambiguous
#   M1  the literal 09-02 event        -> exit 0 + LINE NOTE, no *NEW*
#   M1b the SAME tree, PRE-FIX tool    -> exit 3  (the stand can see the defect)
#   M2  a genuinely new duplicate      -> exit 3 + *NEW*, and NO ambiguity
#   M3  two judged rows, one key       -> exit 3 + AMBIGUOUS ANCHOR
#   M4  two live findings, one key     -> exit 3 + AMBIGUOUS ANCHOR
#
# ⭐ M2 is the load-bearing cell.  M1 only shows the tool can stay green; M2
# shows it does not stay green when it should not.  A key that never goes red
# is not insertion-proof, it is deaf.
#
# Restore discipline (evidence-discipline skill): every mutated file is copied
# FIRST, `trap restore EXIT` is installed BEFORE the first apply, and the
# restore is verified with sha256 -- not with `git checkout`, which would also
# quietly revert unrelated work in the tree.
#
# Read-only with respect to git, zero AWS, ~10s.

set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" || exit 2

TOOL="tools/agent/chain_member_census.py"
AIUG="bots/ability_item_usage_generic.lua"
PROBE="bots/mode_retreat_generic.lua"
WORK="$(mktemp -d /tmp/mutstand_chain_key.XXXXXX)"
FILES=("$TOOL" "$AIUG" "$PROBE")

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

FAILS=0
cell() {  # cell <name> <want_exit> <must_contain...> ; reads MUST_NOT via env
    local name="$1" want="$2"; shift 2
    local out rc
    out="$(python3 "$TOOL" --quiet 2>&1)"; rc=$?
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
        sed -n '1,12p' <<<"$out" | sed 's/^/      | /'
    fi
}

echo "=== M0  baseline, nothing mutated ==="
MUST_NOT='*NEW* AMBIGUOUS LINE_NOTE_UNUSED' \
    cell "M0 " 0 "judged 13, new 0; ambiguous 0"

echo "=== M1  the literal 2026-09-02 event: 10 comment lines at $AIUG:3406 ==="
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
ins = ["    -- mutstand_chain_key.sh: a comment, exactly like 77e18be9's ten."] * 10
open(p, "w", encoding="utf-8").write("\n".join(lines[:3405] + ins + lines[3405:]))
PY
MUST_NOT='*NEW* AMBIGUOUS' \
    cell "M1 " 0 "judged 13, new 0; ambiguous 0" "LINE NOTE"

echo "=== M1b the SAME mutated tree, read by the PRE-FIX tool (line-keyed) ==="
git show HEAD:"$TOOL" > "$WORK/prefix_census.py" 2>/dev/null
if [ -s "$WORK/prefix_census.py" ] && grep -q "drift_hint" "$WORK/prefix_census.py"; then
    out="$(PYTHONPATH="$REPO/tools/agent" python3 "$WORK/prefix_census.py" \
           --root "$REPO" --quiet 2>&1)"; rc=$?
    if [ "$rc" = 3 ]; then
        echo "M1b CAUGHT/OK   exit 3 (pre-fix tool calls the moved row *NEW*)"
    else
        echo "M1b *** WRONG ***   exit $rc, wanted 3"
        FAILS=$((FAILS + 1))
    fi
else
    echo "M1b SKIPPED (HEAD's $TOOL is not the pre-fix line-keyed one) -- this"
    echo "    is a SKIP, not a pass: after this change lands, HEAD carries the"
    echo "    fix and the comparison has to be made against the commit before."
fi
cp "$WORK/$(echo "$AIUG" | tr / _)" "$AIUG"

echo "=== M2  a genuinely NEW duplicate, at a site no row judges ==="
python3 - "$PROBE" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
i = next(i for i, l in enumerate(lines) if l.startswith("function "))
lines.insert(i + 1, "    if J.IsValidTarget(bot) and J.IsValidTarget(bot) then return end")
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
MUST_NOT='AMBIGUOUS' \
    cell "M2 " 3 "*NEW*" "judged 13, new 1; ambiguous 0"
cp "$WORK/$(echo "$PROBE" | tr / _)" "$PROBE"

echo "=== M3  two judged rows under one key (a dict literal would eat one) ==="
python3 - "$TOOL" <<'PY'
import sys
p = sys.argv[1]
src = open(p, encoding="utf-8").read()
row = ('    ("bots/BotLib/hero_tiny.lua", "J.IsValidTarget(botTarget)", '
       '"02aa798f", 729,\n        "IDEMPOTENT.  a second row, same key."),\n')
marker = "]\n\n#: Detector B judgements"
open(p, "w", encoding="utf-8").write(src.replace(marker, row + marker, 1))
PY
cell "M3 " 3 "AMBIGUOUS ANCHOR" "judged row written twice"
cp "$WORK/$(echo "$TOOL" | tr / _)" "$TOOL"

echo "=== M4  two LIVE findings under one key (the same chain written twice) ==="
python3 - "$PROBE" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8", errors="replace").read().split("\n")
i = next(i for i, l in enumerate(lines) if l.startswith("function "))
twin = "    if J.IsValidTarget(bot) and J.IsValidTarget(bot) then return end"
lines[i + 1:i + 1] = [twin, twin]
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
cell "M4 " 3 "AMBIGUOUS ANCHOR" "two findings, one key"
cp "$WORK/$(echo "$PROBE" | tr / _)" "$PROBE"

echo
if [ "$FAILS" = 0 ]; then
    echo "MUTSTAND  all cells behaved as specified"
else
    echo "MUTSTAND  $FAILS cell(s) did NOT -- a surviving mutant means the"
    echo "          assertion, not the mutation, is what to suspect first"
fi
exit $((FAILS == 0 ? 0 : 3))
