#!/usr/bin/env bash
# Mutation stand for tests/test_isvalidcreep_bound_completeness.lua
# (strategy charter backlog 0NEXT16: "should utils.IsValidCreep's `> 9` itself
# be narrowed, now that 'camppick' aligns the same bound at the call layer?").
#
# The test file's job is to make ONE ruling falsifiable: narrowing the literal
# is incomplete on its own path (the armor-reduction shortcut outruns it) and
# where it does bite it changes more than ancient-refusal (a 'nearest' farmer
# silently becomes a minHP one).  Every mutant below is a way that ruling could
# be wrong; a mutant that SURVIVES means the file argues for the ruling without
# measuring it.
#
# Every mutant is applied to the SHIPPED implementation, never to a copy
# (evidence-discipline rule 1).  Each leg proves its edit LANDED with grep -c
# before running the test; an edit that did not land is NO-OP, a failure of the
# stand rather than a pass of the code.  Restore is from a byte copy verified
# with sha256sum, so a stand that dies mid-run cannot leave a mutant shipped.
#
# Usage: bash tools/agent/mutstand_isvalidcreep_bound.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

SITE=bots/FunLib/aba_site.lua
UTIL=bots/FunLib/utils.lua
BAKS=$(mktemp)
BAKU=$(mktemp)
cp "$SITE" "$BAKS"
cp "$UTIL" "$BAKU"
SUMS=$(sha256sum "$SITE" "$UTIL")

restore() {
    cp "$BAKS" "$SITE"
    cp "$BAKU" "$UTIL"
    if [ "$(sha256sum "$SITE" "$UTIL")" != "$SUMS" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

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
    if lua5.1 tests/run_tests.lua isvalidcreep_bound >/dev/null 2>&1; then
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
            echo "  $name: RED -- the control mutant went red, so at least one"
            echo "        assertion is keyed to something it should not be"
            fails=$((fails + 1))
        fi
    fi
    restore
}

echo "== mutation stand: IsValidCreep bound completeness =="

# M1  The shortcut in GetMaxHPCreep starts respecting IsValidCreep -- i.e.
#     somebody "fixes" half the incompleteness this ruling turns on.  If the
#     file cannot tell, its central claim ("narrowing the literal is not enough")
#     is being asserted rather than measured.
python3 - "$SITE" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "        if not creep:IsNull() and ____exports.HasArmorReduction(creep) then"
new = "        if IsValidCreep(creep) and ____exports.HasArmorReduction(creep) then -- MUT1"
assert s.count(old) == 2, 'the shortcut no longer appears exactly twice'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
check "M1 maxHP shortcut respects IsValidCreep" "$SITE" "MUT1" 1 CAUGHT

# M2  The same edit, applied to GetMinHPCreep instead.  Its partner is M1: a
#     file that only ever drove the maxHP selector would catch M1 and miss this,
#     which is exactly how "the bound is incomplete" could end up proven for one
#     branch and assumed for the other.
python3 - "$SITE" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "        if not creep:IsNull() and ____exports.HasArmorReduction(creep) then"
new = "        if IsValidCreep(creep) and ____exports.HasArmorReduction(creep) then -- MUT2"
assert s.count(old) == 2, 'the shortcut no longer appears exactly twice'
i = s.rindex(old)
open(p, 'w', encoding='utf-8').write(s[:i] + new + s[i + len(old):])
PY
check "M2 minHP shortcut respects IsValidCreep" "$SITE" "MUT2" 1 CAUGHT

# M3  GetNearestCreep starts SCANNING instead of testing [1] only.  That single
#     line is the whole mechanism behind the typeswap reading: with a scan, a
#     narrowed literal really would mean "the nearest non-ancient", camppick
#     and the literal would agree, and the ruling would have to be re-derived.
python3 - "$SITE" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = """    if IsValidCreep(creepList[1]) then
        return creepList[1]
    end
    return nil"""
new = """    for ____, c in ipairs(creepList) do -- MUT3
        if IsValidCreep(c) then return c end
    end
    return nil"""
assert s.count(old) == 1, 'GetNearestCreep is not in the expected shape'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
check "M3 GetNearestCreep scans instead of testing [1]" "$SITE" "MUT3" 1 CAUGHT

# M4  The literal stops refusing ancients at all.  This is the world in which
#     there is nothing to narrow, and every "the shipped bound already refuses
#     here" control in the file is false.
sed -i 's/GetBot():GetLevel() > 9 or not target:IsAncientCreep()/GetBot():GetLevel() > 0 or not target:IsAncientCreep()/' "$UTIL"
check "M4 the literal stops refusing ancients" "$UTIL" "GetLevel() > 0 or not target:IsAncientCreep()" 1 CAUGHT

# M5  camppick's filter no-ops: armed, it hands the caller's list straight back.
#     The comparison half of the typeswap reading dies with it -- and a lever
#     that no-ops while every gate and call site still looks right is the
#     failure mode this repo keeps paying for (pullcad, AGENTS.md).
sed -i 's/    if not bStrictAncient or botLevel >= ____exports.ANCIENT_MIN_LEVEL then/    if true or not bStrictAncient or botLevel >= ____exports.ANCIENT_MIN_LEVEL then -- MUT5/' "$SITE"
check "M5 camppick filter no-ops" "$SITE" "MUT5" 1 CAUGHT

# M6  THE CAMPFARM SHAPE.  The filter also empties and rewrites the CALLER's
#     table, so presence stops being preserved.  Every ancient-refusal
#     assertion in this file still passes under it.  The leg exists so this
#     file cannot be quoted as an argument for filtering the caller's list --
#     the shape GH #265 photographed a level-4 Earthshaker dying inside.
python3 - "$SITE" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = """    if not bDropped then
        return creepList
    end
    return kept
end"""
new = """    if not bDropped then
        return creepList
    end
    for i = #creepList, 1, -1 do table.remove(creepList, i) end -- MUT6
    for i, u in ipairs(kept) do creepList[i] = u end
    return kept
end"""
assert s.count(old) == 1, 'FilterFarmNeutrals is not in the expected shape'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
check "M6 filter mutates the caller's table (= campfarm)" "$SITE" "MUT6" 1 CAUGHT

# CONTROL  A comment-only edit inside the region under test.  It must stay
#     GREEN: if it goes red, some assertion is keyed to file bytes rather than
#     to behaviour, and every CAUGHT above is suspect.  Anchored on the
#     GetNearestCreep header line, which occurs exactly once.
sed -i 's/^____exports.GetNearestCreep = function(creepList)/-- CONTROLNOOP\n____exports.GetNearestCreep = function(creepList)/' "$SITE"
check "CONTROL comment-only edit" "$SITE" "CONTROLNOOP" 1 SURVIVED

echo
if [ "$fails" -eq 0 ]; then
    echo "mutation stand: OK (6 mutants CAUGHT, control SURVIVED, 0 NO-OP)"
    exit 0
fi
echo "mutation stand: $fails leg(s) failed"
exit 1
