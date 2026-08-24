#!/usr/bin/env python3
"""Census: `GetSpecialValue*('key')` reads whose key is not in the game's KV.

Why this exists (hero group, 2026-08-24)
----------------------------------------
`ability:GetSpecialValueInt('foo')` returns **0** when `foo` is not a key in
that ability's `AbilityValues` block.  There is no error, no warning, and no
way to see it from inside a game: `print()` never reaches the server console
and the engine's error handler is broken (AGENTS.md).  So a key that Valve
renamed in some past patch degrades silently into a zero -- and a zero fed to
a radius, a count or a threshold usually means "this branch is now dead".

The bearing case that motivated the script: `hero_lion.lua:973` reads
`splash_radius_scepter` off `lion_finger_of_death`.  Today's KV calls that key
`splash_radius`.  The read is 0, so the two branches downstream of it
(`R团战Aoe` and the scepter split-push) can never fire.

WHAT IT DOES AND DOES NOT PROVE
-------------------------------
The check is deliberately ONE-DIRECTIONAL, for the same reason the boots
supply census is (hero charter, 2026-08-24):

  * a key that appears in NONE of the owning hero's abilities is a PROOF that
    the read is a zero -- whichever handle it was taken on;
  * a key that DOES appear proves nothing at all, because this script does not
    resolve which ability the Lua handle points at.  `radius` exists on
    somebody's ability in nearly every hero file.

So findings are real; silence is not a clean bill of health.

KEYS THAT ARE NOT ABILITY VALUES
--------------------------------
Two families are legitimate and would otherwise be false positives:

  * `value` -- the shape `talentN:GetSpecialValueInt('value')`.  Talents are
    `special_bonus_*` abilities living in npc_abilities.txt, not in the hero
    KV, and every one of them carries a `value`.
  * the `Ability*` names (`AbilityCastRange`, `AbilityCooldown`,
    `AbilityManaCost`, ...) -- these are readable through the same call and are
    top-level KV keys, so they are collected as well as the AbilityValues ones.

Files outside `bots/BotLib/hero_*.lua` (FunLib, modes, item usage) reference
abilities of arbitrary heroes, so their keys are checked against the union over
every hero we ship -- weaker still, and reported separately.

Usage:

    python3 tools/agent/special_value_key_census.py            # census
    python3 tools/agent/special_value_key_census.py --dump-keys lion
    python3 tools/agent/special_value_key_census.py --snapshot  # focus-five table

Network: one HTTPS GET per hero against the same public d2vpkr mirror
`gen_ability_meta.py` already uses (no AWS, no cost).
"""

import glob
import json
import os
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
        "dota/scripts/npc/heroes/npc_dota_hero_%s.txt")
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Read through the same call, but they are top-level KV keys, not AbilityValues.
TOP_LEVEL = ("AbilityCastRange", "AbilityCastPoint", "AbilityCooldown",
             "AbilityManaCost", "AbilityDamage", "AbilityChannelTime",
             "AbilityDuration", "AbilityCharges", "AbilityChargeRestoreTime",
             "AbilityModifierSupportValue")

# talentN:GetSpecialValueInt('value') -- talents live in npc_abilities.txt.
TALENT_KEYS = frozenset(("value",))

CALL_RE = re.compile(r"GetSpecialValue(?:Int|Float)?\s*\(\s*['\"]([A-Za-z0-9_]+)['\"]")


def strip_comments(src):
    """Drop Lua line comments BEFORE keys are picked out.

    A parser that reads prose reports the prose: the reasoning blocks in these
    files quote key names while explaining them (hero charter, GH #136).
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
    except Exception as exc:                                  # noqa: BLE001
        return hero, None if "404" in str(exc) else _raise(exc)


def _raise(exc):
    raise exc


def kv_keys(text):
    """Every key name a GetSpecialValue call could legitimately resolve.

    Walks the KV block structure and collects, for the hero's ability blocks:
    the top-level `Ability*` names present, and every immediate child name of
    an `AbilityValues` block (both the `"k" "v"` shorthand and the
    `"k" { "value" "v" }` long form).
    """
    keys, stack, pend = set(), [], None
    for raw in text.splitlines():
        line = raw.split("//")[0].strip()
        if not line:
            continue
        pair = re.match(r'^"([^"]+)"\s+"([^"]*)"$', line)
        if pair:
            name = pair.group(1)
            if len(stack) >= 2 and stack[-1] == "AbilityValues":
                keys.add(name)                      # "k" "v" shorthand
            elif name in TOP_LEVEL:
                keys.add(name)
            continue
        lone = re.match(r'^"([^"]+)"$', line)
        if lone:
            pend = lone.group(1)
            continue
        if line.startswith("{"):
            if pend is not None and stack and stack[-1] == "AbilityValues":
                keys.add(pend)                      # "k" { "value" "v" } form
            stack.append(pend if pend is not None else "?")
            pend = None
            continue
        if line.startswith("}") and stack:
            stack.pop()
    return keys


def reads_in(path):
    """{ key -> [line numbers] } for one Lua file, comments stripped."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    stripped = strip_comments(src)
    out = {}
    for n, line in enumerate(stripped.splitlines(), 1):
        for key in CALL_RE.findall(line):
            out.setdefault(key, []).append(n)
    return out


SNAPSHOT = "tests/mock/special_value_keys.lua"

# The hero group's five polish targets (AGENTS.md).  Only these are snapshotted:
# the standing assertion is about the files this stream owns, and a table of all
# 127 heroes would be a large generated file nobody reads.
FOCUS_FIVE = ("axe", "zuus", "skeleton_king", "lion", "crystal_maiden")


def write_snapshot(per_hero):
    """Freeze the focus five's legal key sets into a Lua table for the tests."""
    lines = [
        "-- GENERATED by tools/agent/special_value_key_census.py "
        "--snapshot -- do not hand-edit.",
        "--",
        "-- Every key name a GetSpecialValue* call can legally resolve on one of",
        "-- the five focus heroes' abilities, read out of the game's own KV",
        "-- (npc_dota_hero_<name>.txt on the d2vpkr mirror, the same source",
        "-- gen_ability_meta.py uses).  A key NOT in this set answers 0 in game,",
        "-- silently.  tests/test_lion_r_splash_radius_key.lua asserts that no",
        "-- read in the five hero files falls outside it.",
        "--",
        "-- Regenerate after a patch:",
        "--   python3 tools/agent/special_value_key_census.py --snapshot",
        "",
        "local X = {}",
        "",
        "-- hero unit short name -> set of legal AbilityValues / Ability* keys.",
        "X.KEYS = {",
    ]
    for hero in FOCUS_FIVE:
        keys = sorted(per_hero.get(hero, ()))
        lines.append("    ['%s'] = {" % hero)
        row = "       "
        for key in keys:
            piece = " ['%s'] = true," % key
            if len(row) + len(piece) > 96:
                lines.append(row)
                row = "       "
            row += piece
        if row.strip():
            lines.append(row)
        lines.append("    },")
    lines += ["}", "", "return X", ""]
    with open(os.path.join(REPO, SNAPSHOT), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def main(argv):
    heroes = hero_names()
    with ThreadPoolExecutor(max_workers=8) as pool:
        fetched = dict(pool.map(fetch, heroes))

    per_hero = {h: kv_keys(t) for h, t in fetched.items() if t}
    missing_kv = sorted(h for h, t in fetched.items() if not t)
    union = set()
    for keys in per_hero.values():
        union |= keys

    if len(argv) > 2 and argv[1] == "--dump-keys":
        print("\n".join(sorted(per_hero.get(argv[2], ()))))
        return 0

    if "--snapshot" in argv:
        write_snapshot(per_hero)
        print("wrote " + SNAPSHOT)
        return 0

    findings, checked, skipped = [], 0, []
    for hero in heroes:
        path = os.path.join(REPO, "bots/BotLib/hero_%s.lua" % hero)
        if hero not in per_hero:
            skipped.append(hero)
            continue
        for key, lines in sorted(reads_in(path).items()):
            if key in TALENT_KEYS:
                continue
            checked += 1
            if key not in per_hero[hero]:
                findings.append(("hero_%s.lua" % hero, key, lines, hero))

    generic = []
    for path in sorted(glob.glob(os.path.join(REPO, "bots/**/*.lua"), recursive=True)):
        rel = os.path.relpath(path, REPO)
        if re.match(r"bots/BotLib/hero_[a-z_]+\.lua$", rel):
            continue
        for key, lines in sorted(reads_in(path).items()):
            if key in TALENT_KEYS:
                continue
            checked += 1
            if key not in union:
                generic.append((rel, key, lines, "<any hero>"))

    print("SPECIALVALUE heroes=%d kv_fetched=%d kv_absent=%d reads_checked=%d"
          % (len(heroes), len(per_hero), len(missing_kv), checked))
    if missing_kv:
        print("  no KV upstream (not checked): " + " ".join(missing_kv))
    print()
    print("== keys absent from the owning hero's whole KV (PROOF the read is 0) ==")
    for rel, key, lines, owner in findings:
        print("  %-42s %-28s lines %s" % (rel, key, ",".join(map(str, lines))))
    if not findings:
        print("  (none)")
    print()
    print("== generic files: key absent from EVERY hero's KV ==")
    for rel, key, lines, _ in generic:
        print("  %-42s %-28s lines %s" % (rel, key, ",".join(map(str, lines))))
    if not generic:
        print("  (none)")

    if "--json" in argv:
        print(json.dumps({"findings": findings, "generic": generic}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
