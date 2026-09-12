#!/usr/bin/env bash
# Mutation stand for tests/test_arbheart_host_bid_role_gate.lua
# (strategy desk 2026-09-12, GH #775).  Not part of any suite -- run by hand
# when that test, bots/mode_farm_generic.lua or the IsTimeToFarm role gate in
# bots/FunLib/aba_site.lua is edited.
#
# WHAT IS ON THE BENCH.  The file makes ONE reading and ONE witness:
#   * the reading -- on arbheart's own pinned frame the host mode bids NONE
#     through every one of its ten positive-desire exits, and the conjunct that
#     closes it is `J.Site.IsTimeToFarm(bot)`, false BY ROLE for a position-5
#     support;
#   * the witness -- with a bid restored through the bypass exit, the release
#     AND the retire fire on a tick whose own GetDesire() is positive.
# A reading like that is worth exactly as much as the mutants it can see, so the
# mutants split three ways:
#   * M1/M2 -- the CAUSE mutants.  Is the zero really caused by that conjunct
#     and by the role band underneath it, or would any frame read zero?
#   * M3/M4 -- the WITNESS mutants.  Does section C constrain the release and
#     the retire, or would any world satisfy it?
#   * M5/M6/M7 -- the ORACLE mutants.  A line trace that matches nothing and a
#     source scanner that finds nothing both print a perfectly clean reading.
#     Each must be caught by a DIFFERENT assertion.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3): restore is an out-of-tree
# `cp` verified with `sha256sum -c`, never `git checkout`; exit codes are read
# BARE, never through a pipe; a mutant whose anchor is absent OR ambiguous
# ABORTS the stand rather than scoring a no-op as "caught".
#
# Usage: bash tools/agent/mutstand_arbheart_hostbid.sh
set -u
cd "$(dirname "$0")/../.."

MODE=bots/mode_farm_generic.lua
SITE=bots/FunLib/aba_site.lua
TEST=tests/test_arbheart_host_bid_role_gate.lua
FILES=("$MODE" "$SITE" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_arbheart.XXXXXX")
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

run_tests() {
    lua5.1 tests/run_tests.lua arbheart_host_bid > "$WORK/run.log" 2>&1
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
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ANCHOR PROBLEM -- stand aborted rather than scoring a no-op"
        exit 2
    fi
}

CONJ=$'\tand J.Site.IsTimeToFarm(bot)'
BAND=$'    if not considerResult and ____exports.GetPosition(bot) <= 3 then'
RADIUS=$'\t\t\t\t\t\tand GetUnitToLocationDistance(member, vCamp) <= 800'
RETIRE=$'\t\t\t\t\t\tJ.Role[\'availableCampTable\'] =\n\t\t\t\t\t\t\tJ.Site.UpdateAvailableCamp(bot, old, J.Role[\'availableCampTable\'])'
HOOK=$"        if src:find('mode_farm_generic') then"
SCAN=$'        if inHelper and text:match(\'return%s\') and not text:match(\'BOT_MODE_DESIRE_NONE\')'
GUARDA=$'\t\t\t\tlocal nCampAllies = J.GetAlliesNearLoc(preferedCamp.cattr.location, 800)'

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
        grep -m1 'FAIL' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

echo
echo "=== mutants ==="

# M1: the named conjunct stops gating.  If the zero survives this, the reading
# blames the wrong line and every conclusion drawn from it is about something
# else.
sub "$MODE" "$CONJ" $'\tand true'
score "M1 IsTimeToFarm conjunct neutered  " "must bid NONE here"

# M2: the role band widens to take position 5 in.  This is the ONLY reason the
# subject fails IsTimeToFarm, so the whole "closed by role, not by frame" half
# rests on it being load-bearing.
sub "$SITE" "$BAND" $'    if not considerResult and ____exports.GetPosition(bot) <= 5 then'
score "M2 role band widened to pos 5      " "IsTimeToFarm now answers yes"

# M3: the release radius shrinks below the ally's real distance (574.8u).  The
# witness must be about THIS geometry, not about arming the gate at all.
sub "$MODE" "$RADIUS" $'\t\t\t\t\t\tand GetUnitToLocationDistance(member, vCamp) <= 100'
score "M3 release radius 800 -> 100       " "released AND retired"

# M4: the retire call is deleted (the GH #456 defect restored).  Section C
# claims release AND retire on a live tick; without this mutant it could be
# claiming only the release.
sub "$MODE" "$RETIRE" ""
score "M4 retire call deleted             " "released AND retired"

# M5: the line hook stops matching the file under test, so the trace is empty.
# An empty trace contains no positive exit and no guard A -- i.e. it passes the
# two "nothing was reached" assertions for free.  R2's terminal-line assertion
# is what stands between that and a clean-looking reading.
sub "$TEST" "$HOOK" $"        if false and src:find('mode_farm_generic') then"
score "M5 trace hook matches nothing      " "must leave through its terminal"

# M6: the positive-exit scanner finds nothing.  Then "the trace reached none of
# them" is vacuous; only the count assertion can see it.
sub "$TEST" "$SCAN" $'        if false and inHelper and text:match(\'return%s\') and not text:match(\'BOT_MODE_DESIRE_NONE\')'
score "M6 exit scanner finds nothing      " "positive-desire exits"

# M7: guard A is reshaped so the locator cannot find it.  Both R3 and C2 reason
# about lines the locator returns; if it silently answers nil, "the guard never
# ran" would hold because nothing was ever looked for.
sub "$MODE" "$GUARDA" $'\t\t\t\tlocal nCampAllies = J.GetAlliesNearLoc(preferedCamp.cattr.location, 801)'
score "M7 guard A locator anchor moved    " "gone or reshaped"

echo
echo "=== stand ==="
echo "$CAUGHT/$TOTAL caught"
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
else
    echo "STAND RED -- a mutant the assertions cannot see is a claim this file"
    echo "            is not entitled to make. Fix the file, not this script."
    exit 1
fi
