#!/usr/bin/env bash
# Mutation stand for `lionwseed` (tests/test_lion_w_fight_seed.lua).
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
# ⛔ EVERY FILE A MUTANT TOUCHES IS IN THE BACKUP LIST.  Three, because §2 and
# §3.3 of the test read three hero files.  The hero desk broke exactly this rule
# two rounds ago (charter -195): a mutant edited a file that was not backed up,
# the edit stayed in the tree for the rest of the run, and the ten mutants after
# it scored for free against a section that was already red.  The leak did NOT
# look like a leak -- it looked like one plausible SURVIVOR.
#
# ⚠️ AND THE NEEDLES ARE ANCHORED ON WHOLE LINES, not on bare identifiers.
# `perl -0p s///` without /g replaces the FIRST occurrence in the file, and this
# file has ~17 soak gates; charter -196 lost a round to a needle that landed on
# a sibling lever eleven hundred lines away and read back as a SURVIVOR.
set -u

# ⭐ tests/test_lion_w_fight_seed.lua IS IN THIS LIST from 2026-09-18, and the
# reason is the round that added M19/M20.  Every mutant above prices the SOURCE;
# the two defects that made this lever's published domain wrong (`0` where the
# tree reads 6) were both in the TEST's own SCOPE -- one corpus directory out of
# two, and the branch guard transcribed as its first disjunct.  A stand that can
# only move the source cannot price a defect that lives in the reader.
#
# ⭐⭐ tests/mock/replay_fixture.lua JOINED THE LIST 2026-09-18 (second pass),
# for M23.  §6.3 promises that this file will SAY SO on the day the loader's
# dropped mode argument starts reaching the filter -- and a promise about an
# instrument can only be priced by moving that instrument.  ⛔ It is the most
# shared file any mutant here touches, which is precisely why it is backed up
# and restore-proved rather than left out.
SRCS=(
  bots/BotLib/hero_lion.lua
  bots/BotLib/hero_crystal_maiden.lua
  bots/BotLib/hero_skeleton_king.lua
  tests/test_lion_w_fight_seed.lua
  tests/mock/replay_fixture.lua
)
SRC=bots/BotLib/hero_lion.lua
CM=bots/BotLib/hero_crystal_maiden.lua
WK=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_lion_w_fight_seed.lua
LOADER=tests/mock/replay_fixture.lua
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
echo "mutation stand: lionwseed"

restore
base=$(fails)
[ "$base" = 0 ] || { echo "  !! baseline is not green ($base failures)"; exit 3; }
echo "  ok M-base: clean tree is green (0 failures)"
OK=$((OK+1))

# --- the control ------------------------------------------------------------
mutate "M0 no-op control (comment text only)" "$SRC" \
  "s/--- The seed X\.ConsiderW's 团战 argmax starts from\./--- The seed (control) X.ConsiderW's 团战 argmax starts from./" SURVIVED

# --- the wiring -------------------------------------------------------------
# ⭐ The failure mode `lionwfight`'s own file had to learn from a stand: the
# helper exists, passes every unit test, and reaches no decision.
mutate "M1 call site reverted to the bare literal (helper wired to nothing)" "$SRC" \
  "s/\t\tlocal nMostDangerousDamage = X\.lion_FightArgmaxSeed\(\)/\t\tlocal nMostDangerousDamage = 0/" CAUGHT

mutate "M2 armed leg returns the shipped seed (lever made a no-op)" "$SRC" \
  "s/\treturn -1\n\nend\n\n\nfunction X\.ConsiderW\(\)/\treturn X.nWFightArgmaxSeedShipped\n\nend\n\n\nfunction X.ConsiderW()/" CAUGHT

mutate "M3 armed seed sits ON the floor instead of below it" "$SRC" \
  "s/\treturn -1\n\nend\n\n\nfunction X\.ConsiderW\(\)/\treturn 0\n\nend\n\n\nfunction X.ConsiderW()/" CAUGHT

mutate "M4 armed seed moved the WRONG way (raises the bar)" "$SRC" \
  "s/\treturn -1\n\nend\n\n\nfunction X\.ConsiderW\(\)/\treturn 1\n\nend\n\n\nfunction X.ConsiderW()/" CAUGHT

# --- the gate ---------------------------------------------------------------
mutate "M5 turbo conjunct dropped (fires in normal mode)" "$SRC" \
  "s/if not \( J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'lionwseed' \) \) then return X\.nWFightArgmaxSeedShipped end/if not ( J.IsSoakCandidate( 'lionwseed' ) ) then return X.nWFightArgmaxSeedShipped end/" CAUGHT

# ⛔ THE LIVE-IN-SHIPPED-PLAY MUTANT. Without §5.2's UNARMED control this one
# survives, and the lever is in every real game the day it lands.
mutate "M6 gate removed entirely (lever LIVE in shipped play)" "$SRC" \
  "s/\tif not \( J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'lionwseed' \) \) then return X\.nWFightArgmaxSeedShipped end\n\n//" CAUGHT

# ⛔ THE pullcad TRAP, and the id-collision that cost charter -196 a round.
mutate "M7 gate takes the sibling lever's id (id collision)" "$SRC" \
  "s/J\.IsSoakCandidate\( 'lionwseed' \) \) then return X\.nWFightArgmaxSeedShipped end/J.IsSoakCandidate( 'lionwfight' ) ) then return X.nWFightArgmaxSeedShipped end/" CAUGHT

mutate "M8 gate-inside-a-gate (frozen FALSE the day the sibling promotes)" "$SRC" \
  "s/if not \( J\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'lionwseed' \) \) then return X\.nWFightArgmaxSeedShipped end/if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionwseed' ) and J.IsSoakCandidate( 'lionwfight' ) ) then return X.nWFightArgmaxSeedShipped end/" CAUGHT

# --- the branch the lever reaches into --------------------------------------
mutate "M9 the strict > relaxed to >= (the seed stops being what vetoes)" "$SRC" \
  "s/\t\t\t\tif \( npcEnemyDamage > nMostDangerousDamage \)/\t\t\t\tif ( npcEnemyDamage >= nMostDangerousDamage )/" CAUGHT

# ⛔ THE SENTINEL-ESCAPES MUTANT. The whole safety argument for -1 is that the
# seed never leaves the loop. §1.4 prices that by COUNT, so this adds a use.
mutate "M10 the seed escapes the loop (a -1 reaches the motive string)" "$SRC" \
  "s/\t\tif npcMostDangerousEnemy ~= nil\n\t\t\tand J\.IsInRange\( bot, npcMostDangerousEnemy, nCastRange \+ 50 \)/\t\tlocal _leak = nMostDangerousDamage\n\t\tif npcMostDangerousEnemy ~= nil\n\t\t\tand J.IsInRange( bot, npcMostDangerousEnemy, nCastRange + 50 )/" CAUGHT

mutate "M11 the argmax re-assignment deleted (winner never updates)" "$SRC" \
  "s/\t\t\t\t\tnMostDangerousDamage = npcEnemyDamage\n//" CAUGHT

mutate "M12 the sibling lever's call site removed (pair can no longer cast)" "$SRC" \
  "s/\n\t\t\t\tand X\.lion_IsHexFightTargetInReach\( bot, npcEnemy, nCastRange \+ 50, true \)//" CAUGHT

mutate "M13 the winner acceptance test deleted (shipped stops vetoing)" "$SRC" \
  "s/\n\t\t\tand J\.IsInRange\( bot, npcMostDangerousEnemy, nCastRange \+ 50 \)//" CAUGHT

# ⭐ THE DOMAIN MUTANT. §3 and §5.3 re-implement the loop's filter, and every
# simplification in a re-implementation is an unsigned assumption. Move the
# branch's filter and the census is measuring a different set than the branch.
mutate "M14 the branch's candidate filter loses a conjunct (census drifts)" "$SRC" \
  "s/\t\t\t\tand not npcEnemy:IsDisarmed\(\)\n\t\t\t\t-- \[lionwfight\] gate off/\t\t\t\t-- [lionwfight] gate off/" CAUGHT

mutate "M15 the search ring narrowed (the corpus domain changes underneath)" "$SRC" \
  "s/\tlocal nInBonusEnemyList = J\.GetNearbyHeroes\(bot, nCastRange \+ 300, true, BOT_MODE_NONE \)/\tlocal nInBonusEnemyList = J.GetNearbyHeroes(bot, nCastRange + 50, true, BOT_MODE_NONE )/" CAUGHT

# --- ⭐ THE LINEAGE MUTANTS.  §2.1 claims three copies with the SAME seed
# polarity and §3.3 claims both ungated copies are empty on this corpus.  Those
# are claims about files this lever does not touch, so the only way to price
# them is to move those files -- which is why they are in the backup list.
mutate "M16 lineage: crystal_maiden's seed silently fixed" "$CM" \
  "s/\t\tlocal npcMostDangerousEnemy = nil\n\t\tlocal nMostDangerousDamage = 0\n/\t\tlocal npcMostDangerousEnemy = nil\n\t\tlocal nMostDangerousDamage = -1\n/" CAUGHT

mutate "M17 lineage: skeleton_king's strict > relaxed" "$WK" \
  "s/\t\t\t\tif \( npcEnemyDamage > nMostDangerousDamage \)/\t\t\t\tif ( npcEnemyDamage >= nMostDangerousDamage )/" CAUGHT

# ⛔ THE BUNDLE MUTANT. One lever in one file; a second file makes it a bundle
# no wave can take apart (GH #606).
mutate "M18 the id leaks into a second hero file (silent bundle)" "$CM" \
  "s/\t\tlocal npcMostDangerousEnemy = nil\n\t\tlocal nMostDangerousDamage = 0\n/\t\tlocal npcMostDangerousEnemy = nil\n\t\tlocal nMostDangerousDamage = J.IsSoakCandidate( 'lionwseed' ) and -1 or 0\n/" CAUGHT

# --- ⭐⭐ THE SCOPE MUTANTS (2026-09-18).  These move the TEST, not the source.
# Both reproduce a defect this file's census actually carried, and under either
# one the published reading flips from "6 search-ring all-zero frames, a solo
# end-to-end witness" back to "0, no solo domain" -- silently, with the file
# green.  That is the shape they exist to make expensive.
mutate "M19 census walks ONE corpus directory again (the tests/frames half goes blind)" "$TEST" \
  "s/    for _, dir in ipairs\(\{ FIXTURE_DIR, STAGED_DIR \}\) do/    for _, dir in ipairs({ FIXTURE_DIR }) do/" CAUGHT

mutate "M20 branch guard transcribed as its FIRST disjunct only (ally half dropped)" "$TEST" \
  "s/                    local bGuard = \(#set >= 2\)\n                        or \(bAllyDisjunct == true and nAllies >= 3\)/                    local bGuard = (#set >= 2)/" CAUGHT

# --- ⭐⭐ THE INSTRUMENT-CAVEAT MUTANTS (2026-09-18, second pass).  §3.4/§6.3
# say the branch's ENTRY predicate is blind on this corpus and measure how tight
# the resulting assumption is.  Both readings are only worth their ink if they
# bite when the measurement drifts, so both are priced here.
#
# ⛔ M21 IS THE ONE THAT MATTERS: the slack partition is what turns "an upper
# bound" (true of every corpus reading ever taken here, and therefore nearly
# free) into "zero slack on 12 of 20 frames", which is the sentence the charter
# and hero_lion.lua now carry.  A counter that quietly stops counting reads back
# as a comfortable number, not as a red file.
mutate "M21 the zero-slack counter stops firing (the partition silently unbalances)" "$TEST" \
  "s/                if nNear == 2 then c\.fight_minimum = c\.fight_minimum \+ 1/                if nNear == 99 then c.fight_minimum = c.fight_minimum + 1/" CAUGHT

# ⭐ M22: the census must ask the ally question at the SAME radius the predicate
# does, or the slack reading describes a ring J.IsInTeamFight never looked at.
mutate "M22 the slack ring narrowed to 600 (census and the predicate diverge)" "$TEST" \
  "s/                local nNear = #J\.GetNearbyHeroes\(bot, 1200, false, BOT_MODE_ATTACK\)/                local nNear = #J.GetNearbyHeroes(bot, 600, false, BOT_MODE_ATTACK)/" CAUGHT

# ⛔⛔ M22b IS A MEASURED EQUIVALENT AND IT IS DECLARED, NOT HIDDEN.  It was
# written as a CAUGHT twin of M22 (widen instead of narrow) and it came back
# SURVIVED, so the reason was bought rather than assumed:
#
#   allies in the 1200-1600 annulus, over both corpus directories
#     Lion  3 of 42 live frames carry one   -- 0 of the 13 teamfight-true frames
#     CM    9 of 70                         -- 0 of the 5
#     WK    1 of 51                         -- 0 of the 2
#
# ⇒ the annulus is NOT empty in this corpus (13 live frames have a body in it);
# it simply never overlaps the teamfight-true set, so widening the ring moves no
# count and the stand CANNOT price the radius in that direction.  ⭐ What holds
# the radius is therefore the source read in §3.4's header (J.IsInTeamFight's
# one return is at `nRadius`, and the census calls it with 1200), plus M22's
# narrowing half -- ⛔ not this mutant, and a later round may not read its
# SURVIVED as "the radius is covered".
mutate "M22b (declared equivalent) the slack ring widened to 1600 -- no teamfight frame has an ally out there" "$TEST" \
  "s/                local nNear = #J\.GetNearbyHeroes\(bot, 1200, false, BOT_MODE_ATTACK\)/                local nNear = #J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_ATTACK)/" SURVIVED

# ⭐⭐ M23 IS THE ARRIVAL DETECTOR, and it is the only mutant on this stand that
# moves the LOADER.  §6.3 promises that the day the mode argument reaches the
# filter, this file says so instead of quietly re-reading the same numbers under
# a different instrument.  The mutant makes the third argument matter; if §6.3's
# control is ever weakened to a tautology, this goes SURVIVED.
# (⚠️ tests/mock/replay_fixture.lua is in SRCS for exactly this mutant -- the
# charter's `-195` leak was a mutant editing a file nobody backed up.)
mutate "M23 the loader's GetNearbyHeroes honours its mode argument (instrument arrives)" "$LOADER" \
  "s/        rawget\(me, '__spec'\)\.GetNearbyHeroes = function\(self, radius, enemies, _\)\n            local out = \{\}/        rawget(me, '__spec').GetNearbyHeroes = function(self, radius, enemies, mode)\n            local out = {}\n            if mode == BOT_MODE_ATTACK then return out end/" CAUGHT

restore
echo
echo "mutstand lionwseed: $OK/$((OK+BAD))"
[ "$BAD" = 0 ] || exit 3
