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
#   * ACCUSE (M13, M16) / MISS (M11, M12, M15, M17, M18) carry the same split
#     into the RULING 67 and RULING 75 cells; M19 moves no exit code either.
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
    's/entry_text\[chosen\.start\(\):\]/entry_text/'

# M5 (MISS) -- the anti-empty-match floor.  With it gone, a charter whose carry
# list names no issue at all prints a clean exit 0 -- indistinguishable from
# "every carried ref is open", which is the failure this repo has already had
# six times (#29 #31 #34 #37 #95 #103).
# ⚠ The anchor carries the `and handoff_gap is None` tail on purpose.  RULING 67
# added a SECOND `if total == 0:` (the 8-space disclosure branch inside the
# findings block), and `perl -0p s///` replaces the FIRST match in the slurped
# file -- so the short anchor silently started mutating the other line, which no
# claim asserts, and M5 printed SURVIVED while the guard it names was untouched.
# A mutant that lands somewhere else is not a weak assertion; it is a stand
# reading the wrong line (evidence-discipline rule 2, caught on this stand).
mutate "M5 zero extracted refs exits 0 instead of 2" \
    's/    if total == 0 and handoff_gap is None:/    if False:/'

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
    's/    chosen = anchors\[-1\]/    chosen = hits[0]/'

# --- RULING 67 (2026-09-16T19:0xZ): NO-HANDOFF + fallback -------------------
# M11 (MISS) -- the dropped baton is demoted back to UNCERTIFIABLE.  Nothing
# else changes: the same three true lines print, and they add up to "nothing to
# check here" while the previous round's list is unguarded.  This is the mutant
# that reproduces the incident itself.
mutate "M11 a missing carry list exits 2 (UNCERTIFIABLE) instead of 3" \
    's/    if findings or handoff_gap is not None:/    if findings:/'

# M12 (MISS) -- the fallback never fires, so the live baton is never read.  The
# NO-HANDOFF line goes with it; the leg simply has nothing to say on exactly the
# round where the list stopped being copied forward.
mutate "M12 no fallback to the last entry that carries a list" \
    's/    if carry_segment\(entries\[0\]\[1\]\) is None and not any\(/    if False and not any(/'

# M13 (ACCUSE) -- the fallback fires even when the newest entry DOES carry a
# list.  Claim 6 dies: a superseded list comes back into scope and its long-dead
# names are reported as live carried work.  The premise of the fallback is that
# nothing superseded the old list; drop the premise and it is just firing at
# history.
mutate "M13 the fallback fires even when the newest entry has a list" \
    's/    if carry_segment\(entries\[0\]\[1\]\) is None and not any\(/    if True or not any(/'

# M14 (NO EXIT CODE MOVES) -- the fallback distance loses its age when the stamp
# is fuzzy (`T10:1xZ`, which this charter writes about half the time).  Every rc
# is unchanged; what is lost is the difference between "fell back one entry" and
# "fell back thirty hours", printed identically.  Same shape as M6.
mutate "M14 an uncomputable fallback age prints as nothing" \
    's/age = ", age not computable \(fuzzy stamp\)"/age = ""/'

# --- RULING 75 (2026-09-18): the segment is anchored on the LIST -------------
# M15 (MISS) -- the incident itself, reproduced.  Drop the anchor test and the
# segment is the LAST『下次触发』again, so a mention that comes AFTER the list
# truncates it away.  On entry 2026-09-18T01:15Z that printed `1 carry
# segment(s), 0 GH ref(s)` + exit 2 while 8 refs sat unread three lines above --
# and exit 2 is this leg's own word for "nobody could look, it fixes itself next
# round", which this one does not.
mutate "M15 the segment is the last mention again, not the list anchor" \
    's/    anchors = \[h for h in hits if is_list_mark\(entry_text, h\.start\(\)\)\]/    anchors = list(hits)/'

# M16 (ACCUSE) -- the rule that was tried FIRST and refuted by the corpus:
# "the latest mention that yields refs".  It walks back past a list that carries
# no `GH #` (real entry 2026-09-11T04:19Z) into a narrative quote, and reports
# refs nobody ever carried.  It is the mutant a careful author writes, which is
# why it is here rather than in a comment.
mutate "M16 the anchor is 'the latest mention that yields refs'" \
    's/    anchors = \[h for h in hits if is_list_mark\(entry_text, h\.start\(\)\)\]/    anchors = [h for h in hits if refs_in(entry_text[h.start():])]/'

# M17 (MISS) -- half the anchor: bold only, colon dropped.  ⚠ On the charter as
# it stands this changes NO real answer (measured: 94 entries, 0 disagreements),
# so it is caught by a fixture, not by the corpus -- a BOLDED colon-less prose
# tail (`⚠️ **这一条也进下次触发 ⑭**。`), which this charter writes the
# ingredients of on every line.
mutate "M17 anchor loses the colon condition (bold alone)" \
    's/    tail = line\[off \+ len\(u".*"\)\:\]/    tail = ":"/'

# M18 (MISS) -- the other half: colon only, bold dropped.  Also invisible on the
# current corpus; caught by the unbolded prose tail whose line happens to end in
# a colon (`… ⇒ 进下次触发 ⑭。`claim_precheck.sh` 复跑:resolved 8 → 11`).
mutate "M18 anchor loses the bold condition (colon alone)" \
    's/    if line\[:off\]\.count\("\*\*"\) % 2 == 0:\n        return False/    if False:\n        return False/'

# M19 (MISS) -- the prose-only branch stops naming itself.  No exit code moves
# anywhere: what is lost is that the registered hole `carry_mark_prose_vs_list`
# goes back to being unobservable, which is the whole reason it sat OWED with
# both of its candidate anchors refuted and nothing measuring how often it fires.
mutate "M19 the prose-only fallback prints nothing" \
    's/        if kind == "prose-fallback":/        if False:/'

# --- RULING 76 (claim 12): the refresh set must not become a second hand-copy -
# ⚠ ASCII anchors only.  `perl -0pi` matches BYTES, so a CJK anchor written as
# \N{U+...} never lands and the stand would print ANCHOR MISS (M17's lesson,
# and the reason that guard exists at all).

# M20 (MISS) -- the divergence itself: the refresh set stops being what the
# audit leg reads.  This is the incident in one line -- the refreshing round
# fetches a SUBSET, and every number it drops reads back `not in corpus`
# forever while looking like an environment problem.
mutate "M20 refresh set takes only the first ref of each entry" \
    's/        for n in refs_in\(seg\):\n            if n not in from_entry:/        for n in refs_in(seg)[:1]:\n            if n not in from_entry:/'

# M21 (MISS) -- the to-fetch list stops being populated.  REFRESH-SET still
# prints, so the mode looks like it works; what is lost is the one line that
# says WHICH numbers the corpus is missing -- i.e. exactly the signal whose
# absence let `#548` sit unfetched for five rounds.
mutate "M21 nothing is ever reported as missing from the corpus" \
    's/        if missing_here:\n            missing.append\(n\)/        if False:\n            missing.append(n)/'

# M22 (MISS) -- anti-empty-match, same rule as claim 5: "nothing to refresh"
# and "the extractor matched nothing" print the same clean 0.
mutate "M22 an empty refresh set exits 0" \
    's/                   "\(anti-empty-match\)"\)\n        return 2, out/                   "(anti-empty-match)")\n        return 0, out/'

# M23 (MISS) -- the printed recipe drops the method.  The tool then repeats the
# old epilog's mistake: a refreshing round is told nothing about point-query vs
# list_issues, and RULING 55 says the list read lags by minutes.
# ⚠ The first version of M23 anchored on the CJK marker written as \x{26d4} and
# printed ANCHOR MISS -- perl read the brace as a literal and never matched.
# The anchor below is pure ASCII and lands on the FIRST occurrence, which is the
# printed recipe (line ~452); the epilog's copy sits later in the file.
mutate "M23 the printed recipe stops naming issue_read" \
    's/issue_read\(method=get\)/issue_seen(method=get)/'

# M24 (MISS) -- an unusable corpus makes everything read as already-known, so
# the set to fetch collapses to empty exactly when the corpus most needs
# repair.  The REFRESH-SET line still prints, which is what makes it quiet.
mutate "M24 an unusable corpus marks every ref as not-missing" \
    's/            state, missing_here = "corpus unusable", True/            state, missing_here = "corpus unusable", False/'

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
