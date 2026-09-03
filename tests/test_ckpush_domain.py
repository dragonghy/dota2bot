#!/usr/bin/env python3
"""Pins for `ckpush_domain.py` -- the traps this detector family already sprang.

Not a re-run of the tool's own `--selfcheck` (that pins the source constants
and the arithmetic).  This file pins the three CORPUS-shaped mistakes that
cost real rounds in this repo, each of which would turn this detector's answer
into a silent wrong number rather than an error:

  1. GH #176 -- an ILLUSION carries the same hero name and player_id, only
     `idx` differs, and it has no pre-horn sample.  Chaos Knight is the worst
     possible hero for this: Phantasm's whole effect is to CREATE illusions of
     him, so a name-keyed read manufactures extra `chaos_knight` streams at
     exactly the timestamps this detector counts.  If `frames_by_hero` ever
     stops dropping them, the domain count inflates and nothing raises a hand.

  2. LIMIT 4 (grid holes) -- `buildings[]` is 0.2 Hz and `creeps[]` 0.33 Hz
     against a 1 Hz snapshot grid.  A MISSING sample must never read as an
     EMPTY one: "no tower block within 2.5 s" is unknown, not "no tower".  The
     charter's `pullcamp`/`fieldbuy` family has produced a SILENT verdict from
     exactly this substitution before.

  3. The SELECTION direction.  `ckpush` armed returns the LARGER threshold
     (480), so the armed leg is the RESTRICTIVE one.  A reader who assumes
     "armed = more behaviour" reads the whole table backwards.  Pinned as an
     assertion on the tool's constants so a source edit that flips the
     selection cannot pass silently.

Run: python3 tests/test_ckpush_domain.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "batch_test", "behavioral"))

import ckpush_domain as ck  # noqa: E402
import entities as ent  # noqa: E402

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)


def snap(idx, t, x=0.0, y=0.0, ph_level=1, cd=0.0, team=2):
    return {
        "idx": idx, "t": t, "hero": "npc_dota_hero_chaos_knight", "team": team,
        "x": x, "y": y, "hp": 600, "hp_pct": 1.0, "mp_pct": 1.0, "level": 12,
        "items": [],
        "abilities": [{"name": ck.PHANTASM, "level": ph_level, "cd": cd, "cd_len": 45}],
    }


def game(ck_snaps, buildings, creeps, events=()):
    return {
        "snapshots": list(ck_snaps),
        "buildings": list(buildings),
        "creeps": list(creeps),
        "events": list(events),
    }


def tower(t, x, y, team=3):
    return {"t": t, "name": "tower", "team": team, "x": x, "y": y,
            "hp": 1800, "hp_pct": 1.0, "alive": True}


def creep(t, x, y, team=2):
    return {"t": t, "team": team, "x": x, "y": y}


# --------------------------------------------------------------------------
# 3. SELECTION DIRECTION -- armed is the restrictive leg.
# --------------------------------------------------------------------------
check(ck.BAND_LO == 240, "shipped (gate-off) threshold is 8*30 = 240")
check(ck.BAND_HI == 480, "armed threshold is 8*60 = 480")
check(ck.BAND_HI > ck.BAND_LO,
      "armed returns the LARGER threshold => arming REMOVES push-Phantasm "
      "from the band; a table read as 'armed = more' is read backwards")

# The radii are the source's, not this file's opinion.
check((ck.R_TOWER, ck.R_RAX, ck.R_CREEP, ck.N_CREEP) == (700.0, 400.0, 1000.0, 2),
      "source radii 700/400/1000 and the >=2 creep count")

# --------------------------------------------------------------------------
# A baseline positive: one frame that satisfies every observable conjunct.
# Everything below perturbs exactly one thing away from this frame, so a
# failure names its own cause.
# --------------------------------------------------------------------------
BASE = game(
    [snap(1, -30.0), snap(1, 300.0, 100.0, 0.0)],
    [tower(300.0, 400.0, 0.0), {"t": 300.0, "name": "ancient", "team": 2,
                                "x": -9000.0, "y": -9000.0, "hp": 4500,
                                "hp_pct": 1.0, "alive": True}],
    [creep(300.0, 150.0, 0.0), creep(300.0, 160.0, 10.0)],
)
r = ck.analyse_game(BASE)
check(r["has_ck"], "baseline: chaos_knight found")
check(len(r["domain"]) == 1, "baseline: exactly one domain frame (got %d)" % len(r["domain"]))
if r["domain"]:
    check(r["domain"][0]["n_tower"] == 1, "baseline: the enemy tower is counted")
    check(r["domain"][0]["n_creep"] == 2, "baseline: both allied creeps counted")

# --------------------------------------------------------------------------
# 1. GH #176 -- Phantasm's own illusions must not become domain frames.
#    Same name, same team, no pre-horn sample; only `idx` differs.
# --------------------------------------------------------------------------
ILLU = game(
    [snap(1, -30.0), snap(1, 300.0, 100.0, 0.0),
     snap(7, 300.0, 105.0, 5.0), snap(9, 300.0, 110.0, 10.0)],
    BASE["buildings"], BASE["creeps"],
)
r_illu = ck.analyse_game(ILLU)
check(len(r_illu["domain"]) == 1,
      "GH #176: two Phantasm illusions at the same timestamp add ZERO domain "
      "frames (got %d, expected 1)" % len(r_illu["domain"]))

# And the drop is the PRE-HORN rule, not an hp or motion rule: an illusion at
# full health that moves is still dropped, which is the discriminator
# entities.py documents.
fr, _ = ent.frames_by_hero(ILLU)
check(len(fr.get(ck.CK)) == 2, "GH #176: only the pre-horn stream survives")

# --------------------------------------------------------------------------
# 2. LIMIT 4 -- a missing grid sample is UNKNOWN, never EMPTY.
# --------------------------------------------------------------------------
# (a) building grid hole: the nearest block is 10 s away, outside the 2.5 s
#     slack.  The frame must be counted as "no sample", NOT silently rejected
#     as "no tower nearby" -- the two have opposite meanings for a SILENT
#     verdict.
HOLE_B = game([snap(1, -30.0), snap(1, 300.0, 100.0, 0.0)],
              [tower(280.0, 400.0, 0.0)], BASE["creeps"])
r_hb = ck.analyse_game(HOLE_B)
check(r_hb["no_building_sample"] == 1,
      "LIMIT 4: a building grid hole is reported, not swallowed")
check(len(r_hb["domain"]) == 0, "LIMIT 4: a grid hole yields no domain frame")

# (b) creep grid hole, same shape one conjunct later.
HOLE_C = game([snap(1, -30.0), snap(1, 300.0, 100.0, 0.0)],
              BASE["buildings"], [creep(280.0, 150.0, 0.0)])
r_hc = ck.analyse_game(HOLE_C)
check(r_hc["no_creep_sample"] == 1,
      "LIMIT 4: a creep grid hole is reported, not swallowed")

# (c) the discrimination that makes (a)/(b) meaningful: a block that IS present
#     and genuinely empty must reject WITHOUT incrementing the hole counter.
EMPTY = game([snap(1, -30.0), snap(1, 300.0, 100.0, 0.0)],
             [tower(300.0, 9000.0, 9000.0)], BASE["creeps"])
r_e = ck.analyse_game(EMPTY)
check(r_e["no_building_sample"] == 0 and len(r_e["domain"]) == 0,
      "LIMIT 4: a present-but-empty block rejects without counting as a hole")

# --------------------------------------------------------------------------
# Band edges are OPEN, and a learned-but-cooling Phantasm is out of the domain
# while still counting as learned (the two are different questions).
# --------------------------------------------------------------------------
for t_edge in (240.0, 480.0):
    g = game([snap(1, -30.0), snap(1, t_edge, 100.0, 0.0)],
             [tower(t_edge, 400.0, 0.0)], [creep(t_edge, 150.0, 0.0),
                                           creep(t_edge, 160.0, 10.0)])
    check(len(ck.analyse_game(g)["domain"]) == 0,
          "band edge t=%.0f is outside the disagreement band" % t_edge)

COOL = game([snap(1, -30.0), snap(1, 300.0, 100.0, 0.0, cd=12.0)],
            BASE["buildings"], BASE["creeps"])
r_cool = ck.analyse_game(COOL)
check(r_cool["learned"] == 1 and r_cool["ready"] == 0,
      "a cooling Phantasm counts as LEARNED but not READY")

UNLEARNED = game([snap(1, -30.0), snap(1, 300.0, 100.0, 0.0, ph_level=0)],
                 BASE["buildings"], BASE["creeps"])
check(ck.analyse_game(UNLEARNED)["learned"] == 0,
      "level 0 Phantasm is not learned")

# --------------------------------------------------------------------------
# The source-comment claim is measured, not assumed: a learn at or below 240
# must be COUNTED rather than dropped, or the census can never falsify it.
# --------------------------------------------------------------------------
EARLY = game([snap(1, -30.0, ph_level=0), snap(1, 200.0, 100.0, 0.0),
              snap(1, 300.0, 100.0, 0.0)],
             BASE["buildings"], BASE["creeps"])
r_early = ck.analyse_game(EARLY)
check(r_early["learned_at_or_below_lo"] == 1,
      "a learned Phantasm at t=200 is counted against the source comment's claim")
check(r_early["first_learn_t"] == 200.0, "first_learn_t is the earliest learned frame")

print("%d PASS / %d FAIL" % (checks - len(failures), len(failures)))
for f in failures:
    print("  FAIL", f)
sys.exit(0 if not failures else 1)
