#!/usr/bin/env bash
# Mutation stand for tests/test_domain_scan_pass_pins.py (director 2026-09-08,
# test_set.md §GB) -- the two-way pin between the queue rows that ride the
# archive-scan pass and the needles of
# `iterations/owed_executions.json:hero_domain_scan_2_30_31`.
#
# What the defended claim IS, stated so a mutant can break it: the set of queue
# requests whose `director.owed_row` names that row is EQUAL to the set of
# queue-shaped needles in the row's `done_when.contains`, the row still points
# at the artefact both sides were ruled onto, and neither set is empty.
#
# ⭐ EVERY MUTANT BELOW IS IN THE DIRECTION THAT ACTUALLY HAPPENED, TWICE:
# the pass ends up OWING LESS THAN IT WAS RULED TO OWE, and the owed leg reads
# DONE over readings nobody started.  hero-38/39/40 were ruled onto this pass on
# 09-06T22:xxZ and 09-07T10:xxZ and were never pinned; the round that upgraded
# the row from `path_exists` to `path_contains_all` (hero-36) was the round
# immediately before.  A stand made of happy-path mutants would be green in
# exactly the tree this test exists to catch.  M1 is that drift verbatim.
#
# THE MUTANTS ARE IN THE DATA, NOT IN THE TEST.  The asserted invariant is a
# relation between two registry files, so a mutant that edits the test would
# only prove the test can be deleted.  Both files are restored from copies and
# the restore is proved with `sha256sum -c`.
# ⚠ Run this on a tree where those two JSON files are staged or committed if
# you also want to read `git status` afterwards -- the stand itself only
# promises the bytes back, which is what the checksum line reports.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

QUEUE='iterations/queue.json'
OWEDF='iterations/owed_executions.json'
BAK_Q="$(mktemp)"
BAK_O="$(mktemp)"
SUMS="$(mktemp)"

cp "$QUEUE" "$BAK_Q" || exit 2
cp "$OWEDF" "$BAK_O" || exit 2
sha256sum "$QUEUE" "$OWEDF" > "$SUMS" || exit 2

# `restore` is defined BEFORE the trap that calls it, and the trap calls it by
# NAME (the shape tests/test_mutstand_restore_trap.py requires, GH #418).
restore() { cp "$BAK_Q" "$QUEUE"; cp "$BAK_O" "$OWEDF"; }

trap 'restore 2>/dev/null; rm -f "$BAK_Q" "$BAK_O" "$SUMS"' EXIT

run_test() { python3 tests/test_domain_scan_pass_pins.py >/dev/null 2>&1; echo $?; }

caught=0; survived=0; ctrl_ok=0

# $1 = label, $2 = python program run with `q` (queue dict), `o` (owed dict),
# `row` (the pass's owed row) in scope; it mutates them in place.
mutant() {
    local label="$1"; shift
    restore
    python3 - "$1" <<'PY'
import json, sys
prog = sys.argv[1]
q = json.load(open('iterations/queue.json', encoding='utf-8'))
o = json.load(open('iterations/owed_executions.json', encoding='utf-8'))
row = [r for r in o['owed'] if r.get('id') == 'hero_domain_scan_2_30_31'][0]
exec(prog)
json.dump(q, open('iterations/queue.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
open('iterations/queue.json', 'a', encoding='utf-8').write('\n')
json.dump(o, open('iterations/owed_executions.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
open('iterations/owed_executions.json', 'a', encoding='utf-8').write('\n')
PY
    if sha256sum -c "$SUMS" >/dev/null 2>&1; then
        echo "ANCHOR MISS     : $label -- the mutation did not change either file, so its CAUGHT would be a lie"
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

# The CONTROL runs FIRST, so a stand that is simply broken cannot print CAUGHT
# for everything.  Prose is the whole substance of these two files, and the test
# reads none of it: rewriting a ruling's note must NOT turn the test red.
control() {
    restore
    python3 - <<'PY'
import json
o = json.load(open('iterations/owed_executions.json', encoding='utf-8'))
row = [r for r in o['owed'] if r.get('id') == 'hero_domain_scan_2_30_31'][0]
row['ruling'] = row['ruling'] + " (control edit: prose only, no machine key touched)"
json.dump(o, open('iterations/owed_executions.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
open('iterations/owed_executions.json', 'a', encoding='utf-8').write('\n')
PY
    if sha256sum -c "$SUMS" >/dev/null 2>&1; then
        echo "CONTROL BROKEN  : the control edit did not land"
    else
        local rc; rc="$(run_test)"
        if [ "$rc" = "0" ]; then
            echo "CONTROL ok      : a prose-only edit is NOT caught"; ctrl_ok=1
        else
            echo "CONTROL BROKEN  : a prose-only edit turned the test red -- prose is being read as a machine key"
        fi
    fi
    restore
}

control

# M1 -- THE drift, verbatim: a request ruled onto the pass, no needle for it.
# This is hero-38/39/40's state from 09-06 to this round, and the owed leg read
# DONE the whole time.
mutant "M1 a ruled rider has no needle (hero-40's real state until today)" \
    "row['done_when']['contains'] = [n for n in row['done_when']['contains'] if n != 'hero-40']"

# M2 -- the same hole entered from the queue side: the ruling rides the pass in
# prose while the machine key is gone.  The needle is then an orphan that keeps
# the leg red for a reading no row claims -- the mirror failure, and the reason
# the invariant is an equality rather than an inclusion.
mutant "M2 a needle whose rider dropped its owed_row key" \
    "[r['director'].pop('owed_row') for r in q['requests'] if r.get('id') == 'hero-45']"

# M3 -- the rename.  The row's own ruling says the path is the only machine key
# this leg can read; a rename turns a delivered ruling into an unclaimed new
# row, and nothing else in the tree would say so.
mutant "M3 the artefact is renamed under the row" \
    "row['done_when']['path'] = 'iterations/reports/replay-check/domain_scan_v2.md'"

# M4 -- the rename entering through ONE rider instead: that rider's readings go
# to a file the leg never opens, and its needle is satisfied by a mention in the
# file it abandoned.
mutant "M4 one rider is pointed at a different deliverable" \
    "[r['director'].__setitem__('deliverable', 'iterations/reports/replay-check/somewhere_else.md') for r in q['requests'] if r.get('id') == 'hero-46']"

# M5 -- the vacuous pass.  Empty both sides and the two equalities above agree
# perfectly about nothing; this is the reading that makes the whole file
# meaningless, so it has its own assertion and its own mutant.
mutant "M5 both sides emptied (set() == set() agrees with anything)" \
    "row['done_when']['contains'] = [n for n in row['done_when']['contains'] if not n.startswith('hero-')]
for r in q['requests']:
    if (r.get('director') or {}).get('owed_row'):
        r['director'].pop('owed_row')"

restore
if sha256sum -c "$SUMS" >/dev/null 2>&1; then
    echo "RESTORE         : YES -- both files are byte-identical to the pre-run copies"
else
    echo "RESTORE         : NO -- a file still differs; fix before trusting anything above"
fi

echo "SUMMARY         : $caught CAUGHT / $survived SURVIVED / control_ok=$ctrl_ok"
# Exit 0 only if every mutant was caught AND the control behaved: a stand that
# catches everything including the control proves nothing.
if [ "$survived" = "0" ] && [ "$ctrl_ok" = "1" ]; then exit 0; fi
exit 3
