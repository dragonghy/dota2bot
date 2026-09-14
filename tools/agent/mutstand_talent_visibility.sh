#!/usr/bin/env bash
# Mutation stand for tests/test_talent_uptake_visibility.lua (GH #817, hero
# 2026-09-14).  Each mutant breaks ONE thing the file claims; a mutant that
# SURVIVES is an assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant (evidence-discipline rule 1): a sed that "undoes" a sed is
# not a restore, and a stand that dies mid-run must not leave a mutated tree.
#
# ⛔ TWO MUTANTS THAT CANNOT BE KILLED, and why -- do not add them:
#   * flipping Axe's t10 from {n,0} to {0,n}: BOTH of Axe's t10 rows are
#     hero-unique, so the ceiling stays 0 and section 4's Axe test is right to
#     stay green.  The assertion is about the ceiling, not about which row.
#   * re-typing WAVE's `talents` for any hero except skeleton_king: only WK's
#     count is joined to a computed ceiling; the rest are transcription and the
#     file says so.
#
# Usage: bash tools/agent/mutstand_talent_visibility.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_talent_uptake_visibility.lua
ABA=bots/FunLib/aba_skill.lua
GENERIC=bots/ability_item_usage_generic.lua
DUMPER=tools/batch_test/behavioral/dumper/main.go
WK=bots/BotLib/hero_skeleton_king.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$ABA" "$GENERIC" "$DUMPER" "$WK"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

# Restore, and then PROVE it: a stand that only copies has no way to notice it
# put back the wrong bytes (or nothing at all), and the tree it hands the next
# reader is the mutated one.  sha256sum against the pristine copies is the
# proof; a mismatch aborts rather than continuing to run mutants on a tree
# nobody can trust.
restore() {
	local f pristine
	for f in "$TEST" "$ABA" "$GENERIC" "$DUMPER" "$WK"; do
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
	out=$(lua5.1 tests/run_tests.lua talent_uptake 2>&1)
	if echo "$out" | grep -q "0 failures"; then
		echo "SURVIVED  $name  -- the suite stayed green"
		fail=$((fail + 1))
	elif echo "$out" | grep -qF "$want"; then
		echo "killed    $name"
		pass=$((pass + 1))
	else
		echo "WRONG MESSAGE  $name  -- red, but not on the assertion aimed at"
		echo "$out" | grep -A2 'FAIL' | head -6
		fail=$((fail + 1))
	fi
	restore
}

# M1  The partition's single permitted miss is removed: OD now reads as spending
#     at level 10, so nothing misses and the "exactly one miss" claim must red.
#     This is the mutant that proves section 2 is not just counting to <=1.
sed -i "s/{ hero = 'obsidian_destroyer', talents = 0, lv10 = 0 }/{ hero = 'obsidian_destroyer', talents = 0, lv10 = 8 }/" "$TEST"
run "M1 OD stops missing -> 'exactly one miss' must red" "supposed to miss on obsidian_destroyer"

# M2  A SECOND miss appears (a unique-t10 hero that did spend at 10).  Guards
#     the other side of the same equality; M1 alone passes a `#misses <= 1`.
sed -i "s/{ hero = 'nevermore',          talents = 0, lv10 = 0 }/{ hero = 'nevermore',          talents = 0, lv10 = 8 }/" "$TEST"
run "M2 a second miss appears -> must red" "supposed to miss on obsidian_destroyer"

# M3  The dumper's drop moves AFTER the leveled-talent keep -- the exact code
#     change that would make unique talents visible and this whole file wrong.
python3 - <<'PY'
import re
p = 'tools/batch_test/behavioral/dumper/main.go'
s = open(p).read()
i = s.index('func isRealAbility')
head, body = s[:i], s[i:]
drop = '''	if strings.Contains(cn, "Special_Bonus_Base") || strings.Contains(cn, "Special_Bonus_Attributes") {
		return false
	}
'''
keep = '''	if strings.Contains(cn, "Special_Bonus") {
		return level > 0
	}
'''
body = body.replace(drop + keep, keep + drop, 1)
open(p, 'w').write(head + body)
PY
run "M3 dumper drop moves after the keep -> order claim must red" "the other way round"

# M4  The terminal else starts removing the head, which is what section 5's
#     "the head was not stuck" argument rests on NOT happening.
python3 - <<'PY'
p = 'bots/ability_item_usage_generic.lua'
s = open(p).read()
i = s.index('print("[WARN] Skipped to level up ability "')
j = s.index('\n', i)
s = s[:j + 1] + '\t\t\ttable.remove( sAbilityLevelUpList, 1 )\n' + s[j + 1:]
open(p, 'w').write(s)
PY
run "M4 terminal else removes the head -> section 5 must red" "terminal \`else\` now removes the head"

# M5  GetTalentBuild's t10 rule flips left/right.  Every row this file looks up
#     goes through it, so it must red BEFORE any partition is reported.
sed -i "s/\[1\] = ( tTalentTreeList\['t10'\]\[1\] == 0 and 1 or 2 )/[1] = ( tTalentTreeList['t10'][1] == 0 and 2 or 1 )/" "$ABA"
# ⚠️ `want` names the assertion that ACTUALLY fires first, not the one the
#    mutant is "about": the pattern still matches a flipped rule (it captures
#    both digits), so the shape guard passes and the VALUE guard on the next
#    line is what reds.  Aiming `want` at the earlier assert reads the kill as
#    WRONG MESSAGE -- the same trap the -170 and -172 stands hit.
run "M5 selection rule flips -> the read-out-of-source guard must red" "this file assumes 1 and 2"

# M6  Wraith King's t15 pick moves onto a hero-unique row, taking his visible
#     ceiling to 0 while #817's transcribed count stays 1.  Guards the join in
#     section 4 -- without it the test only asserts a constant.
sed -i "s/\['t15'\] = {10, 0},/['t15'] = {0, 10},/" "$WK"
run "M6 WK t15 -> unique row, ceiling 0 vs read 1" "selected talent rows is generic"

# M7  Anti-vacuum: the WAVE table is emptied.  A partition over zero heroes
#     agrees with everything, and the round-count guard is the only thing that
#     can notice.
python3 - <<'PY'
import re
p = 'tests/test_talent_uptake_visibility.lua'
s = open(p).read()
s = re.sub(r'local WAVE = \{.*?\n\}\n', 'local WAVE = {}\n', s, count=1, flags=re.S)
open(p, 'w').write(s)
PY
run "M7 WAVE emptied -> the ten-hero guard must red" "walked 0"

echo
echo "mutants killed $pass / $((pass + fail))"
[ "$fail" -eq 0 ] || exit 3
