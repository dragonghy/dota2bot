#!/usr/bin/env bash
# Mutation stand for tests/test_helpnear_closest_ally.lua.
#
# ⛔ WHY: that test was green on its second run and its first failure was in the
# stand-in grep, not in a claim about the code. A gate test that has never been
# shown to go red for the RIGHT reason is indistinguishable from one that
# asserts nothing.
#
# ⛔ SCORING: a mutant that dies with the WRONG message counts as SURVIVED.
# Matching the wrong assertion is how a test keeps its green for a reason that
# has nothing to do with the defect.
#
# Restores from a byte copy, never from git checkout: the tree may carry
# uncommitted work and a checkout would eat it (evidence-discipline 1).
set -u

T=tests/test_helpnear_closest_ally.lua
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
run_case "M1 gate id typo" "the 'helpnear' gate is gone" \
  "sed -i \"s/IsSoakCandidate('helpnear')/IsSoakCandidate('helpnar')/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- the pick would change in normal games.
run_case "M2 turbo scope dropped" "the turbo scope disappeared" \
  "sed -i \"s/local bNearest = J.IsModeTurbo() and J.IsSoakCandidate('helpnear')/local bNearest = J.IsSoakCandidate('helpnear')/\" \
     bots/FunLib/jmz_func.lua"

# M3 ⭐ THE LEVER ITSELF, inverted: armed keeps the FARTHEST eligible ally.
#    Every source-shape assertion still passes -- only a real frame can tell.
run_case "M3 armed keeps the farthest" "armed, the picker must answer" \
  "sed -i 's/if nNearestDist == nil or nDist < nNearestDist/if nNearestDist == nil or nDist > nNearestDist/' \
     bots/FunLib/jmz_func.lua"

# M4 the gate stops being a gate: armed unconditionally. Disarmed games would
#    silently get the new pick, which is the one thing a soak candidate may not
#    do.
run_case "M4 always armed" "disarmed, the pick moved" \
  "sed -i \"s/local bNearest = J.IsModeTurbo() and J.IsSoakCandidate('helpnear')/local bNearest = true/\" \
     bots/FunLib/jmz_func.lua"

# M5 the disarmed early return goes away -- disarmed becomes a second pass over
#    a computed answer, i.e. the shipped cost and the shipped pick both move.
run_case "M5 disarmed early return removed" "the disarmed early return is gone" \
  "perl -0pi -e 's/\t\t\tif not bNearest then return member end\n//' \
     bots/FunLib/jmz_func.lua"

# M6 an eligibility clause is dropped -- the armed answer is now drawn from a
#    different set than the shipped loop's.
run_case "M6 illusion clause dropped" "eligibility clause vanished" \
  "perl -0pi -e 's/\t\tand not J\.IsSuspiciousIllusion\(member\)\n\t\tthen\n\t\t\t-- Disarmed/\t\tthen\n\t\t\t-- Disarmed/' \
     bots/FunLib/jmz_func.lua"

# M7 the anchor stops being the pick: the call site falls back to a SECOND
#    picker, so ConsiderHelpAlly can anchor on a hero this lever never chose.
#    ⛔ This mutant SURVIVED the first stand: the assertion was a substring
#    match and the mutated line still contained the expected text. The
#    assertion now pins the whole statement (evidence-discipline 2 -- when a
#    mutant survives, suspect the assertion, not the mutant).
run_case "M7 call site falls back to a second picker" "and nothing else" \
  "sed -i 's/local nClosestAlly = J.GetClosestAlly(bot, nRadius)\$/local nClosestAlly = J.GetClosestAlly(bot, nRadius) or J.GetClosestCore(bot, nRadius)/' \
     bots/mode_team_roam_generic.lua"

# M8 the armed answer becomes nil when the loop found somebody -- the caller's
#    `nClosestAlly ~= nil` guard would read a different question armed.
run_case "M8 armed answers nil" "armed, the picker must answer" \
  "perl -0pi -e 's/\treturn hNearest\n/\treturn nil\n/' bots/FunLib/jmz_func.lua"

# M9 the TEST's own control collapses into the witness, so "unchanged where the
#    pick was already nearest" stops being a second reading.
run_case "M9 the control becomes a witness" "lost either its differing frames or its control" \
  "sed -i \"s/'npc_dota_hero_chaos_knight', 'npc_dota_hero_chaos_knight' }/'npc_dota_hero_chaos_knight', 'npc_dota_hero_skywrath_mage' }/\" $T"

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
