#!/usr/bin/env bash
# Mutation stand for tests/test_tpstale_recover_leak.lua (charter 0NEXT13).
#
# Every mutant is applied to the SHIPPED implementation, never to a copy of it
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate).  Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP, which is a failure
# of the stand, not a pass of the code.
#
# Restore is from a byte copy taken before the first mutation and verified with
# cmp afterwards, so a stand that dies mid-run cannot leave a mutant shipped.
#
# Usage: bash tools/agent/mutstand_tpstale.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

AIUG=bots/ability_item_usage_generic.lua
JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_tpstale_recover_leak.lua
BAK=$(mktemp)
BAKJ=$(mktemp)
BAKT=$(mktemp)
cp "$AIUG" "$BAK"
cp "$JMZ" "$BAKJ"
cp "$TEST" "$BAKT"

restore() {
    cp "$BAK" "$AIUG"
    cp "$BAKJ" "$JMZ"
    cp "$BAKT" "$TEST"
    if ! cmp -s "$BAK" "$AIUG" || ! cmp -s "$BAKJ" "$JMZ" \
        || ! cmp -s "$BAKT" "$TEST"; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

# run_one <name> <file> <landed-grep> <expect-count> <what it should do>
# Applies whatever the caller already edited; here we only measure.
check() {
    local name="$1" file="$2" needle="$3" want="$4" expect="$5"
    local got
    got=$(grep -c -- "$needle" "$file")
    if [ "$got" != "$want" ]; then
        echo "  $name: NO-OP -- edit did not land (grep -c '$needle' = $got, wanted $want)"
        fails=$((fails + 1))
        restore
        return
    fi
    if lua5.1 tests/run_tests.lua tpstale_recover_leak >/dev/null 2>&1; then
        if [ "$expect" = "CAUGHT" ]; then
            echo "  $name: SURVIVED -- the suite is green on a mutant"
            fails=$((fails + 1))
        else
            echo "  $name: SURVIVED (as intended -- control)"
        fi
    else
        if [ "$expect" = "CAUGHT" ]; then
            echo "  $name: CAUGHT"
        else
            echo "  $name: RED -- the control mutant went red, so at least one "
            echo "        assertion is keyed to something it should not be"
            fails=$((fails + 1))
        fi
    fi
    restore
}

echo "== mutation stand: tpstale =="

# M1  The gate stops naming its own id.  A gate that names nothing is armed by
#     nothing, so the whole lever silently no-ops -- the 'pullcad' failure mode,
#     and the one a wiring census cannot see.
sed -i "s/J.IsSoakCandidate( 'tpstale' )/J.IsSoakCandidate( 'tpstalez' )/" "$JMZ"
check "M1 gate id renamed" "$JMZ" "IsSoakCandidate( 'tpstalez' )" 1 CAUGHT

# M1b The helper stops being gate-first: turbo is asked before the candidate id.
#     Nothing about the id, the call site or the answer changes -- unarmed it
#     simply reaches an engine call it is not allowed to reach. The suite
#     enforces this for the sibling helpers; it has to enforce it here too, or
#     the convention holds only where somebody remembered to test it.
python3 - "$JMZ" <<'PY2'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index('function J.ShouldDropUnownedRecoverTp')
gate = "\tif not J.IsSoakCandidate( 'tpstale' ) then return false end\n"
turbo = "\tif not J.IsModeTurbo() then return false end\n"
marked = "\tif not J.IsModeTurbo() then return false end -- MUT1B\n"
body = s[i:i + 400]
assert gate + turbo in body, 'the helper is not in the expected two-line order'
s = s[:i] + body.replace(gate + turbo, marked + gate, 1) + s[i + 400:]
open(p, 'w', encoding='utf-8').write(s)
PY2
check "M1b helper turbo-before-gate" "$JMZ" "MUT1B" 1 CAUGHT

# M2  The gated block assigns a DESTINATION instead of dropping one.  This is
#     the one direction the lever must never have: armed would be able to OPEN
#     the branch, turning a narrowing into a widening.  Nothing about the gate,
#     the id, or the call site changes -- only the polarity of what it does.
#     Targeted by OFFSET, not by pattern: `tpLoc = nil` at three tabs also
#     occurs in the defend branch's ShouldAllowDefendTp clear, and a sed keyed
#     to the line text mutated both -- a different mutant than the one this leg
#     names, which is exactly the substitution a stand must not make silently.
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index("J.ShouldDropUnownedRecoverTp(")
j = s.index("tpLoc = nil", i)
s = s[:j] + "tpLoc = J.GetTeamFountain() -- MUT2" + s[j + len("tpLoc = nil"):]
open(p, 'w', encoding='utf-8').write(s)
PY
check "M2 drop becomes an assignment" "$AIUG" "MUT2" 1 CAUGHT

# M3  The ownership flag is set UNCONDITIONALLY, one line above the branch's own
#     conjunction, instead of inside it.  Every existence check still passes --
#     the flag is declared, set, read, and the gate is intact -- and the lever
#     becomes a no-op on every frame, because the flag it reads is now true
#     everywhere.  This is the 'order-blind' mutant (the M3 shape of
#     mutstand_pullnolane): structure survives, meaning does not.
sed -i "s/^\t\tlocal bRecoverTpIsOurs = false$/\t\tlocal bRecoverTpIsOurs = true/" "$AIUG"
check "M3 flag true before the conjunction" "$AIUG" "^		local bRecoverTpIsOurs = true$" 1 CAUGHT

# M4  The recorded exposure count is zeroed.  A lever with an empty domain must
#     not ship, and the census is the only thing that knows the domain is not
#     empty -- so the assertion that guards it has to be keyed to the number,
#     not merely to the number's presence.
sed -i "s/    inner_shut = 10,/    inner_shut = 0,/" "$TEST"
check "M4 census exposure zeroed" "$TEST" "inner_shut = 0," 1 CAUGHT

# CONTROL  A comment-only edit inside the shipped block.  It must SURVIVE: if it
#     does not, some assertion is keyed to comment text rather than to code, and
#     every CAUGHT above would be suspect for the same reason.
sed -i "s/-- \[tpstale\] see the block above the conjunction/-- [tpstale] SEE THE BLOCK ABOVE THE CONJUNCTION/" "$AIUG"
check "CONTROL comment-only edit" "$AIUG" "SEE THE BLOCK ABOVE THE CONJUNCTION" 1 SURVIVE

echo
if [ "$fails" -eq 0 ]; then
    echo "STAND GREEN -- 5 mutants CAUGHT, control SURVIVED, 0 NO-OP"
    exit 0
fi
echo "STAND RED -- $fails leg(s) failed"
exit 1
