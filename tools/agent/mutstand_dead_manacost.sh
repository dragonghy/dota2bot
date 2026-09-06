#!/usr/bin/env bash
# Mutation stand for tests/test_dead_manacost_binding_census.lua
# (2026-09-05, hero stream, backlog -75).
#
# WHY THIS STAND EXISTS.  The landing that added that file moves NO value: it
# adds a register and its guards, `bots/` keeps its behaviour byte for byte, and
# every number it asserts was already true before the file existed.  "The suite
# is green" therefore says nothing about whether any of those eight sections can
# fail at all -- the M14 shape backlog `-93` paid for ("a landing that moves no
# value must carry its own white-box mutation").
#
# Six mutations, each aimed at ONE section, plus the supply pair that has to red
# FIRST (M5): a scanner pointed at nothing satisfies every "this must be absent"
# assertion perfectly, so the negative results in that file are free unless the
# floors bite before them.
#
# Anchor discipline (backlog `-91`, sharpened in `-94`): sub() aborts unless its
# anchor is unique, and the count is taken in python over the WHOLE FILE TEXT.
# `grep -F` splits a multi-line pattern into independent line patterns and counts
# lines matching ANY of them, so a two-line anchor occurring exactly once reports
# 3 -- the guard failing open in the one shape it exists for.
set -u

CENSUS=tests/test_dead_manacost_binding_census.lua
LION=bots/BotLib/hero_lion.lua
AXE=bots/BotLib/hero_axe.lua
WK=bots/BotLib/hero_skeleton_king.lua
JMZ=bots/FunLib/jmz_func.lua
SCAN=tests/lua_source_scan.lua
FILES="$CENSUS $LION $AXE $WK $JMZ $SCAN"

BAKDIR=$(mktemp -d)
for f in $FILES; do cp "$f" "$BAKDIR/$(basename "$f")"; done
restore_all() { for f in $FILES; do cp "$BAKDIR/$(basename "$f")" "$f"; done; }
# A stand that restores but cannot PROVE it restored may have eaten the round's
# fix and said nothing (GH #418).  The manifest is taken before the first
# mutation; verify_restore re-checks it at the end.
sha256sum $FILES > "$BAKDIR/orig.sha"
verify_restore() {
	sha256sum -c "$BAKDIR/orig.sha" > /dev/null \
		|| { echo "RESTORE FAILED: the tree did not come back byte-for-byte"; return 1; }
	echo "restore verified"
}
trap 'restore_all; rm -rf "$BAKDIR"' EXIT

pass=0; fail=0

# sub <file> <literal-from> <literal-to>
sub() {
    local file=$1 from=$2 to=$3
    python3 - "$file" "$from" "$to" <<'PY' || exit 9
import sys
p, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
n = s.count(a)
if n != 1:
    sys.stderr.write("ABORT: anchor is not unique (%d occurrences):\n%s\n" % (n, a))
    sys.exit(9)
open(p, 'w').write(s.replace(a, b, 1))
PY
}

# expect_red <label> <substring the failure text must contain>
#
# The exit code is read from a command substitution, never through a pipe
# (evidence discipline 3: a pipe reports the READER's status).
expect_red() {
    local label=$1 want=$2 out rc
    out=$(lua5.1 tests/run_tests.lua test_dead_manacost_binding_census 2>&1); rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "  SURVIVED  $label -- the suite stayed green; the assertion is asleep"
        fail=$((fail + 1))
    elif ! printf '%s' "$out" | grep -qF -- "$want"; then
        echo "  WRONG-RED $label -- it failed, but not on '$want'"
        printf '%s\n' "$out" | tail -6
        fail=$((fail + 1))
    else
        echo "  KILLED    $label"
        pass=$((pass + 1))
    fi
    restore_all
}

echo "== baseline"
if out=$(lua5.1 tests/run_tests.lua test_dead_manacost_binding_census 2>&1); then
    echo "  green: $(printf '%s' "$out" | tail -1)"
else
    echo "  ABORT: the stand's baseline is already RED -- nothing below is readable"
    printf '%s\n' "$out" | tail -8
    exit 2
fi

echo "== M1 wire the class-戊 site the backlog is actually about (lion ConsiderW)"
# The one mutation that mimics the intended future change.  Two sections must
# object: the site leaves the dead set (register: missing) and, were it still
# dead, its `absent` list would object too.  This is the assertion whose red is
# the deliverable, so it has to be provably reachable.
sub "$LION" '	local nManaCost = abilityW:GetManaCost()
	local nDamage = abilityW:GetAbilityDamage()' \
'	local nManaCost = abilityW:GetManaCost()
	if J.GetManaAfter( nManaCost ) < 0.3 then return 0 end
	local nDamage = abilityW:GetAbilityDamage()'
expect_red "M1 lion ConsiderW wired" "a registered site is gone from the dead set"

echo "== M2 a focus function grows a NEW unread binding"
sub "$WK" '	local nManaCost = abilityQ:GetManaCost()' \
'	local nManaCost = abilityQ:GetManaCost()
	local nUnreadCost = abilityW:GetManaCost()'
expect_red "M2 new dead site in skeleton_king" "grew a NEW unread GetManaCost binding"

echo "== M3 affordability stops being answered upstream (axe ConsiderR)"
sub "$AXE" '	if not abilityR:IsFullyCastable() then return 0 end' \
'	if abilityR:GetLevel() <= 0 then return 0 end'
expect_red "M3 axe ConsiderR loses IsFullyCastable" "no longer gates on IsFullyCastable"

echo "== M4 the class-乙 gate is promoted away"
sub "$JMZ" "	if not J.IsLaneFixOn( 'mana' ) then return false end" \
'	-- gate removed by the mutation stand'
expect_red "M4 ShouldConserveManaInLane ungated" "no longer opens with an IsLaneFixOn gate"

echo "== M5 kill the supply: do the FLOORS red before the negative results?"
# The point of the whole stand.  Every "this must be absent" reading in the
# census file is satisfied by a scanner that reaches nothing.  Emptying the
# walk must be caught by a supply floor, not shrugged off as a clean sweep.
sub "$SCAN" "        'find bots -name \"*.lua\" '" \
"        'find bots -name \"*.NOSUCH\" '"
expect_red "M5 tree walk returns nothing" "supply:"

echo "== M6 white-box: is the class register doing the work, or the dead set?"
# M1 reds two sections at once, so on its own it cannot say the `absent` list
# earns its place.  Here the site is wired AND kept in the dead set (the write
# is a comment mention, which the scanner resolves toward LIVE only for real
# code -- so instead we keep the read and drop the register's own guard), and
# the surviving objection must be the class assertion naming class 戊.
sub "$CENSUS" "    { path = 'bots/BotLib/hero_lion.lua', fn = 'X.ConsiderW', recv = 'abilityW',
      class = '戊', absent = RESERVE_IDIOMS }," \
"    { path = 'bots/BotLib/hero_lion.lua', fn = 'X.ConsiderW', recv = 'abilityW',
      class = '戊', tags = { 'IsAllowedToSpam' } },"
expect_red "M6 register anchored on a predicate that is not there" "is registered class 戊 on the strength of"

echo
echo "KILLED=$pass  SURVIVED/WRONG=$fail"
restore_all
verify_restore || exit 1
[ "$fail" -eq 0 ] || exit 1
