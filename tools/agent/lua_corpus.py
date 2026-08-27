#!/usr/bin/env python3
"""The one answer to "which .lua files under bots/ are the corpus, and how do
you read one" (GH #243).

WHY THIS EXISTS.  Six independent censuses each open-coded the same two lines --
`os.walk(bots/)` collecting every `.lua`, then `open()` on each collected path
later.  Between those two moments the tree is not frozen: sixteen Lua gate tests
(GH #229) create and delete `bots/Customize/soak_side.lua`, the gitignored,
farm-only switch that arms a soak candidate.  A census that listed the file and
then reached it after the deletion died with FileNotFoundError.

That is a race with a MEASURED failure rate, not a theoretical one: with the
gate switch churning the way a full `tests/run_tests.lua` churns it,
`tests/test_ability_value_key_census.py` failed 3 runs in 8 and
`tests/test_guard_implication_census.py` 1 in 10 -- while both were green on
every quiet re-run of the same tree.  That is precisely the shape GH #243
reported: one selfcheck read 39 passed / 2 failed, two later runs of the same
runner on the same working tree read 41 / 0.

TWO SEPARATE DEFECTS, TWO SEPARATE REPAIRS.

  (1) The gate switch was never corpus.  It is gitignored, it is written by the
      farm and by gate tests, and it holds one table literal -- no guards, no
      ability reads, nothing any census is asking about.  Its only effect on a
      census was to make the answer depend on whether a gate test happened to be
      mid-flight.  `bots_lua_files()` excludes it BY NAME, which removes the
      race at the source rather than making it survivable.

  (2) A file that vanishes between listing and reading is still possible for
      every OTHER path (a concurrent checkout, an editor, a future generated
      file), and there the honest verdict is "this scan did not run" -- NOT a
      different count.  `read_lua()` raises `CorpusVanished` for exactly that
      case, and `uncertifiable()` turns it into exit code 2 with a banner.

⭐ WHY EXIT 2 AND NOT A FAILURE.  A census that could not read its input has no
answer; a census whose count moved has one and says it is wrong.  Those two
license opposite next actions, and before this change they printed identically
-- as `FAIL <file>` in `tests/run_py_tests.sh`, which 开工自检 escalates to
`TRUNK RED -- a python test is failing ON THE WORKING TREE`.  A round that read
that line believed something about trunk that was not true.  Same distinction
rule 10 draws for `UNCERTIFIABLE` (GH #171) and the push gate draws for
could-not-run (GH #213): 0 clean / 2 did-not-run / 3 findings.

⭐ WHAT THIS MODULE DELIBERATELY DOES NOT DO.  It does not make the exclusion
configurable and it does not exclude a directory.  `EXCLUDED_RELPATHS` is one
frozen path with its reason attached, because an exclusion mechanism that is
easy to extend is how a census quietly stops covering shipped code.  Adding a
row here must cost an argument.
"""

import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

#: Paths under bots/ that are NOT part of the scanned corpus, with the reason.
#: Keyed by repo-relative POSIX path so the reason travels with the row.
EXCLUDED_RELPATHS = {
    "bots/Customize/soak_side.lua":
        "gitignored, farm-only gate switch; created and deleted mid-run by the "
        "16 Lua gate tests (GH #229), so listing it makes a census answer "
        "depend on test timing (GH #243)",
}

#: Exit code meaning "this did not run", as distinct from 1 (it ran and failed).
UNCERTIFIABLE_EXIT = 2


class CorpusVanished(Exception):
    """A listed corpus file was gone by the time it was read.

    Carries the path so the banner can name it.  Deliberately NOT a subclass of
    OSError: call sites that catch OSError to skip unreadable inputs must not
    swallow this one -- swallowing it is how "did not run" becomes "counted
    fewer".
    """

    def __init__(self, path):
        self.path = path
        super().__init__(
            "%s disappeared between listing and reading -- the tree changed "
            "under this scan" % path)


def is_excluded(path, root=None):
    """True if `path` (abs or repo-relative) is a declared non-corpus file."""
    root = root or REPO
    if os.path.isabs(path):
        path = os.path.relpath(path, root)
    return path.replace(os.sep, "/") in EXCLUDED_RELPATHS


def bots_lua_files(root=None):
    """Sorted absolute paths of every corpus `.lua` file under `bots/`.

    Sorted, so two censuses that disagree cannot be disagreeing about order.
    """
    root = root or REPO
    out = []
    for base, _dirs, names in os.walk(os.path.join(root, "bots")):
        for name in sorted(names):
            if not name.endswith(".lua"):
                continue
            path = os.path.join(base, name)
            if is_excluded(path, root):
                continue
            out.append(path)
    return sorted(out)


def bots_lua_relpaths(root=None):
    """Same list as `bots_lua_files`, repo-relative and POSIX-separated."""
    root = root or REPO
    return [os.path.relpath(p, root).replace(os.sep, "/")
            for p in bots_lua_files(root)]


def read_lua(path, errors=None):
    """Read a corpus file; raise `CorpusVanished` if it is gone.

    Every other OSError propagates unchanged -- a permission error or a bad
    encoding is a real defect in the scan's environment and must not be
    laundered into the same bucket as a mid-scan deletion.
    """
    kw = {"encoding": "utf-8"}
    if errors is not None:
        kw["errors"] = errors
    try:
        with open(path, "r", **kw) as fh:
            return fh.read()
    except FileNotFoundError:
        raise CorpusVanished(path)


def uncertifiable(exc, what="this scan", stream=None):
    """Print the did-not-run banner for a `CorpusVanished` and exit 2.

    The banner says NOT A FAILURE in as many words, because the whole point of
    the code is that a reader must not act on it as if a count had moved.
    """
    stream = stream or sys.stderr
    stream.write(
        "UNCERTIFIABLE -- %s did NOT run: %s\n"
        "  This is NOT a test failure and NOT a changed count: the scan never\n"
        "  read its full input, so it has no answer to report.  Re-run on a\n"
        "  quiet tree (nothing else writing under bots/).\n" % (what, exc))
    stream.flush()
    sys.exit(UNCERTIFIABLE_EXIT)


def guard(what="this scan"):
    """Decorator/context helper: run `fn`, turning `CorpusVanished` into exit 2.

    Used by the standalone test scripts, whose exit code IS their whole report.
    """
    def wrap(fn):
        def inner(*a, **kw):
            try:
                return fn(*a, **kw)
            except CorpusVanished as exc:
                uncertifiable(exc, what)
        return inner
    return wrap
