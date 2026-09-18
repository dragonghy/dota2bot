#!/usr/bin/env bash
# Mutation stand for tests/test_pipetower_backup_tower.lua.
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

T=tests/test_pipetower_backup_tower.lua
declare -a FILES=(
  "$T"
  bots/FunLib/jmz_func.lua
  bots/ability_item_usage_generic.lua
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
run_case "M1 gate id typo" "the 'pipetower' gate is gone" \
  "sed -i \"s/IsSoakCandidate( 'pipetower' )/IsSoakCandidate( 'pipetowr' )/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- the flag would flip in normal games too.
run_case "M2 turbo scope dropped" "armed outside turbo changed the tower term" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'pipetower' )/if J.IsSoakCandidate( 'pipetower' )/\" \
     bots/FunLib/jmz_func.lua"

# M3 ⭐ THE GATE INVERTED: the DISARMED tree is the one that changed.  Every
#    source-shape assertion in section 1 still passes -- both flags are still
#    there, exactly once each.  ⛔ The `want` is about the disarmed leg because
#    that is the assertion an inverted gate reaches first (evidence-discipline 2).
run_case "M3 the gate inverted" \
  "disarmed, the count is no longer the shipped enemy-flag read" \
  "sed -i \"s/and J.IsSoakCandidate( 'pipetower' )/and not J.IsSoakCandidate( 'pipetower' )/\" \
     bots/FunLib/jmz_func.lua"

# M4 the armed leg reads the SAME flag -- the lever is a no-op on every frame
#    while the gate, the id and the turbo scope all survive.
# ⛔ The `want` is the FIRST assertion the case reaches, not the verdict line:
#    with both legs on the enemy flag the armed tower term reads 1, and the
#    count is asserted before the pipe verdict is (evidence-discipline 2 --
#    the first draft wanted the verdict line and scored this SURVIVED).
run_case "M4 armed leg reads the enemy flag too" \
  "armed, the tower term must count towers that fight FOR us" \
  "sed -i 's/return #hBot:GetNearbyTowers( nRadius, false )/return #hBot:GetNearbyTowers( nRadius, true )/' \
     bots/FunLib/jmz_func.lua"

# M5 the call site stops delegating -- the helper and every assertion about it
#    survive untouched while the lever is unreachable from the only site there is.
run_case "M5 the call site stops delegating" "no longer routes its tower term" \
  "sed -i 's/J.GetBackupTowerCount( bot, 1200 )/#bot:GetNearbyTowers( 1200, true )/' \
     bots/ability_item_usage_generic.lua"

# M6 the consumer's threshold is edited.  ⛔ NOT this lever's business (one
#    lever: whose towers the term counts), so the test must pin the consumer's
#    exact text rather than let a threshold edit ride along.
run_case "M6 the consumer threshold moved" \
  "expected exactly one consumer of the backup-tower count" \
  "sed -i 's/#nNearbyAllyHeroes + nBackupTowerCount >= 2/#nNearbyAllyHeroes + nBackupTowerCount >= 1/' \
     bots/ability_item_usage_generic.lua"

# M7 the repair is made DEFAULT instead of gated -- disarmed turbo games
#    silently get the new answer, which is the one thing a soak candidate may
#    not do.
run_case "M7 ungated, shipped by default" \
  "disarmed, the count is no longer the shipped enemy-flag read" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'pipetower' )/if J.IsModeTurbo()/\" \
     bots/FunLib/jmz_func.lua"

# M8 the helper grows a radius of its OWN -- a clamp exactly like the one in
#    J.GetAttackableWeakestUnit.  Behaviourally a no-op here (the call site
#    passes 1200), and both flag reads survive untouched, so ONLY the literal
#    pin can see it -- and the day a second caller passes 600 the helper would
#    be answering about a ring nobody asked for.
run_case "M8 helper grows its own radius" "grew a radius of its own" \
  "perl -0pi -e 's/(function J\\.GetBackupTowerCount\\( hBot, nRadius \\)\\n)/\$1\n\tif nRadius > 1200 then nRadius = 1200 end\n/' \
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
