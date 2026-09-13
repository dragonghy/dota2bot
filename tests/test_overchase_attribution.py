#!/usr/bin/env python3
"""Controls for `overchase_domain.py`'s 2026-09-13 discriminator.

WHY (replay-check 2026-09-12 -> 2026-09-13)
-------------------------------------------
The first (a)-evidence reading for `overchase` came back INDETERMINATE, and
what decided it was not the sign-flipped aggregate but two BASELINE-leg frames:
on the leg where `J.ShouldPunishOverchase` is shut ENTIRELY, `closed` (the
shrink of the pair distance) still read 35-46%, and a 1%-HP phantom_assassin
being run down by a skywrath_mage scored as a textbook collapse
(`iterations/reports/replay-check/20260912T010526Z.md` section 4).  `closed` is
the SUM of two bodies' motion, so it cannot tell "turned and punished" from
"was caught" -- the one distinction the gate exists to make.

`punish` / `rundown` split that sum.  This file is their POSITIVE and NEGATIVE
control, on synthetic frames where the truth is known by construction:

  A  the bot turns into the chaser and hits it      -> punish,  not rundown
  B  the bot flees, the chaser runs it down and hits it -> rundown, not punish
  C  nobody commits                                  -> neither

⭐ The load-bearing assertion is not "A reads punish".  It is that **`closed` is
TRUE IN BOTH A AND B** while the discriminator separates them -- an instrument
that fired on A alone would be indistinguishable from one that simply got
stricter, which is the `lanefix` lesson ("only a negative control tells
narrowing from switching off").

Usage:  python3 tests/test_overchase_attribution.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "batch_test", "behavioral"))

import overchase_domain as od  # noqa: E402

failures = []


def check(cond, msg):
    print("  [%s] %s" % ("ok" if cond else "FAIL", msg))
    if not cond:
        failures.append(msg)


BOT = "npc_dota_hero_axe"                 # radiant, the collapsing bot
ALLY = "npc_dota_hero_crystal_maiden"     # radiant, the low-HP chased ally
CHASER = "npc_dota_hero_zuus"             # dire, the over-chaser
FAR = "npc_dota_hero_tidehunter"          # dire, parked far away so ISOLATED holds

T0 = 100.0
TS = [t / 1.0 for t in range(0, 111)]     # 0 .. 110 s, 1 Hz (pre-horn sample at 0)


def snap(idx, hero, team, t, x, y, hp_pct=1.0):
    return {"idx": idx, "hero": hero, "team": team, "t": t, "x": x, "y": y,
            "hp": max(1, int(1000 * hp_pct)), "hp_pct": hp_pct,
            "max_hp": 1000, "alive": hp_pct > 0}


def dmg(actor, target, t):
    return {"type": "DAMAGE", "t": t, "actor": actor, "target": target,
            "actor_hero": True, "target_hero": True}


def timeline(bot_path, chaser_path, events):
    """One synthetic game.  `*_path` maps t -> (x, y); missing t holds still."""
    snaps, blds = [], []
    bx, by = 1500.0, 0.0
    cx, cy = 500.0, 0.0
    for t in TS:
        bx, by = bot_path.get(t, (bx, by))
        cx, cy = chaser_path.get(t, (cx, cy))
        snaps.append(snap(1, BOT, od.RADIANT, t, bx, by))
        snaps.append(snap(2, ALLY, od.RADIANT, t, 700.0, 300.0, hp_pct=0.20))
        snaps.append(snap(3, CHASER, od.DIRE, t, cx, cy))
        snaps.append(snap(4, FAR, od.DIRE, t, 7000.0, 7000.0))
        # our tower stands at the origin, so the chaser at (500,0) is inside
        # the 1200 building ring -> the DEEP clause is satisfied by its
        # building door and never needs the ancients.
        blds.append({"t": t, "team": od.RADIANT, "name": "tower", "alive": True,
                     "x": 0.0, "y": 0.0})
        blds.append({"t": t, "team": od.RADIANT, "name": "ancient", "alive": True,
                     "x": -7000.0, "y": -7000.0})
        blds.append({"t": t, "team": od.DIRE, "name": "ancient", "alive": True,
                     "x": 7000.0, "y": 7000.0})
    return {"snapshots": snaps, "buildings": blds, "events": events}


def game(tmp, name, bot_path, chaser_path, events):
    import json
    p = os.path.join(tmp, name + ".json")
    with open(p, "w") as fh:
        json.dump(timeline(bot_path, chaser_path, events), fh)
    return od.Game(p, "radiant", name)


def admitted(eps):
    return [e for e in eps if e["band"] == "admit" and e["bot"] == "axe"
            and e["enemy"] == "zuus"]


def main():
    import tempfile
    tmp = tempfile.mkdtemp(prefix="oc_attr_")

    # The chase limb the replay carries: the chaser hit our low ally at T0-1.
    chase = [dmg(CHASER, ALLY, T0 - 1.0)]

    # --- A: the bot turns in and lands a hit -----------------------------
    a = game(tmp, "A_turn",
             {T0 + 1.0: (1200.0, 0.0), T0 + 2.0: (900.0, 0.0)},
             {},
             chase + [dmg(BOT, CHASER, T0 + 2.0)])
    ea = admitted(a.episodes())
    check(len(ea) >= 1, "A: the gate's observable clauses admit the pair")
    if ea:
        e = ea[0]
        check(e["closed"], "A: `closed` is true (600u of pair shrink)")
        check(e["bot_adv"] >= 250 and e["chaser_adv"] <= 1,
              "A: the advance is attributed to the BOT (bot %.0f, chaser %.0f)"
              % (e["bot_adv"], e["chaser_adv"]))
        check(e["punish"] and not e["rundown"], "A: punish, not rundown")

    # --- B: the bot flees, the chaser runs it down -----------------------
    b = game(tmp, "B_rundown",
             {T0 + 1.0: (1700.0, 0.0), T0 + 2.0: (1900.0, 0.0)},
             {T0 + 1.0: (1100.0, 0.0), T0 + 2.0: (1700.0, 0.0)},
             chase + [dmg(CHASER, BOT, T0 + 2.0)])
    eb = admitted(b.episodes())
    check(len(eb) >= 1, "B: the same clauses admit the pair")
    if eb:
        e = eb[0]
        # THE POINT OF THE WHOLE FILE: the old quantity cannot tell B from A.
        check(e["closed"], "B: `closed` is ALSO true -- the conflation, reproduced")
        check(e["chaser_adv"] >= 250 and e["bot_adv"] < 0,
              "B: the advance is attributed to the CHASER (bot %.0f, chaser %.0f)"
              % (e["bot_adv"], e["chaser_adv"]))
        check(e["rundown"] and not e["punish"], "B: rundown, not punish")
        check(e["hit_by_chaser"] and not e["hit_chaser"],
              "B: only the chaser landed damage")

    # --- C: nobody commits (both quantities must stay silent) ------------
    c = game(tmp, "C_still", {}, {}, chase)
    ec = admitted(c.episodes())
    check(len(ec) >= 1, "C: admitted (the gate's clauses are about geometry)")
    if ec:
        e = ec[0]
        check(not e["closed"], "C: `closed` false (nobody moved)")
        check(not e["punish"] and not e["rundown"],
              "C: neither reading fires on a standstill")

    # --- D: motion without contact is not a punish -----------------------
    # A bot that walks toward the chaser and never lands a hit is the shape a
    # pure-geometry reading would score; requiring the DAMAGE event is what
    # keeps `punish` from inheriting `closed`'s blindness.
    d = game(tmp, "D_walk_no_hit",
             {T0 + 1.0: (1200.0, 0.0), T0 + 2.0: (900.0, 0.0)}, {}, chase)
    ed = admitted(d.episodes())
    check(len(ed) >= 1, "D: admitted")
    if ed:
        e = ed[0]
        check(e["closed"] and e["bot_driven"],
              "D: closed and bot-driven by geometry alone")
        check(not e["punish"], "D: but NOT a punish -- no landed hit")

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
