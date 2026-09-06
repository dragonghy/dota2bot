"""Adversarial wrapper around tools/batch_test/behavioral/wkbonefight_domain.py.

`--selfcheck` proves the scanner agrees with itself.  This file exists for the
other half: the corpus shapes that would have MANUFACTURED this round's
headline, each pinned from the negative side so the tool has to refuse them.

The headline being protected is "the `wkbonefight` domain IS reached -- N ready
instants with an enemy inside 650 while TWO OR MORE enemies stand inside 1600,
i.e. exactly the teamfights the shipped `== 1` duel test throws away".  Four
ways that headline could be conjured out of a corpus that does not contain it:

  1. counting an ILLUSION as the second enemy (GH #176 -- an illusion carries
     the hero's name and player_id, and it stands next to its owner, which is
     precisely where a second body flips layer 1 into layer 2);
  2. counting a CORPSE as the second enemy -- either through an interpolated
     hp (GH #176 (2)) or through the frozen post-death stream that outnumbers
     the live one 22.6 : 1 (charter 2026-09-02);
  3. counting frames where the ability is not actually castable -- the mana
     floor is a per-rank ladder (70/80/90/100), and reading it as one constant
     inflates the domain at exactly the ranks WK spends the game at;
  4. reporting a CHARGE COUNT for column (4).  The stack level is not in this
     dump; the request pre-registered "拿不到就明写拿不到,不要用 0 顶替", and a
     tool that quietly substituted 0 would turn an unmeasured gate into a
     measured refusal.

Case 4 is the one with teeth in the other direction too: it is the only column
the queue row asks for that this instrument cannot buy, so the test pins that
the tool keeps SAYING it cannot buy it -- including the day the dumper starts
emitting a real level, when `stacks_recoverable` must flip to True instead of
this file being edited.
"""

import os
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..",
                                "tools", "batch_test", "behavioral"))

import wkbonefight_domain as W  # noqa: E402

WK = "npc_dota_hero_" + W.WK
LINA = "npc_dota_hero_lina"
PUDGE = "npc_dota_hero_pudge"


def snap(t, hero, idx, team, x, y=0.0, hp_pct=1.0, mp=500, level=10,
         w_level=3, w_cd=0.0, r_cd=99.0):
    return {"t": t, "hero": hero, "idx": idx, "team": team, "player_id": idx,
            "x": x, "y": y, "hp": int(1000 * hp_pct), "hp_pct": hp_pct,
            "mp": mp, "max_mp": 800, "level": level, "items": [],
            "abilities": [{"name": W.W_NAME, "level": w_level, "cd": w_cd,
                           "cd_len": 42},
                          {"name": W.R_NAME, "level": 1, "cd": r_cd,
                           "cd_len": 180}]}


def tl(snaps, events=None):
    return {"game": {"teams": {}}, "snapshots": snaps, "events": events or []}


def duel(**kw):
    """WK plus ONE enemy at 400u, pre-horn onward -- layer 1, never layer 2."""
    out = []
    for t in (-2.0, 0.0, 1.0, 2.0):
        out.append(snap(t, WK, 10, 2, 0.0, **kw))
        out.append(snap(t, LINA, 20, 3, 400.0))
    return tl(out)


class AnIllusionIsNotTheSecondEnemy(unittest.TestCase):
    """Shape 1.  A copy standing on the fight is how layer 2 gets invented."""

    def test_post_horn_duplicate_does_not_reach_layer_two(self):
        t = duel()
        for ts in (1.0, 2.0):
            t["snapshots"].append(snap(ts, LINA, 99, 3, 30.0))
        r = W.scan_one(t, "g")
        self.assertEqual(r["layer_n2"]["frames"], 0)
        self.assertEqual(r["layer_n1"]["frames"], 3)

    def test_the_guard_is_birth_time_and_not_health_or_motion(self):
        """An illusion at full health that moves is still an illusion."""
        t = duel()
        for i, ts in enumerate((1.0, 2.0)):
            s = snap(ts, LINA, 98, 3, 30.0 + 40 * i)
            s["hp_pct"], s["hp"] = 1.0, 1000
            t["snapshots"].append(s)
        self.assertEqual(W.scan_one(t, "g")["view_hist"], {"1": 3})

    def test_a_real_second_enemy_DOES_reach_layer_two(self):
        """The mirror of the above: the guard must not eat the real signal."""
        t = duel()
        for ts in (-2.0, 0.0, 1.0, 2.0):
            t["snapshots"].append(snap(ts, PUDGE, 21, 3, 500.0))
        r = W.scan_one(t, "g")
        self.assertEqual(r["layer_n2"]["frames"], 3)
        self.assertEqual(r["layer_n1"]["frames"], 0)


class ACorpseIsNotTheSecondEnemy(unittest.TestCase):
    """Shape 2.  Both halves: the zero-hp stream and the frozen position."""

    def _two_enemies_one_dies(self, freeze_hp):
        snaps = []
        for ts in (-2.0, 0.0, 1.0, 2.0):
            snaps.append(snap(ts, WK, 10, 2, 0.0))
            snaps.append(snap(ts, LINA, 20, 3, 400.0))
            dead = ts > 0.5
            snaps.append(snap(ts, PUDGE, 21, 3, 500.0,
                              hp_pct=freeze_hp if dead else 1.0))
        return tl(snaps, [{"t": 0.5, "type": "DEATH", "actor": "x",
                           "target": PUDGE, "inflictor": "",
                           "value": 0, "actor_hero": True,
                           "target_hero": True}])

    def test_zero_hp_corpse_drops_out_of_the_ring(self):
        r = W.scan_one(self._two_enemies_one_dies(0.0), "g")
        self.assertEqual(r["view_hist"], {"1": 2, "2": 1})
        self.assertEqual(r["layer_n2"]["frames"], 1)

    def test_a_frozen_positive_hp_stream_IS_still_counted_and_IS_registered(self):
        """The hole the guard genuinely has, pinned as a hole and not as a pass.

        `entities.alive_at` reads a RUN of positive-hp frames after a death as
        a resurrection, because Wraith King reincarnates in place and any
        "respawn = jumped to the fountain" rule mis-times him (charter
        2026-08-21).  A stream frozen at positive hp has the same shape, so it
        IS counted as a live enemy -- this test asserts that it is, rather than
        asserting a bound that would read as the contaminant being handled.

        What the tool owes instead is the SIZE of the hole, and that is the
        assertion with teeth: every such reading is registered as a suspect, so
        the corpus report carries the number the domain could have been
        inflated by.  Real corpses read hp 0 (96.2% of frames, charter
        2026-08-21) and the units that actually freeze are illusions, which the
        birth-time guard already drops -- but "should be small" is not a
        reading, so the count is published beside the domain.
        """
        r = W.scan_one(self._two_enemies_one_dies(0.05), "g")
        # three post-horn WK frames read n1600 == 2; the death lands at t=0.5,
        # so two of the three second-enemy readings are post-death suspects and
        # the t=0 one is a genuinely live enemy.
        self.assertEqual(r["layer_n2"]["frames"], 3)
        self.assertEqual(r["resurrect_suspect_frames"], 2)

    def test_a_clean_corpus_reports_zero_suspects(self):
        r = W.scan_one(self._two_enemies_one_dies(0.0), "g")
        self.assertEqual(r["resurrect_suspect_frames"], 0)


class TheManaFloorIsALadderNotAConstant(unittest.TestCase):
    """Shape 3.  70/80/90/100 by rank (tests/mock/special_value_shapes.lua)."""

    def test_every_rank_is_refused_one_point_below_its_own_cost(self):
        for rank, cost in W.W_MANA.items():
            r = W.scan_one(duel(w_level=rank, mp=cost - 1), "lo")
            self.assertEqual(r["ready_frames"], 0, "rank %d" % rank)

    def test_every_rank_is_accepted_at_exactly_its_own_cost(self):
        for rank, cost in W.W_MANA.items():
            r = W.scan_one(duel(w_level=rank, mp=cost), "hi")
            self.assertEqual(r["ready_frames"], 3, "rank %d" % rank)

    def test_rank_four_is_not_paid_for_at_the_rank_one_price(self):
        """The specific inflation: reading one constant 70 would call a rank-4
        frame with 70 mana ready, and rank 4 is where WK spends the fight."""
        self.assertEqual(W.scan_one(duel(w_level=4, mp=70), "g")
                         ["ready_frames"], 0)

    def test_a_cooling_ability_is_never_ready(self):
        self.assertEqual(W.scan_one(duel(w_cd=0.1), "g")["ready_frames"], 0)

    def test_mana_reserved_for_reincarnation_is_not_domain(self):
        """X.ShouldSaveMana is the one unobservable that IS observable, and
        dropping it would add every late-game banking frame to column (1)."""
        r = W.scan_one(duel(level=10, mp=300, r_cd=1.0), "g")
        self.assertEqual(r["ready_frames"], 0)
        self.assertEqual(r["savemana_frames"], 3)


class ColumnFourStaysBlind(unittest.TestCase):
    """Shape 4.  The charge level is not in this dump and may not be faked."""

    def _with_stack_rows(self, value):
        t = duel()
        t["events"].append({"t": 1.0, "type": "MODIFIER_STACK_EVENT",
                            "actor": WK, "target": WK,
                            "inflictor": W.W_MODIFIER, "value": value,
                            "actor_hero": True, "target_hero": True})
        return W.scan_one(t, "g")["stack_evidence"]

    def test_a_zero_valued_edge_is_not_a_level(self):
        ev = self._with_stack_rows(0)
        self.assertEqual(ev["stack_rows"], 1)
        self.assertFalse(ev["stacks_recoverable"])

    def test_the_day_the_dumper_emits_a_level_this_flips(self):
        """Written so the blind column reopens by itself rather than needing
        somebody to remember this file."""
        self.assertTrue(self._with_stack_rows(4)["stacks_recoverable"])

    def test_no_snapshot_carries_a_modifier_list(self):
        self.assertFalse(
            W.scan_one(duel(), "g")["stack_evidence"]["snap_modifier_key"])

    def test_a_release_is_still_witnessed_from_the_event_stream(self):
        """The one thing the dump DOES settle against the fixture zero: a cast
        of the ability proves `bot:HasModifier` was true, because ConsiderW is
        the repo's only caster."""
        t = duel()
        t["events"].append({"t": 1.0, "type": "ABILITY", "actor": WK,
                            "target": "dota_unknown",
                            "inflictor": W.W_NAME, "value": 0,
                            "actor_hero": True, "target_hero": False})
        self.assertEqual(W.scan_one(t, "g")["stack_evidence"]["casts"], 1)


class TheTwoLayersAreNeverPooled(unittest.TestCase):
    """The queue row's own acceptance clause, pinned as a test.

    Pooling is the failure that reads best: it makes the domain look larger
    while deleting the only distinction the lever is about.
    """

    def test_layer_sizes_are_reported_separately_and_sum_is_not_reported(self):
        t = duel()
        for ts in (-2.0, 0.0, 1.0, 2.0):
            t["snapshots"].append(snap(ts, PUDGE, 21, 3, 500.0))
        r = W.scan_one(t, "g")
        self.assertEqual(r["layer_n1"]["frames"], 0)
        self.assertEqual(r["layer_n2"]["frames"], 3)
        self.assertNotIn("layer_all", r)

    def test_aggregate_keeps_the_split(self):
        a = W.aggregate([W.scan_one(duel(), "a"), W.scan_one(duel(), "b")])
        self.assertEqual(a["layer_n1"]["frames"], 6)
        self.assertEqual(a["layer_n2"]["frames"], 0)

    def test_both_sides_are_disclosed_even_when_one_is_empty(self):
        """Iron rule 4(i-a): the READING of each stratum is registered, not
        just the game count."""
        a = W.aggregate([W.scan_one(duel(), "a")])
        self.assertIn("radiant", a["strata"])
        self.assertIn("dire", a["strata"])
        self.assertEqual(a["strata"]["dire"]["ready_frames"], 0)


class TheGeometricCountIsAnUpperBound(unittest.TestCase):
    """LIMITS 4.  There is no fog bitmask, so `#nEnemysHerosInView` cannot be
    read exactly; the tool must publish the witnessed floor beside it and never
    silently swap one for the other."""

    def test_both_counts_are_reported(self):
        r = W.scan_one(duel(), "g")
        self.assertEqual(r["view_hist"], {"1": 3})
        self.assertEqual(r["view_hist_witnessed"], {"0": 3})

    def test_the_floor_rises_only_near_an_interaction(self):
        t = duel()
        t["events"].append({"t": 1.0, "type": "DAMAGE", "actor": LINA,
                            "target": WK, "inflictor": "x", "value": 10,
                            "actor_hero": True, "target_hero": True})
        self.assertEqual(W.scan_one(t, "g")["view_hist_witnessed"], {"1": 3})


class SelfcheckRunsClean(unittest.TestCase):
    def test_selfcheck_exit_zero(self):
        p = subprocess.run(
            [sys.executable,
             os.path.join(os.path.dirname(__file__), "..", "tools",
                          "batch_test", "behavioral",
                          "wkbonefight_domain.py"), "--selfcheck"],
            capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("0 FAIL", p.stdout)


if __name__ == "__main__":
    unittest.main()
