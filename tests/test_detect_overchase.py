#!/usr/bin/env python3
"""Unit test for the d20_enemy_overchase_unpunished detector (issue #20).

Plain python, no pytest (matches tests/test_storyboard_smoke.py). Builds minimal
synthetic timelines around a single instant and asserts the detector fires on the
target pattern (an enemy solo-chasing our low ally deep into our half while we have
the numbers and it survives) and stays silent on each of the safety cut-outs
(chaser backed by an ally, chaser punished with a kill, victim not low, chaser not
deep, too few defenders).

Usage:  python3 tests/test_detect_overchase.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEHAV = os.path.join(ROOT, "tools", "batch_test", "behavioral")
sys.path.insert(0, BEHAV)
import detect  # noqa: E402

failures = []


def check(cond, msg):
    print("  [%s] %s" % ("ok" if cond else "FAIL", msg))
    if not cond:
        failures.append(msg)


CHASER = "npc_dota_hero_zuus"          # team 3 (Dire), the over-chaser
CHASER_ALLY = "npc_dota_hero_tidehunter"  # team 3, normally far away
VICTIM = "npc_dota_hero_axe"           # team 2 (Radiant), the chased low ally
DEF1 = "npc_dota_hero_crystal_maiden"  # team 2 defender
DEF2 = "npc_dota_hero_sniper"          # team 2 defender

T = 100.0


def snap(hero, team, x, y, hp_pct):
    return {"t": T, "hero": hero, "team": team, "x": x, "y": y,
            "hp": 100 if hp_pct > 0 else 0, "hp_pct": hp_pct,
            "mp_pct": 0.5, "level": 6}


def build(opts=None):
    """A Dire zuus deep in the Radiant half (x+y very negative) next to our
    low-HP axe, with two Radiant defenders in collapse range and zuus's only
    ally parked far away (so zuus is solo). Knobs flip one condition each."""
    opts = opts or {}
    # zuus deep in our half: x+y = -3000 -> depth from team 3 = 3000 > margin
    zx, zy = (0, 0) if opts.get("not_deep") else (-1500, -1500)
    victim_hp = 0.8 if opts.get("victim_healthy") else 0.30
    # chaser ally: far by default; near (backing the dive) when 'backed'
    ally_xy = (-1500, -1450) if opts.get("backed") else (3000, 3000)

    snaps = [
        snap(CHASER, 3, zx, zy, 1.0),
        snap(VICTIM, 2, zx + 100, zy, victim_hp),
        snap(DEF1, 2, zx - 100, zy, 0.9),
        snap(CHASER_ALLY, 3, ally_xy[0], ally_xy[1], 1.0),
    ]
    if not opts.get("one_defender"):
        snaps.append(snap(DEF2, 2, zx, zy + 100, 0.9))

    teams = {CHASER: 3, VICTIM: 2, DEF1: 2, CHASER_ALLY: 3, DEF2: 2}
    events = []
    if opts.get("punished"):
        # zuus dies 3s later -> the over-chase WAS punished
        events.append({"t": T + 3.0, "type": "DEATH", "actor": DEF1,
                       "target": CHASER, "inflictor": "", "value": 0,
                       "actor_hero": True, "target_hero": True})

    return {"game": {"start_time": 0.0, "teams": teams},
            "snapshots": snaps, "events": events}


def fires(opts=None):
    tl = detect.Timeline(build(opts))
    found = detect.d20_enemy_overchase_unpunished(tl)
    return found


# FIRE: the full target pattern.
f = fires()
check(len(f) == 1, "FIRE: solo over-chase of a low ally, we have numbers, "
                   "unpunished -> exactly one finding (got %d)" % len(f))
if f:
    check(f[0]["hero"] == CHASER and f[0]["victim"] == VICTIM,
          "the finding names the chaser (zuus) and the victim (axe)")
    check(f[0]["detector"] == "enemy_overchase_unpunished" and f[0]["bug"] == "20",
          "finding is tagged enemy_overchase_unpunished / bug 20")

# NO-FIRE cut-outs.
check(len(fires({"backed": True})) == 0,
      "NO-FIRE: chaser has an ally backing the dive -> not a solo over-chase")
check(len(fires({"punished": True})) == 0,
      "NO-FIRE: chaser dies within the punish window -> it WAS punished")
check(len(fires({"victim_healthy": True})) == 0,
      "NO-FIRE: the chased ally is not low HP -> not a desperate over-chase")
check(len(fires({"not_deep": True})) == 0,
      "NO-FIRE: chaser is not deep in our half -> normal positioning")
check(len(fires({"one_defender": True})) == 0,
      "NO-FIRE: only one defender present -> we lacked the numbers to collapse")


if failures:
    print("\n%d FAILURE(S):" % len(failures))
    for x in failures:
        print("  - " + x)
    raise SystemExit(1)
print("\nall d20_enemy_overchase_unpunished checks passed")
