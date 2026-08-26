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

  * SLOT ORDER comes from the game's own `npc_heroes.txt` on the d2vpkr mirror
    -- the same file `tools/agent/hero_slot_map.py` reads for abilities.  A
    hero's talents are a CONTIGUOUS RUN of eight `"AbilityN" "special_bonus_*"`
    entries, and N is the same 1-based slot index `bot:GetAbilityInSlot` reads
    0-based.  So the Nth entry of that run IS `sTalentList[N]`, by the same
    arithmetic GH #209 measured for abilities.
  * WHAT EACH TALENT DOES comes from the game's `npc_dota_hero_<name>.txt` on
    the same mirror -- the file `special_value_key_census.py` reads.  A
    talent appears there as an override key inside the AbilityValues block it
    modifies, so `special_bonus_unique_lion_4` showing up under
    `lion_voodoo / AbilityValues / radius` IS the proof that it is the Hex-AoE
    talent.

So a talent's (ability, key) list is a proof of what it modifies.  The converse
is NOT true: a talent with an EMPTY list is not proven inert -- generic rows
(`special_bonus_hp_200`, `special_bonus_intelligence_12`) and facet/innate rows
live in npc_abilities.txt, which this script does not read.  Empty means
"nothing in this hero's own KV names it", nothing more.

⚠️ THE SLOT-ORDER SOURCE CHANGED 2026-08-26 (GH #214), AND THE OLD ONE WAS WRONG
-------------------------------------------------------------------------------
The first cut took slot order from odota `dotaconstants build/hero_abilities.json`
(`talents[]`).  That is a DISPLAY list, not a slot list, and -- measured, not
guessed -- it is also a patch behind: `--cross-check` compares it against this
file's KV run and Valve's own datafeed, and on 2026-08-26 the datafeed agreed
with the KV run on 22 of 22 heroes read (176 rows) while odota disagreed on 18
of them.  (The 22 are the heroes `--cross-check` prints: every hero where odota
and the KV run differ, plus the focus five.  Roster-wide the two mirrors agree
on 106 of 127.)  One of those 18 is a focus hero: Wraith King's slot [4] is
`special_bonus_hp_300` (datafeed `special_values` says the value is literally
300), and odota still says `special_bonus_hp_350`.  That stale row was copied
into `tests/mock/talent_slots.lua` and into `tests/test_focus_talent_anchor.lua`
on 2026-08-24 as a "correction" of the hero file, which had it right.

The methodological half is worth more than the row: that correction was recorded
as "odota + the hero KV read hp_350", i.e. TWO agreeing sources.  It cannot have
been two -- `npc_dota_hero_skeleton_king.txt` carries AbilityValues override
keys and no talent NAMES at all, which is exactly what this module's own
docstring says three paragraphs up.  A generic talent like `special_bonus_hp_300`
can never appear in it.  So the "second source" was structurally incapable of
saying anything, and the one real source was the stale one.
⇒ Before writing "two sources agree", check that the second one is capable of
   disagreeing.

Usage:

    python3 tools/agent/talent_slot_census.py               # human-readable table
    python3 tools/agent/talent_slot_census.py --snapshot    # write the Lua table
    python3 tools/agent/talent_slot_census.py --cross-check # KV vs odota vs Valve

Network: `npc_heroes.txt` (~900 KB) plus one HTTPS GET per focus hero.
`--cross-check` adds odota's `hero_abilities.json` and one datafeed GET per
hero compared.  No AWS, no cost.
"""

import json
import os
import re
import sys
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

KV = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
      "dota/scripts/npc/heroes/npc_dota_hero_%s.txt")
HEROES_KV = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
             "dota/scripts/npc/npc_heroes.txt")
ABILITIES = ("https://raw.githubusercontent.com/odota/dotaconstants/master/"
             "build/hero_abilities.json")
# Valve's own feed -- the adjudicator when the two mirrors disagree.  Same
# endpoint tests/test_focus_talent_anchor.lua records its names from.
FEED = "https://www.dota2.com/datafeed/herodata?language=english&hero_id=%d"
HEROLIST = "https://www.dota2.com/datafeed/herolist?language=english"

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


# npc_heroes.txt layout.  Both regexes and the depth rule are the ones
# tools/agent/hero_slot_map.py already measured against this file: hero HEADERS
# are inconsistently indented (a few sit at column 0) but hero FIELDS always sit
# at exactly two tabs, while the nested ability-draft block that repeats
# "Ability1".."Ability4" with a different meaning sits at three.
HDR = re.compile(r'^(\t*)"(npc_dota_hero_[A-Za-z0-9_]+)"\s*$')
ABIL = re.compile(r'^(\t*)"(Ability(\d+))"\s+"([^"]*)"')
FIELD_DEPTH = 2

TALENT_ROWS = 8


def parse_talent_slots(text):
    """hero short name -> [(slot, talent name), ...] in engine slot order.

    A hero's talents are the run of `"AbilityN" "special_bonus_*"` entries in
    its block, keyed here by the 0-based slot `bot:GetAbilityInSlot` uses
    (upstream N is 1-based).  Heroes with no talent entries are omitted; a hero
    whose run is not exactly TALENT_ROWS long, or not contiguous, is returned
    as-is so callers can fail loudly instead of silently renumbering.

    ⚠️ THE RUN DOES NOT ALWAYS START AT Ability10.  Measured 2026-08-26 over all
    127 heroes: it is Ability10 for 123 of them, but kez and rubick start at
    Ability12, largo at Ability15 and invoker at Ability17 -- those heroes carry
    real abilities in the slots below.  Anything that hardcodes 10 reads an
    ABILITY as a talent for four heroes, which is how the first draft of this
    function reported invoker's talents as `invoker_emp`, `invoker_alacrity`...
    """
    out, hero = {}, None
    for raw in text.splitlines():
        line = raw.rstrip("\r")
        m = HDR.match(line)
        if m:
            hero = m.group(2)[len("npc_dota_hero_"):]
            out.setdefault(hero, [])
            continue
        if hero is None:
            continue
        a = ABIL.match(line)
        if a and len(a.group(1)) == FIELD_DEPTH and a.group(4).startswith("special_bonus_"):
            out[hero].append((int(a.group(3)) - 1, a.group(4)))
    return {h: rows for h, rows in out.items() if rows}


def contiguity_error(rows):
    """Why this hero's talent run cannot be read as sTalentList[1..8], or None."""
    if len(rows) != TALENT_ROWS:
        return "%d talent entries, expected %d" % (len(rows), TALENT_ROWS)
    slots = [s for s, _ in rows]
    if slots != list(range(slots[0], slots[0] + TALENT_ROWS)):
        return "talent slots %s are not contiguous" % slots
    return None


def kv_talents(text=None):
    """{ hero -> [name, ...] } indexed 1..8 by position, from npc_heroes.txt."""
    slots = parse_talent_slots(text if text is not None else get(HEROES_KV))
    if len(slots) < 100:
        raise SystemExit(
            "parsed talents for only %d heroes -- the upstream layout changed; "
            "fix the parser before trusting anything downstream" % len(slots))
    return {h: [n for _, n in rows] for h, rows in slots.items()}, slots


def census(heroes_text=None):
    """{ hero -> [ (slot, talent name, [what it modifies]), ... ] }"""
    names, slots = kv_talents(heroes_text)
    out = {}
    for hero in FOCUS_FIVE:
        if hero not in names:
            raise SystemExit("npc_heroes.txt names no talents for " + hero)
        bad = contiguity_error(slots[hero])
        if bad:
            raise SystemExit("%s: %s -- sTalentList[N] is not row N for this "
                             "hero, so nothing below is safe to snapshot"
                             % (hero, bad))
        mods = talent_overrides(get(KV % hero))
        out[hero] = [(i, name, sorted(mods.get(name, ())))
                     for i, name in enumerate(names[hero], 1)]
    return out


def cross_check(heroes_text=None):
    """KV run vs odota `talents[]` vs Valve's datafeed, per hero.

    Returns [(hero, kv, odota, feed_or_None)] for every hero where the two
    mirrors disagree, plus the focus five (always, so a clean run still prints
    the rows the snapshot rests on).  The datafeed is fetched only for the
    heroes actually printed -- it is the adjudicator, not a third census.
    """
    names, _ = kv_talents(heroes_text)
    od = {h[len("npc_dota_hero_"):]:
          [t["name"] for t in v.get("talents", ())
           if t["name"].startswith("special_bonus_")]
          for h, v in json.loads(get(ABILITIES)).items()}
    interesting = [h for h in sorted(names)
                   if h in od and od[h] != names[h]]
    interesting += [h for h in FOCUS_FIVE if h not in interesting]
    ids = {x["name"][len("npc_dota_hero_"):]: x["id"]
           for x in json.loads(get(HEROLIST))["result"]["data"]["heroes"]}
    rows = []
    for hero in interesting:
        feed = None
        if hero in ids:
            entry = json.loads(get(FEED % ids[hero]))["result"]["data"]["heroes"][0]
            feed = [t["name"] for t in entry.get("talents", ())
                    if t["name"].startswith("special_bonus_")]
        rows.append((hero, names[hero], od.get(hero), feed))
    return rows


def lua_quote(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def snapshot_header():
    """The generated file's preamble.

    Separated from write_snapshot so a test can read it WITHOUT regenerating:
    checking only the committed .lua lets a generator that stops naming its
    source ride until the next patch, which is a whole release cycle of a
    reader having no way to tell where the table came from.  (Measured: that
    exact mutation escaped the first cut of tests/test_talent_slot_census.py.)
    """
    return [
        "-- GENERATED by tools/agent/talent_slot_census.py --snapshot "
        "-- do not hand-edit.",
        "--",
        "-- What `sTalentList[N]` resolves to for each focus hero, and what that",
        "-- talent modifies in the game's own hero KV.  Slot order is READ OUT of",
        "-- npc_heroes.txt (the contiguous run of \"AbilityN\" \"special_bonus_*\"",
        "-- entries, N being the same slot bot:GetAbilityInSlot indexes), so",
        "-- 1 = t10 left, 2 = t10 right, ... 8 = t25 right -- the order",
        "-- aba_skill.X.GetTalentList builds its list in.  Until 2026-08-26 this",
        "-- came from odota's display list instead, which was a patch behind on",
        "-- Wraith King's slot 4 (GH #214).",
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


def write_snapshot(data):
    lines = snapshot_header()
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


def print_cross_check(rows):
    disagree_od = disagree_kv = 0
    for hero, kv, od, feed in rows:
        marks = []
        if od is None:
            marks.append("odota=absent")
        elif od != kv:
            marks.append("odota DIFFERS")
            disagree_od += 1
        if feed is None:
            marks.append("feed=unavailable")
        elif feed != kv:
            marks.append("FEED DIFFERS FROM KV")
            disagree_kv += 1
        print("== %-20s %s" % (hero, ", ".join(marks) or "all three agree"))
        for i in range(TALENT_ROWS):
            a = kv[i] if i < len(kv) else "<none>"
            b = od[i] if od and i < len(od) else "<none>"
            c = feed[i] if feed and i < len(feed) else "<none>"
            if a != b or (feed is not None and a != c):
                print("   [%d] kv=%-50s odota=%-50s feed=%s" % (i + 1, a, b, c))
    print()
    print("heroes printed: %d; odota disagrees with the KV run on %d; "
          "Valve's feed disagrees with the KV run on %d"
          % (len(rows), disagree_od, disagree_kv))
    # The whole point of the adjudicator: a feed/KV disagreement means the SOURCE
    # is wrong and the snapshot must not be regenerated until it is understood.
    # An odota disagreement alone only means the secondary mirror is stale.
    return 3 if disagree_kv else 0


def main(argv):
    if "--cross-check" in argv:
        return print_cross_check(cross_check())
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
