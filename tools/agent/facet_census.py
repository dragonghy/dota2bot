#!/usr/bin/env python3
"""Census: does a hero's FACET change which talent `sTalentList[N]` resolves to?

Why this exists (hero desk, 2026-08-27, GH #238 baton 2, last hero)
-------------------------------------------------------------------
`hero_skeleton_king.lua` shipped a blocking sentence in its own source, written
by the round that re-anchored the talent block:

    "Note both of his t20/t25 alternatives at [2] and [6] are FACET rows, and
     nothing in this repo reads which facet the game rolled -- settle that
     before pricing the pair."

That is a real hazard on its face.  `aba_skill.X.GetTalentList` walks
`bot:GetAbilityInSlot(0..25)` at runtime and appends every `IsTalent()` ability
in slot order, so `sTalentList[6]` is "whatever the engine put in the second
t20 slot for THIS hero in THIS game".  If a facet could swap a talent row, then
a t20/t25 price argued against one row would be an argument about a row the
game does not always ship, and -- worse -- `hero_skeleton_king.lua` binds
`talent6 = bot:GetAbilityByName( sTalentList[6] )` and reads `talent6:IsTrained()`
twice inside `X.ConsiderW` as a bank-threshold bypass.  A facet-dependent slot 6
would make that bypass mean different things in different games.

WHAT THIS MEASURES, AND WHY IT SETTLES IT
-----------------------------------------
The game's own `npc_heroes.txt` (the file `tools/agent/hero_slot_map.py` and
`tools/agent/talent_slot_census.py` already read) carries, per hero:

  * the talent run -- eight contiguous `"AbilityN" "special_bonus_*"` entries,
    N being the same slot index `bot:GetAbilityInSlot` reads (GH #209 / #214);
  * a `"Facets"` block -- one sub-block per facet, each with `Icon` / `Color` /
    `GradientID`, optionally `"Deprecated" "true"`, and optionally an
    `"Abilities"` sub-block that GRANTS an ability at a given `AbilityIndex`.

So the question has a file-local answer, and it is two separate answers that
must not be conflated:

  (1) STRUCTURAL -- does any facet block anywhere in the roster name a
      `special_bonus_*` row, or an `AbilityIndex` inside the talent run
      (10..17)?  If none does, no facet can move a talent slot for ANY hero,
      and the blocker is retired for the whole TALENTPRICE axis rather than
      for Wraith King alone.
  (2) PER-HERO -- is this hero's facet set live at all?  A facet marked
      `"Deprecated" "true"` cannot be rolled, so a hero whose entire block is
      deprecated has no facet roll to read in the first place.

THE CONTROL THAT MATTERS
------------------------
Answering (2) from Valve's `datafeed/herodata` endpoint would have produced a
FALSE finding this round: that endpoint returns `facets: []` and
`facet_abilities: []` for every hero queried (7/7 on 2026-08-27, Wraith King
and Bristleback included) -- and Bristleback demonstrably HAS facet machinery
in the KV.  An empty array there means "this endpoint does not serve facets",
not "this hero has none".  The KV is the source; the feed is not a second
opinion about facets.  Nor is "all facets are deprecated" true as a shortcut:
this census counts the live ones, and there are some.

Usage:
    python3 tools/agent/facet_census.py                  # roster summary
    python3 tools/agent/facet_census.py --focus          # focus five, verbose
    python3 tools/agent/facet_census.py --hero skeleton_king
    python3 tools/agent/facet_census.py --snapshot       # write tests/mock/hero_facets.lua
    python3 tools/agent/facet_census.py --check          # exit 3 if (1) is violated

LIMITS (read these before quoting a number)
  * This reads ONE file.  A facet could still change a talent's VALUE through a
    `required_facet` entry in the hero's own `npc_dota_hero_<name>.txt`
    AbilityValues -- that is a different question from which talent sits in a
    slot, and it is `special_value_key_census.py`'s ground, not this one's.
  * `Deprecated` is read as the literal KV key.  A facet could in principle be
    made unreachable some other way; this census would call that one live.
  * An empty `Facets` block and no `Facets` block at all are reported the same
    way (zero entries) -- the distinction has no consequence for either answer.
"""

import os
import re
import sys
import urllib.request

URL = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
       "dota/scripts/npc/npc_heroes.txt")
SNAPSHOT = "tests/mock/hero_facets.lua"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

FOCUS_FIVE = ["axe", "zuus", "skeleton_king", "lion", "crystal_maiden"]

# The talent run occupies AbilityN for N in this range (GH #214).  A facet that
# named an AbilityIndex inside it would be moving a talent row.
TALENT_SLOT_LO, TALENT_SLOT_HI = 10, 17

HERO_HDR = re.compile(r'^(\t*)"(npc_dota_hero_[A-Za-z0-9_]+)"\s*$', re.M)

# ANTI-VACUUM.  The first cut of this file compiled HERO_HDR without re.M, so
# split_heroes() matched nothing and the census printed
#   heroes 0 / facet entries 0 / focus five with a LIVE facet: none
# -- which is the SAME final sentence the correct run prints.  A parse that
# reads zero heroes must not be able to agree with the conclusion, so the floor
# is enforced rather than eyeballed.  127 heroes shipped at 7.41; the file
# carries a couple of non-playable entries, so the floor is set below that and
# is about detecting a broken parse, not about pinning the roster size.
MIN_HEROES = 100


def fetch(url=URL):
    req = urllib.request.Request(url, headers={"User-Agent": "dota2bot-agent"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read().decode("utf-8", "replace")


def _balanced(text, start):
    """Return (body, end) for the brace block that opens at or after `start`."""
    depth = 0
    opened = False
    for i in range(start, len(text)):
        c = text[i]
        if c == "{":
            depth += 1
            if not opened:
                opened = True
                body_start = i + 1
        elif c == "}":
            depth -= 1
            if opened and depth == 0:
                return text[body_start:i], i + 1
    return "", len(text)


def split_heroes(txt):
    """hero unit name -> its KV body text."""
    out = {}
    for m in HERO_HDR.finditer(txt):
        body, _ = _balanced(txt, m.end())
        out[m.group(2)] = body
    return out


def parse_facets(body):
    """[{name, deprecated, grants:[(index, ability)], names_talent_row:bool}]"""
    m = re.search(r'^(\t+)"Facets"\s*$', body, re.M)
    if not m:
        return []
    blk, _ = _balanced(body, m.end())
    indent = len(m.group(1)) + 1
    facets = []
    for fm in re.finditer(r'^\t{%d}"([A-Za-z0-9_]+)"\s*$' % indent, blk, re.M):
        sub, _ = _balanced(blk, fm.end())
        grants = []
        am = re.search(r'^\t+"Abilities"\s*$', sub, re.M)
        if am:
            abil_blk, _ = _balanced(sub, am.end())
            for em in re.finditer(r'^\t+"Ability\d+"\s*$', abil_blk, re.M):
                ent, _ = _balanced(abil_blk, em.end())
                nm = re.search(r'"AbilityName"\s+"([^"]+)"', ent)
                ix = re.search(r'"AbilityIndex"\s+"(\d+)"', ent)
                grants.append((int(ix.group(1)) if ix else None,
                               nm.group(1) if nm else None))
        idxs = [g[0] for g in grants if g[0] is not None]
        facets.append({
            "name": fm.group(1),
            "deprecated": bool(re.search(r'"Deprecated"\s+"true"', sub, re.I)),
            "grants": grants,
            # Either way of naming a talent row: by name, or by slot index.
            "names_talent_row": ("special_bonus" in sub)
                                or any(TALENT_SLOT_LO <= i <= TALENT_SLOT_HI
                                       for i in idxs),
        })
    return facets


def census(txt=None):
    txt = txt if txt is not None else fetch()
    heroes = split_heroes(txt)
    if len(heroes) < MIN_HEROES:
        raise SystemExit(
            "facet_census: parsed only %d heroes out of npc_heroes.txt (floor %d).\n"
            "That is a BROKEN PARSE, not a roster with no facets -- refusing to\n"
            "report, because every counter below would read zero and the summary\n"
            "line would still say 'focus five with a LIVE facet: none'."
            % (len(heroes), MIN_HEROES))
    return {h: parse_facets(b) for h, b in heroes.items()}


def short(hero_unit):
    return hero_unit[len("npc_dota_hero_"):]


def summarize(data):
    total = live = dep = 0
    offenders = []
    live_heroes = []
    for hero, facets in sorted(data.items()):
        if not facets:
            continue
        total += len(facets)
        alive = [f for f in facets if not f["deprecated"]]
        dep += len(facets) - len(alive)
        live += len(alive)
        if alive:
            live_heroes.append((short(hero), [f["name"] for f in alive]))
        for f in facets:
            if f["names_talent_row"]:
                offenders.append((short(hero), f["name"]))
    return total, live, dep, live_heroes, offenders


def print_hero(hero_short, facets):
    print("== %s -- %d facet entr%s"
          % (hero_short, len(facets), "y" if len(facets) == 1 else "ies"))
    if not facets:
        print("   (no Facets block -- no facet roll to read)")
        return
    for f in facets:
        state = "DEPRECATED (cannot be rolled)" if f["deprecated"] else "LIVE"
        print("   %-42s %s" % (f["name"], state))
        for ix, ab in f["grants"]:
            print("        grants %-40s at AbilityIndex %s" % (ab, ix))
        if f["names_talent_row"]:
            print("        !! NAMES A TALENT ROW")


def lua_quote(s):
    return "'" + str(s).replace("\\", "\\\\").replace("'", "\\'") + "'"


def write_snapshot(data):
    total, live, dep, live_heroes, offenders = summarize(data)
    L = [
        "-- GENERATED by tools/agent/facet_census.py --snapshot -- do not hand-edit.",
        "--",
        "-- Read off the game's own npc_heroes.txt (the same file",
        "-- tools/agent/talent_slot_census.py takes slot order from).  It answers the",
        "-- question hero_skeleton_king.lua parked in its own source: can a FACET",
        "-- change which talent sits in a slot, so that a t20/t25 price is an argument",
        "-- about a row the game does not always ship?",
        "--",
        "-- Two answers, kept apart on purpose:",
        "--   NAMES_TALENT_ROW  -- roster-wide, how many facet blocks name a",
        "--                        special_bonus_* row or an AbilityIndex inside the",
        "--                        talent run (10..17).  Zero means no facet can move",
        "--                        a talent slot for ANY hero.",
        "--   per-hero FACETS   -- whether this hero has a facet that can be rolled",
        "--                        at all.  A `Deprecated true` entry cannot.",
        "--",
        "-- NOT a substitute for the KV value census: a facet can still gate a",
        "-- talent's VALUE via `required_facet` inside AbilityValues.  Different",
        "-- question, different tool (special_value_key_census.py).",
        "--",
        "-- Regenerate after a patch:",
        "--   python3 tools/agent/facet_census.py --snapshot",
        "",
        "local X = {}",
        "",
        "-- Roster-wide counters, over every hero in npc_heroes.txt.",
        "X.ROSTER = {",
        "    facet_entries      = %d," % total,
        "    deprecated         = %d," % dep,
        "    live               = %d," % live,
        "    names_talent_row   = %d," % len(offenders),
        "}",
        "",
        "-- Heroes with at least one LIVE (rollable) facet.  Recorded because the",
        "-- convenient shortcut 'facets are dead everywhere now' is FALSE, and three",
        "-- of these are in this project's candidate hero pool.",
        "X.LIVE_FACET_HEROES = {",
    ]
    for h, names in live_heroes:
        L.append("    [%s] = { %s }," % (lua_quote(h), ", ".join(lua_quote(n) for n in names)))
    L += [
        "}",
        "",
        "-- Focus five, in full.",
        "X.FOCUS = {",
    ]
    for hero in FOCUS_FIVE:
        facets = data.get("npc_dota_hero_" + hero, [])
        L.append("    [%s] = {" % lua_quote(hero))
        for f in facets:
            grants = ", ".join(lua_quote(ab) for _, ab in f["grants"] if ab)
            L.append("        { name = %s, deprecated = %s, grants = { %s } },"
                     % (lua_quote(f["name"]), "true" if f["deprecated"] else "false", grants))
        L.append("    },")
    L += ["}", "", "return X", ""]
    with open(os.path.join(REPO, SNAPSHOT), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L))
    print("wrote " + SNAPSHOT)


def main(argv):
    data = census()
    total, live, dep, live_heroes, offenders = summarize(data)

    if "--snapshot" in argv:
        write_snapshot(data)
        return 0

    if "--hero" in argv:
        name = argv[argv.index("--hero") + 1]
        print_hero(name, data.get("npc_dota_hero_" + name, []))
        return 0

    if "--focus" in argv:
        for hero in FOCUS_FIVE:
            print_hero(hero, data.get("npc_dota_hero_" + hero, []))
        print()

    print("heroes in npc_heroes.txt : %d" % len(data))
    print("facet entries            : %d  (deprecated %d, live %d)" % (total, dep, live))
    print("facet blocks naming a talent row (special_bonus_* or AbilityIndex 10..17): %d"
          % len(offenders))
    for h, f in offenders:
        print("   !! %s / %s" % (h, f))
    print()
    print("heroes with a LIVE facet : %d" % len(live_heroes))
    for h, names in live_heroes:
        print("   %-22s %s" % (h, ", ".join(names)))
    print()
    focus_live = [h for h in FOCUS_FIVE
                  if any(not f["deprecated"]
                         for f in data.get("npc_dota_hero_" + h, []))]
    print("focus five with a LIVE facet: %s" % (", ".join(focus_live) or "none"))

    if "--check" in argv and offenders:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
