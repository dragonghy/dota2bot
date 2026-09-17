#!/usr/bin/env bash
# Mutation stand for tests/test_skill_slot_talent_park.lua (`SLOTPARK`).
#
# SUBJECT: bots/FunLib/aba_skill.lua -- the slot loop (X.GetSkillList), the
# talent-side picker (X.GetTalentBuild) and the skillstall look-ahead
# (X.FindUpgradableBehindHead).
#
# The three disciplines this stand carries, each bought with a real round:
#   * RESTORE FROM A COPY OUTSIDE THE TREE, verified with `sha256sum -c`.  A
#     stand that restores with `git checkout` cannot be trusted while anything
#     else in the round is also editing the tree.
#   * `cmp -s` AFTER EVERY EDIT.  A sed/perl pattern that matches nothing exits 0
#     and the stand then runs the ORIGINAL file and prints SURVIVED.  That output
#     is byte-identical to a real survivor, and the tempting misdiagnosis is to
#     weaken the assertion -- the exact reverse of evidence-discipline rule 2.
#     So: edit applied nothing => "EDIT APPLIED NOTHING", no verdict.
#   * REPORT WHICH SECTION KILLED EACH MUTANT.  A mutant killed only by §1 (the
#     literal source anchors) is barely evidence: §1 is a parse assertion, and
#     the -197 lesson is that an assertion which is true "somewhere in the file"
#     says nothing about the site that matters.  The per-mutant killer list below
#     is what shows §3-§7 are doing work.
#
# Usage: bash tools/agent/mutstand_slotpark.sh
set -u

SUBJECT="bots/FunLib/aba_skill.lua"
TEST="tests/test_skill_slot_talent_park.lua"
WORK="$(mktemp -d /tmp/mutstand_slotpark.XXXXXX)"
ORIG="$WORK/aba_skill.lua.orig"
RUNNER="$WORK/run1.lua"

cleanup() { cp -f "$ORIG" "$SUBJECT"; rm -rf "$WORK"; }
trap cleanup EXIT

cp -f "$SUBJECT" "$ORIG"
( cd "$WORK" && sha256sum aba_skill.lua.orig > manifest.sha256 )

cat > "$RUNNER" <<'LUA'
local path = ...
local ok, t = pcall(dofile, path)
if not ok then io.write('LOADFAIL ' .. tostring(t) .. '\n'); os.exit(1) end
local names = {}
for k in pairs(t) do names[#names + 1] = k end
table.sort(names)
local nBad = 0
for _, n in ipairs(names) do
    local pass, err = pcall(t[n])
    if not pass then
        nBad = nBad + 1
        io.write('KILLEDBY ' .. n:match('^(%d+[a-z]*)%.') .. '\n')
    end
end
os.exit(nBad == 0 and 0 or 1)
LUA

restore() {
    cp -f "$ORIG" "$SUBJECT"
    ( cd "$WORK" && sha256sum -c manifest.sha256 >/dev/null ) \
        || { echo "FATAL: restore failed sha256 check"; exit 9; }
}

baseline() {
    lua5.1 "$RUNNER" "$TEST" >/dev/null 2>&1
    return $?
}

# apply <needle> <replacement>  -- single literal replacement of the FIRST
# occurrence, done in python so the needle is a literal and not a regex (the
# `plain=true` / `%.`-in-a-literal family of self-inflicted misses).
apply() {
    python3 - "$SUBJECT" "$1" "$2" <<'PY'
import sys
path, needle, repl = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding='utf-8').read()
n = s.count(needle)
if n == 0:
    sys.exit(7)
s = s.replace(needle, repl, 1)
open(path, 'w', encoding='utf-8').write(s)
print(n)
PY
}

NKILL=0; NTOTAL=0; NBROKEN=0
declare -a SUMMARY=()

mutant() {
    local id="$1" desc="$2" needle="$3" repl="$4"
    NTOTAL=$((NTOTAL + 1))
    restore

    local occ
    occ="$(apply "$needle" "$repl")"
    local rc=$?
    if [ $rc -eq 7 ]; then
        echo "  $id  NEEDLE MISS -- no verdict  ($desc)"
        SUMMARY+=("$id NEEDLE-MISS")
        NBROKEN=$((NBROKEN + 1))
        return
    fi
    if cmp -s "$SUBJECT" "$ORIG"; then
        echo "  $id  EDIT APPLIED NOTHING -- no verdict  ($desc)"
        SUMMARY+=("$id EDIT-NOOP")
        NBROKEN=$((NBROKEN + 1))
        return
    fi

    local out killers
    out="$(lua5.1 "$RUNNER" "$TEST" 2>&1)"
    if [ $? -ne 0 ]; then
        killers="$(printf '%s' "$out" | grep '^KILLEDBY' | awk '{print $2}' | paste -sd, -)"
        [ -z "$killers" ] && killers="load-error"
        echo "  $id  killed by §$killers   ($desc)  [occurrences in file: $occ]"
        SUMMARY+=("$id killed:§$killers")
        NKILL=$((NKILL + 1))
    else
        echo "  $id  *** SURVIVED ***   ($desc)  [occurrences in file: $occ]"
        SUMMARY+=("$id SURVIVED")
    fi
}

echo "=== baseline (must be green before any mutant means anything) ==="
restore
if baseline; then echo "  baseline GREEN"; else echo "  baseline RED -- fix that first"; exit 8; fi

echo
echo "=== mutants ==="

# --- the interleave rule itself -------------------------------------------
mutant M1 "talent window opens at slot 9 instead of 10" \
    'i >= 10 and (i % 5 == 0' 'i >= 9 and (i % 5 == 0'

mutant M2 "talent lands on slots =1 mod 5 instead of 0 mod 5" \
    'i % 5 == 0 or ability_idx' 'i % 5 == 1 or ability_idx'

mutant M3 "second disjunct removed: talents no longer emitted on ability exhaustion" \
    'or ability_idx > #nAbilityBuildList)) then' 'or false)) then'

mutant M4 "slot count stops counting the talent entries" \
    'local totalSlots = #nAbilityBuildList + #nTalentBuildList' \
    'local totalSlots = #nAbilityBuildList + 4'

mutant M5 "talent window opens at slot 5: t10 can now be parked early" \
    'i >= 10 and (i % 5 == 0' 'i >= 5 and (i % 5 == 0'

# --- the ability/talent bookkeeping --------------------------------------
# ⚠️ M6 IS A DEMONSTRATED EQUIVALENT MUTANT, not a coverage gap.  It is kept
# because deleting it would lose the reason, and "survivor" is the shape a real
# gap has -- the next person to run this stand must not have to re-chase it.
#
# MEASURED, not argued: driving X.GetSkillList over 197 rows (synthetic rows of
# every length 1..20, where the guard could plausibly matter, plus all 177 shipped
# rows) and diffing the full slot list before/after gives ZERO differing bytes.
# Reproduce:
#   cp bots/FunLib/aba_skill.lua /tmp/aba.orig
#   <dump slot lists> ; sed the guard to `if true then` ; <dump again> ; diff
#
# WHY it is equivalent, so the reading is checkable and not just quoted:
#   * The else-branch is reached only when the talent test is false, i.e. i < 10,
#     or (i >= 10 and i%5 ~= 0 and ability_idx <= #ab).  In the second case the
#     guard is ALREADY true, so removing it cannot change anything.
#   * In the first case with the row exhausted, nAbilityBuildList[ability_idx] is
#     nil and `sAbilityList[nil]` READS as nil in Lua 5.1 (only a nil-key WRITE
#     raises), so the unguarded assignment stores nil -- byte-identical to not
#     assigning.  Its one side effect, incrementing ability_idx, only makes
#     `ability_idx > #ab` more true, and that predicate already held.
# ⇒ The guard is defensive, and this stand cannot price defensive code by
#   mutation.  ⛔ Do NOT "fix" this by weakening an assertion somewhere.
EXPECTED_EQUIVALENT="M6"
mutant M6 "else-branch drops its bounds guard -- DEMONSTRATED EQUIVALENT, see header" \
    'if ability_idx <= #nAbilityBuildList then' 'if true then'

mutant M7 "talent_idx never advances: entry 1 is emitted into every talent slot" \
    'talent_idx = talent_idx + 1' 'talent_idx = talent_idx + 0'

# --- the dead-tail pairing (#822 claim 2) --------------------------------
mutant M8 "entry 5 picks the SAME side as entry 1 (tier 10 no longer paired)" \
    "[5] = ( tTalentTreeList['t10'][1] == 0 and 2 or 1 )" \
    "[5] = ( tTalentTreeList['t10'][1] == 0 and 1 or 2 )"

mutant M9 "entry 7 points at tier 25 instead of tier 20" \
    "[7] = ( tTalentTreeList['t20'][1] == 0 and 6 or 5 )" \
    "[7] = ( tTalentTreeList['t25'][1] == 0 and 8 or 7 )"

mutant M10 "entry 3 and entry 7 both pick the low side of tier 20" \
    "[7] = ( tTalentTreeList['t20'][1] == 0 and 6 or 5 )" \
    "[7] = ( tTalentTreeList['t20'][1] == 0 and 5 or 6 )"

# --- the skillstall look-ahead (LIMIT C) ---------------------------------
mutant M11 "look-ahead starts at the head instead of behind it" \
    'for i = 2, #tQueue' 'for i = 1, #tQueue'

mutant M12 "nil-bot guard removed" \
    'if hBot == nil or type( tQueue ) ~= ' 'if type( tQueue ) ~= '

mutant M13 "non-number level guard removed" \
    "or type( nBotLevel ) ~= 'number'" 'or false'

mutant M14 "look-ahead ignores the max-level ceiling" \
    'and hAbility:GetLevel() < hAbility:GetMaxLevel()' 'and true'

# --- LIMIT A's two overrides --------------------------------------------
mutant M15 "meepo override renamed (LIMIT A would silently over-claim)" \
    "botName == 'npc_dota_hero_meepo'" "botName == 'npc_dota_hero_meepo_renamed'"

restore

echo
echo "=== verdict ==="
printf '  %s\n' "${SUMMARY[@]}"
echo
echo "  killed $NKILL / $NTOTAL    (no-verdict: $NBROKEN)"
echo "  expected-equivalent (excused, with proof in this file's header): ${EXPECTED_EQUIVALENT:-none}"
if baseline; then echo "  baseline GREEN again after restore"; else
    echo "  baseline RED after restore -- the stand corrupted the tree"; exit 9; fi

# A no-verdict mutant is never excused: it means the stand did not run, which is
# not the same as the file being weak and must not exit 0.
[ "$NBROKEN" -eq 0 ] || exit 1

# Every survivor other than the demonstrated-equivalent one is a real finding.
NEXPECTED=0
for m in $EXPECTED_EQUIVALENT; do
    printf '%s\n' "${SUMMARY[@]}" | grep -qx "$m SURVIVED" && NEXPECTED=$((NEXPECTED + 1))
done
[ $((NKILL + NEXPECTED)) -eq "$NTOTAL" ] || exit 1
exit 0
