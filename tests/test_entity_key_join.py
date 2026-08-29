#!/usr/bin/env python3
"""`entities.py`'s snapshot/event join must actually reach Vengeful Spirit.

Plain python, no pytest (matches tests/test_canon_hero_join.py).

WHAT THIS PINS (`[bug]` GH #303).  `entities.canon()` strips the
`npc_dota_hero_` prefix and nothing else, while the two dump streams disagree
on the rest of the string: events spell Vengeful Spirit
`npc_dota_hero_vengefulspirit` and snapshots spell it
`npc_dota_hero_vengeful_spirit`.  Measured on W24 (`2d1024ee`, 2026-08-29),
five games carried 8,033 actor rows and 7,545 target rows with no snapshot
counterpart, and every one of them was that hero.  A `canon()` join therefore
dropped every VS row and reported a smaller number rather than an error.

THREE PROPERTIES, and the third is the one a single detector run cannot see:

  1. `hkey()` JOINS the two spellings, and it does so as a RULE.  #82 already
     found the same defect from the other end (`roam_conversion.canon_hero`),
     and its lesson is recorded here too: `anti_mage` is structurally affected
     and was absent from #82's corpus, so an alias table covering exactly the
     heroes somebody happened to observe would look complete and stay blind.

  2. `canon()` STILL DOES NOT collapse underscores.  This looks like an
     omission and is a requirement: `tpreach_domain.SOURCE_CITED_RANGE` is
     keyed `'crystal_maiden'` / `'witch_doctor'` and `bbfloor_domain` tests
     `sp['hero'] == 'skeleton_king'`, so "fixing" canon in place would trade
     one silent zero for several.  Asserted so a later simplification that
     merges the two functions fails HERE.

  3. The join is COLLISION-FREE over the roster.  An underscore-insensitive
     key is only safe while no two heroes collapse onto one token; if two ever
     did, this fix would MERGE their rows, which is strictly worse than the
     miss it repairs.  Checked against every `npc_dota_hero_*` name the
     shipped scripts mention, so a future roster addition fails here rather
     than inside somebody's detector read.

And two end-to-end properties, because a helper that is right in isolation is
not the thing that was broken:

  4. `frames_by_hero` / `death_times` ANSWER a lookup made with the other
     stream's spelling (the `HeroMap` join), on a synthetic timeline built
     with the real mismatch in it.
  5. `join_gaps()` -- the issue's acceptance metric -- reports the gap under
     `canon` and reports nothing under `hkey`.

Usage:  python3 tests/test_entity_key_join.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "batch_test", "behavioral"))
sys.path.insert(0, os.path.join(ROOT, "tools", "agent"))
import entities  # noqa: E402
import roam_conversion as RC  # noqa: E402
from lua_corpus import CorpusVanished, bots_lua_files, read_lua, uncertifiable  # noqa: E402

failures = []


def check(cond, msg):
    if cond:
        print("  ok   %s" % msg)
    else:
        failures.append(msg)
        print("  FAIL %s" % msg)


def roster():
    """Every `npc_dota_hero_*` name the shipped bot scripts mention."""
    names = set()
    pat = re.compile(r"npc_dota_hero_[a-z0-9_]+")
    try:
        for path in bots_lua_files(ROOT):
            names.update(pat.findall(read_lua(path, errors="ignore")))
    except CorpusVanished as exc:
        uncertifiable(exc, "tests/test_entity_key_join.py")
    return sorted(names)


# The mismatch, verbatim from the W24 measurement in GH #303.
SNAP_VS, EV_VS = "npc_dota_hero_vengeful_spirit", "npc_dota_hero_vengefulspirit"
# A hero whose two streams AGREE, so every assertion below has a control.
SNAP_CM = EV_CM = "npc_dota_hero_crystal_maiden"


def timeline():
    """Two heroes, sampled from before the horn; one dies at t=10.

    VS is spelled the snapshot way in `snapshots` and the event way in
    `events` -- that difference is the whole fixture.
    """
    snaps = []
    t = -5.0
    while t < 30.0:
        for idx, nm, team in ((1, SNAP_VS, 2), (2, SNAP_CM, 3)):
            snaps.append({"hero": nm, "idx": idx, "t": round(t, 1), "team": team,
                          "x": 0.0, "y": 0.0, "level": 1,
                          "hp_pct": 0.0 if (nm is SNAP_VS and t >= 10.0) else 1.0})
        t += 0.5
    events = [
        {"type": "DEATH", "t": 10.0, "actor": EV_CM, "target": EV_VS,
         "actor_hero": True, "target_hero": True},
    ]
    return {"snapshots": snaps, "events": events}


print("1. hkey(): a rule, not an alias table")
check(entities.hkey(EV_VS) == entities.hkey(SNAP_VS),
      "vengefulspirit joins vengeful_spirit")
check(entities.hkey("npc_dota_hero_queenofpain")
      == entities.hkey("npc_dota_hero_queen_of_pain"),
      "queenofpain joins queen_of_pain (the other half of GH #82)")
check(entities.hkey("npc_dota_hero_antimage")
      == entities.hkey("npc_dota_hero_anti_mage"),
      "antimage joins anti_mage (predicted, absent from #82's corpus)")
check(entities.hkey("npc_dota_hero_not_a_real_hero")
      == entities.hkey("npc_dota_hero_notarealhero"),
      "an unlisted name joins too -- an alias table would fail here")
check(entities.hkey(None) == "", "None survives (callers pass raw dump fields)")
# The two implementations of one rule must not fork: #82's lives in
# roam_conversion and keeps the prefix, this one strips it, and that is the
# ONLY difference either is allowed to have.
check(all(entities.hkey(n) == RC.canon_hero(n).replace("npcdotahero", "")
          for n in (EV_VS, SNAP_VS, SNAP_CM, "npc_dota_hero_anti_mage")),
      "hkey agrees with roam_conversion.canon_hero (same rule, two homes)")

print("2. canon(): still the DISPLAY name, underscores intact")
check(entities.canon(SNAP_VS) == "vengeful_spirit", "canon keeps the underscore")
check(entities.canon(EV_VS) != entities.canon(SNAP_VS),
      "canon alone does NOT join the two spellings -- that is what hkey is for")
check(entities.canon("npc_dota_hero_skeleton_king") == "skeleton_king",
      "bbfloor_domain's `sp['hero'] == 'skeleton_king'` still holds")
check(entities.canon("npc_dota_hero_crystal_maiden") == "crystal_maiden",
      "tpreach_domain's SOURCE_CITED_RANGE key still resolves")

print("3. collision-free over the roster")
names = roster()
check(len(names) > 100, "roster scraped from bots/ (%d names)" % len(names))
buckets = {}
for n in names:
    buckets.setdefault(entities.hkey(n), []).append(n)
collisions = {k: v for k, v in buckets.items() if len(v) > 1}
check(not collisions, "no two hero names collapse onto one key%s"
      % ("" if not collisions else " -- %r" % collisions))

print("4. the join reaches the frames (end-to-end, the shape #303 measured)")
tl = timeline()
fr, team = entities.frames_by_hero(tl)
check(set(fr) == {"vengeful_spirit", "crystal_maiden"},
      "keys stay in DISPLAY form (report columns and `== 'skeleton_king'` "
      "tests read them)")
check(bool(fr.get(entities.canon(EV_VS))),
      "an EVENT-spelled lookup finds the VS frames (this is what returned "
      "None before)")
check(team.get(entities.canon(EV_VS)) == 2, "so does the team map")
check(entities.canon(EV_VS) in fr, "`in` joins as well as `.get`")
check(fr[entities.canon(EV_VS)] is fr["vengeful_spirit"],
      "both spellings reach the SAME row list, not two")
check(bool(fr.get(EV_CM.replace("npc_dota_hero_", ""))),
      "control: the agreeing hero was never broken and is not broken now")
check(fr.get("npc_dota_hero_lina") is None and fr.get("lina") is None,
      "an absent hero still answers None -- the join does not invent rows")

deaths = entities.death_times(tl)
check(deaths.get("vengeful_spirit") == [10.0],
      "death_times, whose keys are EVENT spellings, answers a SNAPSHOT query")
check(entities.alive_at(fr["vengeful_spirit"], deaths.get("vengeful_spirit", []),
                        5.0) is True,
      "alive before the death")
check(entities.alive_at(fr["vengeful_spirit"], deaths.get("vengeful_spirit", []),
                        20.0) is False,
      "DEAD after it -- the reading that was silently 'alive' while the join "
      "missed (same failure as #82's 196 corpse frames)")

print("5. join_gaps(): the acceptance metric reports the defect and the fix")
gaps_canon = entities.join_gaps(tl, key=entities.canon)
check(gaps_canon == {EV_VS: 1},
      "under canon the VS row is reported missing (%r)" % gaps_canon)
gaps_hkey = entities.join_gaps(tl, key=entities.hkey)
check(gaps_hkey == {},
      "under hkey nothing is missing -- GH #303's acceptance line (%r)"
      % gaps_hkey)

print("6. the cross-stream `==` sites HeroMap cannot reach (GH #303 second half)")
# A mapping can normalise a LOOKUP; it cannot normalise `canon(a) == b`.  Those
# sites were edited to compare through hkey, and an edit with no assertion on it
# is a comment -- so each one is driven here with the two spellings crossed, the
# way a real dump presents them.  Every call passes the EVENT spelling for the
# hero and asks a question whose answer comes from the SNAPSHOT side.
import tbearly_domain  # noqa: E402
import tp_channel_death as TCD  # noqa: E402
import tpgap_domain as TPG  # noqa: E402

check(tbearly_domain.deaths_before(tl, "vengeful_spirit", 20.0) == 1,
      "tbearly.deaths_before counts the VS death (0 before the fix)")
check(TCD._team_of(tl, entities.canon(EV_VS)) == 2,
      "tp_channel_death._team_of answers for an EVENT-spelled presser")

atk = TCD.ATTACK_INFLICTOR
ev_dmg = [{"type": "DAMAGE", "t": 9.0, "actor": EV_CM, "target": EV_VS,
           "inflictor": atk, "value": 40.0}]
check(TCD.saw_enemy(ev_dmg, "crystal_maiden", "vengeful_spirit", 9.0) is True,
      "tp_channel_death.saw_enemy finds the VS witness")
check(TPG.realized_burst(ev_dmg, "vengeful_spirit", {"crystal_maiden"},
                         9.0, 3.0) == 40.0,
      "tpgap.realized_burst sums damage TO VS FROM a banded enemy (0.0 before)")
check(TPG.vision_witness(ev_dmg, "vengeful_spirit", 3, {"crystal_maiden"}, 9.0)
      == "ally-attack:crystal_maiden",
      "tpgap.vision_witness sees the ally attacking VS")
mods = [{"type": "MODIFIER_ADD", "t": 8.0, "target": EV_VS,
         "inflictor": "modifier_crystal_maiden_frostbite"}]
check(TPG.active_modifiers(mods, "vengeful_spirit", 9.0)
      == ["modifier_crystal_maiden_frostbite"],
      "tpgap.active_modifiers finds VS's modifier (empty before)")

print()
if failures:
    print("FAILED %d" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")
