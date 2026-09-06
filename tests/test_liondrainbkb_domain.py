#!/usr/bin/env python3
"""Wrapper tests for tools/batch_test/behavioral/liondrainbkb_domain.py.

The scanner's own `--selfcheck` asserts its internals.  This file exists for
the two things a selfcheck cannot do: pin the reading that the 2026-09-06
replay-check round published (the `liondrainbkb` premise is FALSIFIED on real
frames), and pin it FROM THE NEGATIVE SIDE -- i.e. build the corpus shapes
that would have produced that headline WRONGLY, and require the scanner to
refuse them.

Three ways the headline could have been manufactured, one test each:
  1. a non-immunity modifier in IMMUNITY_MODIFIERS (the first pass counted
     `modifier_item_mask_of_madness_berserk`, which increases damage taken);
  2. an illusion of the target hero eating the real hero's frame (GH #176);
  3. the enemy popping BKB in reaction to the drain, read backwards as
     "the drain landed on an immune target".
Each is a live failure mode, not a hypothetical -- (1) and (2) both fired
during the round that wrote this file.
"""

import os
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL_DIR = os.path.join(HERE, "..", "tools", "batch_test", "behavioral")
sys.path.insert(0, TOOL_DIR)

import liondrainbkb_domain as L  # noqa: E402

LION = L.LION
SVEN = "npc_dota_hero_sven"
BKB = "modifier_black_king_bar_immune"


def snap(t, hero, idx, **kw):
    d = {"t": t, "hero": hero, "idx": idx, "x": 0, "y": 0, "hp": 500,
         "hp_pct": 1.0, "mp": 400, "max_mp": 500, "level": 6, "items": [],
         "abilities": []}
    d.update(kw)
    return d


def mod(t, kind, target, name, actor=None):
    return {"t": t, "type": kind, "actor": actor or target, "target": target,
            "inflictor": name, "target_hero": True, "actor_hero": True}


def timeline(events, snapshots=None):
    return {
        "game": {"teams": {LION: 2, SVEN: 3}},
        "snapshots": snapshots if snapshots is not None else [
            snap(0.0, LION, 1), snap(0.0, SVEN, 2)],
        "events": events,
    }


def drain(t_add, t_remove, target=SVEN):
    return [
        {"t": t_add, "type": "ABILITY", "actor": LION, "target": target,
         "inflictor": L.DRAIN_ABILITY, "target_hero": True, "actor_hero": True},
        mod(t_add, "MODIFIER_ADD", target, L.DRAIN_MOD, actor=LION),
        mod(t_remove, "MODIFIER_REMOVE", target, L.DRAIN_MOD, actor=LION),
    ]


class PremiseReading(unittest.TestCase):
    """The published headline, and the shapes that must NOT produce it."""

    def test_nested_channel_is_the_falsification(self):
        # BKB up at 10.0, drain runs 13.0-17.0, BKB down at 19.0: the whole
        # channel is inside the immunity window.  This is the corpus shape of
        # b34547__20260905_004847_slot1 t=1266.4 (channel 5.1s, BKB [1266.1,
        # 1274.1]) and it is what "premise falsified" means.
        tl = timeline([mod(10.0, "MODIFIER_ADD", SVEN, BKB)]
                      + drain(13.0, 17.0)
                      + [mod(19.0, "MODIFIER_REMOVE", SVEN, BKB)])
        row = L.scan_game(tl, "g")["add_rows"][0]
        self.assertTrue(row["nested_in_immunity"])
        self.assertEqual(row["immunity_lead_s"], 3.0)
        self.assertEqual(row["channel_s"], 4.0)

    def test_immunity_starting_after_the_drain_is_not_counted(self):
        # The enemy pops BKB one second INTO the channel.  That is a reaction
        # to the drain, not a cast onto an immune target; counting it would
        # invert the causal direction.
        tl = timeline(drain(13.0, 17.0)
                      + [mod(14.0, "MODIFIER_ADD", SVEN, BKB),
                         mod(22.0, "MODIFIER_REMOVE", SVEN, BKB)])
        row = L.scan_game(tl, "g")["add_rows"][0]
        self.assertEqual(row["immune_at_add"], [])
        self.assertFalse(row["nested_in_immunity"])

    def test_channel_outliving_the_immunity_is_not_nested(self):
        # BKB expires mid-channel: the drain was legal for part of its life,
        # so this is NOT the decisive shape and must not be reported as one.
        tl = timeline([mod(10.0, "MODIFIER_ADD", SVEN, BKB)]
                      + drain(13.0, 20.0)
                      + [mod(15.0, "MODIFIER_REMOVE", SVEN, BKB)])
        row = L.scan_game(tl, "g")["add_rows"][0]
        self.assertEqual(row["immune_at_add"], [BKB])   # still registered
        self.assertFalse(row["nested_in_immunity"])     # but not decisive

    def test_mask_of_madness_cannot_manufacture_a_hit(self):
        # The first pass of this scan counted 3 landings under Mask of Madness
        # berserk, a modifier that INCREASES damage taken and blocks nothing.
        # Readmitting it would have inflated the headline by ~19%.
        tl = timeline([mod(10.0, "MODIFIER_ADD", SVEN,
                           "modifier_item_mask_of_madness_berserk")]
                      + drain(13.0, 17.0))
        row = L.scan_game(tl, "g")["add_rows"][0]
        self.assertEqual(row["immune_at_add"], [])

    def test_guardian_angel_is_physical_immunity_only(self):
        tl = timeline([mod(10.0, "MODIFIER_ADD", SVEN,
                           "modifier_omniknight_guardian_angel")]
                      + drain(13.0, 17.0))
        self.assertEqual(L.scan_game(tl, "g")["add_rows"][0]["immune_at_add"], [])


class IllusionGuard(unittest.TestCase):
    """GH #176: the combat log is name-keyed, so illusions can eat a frame."""

    def test_later_born_entity_is_dropped_and_flagged(self):
        tl = timeline([mod(10.0, "MODIFIER_ADD", SVEN, BKB)] + drain(13.0, 17.0),
                      snapshots=[snap(0.0, LION, 1), snap(0.0, SVEN, 2),
                                 snap(5.0, SVEN, 77, hp=0, hp_pct=0.0, x=9000)])
        r = L.scan_game(tl, "g")
        self.assertEqual(r["illusion_samples_dropped"], 1)
        self.assertEqual(r["multi_entity_names"], 1)
        # a landing on a name that also has illusions is still measured, but
        # marked so the report can restrict to the conflation-proof subset
        self.assertFalse(r["add_rows"][0]["name_clean"])

    def test_single_entity_name_is_clean(self):
        tl = timeline([mod(10.0, "MODIFIER_ADD", SVEN, BKB)] + drain(13.0, 17.0))
        r = L.scan_game(tl, "g")
        self.assertEqual(r["illusion_samples_dropped"], 0)
        self.assertTrue(r["add_rows"][0]["name_clean"])


class CastSideBlindness(unittest.TestCase):
    """Section 4: why the request's column (4) cannot be bought."""

    def test_cast_with_no_modifier_is_reported_as_unlanded(self):
        # The scanner CAN see an ABILITY row with no modifier -- it just never
        # happens, because the engine writes no row for a refused order.  The
        # mechanism has to work, or the reported zero would be a dead branch
        # rather than a measurement.
        tl = timeline([{"t": 13.0, "type": "ABILITY", "actor": LION,
                        "target": SVEN, "inflictor": L.DRAIN_ABILITY,
                        "target_hero": True, "actor_hero": True}])
        r = L.scan_game(tl, "g")
        self.assertEqual(r["casts"], 1)
        self.assertEqual(r["adds"], 0)
        self.assertEqual(len(r["unlanded"]), 1)

    def test_same_tick_landing_is_not_unlanded(self):
        r = L.scan_game(timeline(drain(13.0, 17.0)), "g")
        self.assertEqual(r["casts"], 1)
        self.assertEqual(r["unlanded"], [])


class SelfcheckRuns(unittest.TestCase):
    def test_selfcheck_exits_clean(self):
        p = subprocess.run(
            [sys.executable, os.path.join(TOOL_DIR, "liondrainbkb_domain.py"),
             "--selfcheck"], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("0 FAIL", p.stdout)


if __name__ == "__main__":
    unittest.main()
