#!/usr/bin/env bash
# One command every routine trigger runs at 开工, before claiming any work.
#
# WHY THIS EXISTS -- and it is not the reason GH #113 gives.
#
# #113 reported three rounds on 2026-08-22 whose output never reached `main`,
# and diagnosed the first (hero 08:00Z) as STRUCTURALLY invisible to
# `unlanded_commits.py`, on the grounds that it "never pushed, not even a
# branch".  Measured at 12:5xZ that day, that is false: the 08:00Z tree is on
# `origin/claude/vibrant-heisenberg-3os6d0` as `eda1257` (committed 08:39:10Z),
# with the SAME EIGHT FILES the 10:00Z round then rebuilt from scratch.
#
# So the detector built at 03:00Z would have found all three shapes.  Nobody ran
# it.  The 10:00Z round paid a full trigger to re-derive work that was sitting on
# a remote branch, and the 12:00Z round paid again to land it.
#
# A detector nobody runs is the dead S3 lifecycle rule of test_set.md Z.4: on the
# books, matching nothing.  This wrapper is the cheap half of the fix -- the
# half that makes the checks happen.
#
# Exit 0 clean, 2 uncertifiable, 3 findings.  Findings are a QUESTION (see each
# tool's LIMITS): an OFF-TRUNK branch may be work already relanded under a
# different SHA, and a cadence GAP may be a trigger that legitimately had
# nothing to file.  Look before concluding -- but LOOK.
#
# Usage:  bash tools/agent/routine_selfcheck.sh [--comments <gh-comments.json>]
set -u
cd "$(dirname "$0")/../.."

extra=()
while [ $# -gt 0 ]; do
    case "$1" in
        --comments) extra+=(--comments "$2"); shift 2 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

worst=0
note() { [ "$1" -gt "$worst" ] && worst="$1"; return 0; }

printf '=== unlanded work (pushed to a branch, never landed) ===\n'
python3 tools/agent/unlanded_commits.py --fetch
note $?

printf '\n=== report cadence + published citations ===\n'
python3 tools/agent/citation_audit.py --cadence --fetch "${extra[@]+"${extra[@]}"}"
note $?

printf '\nselfcheck worst exit: %d\n' "$worst"
exit "$worst"
