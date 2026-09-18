#!/usr/bin/env bash
# Mutation stand for tests/test_claimlone_roam_lone_ally.lua.
#
# ⛔ WHY: that test was green on its second run and a gate test that has never
# been shown to go red for the RIGHT reason is indistinguishable from one that
# asserts nothing.
#
# ⛔ SCORING: a mutant that dies with the WRONG message counts as SURVIVED.
# Matching the wrong assertion is how a test keeps its green for a reason that
# has nothing to do with the defect.
#
# Restores from a byte copy, never from git checkout: the tree may carry
# uncommitted work and a checkout would eat it (evidence-discipline 1).
set -u

T=tests/test_claimlone_roam_lone_ally.lua
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
  fi
}

echo "== mutants that must be CAUGHT =="

# M1 the gate id stops matching -- the lever can never arm.
run_case "M1 gate id typo" "the 'claimlone' gate is gone" \
  "sed -i \"s/IsSoakCandidate( 'claimlone' )/IsSoakCandidate( 'claimlon' )/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- the veto would widen in normal games too.
run_case "M2 turbo scope dropped" "the turbo scope disappeared" \
  "sed -i \"s/not ( J.IsModeTurbo() and J.IsSoakCandidate( 'claimlone' ) )/not ( J.IsSoakCandidate( 'claimlone' ) )/\" \
     bots/FunLib/jmz_func.lua"

# M3 ⭐ THE LEVER ITSELF, inverted: armed makes the guard fire instead of
#    suspending it.  Every source-shape assertion still passes -- only a real
#    frame can tell.
#    ⛔ THE FIRST `want` HERE WAS WRONG AND THE MUTANT SCORED SURVIVED FOR IT:
#    it expected "armed did not see the lone ally", but an inverted gate moves
#    the DISARMED leg first and the witness test asserts `shipped == false`
#    BEFORE `armed == true`, so that message is never reached.  What an inverted
#    gate actually means is that the un-armed tree changed -- which is what this
#    string says (evidence-discipline 2: when a mutant survives, suspect the
#    assertion).
run_case "M3 the gate inverted" "the unarmed side saw the lone ally" \
  "sed -i \"s/and not ( J.IsModeTurbo() and J.IsSoakCandidate( 'claimlone' ) )/and ( J.IsModeTurbo() and J.IsSoakCandidate( 'claimlone' ) )/\" \
     bots/FunLib/jmz_func.lua"

# M4 the shipped guard's threshold moves instead of being gated -- disarmed
#    games silently get the new answer, which is the one thing a soak candidate
#    may not do.
run_case "M4 threshold moved, not gated" "shipped already answers true" \
  "sed -i 's/if #hAllyList < 2/if #hAllyList < 1/' bots/FunLib/jmz_func.lua"

# M5 the dead self-test goes away.  It IS dead (self_in_list 0 / 1039), and
#    that is the point: deleting it erases the evidence that the belief was
#    held, and no frame would ever notice.
run_case "M5 the ally ~= bot term deleted" "the \`ally ~= bot\` term was deleted" \
  "perl -0pi -e 's/\t\tif ally ~= bot\n\t\t\tand not ally:IsIllusion\(\)/\t\tif not ally:IsIllusion()/' \
     bots/FunLib/jmz_func.lua"

# M6 the ring silently becomes the 800 one 'soloclaim' already repaired -- two
#    different functions would then be measured as one.
run_case "M6 the ring radius collapses onto soloclaim's" "the ally ring moved" \
  "sed -i 's/bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE)/bot:GetNearbyHeroes(800, false, BOT_MODE_NONE)/' \
     bots/FunLib/jmz_func.lua"

# M7 ⭐ the mode file stops routing through the repair.  The gate, the guard and
#    every assertion about them survive untouched while the lever is unreachable
#    from all five of X.IsAllysTarget's call sites.
run_case "M7 the mode file stops delegating" "stopped delegating" \
  "perl -0pi -e 's/\treturn J\.IsRoamAllysTarget\(unit\);/\treturn false;/' \
     bots/mode_team_roam_generic.lua"

# M8 the claim test is swapped for J.GetProperTarget -- a SECOND lever (a
#    different definition of "is holding this unit") riding this one.
run_case "M8 claim test swapped for GetProperTarget" "the claim test changed" \
  "sed -i 's/( ally:GetTarget() == unit or ally:GetAttackTarget() == unit )/( J.GetProperTarget( ally ) == unit )/' \
     bots/FunLib/jmz_func.lua"

# M9 the illusion clause is dropped.  ⛔ No frame in the corpus can see this:
#    the fixture loader drops illusions at dump time, so the discriminator is
#    structurally absent and the source is the only place it can be pinned.
run_case "M9 illusion clause dropped" "the illusion test vanished" \
  "sed -i 's/and not ally:IsIllusion()//' bots/FunLib/jmz_func.lua"

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
