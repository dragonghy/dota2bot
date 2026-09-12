#!/usr/bin/env bash
# Mutation stand for the `unmet_at_ruling` witness of the OWED_EXECUTION leg
# (tools/agent/pending_rulings.py, director 2026-09-12, LIMIT 14), as defended
# by tests/test_pending_rulings.py.
#
# What the defended claim IS, stated so a mutant can break it: a row whose
# machine key is satisfied and which carries NO readable witness must read
# BORN-DONE, must be a finding, and must NOT print "the director should retire
# this row" -- while the same row WITH a witness must go back to DONE, level 0,
# retire line printed.  Both halves are load-bearing: without the first the
# leg vouches for a reading it has never seen change (7 live rows were doing
# exactly that when this landed), and without the second the guard is just a
# way of never retiring anything, and the next director deletes it.
#
# WHY A STAND AND NOT JUST THE TEST.  Every way this guard can be wrong makes
# it print a CLEANER answer -- fewer findings, exit 0, "retire me" back under
# a row nobody has read.  A guard whose failure mode is silence has to be
# shown to redden, not asserted to.
#
# RESTORE IS FROM A FILE COPY AND IS VERIFIED WITH `git diff` against the
# index, not with a checksum of the stand's own backup: a hash round-trip only
# proves the backup is self-consistent, and stays green when the backup was
# taken from an ALREADY MUTATED file (GH #418 family).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

SRC='tools/agent/pending_rulings.py'
BAK="$(mktemp)"

cp "$SRC" "$BAK" || exit 2

# TWO restore verdicts, because neither one alone is both decisive and quiet,
# and the sibling stands carry only the second:
#   * START_SHA is what the file looked like when this stand started, so the
#     end-of-run comparison answers the question the stand OWES an answer to --
#     "is the tree holding a mutant" -- whatever the index says;
#   * `git diff` against the index is the second opinion that catches a backup
#     taken from an ALREADY MUTATED file, which START_SHA cannot see.
# On a tree with UNCOMMITTED work on $SRC the second one says NO and means
# nothing by it.  Measured 2026-09-12: this stand's first run printed exactly
# that at a perfectly restored file, because the guard it defends was itself
# still uncommitted.  So the sha decides the exit code and git only advises.
START_SHA="$(sha256sum "$SRC" | cut -d' ' -f1)"

# `restore` is defined BEFORE the trap that calls it, and the trap calls it by
# NAME rather than repeating the `cp` inline -- the shape
# tests/test_mutstand_restore_trap.py exists to require.
restore() { cp "$BAK" "$SRC"; }

trap 'restore 2>/dev/null; rm -f "$BAK"' EXIT

run_test() { python3 tests/test_pending_rulings.py >/dev/null 2>&1; echo $?; }

caught=0; survived=0; ctrl_ok=0

# The CONTROL runs FIRST, so a stand that is simply broken cannot print CAUGHT
# for everything.  A pure comment edit must NOT be caught: if it is, the test
# is reading prose as code and every CAUGHT below is worthless.
control() {
    restore
    perl -0pi -e 's/# LIMIT 14\./# LIMIT 14. (control edit)/' "$SRC"
    if ! git diff --quiet -- "$SRC"; then
        local rc; rc="$(run_test)"
        if [ "$rc" = "0" ]; then
            echo "CONTROL ok      : a pure comment edit is NOT caught"; ctrl_ok=1
        else
            echo "CONTROL BROKEN  : a comment-only edit turned the test red -- prose is being read as code"
        fi
    else
        echo "CONTROL BROKEN  : the control edit did not land (anchor missing)"
    fi
    restore
}

# $1 = label, $2 = perl program
mutate() {
    local label="$1"; shift
    restore
    perl -0pi -e "$1" "$SRC"
    if git diff --quiet -- "$SRC"; then
        echo "ANCHOR MISS     : $label -- the mutation did not land, so its CAUGHT would be a lie"
        survived=$((survived + 1))
        restore
        return
    fi
    local rc; rc="$(run_test)"
    if [ "$rc" != "0" ]; then
        echo "CAUGHT          : $label"; caught=$((caught + 1))
    else
        echo "SURVIVED        : $label"; survived=$((survived + 1))
    fi
    restore
}

control

# M1 -- the overlay itself.  Skip it and the tree is back to 2026-09-12
# morning: seven rows reading DONE with "retire me" under them, one of which
# had a criterion that was true the minute it was written.
mutate "M1 witness overlay skipped (leg reverts to unconditional DONE)" \
    's/        if state == "DONE":\n            return _witness_overlay\(row, detail\)\n/        if False:\n            return _witness_overlay(row, detail)\n/'

# M2 -- the missing-witness branch.  Reading DONE when nothing was recorded is
# the entire defect: it is the state that cannot be told from a real one.
mutate "M2 a missing witness reads DONE instead of BORN-DONE" \
    's/        return \("BORN-DONE",\n                "%s -- and no `%s` is recorded/        return ("DONE",\n                "%s -- and no `%s` is recorded/'

# M3 -- the REFUSAL on an unreadable witness.  `unmet_at_ruling: true` is the
# shape a hurried author writes; falling through restores "retire me" at a row
# whose author was trying to say the opposite (the `residual` rule, verbatim).
mutate "M3 unreadable witness falls through instead of refusing" \
    's/        return \("UNCERTIFIABLE",\n                "%s -- and this row\x27s `%s` is not a non-empty string \(%r\)"/        return ("DONE",\n                "%s -- and this row\x27s `%s` is not a non-empty string (%r)"/'

# M4 -- the shape check.  Accept any non-empty string and "yes" buys a
# retirement; the field then records that somebody typed, not that somebody
# read.  (Both halves of `_witness_problems` are covered: the test feeds a bare
# promise AND the house style's fuzzed `T22:xxZ` stamp.)
mutate "M4 witness shape unchecked (any non-empty string passes)" \
    's/    problems = _witness_problems\(text\)\n    if problems:/    problems = []\n    if problems:/'

# M4b -- only the OWED half of the shape check.  A fuzzed stamp is prose, not a
# time, and this is the half that a reader would most plausibly call pedantic.
mutate "M4b witness accepts a fuzzed stamp (UTC instant no longer required)" \
    's/    if not any\(parse_utc\(tok\.strip\("\(\)\[\],;"\)\) for tok in text\.split\(\)\):/    if False:/'

# M5 -- the arrow line, which is the half a human acts on.  Print the retire
# sentence for BORN-DONE too and the new state is decoration.
mutate "M5 BORN-DONE rows print the retire line again" \
    's/            print\("      -> the key reads satisfied and was NEVER WITNESSED "/            print("      -> executed; the director should retire this row" + " "/'

# M6 -- the finding.  A BORN-DONE row that does not raise the exit level is
# reported in a section nobody is required to act on.
# NOTE the anchor is the `finding = True` line itself, not the `elif` above it:
# an inserted `finding = False` would be overwritten by the surviving
# assignment and SURVIVE as a no-op mutant (the trap mutstand_owed_residual.sh
# documents at its own M5).
mutate "M6 BORN-DONE stops being a finding (exit level unchanged)" \
    's/            finding = True\n            print\("      -> the key reads satisfied/            print("      -> the key reads satisfied/'

# M7 -- the DONE precondition.  Grading a row whose key is UNMET replaces the
# sharper sentence ("the file is not there") with a vaguer one, and a
# never-started row starts to look like a finished one.
mutate "M7 witness graded even when the machine key is unmet" \
    's/        if state == "DONE":\n            return _witness_overlay\(row, detail\)\n        return state, detail/        return _witness_overlay(row, detail)/'

# M8 -- the witnessed path.  If a good witness does not restore DONE, nothing
# can ever be retired, the registry becomes wallpaper (GH #276), and the next
# director's cheapest move is to delete the guard.
mutate "M8 a witnessed row can no longer reach DONE" \
    's/    return \("DONE",\n            "%s -- and the key was witnessed UNMET at ruling time: %s"/    return ("BORN-DONE",\n            "%s -- and the key was witnessed UNMET at ruling time: %s"/'

restore
restored_ok=0
if [ "$(sha256sum "$SRC" | cut -d' ' -f1)" = "$START_SHA" ]; then
    echo "RESTORE         : YES -- $SRC is byte-identical to what this stand started from"
    restored_ok=1
else
    echo "RESTORE         : FATAL -- $SRC does NOT match its pre-run sha; the tree may hold a mutant"
fi
if git diff --quiet -- "$SRC"; then
    echo "INDEX           : clean (and so the sha above was taken from committed content)"
else
    echo "INDEX           : $SRC differs from the index -- expected while the guard itself is uncommitted; it does NOT mean the restore failed"
fi

echo "SUMMARY         : $caught CAUGHT / $survived SURVIVED / control_ok=$ctrl_ok restored=$restored_ok"
# Exit 0 only if every mutant was caught AND the control behaved AND the tree
# came back: a stand that catches everything including the control proves
# nothing, and one that leaves a mutant behind has done damage, not work.
if [ "$survived" = "0" ] && [ "$ctrl_ok" = "1" ] && [ "$restored_ok" = "1" ]; then exit 0; fi
exit 3
