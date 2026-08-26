#!/usr/bin/env python3
"""Generate tests/mock/hero_slots.lua -- the engine slot order of every hero's
abilities, read out of the game's own `npc_heroes.txt`.

WHY THIS EXISTS (GH #209; #203 / #206 left this as a declared assumption)
------------------------------------------------------------------
`bots/FunLib/aba_skill.lua:X.GetAbilityList` walks `bot:GetAbilityInSlot(0..10)`
and COMPACTS what it accepts with `table.insert`, writing only index 6 directly
(the ultimate, and only from `slot >= 4`).  So `sAbilityList[N]` means "the Nth
ability the walk accepted", and every reasoning step about what index N names
starts from the hero's SLOT ORDER.

Two shipped soak candidates already rest on a slot order:

  * `zusbind` (GH #203) quotes Zeus's slots 0..6 in
    tests/test_zuus_ability_index_binding.lua;
  * `cmclone` (GH #206) quotes Crystal Maiden's in
    tests/test_cm_ability_index_binding.lua.

Both took that order from the Dota 2 datafeed's `abilities` array and both said,
in as many words, that "GetAbilityInSlot enumerates the datafeed's order" was an
ASSUMPTION -- the datafeed publishes a display list, not slot indices.  It is no
longer an assumption: `npc_heroes.txt` carries a literal `"AbilityN"` map per
hero, N is 1-based over the same slots the bot API indexes 0-based, and it names
the `generic_hidden` placeholders that occupy empty slots.  That file is the
reason `X.GetAbilityList` can hardcode `slot >= 4` and index 6 at all: the KV
convention is Ability1..3 = the basics, Ability4/5 = extras or placeholders,
Ability6 = the ultimate.

WHAT IT COSTS
    One HTTPS GET (~900 KB) of the dotabuff/d2vpkr mirror this repo already
    reads in tools/agent/gen_ability_meta.py.  No AWS, no per-hero fan-out --
    which is what makes the roster-wide half of the survey cheap.

    python3 tools/agent/hero_slot_map.py            # regenerate the Lua table
    python3 tools/agent/hero_slot_map.py --census   # index-bind risk report

⚠️ WHAT THIS DOES *NOT* SETTLE, and the census says so on every line it prints:
    The slot order is only half of "what does index N name".  The other half is
    the walk's drop rule -- `NOT_LEARNABLE and ability:IsHidden()` -- and
    `IsHidden()` cannot be evaluated outside the game VM
    (tests/test_focus_innate_index_anchor.lua section 2).  So this file answers
    "which ability sits in which slot", never "which ones the walk kept".  The
    census below therefore reports the occupant of an index in the NOTHING-IS-
    DROPPED world, which is one real world among several, and flags a hero only
    when that world disagrees with what the hero file's own variable name says
    it wanted.  A disagreement is a lead, not a verdict.

⚠️ THE UPSTREAM FILE IS NOT UNIFORMLY INDENTED, AND NOT IN THE WAY IT LOOKS.
    Some hero HEADERS start at column 0 (slark, earth_spirit) while the rest
    start at one tab -- but every hero's FIELDS sit at two tabs either way.  So
    the header indent is cosmetic and must not be used as a base: the first cut
    of this tool measured field depth relative to its own header, which reads
    slark's real Ability1..6 as too shallow and hands back an empty slot map.
    Ability keys are therefore accepted at exactly two tabs (the nested
    ability-draft blocks that repeat "Ability1".."Ability4" with a different
    meaning sit at three), and both entry points fail loudly rather than emit a
    hero with no abilities -- an empty map here is a parse hole, never a hero.
"""

import argparse
import glob
import os
import re
import sys
import urllib.request

URL = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
       "dota/scripts/npc/npc_heroes.txt")
OUT = "tests/mock/hero_slots.lua"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

HDR = re.compile(r'^(\t*)"(npc_dota_hero_[A-Za-z0-9_]+)"\s*$')
ABIL = re.compile(r'^(\t*)"(Ability(\d+))"\s+"([^"]*)"')

# The walk only ever looks at slots 0..10 (aba_skill.lua's
# `totalUpgradeableAbilities`), so nothing above Ability11 can reach an index.
MAX_ABILITY = 11

# Hero fields sit at two tabs throughout the upstream file; the nested
# ability-draft block sits at three.  See the header note -- this is NOT
# relative to the hero's own header, which is dedented for a few heroes.
FIELD_DEPTH = 2

# Heroes in bots/BotLib that are not heroes in the KV sense.  A summoned unit
# has no npc_heroes.txt block, and that is data, not a parse failure.
NOT_A_HERO = {"lone_druid_bear"}


def fetch(url=URL):
    req = urllib.request.Request(url, headers={"User-Agent": "dota2bot-agent"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read().decode("utf-8", "replace")


def parse(text):
    """hero name (without the npc_dota_hero_ prefix) -> {slot index: ability}.

    A hero's fields are at FIELD_DEPTH tabs no matter where its header sits
    (see the header note about the dedented blocks).  Depth is what separates a
    slot map from the nested ability-draft block, which repeats
    "Ability1".."Ability4" one level deeper with a different meaning -- read
    those as slots and half the roster's abilities come back renamed.
    """
    out = {}
    hero = None
    for raw in text.splitlines():
        line = raw.rstrip("\r")
        m = HDR.match(line)
        if m:
            hero = m.group(2)[len("npc_dota_hero_"):]
            out.setdefault(hero, {})
            continue
        if hero is None:
            continue
        a = ABIL.match(line)
        if a and len(a.group(1)) == FIELD_DEPTH:
            n = int(a.group(3))
            if n <= MAX_ABILITY:
                out[hero][n - 1] = a.group(4)
    return out


def bot_heroes():
    names = []
    for path in sorted(glob.glob(os.path.join(REPO, "bots/BotLib/hero_*.lua"))):
        names.append(os.path.basename(path)[len("hero_"):-len(".lua")])
    return names


def render(slots, shipped):
    lines = [
        "-- GENERATED by tools/agent/hero_slot_map.py -- do not hand-edit.",
        "--",
        "-- Engine ability SLOT ORDER per hero, from the game's own npc_heroes.txt",
        "-- (\"AbilityN\", 1-based upstream) re-keyed here to the 0-based slot",
        "-- index bot:GetAbilityInSlot uses, so a key IS a slot.  This is the",
        "-- input every `sAbilityList[N]` argument starts",
        "-- from: X.GetAbilityList walks these slots and compacts what it accepts.",
        "--",
        "-- Empty AbilityN entries and `generic_hidden` placeholders are kept",
        "-- VERBATIM -- the walk inserts generic_hidden like a real ability",
        "-- (aba_skill.lua, `if slot ~= 0`), so dropping them here would move every",
        "-- index after them.  Only heroes shipped in bots/BotLib are emitted.",
        "--",
        "-- This table says which ability is in which slot.  It does NOT say which",
        "-- ones the walk keeps: that turns on ability:IsHidden(), unreadable",
        "-- outside the game VM (tests/test_focus_innate_index_anchor.lua §2).",
        "",
        "return {",
    ]
    for hero in shipped:
        tbl = slots.get(hero)
        if not tbl:
            continue
        top = max(tbl)
        # 0-keyed on purpose: the key IS the engine slot index, so nobody has
        # to remember an off-by-one between this table and GetAbilityInSlot.
        cells = ["[%d]=%s" % (i, lua_str(tbl.get(i, ""))) for i in range(top + 1)]
        lines.append("    ['%s'] = { %s }," % (hero, ", ".join(cells)))
    lines.append("}")
    return "\n".join(lines) + "\n"


def lua_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def census(slots):
    """Which shipped hero files read an sAbilityList index, and what the
    NOTHING-IS-DROPPED world puts there."""
    rows, holes = [], []
    for hero in bot_heroes():
        path = os.path.join(REPO, "bots/BotLib/hero_%s.lua" % hero)
        src = open(path, encoding="utf-8", errors="replace").read()
        idx = sorted({int(m) for m in re.findall(r"sAbilityList\[(\d+)\]", src)})
        if not idx:
            continue
        tbl = slots.get(hero)
        if not tbl:
            if hero not in NOT_A_HERO:
                holes.append(hero)
            continue
        rows.append((hero, idx, tbl))
    return rows, holes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--census", action="store_true",
                    help="print the index-bind report instead of regenerating")
    ap.add_argument("--from-file", help="parse a local npc_heroes.txt (offline)")
    args = ap.parse_args()

    text = open(args.from_file, encoding="utf-8", errors="replace").read() \
        if args.from_file else fetch()
    slots = parse(text)
    if len(slots) < 100:
        sys.exit("parsed only %d hero blocks -- the upstream layout changed; "
                 "fix the parser before trusting anything downstream" % len(slots))

    if args.census:
        rows, holes = census(slots)
        if holes:
            sys.exit("no slot map for shipped hero(es): %s -- that is a parse "
                     "hole, not a hero without abilities" % ", ".join(holes))
        print("%d shipped hero files read an sAbilityList index" % len(rows))
        for hero, idx, tbl in rows:
            top = max(tbl)
            layout = ", ".join("%d=%s" % (i, tbl.get(i) or "<empty>")
                               for i in range(min(top, 6) + 1))
            print("  %-20s binds %-22s | %s" % (hero, idx, layout))
        return

    shipped = [h for h in bot_heroes() if h in slots]
    missing = [h for h in bot_heroes()
               if h not in slots and h not in NOT_A_HERO]
    if missing:
        sys.exit("no slot map for shipped hero(es): %s" % ", ".join(missing))
    out = os.path.join(REPO, OUT)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(render(slots, shipped))
    print("wrote %s (%d heroes)" % (OUT, len(shipped)))


if __name__ == "__main__":
    main()
