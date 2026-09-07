#!/usr/bin/env bash
# Mutation stand for the 'roshpit' soak candidate (GH #450, ruling
# iterations/streams/test_set.md §FK.3) and its pin
# tests/test_roshan_pit_daynight.lua.  Not part of any suite -- run by hand
# when either the gate or the test file is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- the runner writes to a log file and `$?` is
#     read with no pipe between it and the command;
#   * a mutant whose target string is absent ABORTS, because a no-op edit
#     scored as "caught" is the stand lying about what was on the bench.
#
# AND THE ONE THIS FAMILY OF STANDS IS WRITTEN AROUND (test_set.md §EE.5):
# "N of N CAUGHT" is a claim about the SET, not about any single check.  A
# mutant can be killed by a neighbouring assertion while the check advertised
# as pinning that behaviour passes right through it.  So this stand prints the
# failing assertion of every mutant and the reader is expected to check that
# the case which DIED is the one the mutant was aimed at.  M9 is the range
# control: it must SURVIVE, or the stand is measuring "any edit reddens".
#
# Usage: bash tools/agent/mutstand_roshan_pit_daynight.sh
set -u
cd "$(dirname "$0")/../.."

TEST=test_roshan_pit_daynight.lua
JMZ=bots/FunLib/jmz_func.lua
UTILS=bots/FunLib/utils.lua
FARM=bots/mode_farm_generic.lua
FILES=("$JMZ" "$UTILS" "$FARM")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_roshpit.XXXXXX")
for f in "${FILES[@]}"; do cp "$f" "$WORK/$(basename "$f").orig"; done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do cp "$WORK/$(basename "$f").orig" "$f"; done
    sha256sum -c "$WORK/sum.txt" > /dev/null || {
        echo "RESTORE FAILED -- a source file does not match its pre-mutation checksum"; exit 2; }
}

# An interrupted stand otherwise leaves the MUTANT in the working tree, where
# the next `git add -A` commits it (GH #418 is that exact accident).
trap restore EXIT

apply_mutant() {   # $1 = mutant id
    MUT="$1" python3 - <<'PY'
import os, sys

JMZ = "bots/FunLib/jmz_func.lua"
UTILS = "bots/FunLib/utils.lua"
FARM = "bots/mode_farm_generic.lua"

# (file, needle, replacement) -- the needle must be present exactly once.
ARMED_BLOCK = """		if bDay
		then
			return J.Utils.RadiantRoshanLoc
		else
			return J.Utils.DireRoshanLoc
		end"""
SHIPPED_BLOCK = """	if bDay
	then
		return J.Utils.DireRoshanLoc
	else
		return J.Utils.RadiantRoshanLoc
	end"""
GATE = "J.RoshanPitForTimeOfDay( J.IsModeTurbo() and J.IsSoakCandidate('roshpit') )"
PHASE = "\tlocal bDay = J.CheckTimeOfDay() == 'day'"

MUTANTS = {
    # M1 -- the candidate becomes a no-op: the armed leg answers the shipped
    #       pit.  Aimed at [flip] and [worker].
    "M1": (JMZ, ARMED_BLOCK, ARMED_BLOCK
           .replace("RadiantRoshanLoc", "TMP").replace("DireRoshanLoc", "RadiantRoshanLoc")
           .replace("TMP", "DireRoshanLoc")),
    # M2 -- the gate stops being turbo-only.  Aimed at [turbo-only] and [gate].
    "M2": (JMZ, GATE, "J.RoshanPitForTimeOfDay( J.IsSoakCandidate('roshpit') )"),
    # M3 -- the gate is gone: the fix ships live.  Aimed at [off-candidate],
    #       [corpus] and [gate].
    "M3": (JMZ, GATE, "J.RoshanPitForTimeOfDay( true )"),
    # M4 -- the shipped leg is flipped instead of the armed one, i.e. the
    #       ungated constant swap §FK.3 refused.  Aimed at [off-candidate].
    "M4": (JMZ, SHIPPED_BLOCK, SHIPPED_BLOCK
           .replace("DireRoshanLoc", "TMP").replace("RadiantRoshanLoc", "DireRoshanLoc")
           .replace("TMP", "RadiantRoshanLoc")),
    # M5 -- a pit constant moves 2000u.  Aimed at [premise]: the "7889.6u apart,
    #       so this is not rounding" argument must be measured, not quoted.
    "M5": (UTILS, "____exports.DireRoshanLoc = Vector(2980, -2816, 1107)",
           "____exports.DireRoshanLoc = Vector(4980, -2816, 1107)"),
    # M6 -- the armed leg gets its phase from the engine while the shipped leg
    #       keeps the modulo: the OTHER lever riding in on this one.  Aimed at
    #       [coupling].
    "M6": (JMZ, PHASE, "\tlocal bDay = ( GetTimeOfDay() >= 0.25 and GetTimeOfDay() < 0.75 )"),
    # M7 -- the gate is read a second time, inside the worker.  Aimed at [gate]
    #       ("resolved in exactly one place").
    "M7": (JMZ, "\tlocal bDay = J.CheckTimeOfDay() == 'day'",
           "\tlocal bDay = J.CheckTimeOfDay() == 'day'\n"
           "\tif J.IsSoakCandidate('roshpit') then bArmed = true end"),
    # M8 -- a second file makes its own pit choice, naming one constant.  Aimed
    #       at [call sites]: this is the shape that would survive a promote.
    "M8": (FARM, "local nInRangeAlly_roshan = J.GetAlliesNearLoc(J.GetCurrentRoshanLocation(), 1200)",
           "local nInRangeAlly_roshan = J.GetAlliesNearLoc(J.Utils.RadiantRoshanLoc, 1200)"),
    # M9 -- RANGE CONTROL.  A comment-only edit inside the worker.  It must
    #       SURVIVE; if it dies, this stand measures "any edit reddens" and
    #       none of the CAUGHT readings above mean anything.
    "M9": (JMZ, "	-- 7.41: Roshan's pit preference switched (day/night swap)\n	-- Kept as an if/else",
           "	-- 7.41: Roshan pit preference (day/night swap) -- see GH #450\n	-- Kept as an if/else"),
}

mut = os.environ["MUT"]
path, needle, repl = MUTANTS[mut]
src = open(path, encoding="utf-8").read()
n = src.count(needle)
if n != 1:
    sys.stderr.write("ABORT %s: target appears %d time(s) in %s, expected 1\n" % (mut, n, path))
    sys.exit(3)
open(path, "w", encoding="utf-8").write(src.replace(needle, repl, 1))
PY
}

run_test() {   # writes the runner log to $WORK/out.txt, returns the BARE code
    lua5.1 tests/run_tests.lua "$TEST" > "$WORK/out.txt" 2>&1
    return $?
}

restore
run_test
BASE=$?
echo "baseline: exit $BASE :: $(grep -E '^[0-9]+ tests' "$WORK/out.txt" || true)"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE IS RED -- every mutant below would score CAUGHT for the wrong reason."
    exit 2
fi

CAUGHT=0; SURVIVED=0; ABORTED=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9; do
    restore
    if ! apply_mutant "$m"; then
        echo "$m  ABORTED (target string absent -- nothing was on the bench)"
        ABORTED=$((ABORTED + 1))
        continue
    fi
    run_test
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "$m  CAUGHT (exit $rc)"
        # EVERY dead case, not the first three: §EE.5 asks the reader to check
        # that the case the mutant was AIMED at is among them, and a truncated
        # list is exactly how a neighbour's kill gets read as the aimed one's.
        grep -E '^FAIL' "$WORK/out.txt" | sed 's/^/      /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$m  SURVIVED (exit 0)"
        SURVIVED=$((SURVIVED + 1))
    fi
done

restore
run_test
echo "baseline after restore: exit $? :: $(grep -E '^[0-9]+ tests' "$WORK/out.txt" || true)"
echo "CAUGHT=$CAUGHT SURVIVED=$SURVIVED ABORTED=$ABORTED  (M9 is the range control and MUST survive)"
