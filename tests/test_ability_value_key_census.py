#!/usr/bin/env python3
"""Ratchets for tools/agent/ability_value_key_census.py (GH #228 §6.3, axis ABILVALUE).

WHAT THE TOOL IS FOR.  GH #228 proved that 21 sites reading `'value'` off a
TALENT handle are silent zeros, and registered -- explicitly, as the half it did
not buy -- a sister shape: eight sites that read the same key off an ORDINARY
ABILITY handle, none of which had ever been counted.  An ability's special
values are keyed by the ENTRY NAME inside its `AbilityValues` block; in the
modern long form, `value` is an INNER key of an entry, not an entry.  So the
read answers only if the ability literally owns an entry NAMED `value`, and none
of the seven abilities involved does.

⭐ WHY THE PARSER GETS THE LARGEST SECTION.  The entire finding is the sentence
"this entry name is not in that block", and there are two ways to be wrong about
it that print identically to being right:

  * a parser that reads the INNER keys of a long-form entry as entries reports
    `value` present on nearly every modern ability -- the finding's exact
    negation, delivered as a clean green run;
  * a parser that loses entries manufactures findings on abilities that are
    fine.

So the fixture carries the short form, the long form, an ability that really
does own an entry named `value` (the negative case, which must come back
ANSWERS), the `special_bonus_*` sub-keys that must NOT be read as entries, and
an ability with no AbilityValues block at all -- which must be ABSENT, not
empty, because "no block" and "a block with nothing in it" license different
verdicts.

⭐ WHY THE ORDINAL IS TESTED SEPARATELY.  A site's identity is
(file, variable, nth-read-of-that-variable) -- never the line number (GH #221).
The ordinal is not decoration: hero_enigma.lua reads `Malefice` twice and the
two reads want OPPOSITE repairs -- the first a key (`stun_instances`), the
second deletion (it is a talent term the engine already folded, so a key there
double-counts).  A census that numbered every read 1 would hand both rows the
first row's instruction and stay green.

NOTHING HERE TOUCHES THE NETWORK.  Which KV mirror is right is the tool's
question, decided against the live files.
"""

import os
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import ability_value_key_census as C  # noqa: E402


# Shapes taken from the real per-hero KV: `radius` long-form with a talent
# sub-key (tiny_avalanche), `tick_interval` short-form (same ability),
# an ability that genuinely owns an entry named `value` (how a GENERIC talent
# block is written -- the case that must NOT be reported as a finding), and one
# with no AbilityValues at all.
KV = '''"DOTAAbilities"
{
	"hero_long_and_short"
	{
		"AbilityCastPoint"	"0.3"
		"AbilityValues"
		{
			"tick_interval"		"0.3"
			"radius"
			{
				"value"					"325 340 355 370"
				"special_bonus_unique_x"	"+85"
			}
			"avalanche_damage"
			{
				"value"		"90 180 270 360"
			}
		}
	}
	"hero_owns_value"
	{
		"AbilityValues"
		{
			"value"		"200"
		}
	}
	"hero_no_values"
	{
		"AbilityCastRange"	"600"
	}
}
'''


class Parser(unittest.TestCase):
    def setUp(self):
        self.keys = C.ability_value_keys(KV)

    def test_short_and_long_entries_are_both_entries(self):
        self.assertEqual(self.keys["hero_long_and_short"],
                         ["tick_interval", "radius", "avalanche_damage"])

    def test_inner_value_of_a_long_entry_is_not_an_entry(self):
        # The whole finding inverts if this one goes wrong: every long-form
        # ability would report `value` present and the census would go green.
        self.assertNotIn("value", self.keys["hero_long_and_short"])

    def test_inner_special_bonus_is_not_an_entry(self):
        self.assertNotIn("special_bonus_unique_x", self.keys["hero_long_and_short"])

    def test_an_ability_that_owns_value_reports_it(self):
        self.assertEqual(self.keys["hero_owns_value"], ["value"])

    def test_an_ability_without_ability_values_is_absent_not_empty(self):
        self.assertNotIn("hero_no_values", self.keys)

    def test_keys_outside_ability_values_are_not_entries(self):
        self.assertNotIn("AbilityCastPoint", self.keys["hero_long_and_short"])

    def test_a_file_with_no_abilities_yields_nothing_rather_than_raising(self):
        self.assertEqual(C.ability_value_keys('"DOTAAbilities"\n{\n}\n'), {})


class Scanner(unittest.TestCase):
    def test_an_ability_handle_read_of_value_is_a_site(self):
        self.assertEqual(
            C.scan_file("<t>", ["local Foo = bot:GetAbilityByName('hero_foo')",
                                "local n = Foo:GetSpecialValueInt('value')"]),
            [("Foo", "hero_foo", 2)])

    def test_a_talent_handle_read_belongs_to_the_other_axis(self):
        # Double-booking GH #228's sites here would inflate this axis by 21.
        self.assertEqual(
            C.scan_file("<t>", ["local T = bot:GetAbilityByName('special_bonus_unique_x')",
                                "local n = T:GetSpecialValueInt('value')"]),
            [])

    def test_an_unbound_variable_is_not_a_site(self):
        self.assertEqual(
            C.scan_file("<t>", ["local n = Foo:GetSpecialValueInt('value')"]), [])

    def test_another_key_is_not_a_site(self):
        self.assertEqual(
            C.scan_file("<t>", ["local Foo = bot:GetAbilityByName('hero_foo')",
                                "local n = Foo:GetSpecialValueInt('radius')"]),
            [])

    def test_float_and_int_reads_are_both_sites(self):
        self.assertEqual(
            len(C.scan_file("<t>", ["local Foo = bot:GetAbilityByName('hero_foo')",
                                    "local n = Foo:GetSpecialValueInt('value')",
                                    "local m = Foo:GetSpecialValueFloat('value')"])),
            2)

    def test_a_variable_bound_twice_is_unresolved_rather_than_guessed(self):
        self.assertEqual(
            C.scan_file("<t>", ["local Foo = bot:GetAbilityByName('hero_foo')",
                                "local Foo = bot:GetAbilityByName('hero_bar')",
                                "local n = Foo:GetSpecialValueInt('value')"]),
            [("Foo", None, 3)])

    def test_a_commented_out_read_is_not_a_site(self):
        # This change put a paragraph of prose quoting the scanned idiom above
        # every one of the eight sites, so the stripper is load-bearing in the
        # direction of over-counting now, not just under-counting.
        self.assertEqual(
            C.scan_file("<t>", C.strip_comments(
                "local Foo = bot:GetAbilityByName('hero_foo')\n"
                "-- local n = Foo:GetSpecialValueInt('value')\n")),
            [])

    def test_a_live_read_after_a_comment_on_the_same_line_survives(self):
        self.assertEqual(
            C.scan_file("<t>", C.strip_comments(
                "local Foo = bot:GetAbilityByName('hero_foo')\n"
                "local n = Foo:GetSpecialValueInt('value') -- see GH #228\n")),
            [("Foo", "hero_foo", 2)])


class Ordinal(unittest.TestCase):
    def test_repeated_reads_of_one_variable_are_numbered(self):
        self.assertEqual(
            C.numbered([("Foo", "a", 3), ("Bar", "b", 4), ("Foo", "a", 9)]),
            [("Foo", "a", 3, 1), ("Bar", "b", 4, 1), ("Foo", "a", 9, 2)])

    def test_the_two_malefice_rows_carry_different_dispositions(self):
        # If this ever collapses to one entry, the census can no longer tell
        # "missing base key" from "already-folded talent term" -- and it would
        # print one repair instruction for both.
        first = C.SIGN[("bots/BotLib/hero_enigma.lua", "Malefice", 1)]
        second = C.SIGN[("bots/BotLib/hero_enigma.lua", "Malefice", 2)]
        self.assertEqual(first[0], "UNDER")
        self.assertEqual(second[0], "FOLD")
        self.assertEqual(second[2], None)   # FOLD's repair is deletion

    def test_no_sign_row_names_value_as_the_intended_key(self):
        for key, (_, _, want) in C.SIGN.items():
            self.assertNotEqual(want, "value", key)


class Classifier(unittest.TestCase):
    def rows(self, keys):
        return C.census(slots={"h": {0: "hero_foo"}},
                        kv={"h": {"hero_foo": keys}})

    def test_absent_value_entry_is_a_finding(self):
        # Driven through a real tree scan, so a scanner that found nothing would
        # make this vacuous -- hence the length assertion.
        rows = self.rows(["radius"])
        self.assertTrue(rows)
        self.assertTrue(all(r["verdict"] != "ANSWERS" for r in rows))

    def test_present_value_entry_is_not_a_finding(self):
        rows = C.census(slots={"h": {0: "enigma_black_hole"}},
                        kv={"h": {"enigma_black_hole": ["value", "radius"]}})
        hit = [r for r in rows if r["ability"] == "enigma_black_hole"]
        self.assertTrue(hit)
        self.assertTrue(all(r["verdict"] == "ANSWERS" for r in hit))
        self.assertEqual(C.findings(hit), [])

    def test_an_unknown_hero_is_no_kv_not_a_silent_pass(self):
        rows = C.census(slots={}, kv={})
        self.assertTrue(rows)
        self.assertTrue(all(r["verdict"] == "NO-KV" for r in rows))
        self.assertEqual(len(C.findings(rows)), len(rows))


class Snapshot(unittest.TestCase):
    def test_committed_snapshot_declares_its_generator_on_the_first_line(self):
        # GH #223's M8: an assertion that merely requires the name to appear
        # SOMEWHERE is near-vacuous in a self-describing file -- this header
        # names the script twice.  Pin the first line verbatim.
        path = os.path.join(REPO, "tests", "mock", "ability_value_reads.lua")
        with open(path, encoding="utf-8") as fh:
            first = fh.readline().rstrip("\n")
        self.assertEqual(first, C.snapshot_header()[0])
        self.assertIn("ability_value_key_census.py", first)


class SelfTest(unittest.TestCase):
    def test_tool_self_test_passes(self):
        self.assertEqual(C.self_test(), 0)


if __name__ == "__main__":
    unittest.main(verbosity=0)
