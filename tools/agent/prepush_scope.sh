#!/usr/bin/env bash
# Compute the fast Lua leg's SCOPE for one `git push`, from the ref updates
# that git hands a pre-push hook on stdin.
#
# GH #865 (A) -- director RULING 70 (2026-09-17), amending RULING 69's (A).
#
# THE DEFECT THIS REPLACES
# ------------------------
# `.githooks/pre-push` used to compute scope as:
#
#     git diff --name-only origin/main...HEAD
#
# `origin/main` is a LOCAL ref, and `git push origin HEAD:main` moves it to
# HEAD.  So the twin push that follows it asks the same expression and gets an
# EMPTY answer -- which the gate reads (correctly, by its own rules) as "we
# could not tell, run everything".  Measured on the director's 2026-09-17T04:20Z
# round: a markdown-only re-push with `origin/main` already equal to the tree
# printed `scope EMPTY -> running the WHOLE manifest` and then ran 567.4s for a
# tree `main` already carried.  The expression is not wrong about the repo; it
# is wrong about WHICH REF IS BEING PUSHED, and only git knows that.
#
# git already says so, on stdin, one line per ref:
#
#     <local ref> <local sha> <remote ref> <remote sha>
#
# `remote sha` is the sha the remote currently has for that ref -- exactly the
# base the push is adding to -- and it is all zeros when the ref is NEW.
#
# WHY A NEW REF STILL FALLS BACK (the amendment; RULING 70)
# --------------------------------------------------------
# RULING 69's (A) said an all-zero remote sha is "the true cannot-tell => run
# the whole set".  That is right about git and wrong about THIS repo, and the
# difference is measurable: every Routine session pushes its OWN branch, so the
# branch push is a new ref on EVERY round (measured 2026-09-17: 1264 `claude/*`
# refs on origin, and this session's branch absent from `ls-remote`).  Taken
# literally, (A) would convert the first push of every round -- the common case,
# including every markdown-only round -- from a scope answer into a full
# manifest run.  That is a regression in the common case bought to fix a rare
# one.
#
# For a new branch the question "what does this push add" still HAS an answer:
# the commits this branch adds to the integration branch, i.e. the three-dot
# diff from the merge base with `origin/main`.  That is the same expression as
# before -- but now it is reached ONLY on the new-ref path, where the twin-push
# ref move cannot poison it, because a branch push does not move `origin/main`.
#
# And when it IS poisoned anyway (someone pushed main first, so the merge base
# is HEAD and the diff is empty), the answer is empty => run everything.  The
# fallback can lose precision.  It cannot fail open.
#
# FAIL-CLOSED, stated rather than implied
# ---------------------------------------
# Every way this can go wrong -- no stdin, an empty line, a sha the local
# object store does not have, a git command that exits non-zero -- ends as
# `unknown` with an EMPTY path file.  `lua_gate.py --if-touched` reads an empty
# list as RUN EVERYTHING (see `touches_lua`, which says so in its docstring).
# Skipping needs a positive answer, never the absence of one.  That direction is
# the one this repo has repeatedly paid for getting backwards (GH #171 SKIP,
# GH #205, GH #624), so it is not available here.
#
# USAGE
#     tools/agent/prepush_scope.sh <paths-outfile>   < <git's ref-update lines>
#
# Writes the changed paths (one per line, deduplicated, possibly none) to
# <paths-outfile>, and prints ONE provenance token on stdout:
#
#     stdin-remote         the remote sha git named for this ref; authoritative
#     fallback-merge-base  new ref (all-zero remote sha); merge base with
#                          $PREPUSH_FALLBACK_REF (default origin/main)
#     mixed                several refs in one push, answered by both routes
#     unknown              no positive answer -- caller MUST run the whole set
#
# Exit status is 0 whenever the tool itself ran.  The VERDICT is the token, not
# the exit code: "could not tell" is a normal, expected answer here, and
# conflating it with "the tool broke" would put a real breakage behind a word
# the caller already handles quietly.
set -u

out="${1:-}"
if [ -z "$out" ]; then
    printf 'usage: prepush_scope.sh <paths-outfile>  < <ref-update lines>\n' >&2
    exit 64
fi
: > "$out" 2>/dev/null || { printf 'unknown\n'; exit 0; }

fallback_ref="${PREPUSH_FALLBACK_REF:-origin/main}"

src="unknown"
have_any=0

# `all zeros` covers both git's 40-char (sha1) and 64-char (sha256) null shas,
# and an empty field, without hardcoding a width.
is_zero() {
    case "${1:-}" in
        "") return 0 ;;
        *[!0]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Sets the verdict only. Truncating `$out` is deliberately NOT done here: the
# single truncation below, keyed on `have_any`, is the one that has to be right,
# and a second copy of it here was measured (2026-09-17 mutation stand, M4) to
# be unkillable -- i.e. it could be deleted with no entry noticing, which makes
# it decoration on a fail-closed path. One guard that a test can kill beats two
# that share the work.
fail_closed() {
    src="unknown"
    have_any=0
}

# Reading from stdin directly (no pipe into this loop) so the assignments below
# survive it.  If the caller gave us nothing, the loop body never runs and the
# answer stays `unknown` -- which is the correct reading of "no stdin".
while read -r local_ref local_sha remote_ref remote_sha _rest; do
    # A blank or malformed line is not a positive answer about anything.
    if [ -z "${local_ref:-}" ] || [ -z "${local_sha:-}" ]; then
        fail_closed
        break
    fi

    # A DELETE zeroes the LOCAL sha: nothing arrives at the remote, so this
    # line contributes no paths.  It also casts no vote -- `continue`, not a
    # positive empty answer.  If a push is ONLY deletions, `have_any` stays 0
    # and the whole set runs; that is the fail-closed side of a rare case.
    if is_zero "$local_sha"; then
        continue
    fi

    this_src="stdin-remote"
    base="$remote_sha"
    if is_zero "$base"; then
        # NEW REF. See "WHY A NEW REF STILL FALLS BACK" above.
        this_src="fallback-merge-base"
        base=$(git merge-base "$fallback_ref" "$local_sha" 2>/dev/null) || base=""
    fi

    if [ -z "$base" ]; then
        fail_closed
        break
    fi

    # The sha git names is the REMOTE's, and a clone that has never fetched it
    # does not have the object. That is NOT an empty diff, it is an error --
    # and the `if !` below is what keeps it from arriving wearing the shape of
    # "nothing changed". (A separate `git cat-file -e` pre-check stood here
    # until the 2026-09-17 mutation stand showed no entry could kill it: `git
    # diff` already exits non-zero on a bad object, so the pre-check only ever
    # restated this guard's answer. A guard nothing can kill is a guard nothing
    # is testing.)
    # TWO dots, deliberately. `$base...$local_sha` (three) would name exactly
    # what the push ADDS, which is the prettier answer; two dots also names
    # what the remote has and this ref does not. Those differ only when the
    # push is NOT a fast-forward -- i.e. when git is about to reject it anyway
    # -- and the difference is that two dots over-includes. Over-including
    # costs seconds; under-including skips a test that had something to say.
    if ! git diff --name-only "$base" "$local_sha" >> "$out" 2>/dev/null; then
        fail_closed
        break
    fi

    have_any=1
    if [ "$src" = "unknown" ] || [ "$src" = "$this_src" ]; then
        src="$this_src"
    else
        src="mixed"
    fi
done

if [ "$have_any" -ne 1 ]; then
    src="unknown"
    : > "$out" 2>/dev/null || true
else
    # Several refs can carry the same path; the gate wants a set.
    sorted=$(sort -u < "$out" 2>/dev/null) || sorted=""
    printf '%s' "$sorted" > "$out" 2>/dev/null || true
    [ -s "$out" ] && printf '\n' >> "$out" 2>/dev/null
fi

printf '%s\n' "$src"
exit 0
