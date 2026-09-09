#!/usr/bin/env bash
# Mutation stand for tests/test_blind_a_pulllane_pullthink.lua.
#
# The file it defends records a BLINDNESS, so -- as in the cmrguard and
# roamidle/campsel stands -- EVERY MUTANT BELOW RUNS IN THE SAME DIRECTION:
# each one either LIFTS the blindness (the instrument gains the reading) or
# DISSOLVES A REASON for it (the lever, the gate, the constant or the
# declaration moves).  A test that stays green through those is a test that
# would let a retired id silently become re-proposable, or that would outlive
# its own subject.
#
# 'pulllane's blindness: its clause J.IsCampBesideLane sits inside a loop that
# is only reached after GetLaneFrontLocation, which the loader REFUSES by name
# (GH #61).  Exactly 9 of 1100 corpus hero-handles survive the helper's domain
# filters, and the instrument declines on all 9.
# 'pullthink's blindness: both operands are dead -- the scope operand needs the
# same lane front, and the throttle operand reads bot:GetAnimActivity(), which
# falls to bot_api.lua's `^Get -> 0` catch-all on 1100/1100 handles.
#
# ⭐ The stand also defends a claim ABOUT A COMMENT: mode_roam_generic.lua says
# meaningfulActivities is an EMPTY table, and it measurably is not.  M7 repairs
# that comment, which must go red -- the assertion is written to expire with
# its subject rather than to quietly outlive it.
#
# RESTORE IS FROM FILE COPIES TAKEN OUTSIDE THE TREE and is verified with
# `git diff --quiet` rather than a checksum of the stand's own backups: a hash
# round-trip only proves a backup is self-consistent, and stays green when the
# backup was taken from an ALREADY MUTATED file.  `git diff` compares against
# the index, so it catches that case too and can only err noisily.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

BOTAPI='tests/mock/bot_api.lua'
LOADER='tests/mock/replay_fixture.lua'
JMZ='bots/FunLib/jmz_func.lua'
ROAM='bots/mode_roam_generic.lua'
ATOMS='iterations/promote_atoms.json'

FILES=("$BOTAPI" "$LOADER" "$JMZ" "$ROAM" "$ATOMS")

BAKDIR="$(mktemp -d)"
for f in "${FILES[@]}"; do
    cp "$f" "$BAKDIR/$(echo "$f" | tr '/' '_')" || exit 2
done

restore() {
    for f in "${FILES[@]}"; do
        cp "$BAKDIR/$(echo "$f" | tr '/' '_')" "$f" || exit 2
    done
    if ! git diff --quiet -- "${FILES[@]}"; then
        echo "RESTORE FAILED -- the tree still differs from the index. STOP."
        git diff --stat -- "${FILES[@]}"
        exit 2
    fi
}
trap restore EXIT

TEST='test_blind_a_pulllane_pullthink'

CAUGHT=0
SURVIVED=0

# Run the defended test; echo CAUGHT if it goes red (the mutant was detected).
run_mutant() {
    local label="$1"
    local out rc
    out="$(lua5.1 tests/run_tests.lua "$TEST" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        CAUGHT=$((CAUGHT + 1))
        echo "  CAUGHT    $label"
    else
        SURVIVED=$((SURVIVED + 1))
        echo "  SURVIVED  $label   <-- the test does not defend this"
        echo "$out" | tail -3 | sed 's/^/            /'
    fi
    restore
}

echo "=== control: unmutated tree must be GREEN ==="
control_out="$(lua5.1 tests/run_tests.lua "$TEST" 2>&1)"; control_rc=$?
if [ "$control_rc" -ne 0 ]; then
    echo "CONTROL FAILED (exit $control_rc) -- the stand proves nothing. STOP."
    echo "$control_out" | tail -20
    exit 2
fi
echo "  control_ok=1  ($(echo "$control_out" | tail -1))"
echo

echo "=== mutants: each LIFTS the blindness or dissolves a reason for it ==="

# --- the instrument gains the reading ---------------------------------------

# M1  The catch-all stops answering 0 -- GetAnimActivity could now match an
#     ACTIVITY_* sentinel and 'pullthink's throttle operand becomes readable.
sed -i "s|if key:find('\^Get') then return 0 end|if key:find('^Get') then return 1154 end|" "$BOTAPI"
run_mutant "M1  bot_api ^Get catch-all answers 1154 instead of 0"

# M2  The loader serves the getter directly -- the never-generalised fix,
#     generalised (the §GF.2 gap closed).
perl -0pi -e "s/(    _G\.GetLaneFrontLocation = function\(\))/    rawget(bot, '__spec').GetAnimActivity = 1154\n\n\$1/" "$LOADER"
run_mutant "M2  loader serves GetAnimActivity (the cheap purchase, made)"

# M3  The loader stops REFUSING the lane front and answers the pre-#61 stub --
#     the 9 candidate frames become answerable.
perl -0pi -e "s/    _G\.GetLaneFrontLocation = function\(\)\n        error\(/    _G.GetLaneFrontLocation = function() return M_Vector_stub() end\n    local _unused = function()\n        error(/" "$LOADER"
run_mutant "M3  loader answers GetLaneFrontLocation instead of refusing"

# M4  The refusal survives but stops naming itself -- the witness [1d] reads is
#     lost, and a future round cannot tell a refusal from a crash.
perl -0pi -e 's/LOADER REFUSES: GetLaneFrontLocation is unresolved \(GH #61\)\. /lane front unavailable. /' "$LOADER"
run_mutant "M4  loader refusal stops naming 'LOADER REFUSES' and GH #61"

# M5  The lane path stops being one constant point -- 'pulllane's clause would
#     be measuring against a real path.
sed -i "s|G.GetLocationAlongLane = function() return M.Vector(0, 0, 0) end|G.GetLocationAlongLane = function(_, f) return M.Vector((f or 0) * 1000, 0, 0) end|" "$BOTAPI"
run_mutant "M5  GetLocationAlongLane varies with the fraction"

# M6  The camp roster fills -- the wall §GF explicitly REFUTED as the binding
#     one, mutated anyway so [1a]'s reading cannot rot unnoticed.
sed -i "s|G.GetNeutralSpawners = function() return {} end|G.GetNeutralSpawners = function() return { { team = 2, location = M.Vector(0, 0, 0) } } end|" "$BOTAPI"
run_mutant "M6  GetNeutralSpawners serves a camp"

# M7  The stale comment is repaired.  [2c] MUST go red: its whole point is that
#     the claim is still in the source, so the assertion expires with it.
perl -0pi -e 's/builds meaningfulActivities as an EMPTY table/builds meaningfulActivities from ALL_CAPS sentinels/' "$ROAM"
run_mutant "M7  the stale 'EMPTY table' comment is repaired"

# M8  The helper's domain widens -- the 9-frame candidate count moves, and with
#     it the size of the purchase §GF quotes.
perl -0pi -e 's/if nNow < 60 or nNow > 6 \* 60 then return nil end/if nNow < 60 or nNow > 12 * 60 then return nil end/' "$JMZ"
run_mutant "M8  pull window widened 6min -> 12min (candidate count moves)"

# --- a reason for the blindness dissolves -----------------------------------

# M9  'pulllane's gate is deleted -- a retirement silently became a reject.
perl -0pi -e "s/J\.IsSoakCandidate\( 'pulllane' \)/false/" "$JMZ"
run_mutant "M9  pulllane gate removed from bots/ (retirement turned into a reject)"

# M10 THE SPACING TRAP, pinned.  The gate is written WITH spaces; a grep for
#     the spaceless form reads back "no call site" and would retire a LIVE
#     lever as dead.  The 2026-09-09 round walked into exactly this.
perl -0pi -e "s/J\.IsSoakCandidate\( 'pulllane' \)/J.IsSoakCandidate('pulllane')/" "$JMZ"
run_mutant "M10 pulllane gate respelled without spaces (the grep trap)"

# M11 The lever's constant moves -- §GF retires the id, not the constant.
perl -0pi -e 's/local PULL_CAMP_LANE_GAP = 1200/local PULL_CAMP_LANE_GAP = 992/' "$JMZ"
run_mutant "M11 PULL_CAMP_LANE_GAP retuned 1200 -> 992"

# M12 'pullthink' is conjoined with a promoted id -- the pullcad trap, live.
perl -0pi -e "s/bot\.roamCampPull ~= nil and J\.IsSoakCandidate\('pullthink'\)/bot.roamCampPull ~= nil and J.IsSoakCandidate('pullthink') and J.IsSoakCandidate('pullbeat')/" "$ROAM"
run_mutant "M12 pullthink conjoined with the promoted 'pullbeat' (pullcad trap)"

# M13 A promote atom names a retired id -- retiring it could freeze another.
perl -0pi -e 's/^\{/\{\n  "_mut": { "kind": "no_promote_without", "subject": ["pulllane"] },/' "$ATOMS"
run_mutant "M13 promote_atoms.json names pulllane"

echo
echo "MUTSTAND  $CAUGHT CAUGHT / $SURVIVED SURVIVED / control_ok=1"
[ "$SURVIVED" -eq 0 ] || exit 3
