#!/usr/bin/env python3
"""Pins for `wandbleed_trigger.py`'s LIMIT 7 (liveness) and LIMIT 8 (4000 ring).

WHAT THIS FILE EXISTS TO STOP.  On 2026-09-04 the W44 sweep produced TWO
"exclusive-domain wandbleed firings" on the armed leg.  One was real; the other
was manufactured by the reader itself, and the reader had no way to say so:

  20260904_003457_slot3 (run ...3a74c4, seed 3749), pudge t=1064.20, hp_pct
  0.388, ONE charge drunk.  `npc_dota_hero_skeleton_king` stood 299.6 u away
  at hp=1 / hp_pct=0.0 under `modifier_skeleton_king_reincarnation_scepter_
  active` (added t=1062.8, removed t=1068.8 together with his DEATH event),
  moving (-2736,4044 -> -2197,4159), phase-booting at t=1065.4 and burning
  pudge with radiance on every 1.0 s tick.  `entities.alive_at` -- the repo's
  death-EVENT-anchored liveness -- answers ALIVE for him on that frame.

The old corpse filter was `hp_pct <= 0`, so it deleted him: the 1000 ring read
5464.8 u (the next enemy) instead of 299.6 u, and a 用途1 cast was promoted
into the column the script exists to count.  ONE charge is independently fatal
to that promotion -- the gate's own floor is five -- so the row was internally
contradictory and still passed.

THE MECHANISM IS IN THE DUMPER AND IS PINNED BELOW: `hp_pct` is emitted through
`round3`, so anything under 0.05% of the max pool reads as exactly 0.0, while
`hp` is emitted raw.  The dumper was carrying the fact the reader threw away.

DIRECTION.  This is the OPPOSITE error to GH #78 / #176, which are about a
corpse leaking through an `hp_pct > 0` filter as if alive.  Nobody had measured
the other side: a LIVING hero deleted as a corpse.  Census over the 25 W44
games swept that round -- 87 alive-but-zero-`hp_pct` rows across 19 of the 25
games, every one of them at hp == 1, 57 of them Wraith King.

Run: python3 tests/test_wandbleed_trigger_liveness.py
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "batch_test", "behavioral"))

import wandbleed_trigger as wb  # noqa: E402

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)


# --------------------------------------------------------------------------
# 1.  The mechanism, read off the dumper rather than transcribed: hp_pct is
#     ROUNDED to three decimals and hp is not.  If the dumper ever stops
#     rounding, this test should be the thing that notices, because LIMIT 7's
#     whole argument rests on the rounding.
# --------------------------------------------------------------------------
DUMPER = open(os.path.join(REPO, "tools", "batch_test", "behavioral",
                           "dumper", "main.go"), encoding="utf-8").read()
check(re.search(r"HPPct:\s*round3\(hpPct\)", DUMPER) is not None,
      "the dumper emits hp_pct through round3()")
check(re.search(r"HP:\s*h\.hp\b", DUMPER) is not None,
      "the dumper emits hp RAW, so the exact value survives the rounding")
ROUND3 = re.search(r"func round3\(v float64\) float64 \{\s*\n\s*return ([^\n]+)",
                   DUMPER)
check(ROUND3 is not None and "1000" in ROUND3.group(1),
      "round3 is a three-decimal rounding, i.e. hp/maxhp < 0.0005 reads 0.0")

# Wraith King's real pool on the frame above was 3293, and his hp was 1.
check(round(1 / 3293.0, 3) == 0.0,
      "1 HP out of the measured 3293 max rounds to exactly 0.0")

# --------------------------------------------------------------------------
# 2.  is_live: hp and hp_pct are BOTH consulted, and a true corpse still dies.
#     The second half matters as much as the first -- a fix that swallowed
#     LIMIT 3 (frozen post-death illusion streams) while curing LIMIT 7 would
#     trade a manufactured firing for a missed one, with nothing red.
# --------------------------------------------------------------------------
check(wb.is_live({"hp": 1, "hp_pct": 0.0}),
      "a hero at 1 HP (hp_pct rounded to 0.0) is LIVE")
check(not wb.is_live({"hp": 0, "hp_pct": 0.0}),
      "a corpse (hp == 0 AND hp_pct == 0) is not live")
check(wb.is_live({"hp": 0, "hp_pct": 0.4}),
      "a row carrying only hp_pct is still live (older timelines)")
check(not wb.is_live({}), "a row carrying neither field is not live")


# --------------------------------------------------------------------------
# 3.  The real frame, rebuilt from its measured numbers.  With the 1-HP body
#     present the cast is 用途1; with it deleted the reader invents exactly
#     the row LIMIT 6 says it must never invent.
# --------------------------------------------------------------------------
D_SK = 299.6        # skeleton_king's measured distance from pudge
D_NEXT = 5464.8     # the next enemy (dragon_knight) -- what the old filter saw
T_CAST = 1064.2
T_FRAME = 1063.4


def body(hero, idx, team, t, hp, hp_pct, x=0.0):
    return {"t": t, "hero": hero, "idx": idx, "team": team, "x": x, "y": 0.0,
            "hp": hp, "hp_pct": hp_pct, "mp": 500, "items": [""] * 9}


def w44_frame(sk_hp):
    """The pudge cast with skeleton_king at `sk_hp` HP, everything else real."""
    snaps = []
    for t in (-30.0, T_FRAME, T_CAST + 0.2):
        snaps.append(body("pudge", 150, 2, t, 977, 0.388))
        snaps.append(body("dragon_knight", 1315, 3, t, 2493, 0.99, x=D_NEXT))
        snaps.append(body("skeleton_king", 1387, 3, t, sk_hp,
                          round(sk_hp / 3293.0, 3), x=D_SK))
    ev = [{"t": 1063.4, "type": "DAMAGE", "actor": "skeleton_king",
           "target": "pudge", "actor_hero": True, "target_hero": True,
           "inflictor": "skeleton_king_hellfire_blast", "value": 11},
          {"t": T_CAST, "type": "ITEM", "actor": "pudge", "target": "pudge",
           "inflictor": "item_magic_wand", "value": 0},
          {"t": T_CAST, "type": "HEAL", "actor": "pudge", "target": "pudge",
           "inflictor": "item_magic_wand", "value": 15}]
    return {"snapshots": snaps, "events": ev}


alive = wb.scan_game(w44_frame(1), "radiant")[0]["armed"]
check(alive["exclusive"] == 0 and alive["blocked_enemy_in_1000"] == 1,
      "the real W44 frame is 用途1 once the 1-HP enemy is kept")

# The regression itself: force the pre-fix filter back on and watch the row
# appear.  This is a MUTATION of the guard, not a second code path -- if the
# guard is ever weakened back to hp_pct alone, this check goes red.
saved = wb.is_live
try:
    wb.is_live = lambda s: (s.get("hp_pct") or 0) > 0
    ghost = wb.scan_game(w44_frame(1), "radiant")[0]["armed"]
finally:
    wb.is_live = saved
check(ghost["exclusive"] == 1,
      "with the pre-fix hp_pct-only filter the SAME frame invents a firing")
check(alive["exclusive"] < ghost["exclusive"],
      "the fix removes firings, never adds them (the conservative direction)")

# A genuine corpse at the same spot must NOT block the cast, or the frame
# would stop being able to tell the two apart at all.
dead = wb.scan_game(w44_frame(0), "radiant")[0]["armed"]
check(dead["exclusive"] == 1,
      "a corpse standing at 299.6 u does not block the cast")

# --------------------------------------------------------------------------
# 4.  The one-charge contradiction that the row carried all along.  The gate
#     needs five charges; the drink delivered 15 HP against a pool missing
#     ~1540, i.e. one charge, uncapped.  Read the floor off the Lua branch so
#     a source edit cannot leave this argument behind.
# --------------------------------------------------------------------------
GEN = open(os.path.join(REPO, "bots", "ability_item_usage_generic.lua"),
           encoding="utf-8").read()
GATE = re.search(r"J\.IsSoakCandidate\('wandbleed'\)\s*\n\s*and nHPrate < "
                 r"([0-9.]+) and nCharges >= (\d+)", GEN)
check(GATE is not None, "the wandbleed branch's own clause is still findable")
if GATE:
    check(float(GATE.group(1)) == wb.HP_MAX,
          "HP_MAX mirrors the branch's nHPrate ceiling")
    check(int(GATE.group(2)) == 5,
          "the branch's charge floor is 5, so a 1-charge drink is not this gate")

# --------------------------------------------------------------------------
# 5.  LIMIT 8: SOURCE_RING is J.IsWandBleedSourcePresent's ring, read from the
#     Lua rather than transcribed, and an empty ring is what the counter counts.
# --------------------------------------------------------------------------
JMZ = open(os.path.join(REPO, "bots", "FunLib", "jmz_func.lua"),
           encoding="utf-8").read()
SRC_FN = re.search(r"function J\.IsWandBleedSourcePresent\( bot \)(.*?)\nend",
                   JMZ, re.S)
check(SRC_FN is not None, "J.IsWandBleedSourcePresent is still a function")
if SRC_FN:
    ring = re.search(r"GetNearbyHeroes\(\s*bot,\s*([0-9.]+),", SRC_FN.group(1))
    check(ring is not None and float(ring.group(1)) == wb.SOURCE_RING,
          "SOURCE_RING mirrors the Lua ring (4000), not a number typed here")
    check(">= 1" in SRC_FN.group(1),
          "the predicate is 'at least one live enemy inside the ring'")


def residue_at(distance):
    """One clean exclusive cast whose nearest live enemy sits at `distance`."""
    snaps = []
    for t in (-30.0, 10.0, 11.0):
        snaps.append(body("cm", 1, 2, t, 300, 0.30))
        snaps.append(body("lina", 2, 3, t, 1000, 1.0, x=distance))
    ev = [{"t": 9.5, "type": "DAMAGE", "actor": "lina", "target": "cm",
           "actor_hero": True, "target_hero": True, "inflictor": "x"},
          {"t": 10.5, "type": "ITEM", "actor": "cm", "target": "cm",
           "inflictor": "item_magic_wand", "value": 0}]
    return wb.scan_game({"snapshots": snaps, "events": ev},
                        "radiant")[0]["armed"]


near = residue_at(3999.0)
check(near["exclusive"] == 1 and near["wandbleed2_source_absent"] == 0,
      "a live enemy just inside 4000 is a PRESENT source")
far = residue_at(8381.0)   # the GH #437 desk frame's residue distance
check(far["exclusive"] == 1 and far["wandbleed2_source_absent"] == 1,
      "the GH #437 residue distance (8381 u) is an ABSENT source")
edge = residue_at(4000.0)
# The boundary itself counts as INSIDE here.  That is this reader's stated
# convention, not a measured claim about the engine's radius comparison: an
# enemy at exactly 4000.0 u is a distance no corpus row has ever produced, and
# the convention is chosen to make "source absent" the strictly harder verdict.
check(edge["wandbleed2_source_absent"] == 0,
      "exactly 4000 counts as inside, so ABSENT stays the harder verdict")

# The two limits meet here: the deleted 1-HP body is precisely what turns a
# source-PRESENT frame into a source-ABSENT one, and on the ARMED leg that
# reads as a falsification of the narrowing (§DU.5.2) that never happened.
snaps = []
for t in (-30.0, 10.0, 11.0):
    snaps.append(body("cm", 1, 2, t, 300, 0.30))
    snaps.append(body("lina", 2, 3, t, 1000, 1.0, x=8381.0))
    snaps.append(body("sk", 7, 3, t, 1, 0.0, x=2500.0))
ev = [{"t": 9.5, "type": "DAMAGE", "actor": "lina", "target": "cm",
       "actor_hero": True, "target_hero": True, "inflictor": "x"},
      {"t": 10.5, "type": "ITEM", "actor": "cm", "target": "cm",
       "inflictor": "item_magic_wand", "value": 0}]
mixed = wb.scan_game({"snapshots": snaps, "events": ev}, "radiant")[0]["armed"]
check(mixed["exclusive"] == 1 and mixed["wandbleed2_source_absent"] == 0,
      "a 1-HP enemy at 2500 u keeps the source PRESENT (no false falsifier)")
saved = wb.is_live
try:
    wb.is_live = lambda s: (s.get("hp_pct") or 0) > 0
    mixed_ghost = wb.scan_game({"snapshots": json.loads(json.dumps(snaps)),
                                "events": ev}, "radiant")[0]["armed"]
finally:
    wb.is_live = saved
check(mixed_ghost["wandbleed2_source_absent"] == 1,
      "and the pre-fix filter would have booked that frame as a wandbleed2 "
      "falsifier on the armed leg")

print("%d PASS / %d FAIL" % (checks - len(failures), len(failures)))
for f in failures:
    print("  FAIL", f)
sys.exit(0 if not failures else 1)
