#!/usr/bin/env python3
"""Liveness pins for outlatch_capture.py and for the source claims it rests on.

WHY A LIVENESS TEST AND NOT ONLY A SELFCHECK
  outlatch_capture.py's --selfcheck proves the reader reads synthetic frames
  correctly.  It cannot notice that the SOURCE the reading is about has changed
  underneath it.  Two of this round's claims are claims about Lua and one is a
  claim about the dumper, and all three go quietly false the day someone edits
  those files:

    (1) `mode_outpost_generic.lua` re-issues the capture order every tick.
        ⚠️ CORRECTED 2026-09-05 (GH #511 comment by strategy, verified here
        against the source): the re-issue is real, but the ROOT CAUSE this
        file used to state was wrong.  `Think()`'s FIRST statement is
        `if J.CanNotUseAction(bot) then return end`, and `J.CanNotUseAction`
        (`bots/FunLib/jmz_func.lua`) has `or bot:IsChanneling()` in its
        disjunction -- so the guard IS evaluated on that frame, via a helper.
        The old 1b ("no `IsChanneling` token in this file") was literally true
        and load-bearing ZERO, and it could never have gone red for the right
        reason.  A guard claim must be made over the EVALUATION SET after
        helper expansion, not over one file's token set.  The 75%-abort
        MEASUREMENT stands (53 attempts / 13 completions / 66.6s, both legs
        alike); the mechanism does not.  The live ratchet for the corrected
        mechanism is `tests/test_outchan_domain.py`, not this file.
        ⚠️ READ THIS BEFORE "FIXING" THE OUTPOST MODE (director 2026-09-05,
        completing §EO.6 handoff (丙)): the day an `IsChanneling` token lands
        in `mode_outpost_generic.lua`, that is A NO-OP, not a landing.  The
        guard is already reached on that frame through `J.CanNotUseAction`,
        so a second copy in this file changes no decision on any frame; it
        only makes the old pin's sentence come true.  `tests/test_outchan_
        domain.py:168` is the assertion that fires on that day and says so
        ("if this token appears here, someone landed #511 as written").
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

sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import lua_corpus as LC  # noqa: E402
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

# 1b -- REWRITTEN 2026-09-05.  The old pin asserted the ABSENCE of an
# `IsChanneling` token in this file and called that "the finding is live".  It
# passed for a reason that has nothing to do with the finding: the guard lives
# one call deeper.  What is actually load-bearing is that the channel guard IS
# reached on the cast frame, because that is what makes "the re-issue happens
# on a NOT-channelling frame" true -- i.e. what makes the re-issue the
# DOWNSTREAM of the abort rather than its cause (GH #511, strategy 04:34Z:
# 24/28 removals strictly precede the next cast, 0/28 the other way).
jmz = read("bots/FunLib/jmz_func.lua")


def fn_body(src, name):
    """The body of ONE Lua function, ending at its own `end` at column 0.

    Written this way after a mutation caught the first cut: a plain
    `function J.CanNotUseAction ... or bot:IsChanneling()` search ran straight
    past the closing `end` and matched the `IsChanneling` in the NEXT function
    (`J.CanNotUseAbility`), so deleting the disjunct from CanNotUseAction left
    the check GREEN.  The pin has to be scoped to the callee actually called.
    """
    m = re.search(r"^function %s\(.*?$" % re.escape(name), src, re.M)
    if not m:
        return ""
    rest = src[m.end():]
    e = re.search(r"^end\s*$", rest, re.M)
    return rest[:e.start()] if e else rest


ck("1b the channel guard IS evaluated on the cast frame -- via the helper",
   re.search(r"function Think\(\)\s*\n\s*if J\.CanNotUseAction\(bot\) then return end",
             outpost) is not None
   and "or bot:IsChanneling()" in fn_body(jmz, "J.CanNotUseAction"),
   "if this fails the guard moved or was dropped; re-derive the mechanism "
   "before quoting the 75% number as evidence about a guard")

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
# ⚠️ WIDENED 2026-09-05 (協同組) from "exactly one id" to a NAMED SET, because
# 'outcommit' landed in this file (GH #511 handoff 乙, the commitment fix that
# this file's own §7 asked for). The thing the original check protects is real
# and is kept: each id must have exactly ONE arming point, so a wave that arms
# one leg can still be attributed to one lever. What it can no longer say is
# "this file has one gate", because it now has two -- and an unnamed third is
# still a red.
#
# ⚠️ THE CAVEAT THE ORIGINAL WORDING WAS POINTING AT, restated rather than
# deleted: the two ids are independent under SINGLE-ARM waves, but a wave armed
# with 'all' (or a bundle naming both) arms them together, and then a capture
# reading cannot be attributed to either alone. The `outlatch` condition-(a)
# reading in hand (W47: armed 72% / base 79%, 53 attempts, 13 completions) was
# taken before 'outcommit' existed in the tree, so it is unaffected; the NEXT
# capture reading must arm at most one of them.
_ids = re.findall(r"IsSoakCandidate\('([a-z0-9_]+)'\)", outpost)
ck("2c the outpost mode's soak ids are exactly {outlatch, outcommit}, one arming point each",
   sorted(_ids) == ["outcommit", "outlatch"],
   "found %s -- an unnamed gate, or a duplicated arming point, breaks the "
   "attribution in the report" % (_ids,))
# Routed through lua_corpus (2026-09-05): the open-coded `os.walk(bots/)` this
# used to do is exactly what tests/test_lua_corpus_stability.py forbids, and it
# was that test's only red on trunk -- named by the batch desk at 06:17Z as
# "first named, reason line not extracted". It was this file's, from the round
# that wrote it. A hand-rolled walk sees bots/Customize/soak_*.lua and every
# other declared non-corpus file, and answers a "how many call sites" question
# over a set nobody declared.
ck("2d ability_capture has exactly one call site in bots/",
   sum(1 for p in LC.bots_lua_files()
       if "Action_UseAbilityOnEntity(hAbilityCapture" in LC.read_lua(p)) == 1)

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
