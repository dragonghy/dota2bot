#!/usr/bin/env python3
"""Census: `GetSpecialValue*('key')` reads whose key exists but whose VALUE
does not answer what the call site reads it as.

Why this exists (hero group, 2026-08-25, axis `VALSHAPE`)
---------------------------------------------------------
GH #162's census (`special_value_key_census.py`) asks ONE question about a
`GetSpecialValue*` read: *is the key in the ability's KV at all?*  A key that is
present comes back clean.  That question has two blind spots, and both of them
end in the same silent number the whole `0DMG` / `0SELL` family ends in -- no
error, no warning, nothing a bot-side print could show (AGENTS.md):

  * **LOSSY-INT** -- the key is present, but its value is fractional and the
    call site reads it with `GetSpecialValueInt`.  `0.8` is not `0.8` there;
    it is `0` or `1`.  For a value in (0, 1) the read COLLAPSES: truncation and
    rounding both destroy it (rounding keeps a 0.8, kills a 0.25 -- so only
    values below 0.5 are collapse-proven, and the rest are proven *lossy*).
  * **NO-BASE** -- the key is present, but the KV entry carries NO base
    `value`, only conditional `special_bonus_*` entries.  The read is 0 for
    every caster that does not satisfy the condition.  Today's example is
    `lion_finger_of_death/splash_radius`: no base value, `special_bonus_scepter
    "325"`.  The key census calls that key PRESENT, which is true and says
    nothing about what the read answers.

So this is not a second opinion on #162's axis; it is the half of the same read
that #162's ruler structurally cannot measure.

WHAT IT PROVES AND WHAT IT DOES NOT
-----------------------------------
Same one-directional discipline as the key census and the `0DMG` census, for
the same reason -- this script does not resolve which ability a Lua handle
points at:

  * a read in `bots/BotLib/hero_<h>.lua` can only be taken on one of `<h>`'s
    own abilities.  If EVERY ability of `<h>` that declares the key has the bad
    shape, the finding holds **whichever handle it was taken on** -- a proof;
  * if even one declaring ability has a clean shape, the answer is UNRESOLVED
    and nothing is claimed.  `duration` is fractional on axe_berserkers_call
    (2.1/2.4/2.7/3.0) and integral on axe_battle_hunger (12.0), so
    `hero_axe.lua`'s Int read of `duration` is UNRESOLVED here even though the
    file's own binding (`abilityW` = sAbilityList[2]) settles it by hand.

Silence is therefore NOT a clean bill of health, and a finding is a fact about
the READ, never a verdict on the branch: whether a truncated or zeroed value
widens or narrows the branch has to be read per call site (the `0DMG` lesson --
the same 0 fed to `FindAoELocation`'s nMaxHealth WIDENS and fed to
`J.WillMagicKillTarget` NARROWS).

PARSER FIDELITY IS PART OF THE CLAIM
------------------------------------
A KV parser that loses a key reports exactly what "the key is not there"
reports.  That already bit this team twice: GH #177's cast-shape parser fell out
of step on brewmaster and silently dropped the whole tail of that file, and the
first draft of THIS script dropped every long-form key with no base `value` --
which would have reported lion's `splash_radius` as MISSING, i.e. "GH #162's
landed repair swapped one silent zero for another".  It did not; the key is
there and its shape is NO-BASE by design (scepter-only value on a scepter-only
branch).  `--self-test` pins the four KV shapes this parser must survive so the
next gap is loud instead of empty.

Usage:

    python3 tools/agent/special_value_shape_census.py             # census
    python3 tools/agent/special_value_shape_census.py --focus     # focus five only
    python3 tools/agent/special_value_shape_census.py --self-test # parser only, no network
    python3 tools/agent/special_value_shape_census.py --snapshot  # tests/mock/special_value_shapes.lua

Network: one HTTPS GET per shipped hero against the public d2vpkr mirror that
`gen_ability_meta.py` / `special_value_key_census.py` / `ability_damage_census.py`
already use.  No AWS, no cost.  Tests never go to the network -- they read the
frozen snapshot.
"""

import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import special_value_key_census as KEYS          # noqa: E402  (fetch/BASE/FOCUS_FIVE)

REPO = KEYS.REPO
SNAPSHOT = "tests/mock/special_value_shapes.lua"

# `talentN:GetSpecialValueInt('value')` -- talents are special_bonus_* abilities
# in npc_abilities.txt, not in the hero KV.  Same exemption the key census makes.
TALENT_KEYS = KEYS.TALENT_KEYS

CALL_RE = re.compile(r"GetSpecialValue(Int|Float)\s*\(\s*['\"]([A-Za-z0-9_]+)['\"]")


def strip_comments(src):
    return re.sub(r"--[^\n]*", "", src)


def parse_shapes(text):
    """{ ability -> { key -> {'base': [str], 'bonus': [(str, str)]} } }.

    Braces are COUNTED per line rather than matched against a line that starts
    with one: the `"key" {` shape exists in the wild (GH #177 found it on
    brewmaster), and a parser that ignores such a line never pushes the brace,
    falls out of step and then silently mis-files -- or drops -- everything
    after it in that file.
    """
    out, stack, pend = {}, [], None
    for raw in text.splitlines():
        line = raw.split("//")[0].strip()
        if not line:
            continue
        opens, closes = line.count("{"), line.count("}")
        toks = re.findall(r'"([^"]*)"', line)

        pair = re.match(r'^"([^"]+)"\s+"([^"]*)"\s*$', line)
        if pair and opens == 0 and closes == 0:
            name, value = pair.group(1), pair.group(2)
            if len(stack) >= 2 and stack[-1] == "AbilityValues":
                # "key" "value" shorthand, directly under AbilityValues
                out.setdefault(stack[-2], {})[name] = {"base": [value], "bonus": []}
            elif len(stack) >= 3 and stack[-2] == "AbilityValues":
                # inside a long-form "key" { ... } block
                entry = out.setdefault(stack[-3], {}).setdefault(
                    stack[-1], {"base": [], "bonus": []})
                if name == "value":
                    entry["base"].append(value)
                else:
                    entry["bonus"].append((name, value))
            elif len(stack) >= 1 and name in KEYS.TOP_LEVEL:
                out.setdefault(stack[-1], {})[name] = {"base": [value], "bonus": []}
            continue

        lone = re.match(r'^"([^"]+)"\s*$', line)
        if lone and opens == 0 and closes == 0:
            pend = lone.group(1)
            continue

        for _ in range(opens):
            name = pend if pend is not None else (toks[0] if toks else None)
            # A long-form key is registered the moment its block opens, so a key
            # whose block carries no `value` line still exists (that is NO-BASE,
            # not "absent" -- the distinction this whole script is about).
            if name is not None and stack and stack[-1] == "AbilityValues":
                out.setdefault(stack[-2] if len(stack) >= 2 else "?", {}).setdefault(
                    name, {"base": [], "bonus": []})
            stack.append(name if name is not None else "?")
            pend = None
        for _ in range(closes):
            if stack:
                stack.pop()
    return out


def numbers(value):
    """The numeric per-level tokens of a KV value string ('140 220 300' -> [...])."""
    out = []
    for tok in re.split(r"\s+", value.strip()):
        try:
            out.append(float(tok.lstrip("+")))
        except ValueError:
            pass
    return out


def is_fractional(x):
    return abs(x - round(x)) > 1e-9


def reads_in(path):
    """[(line_no, 'Int'|'Float', key)] for one Lua file, comments stripped."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        src = strip_comments(fh.read())
    out = []
    for n, line in enumerate(src.splitlines(), 1):
        for kind, key in CALL_RE.findall(line):
            out.append((n, kind, key))
    return out


def classify(hero, kind, key, shapes):
    """One read -> (verdict, detail).  See the module docstring for the rules."""
    if key in TALENT_KEYS:
        return "TALENT", ""
    holders = [(a, d[key]) for a, d in shapes.items() if key in d]
    if not holders:
        return "MISSING", "no ability of %s declares it (GH #162's axis)" % hero

    if all(not e["base"] for _, e in holders):
        bonus = sorted({b for _, e in holders for b, _ in e["bonus"]})
        return "NO-BASE", "conditional only: %s" % (", ".join(bonus) or "nothing at all")

    if kind == "Int":
        levels = [x for _, e in holders for v in e["base"] for x in numbers(v)]
        if levels and all(is_fractional(x) for x in levels):
            vals = sorted(set(levels))
            if all(0 < x < 0.5 for x in levels):
                return "LOSSY-INT/COLLAPSE", "every level in (0, 0.5): %s" % vals
            return "LOSSY-INT", "every level fractional: %s" % vals
    return "OK", ""


def census(heroes):
    with ThreadPoolExecutor(8) as pool:
        texts = dict(pool.map(KEYS.fetch, heroes))
    rows, scanned = [], 0
    for hero in heroes:
        text = texts.get(hero)
        if not text:
            continue
        shapes = parse_shapes(text)
        for line, kind, key in reads_in(os.path.join(
                REPO, "bots/BotLib/hero_%s.lua" % hero)):
            scanned += 1
            verdict, detail = classify(hero, kind, key, shapes)
            if verdict not in ("OK", "TALENT"):
                rows.append((hero, line, kind, key, verdict, detail))
    return scanned, rows, texts


# --------------------------------------------------------------------------
# Snapshot: the focus five only.  The standing assertion is about the files
# this stream owns, and a table of all 128 heroes would be a large generated
# file nobody reads (the reasoning special_value_keys.lua already uses).

def write_snapshot(texts):
    lines = [
        "-- GENERATED by tools/agent/special_value_shape_census.py --snapshot "
        "-- do not hand-edit.",
        "--",
        "-- The SHAPE of every AbilityValues / Ability* entry on the five focus",
        "-- heroes' abilities, read out of the game's own KV (npc_dota_hero_<name>.txt",
        "-- on the d2vpkr mirror).  tests/mock/special_value_keys.lua answers *is this",
        "-- key here*; this file answers *what does reading it give you*:",
        "--",
        "--   base  = the per-level value string, or nil when the entry carries none",
        "--           (NO-BASE: the read is 0 unless a conditional bonus applies)",
        "--   bonus = the conditional entries (special_bonus_*, LinkedSpecialBonus, ...)",
        "--",
        "-- tests/test_special_value_shape.lua asserts that no focus-five",
        "-- GetSpecialValueInt read lands on a fractional value, and pins the one",
        "-- NO-BASE read this tree makes on purpose.",
        "--",
        "-- Regenerate after a patch:",
        "--   python3 tools/agent/special_value_shape_census.py --snapshot",
        "",
        "local X = {}",
        "",
        "-- hero unit short name -> ability -> key -> { base = <string?>, bonus = { ... } }",
        "X.SHAPES = {",
    ]
    for hero in KEYS.FOCUS_FIVE:
        text = texts.get(hero)
        assert text, "no KV fetched for %s" % hero
        shapes = parse_shapes(text)
        lines.append("    ['%s'] = {" % hero)
        for ability in sorted(shapes):
            lines.append("        ['%s'] = {" % ability)
            for key in sorted(shapes[ability]):
                entry = shapes[ability][key]
                base = entry["base"]
                base_lua = ("'%s'" % " ".join(base)) if base else "nil"
                bonus = ", ".join("['%s'] = '%s'" % (b, v) for b, v in entry["bonus"])
                lines.append("            ['%s'] = { base = %s, bonus = { %s } },"
                             % (key, base_lua, bonus))
            lines.append("        },")
        lines.append("    },")
    lines += ["}", "", "return X", ""]
    path = os.path.join(REPO, SNAPSHOT)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    return path


# --------------------------------------------------------------------------
# --self-test: the four KV shapes the parser must survive.  A parser gap reads
# exactly like "there is nothing there", so it gets its own red light.

SELF_TEST_KV = '''
"DOTAAbilities"
{
	"demo_ability"
	{
		"AbilityCooldown"	"18 16 14 12"
		"AbilityValues"
		{
			"shorthand"		"315"
			"long_form"
			{
				"value"			"12.0"
				"special_bonus_unique_x"	"+8"
			}
			"no_base"
			{
				"special_bonus_scepter"		"325"
				"affected_by_aoe_increase"	"1"
			}
			"inline_brace"	{
				"value"			"0.25"
			}
			"empty_block"
			{
			}
			"nested_only"
			{
				"subkey"
				{
					"value"		"5"
				}
			}
		}
	}
	"second_ability"
	{
		"AbilityValues"
		{
			"after_the_inline_brace"	"7"
		}
	}
}
'''


def self_test():
    got = parse_shapes(SELF_TEST_KV)
    fails = []

    def want(cond, msg):
        if not cond:
            fails.append(msg)

    demo = got.get("demo_ability", {})
    want(demo.get("shorthand", {}).get("base") == ["315"], 'shorthand "k" "v" lost')
    want(demo.get("long_form", {}).get("base") == ["12.0"], "long form value lost")
    want(demo.get("long_form", {}).get("bonus") == [("special_bonus_unique_x", "+8")],
         "long form bonus lost")
    want("no_base" in demo, "a long-form key with NO value line was dropped -- "
                            "that reads exactly like MISSING (the near-miss on lion)")
    want(demo.get("no_base", {}).get("base") == [], "no_base must have no base value")
    # `no_base` alone does NOT test the registration done when the block OPENS:
    # its child lines re-register it on the way past.  These two do, and they are
    # here because removing that line let the mutation escape when they were not.
    want("empty_block" in demo, "a long-form key with an EMPTY block was dropped")
    want("nested_only" in demo, "a long-form key whose only child is another block "
                                "was dropped")
    want(demo.get("nested_only", {}).get("base") == [],
         "a value nested two levels down is not this key's base value")
    want("subkey" not in demo, "a key nested inside another key is not an AbilityValues key")
    want(demo.get("inline_brace", {}).get("base") == ["0.25"], '"key" { on one line lost')
    want(demo.get("AbilityCooldown", {}).get("base") == ["18 16 14 12"], "top-level key lost")
    # The tail check: an inline brace that is not counted desyncs the stack and
    # takes the REST of the file with it (GH #177's brewmaster).
    want(got.get("second_ability", {}).get("after_the_inline_brace", {}).get("base") == ["7"],
         "the ability AFTER an inline brace was lost -- parser desync")

    want(classify("demo", "Int", "inline_brace", got)[0] == "LOSSY-INT/COLLAPSE",
         "0.25 read as Int must be COLLAPSE")
    want(classify("demo", "Float", "inline_brace", got)[0] == "OK",
         "Float reads are not lossy")
    want(classify("demo", "Int", "no_base", got)[0] == "NO-BASE", "no_base misclassified")
    want(classify("demo", "Int", "shorthand", got)[0] == "OK", "315 is not lossy")
    want(classify("demo", "Int", "nope", got)[0] == "MISSING", "absent key misclassified")

    for msg in fails:
        print("SELF-TEST FAIL: %s" % msg)
    print("self-test: %d check(s) failed" % len(fails))
    return 1 if fails else 0


def main(argv):
    if "--self-test" in argv:
        return self_test()

    focus_only = "--focus" in argv
    heroes = list(KEYS.FOCUS_FIVE) if focus_only else KEYS.hero_names()
    scanned, rows, texts = census(heroes)

    print("GetSpecialValue reads scanned: %d over %d hero file(s)" % (scanned, len(heroes)))
    buckets = {}
    for row in rows:
        buckets.setdefault(row[4], []).append(row)
    for verdict in ("LOSSY-INT/COLLAPSE", "LOSSY-INT", "NO-BASE", "MISSING"):
        hits = buckets.get(verdict, [])
        print("\n%s: %d" % (verdict, len(hits)))
        for hero, line, kind, key, _, detail in hits:
            mark = " <-- FOCUS FIVE" if hero in KEYS.FOCUS_FIVE else ""
            print("  hero_%s.lua:%d  GetSpecialValue%s('%s')  %s%s"
                  % (hero, line, kind, key, detail, mark))

    if "--snapshot" in argv:
        missing = [h for h in KEYS.FOCUS_FIVE if not texts.get(h)]
        if missing:
            _, _, extra = census(missing)
            texts.update(extra)
        print("\nwrote %s" % write_snapshot(texts))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
