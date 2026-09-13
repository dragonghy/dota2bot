#!/usr/bin/env bash
# Mutation stand for `skillstall` (tests/test_skillstall_lookahead.lua).
#
# Evidence discipline:
#   * the tree is restored from FILE COPIES, never from `git checkout` (a stand
#     that restores through git silently launders an unrelated dirty edit);
#   * the verdict reads the runner's own "N tests, M failures" COUNT, never a
#     line substring -- "10 failures" contains "0 failures" (GH #154);
#   * M0 is a deliberate NO-OP control: a stand on which every mutant dies,
#     including one that changed nothing, is measuring the harness and not the
#     assertions.
#
# TWO files, because the lever is two halves that must not be measured
# separately: the PURE look-ahead in aba_skill.lua and the GATED call site in
# ability_item_usage_generic.lua.  A stand that only mutated the helper could not
# tell a gated lever from an ungated one, which is the property GH #799
# acceptance 2 actually asks for.
set -u

SRC_SKILL=bots/FunLib/aba_skill.lua
SRC_DISP=bots/ability_item_usage_generic.lua
TEST=tests/test_skillstall_lookahead.lua
TMP=$(mktemp -d)
cp "$SRC_SKILL" "$TMP/skill.bak"
cp "$SRC_DISP"  "$TMP/disp.bak"

# The restore is PROVED, not asserted: a stand that cannot show it put the tree
# back may have eaten the fix it was measuring.
BASE_SKILL=$(sha256sum < "$SRC_SKILL")
BASE_DISP=$(sha256sum < "$SRC_DISP")
restore() {
  cp "$TMP/skill.bak" "$SRC_SKILL"
  cp "$TMP/disp.bak"  "$SRC_DISP"
  local a b; a=$(sha256sum < "$SRC_SKILL"); b=$(sha256sum < "$SRC_DISP")
  if [ "$a" != "$BASE_SKILL" ] || [ "$b" != "$BASE_DISP" ]; then
    echo "  !! RESTORE FAILED: the tree does not match the pristine copies." >&2
    echo "     pristine copies are at $TMP -- recover from them BEFORE" >&2
    echo "     touching the tree; this stand's results are void." >&2
    exit 3
  fi
}
trap 'restore; rm -rf "$TMP"' EXIT

run() {
  lua5.1 -e "
    local ok, t = pcall(dofile, '$TEST')
    if not ok then io.stderr:write('0 tests, 1 failures\n') os.exit(0) end
    local p, f = 0, 0
    for _, fn in pairs(t) do
      if pcall(fn) then p = p + 1 else f = f + 1 end
    end
    io.stderr:write(('%d tests, %d failures\n'):format(p + f, f))
  " 2>&1 >/dev/null
}

fails() { run | sed -n 's/.*, \([0-9][0-9]*\) failures/\1/p'; }

mutate() { # name  file  perl-expression  expect(CAUGHT|SURVIVED)
  local name="$1" file="$2" expr="$3" expect="$4"
  local bak="$TMP/skill.bak"; [ "$file" = "$SRC_DISP" ] && bak="$TMP/disp.bak"
  restore
  perl -0pi -e "$expr" "$file"
  if cmp -s "$file" "$bak" && [ "$expect" = CAUGHT ]; then
    echo "  !! $name: MUTATION DID NOT APPLY (needle missed) -- not a result"
    BAD=$((BAD+1)); return
  fi
  local n; n=$(fails)
  local got=CAUGHT; [ "$n" = 0 ] && got=SURVIVED
  if [ "$got" = "$expect" ]; then
    echo "  ok $name: $got ($n failures)"
    OK=$((OK+1))
  else
    echo "  !! $name: expected $expect, got $got ($n failures)"
    BAD=$((BAD+1))
  fi
}

OK=0; BAD=0
echo "mutation stand: skillstall"

restore
base=$(fails)
[ "$base" = 0 ] || { echo "  !! baseline is not green ($base failures)"; exit 3; }
echo "  ok M-base: clean tree is green (0 failures)"
OK=$((OK+1))

# --- the control -----------------------------------------------------------
mutate "M0 no-op control (comment text only)" "$SRC_SKILL" \
  "s/The look-ahead half of soak candidate/The look-ahead half (control) of soak candidate/" SURVIVED

# --- the gate --------------------------------------------------------------
mutate "M1 turbo conjunct dropped (fires in normal mode)" "$SRC_DISP" \
  "s/return J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'skillstall' \)/return J.IsSoakCandidate( 'skillstall' )/" CAUGHT

mutate "M2 gate names another lever's id" "$SRC_DISP" \
  "s/J\.IsSoakCandidate\( 'skillstall' \)/J.IsSoakCandidate( 'slotdust' )/" CAUGHT

mutate "M3 lever un-gated (armed leg runs in every game)" "$SRC_DISP" \
  "s/if X\.IsSkillStallSkipOn\(\) then/if true then/" CAUGHT

# --- the call site ---------------------------------------------------------
mutate "M4 the armed leg pops the HEAD instead of the entry it spent" "$SRC_DISP" \
  "s/table\.remove\( sAbilityLevelUpList, nSpendIdx \)/table.remove( sAbilityLevelUpList, 1 )/" CAUGHT

mutate "M5 the spent entry is never removed (offered again next frame)" "$SRC_DISP" \
  "s/\t\t\t\t\ttable\.remove\( sAbilityLevelUpList, nSpendIdx \)\n//" CAUGHT

mutate "M6 shipped guarded head pop deleted" "$SRC_DISP" \
  "s/\t+if botLevel > 25 then\n\t+print\(\"\[WARN\] Ignore ability .*?\n\t+table\.remove\( sAbilityLevelUpList, 1 \)\n\t+end\n//s" CAUGHT

# --- the helper's four admission conditions --------------------------------
mutate "M7 look-ahead may return the head (loop starts at 1)" "$SRC_SKILL" \
  "s/\tfor i = 2, #tQueue/\tfor i = 1, #tQueue/" CAUGHT

mutate "M8 IsHidden() no longer read" "$SRC_SKILL" \
  "s/\t\t\t\tand not hAbility:IsHidden\(\)\n//" CAUGHT

mutate "M9 hero-level requirement no longer read" "$SRC_SKILL" \
  "s/\t\t\t\tand nBotLevel >= hAbility:GetHeroLevelRequiredToUpgrade\(\)\n//" CAUGHT

mutate "M10 CanAbilityBeUpgraded() no longer read" "$SRC_SKILL" \
  "s/\t\t\t\tand hAbility:CanAbilityBeUpgraded\(\)\n//" CAUGHT

mutate "M11 max-level check no longer read" "$SRC_SKILL" \
  "s/\t\t\t\tand hAbility:GetLevel\(\) < hAbility:GetMaxLevel\(\)\n//" CAUGHT

mutate "M12 nil handle no longer guarded" "$SRC_SKILL" \
  "s/\t\t\tif hAbility ~= nil\n\t\t\t\tand not hAbility:IsHidden\(\)/\t\t\tif not hAbility:IsHidden()/" CAUGHT

# --- the require-cycle property --------------------------------------------
mutate "M13 helper resolves the gate itself (require cycle)" "$SRC_SKILL" \
  "s/\tif hBot == nil or type\( tQueue \) ~= 'table'/\tif not J.IsSoakCandidate( 'skillstall' ) then return nil end\n\tif hBot == nil or type( tQueue ) ~= 'table'/" CAUGHT

restore
echo
echo "mutstand skillstall: $OK/$((OK+BAD))"
[ "$BAD" -eq 0 ] || exit 3
