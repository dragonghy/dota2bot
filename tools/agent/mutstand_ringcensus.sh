#!/usr/bin/env bash
# Mutation stand for tests/test_ring_subject_census.py.
#
# ⛔ WHY: that test passed on its FIRST run, on an unmodified tree. A census
# that is green before it has ever been shown to go red is indistinguishable
# from a census that asserts nothing -- and this repo has already paid for a
# census whose scanner had quietly stopped matching (`n_subject_fns` is the
# guard against that, and it is itself one of the mutants below).
#
# ⛔ SCORING: a mutant that dies with the WRONG message counts as SURVIVED.
# Matching the wrong assertion is how a test keeps its green for a reason that
# has nothing to do with the defect (0NEXT38 §丁).
#
# Restores from a byte copy, never from git checkout: the tree may carry
# uncommitted work and a checkout would eat it (evidence-discipline 1).
set -u

T=tests/test_ring_subject_census.py
declare -a FILES=(
  "$T"
  tests/mock/replay_fixture.lua
  bots/FunLib/jmz_func.lua
  tools/batch_test/soak/hero_pool.txt
)
TMP="$(mktemp -d)"
for f in "${FILES[@]}"; do cp "$f" "$TMP/$(echo "$f" | tr / _)"; done
restore() {
  for f in "${FILES[@]}"; do cp "$TMP/$(echo "$f" | tr / _)" "$f"; done
}

# ⛔ A stand that merely CALLS restore and reports success proves nothing --
# tests/test_mutstand_restore_trap.py makes a byte-level round-trip proof the
# contract, and this stand failed it on its first run. Hash the originals now,
# and re-hash at the end: if a single mutant's restore did not round-trip, the
# tree this round measured is not the tree it reports on.
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
  local out rc
  out="$(python3 "$T" 2>&1)"; rc=$?
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

# M1 a brand-new asker-anchored ring in a subject-taking function.
run_case "M1 new asker-anchored ring" "NEW asker-anchored ring" \
  "printf '%s\n' '' 'function J.MutantIsThingNearUnit( unit )' \
     '\tlocal t = J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)' \
     '\treturn #t > 0 and unit ~= nil' 'end' >> bots/FunLib/jmz_func.lua"

# M2 the anchor-relative contract every triage reason rests on.
run_case "M2 instrument turned bot-relative" "no longer derives bEnemy" \
  "sed -i 's/other:GetTeam() ~= self:GetTeam()/other:GetTeam() ~= GetTeam()/' \
     tests/mock/replay_fixture.lua"

# M3 the parked defect gets 'repaired' -- the row must stop being accurate.
run_case "M3 hTarget true ring removed" "hTarget-anchored" \
  "perl -0pi -e 's/GetNearbyHeroes\\(hTarget, 1600, true/GetNearbyHeroes(hTarget, 1600, false/' \
     bots/FunLib/jmz_func.lua"

# M4 ⭐ the external fact that unparks the lever.
run_case "M4 rubick enters the draft pool" "RUBICK IS NOW IN THE DRAFT POOL" \
  "printf 'rubick 2 4 5\n' >> tools/batch_test/soak/hero_pool.txt"

# M5 a triaged ring DISAPPEARS (repaired) without its row being retired.
#    ⛔ Not a rename: renaming trips the `new` assertion first, so it scores
#    RED-with-wrong-message and says nothing about the `gone` half.
run_case "M5 triaged ring repaired, row left behind" "disappeared" \
  "perl -0pi -e 's/unitList = J\\.GetNearbyHeroes\\(bot, nCastRange, bEnemy, BOT_MODE_NONE \\)/unitList = J.GetAlliesNearLoc( vLoc, nRadius )/' \
     bots/FunLib/jmz_func.lua"

# M6 the reductio anchor: the loop stops rejecting only hSource.
#    ⛔ TWO unfaithful versions were paid for here, both scoring as green
#    survivors because perl exits 0 on no-match: (a) \t\t\t matched nothing
#    (the body is TWO tabs), and (b) the 2-tab pattern matched the FIRST
#    `if enemyHero ~= hSource` in the FILE -- which lives in
#    J.IsEnemyBetweenMeAndLocation, a different function -- so the mutation
#    landed somewhere the assertion does not look. Anchor on the unique
#    hTarget ring, not on the shared loop head.
run_case "M6 hTarget exclusion appears" "hTarget exclusion appeared" \
  "perl -0pi -e 's/(GetNearbyHeroes\\(hTarget, 1600, true.*?\n\t\tif enemyHero ~= hSource)/\$1 and enemyHero ~= hTarget/s' \
     bots/FunLib/jmz_func.lua"

# M7 the scanner itself stops matching (the GH #624 shape: a census that has
#    quietly stopped measuring still reads green).
run_case "M7 scanner stops matching functions" "not measuring any more" \
  "sed -i \"s/^FUNC_RE = re.compile(r'function/FUNC_RE = re.compile(r'fnction/\" $T"

echo
echo "== the CONTROL: unmutated tree must stay green =="
restore
if python3 "$T" >/dev/null 2>&1; then
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
