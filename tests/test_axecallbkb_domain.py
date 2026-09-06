#!/usr/bin/env python3
"""Reverse-nails for `axecallbkb_domain.py` (queue hero-30, replay-check).

Each test below refuses ONE shape this round's headline could have been
manufactured from.  They are written from the failure direction: the assertion
is that the scanner REJECTS the polluted input, not that it accepts the clean
one.  Run with `python3 -m unittest tests/test_axecallbkb_domain.py`
(this container has no pytest; `python3 -m pytest` answers
`No module named pytest`, which is a could-not-run, not a failure).
"""

import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tools", "batch_test", "behavioral"))

import axecallbkb_domain as A  # noqa: E402


CALL_READY = [{"name": A.CALL, "level": 2, "cd": 0, "cd_len": 16}]


def snap(t, hero, idx, x, y, hp=1000, mp=500, abils=None):
    return {"t": t, "hero": hero, "idx": idx, "x": x, "y": y, "hp": hp,
            "hp_pct": 1.0, "mp": mp, "max_mp": 800, "level": 10,
            "items": [], "abilities": abils if abils is not None else []}


def base_game(events=None, snaps=None):
    return {
        "game": {"start_time": 0.0,
                 "teams": {A.AXE: 2, "npc_dota_hero_lina": 3,
                           "npc_dota_hero_pudge": 3}},
        "events": list(events or []),
        "snapshots": list(snaps or [
            snap(100.0, A.AXE, 1, 0, 0, abils=CALL_READY),
            snap(100.0, "npc_dota_hero_lina", 2, 200, 0),
            snap(100.0, "npc_dota_hero_pudge", 3, 300, 0),
        ]),
    }


def mod(t, kind, actor, target, name):
    return {"t": t, "type": kind, "actor": actor, "target": target,
            "inflictor": name, "value": 0,
            "actor_hero": True, "target_hero": True}


class SpellImmunityListIsNotAGrabBag(unittest.TestCase):
    """The 2026-09-06 `liondrainbkb` pass manufactured 3 of its first 21
    'immune' landings out of modifiers that are not spell immunity at all."""

    def test_physical_and_damage_modifiers_are_not_spell_immunity(self):
        for name in ("modifier_item_mask_of_madness_berserk",
                     "modifier_omniknight_martyr",
                     "modifier_omniknight_guardian_angel",
                     "modifier_necrolyte_ghost_shroud_active",
                     "modifier_ghost_state"):
            self.assertNotIn(name, A.IMMUNITY_MODIFIERS, name)

    def test_a_ghost_shroud_target_is_not_reported_immune(self):
        tl = base_game([
            mod(99.0, "MODIFIER_ADD", "npc_dota_hero_lina",
                "npc_dota_hero_lina", "modifier_necrolyte_ghost_shroud_active"),
        ])
        g = A.scan_game(tl, "gs")
        rows = [r for r in g["rows_ii"] if r["radius"] == "r315"]
        self.assertEqual([r["immune"] for r in rows], [False])


class ChannelBelongsToTheCasterNotTheVictim(unittest.TestCase):
    """A Dismember marker lands on the VICTIM.  Keying the channel by
    `target` would report Axe's own team-mate -- or Axe -- as the enemy
    channeller, and the branch-(i) domain would be read off the wrong unit."""

    def test_victim_is_not_credited_with_the_channel(self):
        ev = [mod(99.0, "MODIFIER_ADD", "npc_dota_hero_pudge", A.AXE,
                  "modifier_pudge_dismember"),
              mod(105.0, "MODIFIER_REMOVE", "npc_dota_hero_pudge", A.AXE,
                  "modifier_pudge_dismember")]
        ch = A.build_channel_intervals(ev)
        self.assertIn("modifier_pudge_dismember",
                      A.active(ch, A.canon("npc_dota_hero_pudge"), 100.0))
        self.assertNotIn("modifier_pudge_dismember",
                         A.active(ch, A.canon(A.AXE), 100.0))


class AxeMustBeAbleToAct(unittest.TestCase):
    """The self-catch of 2026-09-06: a frame where Axe is being Dismembered
    (i.e. stunned) is not a frame the veto cost anything on.  Counting it
    books 'the veto lost us a cast' against a frame that could not cast."""

    def test_dismembered_axe_is_not_domain(self):
        tl = base_game([
            mod(99.0, "MODIFIER_ADD", "npc_dota_hero_pudge", A.AXE,
                "modifier_pudge_dismember"),
            mod(105.0, "MODIFIER_REMOVE", "npc_dota_hero_pudge", A.AXE,
                "modifier_pudge_dismember"),
        ])
        g = A.scan_game(tl, "stunned")
        self.assertEqual(g["rows_i"], [])
        self.assertEqual(g["rows_ii"], [])
        self.assertEqual(g["n_axe_ready"], 0)
        self.assertEqual(g["n_axe_blocked"], 1)

    def test_a_root_does_not_block_casting(self):
        """Roots stop movement, not spells.  Putting them in the block list
        would silently shrink the domain in the lever's own favour."""
        tl = base_game([
            mod(99.0, "MODIFIER_ADD", "npc_dota_hero_lina", A.AXE,
                "modifier_medusa_gorgon_grasp_root"),
        ])
        g = A.scan_game(tl, "rooted")
        self.assertEqual(g["n_axe_ready"], 1)
        for name in ("modifier_medusa_gorgon_grasp_root",
                     "modifier_spawnlord_master_freeze_root",
                     "modifier_dark_troll_warlord_ensnare"):
            self.assertNotIn(name, A.AXE_CANNOT_CAST, name)


class TheTwoBranchesAreNeverPooled(unittest.TestCase):
    """queue hero-30 pre-registration, and charter rule 4a: one aggregate may
    not be booked to two branches sharing one id."""

    def test_branches_are_separate_row_sets(self):
        tl = base_game([
            mod(99.0, "MODIFIER_ADD", "npc_dota_hero_lina",
                "npc_dota_hero_lina", "modifier_teleporting"),
            mod(103.0, "MODIFIER_REMOVE", "npc_dota_hero_lina",
                "npc_dota_hero_lina", "modifier_teleporting"),
        ])
        g = A.scan_game(tl, "both")
        self.assertTrue(g["rows_i"])
        self.assertTrue(g["rows_ii"])
        summ = A.summarise([g])["r315"]
        self.assertIn("branch_i", summ)
        self.assertIn("branch_ii", summ)
        self.assertNotEqual(summ["branch_i"]["instants"],
                            summ["branch_i"]["instants"]
                            + summ["branch_ii"]["target_instants"])

    def test_the_two_radii_are_separate_and_never_averaged(self):
        """Talent training is not in the dump, so 315 and 400 are two
        readings, not two samples of one."""
        g = A.scan_game(base_game(), "radii")
        r315 = [r["target"] for r in g["rows_ii"] if r["radius"] == "r315"]
        r400 = [r["target"] for r in g["rows_ii"] if r["radius"] == "r400"]
        self.assertEqual(r315, ["npc_dota_hero_lina"])
        self.assertEqual(sorted(r400),
                         ["npc_dota_hero_lina", "npc_dota_hero_pudge"])


class IllusionsAreNotTheHero(unittest.TestCase):
    """GH #176.  An illusion sharing the hero name and standing on top of Axe
    would fabricate an in-ring enemy at distance ~0."""

    def test_later_born_entity_is_discarded(self):
        snaps = [
            snap(50.0, A.AXE, 1, 0, 0, abils=CALL_READY),
            snap(50.0, "npc_dota_hero_lina", 2, 900, 0),
            snap(100.0, A.AXE, 1, 0, 0, abils=CALL_READY),
            snap(100.0, "npc_dota_hero_lina", 2, 900, 0),
            snap(100.0, "npc_dota_hero_lina", 77, 5, 0),
        ]
        g = A.scan_game(base_game(snaps=snaps), "illu")
        self.assertEqual(g["n_discarded_illusion_samples"], 1)
        self.assertEqual([r for r in g["rows_ii"] if r["radius"] == "r315"], [])


class ACastThatHappenedAnywayIsNotALostCast(unittest.TestCase):
    """Verified live on 20260830_004643_slot1 t=1056.5: a BKB'd, teleporting
    Dragon Knight that the shipped veto declines -- and the Call goes out
    0.8s later by another road, cancels the TP and the target dies."""

    def test_cast_near_marks_the_instant(self):
        tl = base_game([
            mod(99.0, "MODIFIER_ADD", "npc_dota_hero_lina",
                "npc_dota_hero_lina", "modifier_black_king_bar_immune"),
            mod(110.0, "MODIFIER_REMOVE", "npc_dota_hero_lina",
                "npc_dota_hero_lina", "modifier_black_king_bar_immune"),
            {"t": 100.8, "type": "ABILITY", "actor": A.AXE,
             "target": "dota_unknown", "inflictor": A.CALL,
             "actor_hero": True, "target_hero": False},
        ])
        g = A.scan_game(tl, "cast_anyway")
        rows = [r for r in g["rows_ii"] if r["radius"] == "r315"]
        self.assertEqual([r["cast_near"] for r in rows], [True])

    def test_a_far_away_cast_does_not_mark_it(self):
        tl = base_game([
            {"t": 140.0, "type": "ABILITY", "actor": A.AXE,
             "target": "dota_unknown", "inflictor": A.CALL,
             "actor_hero": True, "target_hero": False},
        ])
        g = A.scan_game(tl, "cast_far")
        rows = [r for r in g["rows_ii"] if r["radius"] == "r315"]
        self.assertEqual([r["cast_near"] for r in rows], [False])


class TheCommitmentProxyIsDirectional(unittest.TestCase):
    """`J.GetProperTarget` is bot:GetTarget()/GetAttackTarget().  An enemy who
    only hits Axe is not evidence that Axe targeted THEM."""

    def test_enemy_hitting_axe_is_not_axe_dealt(self):
        tl = base_game([
            {"t": 100.0, "type": "DAMAGE", "actor": "npc_dota_hero_lina",
             "target": A.AXE, "actor_hero": True, "target_hero": True},
        ])
        rows = [r for r in A.scan_game(tl, "rev")["rows_ii"]
                if r["radius"] == "r315"]
        self.assertTrue(rows[0]["committed"])
        self.assertFalse(rows[0]["axe_dealt"])

    def test_axe_hitting_enemy_is_axe_dealt(self):
        tl = base_game([
            {"t": 100.0, "type": "DAMAGE", "actor": A.AXE,
             "target": "npc_dota_hero_lina", "actor_hero": True,
             "target_hero": True},
        ])
        rows = [r for r in A.scan_game(tl, "fwd")["rows_ii"]
                if r["radius"] == "r315"]
        self.assertTrue(rows[0]["axe_dealt"])
        self.assertTrue(rows[0]["committed"])


class PredicateConstantsComeFromTheKvSnapshot(unittest.TestCase):
    def test_mana_and_radii(self):
        self.assertEqual(A.CALL_MANA, [90, 100, 110, 120])
        self.assertEqual(A.CALL_RADIUS_BASE, 315.0)
        self.assertEqual(A.CALL_RADIUS_TALENT, 400.0)
        self.assertEqual(A.INTERRUPT_MARGIN, 50.0)
        self.assertEqual(A.INITIATE_MARGIN, 90.0)

    def test_selfcheck_is_green(self):
        self.assertEqual(A.selfcheck(), 0)


if __name__ == "__main__":
    unittest.main()
