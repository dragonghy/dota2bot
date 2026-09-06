#!/usr/bin/env python3
"""Runs `axebhrecast_domain.py`'s selfcheck battery from the python suite, and
pins the two readings that a future edit is most likely to undo.

WHY THIS WRAPPER EXISTS.  `tests/run_py_tests.sh` only loops over
`tests/test_*.py`, so a module-level `--selfcheck` that nothing invokes is a
gate that never opens (the GH #243 shape; same reason `tests/test_tpdying_release.py`
and `tests/test_tpreach_domain.py` exist).

THE MANUFACTURED ZERO THIS FILE EXISTS TO KEEP DEAD.  The lever's armed leg
stands down under `J.HasAghanimsShard( bot )`, so how much domain there is at
all turns on that term.  Reading it off `snapshots[].items` returns ZERO across
72 games -- and that zero is made by the instrument, not observed: Aghanim's
Shard is CONSUMED on use, so it leaves the inventory the moment it starts
mattering, and the combat log puts no shard modifier on Axe either.  Taken at
face value it put all 577 re-casts inside a gate that in fact stands down for
304 of them; the corrected count is 273.  `test_inventory_item_is_not_the_gate_term`
fails if the inventory reading is ever wired back into `axe_has_shard`.

The observable that does work is behavioural and is pinned beside it:
`applies_battle_hunger` reaches `axe_berserkers_call` from `special_bonus_shard`
and from nowhere else, so a Call whose own instant carries a
`modifier_axe_battle_hunger` ADD dates the acquisition.  It is LATE by
construction (it cannot fire until Axe next lands a Call), which makes the
in-domain count an OVER-estimate -- the conservative direction for a request
whose pre-registered failure mode is "the domain is smaller than it looks".

THE KILL-CONFIRM COLUMN IS NOT DECORATION.  X.ConsiderW's KILL LOOP is one of
the five sites the lever deliberately leaves UNWIRED, because its damage claim
is priced on the full 12s a refresh restores.  Frame-by-frame review of this
scan's own best "spread" exemplar (four unhungered enemies inside 900u) found
Axe Culling-Bladed that target dead 2.0s later -- i.e. the single most
benefit-shaped episode in the corpus was a deliberate no-op site.  Without the
column, column (2) reads those as forgone benefit.  It does NOT identify the
branch; that stays INSTRUMENT-BLIND.
"""

import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "batch_test", "behavioral", "axebhrecast_domain.py")
sys.path.insert(0, os.path.dirname(TOOL))

import axebhrecast_domain as M  # noqa: E402


class TestSelfcheckBattery(unittest.TestCase):
    def test_selfcheck_passes(self):
        r = subprocess.run([sys.executable, TOOL, "--selfcheck"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("0 FAIL", r.stdout)
        self.assertNotIn("0 PASS", r.stdout)  # a vacuous battery is not a pass


def _tl(events, axe_items=None):
    snaps = []
    for i in range(-5, 60):
        snaps.append({"t": float(i), "hero": M.AXE, "idx": 10, "team": 2,
                      "player_id": 0, "x": 0.0, "y": 0.0, "hp": 100, "hp_pct": 1.0,
                      "mp": 100, "max_mp": 100, "mp_pct": 1.0, "level": 6,
                      "items": list(axe_items or []),
                      "abilities": [{"name": M.CAST_ABILITY, "level": 1,
                                     "cd": 0, "cd_len": 20}]})
        snaps.append({"t": float(i), "hero": "e1", "idx": 11, "team": 3,
                      "player_id": 1, "x": 100.0, "y": 0.0, "hp": 100, "hp_pct": 1.0,
                      "mp": 100, "max_mp": 100, "mp_pct": 1.0, "level": 6,
                      "items": [], "abilities": []})
        snaps.append({"t": float(i), "hero": "e2", "idx": 12, "team": 3,
                      "player_id": 2, "x": 300.0, "y": 0.0, "hp": 100, "hp_pct": 1.0,
                      "mp": 100, "max_mp": 100, "mp_pct": 1.0, "level": 6,
                      "items": [], "abilities": []})
    return {"game": {"teams": {M.AXE: 2, "e1": 3, "e2": 3}},
            "snapshots": snaps, "events": events}


BASE = [
    {"t": 10.0, "type": "ABILITY", "actor": M.AXE, "target": "e1",
     "inflictor": M.CAST_ABILITY, "target_hero": True},
    {"t": 10.0, "type": "MODIFIER_ADD", "target": "e1", "inflictor": M.DEBUFF},
    {"t": 14.0, "type": "ABILITY", "actor": M.AXE, "target": "e1",
     "inflictor": M.CAST_ABILITY, "target_hero": True},
]


def _scan(tl, tmp="/tmp/_axebh_wrapper.json"):
    with open(tmp, "w") as fh:
        json.dump(tl, fh)
    try:
        return M.scan_timeline(tmp)
    finally:
        os.unlink(tmp)


class TestShardTermIsBehavioural(unittest.TestCase):
    def test_inventory_item_is_not_the_gate_term(self):
        """Holding item_aghanims_shard must not by itself remove the episode.

        This is the manufactured zero, pinned from the other side: if a future
        edit wires the inventory back into `axe_has_shard`, this fails.
        """
        r = _scan(_tl(BASE, axe_items=[M.SHARD_ITEM]))
        self.assertEqual(len(r["episodes"]), 1)
        self.assertFalse(r["episodes"][0]["axe_has_shard"])
        self.assertTrue(r["episodes"][0]["shard_item_in_inventory"])

    def test_call_applying_battle_hunger_dates_the_shard(self):
        ev = BASE + [
            {"t": 8.0, "type": "ABILITY", "actor": M.AXE, "target": "",
             "inflictor": M.CALL_ABILITY},
            {"t": 8.0, "type": "MODIFIER_ADD", "target": "e2", "inflictor": M.DEBUFF},
        ]
        r = _scan(_tl(ev))
        self.assertEqual(r["shard_onset_t"], 8.0)
        self.assertTrue(r["episodes"][0]["axe_has_shard"])
        self.assertEqual(M.aggregate([r])["n_episodes_in_gate_domain"], 0)

    def test_a_call_that_applies_nothing_is_not_a_shard(self):
        ev = BASE + [{"t": 8.0, "type": "ABILITY", "actor": M.AXE, "target": "",
                      "inflictor": M.CALL_ABILITY}]
        self.assertIsNone(M.shard_onset(ev))
        self.assertFalse(_scan(_tl(ev))["episodes"][0]["axe_has_shard"])

    def test_onset_after_the_episode_keeps_it_in_domain(self):
        ev = BASE + [
            {"t": 40.0, "type": "ABILITY", "actor": M.AXE, "target": "",
             "inflictor": M.CALL_ABILITY},
            {"t": 40.0, "type": "MODIFIER_ADD", "target": "e2", "inflictor": M.DEBUFF},
        ]
        r = _scan(_tl(ev))
        self.assertEqual(r["shard_onset_t"], 40.0)
        self.assertFalse(r["episodes"][0]["axe_has_shard"])


class TestKillConfirmColumn(unittest.TestCase):
    def test_death_inside_window_is_attributed_and_split_out(self):
        ev = BASE + [{"t": 16.0, "type": "DEATH", "actor": M.AXE, "target": "e1",
                      "inflictor": "axe_culling_blade"}]
        r = _scan(_tl(ev))
        self.assertEqual(r["episodes"][0]["target_died_in"], 2.0)
        agg = M.aggregate([r])
        self.assertEqual(agg["n_target_died_within_5s"], 1)
        self.assertEqual(agg["n_episodes_target_survived"], 0)

    def test_death_outside_window_is_not(self):
        ev = BASE + [{"t": 30.0, "type": "DEATH", "actor": M.AXE, "target": "e1",
                      "inflictor": "axe_culling_blade"}]
        r = _scan(_tl(ev))
        self.assertIsNone(r["episodes"][0]["target_died_in"])
        self.assertEqual(M.aggregate([r])["n_episodes_target_survived"], 1)


class TestCountColumnDiscipline(unittest.TestCase):
    def test_no_median_is_reported_for_the_count_column(self):
        """Iron rule 4(ii): integer-valued, small-support counts get a
        distribution and threshold shares, never a median."""
        agg = M.aggregate([_scan(_tl(BASE))])
        self.assertFalse([k for k in agg if "median" in k or k.startswith("med_")])
        self.assertIn("unhungered_in_range_dist", agg)
        self.assertIn("share_ge1_candidates", agg)

    def test_branch_stratification_is_declared_blind_not_guessed(self):
        agg = M.aggregate([_scan(_tl(BASE))])
        self.assertIn("INSTRUMENT-BLIND", agg["column4_branch_stratification"])


if __name__ == "__main__":
    unittest.main()
