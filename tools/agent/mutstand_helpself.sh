#!/usr/bin/env bash
# Mutation stand for tests/test_helpself_parity_self.lua.
#
# ⛔ WHY: that test was green on its FIRST run. A gate test that has never been
# shown to go red is indistinguishable from one that asserts nothing, and this
# lever's whole claim is a one-unit change in one count on one real frame --
# exactly the shape a vacuous assertion imitates best.
#
# ⛔ SCORING: a mutant that dies with the WRONG message counts as SURVIVED.
# Matching the wrong assertion is how a test keeps its green for a reason that
# has nothing to do with the defect.
#
# Restores from a byte copy, never from git checkout: the tree may carry
# uncommitted work and a checkout would eat it (evidence-discipline 1).
set -u

T=tests/test_helpself_parity_self.lua
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
run_case "M1 gate id typo" "the 'helpself' gate is gone" \
  "sed -i \"s/IsSoakCandidate( 'helpself' )/IsSoakCandidate( 'helpslf' )/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- the fix would ship live in normal games.
run_case "M2 turbo scope dropped" "the turbo scope disappeared" \
  "perl -0pi -e 's/\tif not J\.IsModeTurbo\(\) then return nCount \+ 1 end\n//' \
     bots/FunLib/jmz_func.lua"

# M3 one of the two refusals stops handing back the shipped count: the helper
#    still exists, still names the gate, and silently changes shipped games.
run_case "M3 a refusal loses its + 1" "found 2" \
  "sed -i \"s/if not J.IsSoakCandidate( 'helpself' ) then return nCount + 1 end/if not J.IsSoakCandidate( 'helpself' ) then return nCount end/\" \
     bots/FunLib/jmz_func.lua"

# M4 ⭐ THE LEVER ITSELF: armed, the membership scan can never match, so the
#    asker keeps being counted twice. Every source-shape assertion still passes
#    -- only the real frame can tell.
#    ⛔ The message asserted here is whichever assertion FIRES; it was read off
#    a real run of this mutant, not predicted (evidence-discipline 4).
run_case "M4 armed scan can never match" "armed, the asker must be counted once, not twice" \
  "perl -0pi -e 's/\tfor _, hAlly in pairs\( tAllies \)/\tfor _, hAlly in pairs( {} )/' \
     bots/FunLib/jmz_func.lua"

# M5 the PROMOTED 'fight' path quietly stops routing through the helper.
run_case "M5 EvalTeamfightIdle reverts" "no longer routes through the helper" \
  "sed -i 's/J.GetHelpParityAllyCount( bot, nAllyNear ) >= #nEnemyNear/( #nAllyNear + 1 ) >= #nEnemyNear/' \
     bots/FunLib/jmz_func.lua"

# M6 ONE of the two mode_team_roam twins reverts -- the 0NEXT42 failure mode
#    (fixing the site the defect was found at and leaving its twin) reappears.
run_case "M6 one roam twin reverts" "found 1" \
  "perl -0pi -e 's/J\.GetHelpParityAllyCount\(bot, nInRangeAlly\)/#nInRangeAlly + 1/' \
     bots/mode_team_roam_generic.lua"

# M7 the repair becomes arithmetic instead of membership: subtract one always.
#    Correct on the witness, WRONG on every frame the asker is not in the list
#    -- which is what the control frame is for.
run_case "M7 arithmetic instead of membership" "the repair is not arithmetic" \
  "sed -i 's/\tlocal nCount = #tAllies\$/\tlocal nCount = #tAllies - 1/' \
     bots/FunLib/jmz_func.lua"

# M8 the TEST's own two witnesses collapse into one population, so "unchanged
#    on the control" and "flipped on the witness" stop being two readings.
run_case "M8 both witnesses become the flip frame" "the witnesses no longer cover both sides" \
  "perl -0pi -e \"s/local W_OUT   = \\{ 'tests\\/fixtures\\/f_080225_wk_lane.lua',\\n                  'npc_dota_hero_vengeful_spirit', 'dire' \\}/local W_OUT   = { 'tests\\/fixtures\\/f_260820_162821_lion_drain_lethal.lua',\\n                  'npc_dota_hero_necrolyte', 'dire' }/\" $T"

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
