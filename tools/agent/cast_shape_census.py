#!/usr/bin/env python3
"""Census: cast orders whose SHAPE the ability's own KV cannot accept.

Why this exists (hero group, 2026-08-25, axis `CASTSHAPE`)
----------------------------------------------------------
Every previous axis this group opened asked what a NUMBER was worth -- a
constant against the KV (`zusstatic`), a key that got renamed (#162), a slot
index that points at the other half of a talent row (#166), a table that has
no role dimension (#170), an API call that reads a field nobody declares any
more (#175).  This one asks a different question about the same files:

    the file decided to cast.  Can the engine accept the order it wrote?

`bot:Action*_UseAbility( h )`, `...OnEntity( h, u )` and `...OnLocation( h, v )`
are three DIFFERENT orders, and which of them an ability accepts is fixed by
its `AbilityBehavior` flags in the game's hero KV:

    DOTA_ABILITY_BEHAVIOR_NO_TARGET     -> ...UseAbility( h )
    DOTA_ABILITY_BEHAVIOR_UNIT_TARGET   -> ...UseAbilityOnEntity( h, u )
    DOTA_ABILITY_BEHAVIOR_POINT         -> ...UseAbilityOnLocation( h, v )
    DOTA_ABILITY_BEHAVIOR_PASSIVE       -> none of them, ever

An order of the wrong shape does not raise: bot-side there is no way to see it
at all (AGENTS.md: `print()` never reaches the server console and the engine
error handler is broken).  It just does not happen -- and the branch that
issued it usually `return`s, so the whole dispatch tick goes with it.

WHAT IT PROVES AND WHAT IT DOES NOT
-----------------------------------
Strong, and the reason PASSIVE is reported on its own:

  * `PASSIVE` in an ability's declared behavior is a proof about the ability,
    not a guess about the handle's provenance -- no cast order of any shape is
    executable on it.  When the site is also the first branch of a dispatch
    chain that `return`s, the cost of being wrong about it is the whole tick,
    which is why it is worth separating from the rest.

Weaker, and reported separately for that reason:

  * SHAPE-MISMATCH (an order shape absent from the flags) has real exceptions
    the flags alone do not settle -- `ALT_CASTABLE`, `AUTOCAST`, abilities that
    the engine lets a point order fall through on, and behavior overrides that
    arrive from a talent or a facet rather than the base block.  Read it as a
    list of questions, not a list of defects.

One-directional, exactly like #162's key census and for the same reason: this
script resolves a Lua variable to an ability name ONLY when the file binds it
to a string literal (`local X = bot:GetAbilityByName('name')`).  A variable
bound through `sAbilityList[N]`, a talent list, or a parameter is reported
UNRESOLVED and proves nothing either way -- the handle->ability step is still
the missing half (GH #151, GH #162).  So:

    a hit is a fact; a miss is silence, never a clean bill of health.

Usage:

    python3 tools/agent/cast_shape_census.py            # census
    python3 tools/agent/cast_shape_census.py --snapshot # tests/mock/ability_behavior.lua

Network: one HTTPS GET per shipped hero against the same public d2vpkr mirror
`gen_ability_meta.py`, `special_value_key_census.py` and
`ability_damage_census.py` already use (no AWS, no cost).
"""

import glob
import os
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
        "dota/scripts/npc/heroes/npc_dota_hero_%s.txt")
OUT = "tests/mock/ability_behavior.lua"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# `local <var> = bot:GetAbilityByName( '<literal>' )` -- the only binding shape
# this script will resolve.  Both quote styles are in the tree.
BIND_RE = re.compile(
    r"""local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"""
    r"""bot:GetAbilityByName\(\s*['"]([a-z0-9_]+)['"]\s*\)""")

# Action_ / ActionQueue_ / ActionPush_ x { UseAbility, OnEntity, OnLocation, OnTree }
CALL_RE = re.compile(
    r"""Action(?:Queue|Push)?_UseAbility(OnEntity|OnLocation|OnTree)?\("""
    r"""\s*([A-Za-z_][A-Za-z0-9_]*)\s*[,)]""")

# order suffix -> the behavior flag that makes that order executable.
SHAPE_FLAG = {
    None: "DOTA_ABILITY_BEHAVIOR_NO_TARGET",
    "OnEntity": "DOTA_ABILITY_BEHAVIOR_UNIT_TARGET",
    "OnLocation": "DOTA_ABILITY_BEHAVIOR_POINT",
    "OnTree": "DOTA_ABILITY_BEHAVIOR_POINT",
}
# A toggle takes the no-target order; an autocast ability answers the same one.
SHAPE_ALSO_OK = {
    None: ("DOTA_ABILITY_BEHAVIOR_TOGGLE", "DOTA_ABILITY_BEHAVIOR_AUTOCAST",
           "DOTA_ABILITY_BEHAVIOR_IMMEDIATE"),
    "OnEntity": ("DOTA_ABILITY_BEHAVIOR_AUTOCAST",),
    "OnLocation": ("DOTA_ABILITY_BEHAVIOR_AOE",),
    "OnTree": ("DOTA_ABILITY_BEHAVIOR_AOE",),
}


def strip_comments(src):
    """Drop Lua line comments BEFORE anything is counted.

    These files carry long reasoning blocks that quote the very API names being
    explained, and a parser that reads prose reports the prose (hero charter,
    GH #136 -- and `test_gate_claim_consistency` learned the same lesson from
    the other end in GH #162).

    Long-bracket blocks (`--[[ ... ]]`, `--[==[ ... ]==]`) go FIRST and whole.
    Stripping only line comments would delete the `--[[` opener and leave the
    block's BODY looking like code -- the failure runs toward false hits, which
    is the direction that costs a reader an investigation.
    """
    src = re.sub(r"--\[(=*)\[.*?\]\1\]",
                 lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
    return re.sub(r"--[^\n]*", "", src)


def hero_names():
    out = []
    for path in sorted(glob.glob(os.path.join(REPO, "bots/BotLib/hero_*.lua"))):
        out.append(os.path.basename(path)[len("hero_"):-len(".lua")])
    return out


def fetch(hero):
    try:
        req = urllib.request.Request(BASE % hero,
                                     headers={"User-Agent": "dota2bot-agent"})
        with urllib.request.urlopen(req, timeout=45) as fh:
            return hero, fh.read().decode("utf-8", "replace")
    except Exception:                                         # noqa: BLE001
        return hero, None   # a hero we ship that upstream has no KV file for


def behaviors(text):
    """ability name -> its top-level `AbilityBehavior` string.

    Walks the KV block structure: depth 1 is the file's root block, depth 2 is
    one ability, so a `"k" "v"` pair at depth 2 is a top-level ability field.
    Nested blocks (`AbilityValues`, `AbilitySpecial`) sit deeper and are
    therefore never mistaken for ability names.

    Braces are COUNTED per line rather than matched as lone `{` / `}` lines.
    A lone-line reader desynchronises on the first `{` that shares a line with
    anything else and then silently drops every ability after it -- measured:
    it lost `brewmaster_liquid_courage`, an ability that is in the file with
    PASSIVE right there on the next line.  A parser that goes quiet on the rest
    of a file is worse than one that errors, because the census reads as
    "nothing there".
    """
    out, depth, pend, cur, fields = {}, 0, None, None, {}

    def flush():
        if cur is not None and "AbilityBehavior" in fields:
            out[cur] = fields["AbilityBehavior"]

    for raw in text.splitlines():
        line = raw.split("//")[0]
        stripped = line.strip()
        if not stripped:
            continue
        lone = re.match(r'^"([A-Za-z0-9_]+)"$', stripped)
        if lone and depth == 1:
            pend = lone.group(1)
        if "{" in stripped:
            depth += stripped.count("{")
            if depth == 2 and pend is not None:
                flush()
                cur, fields, pend = pend, {}, None
        if depth == 2 and cur is not None:
            pair = re.match(r'^"([A-Za-z0-9_]+)"\s+"([^"]*)"', stripped)
            if pair:
                fields.setdefault(pair.group(1), pair.group(2))
        if "}" in stripped:
            new_depth = depth - stripped.count("}")
            if depth == 2 and new_depth < 2:
                flush()
                cur, fields = None, {}
            depth = new_depth
    flush()
    return out


def flags(behavior):
    return set(tok.strip() for tok in behavior.split("|") if tok.strip())


def sites():
    """Every cast order in a hero file, with the name it resolves to (or None)."""
    out = []
    for path in sorted(glob.glob(os.path.join(REPO, "bots/BotLib/hero_*.lua"))):
        hero = os.path.basename(path)[len("hero_"):-len(".lua")]
        src = strip_comments(open(path, encoding="utf-8").read())
        bound = dict((m.group(1), m.group(2)) for m in BIND_RE.finditer(src))
        for i, line in enumerate(src.splitlines(), 1):
            for m in CALL_RE.finditer(line):
                shape, var = m.group(1), m.group(2)
                out.append((hero, os.path.relpath(path, REPO), i, var,
                            bound.get(var), shape))
    return out


def census():
    heroes = hero_names()
    with ThreadPoolExecutor(16) as ex:
        kv = dict(ex.map(fetch, heroes))
    missing = sorted(h for h in heroes if kv[h] is None)

    beh = {}
    for hero, text in kv.items():
        if text is None:
            continue
        for name, value in behaviors(text).items():
            beh.setdefault(hero, {})[name] = value

    passive, mismatch, unresolved, nokv = [], [], [], []
    for hero, path, line, var, name, shape in sites():
        if name is None:
            unresolved.append((path, line, var, shape))
            continue
        value = beh.get(hero, {}).get(name)
        if value is None:
            nokv.append((path, line, var, name, shape))
            continue
        fl = flags(value)
        if "DOTA_ABILITY_BEHAVIOR_PASSIVE" in fl:
            passive.append((path, line, var, name, shape, value))
        elif not ({SHAPE_FLAG[shape]} | set(SHAPE_ALSO_OK[shape])) & fl:
            mismatch.append((path, line, var, name, shape, value))
    return dict(heroes=heroes, missing=missing, beh=beh, passive=passive,
                mismatch=mismatch, unresolved=unresolved, nokv=nokv,
                total=len(sites()))


FOCUS = ("axe", "zuus", "skeleton_king", "lion", "crystal_maiden")


def order(shape):
    return "UseAbility" + (shape or "")


def report(c):
    print("heroes shipped: %d (no upstream KV: %d%s)"
          % (len(c["heroes"]), len(c["missing"]),
             (" -- " + ", ".join(c["missing"])) if c["missing"] else ""))
    print("cast orders in bots/BotLib/hero_*.lua: %d" % c["total"])
    print("  resolvable to a literal ability name: %d"
          % (c["total"] - len(c["unresolved"])))
    print()
    print("PASSIVE-DISPATCH (the ability declares PASSIVE; no order shape can"
          " execute): %d" % len(c["passive"]))
    for path, line, var, name, shape, _v in c["passive"]:
        star = "  <-- FOCUS" if any(path.endswith("hero_%s.lua" % h)
                                    for h in FOCUS) else ""
        print("    %s:%d  %s(%s) -> %s%s"
              % (path, line, order(shape), var, name, star))
    print()
    print("SHAPE-MISMATCH (order shape absent from the flags; weaker -- see the"
          " module docstring): %d" % len(c["mismatch"]))
    for path, line, var, name, shape, value in c["mismatch"]:
        print("    %s:%d  %s(%s) -> %s\n        %s"
              % (path, line, order(shape), var, name, value))
    print()
    print("NO-KV (name absent from the owning hero's KV; NOT a proof -- generic"
          " abilities live elsewhere): %d" % len(c["nokv"]))
    for path, line, var, name, shape in c["nokv"]:
        print("    %s:%d  %s(%s) -> %s" % (path, line, order(shape), var, name))
    print()
    print("UNRESOLVED (handle not bound to a string literal): %d"
          % len(c["unresolved"]))


def snapshot(c):
    """Freeze the behavior of every literal-bound ability the hero files cast.

    Only those: the full set is ~1300 abilities and the ratchet only ever asks
    about the ones a cast order can reach without resolving a handle.
    """
    want = {}
    for hero, _p, _l, _v, name, _s in sites():
        if name is None:
            continue
        value = c["beh"].get(hero, {}).get(name)
        if value is not None:
            want.setdefault(hero, {})[name] = value
    rows = []
    for hero in sorted(want):
        inner = ",\n        ".join("['%s'] = '%s'" % (n, v)
                                   for n, v in sorted(want[hero].items()))
        rows.append("    ['%s'] = {\n        %s,\n    }," % (hero, inner))
    text = """-- GENERATED by tools/agent/cast_shape_census.py -- do not hand-edit.
--
-- The game's own `AbilityBehavior` for every ability that a hero file casts
-- through a STRING-LITERAL binding (`local h = bot:GetAbilityByName('name')`).
-- Handles bound through sAbilityList[N] or a talent list are absent by
-- construction -- resolving those is the open half of GH #151 / GH #162.
--
-- Used as a ratchet: tests/test_cast_shape_legality.lua fails when a new
-- literal-bound cast order appears whose shape these flags cannot accept, and
-- when an ability this repo relies on being PASSIVE stops being passive.
-- Regenerate after a patch:
--
--     python3 tools/agent/cast_shape_census.py --snapshot

local X = {}

-- hero (bots/BotLib/hero_<key>.lua) -> ability name -> AbilityBehavior string.
X.BEHAVIOR = {
%s
}

return X
""" % "\n".join(rows)
    open(os.path.join(REPO, OUT), "w", encoding="utf-8").write(text)
    print("wrote %s (%d heroes, %d abilities)"
          % (OUT, len(want), sum(len(v) for v in want.values())))


def main(argv):
    c = census()
    if "--snapshot" in argv:
        snapshot(c)
        return 0
    report(c)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
