#!/usr/bin/env python3
"""Census: what, in the game's own KV, could `Ability:GetAOERadius()` be served
from?

Why this exists (hero group, 2026-09-05, GH #502's last open cell)
------------------------------------------------------------------
`tests/mock/replay_fixture.lua` serves seven ability getters off the frozen KV
snapshot (`tests/mock/special_value_shapes.lua`).  Six of them are served by
NAME IDENTITY and nothing else:

    GetManaCost / GetCastRange / GetCastPoint / GetCooldown / GetAbilityDamage
                                     <- top-level "Ability<X>" field
    GetSpecialValueInt / GetSpecialValueFloat('k')
                                     <- the AbilityValues key literally named k

`GetAOERadius` is the eighth call the tree makes (7 call sites under `bots/`,
pinned by `tests/test_cm_ult_reach_meter_domain.lua` section 5) and it is NOT
served, so it answers 0 through the generic `^Get` default in
`tests/mock/bot_api.lua`.  GH #502 asked the one question that decides whether
that is a gap worth closing:

    is `AbilityValues/radius` the quantity the engine returns from
    GetAOERadius()?

The concrete case: `crystal_maiden_freezing_field`'s `radius` reads 810, while
`tests/test_replay_260819_cm_r_range.lua` anchors 835 off Liquipedia.  Whoever
closes that gap re-derives two end-to-end cases off whichever number wins, so
the mapping has to be established BEFORE the number is used -- otherwise a
number with no provenance replaces a number with one.

WHAT THIS SCRIPT MEASURES (three questions, in the order that settles them)
--------------------------------------------------------------------------
  (1) NAME IDENTITY.  Is there a top-level `Ability<X>` field whose name is an
      AoE radius -- the shape all five of the other top-level getters are
      served by?  Reported as the full set of distinct `Ability*` field names
      across every shipped hero's KV, so the answer is a census and not a grep
      for a name someone guessed.
  (2) THE FALLBACK RULE'S DOMAIN.  If (1) finds nothing, the only remaining
      rule is a hand-written one -- "the key named `radius`", or "the key
      flagged `affected_by_aoe_increase`".  Is that rule even a FUNCTION?  Per
      ability, count the candidate keys: 0 candidates means the rule serves
      nothing, >=2 means it does not identify one.
  (3) THE RULE ON THE ACTUAL CALL SITES.  Same count, restricted to the
      abilities the 7 shipped `GetAOERadius()` reads are actually taken on.
      Aggregate percentages do not decide this; the call sites do.

⚠️ WHY THE FROZEN SNAPSHOT CANNOT ANSWER (1), AND MUST NOT BE QUOTED FOR IT.
`tests/mock/special_value_shapes.lua` carries no `AbilityAOERadius` key, and
that is NOT evidence: `special_value_shape_census.parse_shapes` only records a
top-level field whose name is in `special_value_key_census.TOP_LEVEL`, a fixed
ten-name tuple.  A field absent from that tuple is dropped by the parser before
it can reach the snapshot, so its absence there is a property of the whitelist,
not of the KV.  Question (1) is therefore asked of the RAW KV TEXT, and
`tests/test_aoe_radius_source_census.py` pins the blindness so a later reader
cannot mistake the snapshot for the measurement.  (Same family as GH #494: a
count taken with no consumer-attribution defaults to reading as a finding.)

ONE-DIRECTIONAL DISCIPLINE (the house rule, same as the sibling censuses)
------------------------------------------------------------------------
This script does not resolve which ability a Lua handle points at from the Lua
alone -- it reads the slot map `tests/mock/hero_slots.lua` for that, and only
for the call sites it can resolve.  A call site whose handle cannot be resolved
is reported UNRESOLVED and nothing is claimed about it.

Usage:

    python3 tools/agent/aoe_radius_source_census.py              # full census
    python3 tools/agent/aoe_radius_source_census.py --sites      # call sites only
    python3 tools/agent/aoe_radius_source_census.py --self-test  # parser only, no network

Network: one HTTPS GET per shipped hero against the same public d2vpkr mirror
the sibling censuses already use.  No AWS, no cost.  Tests never go to the
network.

Exit codes: 0 = census ran, 2 = could not run (fetch failure).  This script
reports; it does not rule -- a finding here is an input to a ruling, and the
ruling for GH #502 is written in `tests/test_replay_260819_cm_r_range.lua`.
"""

import os
import re
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import lua_corpus as LUA_CORPUS                  # noqa: E402  (the one bots/ walk)
import special_value_key_census as KEYS          # noqa: E402  (fetch/BASE)
import special_value_shape_census as SHAPES      # noqa: E402  (parse_shapes)

REPO = KEYS.REPO
SLOT_MAP = "tests/mock/hero_slots.lua"

# The call this census is about.  Matched on ANY receiver, not on the
# `ability<X>` naming convention: `bots/FunLib/rubick_hero/crystal_maiden.lua`
# calls it on a handle named `FreezingField`, and a regex anchored to the
# convention finds 6 of the 7 pinned call sites while looking complete.
# `bots/FunLib/rubick_utility.lua` reads it off a stolen handle whose ability is
# not statically known -- that one is UNRESOLVED by construction, and saying so
# is the point of the discipline.
CALL_RE = re.compile(r"\b(\w+)\s*:\s*GetAOERadius\s*\(")
# `local abilityW = bot:GetAbilityByName( sAbilityList[2] )`
BIND_RE = re.compile(
    r"local\s+ability(\w*)\s*=\s*bot:GetAbilityByName\(\s*sAbilityList\[(\d+)\]")
# The rubick copies' binding form: a name-literal guard, then a bare assignment.
NAME_GUARD_RE = re.compile(r"abilityName\s*==\s*'([a-z0-9_]+)'")
NAME_BIND_RE = re.compile(r"^\s*(\w+)\s*=\s*ability\s*$")

# An AoE radius candidate key, under either of the two hand-written rules that
# remain once name identity has failed.
AOE_FLAG = "affected_by_aoe_increase"
NAMED = "radius"


def candidates_split(ability_keys):
    """(name_rule, flag_rule) candidate key lists for one ability.

    Reported SEPARATELY on purpose.  Merged, the two rules cover for each other
    and the union looks like a function on abilities where neither rule is:
    `drow_ranger_wave_of_silence` has no key named `radius` at all, and the one
    key the flag rule offers there is a WIDTH.  A single merged column would
    print that as one clean candidate.
    """
    named = [k for k in ability_keys if k == NAMED]
    flagged = [k for k, e in ability_keys.items()
               if any(b == AOE_FLAG for b, _ in e["bonus"])]
    return sorted(named), sorted(flagged)


def candidates(ability_keys):
    """The union -- what either rule would offer.  See candidates_split."""
    named, flagged = candidates_split(ability_keys)
    return sorted(set(named) | set(flagged))


def top_level_fields(text):
    """Every distinct top-level `Ability*` field name in one raw KV file."""
    return set(re.findall(r'"(Ability[A-Za-z0-9_]*)"', text))


def hero_slots():
    """{hero -> {slot_index -> ability name}} out of the frozen slot map."""
    path = os.path.join(REPO, SLOT_MAP)
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"\s*\['([a-z0-9_]+)'\]\s*=\s*\{(.*)\},\s*$", line)
            if not m:
                continue
            slots = {}
            for idx, name in re.findall(r"\[(\d+)\]\s*=\s*'([a-z0-9_]*)'", m.group(2)):
                slots[int(idx)] = name
            if slots:
                out[m.group(1)] = slots
    return out


def call_sites():
    """[(file, line, handle, ability|None)] for every GetAOERadius read in bots/.

    Two binding forms are resolved, because the tree uses two:

      * `local abilityW = bot:GetAbilityByName( sAbilityList[2] )` -- the hero
        scripts.  `sAbilityList[N]` is 1-based in Lua and the slot map is
        0-based, hence the -1.
      * `if abilityName == '<x>' then <Handle> = ability` -- the rubick copies,
        which bind by NAME LITERAL and never touch a slot.  This form carries
        its ability name outright, so no slot map is consulted for it.

    A handle matching neither resolves to None (UNRESOLVED), which is the honest
    answer for the stolen handle in `bots/FunLib/rubick_utility.lua`.
    """
    slots = hero_slots()
    out = []
    for path in LUA_CORPUS.bots_lua_files(REPO):
        rel = os.path.relpath(path, REPO)
        src = LUA_CORPUS.read_lua(path, errors="replace")
        if "GetAOERadius" not in src:
            continue
        body = SHAPES.strip_comments(src)
        slot_binds = {sfx: int(n) for sfx, n in BIND_RE.findall(body)}
        name_binds, pending = {}, None
        for line in body.splitlines():
            m = NAME_GUARD_RE.search(line)
            if m:
                pending = m.group(1)
            m = NAME_BIND_RE.search(line)
            if m and pending:
                name_binds[m.group(1)] = pending
        hero = None
        base = os.path.basename(rel)
        if base.startswith("hero_"):
            hero = base[len("hero_"):-len(".lua")]
        for n, line in enumerate(body.splitlines(), 1):
            for handle in CALL_RE.findall(line):
                ability = None
                sfx = handle[len("ability"):] if handle.startswith("ability") else None
                if hero and sfx is not None and sfx in slot_binds and hero in slots:
                    ability = slots[hero].get(slot_binds[sfx] - 1)
                elif handle in name_binds:
                    ability = name_binds[handle]
                out.append((rel, n, handle, ability))
    return out


def fetch_all(heroes):
    with ThreadPoolExecutor(12) as pool:
        return {h: t for h, t in pool.map(KEYS.fetch, heroes)}


def census(texts):
    """(field_names, {rule -> histogram}, per_ability) over every fetched hero."""
    fields, per_ability = Counter(), {}
    hist = {"name": Counter(), "flag": Counter(), "either": Counter()}
    for _hero, text in sorted(texts.items()):
        if not text:
            continue
        for name in top_level_fields(text):
            fields[name] += 1
        for ability, keys in SHAPES.parse_shapes(text).items():
            named, flagged = candidates_split(keys)
            per_ability[ability] = (named, flagged)
            hist["name"][min(len(named), 2)] += 1        # 0, 1, "2 or more"
            hist["flag"][min(len(flagged), 2)] += 1
            hist["either"][min(len(set(named) | set(flagged)), 2)] += 1
    return fields, hist, per_ability


def report(texts):
    fields, hist, per_ability = census(texts)
    aoeish = sorted(n for n in fields if "aoe" in n.lower() or "radius" in n.lower())

    print("=== (1) name identity: is there a top-level AoE-radius field? ===")
    print("hero KV files read      : %d" % sum(1 for t in texts.values() if t))
    print("distinct Ability* fields: %d" % len(fields))
    print("...matching aoe|radius  : %d %s" % (len(aoeish), aoeish))
    if aoeish:
        print("NAME IDENTITY AVAILABLE -- serve GetAOERadius off %s" % aoeish[0])
    else:
        print("NAME IDENTITY UNAVAILABLE -- no KV field of that shape exists, so")
        print("the five top-level getters' rule cannot be extended to this one.")

    print()
    print("=== (2) the fallback rules' domain, EACH RULE ON ITS OWN ===")
    print("    name rule = the key literally named `%s`" % NAMED)
    print("    flag rule = every key carrying `%s`" % AOE_FLAG)
    total = sum(hist["either"].values())
    print("abilities parsed        : %d" % total)
    print("  %-30s %14s %14s %14s" % ("", "name rule", "flag rule", "either"))
    for k, label in ((0, "0 candidates (serves nothing)"),
                     (1, "1 candidate  (looks like fn)"),
                     (2, ">=2 (does NOT identify one)")):
        print("  %-30s %6d %6.1f%% %6d %6.1f%% %6d %6.1f%%" % (
            label,
            hist["name"].get(k, 0), 100.0 * hist["name"].get(k, 0) / max(1, total),
            hist["flag"].get(k, 0), 100.0 * hist["flag"].get(k, 0) / max(1, total),
            hist["either"].get(k, 0), 100.0 * hist["either"].get(k, 0) / max(1, total)))

    print()
    print("=== (3) the rules on the 7 shipped call sites ===")
    verdicts = Counter()
    for rel, line, handle, ability in call_sites():
        if ability is None:
            print("  UNRESOLVED  %s:%d  %s (handle not statically known)"
                  % (rel, line, handle))
            verdicts["unresolved"] += 1
            continue
        cand = per_ability.get(ability)
        if cand is None:
            print("  NO-KV       %s:%d  %s -> %s" % (rel, line, handle, ability))
            verdicts["unresolved"] += 1
            continue
        named, flagged = cand
        # A call site is SERVED only if a rule identifies exactly one key on
        # its own.  Where the two rules disagree the site is reported SPLIT --
        # the union would hide the disagreement behind one number.
        if len(named) == 1 and len(flagged) == 1 and named == flagged:
            verdict = "SERVED"
        elif len(named) == 1 and len(flagged) != 1:
            verdict = "SPLIT"
        elif not named and len(flagged) == 1:
            verdict = "FLAG-ONLY"
        elif not named and not flagged:
            verdict = "EMPTY"
        else:
            verdict = "AMBIGUOUS"
        verdicts[verdict.lower()] += 1
        print("  %-10s  %s:%d  %s -> %s  name=%s flag=%s"
              % (verdict, rel, line, handle, ability, named or "-", flagged or "-"))
    print("  " + " ".join("%s=%d" % kv for kv in sorted(verdicts.items())))
    return 0


# --------------------------------------------------------------------------
# --self-test: the shapes this script's own two parsers must survive.  No
# network.  A parser gap here reads as a clean census, which is the failure
# mode the sibling censuses were bitten by (GH #177).

SELF_TEST_KV = '''
"DOTAAbilities"
{
    "cm_ult"
    {
        "AbilityCooldown"   "100 95 90"
        "AbilityValues"
        {
            "radius"
            {
                "value"                         "810"
                "affected_by_aoe_increase"      "1"
            }
            "explosion_radius"
            {
                "value"                         "320"
                "affected_by_aoe_increase"      "1"
            }
            "slow_duration"     "1.0"
        }
    }
    "single_candidate"
    {
        "AbilityValues"
        {
            "radius"            "500"
        }
    }
    "flag_only"
    {
        "AbilityValues"
        {
            "wave_width"
            {
                "value"                         "225"
                "affected_by_aoe_increase"      "1"
            }
        }
    }
    "no_candidate"
    {
        "AbilityValues"
        {
            "duration"          "3"
        }
    }
}
'''


def self_test():
    shapes = SHAPES.parse_shapes(SELF_TEST_KV)
    got = {a: candidates(k) for a, k in shapes.items()}
    want = {
        # Both rules fire and disagree -- the case GH #502 is about.
        "cm_ult": ["explosion_radius", "radius"],
        # The name rule alone, which is what makes the rule LOOK like a function.
        "single_candidate": ["radius"],
        # The flag rule alone: a real AoE ability with no key named `radius`.
        "flag_only": ["wave_width"],
        "no_candidate": [],
    }
    for ability, expect in sorted(want.items()):
        assert got.get(ability) == expect, (
            "candidates(%s): expected %s, got %s" % (ability, expect, got.get(ability)))

    # Name identity must be asked of the RAW text: `radius` under AbilityValues
    # is not a top-level field and must not be counted as one.
    fields = top_level_fields(SELF_TEST_KV)
    assert fields == {"AbilityCooldown", "AbilityValues"}, fields
    assert not [n for n in fields if "aoe" in n.lower() or "radius" in n.lower()]

    # The slot map must parse, or question (3) silently degrades to UNRESOLVED
    # everywhere -- which reads exactly like "nothing to see here".
    slots = hero_slots()
    assert slots.get("crystal_maiden", {}).get(5) == "crystal_maiden_freezing_field", \
        "slot map parse broke: CM's ultimate is slot 5"
    assert slots.get("drow_ranger", {}).get(1) == "drow_ranger_wave_of_silence", \
        "slot map parse broke: drow's W is wave_of_silence"

    sites = call_sites()
    assert len(sites) >= 7, "expected the 7 pinned call sites, found %d" % len(sites)
    resolved = {a for _, _, _, a in sites if a}
    for want_ability in ("crystal_maiden_freezing_field", "drow_ranger_wave_of_silence",
                         "muerta_the_calling", "sniper_shrapnel"):
        assert want_ability in resolved, "call-site resolution lost " + want_ability
    print("SELFTEST ok (%d call sites, %d resolved)" % (len(sites), len(resolved)))
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    heroes = KEYS.hero_names()
    texts = fetch_all(heroes)
    if not any(texts.values()):
        print("CENSUS could not run: no hero KV fetched")
        return 2
    if "--sites" in argv:
        _f, _h, per_ability = census(texts)
        for rel, line, handle, ability in call_sites():
            print("%s:%d %s -> %s %s"
                  % (rel, line, handle, ability, per_ability.get(ability)))
        return 0
    return report(texts)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
