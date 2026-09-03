#!/usr/bin/env python3
"""Pins for `slotpush_domain.py` -- the traps this reading can fail silently on.

Not a re-run of the tool's `--selfcheck` (that pins the source constants and
the two scan tables).  This file pins the properties that, if they broke, would
turn the detector's answer into a plausible WRONG NUMBER:

  1. THE SUBSET DIRECTION, AND WHY IT IS ONLY ALMOST TRUE.  The armed scan
     reads all five members, the shipped scan a side-dependent subset, so on
     any frame where every consulted member is ALIVE the shipped TRUE set is a
     subset of the armed one and `over` (shipped TRUE, armed FALSE) is
     impossible.  The corpus reading reported `over = 0` in 247k frames -- this
     file is what makes that a MEASUREMENT rather than a tautology, by pinning
     the one construction that could produce it (a dead member) as `ind` and
     never as a silent False.  Asserted over a randomised sweep, not one frame.

  2. THE THREE MODULES MUST AGREE ON THE SLOT MAPPING.  `slotarb`, `slotdust`
     and `slotpush` are the same defect in three functions and all three
     readings are built on `team_slot`.  If a future edit "fixes" one mapping,
     the three ids' numbers quietly stop being comparable and nothing else in
     the tree would say so.

  3. THE SIDE RATIO IS ARITHMETIC, NOT A FITTED NUMBER.  Radiant loses one of
     five scan slots, dire four of five.  The corpus reads 22x, and the reason
     it is not `slotarb`'s 4:1 is that this predicate is an OR over members
     (4-of-5 loses almost nothing, 1-of-5 loses most of it) while `slotarb` is
     a nearest-member SELECTION.  Pinned as a property of the scan tables so
     the report's explanation cannot drift from the code.

  4. TOWER TIERS ARE DERIVED, AND A MAP THAT DOES NOT SEPARATE MUST RAISE.
     `Map` classifies towers by rank of distance from their OWN ancient.  A
     silent misclassification would move the T2 ring (2000 u) onto a T1 tower
     and inflate every count.  Pinned: 11 towers per team, the 5/3/3 partition,
     the strict gaps, and that a malformed census raises instead of guessing.

  5. THE ALLY COUNT EXCLUDES SELF.  `GetNearbyHeroes` does (tests/mock/
     replay_fixture.lua:1063, `other ~= self`).  Counting self would turn the
     shipped `>= 2` into an effective `>= 1` and roughly double the domain.

Run: python3 tests/test_slotpush_domain.py
"""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "batch_test", "behavioral"))

import slotarb_domain as sa            # noqa: E402
import slotdust_arbitration as sd      # noqa: E402
import slotpush_domain as sp           # noqa: E402

checks = 0
failures = []


def check(cond, name):
    global checks
    checks += 1
    if not cond:
        failures.append(name)


FACTS = sp.gate_facts()
BUILDS, ANC, _RINGS = sp._fake_buildings()
MAP = sp.Map(BUILDS)
R = FACTS["ally_radius"]

# --- 1. the subset direction, over a randomised sweep -----------------------
random.seed(415)
saw_under = saw_ind = saw_agree = 0
for _ in range(4000):
    team = random.choice((sp.RADIANT, sp.DIRE))
    pids = list(range(0, 5) if team == sp.RADIANT else range(5, 10))
    pos = {}
    for pid in pids:
        if random.random() < 0.15:
            continue                                   # dead
        anchor = random.choice(MAP.t2[sp.enemy(team)] + MAP.hg[sp.enemy(team)]
                               + [(0.0, 0.0), (9000.0, -9000.0)])
        pos[pid] = (anchor[0] + random.uniform(-2500, 2500),
                    anchor[1] + random.uniform(-2500, 2500))
    armed, shipped, ind = sp.evaluate(pos, team, 0.0, MAP, FACTS, R)
    if shipped and not armed:
        failures.append("over-direction produced on a frame with no dead "
                        "member consulted (team %d, pos %r)" % (team, pos))
        break
    if armed and not shipped and not ind:
        saw_under += 1
    if ind:
        saw_ind += 1
    if armed and shipped:
        saw_agree += 1
checks += 1
check(saw_under > 0, "the sweep actually produced UNDER frames")
check(saw_ind > 0, "the sweep actually produced indeterminate frames")
check(saw_agree > 0, "the sweep actually produced agreeing frames")

# A dead member must be `ind`, never a silent False: that is the ONLY way the
# corpus `over = 0` can be a measurement instead of a definition.
dead_member = {1: (0.0, 0.0), 2: (0.0, 0.0), 3: (0.0, 0.0), 4: (0.0, 0.0)}
_, _, ind0 = sp.evaluate(dead_member, sp.RADIANT, 0.0, MAP, FACTS, R)
check(ind0, "a dead consulted member marks the frame indeterminate")
check(sp.member_condition({}, sp.RADIANT, 0, 0.0, MAP, FACTS, R) is None,
      "an absent member yields None, distinguishable from False")

# --- 2. the three modules agree on the slot mapping -------------------------
check(sp.team_slot is sd.team_slot,
      "slotpush_domain imports the slot mapping, it does not restate it")
check(sa.team_slot is sd.team_slot,
      "slotarb_domain imports the same slot mapping")
check(all(sd.team_slot(sp.RADIANT, p) == p + 1 for p in range(5))
      and all(sd.team_slot(sp.DIRE, p) == p - 4 for p in range(5, 10)),
      "the shared mapping is still pid -> 1..5 per side")

# --- 3. the side ratio is arithmetic ----------------------------------------
r_ship = {m for _, m in sp.shipped_scan(sp.RADIANT)}
d_ship = {m for _, m in sp.shipped_scan(sp.DIRE)}
check(len(r_ship) == 4 and len(d_ship) == 1,
      "radiant loses one of five scan slots, dire four of five")
check(r_ship == {0, 1, 2, 3} and d_ship == {9},
      "the reachable member sets are exactly the ones the report names")
check(all(g != m for g, m in sp.shipped_scan(sp.RADIANT)),
      "every radiant shipped pair asks the guard about a DIFFERENT hero")
check(sp.shipped_scan(sp.DIRE) == [(5, 9)],
      "the one dire pair guards on pid 5 and reads pid 9")
check(all(g == m for g, m in sp.armed_scan(sp.RADIANT))
      and all(g == m for g, m in sp.armed_scan(sp.DIRE)),
      "armed pairs every guard with its own subject")

# The OR shape: one satisfying member anywhere in the roster is enough for
# armed.  Put the satisfier on each slot in turn and count how often each
# scan sees it -- 4/5 for radiant, 1/5 for dire, which IS the ratio claim.
seen = {}
for team in (sp.RADIANT, sp.DIRE):
    hit = 0
    pids = list(range(0, 5) if team == sp.RADIANT else range(5, 10))
    anchor = MAP.t2[sp.enemy(team)][0]
    for star in pids:
        pos = {p: (30000.0 + 10 * p, 30000.0) for p in pids}
        pos[star] = anchor
        for mate in pids:
            if mate != star:
                pos[mate] = (anchor[0] + 150 * (mate - star), anchor[1])
                if sum(1 for q in pos.values()
                       if sp.dist(anchor[0], anchor[1], q[0], q[1]) <= R) >= 3:
                    break
        armed, shipped, _ = sp.evaluate(pos, team, 0.0, MAP, FACTS, R)
        check(armed, "armed sees a satisfier on slot %d (team %d)"
              % (sp.team_slot(team, star), team))
        if shipped:
            hit += 1
    seen[team] = hit
check(seen[sp.RADIANT] > seen[sp.DIRE],
      "the shipped scan sees a lone satisfier far more often on radiant")

# --- 4. tower tiers are derived, and a broken census raises -----------------
for team in (sp.RADIANT, sp.DIRE):
    own = MAP.ancient[team]
    hg = sorted(sp.dist(p[0], p[1], own[0], own[1]) for p in MAP.hg[team])
    t2 = sorted(sp.dist(p[0], p[1], own[0], own[1]) for p in MAP.t2[team])
    check(len(MAP.hg[team]) == sp.N_HIGH_GROUND
          and len(MAP.t2[team]) == sp.N_SECOND_TIER,
          "team %d partitions 5 high-ground / 3 second-tier" % team)
    check(hg[-1] < t2[0],
          "team %d high-ground ring is strictly inside the second tier" % team)
    check(not set(MAP.hg[team]) & set(MAP.t2[team]),
          "team %d tiers are disjoint" % team)
check(FACTS["n_high_ground"] == sp.N_HIGH_GROUND
      and FACTS["n_second_tier"] == sp.N_SECOND_TIER,
      "the tier sizes are read off utils.lua, not assumed")

raised = False
try:
    sp.Map([b for b in BUILDS if not (b["name"] == "tower"
                                      and b["team"] == sp.DIRE)])
except ValueError:
    raised = True
check(raised, "a team with the wrong tower count raises instead of guessing")

# Eleven DISTINCT towers per team whose radii are strictly increasing but
# barely so: rank alone would happily "classify" them.  The first draft of
# this assertion put all eleven at one point, which collapsed the position
# census and raised on the COUNT -- it passed for the wrong reason, and a
# mutation that deleted the separation guard survived because of it.
out = []
for team in (sp.RADIANT, sp.DIRE):
    for i in range(11):
        out.append(sp._b(0.0, "tower", team, ANC[team][0] + 4000.0 + 10.0 * i,
                         ANC[team][1]))
    out.append(sp._b(0.0, "ancient", team, ANC[team][0], ANC[team][1]))
raised2 = False
try:
    sp.Map(out)
except ValueError as exc:
    raised2 = 'do not separate' in str(exc)
check(raised2, "ranked noise raises on the SEPARATION check, not the count")

# The separation guard has TWO floors and they must each be load-bearing on
# their own -- a mutation that zeroed the absolute one survived the first
# draft, because the fractional floor happened to catch the same map.  This
# map has 5% relative gaps (frac floor passes) but 50 u absolute ones.
tight = []
for team in (sp.RADIANT, sp.DIRE):
    for i in range(11):
        tight.append(sp._b(0.0, "tower", team, ANC[team][0] + 1000.0 + 50.0 * i,
                           ANC[team][1]))
    tight.append(sp._b(0.0, "ancient", team, ANC[team][0], ANC[team][1]))
raised3 = False
try:
    sp.Map(tight)
except ValueError as exc:
    raised3 = 'do not separate' in str(exc)
check(raised3, "the ABSOLUTE gap floor catches a map the fractional one lets by")

# ...and the mirror case, so neither floor can be deleted unnoticed: 150 u
# gaps clear the absolute floor but are 0.75% of a 20,000 u radius.
loose = []
for team in (sp.RADIANT, sp.DIRE):
    for i in range(11):
        loose.append(sp._b(0.0, "tower", team,
                           ANC[team][0] + 20000.0 + 150.0 * i, ANC[team][1]))
    loose.append(sp._b(0.0, "ancient", team, ANC[team][0], ANC[team][1]))
raised4 = False
try:
    sp.Map(loose)
except ValueError as exc:
    raised4 = 'do not separate' in str(exc)
check(raised4, "the FRACTIONAL gap floor catches a map the absolute one lets by")


# --- 4b. the three range clauses are separate, and each one binds -----------
# The toy map in _fake_buildings is too crowded to isolate them: a hero near a
# tier-2 tower is also near a high-ground tower, so a mutation that widened the
# high-ground ring to infinity SURVIVED the first draft of this file.  This map
# strings each team's eleven towers along one axis so the three rings can be
# entered one at a time.
def _line_map():
    out = []
    radii = [800, 900, 2400, 2500, 2600, 8000, 8100, 8200, 20000, 20100, 20200]
    for team in (sp.RADIANT, sp.DIRE):
        sgn = 1 if team == sp.DIRE else -1
        for d in radii:
            out.append(sp._b(0.0, "tower", team, ANC[team][0] + sgn * d,
                             ANC[team][1]))
        out.append(sp._b(0.0, "ancient", team, ANC[team][0], ANC[team][1]))
    return sp.Map(out)


LM = _line_map()
check(len(LM.hg[sp.DIRE]) == 5 and len(LM.t2[sp.DIRE]) == 3,
      "the line map partitions the same way")
hg_far = max(LM.hg[sp.DIRE], key=lambda p: p[0])          # dire ancient +2600
for dy, want, why in ((2500.0, True, "inside"), (3500.0, False, "outside")):
    who = (hg_far[0], hg_far[1] - dy)
    pos = {0: who, 1: (who[0] + 80, who[1]), 2: (who[0] - 80, who[1]),
           3: (-40000.0, 0.0), 4: (-40000.0, 0.0)}
    got = sp.member_condition(pos, sp.RADIANT, 0, 0.0, LM, FACTS, R)
    check(got is want,
          "a hero %s the 3000 u high-ground ring and nothing else reads %s"
          % (why, want))

wide, _, _ = sp._fake_buildings()
check(sp.Map(wide) is not None, "the well-separated map still loads")

# --- 5. the ally count excludes self ----------------------------------------
anchor = MAP.t2[sp.DIRE][0]
solo = {p: (30000.0, 30000.0) for p in range(5)}
solo[0] = anchor
check(sp.member_condition(solo, sp.RADIANT, 0, 0.0, MAP, FACTS, R) is False,
      "one hero alone on the tower fails >= 2 (self is not an ally)")
solo[1] = (anchor[0] + 50, anchor[1])
check(sp.member_condition(solo, sp.RADIANT, 0, 0.0, MAP, FACTS, R) is False,
      "one hero plus one ally still fails >= 2")
solo[2] = (anchor[0] - 50, anchor[1])
check(sp.member_condition(solo, sp.RADIANT, 0, 0.0, MAP, FACTS, R) is True,
      "two allies pass")

# --- 6. the radius is read from the tree, and LIMIT 3 is bounded ------------
check(FACTS["ally_radius"] == 2000 and FACTS["ally_min"] == 2,
      "the shipped call really is GetNearbyHeroes(2000, false) >= 2")
far = {0: anchor, 1: (anchor[0] + 1800, anchor[1]),
       2: (anchor[0] - 1800, anchor[1]), 3: (30000.0, 0.0), 4: (30000.0, 0.0)}
check(sp.member_condition(far, sp.RADIANT, 0, 0.0, MAP, FACTS, 2000) is True
      and sp.member_condition(far, sp.RADIANT, 0, 0.0, MAP, FACTS,
                              1600) is False,
      "the 1600 cap (LIMIT 3) changes this frame, so the flag really bites")

# --- 7. episodes and the ward readout ---------------------------------------
rows = [{"t": float(t), "team": sp.DIRE, "armed": a, "shipped": False,
         "ind": False, "n_alive": 5}
        for t, a in [(10, True), (11, True), (12, True), (20, True),
                     (30, False), (31, True)]]
eps = sp.episodes(rows, sp.DIRE)
check(eps == [(10.0, 12.0, 3), (20.0, 20.0, 1), (31.0, 31.0, 1)],
      "episodes cut on the 3 s gap and keep their lengths")
tl = {"wards": [{"team": sp.DIRE, "type": "observer", "t_start": 11.0},
                {"team": sp.DIRE, "type": "sentry", "t_start": 500.0},
                {"team": sp.RADIANT, "type": "observer", "t_start": 11.0}]}
hit, total, span = sp.consequence(tl, rows, sp.DIRE)
check((hit, total) == (1, 2),
      "only this team's wards count, and only those inside a window")
check(abs(span - 5.0) < 1e-9,
      "the window span is the summed episode length, inclusive")

print("%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  FAIL %s" % f)
sys.exit(1 if failures else 0)
