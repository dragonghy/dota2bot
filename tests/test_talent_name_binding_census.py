#!/usr/bin/env python3
"""Ratchets for tools/agent/talent_name_binding_census.py (GH #223).

WHAT THE TOOL IS FOR.  Seven of the eight places this tree binds a talent by
LITERAL NAME call a method on the handle immediately, and
`bot:GetAbilityByName` answers **nil** for a talent the hero does not carry.
`nil:IsTrained()` reaches the engine error handler that masks its own text
(AGENTS.md), so Think() stops part-way through the frame and nothing is logged.
The census is the count of which of those eight names the game still gives the
hero, read out of npc_heroes.txt -- the source GH #214 moved the talent census
to after odota's display list was measured a patch behind.

WHAT IS TESTED HERE: the parser, the guard judge, the verdict, and the
generator's own provenance block.  The fixtures are hand-written; nothing here
touches the network, and nothing here decides which mirror is right -- the tool
does that against the live KV, and it exits 3 when a name is gone AND its call
is unguarded.

⭐ WHY THE GENERATOR'S HEADER IS ASSERTED AND NOT JUST THE SNAPSHOT'S.  GH #214
found this escape hatch the hard way: an assertion that reads the committed
.lua only ever sees the generator's OUTPUT, so a generator that quietly stops
declaring where its data came from rides to the next patch unnoticed.  The
header is therefore returned by a function, and the function is what is
compared against the committed file.

⭐ WHY THE COMMENT STRIPPER HAS ITS OWN SECTION.  The tree really contains the
adversarial case: hero_doom_bringer.lua carries a commented-out copy of the
bearing call site a few dozen lines above the live one.  A scanner that reads
prose reports a call that cannot run -- the mirror image of GH #136's first
buy-list census, which counted a quoted item name in a rationale block as a
purchase.  Both directions are driven below.
"""

import os
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import talent_name_binding_census as C  # noqa: E402


def lines(*text):
    return C.strip_comments("\n".join(text))


class StripComments(unittest.TestCase):
    def test_line_comment_is_blanked_but_the_line_survives(self):
        out = lines("live = 1", "-- dead = 2", "live = 3")
        self.assertEqual(len(out), 3)
        self.assertNotIn("dead", out[1])
        self.assertIn("live", out[2])

    def test_trailing_comment_keeps_the_code_before_it(self):
        out = lines("local x = 1 -- why")
        self.assertIn("local x = 1", out[0])
        self.assertNotIn("why", out[0])

    def test_block_comment_spanning_lines(self):
        out = lines("a = 1", "--[[ start", "hidden = 2", "end ]] b = 3")
        self.assertEqual(len(out), 4)
        self.assertNotIn("hidden", out[2])
        self.assertIn("b = 3", out[3])

    def test_inline_block_comment_keeps_both_sides(self):
        out = lines("local c = 1 --[[ mid ]] + 2")
        self.assertIn("local c = 1", out[0])
        self.assertIn("+ 2", out[0])
        self.assertNotIn("mid", out[0])

    def test_unterminated_block_swallows_the_rest(self):
        out = lines("a = 1", "--[[ never closed", "b = 2", "c = 3")
        self.assertNotIn("b = 2", out[2])
        self.assertNotIn("c = 3", out[3])

    def test_column_positions_are_preserved_for_a_closed_inline_block(self):
        # Line numbers are what a reader opens; columns are what a future
        # position-based matcher would trust.  Both are cheap to keep.
        src = "xx--[[y]]zz"
        self.assertEqual(len(C.strip_comments(src)[0]), len(src))


class FindBindings(unittest.TestCase):
    def scan(self, *text):
        return C.scan_file("<memory>", lines(*text))

    def test_local_form(self):
        got = self.scan("local Foo = bot:GetAbilityByName('special_bonus_x')")
        self.assertEqual([(r[0], r[1]) for r in got], [("Foo", "special_bonus_x")])

    def test_bare_assignment_form(self):
        # silencer binds inside a function, to a local declared earlier.
        got = self.scan("\ttalent20Left = bot:GetAbilityByName('special_bonus_y')")
        self.assertEqual([(r[0], r[1]) for r in got], [("talent20Left", "special_bonus_y")])

    def test_double_quotes_and_inner_spacing(self):
        got = self.scan('local G = bot:GetAbilityByName( "special_bonus_z" )')
        self.assertEqual([(r[0], r[1]) for r in got], [("G", "special_bonus_z")])

    def test_index_form_is_not_a_literal_binding(self):
        # `sTalentList[N]` is the OTHER half of the axis (GH #166 / #214).  It
        # cannot be nil-by-rename, so counting it here would bury the one
        # failure mode this census exists for under seven irrelevant rows.
        self.assertEqual(self.scan("local t = bot:GetAbilityByName( sTalentList[7] )"), [])

    def test_non_talent_ability_names_are_ignored(self):
        self.assertEqual(self.scan("local D = bot:GetAbilityByName('doom_bringer_devour')"), [])

    def test_commented_binding_is_not_counted(self):
        self.assertEqual(self.scan("-- local F = bot:GetAbilityByName('special_bonus_x')"), [])

    def test_calls_are_found_and_the_commented_copy_is_not(self):
        got = self.scan(
            "local Foo = bot:GetAbilityByName('special_bonus_x')",
            "--     and Foo:IsTrained()",
            "    and Foo:IsTrained()")
        self.assertEqual([c[0] for c in got[0][3]], [3])

    def test_a_longer_variable_name_is_not_mistaken_for_this_one(self):
        got = self.scan(
            "local Foo = bot:GetAbilityByName('special_bonus_x')",
            "local n = FooBar:GetLevel()",
            "local m = Foo:GetLevel()")
        self.assertEqual([c[0] for c in got[0][3]], [3])


class GuardJudge(unittest.TestCase):
    def judge(self, *text):
        got = C.strip_comments("\n".join(text))
        return C.guarded(got, len(got) - 1, "Foo")

    def test_same_line_nil_test(self):
        self.assertTrue(self.judge("return Foo ~= nil and Foo:IsTrained()"))

    def test_same_line_truthiness_test(self):
        self.assertTrue(self.judge("local b = Foo and Foo:IsTrained()"))

    def test_continuation_of_the_condition_started_on_the_line_above(self):
        self.assertTrue(self.judge("if Foo ~= nil", "then local n = Foo:GetLevel() end"))

    def test_bare_call_is_unguarded(self):
        self.assertFalse(self.judge("and Foo:IsTrained()"))

    def test_guard_two_lines_up_is_reported_unguarded(self):
        # Conservative on purpose, and said out loud rather than papered over:
        # the judge may over-report (visible, arguable) but must never go
        # silent on a real unguarded call.
        self.assertFalse(self.judge("if Foo ~= nil", "and bar", "and Foo:IsTrained()"))

    def test_a_test_that_ran_does_not_guard_the_next_statement(self):
        # The defect the first draft shipped: looking one line up
        # unconditionally laundered a completed expression into a guard.
        self.assertFalse(self.judge("local a = Foo ~= nil and Foo:IsTrained()",
                                    "local b = Foo:GetLevel()"))

    def test_a_closed_if_block_does_not_guard_the_next_statement(self):
        self.assertFalse(self.judge("if Foo ~= nil then bar() end",
                                    "local n = Foo:GetLevel()"))

    def test_an_early_return_guard_is_over_reported_not_under_reported(self):
        # Really safe in Lua; the judge refuses it anyway, because telling it
        # apart from the closed block above needs flow analysis this does not
        # do.  Recorded so the over-report is a decision, not a surprise.
        self.assertFalse(self.judge("if not Foo then return end",
                                    "local n = Foo:GetLevel()"))

    def test_a_guard_through_an_intermediate_boolean_is_over_reported(self):
        # hero_silencer.lua:747-748's real shape.  An `if` OPENS a condition
        # rather than continuing the line above, so it must carry its own test.
        self.assertFalse(self.judge(
            "local b = Foo ~= nil and Foo:IsTrained()",
            "if b then n = Foo:GetSpecialValueInt('value') end"))

    def test_a_nil_test_of_another_variable_is_not_a_guard(self):
        self.assertFalse(self.judge("if FooBar ~= nil then Foo:IsTrained() end"))


class Verdict(unittest.TestCase):
    NAMES = {"doom_bringer": ["special_bonus_unique_doom_%d" % i for i in range(1, 9)]}

    def row(self, talent, body):
        got = C.scan_file("<memory>", lines(
            "local Foo = bot:GetAbilityByName('%s')" % talent, body))
        var, name, bind, calls = got[0]
        return {"file": "f", "hero": "doom_bringer", "var": var, "talent": name,
                "bind_line": bind, "present": name in self.NAMES["doom_bringer"],
                "slot": 0, "mods": [], "calls": calls}

    def test_absent_and_unguarded_is_a_crash(self):
        row = self.row("special_bonus_unique_doom_99", "and Foo:IsTrained()")
        self.assertFalse(row["present"])
        self.assertEqual(len(C.crashers([row])), 1)

    def test_absent_but_guarded_is_not_a_crash(self):
        row = self.row("special_bonus_unique_doom_99",
                       "return Foo ~= nil and Foo:IsTrained()")
        self.assertFalse(row["present"])
        self.assertEqual(C.crashers([row]), [])

    def test_present_and_unguarded_is_not_a_crash_today(self):
        # It is the same latent shape, and it is recorded -- but the handle
        # exists, so calling it a crash would make the verdict mean something
        # weaker than "this one is broken right now".
        row = self.row("special_bonus_unique_doom_2", "and Foo:IsTrained()")
        self.assertTrue(row["present"])
        self.assertEqual(C.crashers([row]), [])

    def test_one_guarded_call_does_not_excuse_an_unguarded_sibling(self):
        got = C.scan_file("<memory>", lines(
            "local Foo = bot:GetAbilityByName('special_bonus_unique_doom_99')",
            "local a = Foo ~= nil and Foo:IsTrained()",
            "local b = Foo:GetLevel()"))
        var, name, bind, calls = got[0]
        row = {"file": "f", "hero": "doom_bringer", "var": var, "talent": name,
               "bind_line": bind, "present": False, "slot": 0, "mods": [],
               "calls": calls}
        self.assertEqual(len(C.crashers([row])), 1)

    def test_an_unknown_hero_fails_loudly_instead_of_being_skipped(self):
        # A file stem that stops mapping to a unit name would otherwise make
        # every site in that file silently unjudged -- the failure mode the
        # whole census exists to remove, reintroduced by its own plumbing.
        with self.assertRaises(SystemExit):
            C.census(root=REPO, names={"nobody": []})


class HeroOf(unittest.TestCase):
    def test_botlib_hero_file(self):
        self.assertEqual(C.hero_of("bots/BotLib/hero_doom_bringer.lua"), "doom_bringer")

    def test_rubick_copy(self):
        self.assertEqual(C.hero_of("bots/FunLib/rubick_hero/alchemist.lua"), "alchemist")

    def test_non_hero_file(self):
        self.assertIsNone(C.hero_of("bots/FunLib/jmz_func.lua"))


class Snapshot(unittest.TestCase):
    PATH = os.path.join(REPO, C.SNAPSHOT)

    def test_the_committed_snapshot_starts_with_the_generator_s_own_header(self):
        with open(self.PATH, "r", encoding="utf-8") as fh:
            head = fh.read().splitlines()[:len(C.snapshot_header())]
        self.assertEqual(head, C.snapshot_header(),
                         "the snapshot's provenance block and the generator's "
                         "have drifted -- re-run --snapshot")

    def test_the_snapshot_matches_a_fresh_scan_of_the_tree(self):
        # Offline half of the Lua anchor's section 2: no network needed to ask
        # whether the FILE/VAR/TALENT triples still exist where recorded.
        # Whether the game still has the name is the tool's job, not this one's.
        got = set()
        for path in C.hero_files(REPO):
            hero = C.hero_of(path)
            if hero is None:
                continue
            for var, talent, _, _ in C.scan_file(path):
                got.add((os.path.relpath(path, REPO), var, talent))
        with open(self.PATH, "r", encoding="utf-8") as fh:
            text = fh.read()
        recorded = set()
        import re
        for block in re.finditer(
                r"file = '([^']+)',\s*hero = '[^']+',\s*var = '([^']+)',"
                r"\s*talent = '([^']+)',", text):
            recorded.add(block.groups())
        self.assertEqual(got, recorded,
                         "tree and snapshot disagree -- re-run "
                         "`python3 %s --snapshot`" % C.__file__)

    def test_the_snapshot_still_records_at_least_one_absent_name(self):
        with open(self.PATH, "r", encoding="utf-8") as fh:
            self.assertIn("present = false,", fh.read(),
                          "no site is ABSENT any more, so the Lua anchor's "
                          "guard section has nothing to assert -- confirm with "
                          "the census before treating a green run as news")


if __name__ == "__main__":
    unittest.main(verbosity=1)
