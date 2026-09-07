"""Adversarial tests for tools/batch_test/behavioral/cmrangedhp_domain.py.

These pin, FROM THE WRONG SIDE, the shapes in which this round's headline could
have been manufactured by the instrument rather than found in the corpus.  Run
with `python3 -m unittest` (this container has no pytest -- and "pytest is not
installed" is a COULD-NOT-RUN, never a pass).
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "tools", "batch_test", "behavioral"))

import cmrangedhp_domain as M  # noqa: E402

CM = M.CM
FB = M.FROSTBITE


def snap(idx, team, t, x=0.0, y=0.0, hp=1.0, level=9, hero=CM, fb_rank=None):
    ab = []
    if fb_rank is not None:
        ab = [{"name": FB, "level": fb_rank, "cd": 0.0}]
    return {"hero": hero, "idx": idx, "team": team, "t": t, "x": x, "y": y,
            "hp_pct": hp, "level": level, "abilities": ab}


class TestExitPredicate(unittest.TestCase):
    """The exit tests `string.find(name,'ranged')`, not equality with the four
    lane literals.  Conflating the two is the difference between a domain that
    opens at 0:00 and one that opens at 10:00."""

    def test_upgraded_ranged_hits_the_exit_but_is_not_a_gated_name(self):
        n = "npc_dota_creep_badguys_ranged_upgraded"
        self.assertTrue(M.hits_ranged_exit(n))
        self.assertNotIn(n, M.GATED_LANE_NAMES)

    def test_mega_ranged_hits_the_exit_but_is_not_a_gated_name(self):
        n = "npc_dota_creep_goodguys_ranged_upgraded_mega"
        self.assertTrue(M.hits_ranged_exit(n))
        self.assertNotIn(n, M.GATED_LANE_NAMES)

    def test_base_ranged_is_both(self):
        n = "npc_dota_creep_badguys_ranged"
        self.assertTrue(M.hits_ranged_exit(n))
        self.assertIn(n, M.GATED_LANE_NAMES)

    def test_siege_never_reaches_the_exit(self):
        # The picker rejects any name containing 'siege' before the exit, and
        # 'siege' contains no 'ranged' either.
        self.assertFalse(M.hits_ranged_exit("npc_dota_creep_badguys_siege"))

    def test_buckets_do_not_pool_upgraded_into_base(self):
        self.assertNotEqual(
            M.classify_target("npc_dota_creep_badguys_ranged"),
            M.classify_target("npc_dota_creep_badguys_ranged_upgraded"))


class TestFloorsAreReadNotRetyped(unittest.TestCase):
    """GH #560's own lesson: a by-construction argument certified by an
    assertion that cannot fail is not evidence.  The floors must come out of
    the Lua, and a moved floor must change the answer."""

    def test_floors_come_from_source(self):
        self.assertEqual(sorted(M.consumer_floors(), reverse=True),
                         M.EXPECTED_FLOORS)

    def test_a_raised_floor_would_break_the_narrowing_claim(self):
        import tempfile
        src = open(M.HERO_SRC, encoding="utf-8").read()
        mutated = src.replace(
            "if ( nEnemysStrongestCreepsHealth2 > 460",
            "if ( nEnemysStrongestCreepsHealth2 > 560", 1)
        self.assertNotEqual(src, mutated)
        with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False,
                                         encoding="utf-8") as f:
            f.write(mutated)
            p = f.name
        try:
            floors = M.consumer_floors(p)
            self.assertIn(560, floors)
            # 500 no longer clears every floor -> "arming can only narrow"
            # stops being true, and the reader is told so.
            self.assertFalse(all(500 > x for x in floors))
        finally:
            os.unlink(p)

    def test_missing_source_reads_as_unknown_not_as_default(self):
        self.assertIsNone(M.consumer_floors("/nonexistent/hero.lua"))


class TestCapTermIsVacuousOnShippedTree(unittest.TestCase):
    """cm_GetFrostbiteCreepCap is a flat 1200 with cmcreepcap un-armed, and the
    picker admits only health <= 1100, so the cap term cannot bite."""

    def test_ceiling_below_cap(self):
        self.assertLessEqual(M.PICKER_HEALTH_CEILING, M.SHIPPED_CREEP_CAP)

    def test_shipped_literal_under_cap(self):
        self.assertLessEqual(500, M.SHIPPED_CREEP_CAP)


class TestHealthBoundStaysOneSided(unittest.TestCase):
    """The bound may prove `hp > 460`.  It may never prove `hp <= 460`, and no
    code path is allowed to read it as the health."""

    def test_drops_the_possibly_killing_tick(self):
        self.assertEqual(M.hp_lower_bound([200, 200, 200]), 400)

    def test_single_tick_bounds_nothing_above_zero(self):
        self.assertEqual(M.hp_lower_bound([250]), 0)

    def test_no_ticks_is_unknown_not_zero(self):
        self.assertIsNone(M.hp_lower_bound([]))

    def test_bound_is_strictly_below_the_observed_total(self):
        ticks = [200, 200, 150]
        self.assertLess(M.hp_lower_bound(ticks), sum(ticks))

    def test_aggregate_only_counts_proven_over_460(self):
        rec = {"casts": [
            {"t": 700.0, "target": "npc_dota_creep_badguys_ranged",
             "bucket": "lane_ranged", "ranged_exit_name": True,
             "gated_name": True, "after_600": True, "caster": "x",
             "rank": 3, "side": 2, "hp_lb": 400},
            {"t": 701.0, "target": "npc_dota_creep_badguys_ranged",
             "bucket": "lane_ranged", "ranged_exit_name": True,
             "gated_name": True, "after_600": True, "caster": "x",
             "rank": 3, "side": 2, "hp_lb": 600},
        ]}
        agg = M.aggregate([rec])
        self.assertEqual(agg["hp_lb_known"], 2)
        self.assertEqual(agg["hp_lb_over_460"], 1)


class TestConditionalUpperBoundIsWithdrawnWhenItsAssumptionFails(
        unittest.TestCase):
    """The conditional upper bound is the one number in this round that could
    be quoted as `the creep's health`.  It exists only when the combat log
    itself names Frostbite as the killing blow AND no other hero-sourced damage
    touched the target.  Each of those failing must WITHDRAW it, not shrink
    it -- a surviving-but-wrong bound is how an instrument manufactures the
    conclusion it then reports."""

    BASE = {
        "snapshots": [snap(1, 2, -60.0, fb_rank=4), snap(1, 2, 100.0, fb_rank=4)],
        "creeps": [],
    }
    TGT = "npc_dota_creep_badguys_ranged"

    def _game(self, extra_events, death_inflictor=FB, death_actor=CM):
        ev = [
            {"t": 100.0, "type": "ABILITY", "actor": CM, "target": self.TGT,
             "inflictor": FB, "value": 0},
            {"t": 100.5, "type": "DAMAGE", "actor": CM, "target": self.TGT,
             "inflictor": FB, "value": 200},
            {"t": 101.0, "type": "DAMAGE", "actor": CM, "target": self.TGT,
             "inflictor": FB, "value": 200},
        ]
        if death_inflictor is not None:
            ev.append({"t": 101.2, "type": "DEATH", "actor": death_actor,
                       "target": self.TGT, "inflictor": death_inflictor})
        g = dict(self.BASE)
        g["events"] = ev + list(extra_events)
        return M.scan_game(g, "g")["casts"][0]

    def test_clean_episode_gets_the_bound(self):
        c = self._game([])
        self.assertEqual(c["hp_ub_if_frostbite_alone"], 400)
        self.assertEqual(c["hp_lb"], 200)
        self.assertLess(c["hp_lb"], c["hp_ub_if_frostbite_alone"])

    def test_pre_cast_ally_damage_withdraws_the_bound(self):
        """The 2026-09-07 self-catch, from the corpus (game
        20260831_005511_slot1, t=705.5): an allied Storm Spirit hit the frozen
        creep for 221 at t=705.1 -- 0.4s BEFORE the cast row -- and a single
        22-damage Frostbite tick then killed it.  With a 0.2s pre-roll the bound
        survived and said "22 health"; what the picker read was ~243.  The
        window has to reach back past the cast point."""
        c = self._game([
            {"t": 99.6, "type": "DAMAGE", "actor": "npc_dota_hero_storm_spirit",
             "target": self.TGT, "inflictor": "dota_unknown", "value": 221}])
        self.assertNotIn("hp_ub_if_frostbite_alone", c)
        self.assertEqual(c["pre_cast_hero_dmg"], 221)

    def test_damage_older_than_the_pre_roll_keeps_the_bound(self):
        c = self._game([
            {"t": 97.0, "type": "DAMAGE", "actor": "npc_dota_hero_storm_spirit",
             "target": self.TGT, "inflictor": "dota_unknown", "value": 221}])
        self.assertEqual(c["hp_ub_if_frostbite_alone"], 400)
        self.assertEqual(c["pre_cast_hero_dmg"], 0)

    def test_pre_roll_covers_the_cast_point(self):
        # Frostbite's cast point is 0.35s and the order-to-cast latency sits on
        # top of it; a pre-roll at or below that cannot see the interval.
        self.assertGreater(M.DECISION_PRE_ROLL, 0.35)

    def test_withdrawn_bounds_are_counted_not_silently_dropped(self):
        c = self._game([
            {"t": 99.6, "type": "DAMAGE", "actor": "npc_dota_hero_storm_spirit",
             "target": self.TGT, "inflictor": "dota_unknown", "value": 221}])
        agg = M.aggregate([{"casts": [c]}])
        self.assertEqual(agg["ub_withdrawn_pre_cast_dmg"], 1)
        self.assertEqual(agg["clean_episodes"], 0)

    def test_a_hero_autoattack_withdraws_the_bound(self):
        c = self._game([
            {"t": 100.8, "type": "DAMAGE", "actor": CM, "target": self.TGT,
             "inflictor": "", "value": 47}])
        self.assertNotIn("hp_ub_if_frostbite_alone", c)
        self.assertEqual(c["other_hero_dmg_in_window"], 47)

    def test_a_foreign_killing_blow_withdraws_the_bound(self):
        c = self._game([], death_inflictor="lion_impale",
                       death_actor="npc_dota_hero_lion")
        self.assertNotIn("hp_ub_if_frostbite_alone", c)
        self.assertFalse(c["killed_by_frostbite"])
        self.assertTrue(c["died_in_window"])

    def test_a_survivor_gets_no_upper_bound_at_all(self):
        c = self._game([], death_inflictor=None)
        self.assertNotIn("hp_ub_if_frostbite_alone", c)
        self.assertFalse(c["died_in_window"])
        self.assertEqual(c["hp_lb"], 200)   # the lower bound still stands

    def test_zero_other_hero_damage_is_not_zero_other_damage(self):
        """The reading is 'no HERO also hit it'.  Allied-creep and tower damage
        is dropped by the dumper's noise filter and is therefore invisible --
        the bound is conditional and the key name says so."""
        c = self._game([])
        self.assertEqual(c["other_hero_dmg_in_window"], 0)
        self.assertIn("if_frostbite_alone", "hp_ub_if_frostbite_alone")

    def test_a_same_name_creeps_death_cannot_buy_the_bound(self):
        """Creeps carry no idx anywhere in the dump, so a DEATH row keyed on
        the name may belong to a DIFFERENT creep of that name.  The bound is
        gated on the Frostbite inflictor (exact -- only one Frostbite is active
        per caster), never on the name-attributed death."""
        c = self._game([], death_inflictor="dota_unknown",
                       death_actor="npc_dota_hero_venomancer")
        self.assertTrue(c["died_in_window"])       # name-attributed: upper bound
        self.assertFalse(c["killed_by_frostbite"])  # exact
        self.assertNotIn("hp_ub_if_frostbite_alone", c)

    def test_aggregate_splits_the_bound_at_460(self):
        clean = self._game([])
        big = dict(clean, hp_ub_if_frostbite_alone=900)
        agg = M.aggregate([{"casts": [clean, big]}])
        self.assertEqual(agg["clean_episodes"], 2)
        self.assertEqual(agg["hp_ub_at_or_below_460"], 1)
        self.assertEqual(agg["hp_ub_over_460"], 1)


class TestIllusionAndDeathDiscipline(unittest.TestCase):
    """GH #176: hero name is not an entity key, and interpolated hp is not
    life.  Both failure shapes manufacture a 'point blank' enemy."""

    def test_illusion_stream_is_dropped_by_spawn_instant(self):
        st = M.real_hero_streams([snap(1, 2, -60.0), snap(1, 2, 10.0),
                                  snap(9, 2, 10.0)])
        self.assertEqual(list(st), [(CM, 1)])

    def test_illusion_of_an_enemy_is_not_an_enemy_in_the_ring(self):
        rows = [snap(1, 2, -60.0), snap(1, 2, 100.0),
                # enemy illusion standing on top of CM, never seen pre-horn
                snap(8, 3, 100.0, hero="npc_dota_hero_lion")]
        st = M.real_hero_streams(rows)
        self.assertEqual(
            M.near_count(st, 100.0, 0, 0, 1600.0, 2, True, (CM, 1)), 0)

    def test_dead_enemy_is_not_counted(self):
        rows = [snap(1, 2, -60.0), snap(1, 2, 100.0),
                snap(2, 3, -60.0, hero="npc_dota_hero_lion", hp=1.0),
                snap(2, 3, 99.0, x=50, hero="npc_dota_hero_lion", hp=0.0),
                snap(2, 3, 101.0, x=50, hero="npc_dota_hero_lion", hp=0.0)]
        st = M.real_hero_streams(rows)
        self.assertEqual(
            M.near_count(st, 100.0, 0, 0, 1600.0, 2, True, (CM, 1)), 0)

    def test_stale_sample_beyond_two_seconds_is_not_used(self):
        rows = [snap(1, 2, -60.0), snap(1, 2, 100.0),
                snap(2, 3, -60.0, x=50, hero="npc_dota_hero_lion"),
                snap(2, 3, 20.0, x=50, hero="npc_dota_hero_lion")]
        st = M.real_hero_streams(rows)
        self.assertEqual(
            M.near_count(st, 100.0, 0, 0, 1600.0, 2, True, (CM, 1)), 0)

    def test_over_counting_direction_makes_zero_a_subset(self):
        # inside on only ONE bracket -> counted, so `== 0` is harder to reach
        rows = [snap(1, 2, -60.0), snap(1, 2, 100.0),
                snap(2, 3, -60.0, x=9000, hero="npc_dota_hero_lion"),
                snap(2, 3, 99.0, x=9000, hero="npc_dota_hero_lion"),
                snap(2, 3, 101.0, x=100, hero="npc_dota_hero_lion")]
        st = M.real_hero_streams(rows)
        self.assertEqual(
            M.near_count(st, 100.0, 0, 0, 1600.0, 2, True, (CM, 1)), 1)


class TestCasterAttribution(unittest.TestCase):
    """Two CMs in one game is the mirrored-draft norm.  Booking a cast to a
    guess is how 'don't know' gets laundered into 'not guilty'."""

    def _two_cm_game(self, target):
        return {
            "snapshots": [snap(1, 2, -60.0, fb_rank=2), snap(1, 2, 100.0, fb_rank=2),
                          snap(5, 3, -60.0, fb_rank=4), snap(5, 3, 100.0, fb_rank=4)],
            "creeps": [],
            "events": [{"t": 100.0, "type": "ABILITY", "actor": CM,
                        "target": target, "inflictor": FB, "value": 0}],
        }

    def test_neutral_target_with_two_cms_is_ambiguous(self):
        rec = M.scan_game(self._two_cm_game("npc_dota_neutral_harpy_scout"),
                          "g")
        self.assertEqual(rec["casts"][0]["caster"], "ambiguous")
        self.assertNotIn("rank", rec["casts"][0])

    def test_lane_creep_target_resolves_by_the_creeps_own_team(self):
        rec = M.scan_game(
            self._two_cm_game("npc_dota_creep_badguys_ranged"), "g")
        c = rec["casts"][0]
        self.assertNotEqual(c["caster"], "ambiguous")
        self.assertEqual(c["side"], 2)      # dire creep -> radiant caster
        self.assertEqual(c["rank"], 2)      # ...and the radiant CM's rank

    def test_ambiguous_casts_are_registered_not_dropped(self):
        rec = M.scan_game(self._two_cm_game("npc_dota_neutral_harpy_scout"),
                          "g")
        agg = M.aggregate([rec])
        self.assertEqual(agg["ambiguous_caster"], 1)
        self.assertEqual(agg["casts_total"], 1)


class TestInstrumentBlindnessIsReportedNotFilled(unittest.TestCase):
    """The two blind columns must read as UNKNOWN.  A 0 for attack damage would
    degenerate the exit's admission test to `GetHealth() > 0` and read as the
    widest possible window -- the instrument, not the game."""

    def test_creep_rows_carry_no_health_or_name(self):
        tl = {"snapshots": [snap(1, 2, -60.0), snap(1, 2, 5.0)],
              "creeps": [{"t": 1.0, "team": 2, "x": 1.0, "y": 2.0}],
              "events": []}
        rec = M.scan_game(tl, "g")
        self.assertEqual(rec["creep_key_shapes"], {"t|team|x|y": 1})
        self.assertNotIn("hp", "t|team|x|y")

    def test_attack_damage_absence_is_a_flag_not_a_zero(self):
        tl = {"snapshots": [snap(1, 2, -60.0)], "creeps": [], "events": []}
        rec = M.scan_game(tl, "g")
        self.assertIs(rec["snapshot_has_attack_damage"], False)
        self.assertNotIn("attack_damage", rec)


class TestTimeStratification(unittest.TestCase):
    def test_the_600_line_is_not_averaged_away(self):
        def cast(t, name):
            return {"t": t, "target": name, "bucket": M.classify_target(name),
                    "ranged_exit_name": M.hits_ranged_exit(name),
                    "gated_name": name in M.GATED_LANE_NAMES,
                    "after_600": t > 600.0, "caster": "x", "rank": 3,
                    "side": 2}
        rec = {"casts": [
            cast(100.0, "npc_dota_creep_badguys_ranged_upgraded"),
            cast(700.0, "npc_dota_creep_badguys_ranged"),
        ]}
        agg = M.aggregate([rec])
        self.assertEqual(agg["ranged_by_time"],
                         {"before_600": 1, "after_600": 1})
        # only the base name is subject to the 10-minute disjunct
        self.assertEqual(agg["ranged_gatedname_by_time"], {"after_600": 1})


if __name__ == "__main__":
    unittest.main()
