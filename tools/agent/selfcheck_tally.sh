# Source-attributed exit code for 开工自检.  Sourced by
# tools/agent/routine_selfcheck.sh; not executable on its own.
#
# WHY THIS EXISTS (GH #267 §4, ruling (b), director 2026-08-28T06:5xZ)
# --------------------------------------------------------------------
# `tests/test_activemode_world_assertion.lua` sat RED on origin/main for ~22
# hours.  Every stream ran the selfcheck in that window, every one of them read
# `selfcheck worst exit: 3`, and every one of them wrote some form of "exit 3,
# all of it cadence" into their report -- because cadence HAD been the only
# source for days.  On 08-27/08-28 that sentence was false, and nothing in the
# output could say so: the wrapper collapsed seven legs into ONE SCALAR.
#
# This is not "a detector nobody ran" (the wrapper's own header) and not "a
# detector that ran on the wrong files" (#267 §4's own framing).  It is one
# level past both: the detector ran, it found the right thing, and THE SUMMARY
# CHANNEL COULD NOT CARRY THE FINDING.  A real red and a long-standing yellow
# were the same integer.
#
# So the attribution is the product here, not the exit code.  `worst` is still
# computed exactly as before and is still what the process exits with -- no
# stream's existing reading changes -- but every note now records WHICH LEG
# raised it, and the tail prints those names.  "All from cadence" becomes a
# reading instead of an inference.
#
# DELIBERATELY LEG NAMES, NOT FINDING COUNTS.  citation_audit prints its own
# `2 finding(s)`; unlanded_commits and the trunk legs do not.  Scraping a count
# out of each leg's prose would make this file depend on seven output formats it
# does not own -- and a count that silently goes stale is the same defect as the
# scalar it replaces.  What every leg DOES report, structurally, is its exit
# code, so that is what is attributed.
#
# THE ATTRIBUTION MUST NOT BE ABLE TO LIE QUIETLY.  If `worst` is 3 while no leg
# is recorded at level 3 (a future leg that raises `worst` by hand, or a `note`
# that outruns its `sc_leg`), the tail says so and keeps the exit code.  A
# breakdown that can disagree with its own total without saying anything is
# exactly the failure this file was written against.

# THE BUCKETS ARE PER-LEG, AND THAT WAS NOT ENOUGH (GH #420, director
# 2026-09-02T22:xxZ).  `_sc_findings` / `_sc_uncertifiable` are keyed on a leg's
# `note` LEVEL, and a leg has exactly one.  A python leg that is BOTH red and
# partly un-run notes 3, so it lands in `FINDINGS` whole -- and the tests inside
# it that never ran have no bucket to be in.  The summary block then prints
# `UNCERTIFIABLE (exit 2): none`, which is true AT LEG GRANULARITY and false at
# the granularity it is read at ("is there anything nobody looked at this
# round?").  Live on 09-02: `75 passed, 1 failed, 2 uncertifiable` in the leg
# body, `UNCERTIFIABLE (exit 2): none` in this block, same run.
#   The wrapper's own exit-1 branch had already been fixed for this exact shape
# ("A run can be BOTH red and un-run ... the exit-1 branch reports the strictly
# worse tree, so it was the branch that named LESS of what was wrong") -- in the
# LEG BODY.  The summary block, which #267 4b built precisely so attribution
# would stop being hand-made, kept the omission one level up.
#   `_sc_unrun` is therefore keyed on FILES, not legs, and is deliberately NOT
# wired into `worst`: #420 asks for visibility, not a re-adjudicated exit code.
_sc_worst=0
_sc_leg='(unattributed)'
_sc_findings=''
_sc_uncertifiable=''
_sc_unrun=''
_sc_unrun_declared=0
_sc_legs=0

# Name the leg about to run.  Every `sc_note` until the next `sc_leg` is
# attributed here.
sc_leg() {
    _sc_leg="$1"
    _sc_legs=$((_sc_legs + 1))
}

# Record one leg's exit level and fold it into `worst`.  Drop-in for the old
# `note`: same argument, same "always return 0" (it is called as `note $?` and
# under `set -e`-less but `set -u` conditions, and must never become the
# statement that ends the script).
sc_note() {
    case "$1" in
        3) _sc_findings=$(_sc_add "$_sc_findings" "$_sc_leg") ;;
        2) _sc_uncertifiable=$(_sc_add "$_sc_uncertifiable" "$_sc_leg") ;;
    esac
    if [ "$1" -gt "$_sc_worst" ]; then _sc_worst="$1"; fi
    return 0
}

# Append a leg name to a list, once.  A leg that notes the same level twice is
# one source, not two.
_sc_add() {
    for seen in $1; do
        if [ "$seen" = "$2" ]; then printf '%s' "$1"; return 0; fi
    done
    if [ -z "$1" ]; then printf '%s' "$2"; else printf '%s %s' "$1" "$2"; fi
}

sc_worst() { printf '%s' "$_sc_worst"; }

# Record file(s) that did not run INSIDE a leg (GH #420).  Space-separated.
# Never touches `worst`: the leg's own `sc_note` already decided the exit code,
# and #420's acceptance says the exit semantics do not move by one word.
sc_unrun() {
    for _u in $1; do
        _sc_unrun=$(_sc_add "$_sc_unrun" "$_u")
    done
    return 0
}

# Read the python leg's un-run files out of the runner's OWN per-file lines
# (`UNCERTIFIABLE  tests/foo.py  (did NOT run -- ...)`, tests/run_py_tests.sh:37).
#
# DELIBERATELY THE PER-FILE LINES, NOT THE ROLL-UP.  run_py_tests.sh also prints
# a machine-readable `uncertifiable: <list>` line -- but only when `fail` is 0
# (its lines 48-55: the `failed:` branch exits 1 before reaching it).  So the
# roll-up is absent EXACTLY on the tree #420 is about, the strictly worse one.
# Parsing it would have reproduced the defect inside the fix.
#
# The declared count is read too, and disagreement is reported by sc_report
# rather than silently preferred: this file's header rule is that the breakdown
# must not be able to lie quietly, and a scraper pinned to another file's output
# format is the thing most likely to go stale.
sc_unrun_from_py_output() {
    _names=$(printf '%s\n' "$1" | awk '$1 == "UNCERTIFIABLE" && $2 ~ /^tests\// { print $2 }')
    _declared=$(printf '%s\n' "$1" \
        | sed -n 's/^[0-9][0-9]* passed, [0-9][0-9]* failed, \([0-9][0-9]*\) uncertifiable$/\1/p' \
        | tail -1)
    [ -n "$_declared" ] || _declared=0
    _sc_unrun_declared=$((_sc_unrun_declared + _declared))
    sc_unrun "$_names"
    return 0
}

# Count the words in a list (POSIX sh; the lists here are short).
_sc_count() {
    _n=0
    for _w in $1; do _n=$((_n + 1)); done
    printf '%s' "$_n"
}

# Print the breakdown.  Called once, immediately before the wrapper's own
# `selfcheck worst exit:` line, which is left byte-identical so that anything
# grepping for it keeps working.
sc_report() {
    printf '\n=== exit sources (GH #267 4b) ===\n'
    printf 'legs run              : %d\n' "$_sc_legs"
    printf 'FINDINGS (exit 3)     : %s\n' "${_sc_findings:-none}"
    printf 'UNCERTIFIABLE (exit 2): %s\n' "${_sc_uncertifiable:-none}"
    # [GH #420] Third bucket, keyed on files rather than legs.  A leg can be red
    # AND partly un-run; the two lines above can only say one of those.  This
    # line does not move the exit code -- read it as "what nobody looked at",
    # not as a fourth exit level.
    printf 'NOT RUN (inside a leg): %s\n' "${_sc_unrun:-none}"
    _sc_unrun_seen=$(_sc_count "$_sc_unrun")
    if [ "$_sc_unrun_seen" -ne "$_sc_unrun_declared" ]; then
        printf 'ATTRIBUTION BROKEN -- a leg declared %d un-run test(s), %d name(s) reached this line.\n' \
            "$_sc_unrun_declared" "$_sc_unrun_seen"
        printf '  The extractor drifted from the runner output format it reads. Fix the extractor, not this line.\n'
    fi
    if [ "$_sc_worst" -eq 3 ] && [ -z "$_sc_findings" ]; then
        printf 'ATTRIBUTION BROKEN -- worst is 3 but no leg is recorded at 3.\n'
        printf '  A leg raised the exit code without sc_leg/sc_note. Fix the wrapper, not this line.\n'
    elif [ "$_sc_worst" -eq 2 ] && [ -z "$_sc_uncertifiable" ]; then
        printf 'ATTRIBUTION BROKEN -- worst is 2 but no leg is recorded at 2.\n'
        printf '  A leg raised the exit code without sc_leg/sc_note. Fix the wrapper, not this line.\n'
    fi
    printf '  Read this before writing "exit 3, all of it cadence": that sentence was hand-made\n'
    printf '  attribution for days, and on 2026-08-27 it was wrong for 22 hours (GH #267).\n'
}
