#!/usr/bin/env python3
"""Ratchets for the hero slot-map generator (tools/agent/hero_slot_map.py).

WHAT THE TOOL IS FOR.  `sAbilityList[N]` is "the Nth ability
`J.Skill.GetAbilityList` accepted while walking slots 0..10", so every index
argument in this repo starts from a hero's SLOT ORDER.  GH #203 and #206 both
had to take that order from the Dota 2 datafeed and declare it an assumption --
the feed publishes a display list, not slot indices.  `npc_heroes.txt` publishes
the indices, so the tool reads them and tests/test_hero_slot_order_anchor.lua
checks the two candidates against the result.

⭐ WHY THIS FILE IS MOSTLY ABOUT THE PARSER AND NOT THE DATA.  Every hazard here
cost a wrong reading before it was caught, and all of them are silent -- a
mis-parsed hero comes back as a hero with NO abilities, which reads exactly like
a hero the KV does not describe:

  * THE HEADERS ARE NOT UNIFORMLY INDENTED.  A few hero blocks (slark,
    earth_spirit) start at column 0 while the rest start at one tab -- but every
    hero's FIELDS sit at two tabs either way.  The first cut of the tool
    measured field depth RELATIVE TO EACH HEADER, which reads slark's real
    Ability1..6 as too shallow and hands back an empty map.  The census caught
    it only because it refuses to emit an empty map; without that refusal slark
    would have been reported as a hero with no abilities.
  * THE SAME KEYS APPEAR AGAIN ONE LEVEL DEEPER WITH A DIFFERENT MEANING.  Each
    hero repeats "Ability1".."Ability4" at three tabs inside a nested block, and
    those are the four LEARNABLE abilities, not the slots: for Axe that block
    reads culling_blade at Ability4, while the real slot 3 is a
    `generic_hidden` placeholder and the ultimate is at slot 5.  Read the nested
    block as slots and half the roster's index arguments silently move.
  * PLACEHOLDERS ARE DATA.  Empty slots hold the literal name `generic_hidden`
    and the walk KEEPS them (`if slot ~= 0`).  Dropping them while rendering
    would shift every index after them -- and would also destroy the reason
    `X.GetAbilityList` can hardcode `slot >= 4` at all.

WHAT IS NOT TESTED HERE: the network.  The fixtures below are hand-written KV
snippets, so this file never fetches; the live read is exercised by running the
tool.  Nor does anything here claim which abilities the walk KEEPS -- that turns
on `IsHidden()`, unreadable outside the game VM.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "tools", "agent"))

import hero_slot_map as H  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# A miniature npc_heroes.txt carrying all three hazards at once: a normally
# indented hero, a DEDENTED hero, a nested ability-draft block with conflicting
# Ability1..4, placeholders, an empty entry and a talent row past the walk's
# reach.  Tabs are explicit because tabs are the whole discriminator.
SAMPLE = "\n".join([
    '"DOTAHeroes"',
    '{',
    '\t"npc_dota_hero_axelike"',
    '\t{',
    '\t\t"Ability1"\t\t"axelike_call"',
    '\t\t"Ability2"\t\t"axelike_hunger"',
    '\t\t"Ability3"\t\t"axelike_helix"',
    '\t\t"Ability4"\t\t"generic_hidden"',
    '\t\t"Ability5"\t\t"generic_hidden"',
    '\t\t"Ability6"\t\t"axelike_culling"',
    '\t\t"Ability7"\t\t"axelike_innate"',
    '\t\t"Ability8"\t\t""',
    '\t\t"AbilityDraft"',
    '\t\t{',
    '\t\t\t"Ability1"\t"axelike_call"',
    '\t\t\t"Ability2"\t"axelike_hunger"',
    '\t\t\t"Ability3"\t"axelike_helix"',
    '\t\t\t"Ability4"\t"axelike_culling"',
    '\t\t}',
    '\t\t"Ability12"\t\t"special_bonus_way_past_the_walk"',
    '\t}',
    # dedented header, fields still at two tabs -- the slark shape
    '"npc_dota_hero_dedented"',
    '{',
    '\t\t"Ability1"\t\t"dedented_one"',
    '\t\t"Ability6"\t\t"dedented_ult"',
    '}',
    '}',
    "",
])


class TestParse(unittest.TestCase):

    def setUp(self):
        self.slots = H.parse(SAMPLE)

    def test_both_heroes_parse(self):
        self.assertEqual(sorted(self.slots), ["axelike", "dedented"])

    def test_keys_are_zero_based_engine_slots(self):
        """Ability1 is slot 0.  An off-by-one here moves every index argument
        in the repo by one and nothing else would notice."""
        self.assertEqual(self.slots["axelike"][0], "axelike_call")
        self.assertEqual(self.slots["axelike"][5], "axelike_culling")
        self.assertEqual(self.slots["axelike"][6], "axelike_innate")

    def test_dedented_header_still_yields_a_slot_map(self):
        """The regression that made slark look like a hero without abilities."""
        self.assertEqual(self.slots["dedented"],
                         {0: "dedented_one", 5: "dedented_ult"})
        self.assertNotEqual(self.slots["dedented"], {},
                            "an empty map is a parse hole, never a hero")

    def test_nested_draft_block_does_not_overwrite_slots(self):
        """The draft block says Ability4 = culling; the SLOT map says slot 3 is
        a placeholder.  Reading the nested block would put the ultimate at slot
        3, where `IsUltimate() and slot >= 4` fails and index 6 is never
        written -- i.e. abilityR bound to nil for every such hero."""
        self.assertEqual(self.slots["axelike"][3], "generic_hidden")
        self.assertNotEqual(self.slots["axelike"][3], "axelike_culling")

    def test_placeholders_and_empties_survive_verbatim(self):
        self.assertEqual(self.slots["axelike"][4], "generic_hidden")
        self.assertEqual(self.slots["axelike"][7], "",
                         "an empty AbilityN is an occupied slot, not a missing key")

    def test_keys_past_the_walk_are_not_collected(self):
        """The walk stops at slot 10, so Ability12 can never reach an index."""
        self.assertNotIn(11, self.slots["axelike"])
        self.assertLess(max(self.slots["axelike"]), H.MAX_ABILITY)


class TestRender(unittest.TestCase):

    def test_render_emits_explicit_slot_keys(self):
        out = H.render(H.parse(SAMPLE), ["axelike"])
        self.assertIn("['axelike']", out)
        self.assertIn("[0]='axelike_call'", out)
        self.assertIn("[3]='generic_hidden'", out,
                      "placeholders must render; dropping one shifts every later index")
        self.assertIn("[7]=''", out)
        self.assertNotIn("dedented", out, "only requested heroes are emitted")

    def test_render_is_a_lua_table_with_a_header(self):
        out = H.render(H.parse(SAMPLE), ["axelike"])
        self.assertTrue(out.startswith("-- GENERATED by"))
        self.assertIn("do not hand-edit", out)
        self.assertTrue(out.rstrip().endswith("}"))


class TestCheckedInArtifact(unittest.TestCase):
    """The committed table is what the Lua ratchet reads, so its shape is
    checked here rather than only inside Lua."""

    def setUp(self):
        self.path = os.path.join(REPO, H.OUT)

    def test_the_generated_table_is_committed(self):
        self.assertTrue(os.path.exists(self.path),
                        H.OUT + " is missing; run tools/agent/hero_slot_map.py")

    def test_every_shipped_hero_has_a_row_and_no_row_is_empty(self):
        text = open(self.path, encoding="utf-8").read()
        for hero in H.bot_heroes():
            if hero in H.NOT_A_HERO:
                continue
            marker = "['%s'] = {" % hero
            self.assertIn(marker, text, "no slot row for shipped hero " + hero)
            row = text.split(marker, 1)[1].split("}", 1)[0]
            self.assertIn("[0]=", row,
                          hero + " has no slot 0 -- that is a parse hole, not a "
                          "hero without abilities")

    def test_the_focus_five_rows_say_what_the_candidates_rest_on(self):
        """The two rows GH #203 and #206 quote, spot-checked at the slots that
        actually decide their candidates."""
        text = open(self.path, encoding="utf-8").read()
        zuus = text.split("['zuus'] = {", 1)[1].split("}", 1)[0]
        self.assertIn("[3]='zuus_cloud'", zuus)
        self.assertIn("[4]='zuus_lightning_hands'", zuus)
        self.assertIn("[6]='zuus_static_field'", zuus)
        cm = text.split("['crystal_maiden'] = {", 1)[1].split("}", 1)[0]
        self.assertIn("[3]='crystal_maiden_crystal_clone'", cm)
        self.assertIn("[4]='crystal_maiden_glacial_guard'", cm)
        # Axe and Lion are the ones this round leaves UNGATED, and the reason is
        # in these two rows: nothing optional sits at a slot they bind.
        axe = text.split("['axe'] = {", 1)[1].split("}", 1)[0]
        self.assertIn("[3]='generic_hidden'", axe)
        self.assertIn("[5]='axe_culling_blade'", axe)
        lion = text.split("['lion'] = {", 1)[1].split("}", 1)[0]
        self.assertIn("[3]='lion_to_hell_and_back'", lion)
        self.assertIn("[5]='lion_finger_of_death'", lion)


if __name__ == "__main__":
    unittest.main()
