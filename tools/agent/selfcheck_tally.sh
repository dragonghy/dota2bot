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

_sc_worst=0
_sc_leg='(unattributed)'
_sc_findings=''
_sc_uncertifiable=''
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

# Print the breakdown.  Called once, immediately before the wrapper's own
# `selfcheck worst exit:` line, which is left byte-identical so that anything
# grepping for it keeps working.
sc_report() {
    printf '\n=== exit sources (GH #267 4b) ===\n'
    printf 'legs run              : %d\n' "$_sc_legs"
    printf 'FINDINGS (exit 3)     : %s\n' "${_sc_findings:-none}"
    printf 'UNCERTIFIABLE (exit 2): %s\n' "${_sc_uncertifiable:-none}"
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
