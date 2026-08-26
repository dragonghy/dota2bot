#!/usr/bin/env python3
"""Census: `talentN:GetSpecialValue*('value')` reads, and whether the talent
handle they are taken on can answer `value` at all.

Why this exists (hero group, 2026-08-26, axis `TALENTVALUE`)
------------------------------------------------------------
Forty-odd hero files share one idiom for "add the talent bonus to the number I
just read off the ability":

    local nRadius = abilityQ:GetSpecialValueInt( 'radius' )
    if talent7:IsTrained() then nRadius = nRadius + talent7:GetSpecialValueInt( 'value' ) end

It reads as live arithmetic.  It is not.  Talents come in two families and only
one of them owns a `value`:

  * **generic** talents (`special_bonus_hp_200`, `special_bonus_strength_15`,
    ...) are real ability blocks in `npc_abilities.txt`, each carrying exactly
    one `AbilityValues` entry named `value`.  A `GetSpecialValueInt('value')`
    on one of those answers a number.
  * **hero-unique** talents (`special_bonus_unique_axe_2`, ...) have **no KV
    block anywhere** -- not in `npc_abilities.txt`, not in the hero's own
    `npc_dota_hero_<h>.txt`.  Their payload lives inside the *modified
    ability's* `AbilityValues` entry, as a sub-key named after the talent:

        "radius"
        {
            "value"                         "300"
            "special_bonus_unique_axe_2"    "+85"
        }

    So the talent handle has no special values of any kind, `value` included,
    and `talent:GetSpecialValueInt('value')` is a silent 0 (BOT_API_REFERENCE:
    "a typo will silently return 0").

The partition is total and the name carries it: of the 974 talents the shipped
roster references, 65 have their own block (all generic, all with `value`) and
909 do not (all with `unique` in the name).  Measured, not assumed -- rerun
this script.

WHAT THE FINDING IS, AND WHAT IT IS NOT
---------------------------------------
A UNIQUE site is a proof that the term contributes 0.  It is **not**, on its
own, a proof that the branch is wrong -- and here it happens not to be, which
is the part worth writing down:

The KV shape above exists so the engine can fold `+85` into `radius` for a
caster who has trained that talent.  There is nowhere else the bonus could come
from; if the engine did not fold it, the talent would do nothing in the game at
all.  So `abilityQ:GetSpecialValueInt('radius')` already returns the
talent-inclusive number, and the `+ talent:GetSpecialValueInt('value')` term is
dead *in the safe direction*: repointing it at a handle that answers -- the
obvious "repair" -- would DOUBLE-COUNT the bonus.

This repo has already bet on that fold once, in a landed repair: GH #162's
`lionsplash` reads `lion_finger_of_death/splash_radius`, which
`special_value_shape_census.py` classifies NO-BASE -- the entry has no base
`value`, only `special_bonus_scepter "325"`.  That read is worth something only
if the engine resolves `special_bonus_*` sub-entries per caster.  The 21 sites
this script finds encode the opposite bet.  Both cannot be right, and the KV
shape says which one is.

The one site where the finding does NOT reduce to "harmless": when the base
number is **hardcoded** rather than read off the ability, no fold reaches it.
`hero_axe.lua`'s Culling Blade kill-check is the shipped example
(`nKillDamage = 150 + 100 * nSkillLV`), and its repair is the already-registered
`hero-2` lever, not this axis.

WHAT IT COSTS
    Two HTTPS GETs against the dotabuff/d2vpkr mirror this repo already reads
    (`npc_heroes.txt` for each hero's talent order, `npc_abilities.txt` for the
    generic talent blocks).  No per-hero fan-out, no AWS, no cost.

    python3 tools/agent/talent_value_read_census.py             # census
    python3 tools/agent/talent_value_read_census.py --snapshot  # regen the mock
    python3 tools/agent/talent_value_read_census.py --self-test # parser pins

Exit codes follow the house convention: 0 clean / 2 could-not-run / 3 findings.

PARSER FIDELITY IS PART OF THE CLAIM
------------------------------------
"The talent has no KV block" and "my parser lost the block" print the same
answer, so both parsers are pinned by `--self-test` against literal KV excerpts:

  * talent blocks sit at ONE tab in `npc_abilities.txt` and their `value` is a
    long-form entry (`"value" { "value" "200" }`), not a scalar;
  * a hero's talents are a contiguous run of `"AbilityN" "special_bonus_*"` at
    TWO tabs in `npc_heroes.txt`, and the run does not always start at
    Ability10 (GH #214: kez/rubick 12, largo 15, invoker 17) -- this script
    therefore takes the talents in the order they appear, never by fixed index;
  * hero HEADERS are not uniformly indented (GH #209: slark/earth_spirit start
    at column 0), so header indent is never used as a base.

And the Lua side is scanned with comments stripped FIRST: nine of the reads in
`bots/` sit on commented-out `aetherRange` lines, and counting those would put
the census's own headline number out by a third.
"""

import argparse
import glob
import os
import re
import sys
import urllib.request

HEROES_URL = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
              "dota/scripts/npc/npc_heroes.txt")
ABILITIES_URL = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
                 "dota/scripts/npc/npc_abilities.txt")
OUT = "tests/mock/talent_value_reads.lua"

FOCUS_FIVE = ("axe", "zuus", "skeleton_king", "lion", "crystal_maiden")


def fetch(url):
    with urllib.request.urlopen(url, timeout=180) as fh:
        return fh.read().decode("utf-8", "replace")


def strip_kv_comments(text):
    """Drop `//` comments.  KV has no block comments and no escaped quotes in
    the keys this script reads, so a line-tail cut is exact here."""
    return re.sub(r'//[^\n]*', '', text)


def parse_hero_talents(text):
    """hero -> ordered list of its `special_bonus_*` abilities.

    Order is the file's own AbilityN order, taken by appearance.  The run's
    starting index is deliberately NOT assumed (GH #214)."""
    text = strip_kv_comments(text)
    out = {}
    cur = None
    for line in text.split("\n"):
        m = re.match(r'^\t?"(npc_dota_hero_[a-z0-9_]+)"\s*$', line)
        if m:
            cur = m.group(1)[len("npc_dota_hero_"):]
            out.setdefault(cur, [])
            continue
        m = re.match(r'^\t\t"Ability\d+"\s+"(special_bonus_[a-z0-9_]+)"', line)
        if m and cur is not None:
            out[cur].append(m.group(1))
    if not out:
        raise ValueError("npc_heroes.txt parsed to zero heroes -- parse hole")
    return out


def parse_talent_blocks(text):
    """talent name -> True if its own KV block declares a `value` entry.

    Only blocks at exactly one tab are ability definitions; anything deeper is
    a nested table (`AbilityValues`, ability-draft blocks)."""
    text = strip_kv_comments(text)
    # Boundaries are EVERY one-tab block, not just the talent ones.  Slicing
    # talent-start to talent-start looks equivalent while the talents happen to
    # be contiguous, and silently swallows the next ability's body the moment
    # they are not -- which reads `value` off a neighbour and reports a talent
    # that declares nothing as answering.  The tool's own fixture caught this;
    # in the live file the LAST talent block would have absorbed the entire
    # remainder of npc_abilities.txt unconditionally.
    starts = [(m.start(), m.group(1))
              for m in re.finditer(r'^\t"([a-z0-9_]+)"\s*$', text, re.M)]
    starts.append((len(text), None))
    out = {}
    for i in range(len(starts) - 1):
        pos, name = starts[i]
        if not name.startswith("special_bonus_"):
            continue
        body = text[pos:starts[i + 1][0]]
        out[name] = re.search(r'"value"\s*\n?\s*[{"]', body) is not None
    return out


def strip_lua_comments(src):
    """Blank out `--` line comments, keeping line numbering intact."""
    out = []
    for line in src.split("\n"):
        idx = line.find("--")
        out.append(line if idx < 0 else line[:idx])
    return "\n".join(out)


BIND_RE = re.compile(
    r'local\s+(\w+)\s*=\s*bot:GetAbilityByName\(\s*sTalentList\[\s*(\d+)\s*\]')
READ_RE = re.compile(r'(\w+):GetSpecialValue(?:Int|Float)\(\s*[\'"]value[\'"]')


def scan_hero_files(root="bots/BotLib"):
    """-> list of (hero, path, lineno, var, slot) for live talent `value` reads."""
    rows = []
    for path in sorted(glob.glob(os.path.join(root, "hero_*.lua"))):
        hero = os.path.basename(path)[len("hero_"):-len(".lua")]
        live = strip_lua_comments(open(path, encoding="utf-8", errors="replace").read())
        binds = {m.group(1): int(m.group(2)) for m in BIND_RE.finditer(live)}
        for lineno, line in enumerate(live.split("\n"), 1):
            for m in READ_RE.finditer(line):
                var = m.group(1)
                if var in binds:
                    rows.append((hero, path, lineno, var, binds[var]))
    return rows


def classify(rows, talents, blocks):
    """-> list of (hero, path, lineno, var, slot, talent_name, verdict)."""
    out = []
    for hero, path, lineno, var, slot in rows:
        names = talents.get(hero, [])
        if not 1 <= slot <= len(names):
            out.append((hero, path, lineno, var, slot, None, "OUT-OF-RANGE"))
            continue
        name = names[slot - 1]
        if name not in blocks:
            verdict = "UNIQUE-READS-ZERO"
        elif blocks[name]:
            verdict = "GENERIC-READS-A-NUMBER"
        else:
            verdict = "GENERIC-NO-VALUE-KEY"
        out.append((hero, path, lineno, var, slot, name, verdict))
    return out


def render(found, roster):
    lines = [
        "--- GENERATED by tools/agent/talent_value_read_census.py -- do not hand-edit.",
        "---",
        "--- Every live `talentN:GetSpecialValue*('value')` call site in bots/BotLib,",
        "--- with the talent that sTalentList[N] names (npc_heroes.txt order) and",
        "--- whether that talent owns a KV block that could answer 'value'.",
        "---",
        "--- UNIQUE-READS-ZERO      the talent has no KV block at all; the read is 0.",
        "---                        Its bonus lives as a `special_bonus_*` sub-key inside",
        "---                        the ability it modifies, which is where the engine",
        "---                        folds it -- so the base read already carries it and",
        "---                        repointing this term would DOUBLE-COUNT.",
        "--- GENERIC-READS-A-NUMBER the talent owns a block with `value`; the read is real",
        "---                        (and belongs to no ability, so adding it to an ability",
        "---                        quantity is a category error worth a second look).",
        "---",
        "--- This is a CONSISTENCY ratchet, not a correctness one: it goes red when the",
        "--- shipped call sites and this table stop agreeing.  Correctness is owned by the",
        "--- source -- rerun the census against the live KV to move the table.",
        "",
        "return {",
        "    roster = { talents = %d, with_own_kv_block = %d },"
        % (roster[0], roster[1]),
        "    sites = {",
    ]
    for hero, path, lineno, var, slot, name, verdict in found:
        lines.append(
            "        { hero = %s, file = %s, line = %d, var = %s, slot = %d, "
            "talent = %s, verdict = %s },"
            % (lua_str(hero), lua_str(path), lineno, lua_str(var), slot,
               lua_str(name or ""), lua_str(verdict)))
    lines += ["    },", "}", ""]
    return "\n".join(lines)


def lua_str(s):
    return "'" + str(s).replace("\\", "\\\\").replace("'", "\\'") + "'"


SELFTEST_ABILITIES = '''
	"special_bonus_hp_200"
	{
		"AbilityType"					"ABILITY_TYPE_ATTRIBUTES"
		"AbilityValues"
		{
			"value"
			{
				"value" "200"
			}
		}
	}

	// a talent whose block exists but declares no value at all
	"special_bonus_shard"
	{
		"AbilityType"					"ABILITY_TYPE_ATTRIBUTES"
	}
'''

SELFTEST_HEROES = '''
"npc_dota_hero_axe"
	{
		"AbilityDraft"
		{
			"Ability1"		"not_a_talent_this_block_is_deeper"
		}
		"Ability1"		"axe_berserkers_call"
		"Ability10"		"special_bonus_unique_axe_culling_blade_speed_duration"
		"Ability11"		"special_bonus_unique_axe_8"
	}
	"npc_dota_hero_invoker"
	{
		"Ability17"		"special_bonus_unique_invoker_first"
		"Ability18"		"special_bonus_unique_invoker_second"
	}
'''


def self_test():
    fails = []

    def check(cond, msg):
        if not cond:
            fails.append(msg)

    blocks = parse_talent_blocks(SELFTEST_ABILITIES)
    check(blocks.get("special_bonus_hp_200") is True,
          "generic talent with a long-form `value` must read as answerable")
    check(blocks.get("special_bonus_shard") is False,
          "a talent block with no value must not read as answerable")
    check("special_bonus_unique_axe_2" not in blocks,
          "a talent with no block must be absent, not defaulted")

    tal = parse_hero_talents(SELFTEST_HEROES)
    check(tal.get("axe") == ["special_bonus_unique_axe_culling_blade_speed_duration",
                             "special_bonus_unique_axe_8"],
          "hero talent run must skip non-talent AbilityN and deeper draft blocks")
    check(tal.get("invoker") == ["special_bonus_unique_invoker_first",
                                 "special_bonus_unique_invoker_second"],
          "a run that does not start at Ability10 must still be read in order")

    src = ("local talentX = bot:GetAbilityByName( sTalentList[3] )\n"
           "--\tif talentX:IsTrained() then n = n + talentX:GetSpecialValueInt( 'value' ) end\n"
           "if talentX:IsTrained() then n = n + talentX:GetSpecialValueInt( 'value' ) end\n")
    live = strip_lua_comments(src)
    check(live.count("GetSpecialValueInt") == 1,
          "commented-out reads must be stripped before counting")
    check("sTalentList[3]" in live,
          "stripping comments must not eat the binding line")

    for msg in fails:
        print("SELF-TEST FAIL: " + msg)
    print("self-test: %d check(s), %d failure(s)" % (7, len(fails)))
    return 3 if fails else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--snapshot", action="store_true",
                    help="regenerate " + OUT)
    ap.add_argument("--self-test", action="store_true",
                    help="run the parser pins and exit")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    try:
        talents = parse_hero_talents(fetch(HEROES_URL))
        blocks = parse_talent_blocks(fetch(ABILITIES_URL))
    except Exception as exc:                                # noqa: BLE001
        print("COULD NOT RUN: %s" % exc)
        return 2

    referenced = set()
    for names in talents.values():
        referenced.update(names)
    with_block = referenced & set(blocks)
    roster = (len(referenced), len(with_block))

    found = classify(scan_hero_files(), talents, blocks)

    print("roster: %d talents referenced by shipped heroes, %d own a KV block"
          % roster)
    unique_named = [t for t in referenced - with_block if "unique" not in t]
    print("        of the %d with no block, %d lack `unique` in the name"
          % (len(referenced) - len(with_block), len(unique_named)))
    print("live `talentN:GetSpecialValue*('value')` sites: %d" % len(found))
    print()

    for verdict in ("UNIQUE-READS-ZERO", "GENERIC-READS-A-NUMBER",
                    "GENERIC-NO-VALUE-KEY", "OUT-OF-RANGE"):
        rows = [r for r in found if r[6] == verdict]
        if not rows:
            continue
        print("%s: %d" % (verdict, len(rows)))
        for hero, path, lineno, var, slot, name, _ in rows:
            mark = "   <-- FOCUS FIVE" if hero in FOCUS_FIVE else ""
            print("  %s:%d  %s=sTalentList[%d] -> %s%s"
                  % (path, lineno, var, slot, name, mark))
        print()

    if args.snapshot:
        with open(OUT, "w", encoding="utf-8") as fh:
            fh.write(render(found, roster))
        print("wrote %s" % OUT)

    return 3 if any(r[6] != "GENERIC-READS-A-NUMBER" for r in found) else 0


if __name__ == "__main__":
    sys.exit(main())
