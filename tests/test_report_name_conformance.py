#!/usr/bin/env python3
"""No NEW malformed report filename may enter iterations/reports/ (GH #312).

The cadence leg of `citation_audit.py` reads a stream's rhythm off report
FILENAMES.  A name it cannot parse makes that round invisible to the leg, and
the only visible consequence looks like a different thing entirely: a cadence
hole pointed at that stream.  On 2026-08-29 that shape cost real trust --
`20260829T131xZ.md` (a literal `x`, seconds never filled in) was a real
director work unit committed at 13:14:47Z, and two other streams published
"director delivered nothing for 11.5 hours" off the hole it manufactured.

GH #312 offered three cures.  (A) -- name the malformed files one by one and
keep them apart from a directory's recognised non-report files -- landed in
`citation_audit.py`, together with an annotation on any gap that contains one.
That is the READING fixed.  This file is the source: a name that never becomes
malformed cannot mislead anyone downstream.

The seven files below are grandfathered, by a director ruling (2026-08-30,
report `iterations/reports/director/20260830T070000Z.md`) that they are NOT to
be renamed.  The reason is arithmetic, not taste: those names are cited from
`iterations/state.json`, from three charters, from `DECISIONS_NEEDED.md` and
from other streams' reports -- 14+ live citations.  `citation_audit.py` resolves
`iterations/...` paths, so renaming the files would convert every one of those
resolvable citations into a MISSING finding.  Fixing a leg that misreads history
by breaking the history it reads is a trade in the wrong direction; the
annotation already tells the reader the hole is not idleness.

So: the frozen list may SHRINK (a listed file legitimately disappears) but it
may never grow.  A new malformed name is a test failure on the round that
introduced it, which is the only round that can cheaply fix it.

Run:  python3 tests/test_report_name_conformance.py
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
REPORTS = os.path.join(REPO, "iterations", "reports")

CONFORMING = re.compile(r"^\d{8}T\d{6}Z\.md$")
# A `.md` that OPENS with a `YYYYmmddT` stamp is claiming to be a report; the
# same predicate citation_audit.py uses, so the two cannot drift apart.
CLAIMS_STAMP = re.compile(r"^\d{8}T.*\.md$")

GRANDFATHERED = {
    "director/20260829T0707Z.md",      # HHMM, seconds missing
    "director/20260829T10xxZ.md",      # literal `xx`
    "director/20260829T131xZ.md",      # literal `x` -- the GH #312 case
    "hero/20260824T2230Z.md",
    "replay-check/20260827T1030Z.md",
    "strategy/20260828T0430Z.md",
    "strategy/20260828T0730Z.md",
}

failures = []


def main():
    if not os.path.isdir(REPORTS):
        sys.stderr.write("cannot read %s -- did not run\n" % REPORTS)
        return 2
    offenders = []
    for stream in sorted(os.listdir(REPORTS)):
        sdir = os.path.join(REPORTS, stream)
        if not os.path.isdir(sdir):
            continue
        for name in sorted(os.listdir(sdir)):
            if CONFORMING.match(name) or not CLAIMS_STAMP.match(name):
                continue
            rel = "%s/%s" % (stream, name)
            if rel not in GRANDFATHERED:
                offenders.append(rel)

    for rel in offenders:
        print("  FAIL  malformed report name: iterations/reports/%s" % rel)
        print("        rename it to YYYYmmddTHHMMSSZ.md -- unparsed, this round "
              "is invisible to the cadence leg and shows up as a hole "
              "accusing your stream (GH #312)")
    stale = sorted(g for g in GRANDFATHERED
                   if not os.path.exists(os.path.join(REPORTS, g)))
    for rel in stale:
        # Informational: the list shrinking is allowed and expected over time.
        print("  note  grandfathered file no longer present: %s" % rel)
    print("%d stream dir(s) scanned, %d grandfathered, %d new offender(s)"
          % (len([d for d in os.listdir(REPORTS)
                  if os.path.isdir(os.path.join(REPORTS, d))]),
             len(GRANDFATHERED) - len(stale), len(offenders)))
    return 1 if offenders else 0


if __name__ == "__main__":
    sys.exit(main())
