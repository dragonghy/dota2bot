#!/usr/bin/env python3
"""Pins for `slotarb_domain.py` -- the traps this reading can fail silently on.

Not a re-run of the tool's own `--selfcheck` (that pins the source facts and the
arbitration arithmetic).  This file pins the properties that, if they broke,
would turn the detector's answer into a plausible WRONG NUMBER:

  1. THE SUBSET DIRECTION.  `closestMember` is seeded with `bot`, so the armed
     scan is a superset of the shipped one and armed's TRUE set is a strict
     SUBSET of shipped's: armed can REFUSE a camp shipped took, never the
     reverse.  Every table in the tool is read with that direction in mind
     ("armed's divergent rate can only sit at or below baseline's"), so an
     implementation that could produce `armed_true and not shipped_true` would
     invert the whole reading.  Asserted over a randomised roster sweep, not on
     one hand-picked frame.

  2. THE TWO MODULES MUST AGREE ON THE SLOT MAPPING.  `slotarb` and `slotdust`
     are the same defect in two functions, and both readings are built on
     `team_slot`.  This file imports the mapping from BOTH and asserts they are
     the same function -- if a future edit "fixes" one, the two ids' numbers
     stop being comparable and nothing else would say so.

  3. THE CAMP SPLIT (found by looking at frames, not aggregates).  In
     `20260903_101254_slot5` crystal_maiden trades with the ancient frog camp at
     t=870..876 and with the wolf camp at t=879.6 -- 3 s later, ~3,000 u away.
     A 12 s trade-gap merges them into ONE episode whose camp is the FIRST one,
     so the decision would be evaluated against a camp the hero merely passed
     through.  Pinned in both directions: one camp stays one decision, two camps
     become two.

  4. LIMIT 5 IS CONSERVATIVE.  A teammate whose position is unknown at the
     decision instant must never count as a witness.  A permissive version
     would inflate the divergence domain -- the number this file's whole
     verdict rests on.

Run: python3 tests/test_slotarb_domain.py
"""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "batch_test", "behavioral"))

import slotarb_domain as sa  # noqa: E402
import slotdust_arbitration as sd  # noqa: E402

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)


def roster_at(positions):
    """Index a synthetic ten-body roster standing at `positions`."""
    by_ent = sa.index_bodies(sa._stand(positions))
    return by_ent, sa.roster(by_ent)


# --- 1. the subset direction, over randomised rosters ----------------------
rng = random.Random(406)
camp = (0.0, 0.0)
flips = {"armed_only": 0, "shipped_only": 0, "both": 0, "neither": 0}
for _ in range(400):
    pos = {}
    for team, pids in ((sd.RADIANT, range(0, 5)), (sd.DIRE, range(5, 10))):
        for pid in pids:
            pos[(team, pid)] = (rng.uniform(-6000, 6000),
                                rng.uniform(-6000, 6000))
    by_ent, tr = roster_at(pos)
    if tr is None:
        continue
    team = rng.choice((sd.RADIANT, sd.DIRE))
    pid = rng.choice(sorted(tr[team]))
    d = sa.decide(by_ent, tr, team, pid, camp, 100.0, {})
    if d is None:
        continue
    if d["armed_true"] and not d["shipped_true"]:
        flips["armed_only"] += 1
    elif d["shipped_true"] and not d["armed_true"]:
        flips["shipped_only"] += 1
    elif d["shipped_true"]:
        flips["both"] += 1
    else:
        flips["neither"] += 1

check(flips["armed_only"] == 0,
      "armed TRUE without shipped TRUE is impossible (subset direction)")
check(flips["shipped_only"] > 0,
      "the divergent cell is REACHABLE on random rosters (a stand that can "
      "never diverge would pass the line above vacuously)")

# --- 2. one slot mapping, shared by both ids -------------------------------
same = all(sa.team_slot(t, p) == sd.team_slot(t, p)
           for t, pids in ((sd.RADIANT, range(0, 5)), (sd.DIRE, range(5, 10)))
           for p in pids)
check(same, "slotarb and slotdust use the SAME pid->slot mapping")
check(sa.unreached_pids(sd.RADIANT) == {4}
      and sa.unreached_pids(sd.DIRE) == {5, 6, 7, 8},
      "the unreached sets are the complements of the shipped scan")
check(sorted(sa.unreached_pids(sd.DIRE)) != sorted(sa.unreached_pids(sd.RADIANT)),
      "the domain is SIDE-DEPENDENT by construction (4 slots vs 1)")

# --- 3. the camp split -----------------------------------------------------
walk = ([sa._snap("npc_dota_hero_h0", 1, sd.RADIANT, 0, -60.0, 0.0, 0.0)] +
        [sa._snap("npc_dota_hero_h0", 1, sd.RADIANT, 0, 100.0 + i,
                  60.0 * i, 0.0) for i in range(61)])
frames = sa.index_bodies(walk)[("npc_dota_hero_h0", 1)]
jungle = {100 + i: [(60.0 * i, 0.0)] for i in range(61)}
check(len(sa.split_by_camp([(105.0, True), (106.0, True)], jungle, frames)) == 1,
      "two blows on one camp stay ONE camp decision")
two = sa.split_by_camp([(105.0, True), (155.0, True)], jungle, frames)
check(len(two) == 2,
      "blows 3,000u apart are TWO camp decisions (the 101254_slot5 defect)")
check(all(part[0] is not None for part in two),
      "each split part carries its own camp centroid")

# --- 4. LIMIT 5 is conservative --------------------------------------------
pos = {(sd.DIRE, 5): (300.0, 0.0),      # slot 1, unreached, closest of all
       (sd.DIRE, 6): (4000.0, 0.0),     # the subject
       (sd.DIRE, 7): (9000.0, 0.0), (sd.DIRE, 8): (9000.0, 1000.0),
       (sd.DIRE, 9): (9000.0, 2000.0)}
for pid in range(0, 5):
    pos[(sd.RADIANT, pid)] = (-9000.0, 1000.0 * pid)
by_ent, tr = roster_at(pos)
d = sa.decide(by_ent, tr, sd.DIRE, 6, camp, 100.0, {})
check(d is not None and d["shipped_true"] and not d["armed_true"],
      "the witness is seen when his position IS known")

hole = [s for s in sa._stand(pos) if not (s["player_id"] == 5
                                          and 97.0 <= s["t"] <= 103.0)]
by_hole = sa.index_bodies(hole)
d2 = sa.decide(by_hole, sa.roster(by_hole), sd.DIRE, 6, camp, 100.0, {})
check(d2 is not None and d2["armed_true"],
      "a teammate with no bracketing sample is NOT counted as closer (LIMIT 5)")

# --- 5. the farm proxy is a NARROWING, never a widening --------------------
trades = {"npc_dota_hero_h5": [99.5]}
d3 = sa.decide(by_ent, tr, sd.DIRE, 6, camp, 100.0, {}, trades)
check(len(d3["closer_farming"]) <= len(d3["closer_unreached"]),
      "div_farm is a subset of div_wide")
d4 = sa.decide(by_ent, tr, sd.DIRE, 6, camp, 100.0, {}, {})
check(not d4["closer_farming"] and d4["closer_unreached"],
      "with no trade evidence the farm column is empty while wide is not")

print("%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  FAIL %s" % f)
sys.exit(1 if failures else 0)
