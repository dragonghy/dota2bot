#!/usr/bin/env bash
# Mutation stand for the `cmqpoke` lever (hero desk 2026-09-10).
# Not part of any suite -- run by hand when
# bots/BotLib/hero_crystal_maiden.lua's X.cm_ShouldSpendSurplusNova or
# tests/test_cm_nova_surplus_poke.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3), copied from
# mutstand_axecullreach.sh because each line of it was paid for:
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while moving
# nothing, or moving the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, armed path hands back the shipped answer.  Inert in every wave,
#     and the verdict reads back "tested, no effect".
#   * M3 is the INVERSION -- armed declines the LOW-health targets and keeps the
#     healthy ones.  This lever's whole safety argument is a direction, so the
#     direction is on the bench in both senses (M3 inverts it, M9 widens it into
#     a cast-ADDING lever, which section 3 is built to catch).
#   * M6 is THE THIRD RULER: this file measures "enough mana" three ways (0.75
#     in the 进攻 branch, 0.8 here, a flat 440 in both).  Moving this branch onto
#     the other ruler leaves helper, id, gate and direction untouched -- and it
#     also silently deletes a gate from tests/_cm_t10_payoff_sweep.lua's model,
#     which is the trap this round actually fell into.
#   * M7 mutates IN THE SOURCE the thing that makes the pin frame reach this
#     lever at all.  Weakening the assertion instead would only prove the
#     assertion can be deleted.
#   * M2 is turbo-only being dropped while the candidate check stays.  It
#     SURVIVED the stand's first run -- nothing asserted turbo-only -- which is
#     exactly what a stand is for; section 1 now pins it.
#   * M10 is the pullcad trap (AGENTS.md): conjoining the sibling `cmqreach`,
#     which freezes this gate FALSE the day that sibling is promoted while
#     check_armed_wiring.py still calls it WIRED.
#   * M11 and M12 are controls on the READINGS this round published -- the
#     "ratio term decides nothing by itself" census and the pin frame's own
#     numbers.  A stand that cannot go red on a moved reading is not a stand.
#
# Usage: bash tools/agent/mutstand_cmqpoke.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_nova_surplus_poke.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmqpoke.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
}

trap restore EXIT

# The filter is `cm_`, not this one file: the sibling Crystal Maiden tests read
# the same hero module, and a stand scoped to the new file alone would report a
# collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua cm_ > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
n = s.count(old)
if n == 0:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
if n != 1:
    sys.stderr.write("ANCHOR AMBIGUOUS (%d hits) in %s: %r\n" % (n, f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the candidate check is dropped.  The narrowing becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmqpoke' ) ) then return true end" \
            "	if not J.IsModeTurbo() then return true end"
score "M1" "shipped no longer orders a Nova on the pin frame"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmqpoke' ) ) then return true end" \
            "	if not J.IsSoakCandidate( 'cmqpoke' ) then return true end"
score "M2" "is no longer turbo-only"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed declines the targets worth killing
#     and keeps the healthy ones -- the exact opposite of every sentence written
#     about this lever, while staying gated, wired and turbo-only.
echo
echo "=== M3: the quality test is inverted ==="
sub "$HERO" "	return hTarget:GetHealth() / nMaxHealth < 0.4" \
            "	return hTarget:GetHealth() / nMaxHealth >= 0.4"
score "M3" "armed still orders a Nova on the pin frame"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path returns the shipped answer anyway.  check_armed_wiring.py still
#     says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M4: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "	return hTarget:GetHealth() / nMaxHealth < 0.4" \
            "	return true"
score "M4" "armed still orders a Nova on the pin frame"

# ---------------------------------------------------------------------------
# M5: THE CALL SITE IS REMOVED.  Helper, header, id registration and unit tests
#     all survive; the branch goes back to the bare wallet test.
echo
echo "=== M5: the call site reverts to the shipped expression ==="
sub "$HERO" "				if X.cm_ShouldSpendSurplusNova( nWeakestEnemyHeroInBonus,
						nMP > 0.8 or bot:GetMana() > nKeepMana * 2 )" \
            "				if nMP > 0.8 or bot:GetMana() > nKeepMana * 2"
score "M5" "the catch-all branch no longer calls the helper"

# ---------------------------------------------------------------------------
# M6: THE THIRD RULER.  This file measures "enough mana" three different ways
#     (0.75 in the 进攻 branch, 0.8 here, a flat 440 in both).  Swapping this
#     branch onto the 进攻 branch's ruler is a behaviour change that leaves the
#     helper, the id, the gate and the direction untouched -- and it also
#     silently deletes a gate from tests/_cm_t10_payoff_sweep.lua's model.
echo
echo "=== M6: the branch is moved onto the other branch 0.75 ruler ==="
sub "$HERO" "						nMP > 0.8 or bot:GetMana() > nKeepMana * 2 )" \
            "						nMP > 0.75 or bot:GetMana() > nKeepMana * 2 )"
score "M6" "sites; exactly 1 is expected"

# ---------------------------------------------------------------------------
# M7: THE BRANCH GOES DARK.  The whole defect is that the wallet branch sits
#     ABOVE the quality branch and therefore always wins.  Freeze the shipped
#     argument false and the pin frame stops reaching the lever at all -- i.e.
#     the pin would silently stop testing anything.
echo
echo "=== M7: the shipped argument is frozen false (branch unreachable) ==="
sub "$HERO" "						nMP > 0.8 or bot:GetMana() > nKeepMana * 2 )" \
            "						false )"
score "M7" "sites; exactly 1 is expected"

# ---------------------------------------------------------------------------
# M8: the degenerate-read fallback is flipped from "fall back to shipped" to
#     "decline".  A getter that answers 0 would then silently stop Crystal Nova
#     ENTIRELY -- the `zusboltcap` failure direction (GH #175), in the opposite
#     direction to the one this lever is about, which no in-domain counter would
#     ever report.
echo
echo "=== M8: an unreadable max-health declines instead of deferring ==="
sub "$HERO" "	if type( nMaxHealth ) ~= 'number' or nMaxHealth <= 0 then return true end" \
            "	if type( nMaxHealth ) ~= 'number' or nMaxHealth <= 0 then return false end"
score "M8" "must DEFER to the shipped answer"

# ---------------------------------------------------------------------------
# M9: THE LEVER IS WIDENED into one that can ADD a cast -- the shipped
#     disjunction stops being evaluated first, so armed can turn a shipped FALSE
#     into TRUE.  Section 3's whole job.
echo
echo "=== M9: the shipped predicate stops gating the armed leg ==="
sub "$HERO" "	if not bShippedSurplus then return false end" \
            "	if not bShippedSurplus then return J.IsModeTurbo() and J.IsSoakCandidate( 'cmqpoke' ) end"
score "M9" "must name 'cmqpoke' exactly ONCE"

# ---------------------------------------------------------------------------
# M10: the pullcad trap -- the gate is conjoined with a sibling id, which
#      freezes it FALSE the day that sibling is promoted.
echo
echo "=== M10: the gate is conjoined with the sibling id cmqreach ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmqpoke' ) ) then return true end" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmqpoke' ) and J.IsSoakCandidate( 'cmqreach' ) ) then return true end"
score "M10" "names the sibling id 'cmqreach'"

# ---------------------------------------------------------------------------
# M11: a control on the CENSUS reading this round published -- the claim that
#      the ratio term decides nothing by itself.  Move the ratio and the census
#      must notice.
echo
echo "=== M11: the census reads the ratio term at a different threshold ==="
sub "$TEST" "local RATIO_TERM  = 0.8" \
            "local RATIO_TERM  = 0.3"
score "M11" "decides"

# ---------------------------------------------------------------------------
# M12: a control on the PIN's own numbers.  If the frame's mana is re-read, the
#      "the flat 440 is the disjunct doing the work" sentence stops holding and
#      section 4 must say so rather than passing.
echo
echo "=== M12: the pin's registered mana is moved ==="
sub "$TEST" "local KEEP_MANA   = 220" \
            "local KEEP_MANA   = 260"
score "M12" "nKeepMana is no longer 260"

echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 3
