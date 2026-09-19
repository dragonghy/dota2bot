#!/usr/bin/env bash
# Mutation stand for tests/test_smokescan_ally_scan_gate.lua.
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

T=tests/test_smokescan_ally_scan_gate.lua
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
    echo "$out" | grep -E '^\s*(FAIL|not ok|[0-9]+\))' | head -5
  fi
}

echo "== mutants that must be CAUGHT =="

# M1 the gate id stops matching -- the lever can never arm.
run_case "M1 gate id typo" "the 'smokescan' gate is gone" \
  "sed -i \"s/IsSoakCandidate( 'smokescan' )/IsSoakCandidate( 'smokescn' )/\" \
     bots/FunLib/jmz_func.lua"

# M2 the turbo scope disappears -- normal games would get the new answer too.
run_case "M2 turbo scope dropped" "the helper fires outside turbo" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'smokescan' )/if J.IsSoakCandidate( 'smokescan' )/\" \
     bots/FunLib/jmz_func.lua"

# M3 ⭐ THE GATE INVERTED: the DISARMED tree is the one that changed. Every
#    source assertion still passes -- the id, the turbo scope and both disarmed
#    terms are still there. ⛔ The `want` names the DISARMED leg, because that is
#    the assertion an inverted gate reaches first (evidence-discipline 2).
run_case "M3 the gate inverted" \
  "the helper answers armed while the gate is OFF" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'smokescan' )/if J.IsModeTurbo() and not J.IsSoakCandidate( 'smokescan' )/\" \
     bots/FunLib/jmz_func.lua"

# M4 ungated by deletion -- the one thing a soak candidate may not be. The
#    helper becomes an unconditional `return true`: shipped play changes in
#    every game, turbo or not.
run_case "M4 ungated, shipped by default" \
  "with no candidate armed the helper is not the shipped expression" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'smokescan' )/if true/\" \
     bots/FunLib/jmz_func.lua"

# M5 ⭐ THE ARMED LEG BECOMES A NO-OP: it returns the shipped expression too, so
#    the id is WIRED (check_armed_wiring.py would still call it wired -- it
#    checks that a call site exists, not that the predicate can move) and every
#    wave reads back "tested, no effect" with nothing raising a hand.
run_case "M5 the armed leg is the shipped expression" \
  "armed, the scan is STILL skipped on the frame this lever is claimed on" \
  "perl -0pi -e 's/(\\treturn )true(\n\\tend\n\n\\treturn \\(tEnemyHeroes)/\$1(tEnemyHeroes ~= nil and #tEnemyHeroes == 0) or (tEnemyTowers ~= nil and #tEnemyTowers == 0)\$2/' \
     bots/FunLib/jmz_func.lua"

# M6 ⭐ THE DIRECTION REVERSED: armed CLOSES the gate instead of opening it.
#    That is the one direction this lever may never take -- it would suppress
#    the only check there is on every frame and ADD smokes.
run_case "M6 armed closes the gate" \
  "armed closed a gate the shipped expression opened" \
  "perl -0pi -e 's/(\tthen\n\t\treturn )true(\n\tend\n\n\treturn \(tEnemyHeroes)/\$1false\$2/' \
     bots/FunLib/jmz_func.lua"

# M7 ⭐ THE DISARMED `or` BECOMES AN `and` -- i.e. somebody "fixed" the shipped
#    expression in place instead of behind the gate. Shipped play moves, and
#    only a ring with exactly ONE list empty can see it: §6b's two half-open
#    witnesses exist for this mutant and no other.
run_case "M7 the disarmed or becomes an and" \
  "closed a gate the shipped \`or\` opens" \
  "perl -0pi -e 's/(#tEnemyHeroes == 0\)\n\t\t)or( \(tEnemyTowers)/\$1and\$2/' \
     bots/FunLib/jmz_func.lua"

# M8 the disarmed leg drops the TOWER term. The source check in §1 sees it, but
#    so does a real frame -- the hero-half witness -- and the behavioural nail
#    is the one that matters.
run_case "M8 the disarmed tower term dropped" \
  "the disarmed leg no longer carries the shipped tower-list term" \
  "perl -0pi -e 's/\n\t\tor \(tEnemyTowers ~= nil and #tEnemyTowers == 0\)//' \
     bots/FunLib/jmz_func.lua"

# M9 the call site stops delegating: the shipped backwards OR comes back. The
#    helper and every assertion about it survive untouched while the lever is
#    unreachable from the only site there is.
run_case "M9 the call site stops delegating" \
  "no longer guarded by J.ShouldScanAlliesForSmokeBreaker" \
  "perl -0pi -e 's/\tif J\.ShouldScanAlliesForSmokeBreaker\( nInRangeEnemy, nInRangeTower \)\n/\tif (nInRangeEnemy ~= nil and #nInRangeEnemy == 0)\n\tor (nInRangeTower ~= nil and #nInRangeTower == 0)\n/' \
     bots/ability_item_usage_generic.lua"

# M10 ⭐ THE CALL SITE HANDS OVER THE WRONG SUBJECT'S LIST: the ALLY list in
#     place of the enemy-hero list. The helper is untouched and correct, the
#     gate is still delegated, and the lever now answers a question about
#     allies -- the defect being repaired, one step removed.
run_case "M10 the call site passes the ally list" \
  "no longer guarded by J.ShouldScanAlliesForSmokeBreaker" \
  "sed -i 's/J.ShouldScanAlliesForSmokeBreaker( nInRangeEnemy, nInRangeTower )/J.ShouldScanAlliesForSmokeBreaker( nInRangeAlly, nInRangeTower )/' \
     bots/ability_item_usage_generic.lua"

# M11 ⭐ THE FLAG IS ANSWERED INSTEAD OF SCANNED: the loop body is replaced by an
#     unconditional write, so arming stops meaning "run the census" and starts
#     meaning "assume it fails". Every flip assertion in §2/§3 still passes;
#     only the separating control -- same shape, same shell, CLEAN ally -- sees
#     it, which is exactly what that control is for.
run_case "M11 the scan answers true without looking" \
  "expected exactly one ally-scan write" \
  "perl -0pi -e 's/(\tif J\.ShouldScanAlliesForSmokeBreaker\( nInRangeEnemy, nInRangeTower \)\n\tthen\n)/\$1\t\tisThereEnemyNearby = true\n/' \
     bots/ability_item_usage_generic.lua"

# M12 ⭐ MONOTONICITY BROKEN: something writes `false` into the flag below its
#     seed. The whole closed-form direction proof -- "a superset of scans is a
#     subset of smokes" -- rests on the loop being the only writer and writing
#     only `true`. Behaviourally this mutant is invisible on every witness here;
#     the source nail in §1 is what stands between it and a wrong direction
#     claim in a verdict.
run_case "M12 the flag is written false below its seed" \
  "no longer monotone" \
  "perl -0pi -e 's/(\tif not isThereEnemyNearby\n)/\tif false then isThereEnemyNearby = false end\n\$1/' \
     bots/ability_item_usage_generic.lua"

# M13 a SECOND copy of the ring appears at the call site. Behaviourally inert
#     today -- and that is the point: it is how the caster's ring and the ally
#     scan's ring get to drift apart, which is what 'roamring'/'tormring' cost.
run_case "M13 a second, raw ring at the call site" \
  "expected the 1200 to appear exactly once" \
  "perl -0pi -e 's/(\tlocal nInRangeTower = bot:GetNearbyTowers\(nRadius, true\)\n)/\$1\tlocal nUnusedRing = bot:GetNearbyTowers\(1200, true\)\n/' \
     bots/ability_item_usage_generic.lua"

# M14 ⭐ THE pullcad TRAP, built by hand: the helper names the OTHER id of this
#     call site as well. It reads like a dependency made into code, and it
#     freezes FALSE the day either id is promoted -- while check_armed_wiring.py
#     still calls the lever WIRED.
run_case "M14 the gate becomes a conjunction of two ids" \
  "soak ids -- a gate inside a gate" \
  "sed -i \"s/if J.IsModeTurbo() and J.IsSoakCandidate( 'smokescan' )/if J.IsModeTurbo() and J.IsSoakCandidate( 'smokescan' ) and J.IsSoakCandidate( 'smokeself' )/\" \
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
