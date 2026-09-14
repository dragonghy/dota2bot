#!/usr/bin/env bash
# Mutation stand for sections 5b / 5b2 of tests/test_wk_qdmg_domain.lua
# (hero 2026-09-14, the `wkt10ls` t10 price and its coupling to `wkqdmg`).
# Each mutant breaks ONE thing those two sections claim; a mutant that
# SURVIVES is an assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1,
# and the gap tools/agent/py_gate.py caught on this desk's previous stand): a
# stand that only `cp`s has no way to notice it put back the wrong bytes.
#
# ⛔ ONE MUTANT THAT IS NOT HERE, and why -- do not add it:
#   * flipping the SHIPPED t10 row in hero_skeleton_king.lua to {0, 10}.
#     That is not a mutation of an assertion, it is the change itself; it
#     reds sections 4, 5 and 5b at once and tells you nothing about which
#     assertion carries the claim.
#
# Usage: bash tools/agent/mutstand_wkt10ls.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_wk_qdmg_domain.lua
WK=bots/BotLib/hero_skeleton_king.lua
ABA=bots/FunLib/aba_skill.lua
SLOTS=tests/mock/talent_slots.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$WK" "$ABA" "$SLOTS"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$WK" "$ABA" "$SLOTS"; do
		pristine="$TMP/$(echo "$f" | tr / _)"
		cp "$pristine" "$f"
		if [ "$(sha256sum < "$pristine")" != "$(sha256sum < "$f")" ]; then
			echo "ABORT: restore of $f did not reproduce the pristine bytes." >&2
			echo "       The working tree is NOT clean -- recover $f from git." >&2
			exit 2
		fi
	done
}
trap 'restore; rm -rf "$TMP"' EXIT

pass=0
fail=0

# run <name> <want-substring>  -- expects the suite to go RED and to say <want>
run() {
	local name="$1" want="$2" out
	out=$(lua5.1 tests/run_tests.lua wk_qdmg_domain 2>&1)
	if echo "$out" | grep -q "0 failures"; then
		echo "SURVIVED  $name  -- the suite stayed green"
		fail=$((fail + 1))
	elif echo "$out" | grep -qF "$want"; then
		echo "killed    $name"
		pass=$((pass + 1))
	else
		echo "WRONG MESSAGE  $name  -- red, but not on the assertion aimed at"
		echo "$out" | grep -A2 'FAIL' | head -8
		fail=$((fail + 1))
	fi
	restore
}

# M1  The gate id is renamed, i.e. the counterfactual stops being conditional on
#     anything in bots/.  Section 5b(a) is the only thing that can notice.
sed -i "s/'wkt10ls'/'wkt10lsXX'/g" "$WK"
run "M1 wkt10ls gate renamed -> 5b(a) must red" "no longer carries the wkt10ls gate"

# M2  The flip keeps the RIGHT row ({10, 0}), so arming the id changes nothing.
#     This is the silent-no-op failure mode that check_armed_wiring.py cannot
#     see (a call site exists; the predicate is just pointless).
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
s = s.replace("tTalentTreeList['t10'] = {0, 10}", "tTalentTreeList['t10'] = {10, 0}", 1)
open(p, 'w').write(s)
PY
run "M2 flip selects the same row -> 5b(a) must red" "the flip must put a 0 first"

# M3  GetTalentBuild's t10 left/right rule flips.  Both picks in 5b(b) go
#     through it, so the pair must stop resolving.
#     ⚠️ `want` names the assertion that ACTUALLY fires first (the shipped one),
#        not the one the mutant is "about" -- the -170/-172/-173 trap.
sed -i "s/\[1\] = ( tTalentTreeList\['t10'\]\[1\] == 0 and 1 or 2 )/[1] = ( tTalentTreeList['t10'][1] == 0 and 2 or 1 )/" "$ABA"
run "M3 selection rule flips -> 5b(b) must red" "should still take talent index 2"

# M4  The KV snapshot re-orders the t10 pair.  Without 5b(c) the file would go
#     on pricing "index 1" whatever index 1 had become.
sed -i "s/name = 'special_bonus_unique_wraith_king_2'/name = 'special_bonus_unique_wraith_king_ZZ'/" "$SLOTS"
run "M4 t10 pair re-ordered -> 5b(c) must red" "no longer the Vampiric Spirit row"

# M5  The counterfactual is computed with the dot ALREADY extended -- i.e. 5b2
#     silently asks the shipped question again.  The no-op region comes back and
#     the "still withdraws at every level" claim must red.
sed -i "s/return shipped_at(nRank) - armed_value(nRank, Q_DOT_BASE), nRank/return shipped_at(nRank) - armed_value(nRank, Q_DOT_T10), nRank/" "$TEST"
run "M5 counterfactual uses the extended dot -> 5b2 must red" "must still withdraw"

# M6  The lever's own hardcode moves.  5b2's per-rank sizes are supposed to come
#     from driving the real X.wk_GetBlastKillDamage, not from four typed numbers.
sed -i "s/local nShipped = ( 40 \* ( hAbility:GetLevel() - 1 ) + 100 ) \* 1.68/local nShipped = ( 40 * ( hAbility:GetLevel() - 1 ) + 100 ) * 1.0/" "$WK"
run "M6 the 1.68 hardcode moves -> 5b2's sizes must red" "should withdraw 48"

echo
echo "mutants killed $pass / $((pass + fail))"
[ "$fail" -eq 0 ] || exit 3
