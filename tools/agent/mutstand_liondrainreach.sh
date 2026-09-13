#!/usr/bin/env bash
# Mutation stand for `liondrainreach` (tests/test_lion_drain_creep_reach.lua).
#
# Evidence discipline:
#   * the tree is restored from a FILE COPY, never from `git checkout` (a stand
#     that restores through git silently launders an unrelated dirty edit);
#   * the verdict reads the runner's own "N tests, M failures" COUNT, never a
#     line substring -- "10 failures" contains "0 failures" (GH #154);
#   * M0 is a deliberate NO-OP control: a stand on which every mutant dies,
#     including one that changed nothing, is measuring the harness and not the
#     assertions.
set -u

SRC=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_drain_creep_reach.lua
TMP=$(mktemp -d)
cp "$SRC" "$TMP/src.bak"

# The restore is PROVED, not asserted: a stand that cannot show it put the tree
# back may have eaten the fix it was measuring.  `restore` compares the file's
# sha256 against the pristine copy taken before the first mutation and dies loud
# if they differ, so every mutant in the loop below starts from a tree that has
# been shown byte-identical to the original.
BASE_SHA=$(sha256sum < "$SRC")
restore() {
  cp "$TMP/src.bak" "$SRC"
  local now; now=$(sha256sum < "$SRC")
  if [ "$now" != "$BASE_SHA" ]; then
    echo "  !! RESTORE FAILED: $SRC does not match the pristine copy." >&2
    echo "     pristine=$BASE_SHA" >&2
    echo "     now     =$now" >&2
    echo "     A pristine copy is at $TMP/src.bak -- recover from it BEFORE" >&2
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

mutate() { # name  perl-expression  expect(CAUGHT|SURVIVED)
  local name="$1" expr="$2" expect="$3"
  restore
  perl -0pi -e "$expr" "$SRC"
  if cmp -s "$SRC" "$TMP/src.bak" && [ "$expect" = CAUGHT ]; then
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
echo "mutation stand: liondrainreach"

restore
base=$(fails)
[ "$base" = 0 ] || { echo "  !! baseline is not green ($base failures)"; exit 3; }
echo "  ok M-base: clean tree is green (0 failures)"
OK=$((OK+1))

mutate "M0 no-op control (comment text only)" \
  "s/THE SIZE OF THE GAP, read off the KV/THE SIZE OF THE GAP (control), read off the KV/" SURVIVED

mutate "M1 call site removed (branch back to no distance term)" \
  "s/\n\t\t\t\t-- \[liondrainreach\] gate off.*?\n\t\t\t\tand X\.lion_IsDrainCreepInReach\( bot, nCreep, nCastRange, true \)//s" CAUGHT

mutate "M2 shipped answer no longer passed through (one-way broken)" \
  "s/	if not bShippedInReach then return bShippedInReach end\n\n	if not \( J\.IsModeTurbo/	if not bShippedInReach then return true end\n\n	if not ( J.IsModeTurbo/" CAUGHT

mutate "M3 turbo conjunct dropped (fires in normal mode)" \
  "s/if not \( J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'liondrainreach' \) \)/if not ( J.IsSoakCandidate( 'liondrainreach' ) )/" CAUGHT

mutate "M4 gate names another lever's id (pullcad trap)" \
  "s/J\.IsSoakCandidate\( 'liondrainreach' \)/J.IsSoakCandidate( 'liondrainmi' )/" CAUGHT

mutate "M5 gate-inside-a-gate (second soak call in the helper)" \
  "s/if not \( J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'liondrainreach' \) \) then return bShippedInReach end/if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainreach' ) and J.IsSoakCandidate( 'liondrain' ) ) then return bShippedInReach end/" CAUGHT

mutate "M6 armed leg answers true (lever made a no-op)" \
  "s/	return J\.IsInRange\( hCreep, hBot, nCastRange \)/	return true/" CAUGHT

mutate "M7 armed leg measures against the search ring instead of cast range" \
  "s/	return J\.IsInRange\( hCreep, hBot, nCastRange \)/	return J.IsInRange( hCreep, hBot, 1600 )/" CAUGHT

mutate "M8 call site hands the helper the search ring, not the branch's own ring" \
  "s/and X\.lion_IsDrainCreepInReach\( bot, nCreep, nCastRange, true \)/and X.lion_IsDrainCreepInReach( bot, nCreep, 1600, true )/" CAUGHT

mutate "M9 type guard dropped (a string range would be compared)" \
  "s/	if type\( nCastRange \) ~= 'number' then return bShippedInReach end\n//" CAUGHT

mutate "M10 nil-handle guard dropped" \
  "s/	if hBot == nil or hCreep == nil then return bShippedInReach end\n\n//" CAUGHT

# M11 anchors on `local nEnemyCreepList = ...`, NOT on the bare
# `bot:GetNearbyCreeps( 1600, true )`.  The bare needle also occurs, EARLIER, in
# the helper header that quotes the defect -- the first draft of this mutant
# rewrote that sentence, applied cleanly, and SURVIVED, because prose is not the
# branch.  A mutant that edits a comment is not a result.
mutate "M11 the search ring itself narrowed (the defect fixed ungated)" \
  "s/local nEnemyCreepList = bot:GetNearbyCreeps\\( 1600, true \\)/local nEnemyCreepList = bot:GetNearbyCreeps( 850, true )/" CAUGHT

mutate "M12 the 349 disjunct deleted (section 5 registration)" \
  "s/ or nCreep:GetMana\(\) > 349//" CAUGHT

mutate "M13 a second call site added on a branch the header does not describe" \
  "s/	--团战吸蓝\n/	--团战吸蓝\n	local _unused = X.lion_IsDrainCreepInReach( bot, bot, 850, true )\n/" CAUGHT

restore
echo
echo "mutstand liondrainreach: $OK/$((OK+BAD))"
[ "$BAD" -eq 0 ] || exit 3
