#!/usr/bin/env python3
"""Census: `<abilityHandle>:GetSpecialValue*('value')` -- the sister shape GH
#228 measured on TALENT handles, taken here on ORDINARY ABILITY handles.

Why this exists (hero group, 2026-08-26, axis `ABILVALUE`, follow-on to #228 §6.3)
----------------------------------------------------------------------------------
GH #228 counted 21 sites that read the key `'value'` off a TALENT handle and
proved every one of them a silent 0, because a hero-unique talent owns no KV
block at all.  Its §6 registered a deliberately excluded sister shape and said
so in as many words: seven abilities in this tree are read the same way -- not
`talent:GetSpecialValueInt('value')` but `Avalanche:GetSpecialValueInt('value')`
-- and *not one of them had ever been counted*.

This script is that count.  The question is decidable offline and it is a
different question from #228's:

    An ability's special values are keyed by the ENTRY NAME inside its
    `AbilityValues` block.  A modern entry is written long-form --

        "avalanche_damage"
        {
            "value"                     "90 180 270 360"
            "special_bonus_unique_tiny" "+90"
        }

    -- and `value` there is an INNER key of the entry `avalanche_damage`, not an
    entry of the ability.  So `GetSpecialValueInt('value')` on that ability asks
    for an entry that does not exist and gets the documented silent 0
    (BOT_API_REFERENCE: "a typo will silently return 0").  An ability answers
    `value` only if it literally owns an AbilityValues entry NAMED `value`.

⭐ THE HEADLINE, AND IT IS THE OPPOSITE SIGN FROM #228
-----------------------------------------------------
#228's finding reduced to "harmless": a unique talent's bonus has no second
home, so the engine must fold it into the base number the site already read,
and the dead `+ talent:...('value')` term is dead in the SAFE direction --
repairing it would double-count.

Nothing folds here.  These sites are not adding a bonus to a number they
already have; the read IS the number, and the number is 0.  Five of the eight
sites feed a `J.CanKillTarget(...)` with a damage of 0 -- a kill branch that can
never fire, so the ability is never chosen as a finisher.  One feeds a health
cost with 0 -- a cast the hero believes is free, in the direction that spends
health.  Only two are talent-bonus terms of #228's harmless kind.

⭐ AND THE OBVIOUS REPAIR IS WRONG AT ONE SITE IN A SECOND WAY.  The key this
tree wants at `hero_terrorblade.lua` is `health_cost_pct`, whose KV value is
`20` -- twenty PERCENT, not a fraction.  The site multiplies by current health
directly (`bot:GetHealth() * <read>`), so swapping the key alone turns a cost of
0 into a cost of 20x the hero's health, and the guard it feeds
(`(hp - cost)/maxhp > 0.5`) flips from always-true to never-true.  The repair is
two edits, not one, and this file says so where the claimant will read it.

WHAT IT COSTS
    One HTTPS GET of `npc_heroes.txt` (to learn which hero owns each ability)
    plus one per hero that actually has a site -- six today.  No AWS, no
    per-hero fan-out over the roster.

    python3 tools/agent/ability_value_key_census.py             # census
    python3 tools/agent/ability_value_key_census.py --snapshot  # regen the mock
    python3 tools/agent/ability_value_key_census.py --self-test # parser pins

Exit codes follow the house convention: 0 clean / 2 could-not-run / 3 findings.

WHAT IT PROVES, AND WHAT IT DOES NOT
------------------------------------
  * entry named `value` ABSENT from the ability's AbilityValues  =>  PROOF the
    read is 0.  There is nowhere else `GetSpecialValue*` looks.
  * entry named `value` PRESENT  =>  proves the read answers a number, and
    nothing about whether it is the RIGHT number.
  * It says nothing about whether the containing branch matters in play.  The
    `sign` column is this script's reading of the arithmetic downstream of the
    read, recorded per site as prose, and it is a lead for a claimant -- not a
    measured frequency.  Nobody has counted how often these branches are
    reached; that needs a corpus, and these are not focus-five heroes.

PARSER FIDELITY IS PART OF THE CLAIM
------------------------------------
The whole finding is "this entry name is not in that block", so a parser that
loses entries manufactures findings and a parser that invents them hides one.
`--self-test` pins both directions on fixture text: the short form
(`"tick_interval" "0.3"`), the long form, an entry literally named `value`
(the negative case that must come back ANSWERS), the nested `special_bonus_*`
sub-keys that must NOT be read as entries, and an ability whose AbilityValues
block is absent entirely.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import hero_slot_map as S  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if not os.path.isdir(os.path.join(REPO, "bots")):
    REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SNAPSHOT = "tests/mock/ability_value_reads.lua"

HERO_KV = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
           "dota/scripts/npc/heroes/npc_dota_hero_%s.txt")

# `local Avalanche = bot:GetAbilityByName("tiny_avalanche")`, and the same
# without `local`.  Talent bindings (`special_bonus_*`) are matched too and then
# split out: they are GH #228's axis, and counting them here would double-book
# the finding.
BIND = re.compile(
    r"""(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"""
    r"""[A-Za-z_][A-Za-z0-9_]*\s*:\s*GetAbilityByName\s*\(\s*"""
    r"""['"]([a-z0-9_]+)['"]\s*\)""")

READ = re.compile(
    r"""\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*GetSpecialValue[A-Za-z]*\s*\(\s*"""
    r"""['"]value['"]\s*\)""")

TALENT = "special_bonus"

# Prose the census cannot derive: what the surrounding arithmetic does with a 0,
# and the entry the site plainly wanted (read off the KV once, pinned so a
# claimant does not re-derive it).  `intended = None` means there is no right key
# here -- the talent-bonus terms, whose repair is DELETION, not a new key.
#
# Keyed by (file, var, nth-read-of-that-var-in-the-file) -- NOT by line number
# (GH #221: a key carrying a line turns every edit above a site into a red
# ratchet).  The ordinal is load-bearing and is why the key is not just
# (file, var): hero_enigma.lua reads `Malefice` twice, and the two reads have
# OPPOSITE dispositions -- the first is the missing base, the second is a talent
# term the engine already folded.  A key that could not tell them apart would
# have to call both of them one thing, and either choice is a wrong instruction
# to whoever repairs it.
SIGN = {
    ("bots/BotLib/hero_tiny.lua", "Avalanche", 1):
        ("UNDER", "damage 0 -> the CanKillTarget finisher branch cannot fire",
         "avalanche_damage"),
    ("bots/BotLib/hero_enigma.lua", "Malefice", 1):
        ("UNDER", "stun instances 0 -> damage = per-instance * 0 = 0",
         "stun_instances"),
    ("bots/BotLib/hero_enigma.lua", "Malefice", 2):
        ("FOLD", "talent term: stun_instances already folds "
                 "special_bonus_unique_enigma_2 (+4); repairing it double-counts",
         None),
    ("bots/BotLib/hero_enigma.lua", "MidnightPulse", 1):
        ("FOLD", "talent term: radius already folds special_bonus_unique_enigma_9 "
                 "(+200) -- and the handle it is gated on names enigma_6, which "
                 "modifies enigma_black_hole/damage (GH #223 §6.3)",
         None),
    ("bots/BotLib/hero_enigma.lua", "BlackHole", 1):
        ("UNDER", "damage 0 -> the CanKillTarget branch cannot fire", "damage"),
    ("bots/BotLib/hero_gyrocopter.lua", "RocketBarrage", 1):
        ("UNDER", "damage 0 -> CanKillTarget(0 * rockets * duration) cannot fire",
         "rocket_damage"),
    ("bots/BotLib/hero_enchantress.lua", "Impetus", 1):
        ("UNDER", "distance multiplier 0 -> CanKillTarget(0 * distance) cannot fire",
         "distance_damage_pct"),
    ("bots/BotLib/hero_terrorblade.lua", "DemonZeal", 1):
        ("OVER", "health cost read as free -> the post-cast HP guard never binds; "
                 "health_cost_pct is 20 = PERCENT, so the key swap alone flips the "
                 "guard from always-true to never-true",
         "health_cost_pct"),
}


def strip_comments(text):
    """Blank out Lua comments, keeping the line count and column positions.

    Same shape as talent_name_binding_census.strip_comments and for the same
    reason: this tree carries commented-out copies of live idioms (the nine
    `aetherRange` lines GH #228 had to peel off), so a scan that reads prose
    reports call sites that cannot run.
    """
    out, in_block = [], False
    for line in text.splitlines():
        if in_block:
            end = line.find("]]")
            if end < 0:
                out.append("")
                continue
            line = " " * (end + 2) + line[end + 2:]
            in_block = False
        start = line.find("--[[")
        if start >= 0:
            end = line.find("]]", start)
            if end < 0:
                out.append(line[:start])
                in_block = True
                continue
            line = line[:start] + " " * (end + 2 - start) + line[end + 2:]
        cut = line.find("--")
        if cut >= 0:
            line = line[:cut]
        out.append(line)
    return out


def ability_value_keys(text):
    """{ ability name -> [AbilityValues entry names, in file order] }.

    Walks the KV block structure rather than matching a block body, because the
    body-match shape is exactly what cost this group a measurement before: the
    lazy `\\{(.*?)\\}` capture in the charter's §26 swallowed a closing brace and
    reported "Axe never has his ultimate on cooldown".

    An ENTRY is a key at depth 3 (root / ability / AbilityValues / entry),
    written either short (`"tick_interval" "0.3"`) or long (`"radius" { ... }`).
    Keys INSIDE a long entry sit at depth 4 and are deliberately not entries:
    `value` and `special_bonus_*` both live there, and reading them as entries
    would report every long-form ability as owning a `value` -- which would turn
    this census's finding into its exact negation.
    """
    out, stack, pend = {}, [], None
    for raw in text.splitlines():
        line = raw.split("//")[0].strip()
        if not line:
            continue
        pair = re.match(r'^"([^"]+)"\s+"([^"]*)"\s*$', line)
        if pair:
            if len(stack) == 3 and stack[2] == "AbilityValues":
                out.setdefault(stack[1], []).append(pair.group(1))
            continue
        lone = re.match(r'^"([^"]+)"\s*$', line)
        if lone:
            pend = lone.group(1)
            continue
        if line.startswith("{"):
            if len(stack) == 3 and stack[2] == "AbilityValues" and pend is not None:
                out.setdefault(stack[1], []).append(pend)
            stack.append(pend if pend is not None else "?")
            pend = None
            continue
        if line.startswith("}") and stack:
            stack.pop()
    return out


def hero_files(root=None):
    root = os.path.join(root or REPO, "bots")
    for base, _, names in os.walk(root):
        for name in sorted(names):
            if name.endswith(".lua"):
                yield os.path.join(base, name)


def scan_file(path, lines=None):
    """[(var, ability, read_line), ...] for reads of `'value'` on an ABILITY.

    A variable bound twice to different abilities in one file is reported with
    ability `None` (UNRESOLVED) instead of being resolved to the last binding
    seen: guessing here would put a verdict on the wrong ability, and this axis
    has no site of that shape today.
    """
    if lines is None:
        with open(path, "r", encoding="utf-8") as fh:
            lines = strip_comments(fh.read())
    bind = {}
    for line in lines:
        for m in BIND.finditer(line):
            var, abil = m.group(1), m.group(2)
            if var in bind and bind[var] != abil:
                bind[var] = None
            else:
                bind.setdefault(var, abil)
    out = []
    for n, line in enumerate(lines):
        for m in READ.finditer(line):
            var = m.group(1)
            if var not in bind:
                continue                      # sTalentList[N] etc -- GH #228
            abil = bind[var]
            if abil is not None and abil.startswith(TALENT):
                continue                      # talent handle -- GH #228's axis
            out.append((var, abil, n + 1))
    return out


def numbered(sites):
    """[(var, ability, line)] -> [(var, ability, line, nth)], nth per variable.

    The ordinal is the last component of a site's identity (see SIGN): it is
    what distinguishes two reads of the same handle in one file, which is the
    only thing that differs between hero_enigma.lua's two `Malefice` reads --
    and their dispositions are opposite.
    """
    seen, out = {}, []
    for var, abil, line in sites:
        seen[var] = seen.get(var, 0) + 1
        out.append((var, abil, line, seen[var]))
    return out


def owners(slots):
    """{ ability name -> hero short name } from the npc_heroes.txt slot map."""
    out = {}
    for hero, by_slot in slots.items():
        for name in by_slot.values():
            out.setdefault(name, hero)
    return out


def census(root=None, slots=None, kv=None):
    """[ {file, var, ability, line, hero, keys, answers, sign, why, intended} ]

    `kv` is { hero -> AbilityValues-key map }; when omitted the hero KV files of
    exactly the heroes that have a site are fetched.
    """
    if slots is None:
        slots = S.parse(S.fetch())
    owner = owners(slots)
    rows = []
    for path in sorted(hero_files(root)):
        rel = os.path.relpath(path, root or REPO).replace("\\", "/")
        for var, abil, line, nth in numbered(scan_file(path)):
            rows.append({"file": rel, "var": var, "ability": abil, "line": line,
                         "nth": nth, "hero": owner.get(abil)})
    if kv is None:
        kv = {}
        for hero in sorted({r["hero"] for r in rows if r["hero"]}):
            kv[hero] = ability_value_keys(S.fetch(HERO_KV % hero))
    for r in rows:
        keys = kv.get(r["hero"], {}).get(r["ability"])
        r["keys"] = keys
        if r["ability"] is None:
            r["verdict"] = "UNRESOLVED"
        elif keys is None:
            r["verdict"] = "NO-KV"
        elif "value" in keys:
            r["verdict"] = "ANSWERS"
        else:
            r["verdict"] = "READS-ZERO"
        sign, why, want = SIGN.get((r["file"], r["var"], r["nth"]),
                                   ("UNCLASSIFIED", "", ""))
        r["sign"], r["why"], r["intended"] = sign, why, want or ""
    return rows


def findings(rows):
    return [r for r in rows if r["verdict"] in ("READS-ZERO", "NO-KV", "UNRESOLVED")]


def report(rows):
    print("=== `<ability>:GetSpecialValue*('value')` census (axis ABILVALUE) ===")
    print("%-38s %-16s %-11s %-6s %s"
          % ("file:line", "var", "verdict", "sign", "ability / intended key"))
    for r in sorted(rows, key=lambda r: (r["file"], r["line"])):
        where = "%s:%d" % (os.path.basename(r["file"]), r["line"])
        tail = r["ability"] or "?"
        if r["intended"]:
            tail += "  -> " + r["intended"]
        elif r["verdict"] == "READS-ZERO" and r["sign"] == "FOLD":
            tail += "  -> (delete: the base read already folds it)"
        print("%-38s %-16s %-11s %-6s %s"
              % (where, r["var"], r["verdict"], r["sign"], tail))
        if r["why"]:
            print("%-38s   %s" % ("", r["why"]))
    bad = findings(rows)
    signs = {}
    for r in bad:
        signs[r["sign"]] = signs.get(r["sign"], 0) + 1
    print()
    print("%d site(s), %d distinct abilit(ies), %d finding(s): %s"
          % (len(rows), len({r["ability"] for r in rows}), len(bad),
             ", ".join("%s %d" % kv for kv in sorted(signs.items())) or "none"))
    return bad


def lua_quote(s):
    return "'" + str(s).replace("\\", "\\\\").replace("'", "\\'") + "'"


def snapshot_header():
    return [
        "--- GENERATED by tools/agent/ability_value_key_census.py"
        " -- do not hand-edit.",
        "---",
        "--- Every live `<abilityHandle>:GetSpecialValue*('value')` call site in",
        "--- bots/, with the ability its variable is bound to and whether that",
        "--- ability owns an AbilityValues entry NAMED `value`.",
        "---",
        "--- READS-ZERO  the ability has no entry named `value`; the read is a",
        "---             silent 0.  Unlike GH #228's talent sites there is no",
        "---             fold to make this harmless -- the read IS the number.",
        "--- ANSWERS     the ability really owns an entry named `value`.",
        "---",
        "--- `sign` is what the surrounding arithmetic does with the 0, recorded",
        "--- by hand in the census and NOT derived: UNDER = a kill/threshold",
        "--- branch that can never fire, OVER = a cost read as free, FOLD = the",
        "--- talent-bonus term of #228's harmless kind (repair is deletion).",
        "---",
        "--- This is a CONSISTENCY ratchet, not a correctness one: it goes red",
        "--- when the shipped call sites and this table stop agreeing.",
        "--- Correctness is owned by the source -- rerun the census.",
        "",
    ]


def write_snapshot(rows, root=None):
    path = os.path.join(root or REPO, SNAPSHOT)
    lines = snapshot_header()
    signs = {}
    for r in rows:
        signs[r["sign"]] = signs.get(r["sign"], 0) + 1
    lines.append("return {")
    lines.append("    totals = { sites = %d, abilities = %d, reads_zero = %d },"
                 % (len(rows), len({r["ability"] for r in rows}),
                    len([r for r in rows if r["verdict"] == "READS-ZERO"])))
    lines.append("    signs = { %s },"
                 % ", ".join("%s = %d" % (k.lower(), v)
                             for k, v in sorted(signs.items())))
    lines.append("    sites = {")
    for r in sorted(rows, key=lambda r: (r["file"], r["line"])):
        lines.append(
            "        { file = %s, line = %d, var = %s, nth = %d, ability = %s, "
            "hero = %s, verdict = %s, sign = %s, intended = %s },"
            % (lua_quote(r["file"]), r["line"], lua_quote(r["var"]), r["nth"],
               lua_quote(r["ability"]), lua_quote(r["hero"]),
               lua_quote(r["verdict"]), lua_quote(r["sign"]),
               lua_quote(r["intended"] or "")))
    lines.append("    },")
    lines.append("}")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return path


FIXTURE = '''"DOTAAbilities"
{
	"fix_short_and_long"
	{
		"AbilityValues"
		{
			"tick_interval"		"0.3"
			"radius"
			{
				"value"					"325 340"
				"special_bonus_unique_x"	"+85"
			}
		}
	}
	"fix_owns_value"
	{
		"AbilityValues"
		{
			"value"		"200"
		}
	}
	"fix_no_ability_values"
	{
		"AbilityCastRange"	"600"
	}
}
'''


def self_test():
    keys = ability_value_keys(FIXTURE)
    checks = [
        ("short and long entries are both entries",
         keys.get("fix_short_and_long") == ["tick_interval", "radius"]),
        ("the inner `value` of a long entry is NOT an entry",
         "value" not in keys.get("fix_short_and_long", [])),
        ("the inner `special_bonus_*` of a long entry is NOT an entry",
         "special_bonus_unique_x" not in keys.get("fix_short_and_long", [])),
        ("an ability that really owns `value` reports it",
         keys.get("fix_owns_value") == ["value"]),
        ("an ability with no AbilityValues block is absent, not empty",
         "fix_no_ability_values" not in keys),
    ]
    lines = ["local Foo = bot:GetAbilityByName('hero_foo')",
             "local T = bot:GetAbilityByName('special_bonus_unique_x')",
             "local n = Foo:GetSpecialValueInt('value')",
             "local m = T:GetSpecialValueInt('value')",
             "local k = Bar:GetSpecialValueInt('value')",
             "local j = Foo:GetSpecialValueFloat('radius')"]
    sites = scan_file("<fixture>", lines)
    checks += [
        ("an ability-handle read of 'value' is a site",
         sites == [("Foo", "hero_foo", 3)]),
        ("a talent-handle read is GH #228's axis, not this one",
         all(v != "T" for v, _, _ in sites)),
        ("an unbound variable is not a site",
         all(v != "Bar" for v, _, _ in sites)),
        ("a read of some other key is not a site",
         all(ln != 6 for _, _, ln in sites)),
    ]
    dup = scan_file("<fixture>",
                    ["local Foo = bot:GetAbilityByName('hero_foo')",
                     "local Foo = bot:GetAbilityByName('hero_bar')",
                     "local n = Foo:GetSpecialValueInt('value')"])
    checks.append(("a variable bound to two abilities is UNRESOLVED, not guessed",
                   dup == [("Foo", None, 3)]))
    # The ordinal is what lets two reads of ONE variable carry opposite
    # dispositions (hero_enigma.lua's Malefice).  Pinned here because a census
    # that numbered every read 1 would silently hand both rows the first row's
    # instruction -- green, and wrong in the half that matters.
    checks.append(("repeated reads of one variable are numbered 1, 2, ...",
                   numbered([("Foo", "a", 3), ("Bar", "b", 4), ("Foo", "a", 9)])
                   == [("Foo", "a", 3, 1), ("Bar", "b", 4, 1),
                       ("Foo", "a", 9, 2)]))
    checks.append(("a commented-out read is not a site",
                   scan_file("<fixture>", strip_comments(
                       "local Foo = bot:GetAbilityByName('hero_foo')\n"
                       "-- local n = Foo:GetSpecialValueInt('value')\n")) == []))
    bad = 0
    for name, ok in checks:
        print("%-4s %s" % ("ok" if ok else "FAIL", name))
        bad += 0 if ok else 1
    return 0 if bad == 0 else 3


def main(argv):
    if "--self-test" in argv:
        return self_test()
    try:
        rows = census()
    except Exception as exc:                                      # noqa: BLE001
        print("could not run the census: %s" % exc, file=sys.stderr)
        return 2
    bad = report(rows)
    if "--snapshot" in argv:
        print("wrote %s" % write_snapshot(rows))
    return 3 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
