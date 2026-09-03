#!/usr/bin/env python3
"""Every mutation stand must restore the tree even when it is interrupted.

WHY THIS FILE EXISTS (GH #418, 2026-09-02).  A mutation stand works by writing
a deliberate defect into a tracked file, running the tests, and copying the
original back.  The copy-back is the only thing standing between the stand and
a committed mutant, and in five of the six stands it lived exclusively in the
straight-line path: `restore` at the top of the loop, `restore` after it.  Any
exit that does not reach those lines -- a timeout, a ^C, an OOM, a container
reclaimed mid-run, a `set -u` failure in a helper -- leaves the MUTANT in the
working tree, and the next `git add -A` commits it as if it were the round's
work.  Nothing downstream would flag it: it is a plausible one-token edit
inside a file the round legitimately touched.

That is not a hypothesis about a possible future.  `bots/FunLib/jmz_func.lua`
reached main on 2026-09-02 with `dist <= closestDist` where the shipped tree
had `dist < closestDist` -- un-gated, unexplained by its own commit message,
and inside a function whose comment claimed the un-armed path was byte-for-byte
the shipped one.  The round's own mutation log (test_set.md section DJ.7) names
that exact edit, on that exact line, as a mutant it had applied and then
dismissed as equivalent.  Whether the line was typed by hand or left behind by
the stand is not established here and the fix does not depend on which: an EXIT
trap closes the leak, and it costs one line.

WHAT THIS PINS, AND WHAT IT DELIBERATELY DOES NOT.  It pins that each stand
installs an EXIT trap naming its restore function, and that the trap is armed
BEFORE the first mutation.  It does NOT try to prove the restore is correct --
`sha256sum -c` inside each restore does that, and a test that re-derived it
would just be a second copy of the same claim.  The check is universal rather
than a count, so a stand added tomorrow without a trap fails this file on the
day it lands, which is the property a ratchet on the current number of stands
would not have.

A NOTE ON THIS FILE'S OWN SHAPE, because the first version of it got this
wrong.  tests/*.py here are PLAIN SCRIPTS: tests/run_py_tests.sh runs
`python3 <file>` and reads the exit code.  The first version was written as
pytest-style `def test_*()` functions, which python never calls -- so it
exited 0, the runner printed PASS, and it had asserted nothing.  It was caught
by mutating a stand's trap away and watching the file still pass (evidence
discipline 2: suspect the assertion when a mutant survives), which is the same
family as the defect the file is about -- a green that means "nothing ran".
Keep the checks at module level.
"""

import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STANDS = sorted(glob.glob(os.path.join(ROOT, "tools", "agent", "mutstand_*.sh")))

# `trap restore EXIT` and `trap 'restore' EXIT` are both in the tree and both
# correct; the quoting is not the point, reaching the function is.
TRAP = re.compile(r"^\s*trap\s+'?(?P<fn>[A-Za-z_][A-Za-z0-9_]*)'?\s+.*\bEXIT\b", re.M)

fails = []


def ok(label, cond, detail=None):
    if cond:
        print("  ok   %s" % label)
    else:
        print("  FAIL %s%s" % (label, "" if detail is None else "  [%s]" % detail))
        fails.append(label)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


print("mutation stands found: %d" % len(STANDS))

# An empty glob would make every check below vacuously true -- the failure mode
# where a file is green because it tested nothing.  Same shape as the docstring's
# closing note, one level up.
ok("there are stands to check at all (>= 6)", len(STANDS) >= 6, STANDS)

for path in STANDS:
    name = os.path.relpath(path, ROOT)
    src = read(path)
    m = TRAP.search(src)

    ok("%s installs an EXIT trap" % name, m is not None,
       "an interrupted run leaves the mutant in the working tree")
    if m is None:
        continue

    fn = m.group("fn")
    ok("%s traps a function that exists (%s)" % (name, fn),
       re.search(r"^%s\(\)\s*\{" % re.escape(fn), src, re.M) is not None,
       "the trap fires and does nothing")

    ok("%s verifies its restore" % name, "sha256sum" in src,
       "a stand that cannot prove it put the tree back may have eaten the fix")

    # A trap installed after the mutation loop protects nothing.  Order is the
    # whole content of the guarantee, so it is checked by position, not by
    # presence.  A stand that inlines its mutations has nothing to order
    # against and is skipped rather than passed silently.
    #
    # THE APPLIER IS NOT ALWAYS CALLED `apply_mutant` (director 2026-09-03).
    # The first version of this check keyed on the literal string
    # `apply_mutant `, so `mutstand_fixture_debt.sh` -- which has an applier,
    # named `mutant`, and therefore does have a window to order against -- was
    # printed as `--  ordering not applicable` and its order went unchecked.
    # That is this repo's recurring shape: a detector that sees one spelling of
    # the thing and calls the other spellings absent.  So the applier is found
    # by DEFINITION first (a function in this file whose name is `mutant` or
    # `apply_mutant`), and only a stand that defines neither is skipped.
    applier = None
    for cand in ("apply_mutant", "mutant"):
        if re.search(r"^%s\s*\(\)\s*\{" % cand, src, re.M):
            applier = cand
            break

    # Call sites are found by walking lines rather than anchoring the name to
    # the start of one: the real call sites in this tree include
    # `if ! apply_mutant "$m"; then`.  Anchoring cost four stands their ordering
    # check on the first attempt at this widening -- they went from a green
    # check to a `--`, which is the failure this file's own docstring is about
    # (a green that means "nothing ran"), one level up.
    first_apply = -1
    if applier is not None:
        call = re.compile(r"\b%s[ \t]+[\"'$A-Za-z0-9]" % applier)
        pos = 0
        for line in src.splitlines(keepends=True):
            stripped = line.lstrip()
            if not stripped.startswith("#"):
                hit = call.search(line)
                if hit:
                    first_apply = pos + hit.start()
                    break
            pos += len(line)

    if applier is None:
        print("  --   %s defines no mutant applier; ordering not applicable" % name)
    else:
        # A stand that DEFINES an applier and appears to call it nowhere means
        # the detector lost the call shape, not that the stand has no window.
        # Could-not-run is not a pass here either.
        ok("%s ordering check found a %s call site" % (name, applier),
           first_apply != -1,
           "the ordering check below cannot run; widen the call-site pattern")
        if first_apply != -1:
            ok("%s arms the trap before the first %s" % (name, applier),
               m.start() < first_apply,
               "the window the trap exists to close is exactly the one before it")

print()
if fails:
    print("%d FAILURE(S):" % len(fails))
    for f in fails:
        print("  - %s" % f)
    sys.exit(1)
print("mutation stands: every one restores the tree on any exit")
