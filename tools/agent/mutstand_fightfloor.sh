#!/usr/bin/env bash
# Mutation stand for tests/test_fightfloor_parity_floor.lua.
#
# ⛔ WHY: that test was green on its FIRST run. A gate test that has never been
# shown to go red is indistinguishable from one that asserts nothing, and this
# lever's whole claim is a two-value flip on one real frame -- exactly the shape
# a vacuous assertion imitates best.
#
# ⛔ SCORING: a mutant that dies with the WRONG message counts as SURVIVED.
# Matching the wrong assertion is how a test keeps its green for a reason that
# has nothing to do with the defect. tests/run_tests.lua sorts case names, so
# which assertion speaks first is deterministic and the `want` strings below are
# the ones actually observed, not the ones that read best.
#
# Restores from a byte copy, never from git checkout: the tree may carry
# uncommitted work and a checkout would eat it (evidence-discipline 1).
set -u

T=tests/test_fightfloor_parity_floor.lua
declare -a FILES=(
  "$T"
  bots/FunLib/jmz_func.lua
)
TMP="$(mktemp -d)"
for f in "${FILES[@]}"; do cp "$f" "$TMP/$(echo "$f" | tr / _)"; done
restore() {
  for f in "${FILES[@]}"; do cp "$TMP/$(echo "$f" | tr / _)" "$f"; done
}

# ⛔ A stand that merely CALLS restore and reports success proves nothing --
# tests/test_mutstand_restore_trap.py makes a byte-level round-trip proof the
# contract. Hash the originals now and re-hash at the end.
sha256sum "${FILES[@]}" > "$TMP/BASELINE.sha256" 2>/dev/null
verify_restore() {
  if sha256sum --quiet -c "$TMP/BASELINE.sha256" >/dev/null 2>&1; then
    echo "  restore  VERIFIED (sha256 round-trip on ${#FILES[@]} file(s))"
    return 0
  fi
  echo "  !! RESTORE DID NOT ROUND-TRIP -- these files differ from the originals:"
  sha256sum --quiet -c "$TMP/BASELINE.sha256" 2>&1 | grep -v ': OK$' || true
  return 1
}
trap 'restore; rm -rf "$TMP"' EXIT

caught=0; survived=0

run_case() { # name  want-substring  mutate-cmd
  local name="$1" want="$2" cmd="$3"
  restore
  bash -c "$cmd" || { echo "  !! mutate failed: $name"; survived=$((survived+1)); return; }
  # ⛔ The mutation must be PROVED to have landed (GH #846: a mutant that was
  # never applied still scores). Every command below is a sed/perl whose match
  # is unique, so a no-op edit leaves the file byte-identical -- catch that.
  if sha256sum --quiet -c "$TMP/BASELINE.sha256" >/dev/null 2>&1; then
    echo "  SURVIVED  $name  (the mutation did not change any file)"
    survived=$((survived+1)); restore; return
  fi
  local out rc
  out="$(lua5.1 tests/run_tests.lua "$(basename "$T")" 2>&1)"; rc=$?
  restore
  if [ "$rc" -eq 0 ]; then
    echo "  SURVIVED  $name  (test stayed GREEN)"
    survived=$((survived+1))
  elif echo "$out" | grep -qF "$want"; then
    echo "  caught    $name"
    caught=$((caught+1))
  else
    echo "  SURVIVED  $name  (RED but WRONG message; wanted: $want)"
    survived=$((survived+1))
  fi
}

echo "== mutants that must be CAUGHT =="

# M1 the gate id stops matching -- the lever can never arm.
run_case "M1 gate id typo" "the 'fightfloor' gate is gone" \
  "sed -i \"s/IsSoakCandidate( 'fightfloor' )/IsSoakCandidate( 'fightflor' )/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- the fix would ship live in normal games.
run_case "M2 turbo scope dropped" "the turbo scope disappeared" \
  "perl -0pi -e 's/\tif not J\.IsModeTurbo\(\) then return tAllies end\n//' \
     bots/FunLib/jmz_func.lua"

# M3 a disarmed path hands back a REBUILT copy instead of the caller's list.
#    Every existence check still passes and the counts are identical -- the only
#    thing that changes is identity, which is what "inert" has to mean here.
run_case "M3 disarmed path rebuilds the list" "expected both disarmed paths to return tAllies, found 1" \
  "perl -0pi -e 's/\tif not J\.IsModeTurbo\(\) then return tAllies end/\tif not J.IsModeTurbo() then return { unpack( tAllies ) } end/' \
     bots/FunLib/jmz_func.lua"

# M4 ⭐ THE LEVER ITSELF: armed, the floor stops excluding anybody. The helper
#    keeps its gate, its turbo scope, both disarmed returns and the named
#    constant -- every source pin above stays green -- so ONLY the real frame
#    can speak, and this is the one mutant the whole file exists to catch.
run_case "M4 armed floor excludes nobody" "armed, the 12.7%-HP subject must drop out of the fighter count; it read 2" \
  "sed -i 's/if J.GetHP( hAlly ) >= J.COMMIT_PARITY_HP_FLOOR then/if J.GetHP( hAlly ) >= J.COMMIT_PARITY_HP_FLOOR - 1 then/' \
     bots/FunLib/jmz_func.lua"

# M5 the numbers branch quietly stops routing through the helper.
run_case "M5 call site reverts the numbers branch" "consumer inside J.SafeToCommitFight, found 0" \
  "sed -i 's/if #J.GetCommitParityFighters( tAllies ) >= #J.GetEnemiesNearLoc( vLoc, 1200 ) then/if #tAllies >= #J.GetEnemiesNearLoc( vLoc, 1200 ) then/' \
     bots/FunLib/jmz_func.lua"

# M6 the filter leaks into branch (a): a secured burst kill would stop being a
#    go just because one of the allies who lands it is low. The direction claim
#    ("armed only removes commits, and only from the NUMBERS branch") dies here.
#    ⛔ The message asserted is the CONSUMER COUNT, not the "LETHAL branch no
#    longer scores the unfiltered ally list" line six lines below it: both live
#    in the same case, the count assertion runs first, and the branch-(a) line
#    never executes. Asserting a line that cannot fire is how a stand scores a
#    mutant it did not observe. `found 2` vs M5's `found 0` is what keeps the
#    two apart -- one consumer too many is a leak, one too few is a revert.
run_case "M6 filter leaks into the LETHAL branch" "consumer inside J.SafeToCommitFight, found 2" \
  "sed -i 's/local nBurst = J.GetTotalEstimatedDamageToTarget( tAllies, target )/local nBurst = J.GetTotalEstimatedDamageToTarget( J.GetCommitParityFighters( tAllies ), target )/' \
     bots/FunLib/jmz_func.lua"

# M7 the two halves drift apart again: the dive guard un-names the floor.
run_case "M7 dive guard un-names the floor" "the dive guard stopped reading the named floor" \
  "sed -i 's/local bSelfCritical = J.GetHP( bot ) < J.COMMIT_PARITY_HP_FLOOR/local bSelfCritical = J.GetHP( bot ) < 0.35/' \
     bots/FunLib/jmz_func.lua"

# M8 the TEST's own witnesses stop being load-bearing: point both at the healthy
#    control and there is no sub-floor ally left anywhere to flip on.
run_case "M8 test loses its sub-floor witness" "the witnesses no longer cover sub-floor counts 1 / 0" \
  "perl -0pi -e \"s/local W_FLIP   = \\{ 'tests\\/fixtures\\/f_080225_wk_lane.lua',\\n                   'npc_dota_hero_skeleton_king', 'dire',\\n                   'npc_dota_hero_juggernaut' \\}/local W_FLIP   = { 'tests\\/fixtures\\/f_011405_jak_rescue_axe.lua',\\n                   'npc_dota_hero_axe', 'radiant',\\n                   'npc_dota_hero_pudge' }/\" $T"

echo
echo "== the CONTROL: unmutated tree must stay green =="
restore
if lua5.1 tests/run_tests.lua "$(basename "$T")" >/dev/null 2>&1; then
  echo "  control   SURVIVED as required (green on a clean tree)"
else
  echo "  !! CONTROL IS RED on a clean tree -- the stand is broken, not the code"
  survived=$((survived+1))
fi

echo
verify_restore || survived=$((survived+1))

echo
echo "caught=$caught survived=$survived"
[ "$survived" -eq 0 ] || exit 1
