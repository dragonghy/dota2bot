#!/usr/bin/env python3
"""[slotdust] B3 is a per-frame test on the CASTER, not a draft census (GH #445).

WHAT WENT WRONG, IN ONE SENTENCE.  The shipped clause is
`bot:HasModifier('modifier_item_radiance_debuff')`
(bots/ability_item_usage_generic.lua:7326) -- a question about ONE body at ONE
instant -- and `slotdust_arbitration.py` modelled it as "did the caster's ENEMY
side ever hold a radiance in this game".

That substitution is not a coarser version of the same question.  It is a
DIFFERENT question whose answer is fixed by the draft, and on a mirrored-draft
corpus the draft is fixed by construction: over W40's 64 games every one of the
20,167 radiance burn events came from dire's own skeleton_king and radiant threw
zero (GH #445).  So the census answered TRUE for every radiant caster in 46/64
games and FALSE for every dire one, and the arbitration table came back

    radiant   1 survivor / 51 casts   ( 2.0%)
    dire     50 survivors / 93 casts  (53.8%)

-- a 27x split that tracks the PHYSICAL TEAM and not the armed leg.  The row
`ba/baseline/radiant` read 0/11 and was quoted as evidence that the radiant
slots are unreachable.  It was an erased row, not a measured zero.

⭐ THE REUSABLE PART.  A conservative approximation of a predicate is only
conservative if what makes it fire is still the thing the predicate is about.
"Enemy side ever held a radiance" is implied by "this hero is burning", so the
direction looked safe -- and it was safe, per cast.  What it was not is
INDEPENDENT of side: the approximation's truth value was decided by a variable
(which physical team drafted the carrier) that the real predicate never
consults, and a mirrored draft pins that variable.  A necessary condition that
happens to be constant on one side is a side filter, and it deletes a row of the
table without ever printing a number that looks wrong.

WHAT THIS FILE ASSERTS.
  1. The whitewash is gone and is COUNTED, not merely dropped: the retired
     census still runs, into the `b3_census_only` contrast column, so the next
     corpus reports how much the old rule was erasing.
  2. The carrier (an `item_radiance` DAMAGE tick on the caster's own body) is
     what blocks -- on this caster, inside the window, on either side of the
     cast, and never on a teammate's burn.
  3. The carrier's DOMAIN PRICE is on the report.  If a corpus carries zero
     burn ticks, B3 blocked nothing there and the table says so in a loud line;
     a clean-looking zero that cannot be told from "no radiance in the game" is
     the failure this section exists to prevent (LIMIT 13(c)).
  4. The exact carrier (MODIFIER_ADD/REMOVE for the debuff) is COUNTED and
     never blocked on, because whether this corpus emits it is a fact nobody
     has bought yet.  Counting it lets the next run decide; assuming it would
     have made the window's correctness unfalsifiable.
  5. The side-asymmetry itself, reproduced end to end on a mirrored-draft-
     shaped corpus: under the old rule the radiant casters' row is empty, under
     the new one it is not.
"""
import collections
import json
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "batch_test", "behavioral",
                    "slotdust_arbitration.py")
sys.path.insert(0, os.path.dirname(TOOL))
import slotdust_arbitration as sd  # noqa: E402

RAD, DIRE = sd.RADIANT, sd.DIRE
PASS, FAIL = [0], [0]


def check(name, cond, detail=""):
    if cond:
        PASS[0] += 1
        print("  ok   %s" % name)
    else:
        FAIL[0] += 1
        print("  FAIL %s%s" % (name, ("  -- " + detail) if detail else ""))


# ---------------------------------------------------------------- fixtures
def game(caster_team, caster_pid, radiance_team=None, burn_at=None,
         burn_target=None, mod_at=None, t_cast=10.0, sandking_pid=None):
    """Ten pre-horn bodies and one dust cast, with B3's two carriers dialled.

    `radiance_team` writes the snapshot `items[]` the RETIRED census read;
    `burn_at` puts an `item_radiance` DAMAGE tick on `burn_target` (the caster
    by default); `mod_at` puts a MODIFIER_ADD for the debuff on the caster.
    """
    caster = "npc_dota_hero_h%d" % caster_pid
    snaps = []
    for pid in range(10):
        team = RAD if pid < 5 else DIRE
        name = sd.SANDKING if pid == sandking_pid else "npc_dota_hero_h%d" % pid
        items = ([sd.RADIANCE] + [""] * 8) if team == radiance_team else [""] * 9
        is_caster = (team == caster_team and pid == caster_pid)
        for t in (-30.0, t_cast - 1.0, t_cast + 1.0):
            snaps.append({"t": t, "hero": name, "idx": 100 + pid, "team": team,
                          "player_id": pid, "x": 0.0 if is_caster else 9000.0,
                          "y": 0.0, "hp": 500, "hp_pct": 0.5, "items": items})
    events = []
    if burn_at is not None:
        events.append({"t": burn_at, "type": "DAMAGE",
                       "actor": "npc_dota_hero_h%d" % (9 if caster_team == RAD
                                                       else 0),
                       "target": burn_target or caster,
                       "inflictor": sd.RADIANCE_BURN, "value": 60,
                       "actor_hero": True, "target_hero": True})
    if mod_at is not None:
        events.append({"t": mod_at, "type": "MODIFIER_ADD",
                       "actor": "npc_dota_hero_h%d" % (9 if caster_team == RAD
                                                       else 0),
                       "target": caster, "inflictor": sd.RADIANCE_DEBUFF,
                       "value": 0, "actor_hero": True, "target_hero": True})
    events.append({"t": t_cast, "type": "ITEM", "actor": caster,
                   "target": caster, "inflictor": sd.DUST, "value": 0,
                   "actor_hero": True, "target_hero": True})
    return {"snapshots": snaps, "events": events}


def leg_of(caster_team, armed_side):
    return "armed" if caster_team == (RAD if armed_side == "radiant"
                                      else DIRE) else "baseline"


def scan(caster_team, caster_pid, armed_side, **kw):
    got = sd.scan_game(game(caster_team, caster_pid, **kw), armed_side)
    assert got is not None, "the synthetic roster must not be refused"
    return got[0][leg_of(caster_team, armed_side)]


# UNREACHABLE slots are the ones the exclusive column can speak about: dire
# pid 5 is team slot 1, radiant pid 4 is team slot 5.
DIRE_UNREACHABLE, RAD_UNREACHABLE = 5, 4


# ------------------------------------------------- 1. the whitewash
print("=== 1. a draft census is not a per-frame predicate ===")

r = scan(DIRE, DIRE_UNREACHABLE, "dire", radiance_team=RAD)
check("an enemy radiance in the DRAFT no longer blocks the cast",
      r["blocked_b3_radiance"] == 0 and r["exclusive"] == 1)
check("...and the census it used to trust is COUNTED, not silently dropped",
      r["b3_census_only"] == 1)

r = scan(DIRE, DIRE_UNREACHABLE, "dire")
check("no radiance anywhere leaves the contrast column empty",
      r["b3_census_only"] == 0 and r["exclusive"] == 1)

r = scan(DIRE, DIRE_UNREACHABLE, "dire", burn_at=9.8)
check("a burn tick ON THE CASTER blocks it (that IS the shipped clause)",
      r["blocked_b3_radiance"] == 1 and r["exclusive"] == 0)
check("...and a burn with no draft census behind it is registered too",
      r["b3_tick_no_census"] == 1)

r = scan(DIRE, DIRE_UNREACHABLE, "dire", radiance_team=RAD, burn_at=9.8)
check("a burn WITH the census behind it is in neither contrast column",
      r["blocked_b3_radiance"] == 1
      and r["b3_census_only"] == 0 and r["b3_tick_no_census"] == 0)


# ------------------------------------------------- 2. the carrier
print("=== 2. the carrier is this caster's own burn, inside the window ===")

r = scan(DIRE, DIRE_UNREACHABLE, "dire", burn_at=9.8,
         burn_target="npc_dota_hero_h6")
check("a burn tick on a TEAMMATE does not block this caster",
      r["blocked_b3_radiance"] == 0 and r["exclusive"] == 1)

W = sd.B3_BURN_WINDOW
for dt, blocks in ((-W, True), (W, True), (-W - 0.1, False), (W + 0.1, False),
                   (0.0, True)):
    r = scan(DIRE, DIRE_UNREACHABLE, "dire", burn_at=10.0 + dt)
    check("a tick at t%+.1f s %s" % (dt, "blocks" if blocks else "does not"),
          (r["blocked_b3_radiance"] == 1) == blocks,
          "b3=%d exclusive=%d" % (r["blocked_b3_radiance"], r["exclusive"]))

check("the window is wider than one 1.0 s burn tick on each side (LIMIT 13a)",
      sd.B3_BURN_WINDOW > 1.0)

# Ordering: B2 is still consulted first, so a Sand King game does not become a
# B3 reading just because the caster also happens to be burning.
r = scan(DIRE, DIRE_UNREACHABLE, "dire", burn_at=9.8, sandking_pid=0)
check("B2 still precedes B3 in the cascade",
      r["blocked_b2_sandking"] == 1 and r["blocked_b3_radiance"] == 0)

# The tick is also a DAMAGE event, so B4 would catch it -- but B3 is asked
# first, and a reader who sees `blocked_b4` here would attribute the block to
# the wrong clause.
r = scan(DIRE, DIRE_UNREACHABLE, "dire", burn_at=9.8)
check("a burn inside B4's window is booked to B3, not to B4",
      r["blocked_b3_radiance"] == 1 and r["blocked_b4_recent_damage"] == 0)


# ------------------------------------------------- 3. the domain price
print("=== 3. the carrier's own domain price is measured, not assumed ===")

r = scan(DIRE, DIRE_UNREACHABLE, "dire", burn_at=9.8)
check("burn ticks are counted per leg", r["radiance_burn_ticks"] == 1)
r = scan(DIRE, DIRE_UNREACHABLE, "dire")
check("a corpus with no burn ticks says zero rather than nothing",
      r["radiance_burn_ticks"] == 0)
# A burn on the OTHER side is the other leg's domain price, not this one's.
res = sd.scan_game(game(DIRE, DIRE_UNREACHABLE, burn_at=9.8,
                        burn_target="npc_dota_hero_h0"), "dire")[0]
check("ticks are booked against the leg the BURNING body is on",
      res["baseline"]["radiance_burn_ticks"] == 1
      and res["armed"]["radiance_burn_ticks"] == 0)

r = scan(DIRE, DIRE_UNREACHABLE, "dire", mod_at=9.0)
check("MODIFIER_ADD for the debuff is counted (LIMIT 13b)",
      r["radiance_debuff_add"] == 1)
check("...and does NOT block, because nobody has bought that corpus fact yet",
      r["blocked_b3_radiance"] == 0 and r["exclusive"] == 1)


# ------------------------------------------------- 4. the erased row
print("=== 4. the GH #445 shape: a mirrored draft pins the census to one side ===")

# The corpus shape: dire drafts the radiance in every game, both legs cast dust
# from an unreachable slot, and nobody is actually burning.  Under the retired
# rule every RADIANT caster is blocked and every DIRE caster is not.
old = collections.Counter()
new = collections.Counter()
for armed_side in ("radiant", "dire"):
    for caster_team, pid in ((RAD, RAD_UNREACHABLE), (DIRE, DIRE_UNREACHABLE)):
        r = scan(caster_team, pid, armed_side, radiance_team=DIRE)
        side = "radiant" if caster_team == RAD else "dire"
        # `b3_census_only` is exactly "the old rule blocked this, the new one
        # does not", so old-rule blocks = new-rule blocks + census-only.
        old[side] += r["blocked_b3_radiance"] + r["b3_census_only"]
        new[side] += r["blocked_b3_radiance"]
check("under the retired census EVERY radiant caster was blocked",
      old["radiant"] == 2 and new["radiant"] == 0, str(dict(old)))
check("...while no dire caster ever was -- the split tracks the PHYSICAL team",
      old["dire"] == 0 and new["dire"] == 0, str(dict(old)))
check("the tightened clause blocks neither side on this shape",
      sum(new.values()) == 0)


# ------------------------------------------------- 5. end to end
print("=== 5. end to end: the report carries the carrier block ===")

with tempfile.TemporaryDirectory() as tmp:
    def corpus(name, **kw):
        rows, paths = [], []
        for i, (team, pid, side) in enumerate(
                ((RAD, RAD_UNREACHABLE, "radiant"), (RAD, RAD_UNREACHABLE, "dire"),
                 (DIRE, DIRE_UNREACHABLE, "radiant"), (DIRE, DIRE_UNREACHABLE, "dire"))):
            p = os.path.join(tmp, "%s%d.timeline.json" % (name, i))
            with open(p, "w") as fh:
                json.dump(game(team, pid, **kw), fh)
            rows.append({"game": "%s%d" % (name, i), "cand": "slotdust",
                         "seed": 1, "side": side})
            paths.append(p)
        man = os.path.join(tmp, "%s.jsonl" % name)
        with open(man, "w") as fh:
            for r in rows:
                fh.write(json.dumps(r) + "\n")
        run = subprocess.run([sys.executable, TOOL] + paths
                             + ["--manifest", man],
                             capture_output=True, text=True)
        return run

    dry = corpus("dry", radiance_team=DIRE)      # census everywhere, no burns
    wet = corpus("wet", burn_at=9.8)             # the carrier is present

check("the run exits 0 and reads every game",
      dry.returncode == 0 and "games read: 4" in dry.stdout, dry.stderr[-300:])
check("the B3 CARRIER block is printed", "B3 CARRIER" in dry.stdout)
check("a corpus with no burn ticks is called out LOUDLY, not printed as 0",
      "CARRIER ABSENT" in dry.stdout and "LIMIT 13(c)" in dry.stdout,
      [ln for ln in dry.stdout.splitlines() if "CARRIER" in ln])
check("...and the loud line comes BEFORE the fit table a reader would quote",
      dry.stdout.index("CARRIER ABSENT") < dry.stdout.index("REACHABILITY FIT"))
check("the retired census is reported as a number, not as prose",
      "b3_census_only" in dry.stdout)
check("a corpus that DOES carry the tick prints no absent-carrier banner",
      wet.returncode == 0 and "CARRIER ABSENT" not in wet.stdout)
check("both layers are registered in the carrier block (铁律 4(i-a))",
      len([ln for ln in wet.stdout.splitlines()
           if ln.startswith("    ab ") or ln.startswith("    ba ")]) >= 8)
check("the fit table and the LIMIT 6 line still print",
      "REACHABILITY FIT" in wet.stdout
      and "EXCLUSIVE-DOMAIN DUST CASTS" in wet.stdout)


# ------------------------------------------------- 6. the ratchet
print("=== 6. ratchet: the spellings and the limit stay where they are read ===")

src = open(TOOL).read()
check("LIMIT 13 is in the module docstring, not only in this test",
      "13." in src and "PER-FRAME TEST ON THE CASTER" in src)
check("the docstring names the corpus fact that made the census a side filter",
      "MIRRORED-DRAFT" in src or "mirrored-draft" in src.lower())
check("the window is documented as the slack, with its direction",
      "THE WINDOW IS THE SLACK" in src)
# LIMIT 9 from the other side: three constants, three vocabularies, and the
# `item_` prefix is what tells two of them apart.
check("RADIANCE stays the SNAPSHOT spelling (LIMIT 9)",
      not sd.RADIANCE.startswith("item_"))
check("RADIANCE_BURN is the COMBAT-LOG spelling -- it matches an inflictor",
      sd.RADIANCE_BURN == "item_" + sd.RADIANCE)
check("RADIANCE_DEBUFF is the MODIFIER spelling, and is neither of the above",
      sd.RADIANCE_DEBUFF.startswith("modifier_")
      and sd.RADIANCE_DEBUFF not in (sd.RADIANCE, sd.RADIANCE_BURN))
check("the shipped clause this models is still spelled that way in bots/",
      sd.RADIANCE_DEBUFF in open(os.path.join(
          REPO, "bots", "ability_item_usage_generic.lua")).read())
check("the B3 diagnostics are OUT of KEYS, so the parity oracle stays scoped",
      not set(sd.B3_KEYS) & set(sd.KEYS)
      and "blocked_b3_radiance" in sd.KEYS)

print()
print("%d passed, %d failed" % (PASS[0], FAIL[0]))
sys.exit(1 if FAIL[0] else 0)
