#!/usr/bin/env bash
# Mutation stand for `lionwfight` (tests/test_lion_w_fight_reach.lua).
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
# ⛔ EVERY FILE A MUTANT TOUCHES IS IN THE BACKUP LIST, and this stand has three
# because §2 of the test reads three hero files.  The hero desk broke exactly
# this rule one round ago (charter -195): a mutant edited a file that was not
# backed up, the edit stayed in the tree for the rest of the run, and the ten
# mutants after it scored for free against a section that was already red.  The
# leak did NOT look like a leak -- it looked like one plausible SURVIVOR.  The
# list below is checked by `restore`, which dies loud rather than continuing.
set -u

SRCS=(
  bots/BotLib/hero_lion.lua
  bots/BotLib/hero_crystal_maiden.lua
  bots/BotLib/hero_skeleton_king.lua
)
SRC=bots/BotLib/hero_lion.lua
CM=bots/BotLib/hero_crystal_maiden.lua
WK=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_lion_w_fight_reach.lua
TMP=$(mktemp -d)

declare -A BASE_SHA
for f in "${SRCS[@]}"; do
  cp "$f" "$TMP/$(basename "$f").bak"
  BASE_SHA["$f"]=$(sha256sum < "$f")
done

# The restore is PROVED, not asserted: a stand that cannot show it put the tree
# back may have eaten the fix it was measuring.
restore() {
  local f now
  for f in "${SRCS[@]}"; do
    cp "$TMP/$(basename "$f").bak" "$f"
    now=$(sha256sum < "$f")
    if [ "$now" != "${BASE_SHA[$f]}" ]; then
      echo "  !! RESTORE FAILED: $f does not match the pristine copy." >&2
      echo "     Pristine copies are in $TMP -- recover from them BEFORE" >&2
      echo "     touching the tree; this stand's results are void." >&2
      exit 3
    fi
  done
}
trap 'restore; rm -rf "$TMP"' EXIT

run() {
  lua5.1 -e "
    package.path = 'tests/?.lua;' .. package.path
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
  restore
  perl -0pi -e "$expr" "$file"
  if cmp -s "$file" "$TMP/$(basename "$file").bak" && [ "$expect" = CAUGHT ]; then
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
echo "mutation stand: lionwfight"

restore
base=$(fails)
[ "$base" = 0 ] || { echo "  !! baseline is not green ($base failures)"; exit 3; }
echo "  ok M-base: clean tree is green (0 failures)"
OK=$((OK+1))

# --- the control ------------------------------------------------------------
mutate "M0 no-op control (comment text only)" "$SRC" \
  "s/--- THE DEFECT, and it is a SCOPE defect/--- THE DEFECT (control), and it is a SCOPE defect/" SURVIVED

# --- the wiring -------------------------------------------------------------
mutate "M1 call site removed (argmax back to no reach term)" "$SRC" \
  "s/\n\t\t\t\t-- \[lionwreach\] gate off.*?\n\t\t\t\tand X\.lion_IsHexFightTargetInReach\( bot, npcEnemy, nCastRange \+ 50, true \)//s" CAUGHT

mutate "M2 shipped answer no longer passed through (one-way broken)" "$SRC" \
  "s/\tif not bShippedInReach then return bShippedInReach end\n\n\tif not \( J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'lionwfight' \)/\tif not bShippedInReach then return true end\n\n\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionwfight' )/" CAUGHT

mutate "M3 turbo conjunct dropped (fires in normal mode)" "$SRC" \
  "s/if not \( J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'lionwfight' \) \) then return bShippedInReach end/if not ( J.IsSoakCandidate( 'lionwfight' ) ) then return bShippedInReach end/" CAUGHT

# ⭐ ANCHORED ON THE WHOLE GATE LINE, not on the bare IsSoakCandidate call.
# The first draft used the bare needle, and `perl -0p s///` (no /g) replaced the
# FIRST occurrence in the file -- which belonged to the SIBLING lever
# `lionwreach` eleven hundred lines up. The mutant applied, this test stayed
# green, and the SURVIVOR was a fact about the tree: the two levers had the same
# id. Anchor on `then return bShippedInReach end`, which only this helper's gate
# line carries (the sibling's ends `then return true end`).
mutate "M4 gate takes the sibling lever's id back (id collision / pullcad trap)" "$SRC" \
  "s/J\.IsSoakCandidate\( 'lionwfight' \) \) then return bShippedInReach end/J.IsSoakCandidate( 'lionwreach' ) ) then return bShippedInReach end/" CAUGHT

mutate "M5 gate-inside-a-gate (second soak call in the helper)" "$SRC" \
  "s/if not \( J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'lionwfight' \) \) then return bShippedInReach end/if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionwfight' ) and J.IsSoakCandidate( 'lionwpanic' ) ) then return bShippedInReach end/" CAUGHT

mutate "M6 armed leg answers true (lever made a no-op)" "$SRC" \
  "s/\treturn J\.IsInRange\( hBot, hTarget, nAcceptReach \)/\treturn true/" CAUGHT

mutate "M7 nil-handle guard dropped" "$SRC" \
  "s/\tif hBot == nil or hTarget == nil then return bShippedInReach end\n\n//" CAUGHT

mutate "M8 type guard dropped (a string reach would be compared)" "$SRC" \
  "s/\tif type\( nAcceptReach \) ~= 'number' then return bShippedInReach end\n\n//" CAUGHT

mutate "M9 a second call site added on a branch the header does not describe" "$SRC" \
  "s/\tlocal npcMostDangerousEnemy = nil\n\t\tlocal nMostDangerousDamage = 0\n\t\tfor _, npcEnemy in pairs\( nInBonusEnemyList \)/\tlocal npcMostDangerousEnemy = nil\n\t\tlocal _unused = X.lion_IsHexFightTargetInReach( bot, bot, 650, true )\n\t\tlocal nMostDangerousDamage = 0\n\t\tfor _, npcEnemy in pairs( nInBonusEnemyList )/" CAUGHT

# --- ⭐ THE DRIFT MUTANT.  §1.4's whole reason to exist: the reach the lever
# filters at and the reach the branch accepts at must be the SAME number.  Move
# one and armed play can REMOVE a cast shipped play makes, which falsifies the
# direction claim the entire header rests on.  A stand that cannot kill this one
# is not measuring the lever's safety, only its presence.
mutate "M10 DRIFT: lever filters tighter than the branch accepts" "$SRC" \
  "s/and X\.lion_IsHexFightTargetInReach\( bot, npcEnemy, nCastRange \+ 50, true \)/and X.lion_IsHexFightTargetInReach( bot, npcEnemy, nCastRange, true )/" CAUGHT

mutate "M11 DRIFT the other way: lever filters at the SEARCH ring (no-op)" "$SRC" \
  "s/and X\.lion_IsHexFightTargetInReach\( bot, npcEnemy, nCastRange \+ 50, true \)/and X.lion_IsHexFightTargetInReach( bot, npcEnemy, nCastRange + 300, true )/" CAUGHT

# --- the defect itself, and the shape the lever is named after ---------------
mutate "M12 the search ring narrowed instead (defect fixed ungated)" "$SRC" \
  "s/local nInRangeEnemyList = J\.GetNearbyHeroes\(bot, nCastRange, true, BOT_MODE_NONE \)\n\tlocal nInBonusEnemyList = J\.GetNearbyHeroes\(bot, nCastRange \+ 300, true, BOT_MODE_NONE \)/local nInRangeEnemyList = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )\n\tlocal nInBonusEnemyList = J.GetNearbyHeroes(bot, nCastRange + 50, true, BOT_MODE_NONE )/" CAUGHT

mutate "M13 the winner acceptance test deleted (branch stops vetoing)" "$SRC" \
  "s/\n\t\t\tand J\.IsInRange\( bot, npcMostDangerousEnemy, nCastRange \+ 50 \)//" CAUGHT

mutate "M14 the argmax seed moved off 0 (the OTHER defect, silently fixed)" "$SRC" \
  "s/\t\tlocal npcMostDangerousEnemy = nil\n\t\tlocal nMostDangerousDamage = 0\n\t\tfor _, npcEnemy in pairs\( nInBonusEnemyList \)/\t\tlocal npcMostDangerousEnemy = nil\n\t\tlocal nMostDangerousDamage = -1\n\t\tfor _, npcEnemy in pairs( nInBonusEnemyList )/" CAUGHT

# --- ⭐ THE LINEAGE MUTANTS.  §2 claims three copies with three reach postures.
# These are the reason the two sibling files are in the backup list: the claim is
# about files this lever does not touch, so the only way to price it is to move
# them.  Without these, §2 is prose with an assertion shaped like a measurement.
mutate "M15 lineage: crystal_maiden's ring widened (the correct copy broken)" "$CM" \
  "s/local nEnemysHeroesInRange = J\.GetNearbyHeroes\(bot, nCastRange, true, BOT_MODE_NONE \)\n\tlocal nEnemysHeroesInBonus = J\.GetNearbyHeroes\(bot, nCastRange \+ 200, true, BOT_MODE_NONE \)/local nEnemysHeroesInRange = J.GetNearbyHeroes(bot, nCastRange + 300, true, BOT_MODE_NONE )\n\tlocal nEnemysHeroesInBonus = J.GetNearbyHeroes(bot, nCastRange + 200, true, BOT_MODE_NONE )/" CAUGHT

mutate "M16 lineage: skeleton_king's 43-unit over-reach changed" "$WK" \
  "s/local nEnemysHerosInRange = J\.GetNearbyHeroes\(bot, nCastRange \+ 43, true, BOT_MODE_NONE \)/local nEnemysHerosInRange = J.GetNearbyHeroes(bot, nCastRange + 430, true, BOT_MODE_NONE )/" CAUGHT

mutate "M17 lineage: skeleton_king's argmax body deleted (lineage claim false)" "$WK" \
  "s/\t\tlocal npcMostDangerousEnemy = nil\n\t\tlocal nMostDangerousDamage = 0\n/\t\tlocal npcMostDangerousEnemy = nil\n/" CAUGHT

restore
echo
echo "mutstand lionwfight: $OK/$((OK+BAD))"
[ "$BAD" = 0 ] || exit 3
