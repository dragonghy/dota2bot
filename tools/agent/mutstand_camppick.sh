#!/usr/bin/env bash
# Mutation stand for tests/test_camppick_target_tier.lua (charter 0NEXT15,
# GH #137 §4 suggestion 2 / replay desk handoff 2026-09-13T00:4xZ).
#
# Every mutant is applied to the SHIPPED implementation, never to a copy of it
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate).  Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP, which is a failure
# of the stand, not a pass of the code.
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.  sha256sum rather than `git diff --quiet` on purpose: this stand is
# meant to be runnable mid-work, and a git comparison against the index reports
# DIRTY for every uncommitted line of the change under test.
#
# Usage: bash tools/agent/mutstand_camppick.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

SITE=bots/FunLib/aba_site.lua
FARM=bots/mode_farm_generic.lua
BAKS=$(mktemp)
BAKF=$(mktemp)
cp "$SITE" "$BAKS"
cp "$FARM" "$BAKF"
SUMS=$(sha256sum "$SITE" "$FARM")

restore() {
    cp "$BAKS" "$SITE"
    cp "$BAKF" "$FARM"
    if [ "$(sha256sum "$SITE" "$FARM")" != "$SUMS" ]; then
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
    if lua5.1 tests/run_tests.lua camppick_target_tier >/dev/null 2>&1; then
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

echo "== mutation stand: camppick =="

# M1  The lever stops reading its own argument: the filter is always told
#     "unarmed".  Gate, id, call sites and arity all still look right, and a
#     wiring census still reports WIRED -- the lever simply never fires.  This
#     is the failure mode the repo keeps paying for (pullcad, AGENTS.md).
sed -i 's/____exports.FilterFarmNeutrals(creepList, bot:GetLevel(), bStrictAncient)/____exports.FilterFarmNeutrals(creepList, bot:GetLevel(), false)/' "$SITE"
check "M1 strict flag dropped" "$SITE" "bot:GetLevel(), false)" 1 CAUGHT

# M2  Only the maxHP selector keeps reading the filtered list; the other two
#     revert to the raw one.  viper is a maxHP farmer, so a stand that only ever
#     drove viper through GetMaxHPCreep would NOT notice -- this leg exists to
#     prove the [fix] assertions are keyed to the decision and not to one
#     branch.  Its partner is M3.
sed -i 's/targetCreep = ____exports.GetMaxHPCreep(tPick)$/targetCreep = ____exports.GetMaxHPCreep(creepList) -- MUT2/' "$SITE"
check "M2 maxHP branch unfiltered" "$SITE" "MUT2" 2 CAUGHT

# M3  The final fallback (`targetCreep or GetMinHPCreep(...)`) reverts to the raw
#     list.  Unlike M2 this fires only when the branch selection came back nil,
#     which is exactly the all-ancient case [limit] pins.
sed -i 's/return targetCreep or ____exports.GetMinHPCreep(tPick)/return targetCreep or ____exports.GetMinHPCreep(creepList) -- MUT3/' "$SITE"
check "M3 fallback unfiltered" "$SITE" "MUT3" 1 CAUGHT

# M4  THE CAMPFARM SHAPE.  The lever filters the caller's list in place instead
#     of a copy -- i.e. it becomes 'campfarm' rather than the presence-preserving
#     alternative to it.  Every behavioural assertion in the file still passes:
#     the bot still stops picking the ancient at 10..11, still no-ops at 12,
#     still no-ops at 9.  Only [presence] can tell these two levers apart, and
#     this leg is the proof that it does.  If this mutant ever SURVIVES, the two
#     ids are measuring the same thing and one of them should be withdrawn.
python3 - "$SITE" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = """    local tPick = ____exports.FilterFarmNeutrals(creepList, bot:GetLevel(), bStrictAncient)"""
new = """    local tPick = ____exports.FilterFarmNeutrals(creepList, bot:GetLevel(), bStrictAncient) -- MUT4
    if not rawequal(tPick, creepList) then
        for i = #creepList, 1, -1 do table.remove(creepList, i) end
        for i, u in ipairs(tPick) do creepList[i] = u end
    end"""
assert old in s, 'the filter line is not in the expected shape'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
check "M4 filters the caller's list (= campfarm)" "$SITE" "MUT4" 1 CAUGHT

# M5  The gate names a second soak id.  AGENTS.md: a gate written as
#     `IsSoakCandidate('X') and IsSoakCandidate('Y')` is frozen FALSE the day Y
#     is promoted, because a promoted id appears in no armed string -- and
#     check_armed_wiring.py still calls it WIRED.
#     The needle names BOTH ids on purpose: `IsSoakCandidate('campfarm'))` alone
#     already matches NeutralFarmList's own (legitimate) gate one screen up, so
#     it would report the edit as landed whether or not it was.
sed -i "s/J.IsSoakCandidate('camppick'))/J.IsSoakCandidate('camppick') and J.IsSoakCandidate('campfarm'))/" "$FARM"
check "M5 gate conjoined with campfarm" "$FARM" "IsSoakCandidate('camppick') and J.IsSoakCandidate('campfarm'))" 1 CAUGHT

# M6  The lever stops being turbo-only.  Nothing about the id or the call sites
#     changes; the shipped default simply becomes reachable outside Turbo, which
#     is the one thing every gated fix in this repo promises it is not.
sed -i "s/J.IsModeTurbo() and J.IsSoakCandidate('camppick'))/J.IsSoakCandidate('camppick')) -- MUT6/" "$FARM"
check "M6 turbo-only dropped" "$FARM" "MUT6" 1 CAUGHT

# M7  One call site drifts back past the wrapper.  The gate still exists, still
#     resolves once, still names one id -- but one of the four selections is no
#     longer behind it.  This is the drift the call-site COUNT exists to catch,
#     and it is invisible to every behavioural assertion in the file.
python3 - "$FARM" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
assert s.count('FarmNeutralTarget(bot, neutralCreeps)') == 3
s = s.replace('FarmNeutralTarget(bot, neutralCreeps)',
              'J.Site.FindFarmNeutralTarget(neutralCreeps) -- MUT7', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
check "M7 one call site bypasses the gate" "$FARM" "MUT7" 1 CAUGHT

# M8  The ladder constant moves to 10, i.e. somebody "aligns the four
#     thresholds" by pulling the ladder DOWN to the shipped clauses instead of
#     pulling the clauses up.  That silently empties the 10..11 band -- the
#     lever's entire domain -- while leaving every gate and call site intact.
sed -i 's/____exports.ANCIENT_MIN_LEVEL = 12/____exports.ANCIENT_MIN_LEVEL = 10 -- MUT8/' "$SITE"
check "M8 ladder pulled down to 10" "$SITE" "MUT8" 1 CAUGHT

# CONTROL  A comment-only edit inside the function under test.  It must stay
#     GREEN: if it goes red, some assertion is keyed to file bytes rather than
#     to behaviour, and every CAUGHT above is suspect.
#     Anchored on the `local tPick` line, which occurs exactly once; the
#     `local botName` line this first used occurs three times in the file, so
#     the edit landed three times and the stand called its own control a NO-OP.
sed -i 's/^    local tPick = /    -- CONTROLNOOP\n    local tPick = /' "$SITE"
check "CONTROL comment-only edit" "$SITE" "CONTROLNOOP" 1 SURVIVED

echo
if [ "$fails" -eq 0 ]; then
    echo "mutation stand: OK (8 mutants CAUGHT, control SURVIVED, 0 NO-OP)"
    exit 0
fi
echo "mutation stand: $fails leg(s) failed"
exit 1
