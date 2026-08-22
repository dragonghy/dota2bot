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

# Is trunk itself red?  Added 2026-08-22T14:5xZ (director), after GH #116: a
# tool landed at 13:15Z re-introduced `team_slot % 5 + 1` -- a hero->position
# rule this repo had already MEASURED at 47.3% accuracy (GH #57), retired, and
# ratcheted against -- and shipped a creeppull (a)-verdict built on it.  The
# ratchet caught it within 100 minutes and sat red on `origin/main`; the only
# missing step was somebody running the suite.
#
# That is the same shape as this wrapper's own reason for existing (a detector
# nobody runs), so it belongs in the same 开工 command.  The whole py suite is
# 11 files and runs in seconds -- cheap enough that "is main red right now?"
# stops depending on who happens to reach their push gate first.
#
# NOT the Lua suite: that one needs lua5.1 + minutes, and is the push gate's
# job (README rule 6), not 开工's.  A red here is a QUESTION like the others --
# it may be someone else's in-flight breakage, not yours -- but LOOK.
printf '\n=== trunk health (python test suite) ===\n'
if command -v python3 >/dev/null 2>&1; then
    if suite=$(bash tests/run_py_tests.sh 2>&1); then
        printf '%s\n' "$suite" | tail -1
    else
        printf '%s\n' "$suite" | grep -E '^(FAIL|failed:|[0-9]+ passed)' || true
        printf 'TRUNK RED -- a test is failing before you changed anything.\n'
        note 3
    fi
else
    printf 'SKIP (no python3)\n'
fi

printf '\nselfcheck worst exit: %d\n' "$worst"
exit "$worst"
