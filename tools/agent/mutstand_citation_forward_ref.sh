#!/usr/bin/env bash
# Mutation stand for the FORWARD-REF path class of the citation audit
# (tools/agent/citation_audit.py, GH #523 second item / director 2026-09-05
# §9b), as defended by tests/test_citation_audit_forward_ref.py.
#
# What the defended claim IS, stated so a mutant can break it: a cited path is
# forgiven ONLY when it is byte-equal to the `done_when.path` of a LIVE row of
# kind `path_exists` in TRUNK's `iterations/owed_executions.json`, it does not
# already resolve on trunk, and the forgiveness is PRINTED with the row that
# earns it.
#
# ⭐ EVERY MUTANT BELOW IS IN THE FALSE-POSITIVE DIRECTION -- each one makes the
# audit forgive an absence it should have reported, or forgive it silently.
# That is deliberate: this class exists to stop a stable false positive, and
# the way such a fix goes wrong is by forgiving too much, not by refusing too
# much.  A stand made of happy-path mutants would be green in exactly the tree
# this class could damage.  The one that matters most is M5: a silent amnesty
# and a correct one have the same exit code, so only the printout separates
# them -- and nothing about the exit code would notice M5 at all.
#
# RESTORE IS FROM A FILE COPY AND IS VERIFIED WITH `git diff`, not with a
# checksum of the stand's own backup: a hash round-trip only proves the backup
# is self-consistent, and stays green when the backup was taken from an ALREADY
# MUTATED file.  `git diff --quiet` compares against the index, so it catches
# that too, and it can only err in the noisy direction.
# ⚠ It compares against the INDEX, so running this stand on unstaged edits to
# $SRC makes the final RESTORE line read NO even after a byte-perfect restore.
# Stage the file (or run it on a clean tree) before trusting that line.
# ⚠ `__pycache__` is cleared around every run: a mutant and its restore can be
# the same byte length in the same second, and the .pyc staleness rule is
# (source mtime truncated to seconds, source size) -- which would load the
# MUTATED bytecode after a byte-perfect restore.  Measured on RULING 62.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

SRC='tools/agent/citation_audit.py'
BAK="$(mktemp)"

cp "$SRC" "$BAK" || exit 2

drop_pyc() { rm -rf tools/agent/__pycache__ tests/__pycache__; }

# `restore` is defined BEFORE the trap that calls it, and the trap calls it by
# NAME rather than repeating the `cp` inline -- the shape
# tests/test_mutstand_restore_trap.py exists to require (GH #418).
restore() { cp "$BAK" "$SRC"; drop_pyc; }

trap 'restore 2>/dev/null; rm -f "$BAK"' EXIT

run_test() {
    drop_pyc
    python3 tests/test_citation_audit_forward_ref.py >/dev/null 2>&1
    echo $?
}

caught=0; survived=0; ctrl_ok=0

# The CONTROL runs FIRST, so a stand that is simply broken cannot print CAUGHT
# for everything.  A pure comment edit must NOT be caught: if it is, the test is
# reading prose as code and every CAUGHT below is worthless.
control() {
    restore
    perl -0pi -e 's/# GH #523 second item \(director 09-05 §9b\): the acceptance artifact of a/# GH #523 second item (control edit, director 09-05 §9b): the acceptance artifact of a/' "$SRC"
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

# M1 -- drop the kind scope.  Every `done_when.path` in the registry then
# forgives, including the kinds that REQUIRE their path to be there
# (`text_absent` reads the file it names).  This is the widest false positive
# available and the one a reader would most likely write by mistake.
mutate "M1 any done_when.path forgives, not just kind=path_exists" \
    's/        if not isinstance\(done_when, dict\) or done_when\.get\("kind"\) != "path_exists":/        if not isinstance(done_when, dict):/'

# M2 -- include retired rows.  After retirement the artifact is supposed to
# exist, so forgiving it hides exactly the regression the registry retires on:
# a row signed off whose deliverable never landed.
mutate "M2 retired rows keep forgiving their artifact" \
    's/    for row in registry\.get\("owed"\) or \[\]:/    for row in (registry.get("owed") or []) + (registry.get("retired") or []):/'

# M3 -- read the registry from the WORKING TREE instead of trunk.  Then a row
# that exists only in this container forgives a path only this container knows
# about, which is the guard `ignore_rules_certifiable` provides for the sibling
# class -- here it is bought by reading trunk, so it is invisible once lost.
mutate "M3 registry read from the working tree (container-only row forgives)" \
    's/    raw = show\(cwd, trunk_ref, OWED_REGISTRY\)\n    if raw is None:\n        return \{\}/    try:\n        raw = open(os.path.join(cwd, OWED_REGISTRY), encoding="utf-8").read()\n    except OSError:\n        return {}/'

# M4 -- ask the registry BEFORE asking trunk.  A path that is genuinely on
# trunk then reads FORWARD-REF, so a resolved citation gets reported as an
# absence-by-construction: the class starts lying about paths it should never
# have been consulted for.
mutate "M4 registry consulted before trunk (a tracked path reads FORWARD-REF)" \
    's/def resolve_path\(cwd, path, trunk_ref, refs, ignore_ok=False, forward=None\):\n    if git_ok\(\["cat-file", "-e", "%s:%s" % \(trunk_ref, path\)\], cwd\):\n        return "OK", trunk_ref/def resolve_path(cwd, path, trunk_ref, refs, ignore_ok=False, forward=None):\n    if forward and path in forward:\n        return "FORWARD-REF", forward[path]\n    if git_ok(["cat-file", "-e", "%s:%s" % (trunk_ref, path)], cwd):\n        return "OK", trunk_ref/'

# M5 -- THE silent amnesty.  Stop printing the forgiven paths and every exit
# code in the suite is unchanged; the only thing lost is the reader's ability
# to tell a correct forgiveness from a silent one.  If this survives, the
# printout is decoration and the class has no audit trail.
mutate "M5 forgiveness becomes silent (the FORWARD-REF lines are not printed)" \
    's/        for what, label, row_id in forward_hits:/        for what, label, row_id in []:/'

# M6 -- print the path but not the row.  A weaker M5: the line appears, so the
# class looks audited, while the reader cannot check WHICH row earned it -- and
# checking that is the only way to catch M1 and M2 by eye.
mutate "M6 the printed line no longer names the owed row" \
    's/% \(what, label, row_id, trunk_ref, OWED_REGISTRY\)\)/% (what, label, "", trunk_ref, OWED_REGISTRY))/'

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
