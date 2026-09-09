#!/usr/bin/env bash
# Mutation stand for the `cmwface` candidate -- the heading cone that Crystal
# Maiden's SELF-DEFENCE Frostbite branch alone carries, and that no sibling
# branch of X.ConsiderW asks for (hero, 2026-09-09, OWNER_PRIORITIES P4.4 (i)).
# Run by hand when X.cm_IsSelfDefenseFacingOk, X.ConsiderW or
# tests/test_cm_w_selfdefense_facing.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmrcrowd.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick (command substitution);
#   * every `want` is something the mutant actually makes the suite SAY.
#
# ⚠️ HOW TO PICK A `want`, learned the hard way on 2026-09-09.  tests/run_tests.lua
# prints the failing test's NAME for every failure but the assert MESSAGE only for
# the last one.  So a want taken from an assert message works only while the
# mutant produces exactly ONE failure, and silently degrades to "RED with the
# WRONG MESSAGE" -- i.e. scores as survived -- the day it produces two.  M1 and
# M2 were first written that way and scored 0/2 while the suite was in fact
# catching M1 six separate times.  A want drawn from a test NAME cannot rot like
# that; prefer it whenever the mutant reddens more than one assertion.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, and the armed leg hands back the engine's answer anyway -- inert
#     in every wave, and the verdict reads back "tested, no effect".  This one is
#     unusually easy to write here, because the shipped predicate is exactly one
#     expression long.
#   * M3 is the INVERSION: armed suppresses the branch it was written to open,
#     while staying gated, wired and turbo-only.
#   * M5 removes the CALL SITE.  Helper, id, note, cone constant and every gate
#     test survive; only the source-shape assertion sees it.
#   * M6 moves the cone off 45.  Gate OFF then stops being the shipped predicate
#     byte for byte, and NOTHING on a fixture can notice -- the mock answers the
#     cone question false for any cone (see the test's 6.1) -- so the only reader
#     that can catch it is the stub stand in section 2.
#   * M7 is the pullcad trap (AGENTS.md): conjoining a sibling id that lives in
#     the same file would freeze this gate FALSE the day that sibling is
#     promoted, while check_armed_wiring.py still calls the lever WIRED.
#   * M8 is a control on the STAND'S OWN READING: the Wraith-King-domain census
#     that decided which hero moved this round must be able to go red, or
#     "empty at 1600u" is a sentence rather than a measurement.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_w_selfdefense_facing.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmwface.XXXXXX")
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

# The filter is `cm`, not this one file: the sibling Crystal Maiden assertions
# (cmrcrowd / cmrguard / cmrself / cmrcap / cmfarcreep / cmrangedhp / cmlaneband
# / cmqreach) read the same hero module, and a stand scoped to the new file alone
# would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua cm > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of several identical sites scores "survived" for the
# wrong reason.
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

GATE="	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmwface' ) then return true end"

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
# M1: the candidate check is dropped.  The cone stops applying in EVERY Turbo
#     game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE" "	if J.IsModeTurbo() then return true end"
score "M1" "2.1: gate OFF is the shipped call"

# ---------------------------------------------------------------------------
# M2: the turbo conjunct is dropped.  The lever leaks into normal mode, which is
#     not what any wave measures and not what the charter allows to ship dark.
echo
echo "=== M2: the gate stops being turbo-only ==="
sub "$HERO" "$GATE" "	if J.IsSoakCandidate( 'cmwface' ) then return true end"
score "M2" "1.2: the gate is turbo-only, names cmwface"

# ---------------------------------------------------------------------------
# M3: INVERSION.  Armed, the helper refuses -- the branch this lever exists to
#     open is the branch it now nails shut, and it is still gated and wired.
echo
echo "=== M3: armed REFUSES instead of releasing ==="
sub "$HERO" "$GATE" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmwface' ) then return false end"
score "M3" "armed, the cone must not be able to refuse"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  The armed leg asks the engine anyway.  Helper, id, call site,
#     cone constant and the whole prose survive; the lever is inert in every wave
#     in which the engine happens to answer false, i.e. exactly the wave the
#     lever was written for.
echo
echo "=== M4: armed consults the engine anyway (dead wiring) ==="
sub "$HERO" "$GATE" \
    "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmwface' ) then return hBot:IsFacingLocation( hTarget:GetLocation(), X.nWSelfDefenseFacingCone ) end"
score "M4" "armed, the helper still called IsFacingLocation"

# ---------------------------------------------------------------------------
# M5: the CALL SITE is removed and the shipped line put back.  Everything the
#     lever is described by still exists; nothing consumes it.
echo
echo "=== M5: the branch reads the engine directly again (no call site) ==="
sub "$HERO" "			and X.cm_IsSelfDefenseFacingOk( bot, npcEnemy )" \
            "			and bot:IsFacingLocation( npcEnemy:GetLocation(), 45 )"
score "M5" "X.ConsiderW still calls IsFacingLocation directly"

# ---------------------------------------------------------------------------
# M6: the cone moves off the shipped 45.  Gate OFF is no longer the shipped
#     predicate -- and NO fixture can see it, because the mock answers the cone
#     question false whatever the cone is (test section 6.1).  Only the stub
#     stand in section 2 is looking.
echo
echo "=== M6: gate OFF stops being the shipped cone ==="
sub "$HERO" "X.nWSelfDefenseFacingCone = 45" "X.nWSelfDefenseFacingCone = 360"
score "M6" "the shipped cone is 45"

# ---------------------------------------------------------------------------
# M7: the pullcad trap.  A sibling id in the same file is conjoined into the
#     gate.  The lever no-ops in every wave from the day that sibling is
#     promoted, and the verdict reads back "tested, no effect".
echo
echo "=== M7: a sibling soak id is conjoined into the gate (pullcad trap) ==="
sub "$HERO" "$GATE" \
    "	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmwface' ) and J.IsSoakCandidate( 'cmrcrowd' ) then return true end"
score "M7" "the pullcad trap"

# ---------------------------------------------------------------------------
# M8: control on the stand's own reading.  The Wraith-King census is the
#     measurement that decided CM moved and WK did not; if it cannot go red when
#     its own ceiling is loosened past the 1699u frame, it is prose.
echo
echo "=== M8: control -- the Wraith King domain census must be able to go red ==="
sub "$TEST" "    local REPORTABLE = 1600" "    local REPORTABLE = 2000"
score "M8" "Wraith King frame(s) now ALSO put an enemy hero inside"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
