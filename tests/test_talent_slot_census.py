#!/usr/bin/env python3
"""Ratchets for the talent slot-map half of tools/agent/talent_slot_census.py.

WHAT THE TOOL IS FOR.  `sTalentList[N]` is "the Nth `IsTalent()` handle
`J.Skill.GetTalentList` walked past in slot order" -- it `table.insert`s, so an
index is a POSITION IN A COMPACTED LIST, never a slot number.  Focus hero files
bind `talentN = bot:GetAbilityByName( sTalentList[N] )` and then read the handle
as if it were one specific talent, so what N names is a correctness property of
those files (GH #166 found Lion's `talent8` naming the OTHER half of its t25
row).

⭐ WHY THE SOURCE CHANGED, AND WHY THAT IS THE POINT (GH #214).  Until
2026-08-26 the row order came from odota `dotaconstants`' `talents[]`, which is
a DISPLAY list.  Measured the same day: Valve's own datafeed agreed with the
game's `npc_heroes.txt` run on 22 of 22 heroes read (176 rows) and odota
disagreed with both on 18 of them -- including Wraith King's slot 4, where odota
still says `special_bonus_hp_350` and the game says `special_bonus_hp_300`.
That stale row had been copied into the repo on 2026-08-24 as a "correction",
recorded as "odota + the hero KV read hp_350" -- but `npc_dota_hero_*.txt`
carries AbilityValues override keys and no talent NAMES at all, so the second
source could not have said anything.  ⇒ Before writing "two sources agree",
check that the second one is capable of disagreeing.

⭐ THE HAZARD THIS FILE MOSTLY GUARDS: THE RUN DOES NOT START AT Ability10.  It
does for 123 of 127 heroes, which is exactly enough to make hardcoding 10 look
right.  kez and rubick start at Ability12, largo at Ability15 and invoker at
Ability17 -- they carry real abilities in the slots below.  The first draft of
the parser hardcoded 10 and reported invoker's talents as `invoker_emp`,
`invoker_alacrity`, ... -- eight plausible-looking ability names, no error.

The parser also inherits the two npc_heroes.txt hazards
tests/test_hero_slot_map.py documents: dedented hero HEADERS (fields are still
at two tabs) and a nested ability-draft block repeating Ability1..4 one level
deeper.  Both are covered below because this module owns its own copy of the
depth rule.

WHAT IS NOT TESTED HERE: the network, and which mirror is right.  The fixtures
are hand-written KV snippets.  `--cross-check` is what asks the live sources,
and it exits 3 when Valve's datafeed disagrees with the KV run being snapshotted.
"""

import contextlib
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "tools", "agent"))

import talent_slot_census as T  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def hero(name, entries, dedent=False):
    """One hero block.  `entries` is [(N, value)] written at field depth."""
    head = '"npc_dota_hero_%s"' % name
    lines = [head if dedent else "\t" + head, "{" if dedent else "\t{"]
    for n, value in entries:
        lines.append('\t\t"Ability%d"\t\t"%s"' % (n, value))
    lines.append("}" if dedent else "\t}")
    return lines


# Eight talents starting where a normal hero's do.
NORMAL = [(1, "x_one"), (2, "x_two"), (3, "x_three"), (4, "generic_hidden"),
          (5, "generic_hidden"), (6, "x_ult"), (7, "x_innate")] + [
    (10 + i, "special_bonus_x_%d" % (i + 1)) for i in range(8)]

# The invoker shape: real abilities occupy slots the naive reader assumes are
# talents, so the run starts at Ability17.
SHIFTED = [(i, "y_ability_%d" % i) for i in range(1, 17)] + [
    (17 + i, "special_bonus_y_%d" % (i + 1)) for i in range(8)]

SAMPLE = "\n".join(
    ['"DOTAHeroes"', "{"]
    + hero("normal", NORMAL)
    + hero("shifted", SHIFTED)
    # dedented header, fields still at two tabs -- the slark shape
    + hero("dedented", [(1, "z_one")] + [(10 + i, "special_bonus_z_%d" % (i + 1))
                                         for i in range(8)], dedent=True)
    # a nested draft block that repeats the keys one level deeper
    + ["\t\"npc_dota_hero_drafty\"", "\t{",
       '\t\t"Ability1"\t\t"w_one"',
       '\t\t"AbilityDraft"', "\t\t{",
       '\t\t\t"Ability10"\t"special_bonus_NOT_A_SLOT"', "\t\t}"]
    + ['\t\t"Ability%d"\t\t"special_bonus_w_%d"' % (10 + i, i + 1)
       for i in range(8)]
    + ["\t}", "}", ""]
)


class TestParse(unittest.TestCase):

    def setUp(self):
        self.slots = T.parse_talent_slots(SAMPLE)

    def test_only_heroes_with_talents_are_returned(self):
        self.assertEqual(sorted(self.slots),
                         ["dedented", "drafty", "normal", "shifted"])

    def test_position_is_the_index_and_slot_is_kept_separately(self):
        """The tuple is (slot, name) and the LIST POSITION is what N means.
        Conflating the two is the whole bug class this module exists for."""
        rows = self.slots["normal"]
        self.assertEqual([s for s, _ in rows], list(range(9, 17)))
        self.assertEqual(rows[0], (9, "special_bonus_x_1"))
        self.assertEqual(rows[7], (16, "special_bonus_x_8"))

    def test_run_that_does_not_start_at_ability10_still_reads_as_1_to_8(self):
        """The invoker/kez/largo/rubick shape.  Hardcoding Ability10 here reads
        four heroes' ABILITIES as their talents and reports no error."""
        rows = self.slots["shifted"]
        self.assertEqual([n for _, n in rows],
                         ["special_bonus_y_%d" % i for i in range(1, 9)])
        self.assertEqual(rows[0][0], 16, "slot 16 is Ability17, 0-based")
        self.assertIsNone(T.contiguity_error(rows))

    def test_no_ability_name_leaks_into_the_talent_run(self):
        for name in (n for _, n in self.slots["shifted"]):
            self.assertTrue(name.startswith("special_bonus_"), name)

    def test_dedented_header_still_yields_a_talent_run(self):
        """The regression that made slark look like a hero without abilities;
        this module owns its own copy of the depth rule, so it needs its own
        copy of the test."""
        self.assertEqual(len(self.slots["dedented"]), 8)

    def test_nested_draft_block_is_not_a_talent(self):
        names = [n for _, n in self.slots["drafty"]]
        self.assertNotIn("special_bonus_NOT_A_SLOT", names)
        self.assertEqual(names, ["special_bonus_w_%d" % i for i in range(1, 9)])


class TestContiguity(unittest.TestCase):
    """A hero whose run is short or gapped cannot be read as sTalentList[1..8],
    and the caller has to refuse rather than renumber -- a gap moves every index
    after it and every talentN binding in that hero file with it."""

    def test_full_contiguous_run_is_accepted(self):
        rows = [(9 + i, "special_bonus_%d" % i) for i in range(8)]
        self.assertIsNone(T.contiguity_error(rows))

    def test_short_run_is_rejected(self):
        rows = [(9 + i, "special_bonus_%d" % i) for i in range(7)]
        self.assertIn("expected 8", T.contiguity_error(rows))

    def test_gapped_run_is_rejected(self):
        rows = [(9, "a"), (10, "b"), (12, "c"), (13, "d"),
                (14, "e"), (15, "f"), (16, "g"), (17, "h")]
        self.assertIn("not contiguous", T.contiguity_error(rows))

    def test_a_gap_is_not_silently_closed(self):
        """The failure mode being refused: eight names are present, so a
        length-only check passes while index 3 has silently become the talent
        that used to be index 4."""
        rows = [(9, "a"), (10, "b"), (12, "c"), (13, "d"),
                (14, "e"), (15, "f"), (16, "g"), (17, "h")]
        self.assertEqual(len(rows), T.TALENT_ROWS)
        self.assertIsNotNone(T.contiguity_error(rows))


class TestRefusals(unittest.TestCase):
    """Both entry points fail loudly rather than emit a thin result.  An empty
    or short parse reads exactly like "the game has no talents for this hero",
    which is never true and is the shape a layout change takes."""

    def test_a_thin_parse_is_refused_not_returned(self):
        with self.assertRaises(SystemExit) as cm:
            T.kv_talents(SAMPLE)          # four heroes, not a roster
        self.assertIn("upstream layout changed", str(cm.exception))

    def test_census_refuses_a_hero_whose_run_is_not_eight(self):
        short = "\n".join(
            ['"DOTAHeroes"', "{"]
            + [line for h in T.FOCUS_FIVE
               for line in hero(h, [(10 + i, "special_bonus_%s_%d" % (h, i + 1))
                                    for i in range(7)])]
            # pad the roster so kv_talents' own threshold is not what fires
            + [line for i in range(120)
               for line in hero("filler%d" % i,
                                [(10 + j, "special_bonus_f%d_%d" % (i, j)) for j in range(8)])]
            + ["}", ""])
        with self.assertRaises(SystemExit) as cm:
            T.census(short)
        self.assertIn("expected 8", str(cm.exception))


class TestCrossCheckVerdict(unittest.TestCase):
    """The adjudicator's exit code.  odota being stale is a note; Valve's feed
    disagreeing with the KV run means the SNAPSHOT SOURCE is wrong, and a
    regeneration must not be treated as routine."""

    KV = ["special_bonus_a", "special_bonus_b"]

    def test_odota_drift_alone_is_not_a_failure(self):
        rows = [("h", self.KV, ["special_bonus_a", "special_bonus_STALE"], self.KV)]
        self.assertEqual(T.print_cross_check(rows), 0)

    def test_feed_disagreeing_with_the_kv_run_fails(self):
        rows = [("h", self.KV, self.KV, ["special_bonus_a", "special_bonus_OTHER"])]
        self.assertEqual(T.print_cross_check(rows), 3)

    def test_an_unavailable_feed_is_not_printed_as_the_kv_value(self):
        """The exit code alone cannot see this one.  A missing adjudicator that
        gets backfilled with the KV run prints a table in which all three
        columns agree -- which is the exact claim the reader is here to check.
        Measured: a mutation doing that escaped an exit-code-only assertion."""
        rows = [("h", self.KV, ["special_bonus_a", "special_bonus_STALE"], None)]
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(T.print_cross_check(rows), 0)
        text = out.getvalue()
        self.assertIn("feed=unavailable", text)
        self.assertIn("feed=<none>", text)
        self.assertNotIn("feed=special_bonus_b", text)


class TestCensusOrder(unittest.TestCase):
    """census() must hand back the KV run in KV order.  The per-hero KV fetch is
    stubbed: what is under test is the join, not the network."""

    def test_rows_come_back_in_slot_order_starting_at_one(self):
        roster = "\n".join(
            ['"DOTAHeroes"', "{"]
            + [line for h in T.FOCUS_FIVE
               for line in hero(h, [(10 + i, "special_bonus_%s_%d" % (h, i + 1))
                                    for i in range(8)])]
            + [line for i in range(120)
               for line in hero("filler%d" % i,
                                [(10 + j, "special_bonus_f%d_%d" % (i, j)) for j in range(8)])]
            + ["}", ""])
        real_get = T.get
        T.get = lambda url: ""          # no talent overrides in any hero KV
        try:
            data = T.census(roster)
        finally:
            T.get = real_get
        for h in T.FOCUS_FIVE:
            self.assertEqual([(i, n) for i, n, _ in data[h]],
                             [(i, "special_bonus_%s_%d" % (h, i)) for i in range(1, 9)])


class TestSnapshotAgreesWithTheTool(unittest.TestCase):
    """The generated Lua table is checked against the record in
    tests/test_focus_talent_anchor.lua by that file's section 5.  What is
    checked HERE is the half a Lua test cannot see: that the snapshot on disk
    still has the shape this generator writes."""

    def setUp(self):
        path = os.path.join(REPO, T.SNAPSHOT)
        with open(path, encoding="utf-8") as fh:
            self.src = fh.read()

    def test_every_focus_hero_is_present_with_eight_rows(self):
        for name in T.FOCUS_FIVE:
            self.assertIn("['%s'] = {" % name, self.src)
        self.assertEqual(self.src.count("[8] = { name = "), len(T.FOCUS_FIVE))

    def test_the_header_names_its_source(self):
        """A generated file that does not say where it came from is how the
        odota row survived two days of being read as authoritative.

        Both halves are asserted on purpose.  Checking only the committed .lua
        lets a generator that STOPS naming its source ride until the next
        patch -- measured: that mutation escaped the first cut of this file."""
        self.assertIn("npc_heroes.txt", self.src)
        self.assertIn("npc_heroes.txt", "\n".join(T.snapshot_header()))

    def test_the_stale_wraith_king_row_is_gone(self):
        """GH #214.  Named explicitly rather than left to the generic check:
        this is the row that was wrong, and a re-run of the OLD source would
        put it straight back."""
        self.assertNotIn("special_bonus_hp_350", self.src)
        self.assertIn("special_bonus_hp_300", self.src)


if __name__ == "__main__":
    unittest.main()
