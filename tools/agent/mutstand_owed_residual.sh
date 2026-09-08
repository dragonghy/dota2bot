#!/usr/bin/env bash
# Mutation stand for the `residual` field of the OWED_EXECUTION leg
# (tools/agent/pending_rulings.py, director 2026-09-08, GH #627, LIMIT 13),
# as defended by tests/test_pending_rulings.py.
#
# What the defended claim IS, stated so a mutant can break it: a row whose
# machine key is satisfied AND which carries a non-empty `residual` string must
# read RESIDUAL, must be a finding, and must NOT print "the director should
# retire this row" -- that one sentence is the entire defect the field answers
# (it was printed every round at two rows whose own prose said "不许据此退休").
#
# RESTORE IS FROM A FILE COPY AND IS VERIFIED WITH `git diff`, not with a
# checksum of the stand's own backup: a hash round-trip only proves the backup
# is self-consistent, and stays green when the backup was taken from an ALREADY
# MUTATED file. `git diff --quiet` compares against the index, so it catches
# that too, and it can only err in the noisy direction.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

SRC='tools/agent/pending_rulings.py'
BAK="$(mktemp)"

cp "$SRC" "$BAK" || exit 2

# `restore` is defined BEFORE the trap that calls it, and the trap calls it by
# NAME rather than repeating the `cp` inline -- the shape
# tests/test_mutstand_restore_trap.py exists to require (GH #418).
restore() { cp "$BAK" "$SRC"; }

trap 'restore 2>/dev/null; rm -f "$BAK"' EXIT

run_test() { python3 tests/test_pending_rulings.py >/dev/null 2>&1; echo $?; }

caught=0; survived=0; ctrl_ok=0

# The CONTROL runs FIRST, so a stand that is simply broken cannot print CAUGHT
# for everything. A pure comment edit must NOT be caught: if it is, the test is
# reading prose as code and every CAUGHT below is worthless.
control() {
    restore
    perl -0pi -e 's/# LIMIT 13\./# LIMIT 13. (control edit)/' "$SRC"
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

# M1 -- the overlay itself. Ignore `residual` entirely and the leg is back to
# the 2026-09-08 tree: two rows reading DONE with "retire me" under them.
mutate "M1 residual ignored (leg reverts to pre-#627 behaviour)" \
    's/    residual = row\.get\("residual"\)\n    if residual is None:\n        return state, detail\n/    residual = row.get("residual")\n    if True:\n        return state, detail\n/'

# M2 -- the REFUSAL on an unreadable residual. `residual: true` is the shape a
# hurried author would write; silently dropping it restores the retire line at
# a row whose author was trying to say the opposite.
mutate "M2 unreadable residual falls through instead of refusing" \
    's/        return \("UNCERTIFIABLE",\n                "%s -- and this row\x27s `residual` field is not a non-empty "/        return (state,\n                "%s -- and this row\x27s `residual` field is not a non-empty "/'

# M3 -- the DONE precondition. Applying the overlay to an unmet key replaces
# the sharper sentence ("the file is not there") with a vaguer one, and would
# make a never-started row indistinguishable from a nearly-finished one.
mutate "M3 overlay applied even when the machine key is unmet" \
    's/    if state != "DONE":\n        # An unmet key already keeps the row open and already names why\./    if False:\n        # An unmet key already keeps the row open and already names why./'

# M4 -- the arrow line, which is the half a human acts on. Print the retire
# sentence for RESIDUAL too and the state is cosmetic.
mutate "M4 RESIDUAL rows print the retire line again" \
    's/            print\("      -> artefact arrived, but this row is NOT retirable: "/            print("      -> executed; the director should retire this row" + " "/'

# M5 -- the finding. A RESIDUAL row that does not raise the exit level is a
# row the selfcheck reports in a section nobody is required to act on.
# ⚠ The anchor is the `finding = True` line itself, not the `elif` above it:
# the first version of this mutant INSERTED `finding = False` before that line,
# which the surviving `finding = True` then overwrote -- a no-op mutant that
# SURVIVED and would have been read as a hole in the test (evidence discipline
# rule 2: suspect the assertion, and here the assertion was innocent).
mutate "M5 RESIDUAL stops being a finding (exit level unchanged)" \
    's/            finding = True\n            print\("      -> artefact arrived/            print("      -> artefact arrived/'

# M6 -- the machine key's own reading, kept inside the RESIDUAL detail. Drop it
# and the reader loses "the artefact DID arrive", which is true and is half of
# why the row is still open rather than never started.
mutate "M6 RESIDUAL detail drops the key's own reading" \
    's/    return \("RESIDUAL",\n            "%s -- BUT the row records a residual the key cannot see: %s"\n            % \(detail, residual\.strip\(\)\)\)/    return ("RESIDUAL",\n            "the row records a residual the key cannot see: %s"\n            % (residual.strip(),))/'

# M7 -- the residual TEXT. A state with no text is a red light with no label:
# the next director would have to re-derive what survives the key.
mutate "M7 RESIDUAL detail drops the residual text" \
    's/            "%s -- BUT the row records a residual the key cannot see: %s"\n            % \(detail, residual\.strip\(\)\)\)/            "%s -- BUT the row records a residual the key cannot see"\n            % (detail,))/'

restore
if git diff --quiet -- "$SRC"; then
    echo "RESTORE         : YES -- $SRC is byte-identical to the index"
else
    echo "RESTORE         : NO -- $SRC still differs from the index; fix before trusting anything above"
fi

echo "SUMMARY         : $caught CAUGHT / $survived SURVIVED / control_ok=$ctrl_ok"
# Exit 0 only if every mutant was caught AND the control behaved: a stand that
# catches everything including the control proves nothing.
if [ "$survived" = "0" ] && [ "$ctrl_ok" = "1" ]; then exit 0; fi
exit 3
