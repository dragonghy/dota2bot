"""Adversarial tests for tools/batch_test/behavioral/zusultstrand_domain.py.

These pin, FROM THE WRONG SIDE, the shapes in which this round's headline
(198/257 episodes end in a Zeus death, 192 of them with the ult still uncast)
could have been manufactured by the INSTRUMENT rather than found in the corpus.
Two of those shapes are not hypothetical -- they actually bit, on 2026-09-07,
between two sweeps of the same 152 games:

  * the dumper emits the rows of one tick in NONDETERMINISTIC ORDER (row SET
    identical across runs, row SEQUENCE not), so anything reading "the next
    row" or "the first row at t" is irreproducible;
  * `hero` + `player_id` do NOT identify one unit -- ILLUSIONS carry the same
    hero name and the same player_id and differ only in `idx`.  Mixing them
    into Zeus's own time series dragged episodes PAST the real death instant
    and read `ep_died` as 82 instead of 198.

Run with `python3 -m unittest` (this container has no pytest -- and "pytest is
not installed" is a COULD-NOT-RUN, never a pass).
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "tools", "batch_test", "behavioral"))

import zusultstrand_domain as M  # noqa: E402

ZEUS = M.ZEUS
ULT = M.ULT
MANA, CDLAD = M.read_ult_kv()


def snap(t, hero=ZEUS, team=2, x=0.0, y=0.0, hp=300, hp_pct=0.20, mp=400,
         rank=2, cd=0.0, pid=1, idx=1, abilities=True):
    ab = [{"name": ULT, "level": rank, "cd": cd, "cd_len": 130}] if abilities else None
    return {"t": t, "hero": hero, "idx": idx, "team": team, "player_id": pid,
            "x": x, "y": y, "hp": hp, "hp_pct": hp_pct, "mp": mp, "max_mp": 1000,
            "mp_pct": mp / 1000.0, "level": 15, "items": [], "tp_cd": 0,
            "tp_cdlen": 0, "net_worth": 1, "abilities": ab}


def dmg(t, value=50, actor="npc_dota_hero_lina", target=ZEUS, actor_hero=True):
    return {"t": t, "type": "DAMAGE", "actor": actor, "target": target,
            "inflictor": "x", "value": value, "actor_hero": actor_hero,
            "target_hero": True}


def tl(snaps, events):
    return {"game": {}, "snapshots": snaps, "events": events,
            "creeps": [], "buildings": [], "wards": []}


class TestConstantsComeFromTheRepo(unittest.TestCase):
    """The 250/375/500 ladder and the flat 130 cooldown are the two numbers GH
    #564's whole argument rests on.  If this tool retyped them, every
    "affordable" reading would be an assertion about this file."""

    def test_mana_ladder_is_read_not_typed(self):
        self.assertEqual(MANA, [250.0, 375.0, 500.0])

    def test_cooldown_has_no_rank_ladder(self):
        # the entire GH #564 arithmetic ("right side is the constant 130")
        # needs this to be a single value, not a per-rank ladder
        self.assertEqual(CDLAD, [130.0])

    def test_shipped_conjunct_is_false_at_every_rank(self):
        # turbo respawn ceiling = 100 * 0.75 = 75; the conjunct is 75 > cd
        self.assertFalse(any(75.0 > c for c in CDLAD))

    def test_missing_kv_block_raises_rather_than_defaulting(self):
        with self.assertRaises(Exception):
            M.read_ult_kv(path=os.devnull)


class TestTheLadderIsActuallyConsulted(unittest.TestCase):
    """A single hardcoded cost would pass every rank-2 test and silently
    mis-admit rank 1 and rank 3."""

    def _frames(self, rank, mp):
        s = [snap(100.0, rank=rank, mp=mp),
             snap(100.0, hero="npc_dota_hero_lina", team=3, x=800.0, hp=1000,
                  hp_pct=1.0, pid=6, idx=2, rank=1)]
        return M.scan_game(tl(s, [dmg(99.0)]), "g", MANA, CDLAD)["frames"]

    def test_same_mana_admits_rank1_and_refuses_rank2(self):
        self.assertEqual(self._frames(1, 300), 1)
        self.assertEqual(self._frames(2, 300), 0)

    def test_same_mana_admits_rank2_and_refuses_rank3(self):
        self.assertEqual(self._frames(2, 400), 1)
        self.assertEqual(self._frames(3, 400), 0)


class TestIllusionsAreNotTheHero(unittest.TestCase):
    """The 2026-09-07 defect, pinned from the wrong side."""

    def _game(self, illusion_hp_pct):
        s = []
        for t in (100.0, 100.5, 101.0):
            s.append(snap(t))                                    # real, idx 1
            s.append(snap(t, hero="npc_dota_hero_lina", team=3, x=800.0,
                          hp=1000, hp_pct=1.0, pid=6, idx=2, rank=1))
        # one illusion row, same hero name AND same player_id, different idx
        s.append(snap(101.0, x=5000.0, hp_pct=illusion_hp_pct, idx=77))
        return M.scan_game(tl(s, [dmg(99.0), dmg(100.2), dmg(100.8)]),
                           "g", MANA, CDLAD)

    def test_illusion_rows_never_enter_the_domain(self):
        r = self._game(0.10)
        self.assertEqual(r["frames"], 3)
        self.assertEqual(r["zeus_illusion_rows"], 1)

    def test_illusion_count_is_reported_not_swallowed(self):
        # a reading that silently dropped illusions would look identical to one
        # that never met any; the counter is what tells the two apart
        self.assertEqual(self._game(1.0)["zeus_illusion_rows"], 1)

    def test_real_entity_is_the_one_with_the_most_rows(self):
        r = self._game(0.10)
        self.assertEqual(r["real_idx_ties"], [])

    def test_real_entity_tie_is_reported_not_silently_broken(self):
        """Equal row counts make "the real one" arbitrary.  That has to raise a
        hand in the output, because the tie-break itself is not evidence."""
        s = []
        for t in (100.0, 100.5):
            s.append(snap(t))                                    # idx 1
            s.append(snap(t, x=5000.0, idx=77))                  # idx 77, same count
        r = M.scan_game(tl(s, [dmg(99.0), dmg(100.2)]), "g", MANA, CDLAD)
        self.assertIn(ZEUS, r["real_idx_ties"])

    def test_an_illusion_dragging_the_episode_past_the_death_is_the_defect(self):
        """The exact 82-vs-198 shape: an illusion alive after the hero dies."""
        s = []
        # four real rows against three illusion rows: the real entity has to
        # WIN the "most rows" test, and a tie is reported rather than broken
        # (see test_real_entity_tie_is_reported).
        for t in (99.5, 100.0, 100.5):
            s.append(snap(t))
            s.append(snap(t, hero="npc_dota_hero_lina", team=3, x=800.0,
                          hp=1000, hp_pct=1.0, pid=6, idx=2, rank=1))
        s.append(snap(101.0, hp=0, hp_pct=0.0))                  # the hero dies
        s.append(snap(101.0, hero="npc_dota_hero_lina", team=3, x=800.0,
                      hp=1000, hp_pct=1.0, pid=6, idx=2, rank=1))
        for t in (101.5, 102.0, 102.5):                          # illusion lives on
            s.append(snap(t, x=5000.0, idx=77))
            s.append(snap(t, hero="npc_dota_hero_lina", team=3, x=5800.0,
                          hp=1000, hp_pct=1.0, pid=6, idx=2, rank=1))
        r = M.scan_game(tl(s, [dmg(99.0), dmg(100.2), dmg(101.2), dmg(102.2)]),
                        "g", MANA, CDLAD)
        self.assertEqual(r["n_deaths"], 1)
        self.assertTrue(r["episodes"])
        self.assertTrue(r["episodes"][0]["died_within_window"],
                        "illusion frames must not push t1 past the real death")


class TestDeathsAreReadFromTheHeroSOwnHpSeries(unittest.TestCase):
    """A DEATH row names its target by HERO NAME, so an illusion's death and
    the hero's are the same row.  The two counters must be able to disagree --
    if they could not, their agreement on the corpus (741 == 741, 152/152
    games) would be worth nothing."""

    def _base(self):
        s = [snap(100.0),
             snap(100.0, hero="npc_dota_hero_lina", team=3, x=800.0, hp=1000,
                  hp_pct=1.0, pid=6, idx=2, rank=1)]
        return s, [dmg(99.0)]

    def test_log_row_without_hp_transition_is_not_a_death(self):
        s, e = self._base()
        e.append({"t": 102.0, "type": "DEATH", "actor": "npc_dota_hero_lina",
                  "target": ZEUS, "inflictor": "x", "value": 0,
                  "actor_hero": True, "target_hero": True})
        r = M.scan_game(tl(s, e), "g", MANA, CDLAD)
        self.assertEqual((r["n_death_rows"], r["n_deaths"]), (1, 0))

    def test_hp_transition_without_log_row_is_a_death(self):
        s, e = self._base()
        s.append(snap(102.0, hp=0, hp_pct=0.0))
        r = M.scan_game(tl(s, e), "g", MANA, CDLAD)
        self.assertEqual((r["n_death_rows"], r["n_deaths"]), (0, 1))

    def test_another_heros_death_row_is_not_zeuss(self):
        s, e = self._base()
        e.append({"t": 102.0, "type": "DEATH", "actor": ZEUS,
                  "target": "npc_dota_hero_sven", "inflictor": "x", "value": 0,
                  "actor_hero": True, "target_hero": True})
        r = M.scan_game(tl(s, e), "g", MANA, CDLAD)
        self.assertEqual((r["n_death_rows"], r["n_deaths"]), (0, 0))


class TestOrderIndependence(unittest.TestCase):
    """The dumper's tick rows arrive in nondeterministic order.  Shuffling the
    snapshot list must not move a single count."""

    def _snaps(self):
        s = []
        for t in (100.0, 100.25, 100.5, 100.75):
            s.append(snap(t))
            s.append(snap(t, x=5000.0, idx=77))                  # an illusion
            s.append(snap(t, hero="npc_dota_hero_lina", team=3, x=700.0,
                          hp=1000, hp_pct=1.0, pid=6, idx=2, rank=1))
        s.append(snap(101.0, hp=0, hp_pct=0.0))
        s.append(snap(101.0, hero="npc_dota_hero_lina", team=3, x=700.0,
                      hp=1000, hp_pct=1.0, pid=6, idx=2, rank=1))
        return s

    def test_every_count_survives_a_reversal(self):
        e = [dmg(99.0), dmg(100.1), dmg(100.6)]
        a = M.scan_game(tl(list(self._snaps()), list(e)), "g", MANA, CDLAD)
        b = M.scan_game(tl(list(reversed(self._snaps())), list(e)), "g", MANA, CDLAD)
        for k in ("frames", "n_deaths", "deaths_holding_castable_ult",
                  "retreat_proxy_frames", "in_chase_radius",
                  "in_chase_radius_real_only", "ultcash_ring_only",
                  "zeus_illusion_rows"):
            self.assertEqual(a[k], b[k], "%s moved when rows were reordered" % k)
        self.assertEqual(len(a["episodes"]), len(b["episodes"]))


class TestTheUltcashLayerIsNotThePredicate(unittest.TestCase):
    """Column (4) is PARTIAL on purpose.  The retrospective proxy must never be
    reachable through the same key as the geometric ring."""

    def _game(self, later_damage):
        s = [snap(100.0, hp=300),
             snap(100.0, hero="npc_dota_hero_lina", team=3, x=700.0, hp=1000,
                  hp_pct=1.0, pid=6, idx=2, rank=1)]
        e = [dmg(99.0)] + ([dmg(101.0, value=later_damage)] if later_damage else [])
        return M.scan_game(tl(s, e), "g", MANA, CDLAD)

    def test_ring_fires_without_the_proxy(self):
        r = self._game(0)
        self.assertEqual((r["ultcash_ring_only"], r["ultcash_retro_and_ring"]), (1, 0))

    def test_proxy_needs_lethal_retrospective_damage(self):
        self.assertEqual(self._game(10)["ultcash_retro_and_ring"], 0)
        self.assertEqual(self._game(400)["ultcash_retro_and_ring"], 1)

    def test_proxy_is_a_subset_of_the_ring(self):
        r = self._game(400)
        self.assertLessEqual(r["ultcash_retro_and_ring"], r["ultcash_ring_only"])


class TestSelfcheckIsWiredAndCanFail(unittest.TestCase):
    def test_selfcheck_passes(self):
        self.assertEqual(M.selfcheck(), 0)


if __name__ == "__main__":
    unittest.main()
