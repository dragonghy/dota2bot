#!/usr/bin/env bash
# Check a draft issue comment / report BEFORE publishing it: does everything it
# cites resolve on the trunk a reader will have?
#
# WHY THIS EXISTS (GH #290, 2026-08-29)
# -------------------------------------
# On 2026-08-28T22:03Z a round closed GH #286 with five citations for a fix that
# was committed locally and NOT YET PUSHED.  Nothing was faked: the code, the
# test and the archive entries were all real, four hours later.  What went wrong
# was ORDER -- the issue was closed and the citations published while the tree
# was still only local.  For the four hours in between:
#
#   * GH #287 fenced the hero group off `tests/test_skill_list_nil_head_drain.lua`,
#     a file that did not exist, and that fence covered the only half still broken;
#   * W23 launched at 00:16Z from a tree without the fix, and OD stalled in 9/12
#     games -- the measured cost.
#
# `citation_audit.py` could have answered this in one second.  Nobody asked it,
# because asking meant remembering to.  So this is the one-command form, meant to
# be run on the draft while you still have it in a buffer:
#
#     bash tools/agent/claim_precheck.sh /tmp/my_comment.md
#
# It answers exactly one question -- "will a reader be able to follow what I am
# about to publish" -- and it answers it against `origin/main`, not the working
# tree, because that is what the reader has.
#
# THE RULE IT ENFORCES
#     `git push` FIRST.  Then close the issue, then publish the citations.
#     Not because the suite is slow, but because everything downstream reads the
#     trunk and nothing downstream reads your container.
#
# EXIT CODES  (same vocabulary as rule 6's gate and rule 10's selfcheck)
#     0  every citation in the draft resolves on the trunk -- safe to publish
#     2  could not run (no draft given, unreadable, git/python missing)
#     3  at least one citation does not resolve -- DO NOT PUBLISH YET
#
# LIMITS
#   - It checks CITATIONS, not claims.  "adds a local CompactSkillList" names no
#     path, key or section, so nothing here sees it; see citation_audit.py's
#     "WHAT THIS DOES NOT DO".  Cite the test file and it is covered.
#   - A draft with zero citations exits 0 and says so.  There is nothing to
#     certify, and refusing would train the reflex to skip the tool.
#   - `CLAIM_PRECHECK_REPO` points the audit at another checkout.  It exists so
#     tests/test_claim_precheck.py can run this script against a REAL throwaway
#     repository (unpushed commit and all) instead of mocking git -- git is the
#     part that can be wrong.
set -u
TOOLROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPO="${CLAIM_PRECHECK_REPO:-$TOOLROOT}"
cd "$TOOLROOT"

if [ $# -lt 1 ]; then
    printf 'usage: bash tools/agent/claim_precheck.sh <draft-file> [more...]\n' >&2
    printf 'REFUSE  no draft given -- this is exit 2 (could not run), not a pass.\n' >&2
    exit 2
fi

args=()
for f in "$@"; do
    if [ ! -r "$f" ]; then
        printf 'REFUSE  cannot read draft: %s\n' "$f" >&2
        exit 2
    fi
    args+=(--text "$f")
done

command -v python3 >/dev/null 2>&1 || {
    printf 'REFUSE  no python3 -- this leg did NOT run. Not a pass.\n' >&2
    exit 2
}

# Loud, before the verdict: unpushed local commits are the precondition of the
# #286 shape.  Informational on its own -- you may hold unrelated work -- but if
# the verdict below is 3, this line is almost always the reason.
git -C "$REPO" fetch origin main -q 2>/dev/null || true
ahead=$(git -C "$REPO" rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
printf '=== claim precheck ===\n'
printf 'repo: %s\n' "$REPO"
printf 'local commits not on origin/main: %s\n' "$ahead"
if [ "$ahead" != "0" ] && [ "$ahead" != "?" ]; then
    printf 'NOTE  a reader sees origin/main, not this container.  If a citation below\n'
    printf '      is MISSING, push first -- then close the issue, then publish.\n'
fi

out=$(python3 tools/agent/citation_audit.py --repo "$REPO" --fetch "${args[@]}" 2>&1)
rc=$?
printf '%s\n' "$out"

# citation_audit exits 2 on "zero citations extracted".  For a POST-HOC audit
# that refusal is right (an empty scan must not read as a clean bill).  For a
# draft it is not a refusal at all: a comment that cites nothing cannot strand
# anyone.  Every other 2 stays a 2.
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'zero citations extracted'; then
    printf '\nNO CITATIONS -- nothing to certify, nothing to strand.  OK to publish.\n'
    exit 0
fi

if [ "$rc" -eq 0 ]; then
    printf '\nOK to publish: every citation resolves on origin/main.\n'
elif [ "$rc" -eq 3 ]; then
    printf '\nDO NOT PUBLISH YET -- the citations above do not resolve on origin/main.\n'
    printf 'Push, then re-run this, then close the issue / post the comment.\n'
fi
exit $rc
