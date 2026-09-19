#!/usr/bin/env bash
# Mutation stand for tests/test_bbalone_ancient_defenders.lua.
#
# ⛔ WHY: a gate test that has never been shown to go red for the RIGHT reason
# is indistinguishable from one that asserts nothing.
#
# ⛔ SCORING: a mutant that dies with the WRONG message counts as SURVIVED.
# Matching the wrong assertion is how a test keeps its green for a reason that
# has nothing to do with the defect.
#
# Restores from a byte copy, never from git checkout: the tree may carry
# uncommitted work and a checkout would eat it (evidence-discipline 1).
set -u

T=tests/test_bbalone_ancient_defenders.lua
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
  # ⛔ The mutation must be PROVED to have landed (GH #846).
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
    echo "$out" | grep -E 'FAIL|not ok|assert' | head -5
  fi
}

echo "== mutants that must be CAUGHT =="

# M1 the gate id stops matching -- the lever can never arm.
run_case "M1 gate id typo" "the 'bbalone' gate is gone" \
  "sed -i \"s/IsSoakCandidate( 'bbalone' )/IsSoakCandidate( 'bbalon' )/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- normal games would get the new answer too.
run_case "M2 turbo scope dropped" "armed but NOT in turbo" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'bbalone' )/if J.IsSoakCandidate( 'bbalone' )/\" \
     bots/FunLib/jmz_func.lua"

# M3 ⭐ THE GATE INVERTED: the DISARMED tree is the one that changed. Every
#    source assertion still passes. ⛔ The `want` names the DISARMED leg,
#    because that is the assertion an inverted gate reaches first
#    (evidence-discipline 2).
run_case "M3 the gate inverted" "the helper answers armed while the gate is OFF" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'bbalone' )/if J.IsModeTurbo() and not J.IsSoakCandidate( 'bbalone' )/\" \
     bots/FunLib/jmz_func.lua"

# M4 ungated by deletion -- the one thing a soak candidate may not be. Shipped
#    play changes in every game, turbo or not.
run_case "M4 ungated, shipped by default" "the 'bbalone' gate is gone" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'bbalone' )/if true/\" \
     bots/FunLib/jmz_func.lua"

# M5 ⭐ THE ARMED LEG BECOMES A NO-OP: it returns the shipped expression too, so
#    the id is WIRED (check_armed_wiring.py checks that a call site exists, not
#    that the predicate can move) and every wave reads back "tested, no effect"
#    with nothing raising a hand. This is the exact shape this whole work unit
#    exists to remove from 'bbancient'.
run_case "M5 the armed leg is the shipped expression" \
  "armed, the term STILL answers" \
  "perl -0pi -e 's/\t\treturn tAlliesNearAncient ~= nil and #tAlliesNearAncient == 0/\t\treturn tAlliesNearAncient == 0/' \
     bots/FunLib/jmz_func.lua"

# M6 ⭐ THE LEVER DIES IN THE OTHER DIRECTION: armed answers a constant false.
#    Source-wise everything is in place; only a real frame with nobody home
#    sees it.
run_case "M6 armed is constant false" "armed, the term STILL answers" \
  "perl -0pi -e 's/\t\treturn tAlliesNearAncient ~= nil and #tAlliesNearAncient == 0/\t\treturn false/' \
     bots/FunLib/jmz_func.lua"

# M7 the disarmed leg gets "fixed" in place instead of behind the gate -- the
#    shipped default moves, which is the one thing a soak candidate may not do.
run_case "M7 the shipped expression repaired in place" \
  "no longer carries the shipped expression" \
  "perl -0pi -e 's/\treturn tAlliesNearAncient == 0\n/\treturn tAlliesNearAncient ~= nil and #tAlliesNearAncient == 0\n/' \
     bots/FunLib/jmz_func.lua"

# M8 the call site stops delegating: the shipped table-vs-number comparison
#    comes back. The helper and every assertion about it survive untouched
#    while the lever is unreachable from the only site there is.
run_case "M8 the call site stops delegating" "is no longer J.IsAncientUndefended" \
  "sed -i 's/J.IsAncientUndefended( nAllyUnitsAroundAncient )/nAllyUnitsAroundAncient == 0/' \
     bots/ability_item_usage_generic.lua"

# M9 ⭐ THE HELPER BUILDS ITS OWN LIST instead of reading the one it was handed.
#    Behaviourally identical on every frame TODAY -- and that is the point:
#    "same list, same location, same ring as the call site" stops being true by
#    construction and becomes a thing to re-check on every edit. That is the
#    drift 'roamring'/'tormring' cost.
#    ⚠️ The mutant this slot USED to carry (the call site hands over `bot`) was
#    caught by the semantic nail rather than by the assertion written for it --
#    the positive pattern fails for every argument that is not the site's own
#    list, so that assertion was DOMINATED and asserted nothing. It was deleted
#    instead of being kept green, and this mutant replaces it on the half of the
#    claim that is not dominated.
run_case "M9 the helper builds its own list" "the helper builds its own list" \
  "perl -0pi -e 's/\t\treturn tAlliesNearAncient ~= nil and #tAlliesNearAncient == 0/\t\treturn #J.GetAlliesNearLoc( GetAncient( GetBot():GetTeam() ):GetLocation(), 1500 ) == 0/' \
     bots/FunLib/jmz_func.lua"

# M10 a SECOND lever rides along: the sibling enemy-weight threshold moves in
#     the same change. One lever at a time is the rule the lanefix bundle paid
#     for twice.
run_case "M10 the sibling term moves too" "the sibling enemy-weight term changed" \
  "sed -i 's/nEnemyUnitsAroundAncient > 1 and J.IsAncientUndefended/nEnemyUnitsAroundAncient >= 0 and J.IsAncientUndefended/' \
     bots/ability_item_usage_generic.lua"

# M11 ⭐ THE pullcad TRAP, built by hand: the helper names the OTHER id of this
#     branch as well. It reads like the co-arming dependency made into code,
#     and it freezes this gate FALSE the day either id is promoted -- while
#     check_armed_wiring.py still calls the lever WIRED.
run_case "M11 the gate becomes a conjunction of two ids" "a gate inside a gate" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'bbalone' )/if J.IsModeTurbo() and J.IsSoakCandidate( 'bbalone' ) and J.IsSoakCandidate( 'bbancient' )/\" \
     bots/FunLib/jmz_func.lua"

# M12 ⭐ THE DIRECTION REVERSED AT THE CALL SITE: the term is read negated, so
#     armed would REMOVE buybacks instead of adding them. Behaviourally
#     invisible on this corpus (the branch cannot fire here at all); the source
#     nail in §6 is what stands between it and a wrong direction claim in a
#     verdict.
run_case "M12 the term is read negated at the site" "the term is read negated now" \
  "sed -i 's/and J.IsAncientUndefended( nAllyUnitsAroundAncient )/and not J.IsAncientUndefended( nAllyUnitsAroundAncient )/' \
     bots/ability_item_usage_generic.lua"

# M13 ⭐ ARMED ANSWERS FOR THE LIST INSTEAD OF ASKING IT. Every assertion on the
#     claim frame still passes -- it is the separating control, where a living
#     teammate IS standing at the ancient, that dies. That control exists for
#     this mutant and no other.
run_case "M13 armed returns true without looking" \
  "armed, the term calls the base undefended while a living" \
  "perl -0pi -e 's/\t\treturn tAlliesNearAncient ~= nil and #tAlliesNearAncient == 0/\t\treturn true/' \
     bots/FunLib/jmz_func.lua"

# M14 the nil guard is dropped. A getter that came back nil would then be a
#     length-of-nil raise inside a buyback decision -- in a tree where the
#     engine's error text is unreadable (AGENTS.md), i.e. a silent stop.
#     ⛔ The want is the VM's own message: this mutant is caught by the nil leg
#     running, not by an assertion phrased in advance.
run_case "M14 the nil guard dropped" "attempt to get length" \
  "perl -0pi -e 's/\t\treturn tAlliesNearAncient ~= nil and #tAlliesNearAncient == 0/\t\treturn #tAlliesNearAncient == 0/' \
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
