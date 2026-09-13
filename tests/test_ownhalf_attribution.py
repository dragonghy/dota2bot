#!/usr/bin/env python3
"""Controls for `ownhalf_domain.py`'s ported punish/rundown discriminator.

WHY (replay-check 2026-09-13, second round of the day)
-----------------------------------------------------
The sibling instrument `overchase_domain.py` grew this discriminator earlier
today, after two BASELINE-leg frames -- read with `closed` alone -- were
reported backwards: a 1%-HP phantom_assassin scored as a textbook collapse on
the frame where she killed her chaser, and a pudge/skeleton_king pair read the
same way.  `closed` (`d0 - dmin`) is the SUM of two bodies' motion, so it
cannot tell "the bot collapsed" from "the other body walked in", which is the
one distinction a collapse gate exists to make.
(`iterations/reports/replay-check/20260913T095506Z.md` section 2.)

`ownhalf` measures the SAME quantity on a band where the confound is, if
anything, structurally worse: the own-half band is BY CONSTRUCTION the frames
where an enemy hero is deep on our ground inside the collapse ring -- the
geometry of a dive, where the INVADER is the party with a reason to advance.
So the discriminator is ported, and this file is its positive and negative
control on synthetic frames where the truth is known by construction:

  A  the bot turns into the invader and hits it        -> punish,  not rundown
  B  the bot flees, the invader runs it down and hits  -> rundown, not punish
  C  nobody commits                                    -> neither
  D  the bot walks in and never lands a hit            -> bot_driven, NOT punish

⭐ The load-bearing assertion is not "A reads punish".  It is that **`closed` is
TRUE IN BOTH A AND B** while the discriminator separates them -- an instrument
that fired on A alone would be indistinguishable from one that merely got
stricter, which is the `lanefix` lesson ("only a negative control tells
narrowing from switching off").

⭐ E additionally pins that these controls exercise the CANDIDATE door
(`ownhalf`), not the shipped building door -- a control that silently drifted
into the `shipped` band would be testing bit-identical code on both legs.

Usage:  python3 tests/test_ownhalf_attribution.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "batch_test", "behavioral"))

import ownhalf_domain as od  # noqa: E402

failures = []


def check(cond, msg):
    print("  [%s] %s" % ("ok" if cond else "FAIL", msg))
    if not cond:
        failures.append(msg)


BOT = "npc_dota_hero_axe"                 # radiant, the collapsing bot
INVADER = "npc_dota_hero_zuus"            # dire, deep on radiant ground
FAR = "npc_dota_hero_tidehunter"          # dire, parked far away

T0 = 100.0
TS = [float(t) for t in range(0, 111)]    # 0 .. 110 s, 1 Hz

# The invader sits deep in OUR half and far from any building of ours:
#   depth = d(inv, their ancient) - d(inv, our ancient)
#         = 14142 - 5657 = 8485  >= DEPTH_MARGIN (1600)
#   nearest radiant building (tower at the origin) = 4243 > BUILDING_RING
# so the frame is admitted by the CANDIDATE door only.  E asserts both halves.
INV = (-3000.0, -3000.0)
# The bot walks in from outside the collapse ring and crosses it exactly at T0,
# so the episode's t0 is T0 and the consequence window is the motion below.
APPROACH = {T0 - 3.0: (-600.0, -3000.0),     # d 2400, outside the 1600 ring
            T0 - 2.0: (-1000.0, -3000.0),    # d 2000, outside
            T0 - 1.0: (-1300.0, -3000.0),    # d 1700, outside
            T0: (-1500.0, -3000.0)}          # d 1500, ADMITTED


def snap(idx, hero, team, t, x, y, hp_pct=1.0):
    return {"idx": idx, "hero": hero, "team": team, "t": t, "x": x, "y": y,
            "hp": max(1, int(1000 * hp_pct)), "hp_pct": hp_pct,
            "max_hp": 1000, "alive": hp_pct > 0}


def dmg(actor, target, t):
    return {"type": "DAMAGE", "t": t, "actor": actor, "target": target,
            "actor_hero": True, "target_hero": True}


def timeline(bot_path, inv_path, events):
    """One synthetic game.  `*_path` maps t -> (x, y); missing t holds still."""
    snaps, blds = [], []
    bx, by = -100.0, -3000.0
    ix, iy = INV
    for t in TS:
        bx, by = bot_path.get(t, (bx, by))
        ix, iy = inv_path.get(t, (ix, iy))
        snaps.append(snap(1, BOT, od.RADIANT, t, bx, by))
        snaps.append(snap(2, INVADER, od.DIRE, t, ix, iy))
        snaps.append(snap(3, FAR, od.DIRE, t, 6000.0, 6000.0))
        blds.append({"t": t, "team": od.RADIANT, "name": "tower", "alive": True,
                     "x": 0.0, "y": 0.0})
        blds.append({"t": t, "team": od.RADIANT, "name": "ancient",
                     "alive": True, "x": -7000.0, "y": -7000.0})
        blds.append({"t": t, "team": od.DIRE, "name": "ancient", "alive": True,
                     "x": 7000.0, "y": 7000.0})
    return {"snapshots": snaps, "buildings": blds, "events": events}


def game(tmp, name, bot_path, inv_path, events):
    import json
    p = os.path.join(tmp, name + ".json")
    with open(p, "w") as fh:
        json.dump(timeline(bot_path, inv_path, events), fh)
    return od.Game(p, "radiant", name)


def own(eps):
    return [e for e in eps if e["band"] == "ownhalf" and e["bot"] == "axe"
            and e["enemy"] == "zuus" and abs(e["t0"] - T0) < 1e-6]


def path(*steps):
    d = dict(APPROACH)
    d.update(steps[0] if steps else {})
    return d


def main():
    import tempfile
    tmp = tempfile.mkdtemp(prefix="oh_attr_")

    # --- A: the bot collapses in and lands a hit -------------------------
    a = game(tmp, "A_collapse",
             path({T0 + 1.0: (-1800.0, -3000.0),
                   T0 + 2.0: (-2100.0, -3000.0)}),
             {},
             [dmg(BOT, INVADER, T0 + 2.0)])
    ea = own(a.episodes())
    check(len(ea) == 1, "A: exactly one own-half episode opens at t0=%.0f" % T0)
    if ea:
        e = ea[0]
        check(e["closed"], "A: `closed` is true (600u of pair shrink)")
        check(e["bot_adv"] >= 250 and e["enemy_adv"] <= 1,
              "A: the advance is attributed to the BOT (bot %.0f, invader %.0f)"
              % (e["bot_adv"], e["enemy_adv"]))
        check(e["punish"] and not e["rundown"], "A: punish, not rundown")

    # --- B: the bot flees, the invader runs it down ----------------------
    b = game(tmp, "B_rundown",
             path({T0 + 1.0: (-1300.0, -3000.0),
                   T0 + 2.0: (-1100.0, -3000.0)}),
             {T0 + 1.0: (-2100.0, -3000.0), T0 + 2.0: (-1500.0, -3000.0)},
             [dmg(INVADER, BOT, T0 + 2.0)])
    eb = own(b.episodes())
    check(len(eb) == 1, "B: the same geometry admits one episode")
    if eb:
        e = eb[0]
        # THE POINT OF THE WHOLE FILE: the old quantity cannot tell B from A.
        check(e["closed"],
              "B: `closed` is ALSO true -- the conflation, reproduced")
        check(e["enemy_adv"] >= 250 and e["bot_adv"] < 0,
              "B: the advance is attributed to the INVADER "
              "(bot %.0f, invader %.0f)" % (e["bot_adv"], e["enemy_adv"]))
        check(e["rundown"] and not e["punish"], "B: rundown, not punish")
        check(e["hit_by_enemy"] and not e["hit_enemy"],
              "B: only the invader landed damage")

    # --- C: nobody commits (both quantities must stay silent) ------------
    c = game(tmp, "C_still", path({}), {}, [])
    ec = own(c.episodes())
    check(len(ec) == 1, "C: admitted (the band is about geometry)")
    if ec:
        e = ec[0]
        check(not e["closed"], "C: `closed` false (nobody moved)")
        check(not e["punish"] and not e["rundown"],
              "C: neither reading fires on a standstill")

    # --- D: motion without contact is not a punish -----------------------
    # Requiring the DAMAGE event is what keeps `punish` from inheriting
    # `closed`'s blindness to who actually committed.
    d = game(tmp, "D_walk_no_hit",
             path({T0 + 1.0: (-1800.0, -3000.0),
                   T0 + 2.0: (-2100.0, -3000.0)}), {}, [])
    ed = own(d.episodes())
    check(len(ed) == 1, "D: admitted")
    if ed:
        e = ed[0]
        check(e["closed"] and e["bot_driven"],
              "D: closed and bot-driven by geometry alone")
        check(not e["punish"], "D: but NOT a punish -- no landed hit")

    # --- F: the wide window is a SENSITIVITY, not a second definition -----
    # A bot that drives in and lands its hit at t0+5s is declined by `punish`
    # (window 4s) and admitted by `punish_wide` (8s).  Two of the six frame
    # witnesses read on 2026-09-13 are exactly this shape, so the divergence
    # is pinned here rather than left to be rediscovered.
    f = game(tmp, "F_late_hit",
             path({T0 + 1.0: (-1800.0, -3000.0),
                   T0 + 2.0: (-2100.0, -3000.0)}),
             {},
             [dmg(BOT, INVADER, T0 + 5.0)])
    ef = own(f.episodes())
    check(len(ef) == 1, "F: admitted")
    if ef:
        e = ef[0]
        check(e["bot_driven"] and not e["punish"],
              "F: bot-driven, but `punish` declines a hit at t0+5s")
        check(e["punish_wide"],
              "F: `punish_wide` (%.0fs) admits the same episode"
              % od.HIT_WINDOW_WIDE)
    if ea:
        check(ea[0]["punish"] and ea[0]["punish_wide"],
              "F: a hit inside 4s is in BOTH columns (wide is a superset)")

    # --- E: the controls exercise the CANDIDATE door, not the shipped one -
    doors = a.doors(T0, "axe", {"x": INV[0], "y": INV[1]})
    check(doors is not None and doors[0] is False,
          "E: the shipped building door is SHUT on these frames")
    check(doors is not None and doors[1] >= od.DEPTH_MARGIN,
          "E: invade depth %.0f clears the margin %.0f read from the Lua"
          % (doors[1] if doors else -1, od.DEPTH_MARGIN))
    check(not [e for e in a.episodes()
               if e["band"] == "shipped" and e["bot"] == "axe"],
          "E: no episode of these controls landed in the `shipped` band")

    print("")
    if failures:
        print("FAILED %d check(s)" % len(failures))
        for f in failures:
            print("  - %s" % f)
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
