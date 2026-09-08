#!/usr/bin/env python3
"""Two-way pin between the archive-scan pass and the owed row that carries it.

WHY THIS FILE EXISTS (2026-09-08, director, test_set.md §GB).

`iterations/owed_executions.json:hero_domain_scan_2_30_31` is the registry row
for ONE read-only archive traversal that many queue requests ride.  On
2026-09-06 (hero-36) its `done_when` was upgraded from `path_exists` to
`path_contains_all` precisely because a single existing artefact read DONE
while most of the readings it owed were absent -- the needles make each rider
name itself in the artefact.

THE UPGRADE DID NOT HOLD, AND IT FAILED THE VERY NEXT ROUND.  hero-38 and
hero-39 (ruled 09-06T22:xxZ) and hero-40 (ruled 09-07T10:xxZ) were all approved
onto this same pass, and NONE of them was added to the needle list.  So on
09-08 the leg still read DONE with three approved-but-unstarted readings
underneath it.  The defect is not the ruling and not the tool: it is that the
needle list is maintained BY REMEMBERING.  A ruling that rides the pass and a
needle that pins it were two separate manual acts, and the second one is the
one nobody is holding.

SO THE INVARIANT IS TWO-WAY, AND IT IS AN EQUALITY, NOT AN INCLUSION:

    { queue id : director.owed_row == ROW }  ==  { hero-N needles of ROW }

Left-to-right catches the drift that actually happened (rule a rider, forget
the needle).  Right-to-left catches its mirror (a needle for a request that
was never routed here, e.g. after a ruling is rewritten), which would make the
leg red forever for a reading nobody owes.  Neither direction is hypothetical:
the first has now occurred twice on this row.

LIMITS -- what this file does NOT buy.
 1. It says nothing about whether a reading was DELIVERED.  That is the
    needle's own job (`path_contains_all`), and even that only buys MENTION,
    not correctness (see the row's `done_when_note`).  Reading the artefact
    through, per rider, is still the director's own act before retiring.
 2. It pins riders to the row only when the ruling carries the machine key
    `director.owed_row`.  A future ruling that rides this pass in PROSE only
    is invisible here -- the key IS the pin, which is why the key was added to
    hero-2/30..40 as a backfill in the same change.
 3. It is scoped to this one row on purpose.  A general "every owed row's
    needles come from somewhere" law would need every row to be queue-shaped,
    and most are not (they pin reports, tests, gates).

Run: `python3 -m unittest tests/test_domain_scan_pass_pins.py`
(this container has no pytest; `python3 -m pytest` answers `No module named
pytest`, which is a could-not-run, not a pass).
"""

import json
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUEUE = os.path.join(ROOT, "iterations", "queue.json")
OWED = os.path.join(ROOT, "iterations", "owed_executions.json")

ROW_ID = "hero_domain_scan_2_30_31"
ARTEFACT = "iterations/reports/replay-check/domain_scan_hero_2_30_31.md"
QUEUE_ID = re.compile(r"^(hero|strategy|batch|replay)-\d+$")


def _queue():
    with open(QUEUE, encoding="utf-8") as fh:
        return json.load(fh)


def _row():
    with open(OWED, encoding="utf-8") as fh:
        owed = json.load(fh)
    rows = [r for r in owed["owed"] if r.get("id") == ROW_ID]
    if not rows:
        raise AssertionError(
            "%s is not in owed_executions.json:owed -- if it was retired, this "
            "file retires with it (delete both, in one change)." % ROW_ID)
    return rows[0]


def riders_from_queue():
    """Queue ids whose director ruling routes them onto this pass."""
    out = set()
    for req in _queue()["requests"]:
        director = req.get("director") or {}
        if director.get("owed_row") == ROW_ID:
            out.add(req["id"])
    return out


def needles_that_are_queue_ids(row):
    return {n for n in row["done_when"]["contains"] if QUEUE_ID.match(n)}


class NeedlesAndRidersAgree(unittest.TestCase):
    def test_every_rider_is_pinned(self):
        """The drift that happened: hero-38/39/40 ruled onto the pass, never pinned."""
        missing = sorted(riders_from_queue() - needles_that_are_queue_ids(_row()))
        self.assertEqual(
            missing, [],
            "ruled onto %s but absent from its done_when.contains: %s -- the leg "
            "would read DONE without ever asking for these readings" % (ROW_ID, missing))

    def test_every_queue_shaped_needle_is_a_rider(self):
        """The mirror: a needle nobody owes keeps the leg red forever."""
        orphans = sorted(needles_that_are_queue_ids(_row()) - riders_from_queue())
        self.assertEqual(
            orphans, [],
            "pinned in %s but no queue row carries director.owed_row=%s: %s"
            % (ROW_ID, ROW_ID, orphans))

    def test_the_pass_is_not_empty(self):
        """A vacuous pass would satisfy both equalities above.

        Written in the failure direction on purpose: `set() == set()` is the
        one reading that makes this whole file agree with anything.
        """
        self.assertGreaterEqual(len(riders_from_queue()), 2)


class TheRowStillPointsAtTheArtefact(unittest.TestCase):
    def test_done_when_kind_and_path(self):
        """Renaming the artefact is allowed to hurt -- it must not be silent.

        The row's own ruling says the path is the only machine key this leg can
        read, so a rename turns a delivered ruling into an unclaimed new row.
        """
        row = _row()
        self.assertEqual(row["done_when"]["kind"], "path_contains_all")
        self.assertEqual(row["done_when"]["path"], ARTEFACT)

    def test_riders_deliverable_matches_the_row_path(self):
        """A rider that names a different deliverable is pinned to the wrong file.

        The test is `startswith`, not equality, because one legacy row
        (hero-31, the ruling that opened this pass) writes the path AND the
        reason the path is part of the ruling into the same field.  Prose after
        the path is fine; a DIFFERENT path in front of it is not, which is the
        failure this buys -- a rename of the artefact must not be able to enter
        through a rider's field while the row still points at the old name.
        """
        wrong = []
        for req in _queue()["requests"]:
            director = req.get("director") or {}
            if director.get("owed_row") != ROW_ID:
                continue
            deliverable = director.get("deliverable")
            if deliverable is not None and not deliverable.startswith(ARTEFACT):
                wrong.append((req["id"], deliverable[:120]))
        self.assertEqual(wrong, [], "riders naming a deliverable other than %s: %s"
                         % (ARTEFACT, wrong))


if __name__ == "__main__":
    unittest.main()
