#!/usr/bin/env bash
# Mutation stand for tests/test_towerpow_enemy_tower_power.lua.
#
# ⛔ WHY: that test was green on its first clean run, and a gate test that has
# never been shown to go red for the RIGHT reason is indistinguishable from one
# that asserts nothing.
#
# ⛔ SCORING: a mutant that dies with the WRONG message counts as SURVIVED.
# Matching the wrong assertion is how a test keeps its green for a reason that
# has nothing to do with the defect.
#
# Restores from a byte copy, never from git checkout: the tree may carry
# uncommitted work and a checkout would eat it (evidence-discipline 1; the
# strategy round of 2026-09-18T10:16Z lost uncommitted work to exactly that).
set -u

T=tests/test_towerpow_enemy_tower_power.lua
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
# contract.
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
  # never applied still scores).
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
    echo "$out" | grep -E '^\s*(FAIL|not ok|[0-9]+\))' | head -5
  fi
}

echo "== mutants that must be CAUGHT =="

# M1 the gate id stops matching -- the lever can never arm.
run_case "M1 gate id typo" "the 'towerpow' gate is gone" \
  "sed -i \"s/IsSoakCandidate( 'towerpow' )/IsSoakCandidate( 'towerpw' )/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- the enemy column would gain a term in normal
#    games too.
run_case "M2 turbo scope dropped" "armed outside turbo added the enemy-tower term" \
  "sed -i \"/function J.GetFightPowerEnemyTowers/,/^end$/ s/^\tif not J.IsModeTurbo() then return {} end$//\" \
     bots/FunLib/jmz_func.lua"

# M3 ⭐ THE GATE INVERTED: the DISARMED tree is the one that changed.  Every
#    source-shape assertion in §1 still passes -- the id, the turbo scope and
#    the single `true` read are all still there.  ⛔ The `want` is about the
#    disarmed leg because that is the assertion an inverted gate reaches first
#    (evidence-discipline 2).
run_case "M3 the gate inverted" \
  "disarmed the helper must hand back nothing" \
  "sed -i \"s/if not J.IsSoakCandidate( 'towerpow' ) then return {} end/if J.IsSoakCandidate( 'towerpow' ) then return {} end/\" \
     bots/FunLib/jmz_func.lua"

# M4 ⭐ THE FLAG INVERTED -- the mirror of the defect being repaired: OUR towers
#    handed to the ENEMY column.  The gate, the id, the turbo scope and the call
#    site all survive; only a frame that has an own tower and no enemy tower can
#    see it, which is why W_OWN (dragon_knight, 221u) is in the file.
run_case "M4 the helper reads the own-team flag" \
  "the enemy column may only receive towers that shoot at us" \
  "sed -i 's/return hBot:GetNearbyTowers( nRadius, true ) or {}/return hBot:GetNearbyTowers( nRadius, false ) or {}/' \
     bots/FunLib/jmz_func.lua"

# M5 the call site stops delegating -- the helper and every assertion about it
#    survive untouched while the lever is unreachable from the only site there is.
run_case "M5 the call site stops delegating" \
  "no longer routes its enemy-tower term through the helper" \
  "sed -i 's/J.GetFightPowerEnemyTowers( bot, nFightTowerRing )/bot:GetNearbyTowers( nFightTowerRing, true )/' \
     bots/FunLib/jmz_func.lua"

# M6 ⭐ THE TERM LANDS IN THE WRONG COLUMN -- the defect with an extra step.
#    The helper is untouched and answers correctly; the sum puts their tower's
#    firepower on OUR side, which is exactly what 'pipetower' repaired one file
#    over.
run_case "M6 the enemy tower power added to OUR column" \
  "expected exactly one \`enemyPower = enemyPower + nTowerPower\`" \
  "sed -i 's/^\t\tenemyPower = enemyPower + nTowerPower$/\t\tourPowerRaw = ourPowerRaw + nTowerPower/' \
     bots/FunLib/jmz_func.lua"

# M7 the two halves drift apart again: the ally half goes back to a literal, so
#    the named ring stops being the thing both halves read.  Behaviourally a
#    no-op TODAY (the literal equals the name), which is precisely why only the
#    source pin can see it -- and it is the shape 'roamring'/'tormring' cost.
run_case "M7 the ally half goes back to a literal ring" \
  "expected exactly one own-tower read through the named ring" \
  "sed -i 's/bot:GetNearbyTowers(nFightTowerRing, false)/bot:GetNearbyTowers(600, false)/' \
     bots/FunLib/jmz_func.lua"

# M8 the repair is made DEFAULT instead of gated -- disarmed turbo games
#    silently get the new answer, which is the one thing a soak candidate may
#    not do.
run_case "M8 ungated, shipped by default" \
  "disarmed the helper must hand back nothing" \
  "sed -i \"/function J.GetFightPowerEnemyTowers/,/^end$/ s/^\tif not J.IsSoakCandidate( 'towerpow' ) then return {} end$//\" \
     bots/FunLib/jmz_func.lua"

# M9 the shipped ALLY term is deleted instead of the enemy term being added --
#    a "unification" that also unifies at the wrong end: it makes the two
#    columns symmetric by removing information the bot has, and every gate
#    assertion survives it.
run_case "M9 the shipped ally-tower term deleted" \
  "the shipped ally-tower term is gone" \
  "sed -i 's/^\t\t\tourPowerRaw = ourPowerRaw + power$//' bots/FunLib/jmz_func.lua"

# M10 a SECOND ring appears next to the named one -- the named read survives, so
#     M7's counter cannot see it.  Behaviourally inert today, and that is the
#     point: it is how a second copy of the number gets in, and the next edit to
#     one of them is the drift.  ⛔ This is the mutant that drives the raw-literal
#     pin; M7 drives the counter.  (0NEXT47: a mutant that lets an EARLIER
#     assertion answer is not testing the nail you meant.)
run_case "M10 a second, raw ring next to the named one" \
  "a raw 600 tower read is back in J.WeAreStronger" \
  "perl -0pi -e 's/(\tlocal nFightTowerRing = 600\n)/\$1\tlocal nUnusedRing = bot:GetNearbyTowers(600, true)\n/' \
     bots/FunLib/jmz_func.lua"

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
