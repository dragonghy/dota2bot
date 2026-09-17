#!/usr/bin/env bash
# Mutation stand for tests/test_roamring_parity_ring.lua.
#
# ⛔ WHY: that test was green on its FIRST run. A gate test that has never been
# shown to go red is indistinguishable from one that asserts nothing, and this
# lever's whole claim is a two-value flip on one real frame -- exactly the shape
# a vacuous assertion imitates best.
#
# ⛔ SCORING: a mutant that dies with the WRONG message counts as SURVIVED.
# Matching the wrong assertion is how a test keeps its green for a reason that
# has nothing to do with the defect.
#
# Restores from a byte copy, never from git checkout: the tree may carry
# uncommitted work and a checkout would eat it (evidence-discipline 1).
set -u

T=tests/test_roamring_parity_ring.lua
declare -a FILES=(
  "$T"
  bots/FunLib/jmz_func.lua
  bots/mode_team_roam_generic.lua
)
TMP="$(mktemp -d)"
for f in "${FILES[@]}"; do cp "$f" "$TMP/$(echo "$f" | tr / _)"; done
restore() {
  for f in "${FILES[@]}"; do cp "$TMP/$(echo "$f" | tr / _)" "$f"; done
}

# ⛔ A stand that merely CALLS restore and reports success proves nothing --
# tests/test_mutstand_restore_trap.py makes a byte-level round-trip proof the
# contract. Hash the originals now and re-hash at the end: if one mutant's
# restore did not round-trip, the tree this round measured is not the tree it
# reports on.
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
run_case "M1 gate id typo" "the 'roamring' gate is gone" \
  "sed -i \"s/IsSoakCandidate( 'roamring' )/IsSoakCandidate( 'roamrng' )/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- the fix would ship live in normal games.
run_case "M2 turbo scope dropped" "the turbo scope disappeared" \
  "perl -0pi -e 's/\tif not J\.IsModeTurbo\(\) then return nEnemyRadius end\n//' \
     bots/FunLib/jmz_func.lua"

# M3 the helper answers with a literal of its own instead of what the caller
#    asked about: every existence check above still passes.
run_case "M3 helper grows its own literal" "expected both disarmed paths to return nEnemyRadius, found 1" \
  "perl -0pi -e 's/(function J\.GetRoamParityRadius.*?)return nEnemyRadius end\n\tif not J\.IsModeTurbo/\$1return 2000 end\n\tif not J.IsModeTurbo/s' \
     bots/FunLib/jmz_func.lua"

# M4 ⭐ THE LEVER ITSELF: armed, the helper keeps handing back the shipped ring.
#    This is the one mutant the whole file exists to catch -- the real frame
#    must stop flipping.
#    ⛔ The message asserted here is the COUNT assertion, not the "armed REFUSES"
#    one two lines below it: the count fires first and the predicate line never
#    runs. Asserting the line that cannot fire is how a stand scores a mutant it
#    did not actually observe.
run_case "M4 armed is a no-op" "the enemy half must see the hero in the 2000-2200 shell; it read 1" \
  "perl -0pi -e 's/\treturn nAllyRadius\nend/\treturn nEnemyRadius\nend/' \
     bots/FunLib/jmz_func.lua"

# M5 the call site quietly stops routing the enemy half through the helper.
run_case "M5 call site reverts the enemy half" "no longer routes through" \
  "sed -i 's/J.GetRoamParityRadius(nRoamParityAllyRing, 2000))/2000)/' \
     bots/mode_team_roam_generic.lua"

# M6 the two halves drift apart again: the ally half stops reading the name.
run_case "M6 ally half un-names its ring" "no longer reads the named ring" \
  "sed -i 's/GetAlliesNearLoc(bot:GetLocation(), nRoamParityAllyRing)/GetAlliesNearLoc(bot:GetLocation(), 2200)/' \
     bots/mode_team_roam_generic.lua"

# M7 a SECOND consumer of the parity pair appears -- the blast-radius claim
#    ("one read site") stops being true and nothing else would notice.
run_case "M7 second consumer appears" "found 2" \
  "perl -0pi -e 's/(    elseif #nearbyAllies >= #nearbyEnemies then\n)/\$1        if #nearbyAllies >= #nearbyEnemies then end\n/' \
     bots/mode_team_roam_generic.lua"

# M8 the TEST's own ring numbers stop being load-bearing: read both halves at
#    2000 and the witness frame has no shell left to flip on.
run_case "M8 test reads both halves at 2000" "the witnesses no longer cover shell sizes 1 / 0" \
  "sed -i 's/^local ALLY_RING, ENEMY_RING = 2200, 2000$/local ALLY_RING, ENEMY_RING = 2000, 2000/' $T"

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
