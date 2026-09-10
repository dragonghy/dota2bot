#!/usr/bin/env bash
# Mutation stand for the measurable-seed disclosure on `comps_better.winrate`
# (director 2026-09-10, GH #696).
#
# WHAT IT IS DEFENDING.  The new fields say that some seeds in the promote
# bar's denominator were CONSTANTS -- their 0.500 is the wr() identity, so
# `x > 0.5` was false for them whatever the arm did.  Every way this can be
# wrong makes the verdict read more like a measurement than it is:
# the exclusion silently doing nothing (M1), the pooled fraction being
# overwritten so the sweep stops being visible (M5), the key vanishing on the
# wave where it matters most (M4), or the stderr line -- the only channel a
# reader who never opens the JSON has -- going quiet (M6).  A disclosure whose
# failure mode is "looks fine" must be shown to redden, not asserted to.
#
# M2 and M3 are the two wrong anchors this was deliberately NOT written with:
# key the exclusion off the winrate VALUE (0.500) instead of its headroom, or
# off the wave-level DEGENERATE flag instead of the per-seed corpus.  Both
# read plausibly and both are wrong in the direction that loses a real seed.
#
# LIMITS, stated rather than implied.  The `winrate_undisclosed_headroom_seeds`
# branch is NOT covered here: no corpus this stand can build produces a row
# with a winrate and no headroom (the script writes both under the same
# `ab_n and ba_n` guard), so a mutant folding that bucket into `measurable`
# would SURVIVE.  It is asserted only by absence in case 1.  Saying so beats
# a CAUGHT count that quietly means less than it looks like.
#
# DISCIPLINE (evidence-discipline rules 1-3; GH #418 restore family):
#   * the pristine copy lives OUTSIDE the temp dir the trap wipes, the trap is
#     armed BEFORE the first mutant, and the run ends on a sha256 manifest;
#   * every mutant is `cmp`-checked, so a no-op edit cannot score as a mutant;
#   * every anchor is asserted UNIQUE before replacing -- a `replace(..., 1)`
#     that silently moves to an earlier duplicate still reports CAUGHT while
#     testing something else (director 2026-09-10, the M1 drift on
#     mutstand_wave_fence_clock.sh);
#   * exit codes are read BARE -- no pipe between the runner and `$?`.
#
# Usage: bash tools/agent/mutstand_verdict_winrate_comps.sh
set -u
cd "$(dirname "$0")/../.."

TOOL=tools/batch_test/soak/recover_verdict.py
PYTEST=tests/test_verdict_winrate_comps.py

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand.XXXXXX")
BAK=$(mktemp -d "${TMPDIR:-/tmp}/mutbak.XXXXXX")     # NOT the dir the trap wipes
cp "$TOOL" "$BAK/tool.orig"
sha256sum "$TOOL" > "$BAK/manifest.sha256"

restore() {
    cp "$BAK/tool.orig" "$TOOL"
    if ! sha256sum -c --quiet "$BAK/manifest.sha256"; then
        printf 'FATAL: restore did not verify -- the tree may hold a mutant\n' >&2
        exit 9
    fi
}
trap 'restore; rm -rf "$WORK"' EXIT
restore                                   # prove the manifest before mutating

caught=0
survived=0

# run_case <name> <expect RED|GREEN> <python-mutator on $TOOL>
run_case() {
    local name="$1" expect="$2" mut="${3:-}"
    restore
    if [ -n "$mut" ]; then
        python3 - "$TOOL" <<PY
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
$mut
open(p, 'w', encoding='utf-8').write(s)
PY
        if [ $? -ne 0 ]; then
            printf '%-8s ABORT: mutator raised -- the anchor moved or is not unique\n' "$name"
            survived=$((survived + 1))
            return 1
        fi
        if cmp -s "$BAK/tool.orig" "$TOOL"; then
            printf '%-8s ABORT: byte-identical file -- the anchor is gone, not the mutant\n' "$name"
            survived=$((survived + 1))
            return 1
        fi
    fi
    python3 "$PYTEST" > "$WORK/$name.out" 2>&1
    local rc=$?                            # bare, no pipe
    local verdict=GREEN
    [ "$rc" -ne 0 ] && verdict=RED
    if [ "$verdict" = "$expect" ]; then
        if [ "$name" = CONTROL ]; then
            printf '%-8s %-5s (expected %-5s) control_ok   %s\n' "$name" "$verdict" \
                "$expect" "$(tail -1 "$WORK/$name.out")"
        else
            caught=$((caught + 1))
            printf '%-8s %-5s (expected %-5s) CAUGHT       %s\n' "$name" "$verdict" \
                "$expect" "$(grep -m1 'FAIL' "$WORK/$name.out" | cut -c1-96)"
        fi
    else
        [ "$name" = CONTROL ] || survived=$((survived + 1))
        printf '%-8s %-5s (expected %-5s) *** SURVIVED ***\n' "$name" "$verdict" "$expect"
        sed 's/^/           /' "$WORK/$name.out"
    fi
}

printf '=== mutation stand: comps_better.winrate measurable disclosure ===\n'
printf 'work %s   backups %s\n\n' "$WORK" "$BAK"

run_case CONTROL GREEN ""

# M1 -- THE EXCLUSION DOES NOTHING.  `measurable` computed over every scored
# seed, so it equals the pooled fraction always.  This is the shape the field
# would have if it had been added as decoration: present, well-named, and
# carrying no information the line above it did not already carry.
run_case M1 RED '
a = """        else:
            meas.append(r["winrate"])"""
assert s.count(a) == 1, "M1 anchor not unique"
s = s.replace(a, """        meas.append(r["winrate"])""", 1)'

# M2 -- WRONG ANCHOR: keyed off the winrate VALUE, not its headroom.  Excludes
# every seed reading 0.500, which throws away a competitive seed that happened
# to land there -- exactly the corpus GH #352 built its own case on.  Reads
# plausibly ("0.500 means no signal") and is wrong.
run_case M2 RED '
a = """        elif r["winrate_headroom"] == 0.0:"""
assert s.count(a) == 1, "M2 anchor not unique"
s = s.replace(a, """        elif r["winrate"] == 0.5:""", 1)'

# M3 -- WRONG ANCHOR: keyed off the WAVE-level channel flag.  A wave whose
# pooled minority share clears 0.20 excludes nothing, even though individual
# seeds inside it swept.  The sweep is a property of a seed corpus; the flag
# is an average over seeds, and an average cannot say which seed was frozen.
run_case M3 RED '
a = """        elif r["winrate_headroom"] == 0.0:"""
assert s.count(a) == 1, "M3 anchor not unique"
s = s.replace(a, """        elif r["winrate_headroom"] == 0.0 and v.get("winrate_channel") == "DEGENERATE":""", 1)'

# M4 -- THE KEY VANISHES WHEN meas IS EMPTY.  The tempting `if meas:` guard.
# An absent key reads as "nothing to report" -- and the wave where nothing is
# measurable is the one wave where that reading is exactly backwards.  This is
# W30 (231/231 dire): the promote bar was 0/4 and unreachable, and the tool
# would say nothing at all.
#
# ⚠️ The stderr reference is rewritten to `.get` IN THE SAME MUTANT, on
# purpose.  The first version guarded only the assignment, and the mutant then
# died of KeyError on the line below before case 3 ever ran: the stand printed
# CAUGHT off a crash while the assertion it names never executed.  A mutant
# that cannot reach the assertion tests the interpreter, not the test.
run_case M4 RED '
a = """    v["comps_better"]["winrate_measurable"] = "%d/%d" % (
        sum(1 for x in meas if x > 0.5), len(meas))"""
assert s.count(a) == 1, "M4 anchor not unique"
s = s.replace(a, """    if meas:
        v["comps_better"]["winrate_measurable"] = "%d/%d" % (
            sum(1 for x in meas if x > 0.5), len(meas))""", 1)
b = """               v["comps_better"]["winrate_measurable"],"""
assert s.count(b) == 1, "M4 second anchor not unique"
s = s.replace(b, """               v["comps_better"].get("winrate_measurable", "n/a"),""", 1)'

# M5 -- PUBLISHED INSTEAD OF BESIDE.  The pooled fraction is overwritten with
# the measurable one.  Every downstream number then looks healthier and the
# sweep -- which is the finding, not the nuisance -- becomes unreadable: the
# gap between the two denominators IS the corpus disclosure.  Same rule the
# headroom field follows twenty lines up, and the same rule this breaks.
run_case M5 RED '
a = """    v["winrate_forced_seeds"] = forced"""
assert s.count(a) == 1, "M5 anchor not unique"
s = s.replace(a, """    v["comps_better"]["winrate"] = v["comps_better"].get("winrate")
    v["winrate_forced_seeds"] = forced""", 1)
b = """        sum(1 for x in meas if x > 0.5), len(meas))"""
assert s.count(b) == 1, "M5 second anchor not unique"
s = s.replace(b, """        sum(1 for x in meas if x > 0.5), len(meas))
    v["comps_better"]["winrate"] = v["comps_better"]["winrate_measurable"]""", 1)'

# M6 -- THE STDERR LINE GOES QUIET.  The JSON still carries both fractions, so
# a reader who opens it is fine; every reader who does not -- which is how the
# six waves in #352 were read -- sees a clean run.  The fields print but the
# disclosure does not reach the only channel that was actually being read.
run_case M6 RED '
a = """    if forced:
        sys.stderr.write("""
assert s.count(a) == 1, "M6 anchor not unique"
s = s.replace(a, """    if False:
        sys.stderr.write(""", 1)'

printf '\n%d CAUGHT / %d SURVIVED\n' "$caught" "$survived"
[ "$survived" -eq 0 ] || exit 3
