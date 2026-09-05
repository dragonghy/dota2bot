#!/usr/bin/env python3
"""Liveness pins for outlatch_capture.py and for the source claims it rests on.

WHY A LIVENESS TEST AND NOT ONLY A SELFCHECK
  outlatch_capture.py's --selfcheck proves the reader reads synthetic frames
  correctly.  It cannot notice that the SOURCE the reading is about has changed
  underneath it.  Two of this round's claims are claims about Lua and one is a
  claim about the dumper, and all three go quietly false the day someone edits
  those files:

    (1) `mode_outpost_generic.lua` re-issues the capture order with no
        `IsChanneling` guard.  The whole "75% of capture attempts are aborted"
        finding is about that missing guard.  If the guard lands, this test
        goes RED and whoever reads it learns the finding is STALE, not wrong.
    (2) `outlatch` gates the sweep latch and nothing else in that file, so a
        cast is evidence about the latch and the abort rate is not.
    (3) the dumper filters `_Capture` out of `abilities[]`, which is why the
        reader takes casts from `events` and not from ability cooldowns.

  Run: python3 tests/test_outlatch_capture_liveness.py     (exit 0 clean)
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "batch_test", "behavioral"))

import outlatch_capture as OC  # noqa: E402

CHECKS = []


def ck(name, cond, detail=""):
    CHECKS.append((name, bool(cond), detail))


def read(path):
    with open(os.path.join(REPO, path)) as fh:
        return fh.read()


# ---------------------------------------------------------------- section 1
# The Lua the finding is about.
outpost = read("bots/mode_outpost_generic.lua")

ck("1a outpost mode still casts the capture ability from Think()",
   re.search(r"function Think\(\)", outpost) and
   "Action_UseAbilityOnEntity(hAbilityCapture" in outpost)

# The load-bearing pin.  `IsChanneling` (one L) is the engine spelling; accept
# either spelling so a fix written the other way still turns this green.
ck("1b THE FINDING IS LIVE: no IsChanneling guard in mode_outpost_generic.lua",
   not re.search(r"IsChannel?ling\(\)", outpost),
   "if this fails, the guard landed and the 75%-abort finding is STALE, not wrong")

ck("1c the re-issue really is unconditional inside the <=300u branch",
   re.search(r"if hAbilityCapture then\s*\n\s*bot:Action_UseAbilityOnEntity", outpost))

ck("1d the only throttle in front of Think() is the generic think-less one",
   "J.Utils.IsBotThinkingMeaningfulAction(bot, Customize.ThinkLess, \"outpost\")" in outpost)

# ---------------------------------------------------------------- section 2
# `outlatch` is about the sweep latch, and about nothing else in this file.
ck("2a outlatch gate still guards the re-scan",
   "J.IsSoakCandidate('outlatch')" in outpost)
ck("2b the latch line still records the postcondition when armed",
   "DidWeGetOutpost = not bRescan or #Outposts > 0" in outpost)
ck("2c outlatch is the ONLY soak candidate in the outpost mode",
   len(re.findall(r"IsSoakCandidate\('([a-z0-9_]+)'\)", outpost)) == 1,
   "a second gate here would break the attribution in the report")
ck("2d ability_capture has exactly one call site in bots/",
   sum(1 for root, _, files in os.walk(os.path.join(REPO, "bots"))
       for f in files if f.endswith(".lua")
       and "Action_UseAbilityOnEntity(hAbilityCapture" in open(os.path.join(root, f)).read()) == 1)

# ---------------------------------------------------------------- section 3
# The in-repo precedent the fix proposal cites, and the dumper claim.
farm = read("bots/mode_farm_generic.lua")
ck("3a the IsChanneling precedent still exists in mode_farm_generic.lua",
   re.search(r"bot:IsChanneling\(\)", farm))

dumper = read("tools/batch_test/behavioral/dumper/main.go")
ck("3b the dumper still filters _Capture out of abilities[]",
   '"_Capture"' in dumper,
   "casts must be read from events; if this flips, abilities[] becomes a second source")
ck("3c the dumper still tracks CDOTA_BaseNPC_Watch_Tower as a building",
   "CDOTA_BaseNPC_Watch_Tower" in dumper,
   "outpost OWNERSHIP is the ground truth the completion floor is checked against")

# ---------------------------------------------------------------- section 4
# Reader semantics that the corpus reading depends on.
def tl(events, buildings=None, teams=None):
    return {"game": {"teams": teams or {"h_a": 2, "h_b": 3}},
            "events": events, "buildings": buildings or [], "snapshots": []}


def ev(t, typ, actor, infl=OC.CAPTURE_MODIFIER):
    return {"t": t, "type": typ, "inflictor": infl, "actor": actor}


r = OC.read_game(tl([ev(0.0, "MODIFIER_ADD", "h_a"), ev(1.0, "MODIFIER_ADD", "h_b"),
                     ev(4.0, "MODIFIER_REMOVE", "h_a"), ev(5.0, "MODIFIER_REMOVE", "h_b")]), 2)
ck("4a interleaved channels are paired PER ACTOR, not by a global slot",
   sorted(round(a["dur"], 3) for a in r["attempts"]) == [4.0, 4.0],
   "a global open-slot reads one 3.0s attempt here and silently loses one")

r = OC.read_game(tl([ev(0.0, "MODIFIER_ADD", "h_a")]), 2)
ck("4b a channel open at the recording boundary is counted as neither",
   r["attempts"] == [] and r["unclosed"] == 1)

evs = [ev(0.0, "MODIFIER_ADD", "h_a"), ev(3.0, "MODIFIER_REMOVE", "h_a")]
ck("4c the completion floor is a parameter, not a baked constant",
   OC.read_game(tl(evs), 2, 5.0)["attempts"][0]["complete"] is False and
   OC.read_game(tl(evs), 2, 2.0)["attempts"][0]["complete"] is True)

ck("4d leg comes from game.teams; an unknown actor is not filed as 'base'",
   OC.read_game(tl([ev(0.0, "ABILITY", "h_ghost", OC.CAPTURE_ABILITY)]), 2)["casts"][0]["leg"]
   is None)

# 4e the floor check must be able to FAIL.  A long channel with no flip is the
# shape that would mean the floor is wrong; verify_floor has to surface it.
lonely = {"game": "g", "result": OC.read_game(
    tl([ev(0.0, "MODIFIER_ADD", "h_a"), ev(6.0, "MODIFIER_REMOVE", "h_a")]), 2)}
ck("4e verify_floor surfaces a 'complete' attempt that produced no flip",
   OC.verify_floor([lonely])["misfiled"][0] == [6.0])

# 4f and it must not credit a flip that is outside the sampling window
late = {"game": "g", "result": OC.read_game(
    tl([ev(0.0, "MODIFIER_ADD", "h_a"), ev(6.0, "MODIFIER_REMOVE", "h_a")],
       buildings=[{"t": 7.0, "name": OC.WATCH_TOWER, "x": 1, "y": 1, "team": 3,
                   "hp": 1, "hp_pct": 1, "alive": True},
                  {"t": 60.0, "name": OC.WATCH_TOWER, "x": 1, "y": 1, "team": 2,
                   "hp": 1, "hp_pct": 1, "alive": True}]), 2)}
v = OC.verify_floor([late])
ck("4f a flip 54s later is an orphan, not this attempt's success",
   v["produced"] == [] and len(v["orphan_flips"]) == 1)


# 4g/4h hero_track must not be a name filter over `snapshots`.  Two entity
# streams under one hero name (the corpse/duplicate case that put 21 rows on
# one timestamp in 20260905_010205_slot7) must collapse to the real hero, and
# the lookup must use the canon key `frames_by_hero` actually returns.
def snap(idx, t, x, hp, hero="npc_dota_hero_luna", team=2):
    return {"idx": idx, "t": t, "hero": hero, "team": team, "x": x, "y": 0,
            "hp": 1, "hp_pct": hp, "level": 25}


dup = {"game": {"teams": {"npc_dota_hero_luna": 2}}, "events": [], "buildings": [],
       "snapshots": [snap(1, -60.0, 10, 1.0), snap(1, 0.0, 11, 1.0),
                     snap(1, 1.0, 12, 1.0),
                     snap(9, 0.0, 999, 0.0), snap(9, 1.0, 999, 0.0)]}
track = OC.hero_track(dup, "npc_dota_hero_luna", 0.0, 1.0)
ck("4g hero_track drops the duplicate entity stream",
   [r["x"] for r in track] == [11, 12],
   "a name filter would return four rows, two of them from idx 9")
ck("4h hero_track resolves the canon key, not the engine name",
   len(OC.hero_track(dup, "luna", 0.0, 1.0)) == 2,
   "looking frames_by_hero up with 'npc_dota_hero_luna' returns nothing, and "
   "an empty track reads exactly like 'the hero was not there'")


def main():
    failed = [c for c in CHECKS if not c[1]]
    for name, ok, detail in CHECKS:
        if not ok:
            print("FAIL %s%s" % (name, ("  -- " + detail) if detail else ""))
    print("LIVENESS %d checks, %d failed" % (len(CHECKS), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
