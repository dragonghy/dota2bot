#!/usr/bin/env python3
"""Memoize ONE green three-leg reading of iron rule 6's static half, keyed by
the exact tree it was taken on, so the second push of that same tree does not
pay for it again.

WHY (director ruling 2026-09-13, filed off the 09-12T22:2xZ 收尾追加).

The mandated push path in `.claude/rules/claude-code.md` is two commands:

    git push -u origin <branch> && git push origin HEAD:main

git runs `pre-push` once per `git push` INVOCATION, so that path runs the whole
three-leg gate TWICE on a byte-identical tree.  Measured in a throwaway
repo (bare remote + a counting hook, same commit pushed to two refs):
`hook invocations: 2`, `HEAD` and `HEAD^{tree}` identical across both.  The
second run cannot answer a different question than the first -- the legs read
the working tree, and nothing between the two commands touches it.

That duplication is not merely waste, and the waste is not the reason this
file exists.  The 09-12T22:2xZ round measured the gate at ~7 minutes (the fast
Lua leg alone 380s, ~90%) while `main` was moving every ~7 minutes, and watched
`HEAD:main` get remote-rejected three times in a row -- never on a red, always
on a ref race -- burning ~21 minutes for zero product before the fourth attempt
went out under `RULE6_BYPASS=1`.  The push that loses that race is the SECOND
one, and the second one is exactly the run this file removes.  A gate slow
enough to lose the race it must win drives people into its own escape hatch;
shrinking the second push's window from ~7 minutes to ~0 attacks that at the
one place where the work being redone is provably redundant.

WHAT THIS IS NOT.  It is not `RULE6_BYPASS`, and the banner must never be
readable as one.  A bypass asserts nothing; a memo hit replays a reading that a
REAL run of all three legs produced on THIS EXACT tree.  The claim "rule 6's
static half is green on the tree being pushed" is as true on the hit as on the
miss -- what changes is only who did the work and when, and the banner says
both so a report quoting it stays honest.

FAIL-CLOSED IN EVERY DIRECTION (the memo may only ever be an optimization):

  * The key is the TREE, not the commit: `HEAD^{tree}` plus `origin/main`.
    `origin/main` is in the key because the Lua leg scopes itself with
    `git diff --name-only origin/main...HEAD` -- a moved base is a bigger
    changed-set, hence a different question, hence a miss.
  * The working tree must be CLEAN, untracked files included.  The legs lint
    and run what is on DISK, not what is in the commit; a dirty tree means the
    stored reading was taken on something the tree sha does not name.  Any
    output from `git status --porcelain -uall` refuses the memo outright.
  * Only an ALL-GREEN reading is ever stored.  Red and could-not-run are never
    memoized, so a retry after a failure always re-runs.
  * A REDIRECTED gate neither reads nor writes the memo (GH #795).
    PY_GATE_ROOT / PY_GATE_MANIFEST / LUA_GATE_ROOT / LUA_GATE_MANIFEST move
    what legs 2 and 3 actually read off the tree this key names, so a reading
    taken under them is not about this tree at all.  Both gates already PRINT
    that they were redirected ("PY GATE REDIRECTED -- ... (not the repo's own)")
    -- the memo simply never asked, and that omission disarmed this repo's push
    gate for real; see the comment on REDIRECT_ENV below.
  * Anything unexpected -- no git, no `origin/main`, unreadable memo dir,
    corrupt entry -- is a MISS, never a hit.

Storage is `.git/rule6_memo/`, which is per-container and does not travel with
a clone, same as `core.hooksPath` (GH #213).

Subcommands:
    get         exit 0 and print the stored readings on a hit; exit 1 on a miss
                (a miss is normal); exit 2 when the memo is unavailable by rule
                (dirty tree, no origin/main, ...) with the reason on stderr.
    put FILE    store FILE's contents as the readings for the current key.
    key         print the key and its inputs (debugging).
"""

import hashlib
import json
import os
import subprocess
import sys
import time

MEMO_DIRNAME = "rule6_memo"
MAX_ENTRIES = 32
MAX_AGE_SECONDS = 24 * 60 * 60

# Environment variables that move what legs 2 and 3 READ off the tree the key
# names.  The key is (HEAD^{tree}, origin/main) + "the working tree is clean",
# and every one of those inputs is about THIS repo; none of them can see that
# py_gate.py was pointed at a two-file scratch tree in /tmp.
#
# GH #795, and the store direction is the one that reached production.
# tests/test_py_gate_hook.py drives the REAL hook from the REAL repo with these
# set, because what it tests is the hook's wiring, not the repo's ratchets.  Its
# all-green control case therefore stored a reading ABOUT A SYNTHETIC TWO-FILE
# TREE under the real tree's key -- measured 2026-09-13T12:55Z on a clean trunk:
#
#     py gate: 1 ran, 0 findings, 0 uncertifiable, 0.0s
#     lua gate: 1 ran, 0 findings, 0 uncertifiable, 0 known-red, 0.0s
#
# under HEAD^{tree}=47de5248, with `rule6_memo.py get` answering rc=0 and a
# banner asserting "all three legs really ran ... on THIS EXACT tree".  They had
# not.  The next real `git push` of that tree would have replayed it and skipped
# all three legs while printing that sentence -- a fail-open with a friendlier
# face than RULE6_BYPASS, which is exactly what this file's own header says the
# memo may never become.
#
# The read direction bit first and is how it was found: the same entry then
# answered the file's own RED cases, so four of the six assertions that say "a
# red gate refuses the push" were being satisfied by a memo hit (10 checks /
# 6 failed on a clean tree, 10/0 on a dirty one -- i.e. red exactly on the trees
# where a push really happens).
#
# Fail closed in BOTH directions rather than adding them to the key: a redirected
# run is not a reading of this tree, so there is nothing here worth storing under
# any key, and RULE6_NO_MEMO is not a substitute (it suppresses the read and
# leaves the write).
REDIRECT_ENV = (
    "PY_GATE_ROOT",
    "PY_GATE_MANIFEST",
    "LUA_GATE_ROOT",
    "LUA_GATE_MANIFEST",
)


def _git(*args):
    """Return (rc, stdout) for a git command; never raises."""
    try:
        p = subprocess.run(
            ["git"] + list(args),
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            universal_newlines=True,
        )
    except OSError:
        return 127, ""
    return p.returncode, p.stdout


def memo_inputs():
    """Return (inputs_dict, None) or (None, reason) when the memo is unavailable.

    Every branch that returns a reason is a fail-closed branch: the caller must
    treat it as "no memo", never as "green".
    """
    # First, and before any git call: if the legs have been pointed somewhere
    # else, no key computed from this repo describes what they measured.
    redirected = [name for name in REDIRECT_ENV if os.environ.get(name)]
    if redirected:
        return None, "gate inputs are redirected by env (%s)" % ", ".join(redirected)

    rc, top = _git("rev-parse", "--show-toplevel")
    if rc != 0 or not top.strip():
        return None, "not inside a git work tree"

    rc, tree = _git("rev-parse", "HEAD^{tree}")
    if rc != 0 or not tree.strip():
        return None, "cannot resolve HEAD^{tree}"

    rc, base = _git("rev-parse", "origin/main")
    if rc != 0 or not base.strip():
        # The Lua leg's scope is computed against origin/main. Without it we
        # cannot say two runs asked the same question.
        return None, "cannot resolve origin/main"

    # -uall: an untracked .lua under bots/ IS linted by the static leg, so an
    # untracked file makes the tree sha a lie about what was measured.
    rc, dirty = _git("status", "--porcelain", "-uall")
    if rc != 0:
        return None, "cannot read git status"
    if dirty.strip():
        n = len([ln for ln in dirty.splitlines() if ln.strip()])
        return None, "working tree is not clean (%d path(s))" % n

    return (
        {
            "top": top.strip(),
            "tree": tree.strip(),
            "base": base.strip(),
        },
        None,
    )


def memo_key(inputs):
    raw = "rule6-memo-v1\ntree=%s\nbase=%s\n" % (inputs["tree"], inputs["base"])
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:32]


def memo_dir(inputs):
    rc, gitdir = _git("rev-parse", "--git-dir")
    if rc != 0 or not gitdir.strip():
        return None
    gitdir = gitdir.strip()
    if not os.path.isabs(gitdir):
        gitdir = os.path.join(inputs["top"], gitdir)
    return os.path.join(gitdir, MEMO_DIRNAME)


def memo_path(inputs):
    d = memo_dir(inputs)
    if d is None:
        return None
    return os.path.join(d, memo_key(inputs) + ".json")


def _prune(d):
    """Bound the memo dir. Best effort; failure here is never fatal."""
    try:
        entries = []
        now = time.time()
        for name in os.listdir(d):
            if not name.endswith(".json"):
                continue
            p = os.path.join(d, name)
            try:
                st = os.stat(p)
            except OSError:
                continue
            if now - st.st_mtime > MAX_AGE_SECONDS:
                try:
                    os.remove(p)
                except OSError:
                    pass
                continue
            entries.append((st.st_mtime, p))
        entries.sort(reverse=True)
        for _, p in entries[MAX_ENTRIES:]:
            try:
                os.remove(p)
            except OSError:
                pass
    except OSError:
        pass


def cmd_get():
    inputs, reason = memo_inputs()
    if reason is not None:
        sys.stderr.write("rule6_memo: unavailable -- %s\n" % reason)
        return 2
    p = memo_path(inputs)
    if p is None or not os.path.exists(p):
        return 1
    try:
        with open(p, "r") as fh:
            rec = json.load(fh)
    except (OSError, ValueError):
        return 1
    # A corrupt or mis-keyed entry is a miss, never a hit.
    if rec.get("tree") != inputs["tree"] or rec.get("base") != inputs["base"]:
        return 1
    body = rec.get("readings")
    if not isinstance(body, str) or not body.strip():
        return 1
    sys.stdout.write(
        "RULE6_MEMO=REUSE  a green three-leg reading taken %s on THIS EXACT tree.\n"
        % rec.get("at", "(unknown time)")
    )
    sys.stdout.write(
        "  This is a REUSE, not a skip: all three legs really ran, on\n"
        "  HEAD^{tree}=%s with origin/main=%s and a clean working tree.\n"
        "  The push path runs this hook twice per attempt on one tree; the\n"
        "  second run can only repeat the first. Quote the lines below.\n"
        % (inputs["tree"], inputs["base"])
    )
    sys.stdout.write(body if body.endswith("\n") else body + "\n")
    return 0


def cmd_put(path):
    inputs, reason = memo_inputs()
    if reason is not None:
        sys.stderr.write("rule6_memo: not stored -- %s\n" % reason)
        return 2
    try:
        with open(path, "r") as fh:
            body = fh.read()
    except OSError as exc:
        sys.stderr.write("rule6_memo: not stored -- cannot read %s (%s)\n" % (path, exc))
        return 2
    if not body.strip():
        sys.stderr.write("rule6_memo: not stored -- empty readings\n")
        return 2
    d = memo_dir(inputs)
    p = memo_path(inputs)
    if d is None or p is None:
        sys.stderr.write("rule6_memo: not stored -- cannot locate .git\n")
        return 2
    rec = {
        "tree": inputs["tree"],
        "base": inputs["base"],
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "readings": body,
    }
    try:
        os.makedirs(d, exist_ok=True)
        tmp = p + ".tmp%d" % os.getpid()
        with open(tmp, "w") as fh:
            json.dump(rec, fh, indent=1)
        os.replace(tmp, p)
    except OSError as exc:
        sys.stderr.write("rule6_memo: not stored -- %s\n" % exc)
        return 2
    _prune(d)
    return 0


def cmd_key():
    inputs, reason = memo_inputs()
    if reason is not None:
        sys.stdout.write("MEMO_UNAVAILABLE  %s\n" % reason)
        return 2
    sys.stdout.write(
        "MEMO_KEY=%s tree=%s base=%s\n"
        % (memo_key(inputs), inputs["tree"], inputs["base"])
    )
    return 0


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__ or "")
        return 2
    cmd = argv[1]
    if cmd == "get":
        return cmd_get()
    if cmd == "put":
        if len(argv) < 3:
            sys.stderr.write("rule6_memo: put needs a file\n")
            return 2
        return cmd_put(argv[2])
    if cmd == "key":
        return cmd_key()
    sys.stderr.write("rule6_memo: unknown subcommand %r\n" % cmd)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
