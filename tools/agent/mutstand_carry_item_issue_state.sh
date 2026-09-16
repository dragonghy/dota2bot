#!/usr/bin/env bash
# Mutation stand for tools/agent/carry_item_issue_state.py (RULING 63 / owed row
# `carry_item_issue_state_crossread`), as defended by
# tests/test_carry_item_issue_state.py.
#
# What the defended claim IS, stated so a mutant can break it: a `GH #<n>` in
# the NEWEST『下次触发』segment is a FINDING iff a fresh issue corpus says that
# number is `closed`; every other corpus answer (absent / unreadable / stale /
# future-dated / unrecognised state) withholds the finding and reads
# UNCERTIFIABLE; and the finding prints the remedy WITHOUT implying the work is
# done.
#
# ⭐ THE MUTANTS SPLIT INTO TWO DIRECTIONS ON PURPOSE, because this leg can go
# wrong both ways and the two costs land on different people:
#   * ACCUSE (M1, M3, M4, M8) -- a todo that is still live gets struck off the
#     list.  This is the RULING 55 failure direction: 「永远凭空造出停摆」, and
#     the cost lands on whoever was relying on that carried item.
#   * MISS (M2, M5, M7) -- the leg goes quiet and the copying resumes, which is
#     just the pre-RULING-63 world with a green tool on top of it.
#   * M6 changes NO exit code anywhere: it makes the finding read as "that work
#     is done", which is the exact mistake #523 is made of.  Only the printed
#     text can catch it -- same shape as M5 of mutstand_citation_forward_ref.sh.
#
# RESTORE IS FROM A FILE COPY AND IS VERIFIED WITH `git diff` against the INDEX,
# not with a checksum of the stand's own backup: a hash round-trip only proves
# the backup is self-consistent, and stays green when the backup was taken from
# an ALREADY MUTATED file.
# ⚠ Because it compares against the index, running this stand on unstaged edits
# to $SRC makes the final RESTORE line read NO even after a byte-perfect
# restore.  Stage the file (or run on a clean tree) before trusting that line.
# ⚠ `__pycache__` is cleared around every run: a mutant and its restore can be
# the same byte length in the same second, and the .pyc staleness rule is
# (source mtime truncated to seconds, source size) -- which would load the
# MUTATED bytecode after a byte-perfect restore.  Measured on RULING 62.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

SRC='tools/agent/carry_item_issue_state.py'
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
    python3 tests/test_carry_item_issue_state.py >/dev/null 2>&1
    echo $?
}

caught=0; survived=0; ctrl_ok=0

# The CONTROL runs FIRST, so a stand that is simply broken cannot print CAUGHT
# for everything.  A pure comment edit must NOT be caught.
control() {
    restore
    perl -0pi -e 's/# 「GH #538 \/ #528」这种链式写法里/# (control edit) 「GH #538 \/ #528」这种链式写法里/' "$SRC"
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

# M1 (ACCUSE) -- drop the freshness guard.  A month-old corpus then answers, and
# an issue REOPENED since the snapshot is reported closed.  Somebody strikes a
# live todo off the list on the strength of this leg.
mutate "M1 stale corpus still answers (freshness guard removed)" \
    's/    if age_h > max_age_hours:/    if False:/'

# M2 (MISS) -- a number the corpus does not carry falls through to `open`.  This
# is RULING 55 upside down: absence from a list read silently becomes a positive
# claim, and every unlisted carried item reads clean forever.
mutate "M2 a ref absent from the corpus reads as open" \
    's/            if st is None:\n                uncertifiable\.append/            if False:\n                uncertifiable.append/'

# M3 (ACCUSE) -- the same absence becomes `closed` instead.  The louder twin of
# M2: every number the snapshot has not caught up with is reported stale.
mutate "M3 a ref absent from the corpus reads as closed" \
    's/    row = issues\.get\(str\(number\)\)\n    if row is None:\n        return None, None/    row = issues.get(str(number))\n    if row is None:\n        return "closed", None/'

# M4 (ACCUSE) -- scope widens from the『下次触发』tail to the whole entry.  Every
# archival `GH #<n>` in the narrative ("族属 GH #290") becomes a finding; the
# leg turns into a stable false positive, which is how a detector stops being
# read at all (GH #276).
mutate "M4 the whole entry is scanned, not just the carry segment" \
    's/    return entry_text\[hits\[-1\]\.start\(\):\]/    return entry_text/'

# M5 (MISS) -- the anti-empty-match floor.  With it gone, a charter whose carry
# list names no issue at all prints a clean exit 0 -- indistinguishable from
# "every carried ref is open", which is the failure this repo has already had
# six times (#29 #31 #34 #37 #95 #103).
mutate "M5 zero extracted refs exits 0 instead of 2" \
    's/    if total == 0:/    if False:/'

# M6 (NO EXIT CODE MOVES) -- the finding stops denying that a closed issue means
# finished work.  Every rc in the suite is unchanged; what is lost is the one
# sentence that keeps this leg from teaching the very mistake it was built for
# (#523 was closed with a real second item still owed inside it).
mutate "M6 the finding no longer denies that closed == done" \
    's/⛔ 这不是说那件事做完了/⛔ 那件事做完了/'

# M7 (MISS) -- chained refs stop counting.  `GH #538 / #528` collapses to one
# number; on the live charter that is exactly how #528 was reachable.  A
# coverage hole that no exit code in the tool itself would ever show.
# (the label carries no backticks on purpose: `mutate` takes it as a double-quoted
#  argument, so a backticked label would be COMMAND SUBSTITUTED before the stand
#  ever sees it -- the first run of this stand printed `/: Is a directory`.)
mutate "M7 chained slash-hash refs are dropped" \
    's/CHAIN_REF_RE = re\.compile\(r"\\s\*\[\/、,,\]\\s\*#\(\\d\+\)"\)/CHAIN_REF_RE = re.compile(r"(?!x)x")/'

# M8 (ACCUSE) -- the opposite widening: every bare `#<n>` counts.  Wave numbers,
# section marks and prose hash marks all become issue refs, and the real
# findings drown in them.
mutate "M8 every bare #<n> is taken as an issue ref" \
    's/GH_REF_RE = re\.compile\(r"GH\\s\*#\(\\d\+\)"\)/GH_REF_RE = re.compile(r"#(\\d+)")/'

# M9 (MISS) -- the entry stamp must be pure digits.  This repo writes the newest
# entry as `T10:1xZ` about half the time, so the newest entry silently drops out
# of the parse and the leg audits the PREVIOUS round's list -- while printing a
# line that looks exactly like a correct one.  Measured, not imagined: it is
# what the first version of this leg did to its own landing round.
mutate "M9 entries with fuzzy minute digits are skipped" \
    's/ENTRY_RE = re\.compile\(r"\^- \\\*\\\*\(\\d\{4\}-\\d\{2\}-\\d\{2\}T\[\\dxX\]\{2\}:\[\\dxX\]\{2\}Z\)\\\*\\\*"\)/ENTRY_RE = re.compile(r"^- \\*\\*(\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}Z)\\*\\*")/'

# M10 (ACCUSE) -- the carry segment starts at the FIRST『下次触发』instead of the
# last.  Any entry whose narrative discusses the list (this one's does) drags its
# whole body into scope, and every archival ref in it becomes a finding.
mutate "M10 the carry segment starts at the first mention, not the last" \
    's/    return entry_text\[hits\[-1\]\.start\(\):\]/    return entry_text[hits[0].start():]/'

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
