#!/usr/bin/env python3
"""Ratchets for tools/agent/talent_value_read_census.py (GH #228, axis TALENTVALUE).

WHAT THE TOOL IS FOR.  Twenty-one live sites in bots/BotLib add
`talentN:GetSpecialValueInt('value')` to a number they just read off an ability.
Every one of them is a no-op, because talents come in two families and only one
owns a `value`: GENERIC talents (`special_bonus_hp_200`) are real blocks in
npc_abilities.txt carrying exactly one AbilityValues entry named `value`, while
HERO-UNIQUE talents (`special_bonus_unique_axe_2`) have no KV block anywhere --
their payload lives inside the modified ability's own entry, as a sub-key named
after the talent, which is where the engine folds it.  The census is the
classification of each call site against that partition.

WHAT IS TESTED HERE: the two KV parsers, the Lua scanner, and the classifier.
Nothing here touches the network and nothing here decides which mirror is right
-- the tool does that against the live KV.

⭐ WHY BOTH PARSERS GET THEIR OWN SECTION, AND WHY THE FIXTURES ARE UGLY.
"the talent has no KV block" and "my parser lost the block" print the same
answer, and the verdict this tool exists to emit is the first one.  So each
parser is driven against KV shapes the real files actually contain and that a
naive parser gets wrong:

  * a talent's `value` is LONG-FORM (`"value" { "value" "200" }`), not a scalar
    -- a scalar-only match reports every generic talent as answering nothing,
    which would classify all 974 as UNIQUE and make the tool's headline
    "everything is dead" while proving nothing;
  * a hero's talent run does not always start at Ability10 (GH #214: kez and
    rubick at 12, largo 15, invoker 17), so slot N is taken by POSITION IN THE
    RUN, never by `N + 9`;
  * `npc_heroes.txt` nests ability-draft blocks that repeat "Ability1".."Ability4"
    one tab deeper with a different meaning (GH #209), so depth is load-bearing.

⭐ WHY THE LUA SCANNER'S COMMENT STRIPPER IS DRIVEN BOTH WAYS.  Nine of the
`value` reads in bots/ sit on commented-out `aetherRange` lines -- across the
focus five and others.  A scanner that reads prose would put the headline count
out by a third and point rows at lines that cannot run.  A scanner that strips
too eagerly loses the binding line and silently drops real sites, which reports
as "clean".  Both directions are fed below.
"""

import os
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import talent_value_read_census as C  # noqa: E402


ABILITIES_KV = '''
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

	"special_bonus_strength_15"
	{
		"AbilityValues"
		{
			"value"		"15"
		}
	}

	// a block that exists but declares nothing readable
	"special_bonus_shard"
	{
		"AbilityType"					"ABILITY_TYPE_ATTRIBUTES"
	}

	// A talent named DEEPER than one tab, on its own line: this is a sub-entry
	// of an ability value, not an ability.  Accepting it would invent a KV block
	// for a hero-unique talent -- and inventing exactly one block is enough to
	// turn this tool's whole finding upside down for that site.
	"some_ability"
	{
		"AbilityValues"
		{
			"radius"
			{
				"value"							"315"
				"special_bonus_unique_axe_2"
				{
					"value"						"+85"
				}
			}
		}
	}
'''

HEROES_KV = '''
"npc_dota_hero_axe"
	{
		"AbilityDraft"
		{
			"Ability1"		"special_bonus_draft_decoy"
		}
		"Ability1"		"axe_berserkers_call"
		"Ability10"		"special_bonus_unique_axe_culling_blade_speed_duration"
		"Ability11"		"special_bonus_hp_200"
		"Ability12"		"special_bonus_shard"
	}
	"npc_dota_hero_invoker"
	{
		"Ability17"		"special_bonus_unique_invoker_first"
		"Ability18"		"special_bonus_unique_invoker_second"
	}
'''


class TalentBlockParser(unittest.TestCase):
    def setUp(self):
        self.blocks = C.parse_talent_blocks(ABILITIES_KV)

    def test_long_form_value_is_answerable(self):
        # The shape every one of the 421 generic talents in the live file has.
        self.assertIs(self.blocks.get("special_bonus_hp_200"), True)

    def test_scalar_value_is_answerable(self):
        self.assertIs(self.blocks.get("special_bonus_strength_15"), True)

    def test_block_without_value_is_not_answerable(self):
        # Present but empty is a THIRD verdict, not a synonym for absent: the
        # site would still read 0, but for a reason a patch can change.
        self.assertIs(self.blocks.get("special_bonus_shard"), False)

    def test_absent_talent_is_absent_not_defaulted(self):
        # The whole finding rests on this: `not in blocks` must mean "no block",
        # never "block whose value I failed to find".
        self.assertNotIn("special_bonus_unique_axe_2", self.blocks)

    def test_nested_talent_sub_entry_is_not_a_block(self):
        # The escape that drove this fixture in: with the depth anchor widened
        # from `^\t"` to `^\t+"`, every check above still passed, because the
        # fixture had nothing deeper for the widened pattern to catch.  A talent
        # that appears as a LONG-FORM sub-entry of an ability value would then
        # be classified as owning a block, i.e. as answering `value` -- which
        # flips this tool's verdict for that site from "the term is dead" to
        # "the term is live", in the direction that reads as reassuring.
        self.assertNotIn("special_bonus_unique_axe_2", self.blocks)

    def test_comments_do_not_create_blocks(self):
        self.assertNotIn("special_bonus_commented_out",
                         C.parse_talent_blocks(
                             '\t// "special_bonus_commented_out"\n'))


class HeroTalentParser(unittest.TestCase):
    def setUp(self):
        self.talents = C.parse_hero_talents(HEROES_KV)

    def test_run_excludes_real_abilities(self):
        self.assertEqual(
            self.talents["axe"],
            ["special_bonus_unique_axe_culling_blade_speed_duration",
             "special_bonus_hp_200", "special_bonus_shard"])

    def test_nested_draft_block_is_not_a_talent(self):
        # GH #209: the draft block repeats AbilityN one tab deeper.  If it were
        # accepted, slot 1 would name a talent the hero does not have and every
        # downstream verdict for that hero would be about the wrong row.
        self.assertNotIn("special_bonus_draft_decoy", self.talents["axe"])

    def test_run_not_starting_at_ability10(self):
        # GH #214.  A parser that computed `slot = N - 9` would return an empty
        # list here, and an empty list classifies as OUT-OF-RANGE rather than as
        # a parse hole -- a wrong verdict that looks like a finding.
        self.assertEqual(self.talents["invoker"],
                         ["special_bonus_unique_invoker_first",
                          "special_bonus_unique_invoker_second"])

    def test_empty_parse_raises_rather_than_returning_clean(self):
        with self.assertRaises(ValueError):
            C.parse_hero_talents("nothing here at all\n")


class LuaScanner(unittest.TestCase):
    SRC = "\n".join([
        "local talentA = bot:GetAbilityByName( sTalentList[7] )",
        "local talentB = bot:GetAbilityByName( sTalentList[2] )",
        "local abilityQ = bot:GetAbilityByName( sAbilityList[1] )",
        "if talentA:IsTrained() then n = n + talentA:GetSpecialValueInt( 'value' ) end",
        "--\tif talentB:IsTrained() then n = n + talentB:GetSpecialValueInt( 'value' ) end",
        "local nR = abilityQ:GetSpecialValueInt( 'value' )",
        'local nS = talentA:GetSpecialValueFloat( "value" )',
        "local nT = talentA:GetSpecialValueInt( 'radius' )",
    ])

    def sites(self):
        live = C.strip_lua_comments(self.SRC)
        binds = {m.group(1): int(m.group(2)) for m in C.BIND_RE.finditer(live)}
        out = []
        for lineno, line in enumerate(live.split("\n"), 1):
            for m in C.READ_RE.finditer(line):
                if m.group(1) in binds:
                    out.append((lineno, m.group(1), binds[m.group(1)]))
        return out

    def test_line_count_is_preserved(self):
        # A reported line has to be the line a reader opens.
        self.assertEqual(len(C.strip_lua_comments(self.SRC).split("\n")),
                         len(self.SRC.split("\n")))

    def test_live_read_is_found_with_its_slot(self):
        self.assertIn((4, "talentA", 7), self.sites())

    def test_float_form_and_double_quoted_key(self):
        self.assertIn((7, "talentA", 7), self.sites())

    def test_commented_read_is_not_counted(self):
        # The case the tree really has, nine times over.
        self.assertNotIn(5, [row[0] for row in self.sites()])

    def test_ability_handle_is_not_a_talent_read(self):
        # `abilityQ:GetSpecialValueInt('value')` is a different finding entirely
        # (an ability entry's own inner `value` key) and must not be folded in.
        self.assertNotIn(6, [row[0] for row in self.sites()])

    def test_other_keys_on_a_talent_handle_are_not_counted(self):
        self.assertNotIn(8, [row[0] for row in self.sites()])

    def test_exactly_two_sites(self):
        self.assertEqual(len(self.sites()), 2)


class Classifier(unittest.TestCase):
    TALENTS = {"axe": ["special_bonus_unique_axe_2", "special_bonus_hp_200",
                       "special_bonus_shard"]}
    BLOCKS = {"special_bonus_hp_200": True, "special_bonus_shard": False}

    def verdicts(self, slot):
        rows = [("axe", "bots/BotLib/hero_axe.lua", 1, "talentX", slot)]
        return C.classify(rows, self.TALENTS, self.BLOCKS)[0][6]

    def test_unique_reads_zero(self):
        self.assertEqual(self.verdicts(1), "UNIQUE-READS-ZERO")

    def test_generic_reads_a_number(self):
        # Not a synonym for "fine": a generic talent's value belongs to no
        # ability, so adding it to an ability quantity is a category error.  It
        # is a separate verdict so that it cannot hide inside the dead ones.
        self.assertEqual(self.verdicts(2), "GENERIC-READS-A-NUMBER")

    def test_block_without_value_is_its_own_verdict(self):
        self.assertEqual(self.verdicts(3), "GENERIC-NO-VALUE-KEY")

    def test_out_of_range_slot(self):
        # A hero whose run got shorter than the file's index: report it, never
        # silently drop the row (a dropped row reads as "clean").
        self.assertEqual(self.verdicts(9), "OUT-OF-RANGE")


class SnapshotRender(unittest.TestCase):
    def test_render_quotes_and_escapes(self):
        found = [("axe", "bots/BotLib/hero_axe.lua", 376, "talent7", 7,
                  "special_bonus_unique_axe_2", "UNIQUE-READS-ZERO")]
        out = C.render(found, (974, 65))
        self.assertIn("talents = 974", out)
        self.assertIn("with_own_kv_block = 65", out)
        self.assertIn("'special_bonus_unique_axe_2'", out)
        self.assertIn("verdict = 'UNIQUE-READS-ZERO'", out)

    def test_render_declares_its_generator(self):
        # GH #214's escape: an assertion that reads only the committed .lua
        # never sees the generator, so a generator that stops declaring where
        # its data came from rides to the next patch unnoticed.  Assert the
        # RENDERER, not the file.
        out = C.render([], (974, 65))
        self.assertIn("talent_value_read_census.py", out.split("\n")[0])

    def test_committed_snapshot_matches_the_renderer_header(self):
        path = os.path.join(REPO, "tests", "mock", "talent_value_reads.lua")
        with open(path, encoding="utf-8") as fh:
            first = fh.readline().rstrip("\n")
        self.assertEqual(first, C.render([], (0, 0)).split("\n")[0])


class SelfTest(unittest.TestCase):
    def test_tool_self_test_passes(self):
        self.assertEqual(C.self_test(), 0)


if __name__ == "__main__":
    unittest.main(verbosity=0)
