#!/usr/bin/env bash
# Mutation stand for the `text_absent` done_when kind of the OWED_EXECUTION leg
# (tools/agent/pending_rulings.py, director 2026-09-05 §EV / GH #523, landed
# 2026-09-08), as defended by tests/test_pending_rulings.py.
#
# What the defended claim IS, stated so a mutant can break it: a row whose
# ruling says "that sentence is wrong, take it out" reads OWED while any of the
# quoted sentences is still in the file, DONE only when the file is STILL THERE
# and none of them are, and UNCERTIFIABLE whenever the file cannot be read.
#
# ⭐ EVERY MUTANT BELOW IS IN THE FALSE-POSITIVE DIRECTION -- each one makes the
# leg read DONE at a row that is not executed.  That is deliberate and is the
# acceptance sentence this stand was asked for: the failure that costs
# something here is a retired row with the wrong sentence still shipped, not a
# noisy refusal.  A stand made of happy-path mutants would be green in exactly
# the tree this kind exists to catch.  The one that matters most is M1: absent
# and deleted are the same reading of "the text is not in what I read", and
# `path_absent` already owns the second one.
#
# RESTORE IS FROM A FILE COPY AND IS VERIFIED WITH `git diff`, not with a
# checksum of the stand's own backup: a hash round-trip only proves the backup
# is self-consistent, and stays green when the backup was taken from an ALREADY
# MUTATED file.  `git diff --quiet` compares against the index, so it catches
# that too, and it can only err in the noisy direction.
# ⚠ It compares against the INDEX, so running this stand on unstaged edits to
# $SRC makes the final RESTORE line read NO even after a byte-perfect restore.
# Stage the file (or run it on a clean tree) before trusting that line.
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
# for everything.  A pure comment edit must NOT be caught: if it is, the test is
# reading prose as code and every CAUGHT below is worthless.
control() {
    restore
    perl -0pi -e 's/# GH #523, director 2026-09-05 \(test_set\.md/# GH #523 (control edit), director 2026-09-05 (test_set.md/' "$SRC"
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

# M1 -- THE false positive of this kind.  Drop the existence precondition and a
# DELETED artefact reads DONE: every needle is absent from a file that is not
# there.  §EV called this out before a line was written, so a stand that does
# not carry it is not defending the thing that was designed.
mutate "M1 deleted artefact reads DONE (existence precondition dropped)" \
    's/        if not os\.path\.exists\(full\):\n            return \("UNCERTIFIABLE",\n                    "%s does not exist/        if False:\n            return ("UNCERTIFIABLE",\n                    "%s does not exist/'

# M2 -- the unreadable-file refusal, reached through the other door (the path
# exists and the read raises).  Answering DONE there is the same lie as M1 with
# a different cause.
mutate "M2 unreadable file reads DONE instead of refusing" \
    's/            return \("UNCERTIFIABLE",\n                    "%s could not be read \(%s\)" % \(rel, exc\)\)/            return ("DONE",\n                    "%s could not be read (%s)" % (rel, exc))/'

# M3 -- the empty-needle refusal.  A needle set nobody wrote is absent from
# every file in the repo, so the row would go DONE on any path at all -- the
# pre-#523 defect wearing the new kind's name.
mutate "M3 empty needle set passes on any file at all" \
    's/        if not needles or not all\(isinstance\(n, str\) and n for n in needles\):/        if False:/'

# M4 -- the substring check itself.  With `present` forced empty the sentence
# the ruling asked to be deleted is still shipped and the row reads DONE, which
# is precisely the state the field was invented to make visible.
mutate "M4 the wrong sentence is still there and the row reads DONE" \
    's/        present = \[n for n in needles if n in text\]/        present = []/'

# M5 -- a HALF-DONE edit.  Check only the first needle and a row that asked for
# two sentences to go retires with the second one still in the file.  This is
# the mutant closest to a plausible bug: it is green on every single-needle row
# in the registry.
mutate "M5 only the first needle is checked (half-done edit retires)" \
    's/        present = \[n for n in needles if n in text\]/        present = [n for n in needles[:1] if n in text]/'

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
