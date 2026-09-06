#!/usr/bin/env bash
# Mutation stand for the `-76` reason-sentence read (2026-09-04, hero).
#
# Four test files were edited.  Every edit is a REASON edit: the pre-existing
# assertions in all four were green before and are green after, and the readings
# did not move.  So "the suite passes" says nothing about whether the SEVEN new
# sections can fail at all -- exactly the M14 shape the `-93` round paid for
# ("a landing that moves no value must carry its own white-box mutation").
#
#   tests/test_replay_072738_zuus_script.lua   §A drift sentinel
#                                              §B registered disagreement (4/4)
#                                              §C the overwrite was a no-op
#                                              §D empty domain + refuted cause
#   tests/test_axe_cull_immune_veto.lua        KV: recorded anchor vs fixture KV
#   tests/test_cm_q_creep_aoe_reach.lua        KV: pinned Nova numbers vs KV
#   tests/test_replay_260819_cm_r_range.lua    anchors: why each is still needed
#                                              anchors: the 810/835 gap
#
# LIMIT, stated because it cannot be mutated away: §D's full-mana negative
# control CANNOT be driven red by removing the drive.  The raw frame and the
# full-mana frame both queue 0 actions -- that IS the finding -- so deleting
# `sp.GetMana = bot:GetMaxMana()` leaves every number identical.  M4 therefore
# proves only that §D's counter is wired to the action log at all (inject an
# action, it reds), not that the control is doing work today.  §D's value is as
# a tripwire for the day the frame stops being empty, and it is written to say
# so when it fires.
#
# Anchor discipline (backlog `-91`): sub() ABORTS if its anchor is not unique.
set -u

Z=tests/test_replay_072738_zuus_script.lua
A=tests/test_axe_cull_immune_veto.lua
C=tests/test_cm_q_creep_aoe_reach.lua
R=tests/test_replay_260819_cm_r_range.lua
FILES="$Z $A $C $R"

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
#
# The uniqueness count is done in python over the WHOLE FILE TEXT, not by grep.
# grep -F splits a multi-line pattern into independent line patterns and counts
# lines matching ANY of them, so a two-line anchor that occurs exactly once
# reports 3.  That mis-count is the anchor guard failing OPEN in the one shape
# it exists for.
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

# expect_red <filter> <label> <substring the failure text must contain>
expect_red() {
    local filter=$1 label=$2 want=$3 out rc
    out=$(lua5.1 tests/run_tests.lua "$filter" 2>&1); rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "  SURVIVED  $label -- the suite stayed green; the assertion is asleep"
        fail=$((fail + 1))
    elif ! printf '%s' "$out" | grep -qF -- "$want"; then
        echo "  WRONG-RED $label -- it failed, but not on '$want'"
        printf '%s\n' "$out" | tail -4
        fail=$((fail + 1))
    else
        echo "  KILLED    $label"
        pass=$((pass + 1))
    fi
    restore_all
}

echo "=== baseline (all four must be green) ==="
for filter in test_replay_072738_zuus_script test_axe_cull_immune_veto \
              test_cm_q_creep_aoe_reach test_replay_260819_cm_r_range; do
    if lua5.1 tests/run_tests.lua "$filter" > /dev/null 2>&1; then
        echo "  ok   $filter"
    else
        echo "  BASELINE RED: $filter -- stand is meaningless, stop" >&2
        exit 8
    fi
done

echo "=== mutants ==="

# ---------------------------------------------------------------- zuus script
# M1 -- claim the KV agrees with the old hand anchor.  §A must catch that the
# loader answers 800, not 850.
sub "$Z" "zuus_arc_lightning  = { rank = 2, range = 800, mana = 90 }" \
         "zuus_arc_lightning  = { rank = 2, range = 850, mana = 90 }"
expect_red test_replay_072738_zuus_script "M1 KV row lies about cast range (§A)" \
    "loader cast range"

# M2 -- make one hand anchor agree with the KV.  §B must drop to 3/4.
sub "$Z" "zuus_arc_lightning  = { range = 850, mana = 80 }" \
         "zuus_arc_lightning  = { range = 800, mana = 80 }"
expect_red test_replay_072738_zuus_script "M2 an anchor stops disagreeing (§B)" \
    "measured 3/4"

# M3 -- make the anchor world genuinely differ from the KV world, so the
# "removing the overwrite was a no-op" claim becomes false.  §C must catch it.
#
# The action has to be queued AFTER record_actions installs the spy -- an
# earlier version of this mutant put it in the bAnchor block, which runs before
# the spy, and it SURVIVED.  That survival was the mutant being wrong, not the
# assertion being asleep (evidence discipline 2: suspect the mutant first).
sub "$Z" "    local log = rf.record_actions(bot)
    local ok, err = pcall(function() rf.load_hero('zuus').SkillsComplement() end)" \
         "    local log = rf.record_actions(bot)
    if bAnchor then bot:ActionQueue_UseAbility(bot:GetAbilityByName('zuus_arc_lightning')) end
    local ok, err = pcall(function() rf.load_hero('zuus').SkillsComplement() end)"
expect_red test_replay_072738_zuus_script "M3 the two worlds stop agreeing (§C)" \
    "was NOT a no-op"

# M4 -- inject one action into every run, proving §D's counter reads the log.
sub "$Z" "    local log = rf.record_actions(bot)
    local ok, err = pcall(function() rf.load_hero('zuus').SkillsComplement() end)" \
         "    local log = rf.record_actions(bot)
    bot:ActionQueue_UseAbility(bot:GetAbilityByName('zuus_arc_lightning'))
    local ok, err = pcall(function() rf.load_hero('zuus').SkillsComplement() end)"
expect_red test_replay_072738_zuus_script "M4 the frame queues something (§D)" \
    "this is good news"

# ------------------------------------------------------------------- axe / KV
# M5 -- move the recorded anchor off the shipped data.  The KV section must
# name the rank that parted company.
sub "$A" "local R_DAMAGE = { 275, 375, 475 }" \
         "local R_DAMAGE = { 275, 380, 475 }"
expect_red test_axe_cull_immune_veto "M5 recorded damage drifts from the KV (axe KV)" \
    "rank 2 damage: anchor 380"

# M6 -- the white-box half (the M14 lesson): take the KV spec away and the
# cross-check must call itself VACUOUS rather than pass.  Without this, a loader
# that stopped serving Axe would turn the section green-by-absence.
sub "$A" "tests['KV: the recorded Culling anchor matches the fixture KV on all three ranks'] = function()
    local _, bot = rf.load(FIXTURE)
    local h = bot:GetAbilityByName(CULLING)" \
         "tests['KV: the recorded Culling anchor matches the fixture KV on all three ranks'] = function()
    local _, bot = rf.load(FIXTURE)
    local h = bot:GetAbilityByName(CULLING)
    rawget(h, '__spec').GetSpecialValueFloat = nil"
expect_red test_axe_cull_immune_veto "M6 the loader stops serving Axe (axe KV, white box)" \
    "the cross-check is vacuous"

# --------------------------------------------------------------- cm_q / KV
# M7 -- move a pinned number off the shipped data.
sub "$C" "local NOVA_RADIUS     = 425   -- external anchor, see header" \
         "local NOVA_RADIUS     = 420   -- external anchor, see header"
expect_red test_cm_q_creep_aoe_reach "M7 pinned Nova radius drifts from the KV (cm_q KV)" \
    "radius: pinned 420"

# ------------------------------------------------------- cm_r_range / anchors
# M8 -- the loader starts serving a NON-FOCUS hero.  The anchor section must
# say the focus-five bound moved, not quietly keep using the hand number.
sub "$R" "    for _, c in ipairs(cases) do
        local _, _, heroes = rf.load(c[1])" \
         "    for _, c in ipairs(cases) do
        local _, _, heroes = rf.load(c[1])
        rawget(heroes[c[2]]:GetAbilityByName(c[3]), '__spec').GetCastRange = 325"
expect_red test_replay_260819_cm_r_range "M8 a non-focus hero gets served (cm_r anchors)" \
    "the focus-five bound moved"

# M9 -- the 810/835 gap closes.  The registration must fire rather than sit.
sub "$R" "        assert(r:GetSpecialValueInt('radius') == 810," \
         "        rawget(r, '__spec').GetSpecialValueInt = function() return 835 end
        assert(r:GetSpecialValueInt('radius') == 810,"
expect_red test_replay_260819_cm_r_range "M9 the KV radius moves to 835 (cm_r gap)" \
    "the gap is closed"

echo
echo "MUTSTAND ${pass}/$((pass + fail)) killed"
restore_all
verify_restore || exit 1
[ "$fail" -eq 0 ] || exit 1
