#!/usr/bin/env python3
"""Census: `ability:GetAbilityDamage()` reads that are structurally zero.

Why this exists (hero group, 2026-08-25, axis `0DMG`)
----------------------------------------------------
`CAbility:GetAbilityDamage()` is documented in docs/BOT_API_REFERENCE.md as
"base damage of the ability at current level".  It is backed by the ability's
top-level `AbilityDamage` KV field -- NOT by `AbilityValues/damage`.  Modern
Dota moved per-level damage into `AbilityValues` years ago, so an ability that
does not declare `AbilityDamage` answers **0**, silently, with no error and no
way to see it from inside a game (`print()` never reaches the server console
and the engine error handler is broken -- AGENTS.md).

This is the same silent-zero family as GH #162 (a `GetSpecialValueInt` key that
Valve renamed), arriving through a different call.  The difference is scale:
#162 was one key on one ability; this one is a property of the whole call.

WHAT IT PROVES AND WHAT IT DOES NOT
-----------------------------------
The criterion is deliberately ONE-DIRECTIONAL and, unlike #162's, it does not
need to resolve a Lua handle to an ability at all:

  * a `GetAbilityDamage()` call inside `bots/BotLib/hero_<h>.lua` can only ever
    be taken on one of hero `<h>`'s own abilities.  So if NOT ONE of `<h>`'s
    abilities declares a nonzero `AbilityDamage`, that read is **0 whichever
    handle it was taken on** -- a proof, with no handle resolution;
  * if `<h>` does have such an ability, this script says UNRESOLVED and proves
    nothing either way, because it does not know which ability the handle
    points at (the same self-declared gap #162's key census has).

And a proven zero is a fact about the READ, never a verdict on the branch: a
zero fed to `J.WillMagicKillTarget` kills that branch, while a zero fed to
`FindAoELocation`'s `nMaxHealth` **widens** it (0 there means "no HP filter",
docs/BOT_API_REFERENCE.md:1288).  Direction has to be read per call site.

Files outside `bots/BotLib/hero_*.lua` (FunLib, modes, item usage) can hold a
handle for any hero's ability, so their sites are checked against the union
over every hero we ship and reported separately -- weaker still.

Usage:

    python3 tools/agent/ability_damage_census.py            # census
    python3 tools/agent/ability_damage_census.py --snapshot # tests/mock/ability_damage.lua

Network: one HTTPS GET per shipped hero against the same public d2vpkr mirror
`gen_ability_meta.py` and `special_value_key_census.py` already use (no AWS,
no cost).
"""

import glob
import os
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
        "dota/scripts/npc/heroes/npc_dota_hero_%s.txt")
OUT = "tests/mock/ability_damage.lua"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

CALL_RE = re.compile(r"GetAbilityDamage\s*\(\s*\)")


def strip_comments(src):
    """Drop Lua line comments BEFORE call sites are counted.

    The reasoning blocks in these files quote API names while explaining them,
    and a parser that reads prose reports the prose (hero charter, GH #136).
    """
    return re.sub(r"--[^\n]*", "", src)


def hero_names():
    out = []
    for path in sorted(glob.glob(os.path.join(REPO, "bots/BotLib/hero_*.lua"))):
        out.append(os.path.basename(path)[len("hero_"):-len(".lua")])
    return out


def fetch(hero):
    try:
        with urllib.request.urlopen(BASE % hero, timeout=45) as fh:
            return hero, fh.read().decode("utf-8", "replace")
    except Exception:                                         # noqa: BLE001
        return hero, None   # a hero we ship that upstream has no KV file for


def ability_damage(text):
    """ability name -> its `AbilityDamage` string, for the blocks that have one.

    Walks the KV block structure: depth 1 is the file's root block, depth 2 is
    one ability, so a `"k" "v"` pair at depth 2 is a top-level ability field.
    """
    out, stack, pend = {}, [], None
    for raw in text.splitlines():
        line = raw.split("//")[0].strip()
        if not line:
            continue
        if line == "{":
            stack.append(pend)
            pend = None
            continue
        if line == "}":
            if stack:
                stack.pop()
            continue
        pair = re.match(r'^"([^"]+)"\s+"([^"]*)"$', line)
        if pair:
            if len(stack) == 2 and stack[1] and pair.group(1) == "AbilityDamage":
                out[stack[1]] = pair.group(2)
            continue
        lone = re.match(r'^"([^"]+)"$', line)
        if lone:
            pend = lone.group(1)
    return out


def nonzero(values):
    """True when at least one per-level entry of an `AbilityDamage` is not 0."""
    for tok in values.split():
        try:
            if float(tok) != 0:
                return True
        except ValueError:
            return True     # a non-numeric entry is not something we can call zero
    return False


def call_sites():
    """(relative path, line number) for every GetAbilityDamage() read in bots/."""
    out = []
    for path in sorted(glob.glob(os.path.join(REPO, "bots/**/*.lua"), recursive=True)):
        src = open(path, encoding="utf-8").read()
        for i, line in enumerate(strip_comments(src).splitlines(), 1):
            if CALL_RE.search(line):
                out.append((os.path.relpath(path, REPO), i))
    return out


def census():
    heroes = hero_names()
    with ThreadPoolExecutor(16) as ex:
        kv = dict(ex.map(fetch, heroes))
    missing = sorted(h for h in heroes if kv[h] is None)

    declared, live = {}, {}
    for hero, text in kv.items():
        if text is None:
            continue
        for name, values in ability_damage(text).items():
            declared[(hero, name)] = values
            if nonzero(values):
                live.setdefault(hero, {})[name] = values

    proven, unresolved, global_sites = [], [], []
    for path, line in call_sites():
        base = os.path.basename(path)
        if base.startswith("hero_") and path.startswith("bots/BotLib/"):
            hero = base[len("hero_"):-len(".lua")]
            if kv.get(hero) is None:
                unresolved.append((path, line, hero, "no upstream KV"))
            elif hero in live:
                unresolved.append((path, line, hero, ", ".join(sorted(live[hero]))))
            else:
                proven.append((path, line, hero))
        else:
            global_sites.append((path, line))
    return dict(heroes=heroes, missing=missing, declared=declared, live=live,
                proven=proven, unresolved=unresolved, global_sites=global_sites)


def report(c):
    print("heroes shipped: %d (no upstream KV: %d%s)"
          % (len(c["heroes"]), len(c["missing"]),
             (" -- " + ", ".join(c["missing"])) if c["missing"] else ""))
    print("abilities declaring AbilityDamage: %d, of which nonzero: %d"
          % (len(c["declared"]), sum(len(v) for v in c["live"].values())))
    for hero in sorted(c["live"]):
        for name, values in sorted(c["live"][hero].items()):
            print("    %-22s %-34s %s" % (hero, name, values))
    print()
    print("GetAbilityDamage() call sites: %d"
          % (len(c["proven"]) + len(c["unresolved"]) + len(c["global_sites"])))
    print("  PROVEN-ZERO (owning hero declares no nonzero AbilityDamage): %d"
          % len(c["proven"]))
    for path, line, hero in c["proven"]:
        print("    %s:%d" % (path, line))
    print("  UNRESOLVED (owning hero has one; handle not resolved here): %d"
          % len(c["unresolved"]))
    for path, line, _hero, why in c["unresolved"]:
        print("    %s:%d  (%s)" % (path, line, why))
    print("  UNRESOLVED-GLOBAL (not a hero file; handle can be any hero's): %d"
          % len(c["global_sites"]))
    for path, line in c["global_sites"]:
        print("    %s:%d" % (path, line))


def snapshot(c):
    rows = []
    for hero in sorted(c["live"]):
        inner = ", ".join("['%s'] = '%s'" % (n, v)
                          for n, v in sorted(c["live"][hero].items()))
        rows.append("    ['%s'] = { %s },""" % (hero, inner))
    body = "\n".join(rows)
    text = """-- GENERATED by tools/agent/ability_damage_census.py -- do not hand-edit.
--
-- Which abilities, of every hero this repo ships, declare a NONZERO top-level
-- `AbilityDamage` in the game's own hero KV.  `CAbility:GetAbilityDamage()`
-- reads that field and nothing else, so every ability absent from this table
-- answers 0 -- silently (hero charter, axis `0DMG`).
--
-- Used as a ratchet: tests/test_ability_damage_reads.lua fails when a hero
-- file's GetAbilityDamage() read stops being provably zero, or when a new one
-- appears.  Regenerate after a patch:
--
--     python3 tools/agent/ability_damage_census.py --snapshot

local X = {}

-- hero (bots/BotLib/hero_<key>.lua) -> ability name -> per-level AbilityDamage.
X.NONZERO = {
%s
}

return X
""" % body
    path = os.path.join(REPO, OUT)
    open(path, "w", encoding="utf-8").write(text)
    print("wrote %s (%d heroes)" % (OUT, len(c["live"])))


def main(argv):
    c = census()
    if "--snapshot" in argv:
        snapshot(c)
        return 0
    report(c)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
