#!/usr/bin/env python3
"""Census: what `sTalentList[N]` actually resolves to, per focus hero.

Why this exists (hero group, 2026-08-24, GH #166)
-------------------------------------------------
`aba_skill.X.GetTalentList` walks `bot:GetAbilityInSlot(0..25)` and appends
every `IsTalent()` ability in slot order, so `sTalentList[N]` is "the Nth talent
row entry the game ships for this hero", counting 1 = t10-left, 2 = t10-right,
3 = t15-left, ... 8 = t25-right.  Nothing in the tree pins WHICH talent that is.

That is a live hazard, not a theoretical one: hero files bind
`talentN = bot:GetAbilityByName( sTalentList[N] )` and then read the bound
handle as if it were a specific talent -- "the ult damage one", "the AoE Hex
one".  Valve reorders and replaces talent rows every few patches, and when a
row moves the handle silently starts naming a DIFFERENT talent on a DIFFERENT
ability.  There is no error: `IsTrained()` answers about whatever talent now
sits in that slot.

The bearing case: `hero_lion.lua` binds `talent8` and reads it twelve times to
decide things about `lion_voodoo` (Hex).  Slot 8 today is
`special_bonus_unique_lion_2`, which modifies `lion_impale`'s cast range.  The
talent that modifies `lion_voodoo`'s radius is slot 7 -- the other half of the
same t25 row.

WHAT IT PROVES
--------------
Two sources, joined:

  * SLOT ORDER comes from odota `dotaconstants build/hero_abilities.json`
    (`talents[]`), the same source GH #150 used to price
    `special_bonus_unique_wraith_king_facet_3`.  It lists a hero's talents in
    the game's own row order.
  * WHAT EACH TALENT DOES comes from the game's `npc_dota_hero_<name>.txt` on
    the d2vpkr mirror -- the same file `special_value_key_census.py` reads.  A
    talent appears there as an override key inside the AbilityValues block it
    modifies, so `special_bonus_unique_lion_4` showing up under
    `lion_voodoo / AbilityValues / radius` IS the proof that it is the Hex-AoE
    talent.

So a talent's (ability, key) list is a proof of what it modifies.  The converse
is NOT true: a talent with an EMPTY list is not proven inert -- generic rows
(`special_bonus_hp_200`, `special_bonus_intelligence_12`) and facet/innate rows
live in npc_abilities.txt, which this script does not read.  Empty means
"nothing in this hero's own KV names it", nothing more.

Usage:

    python3 tools/agent/talent_slot_census.py             # human-readable table
    python3 tools/agent/talent_slot_census.py --snapshot  # write the Lua table

Network: one HTTPS GET per focus hero plus one for hero_abilities.json.  No AWS,
no cost.
"""

import json
import os
import re
import sys
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

KV = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
      "dota/scripts/npc/heroes/npc_dota_hero_%s.txt")
ABILITIES = ("https://raw.githubusercontent.com/odota/dotaconstants/master/"
             "build/hero_abilities.json")

# AGENTS.md's five polish targets.  Only these are snapshotted, for the same
# reason special_value_key_census.py gives: the standing assertion is about the
# files this stream owns, and 127 heroes would be a generated file nobody reads.
FOCUS_FIVE = ("axe", "zuus", "skeleton_king", "lion", "crystal_maiden")

SNAPSHOT = "tests/mock/talent_slots.lua"


def get(url):
    with urllib.request.urlopen(url, timeout=45) as fh:
        return fh.read().decode("utf-8", "replace")


def talent_overrides(text):
    """{ talent name -> ['ability/key', ...] } from one hero KV.

    Walks the KV block structure; a talent override is any `"special_bonus_*"
    "value"` pair sitting inside an AbilityValues sub-block, and the block path
    names the ability and the key it modifies.
    """
    out, stack, pend = {}, [], None
    for raw in text.splitlines():
        line = raw.split("//")[0].strip()
        if not line:
            continue
        pair = re.match(r'^"([^"]+)"\s+"([^"]*)"$', line)
        if pair:
            name, value = pair.group(1), pair.group(2)
            if name.startswith("special_bonus") and len(stack) >= 3:
                # stack = [root, ability, 'AbilityValues', key]
                out.setdefault(name, []).append(
                    "%s/%s = %s" % (stack[1], stack[-1], value))
            continue
        lone = re.match(r'^"([^"]+)"$', line)
        if lone:
            pend = lone.group(1)
            continue
        if line.startswith("{"):
            stack.append(pend if pend is not None else "?")
            pend = None
            continue
        if line.startswith("}") and stack:
            stack.pop()
    return out


def census():
    """{ hero -> [ (slot, talent name, [what it modifies]), ... ] }"""
    feed = json.loads(get(ABILITIES))
    out = {}
    for hero in FOCUS_FIVE:
        entry = feed["npc_dota_hero_" + hero]
        mods = talent_overrides(get(KV % hero))
        rows = []
        for i, talent in enumerate(entry["talents"], 1):
            name = talent["name"].strip()
            rows.append((i, name, sorted(mods.get(name, ()))))
        out[hero] = rows
    return out


def lua_quote(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def write_snapshot(data):
    lines = [
        "-- GENERATED by tools/agent/talent_slot_census.py --snapshot "
        "-- do not hand-edit.",
        "--",
        "-- What `sTalentList[N]` resolves to for each focus hero, and what that",
        "-- talent modifies in the game's own hero KV.  Slot order is the game's",
        "-- talent row order (1 = t10 left, 2 = t10 right, ... 8 = t25 right),",
        "-- which is the order aba_skill.X.GetTalentList builds its list in.",
        "--",
        "-- `mods` is a PROOF of what the talent changes (it is an override key",
        "-- inside that ability's AbilityValues block).  An EMPTY `mods` proves",
        "-- nothing: generic rows and facet rows live in npc_abilities.txt,",
        "-- which the census does not read.",
        "--",
        "-- Regenerate after a patch:",
        "--   python3 tools/agent/talent_slot_census.py --snapshot",
        "",
        "local X = {}",
        "",
        "-- hero unit short name -> { [slot] = { name = ..., mods = { ... } } }",
        "X.SLOTS = {",
    ]
    for hero in FOCUS_FIVE:
        lines.append("    ['%s'] = {" % hero)
        for slot, name, mods in data[hero]:
            lines.append("        [%d] = { name = %s, mods = {" % (slot, lua_quote(name)))
            for m in mods:
                lines.append("            %s," % lua_quote(m))
            lines.append("        } },")
        lines.append("    },")
    lines += ["}", "", "return X", ""]
    with open(os.path.join(REPO, SNAPSHOT), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def main(argv):
    data = census()
    if "--snapshot" in argv:
        write_snapshot(data)
        print("wrote " + SNAPSHOT)
        return 0
    for hero in FOCUS_FIVE:
        print("== %s" % hero)
        for slot, name, mods in data[hero]:
            print("  %d  %-56s %s" % (slot, name, "; ".join(mods) or "(nothing in this hero's KV)"))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
