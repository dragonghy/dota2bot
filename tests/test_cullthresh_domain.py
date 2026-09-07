"""Adversarial wrapper around tools/batch_test/behavioral/cullthresh_domain.py.

`--selfcheck` proves the scanner agrees with itself.  This file exists for the
other half: three corpus shapes that would have MANUFACTURED this round's
headline, each pinned from the negative side so the tool has to refuse them.

The headline being protected is "the `cullthresh` domain IS reached -- 501
crossings in 69/69 games, 98 band-occupied frames, 28 of them inside 175u".
Every previous round in this stream that reported a domain reading had a way
to conjure one; the three below are the ways available here.
"""

import os
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..",
                                "tools", "batch_test", "behavioral"))

import cullthresh_domain as C  # noqa: E402


AXE = C.AXE
L = "npc_dota_hero_lina"


def snap(t, hero, idx, team, x, hp, hp_pct=1.0, mp=1000, rank=1, cd=0):
    return {"t": t, "hero": hero, "idx": idx, "team": team, "x": x, "y": 0.0,
            "hp": hp, "hp_pct": hp_pct, "mp": mp, "level": 10, "items": [],
            "abilities": [{"name": C.CULL, "level": rank, "cd": cd,
                           "cd_len": 80}]}


def tl(snaps, events=None, teams=None):
    return {"game": {"teams": teams or {AXE: 2, L: 3}},
            "snapshots": snaps, "events": events or []}


class BandIsReadOffTheCode(unittest.TestCase):
    """The band is [150+100lv, damage[lv]), not the prose's (lo, hi].

    The queue row, GH #115 and the helper header all write the domain as a
    half-open interval opening the OTHER way.  The comparison in ConsiderR is
    `hp_eff < nKillDamage`, so 250 is inside the domain and 275 is outside it.
    Taking the prose literally moves both endpoints by one and silently
    changes which frames are pinnable -- this round's rank-2 centaur frame
    (hp exactly 350) exists only under the code's version.
    """

    def test_lower_endpoint_is_included(self):
        self.assertEqual(C.band(1), (250, 275))
        r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                            snap(1.0, L, 2, 3, 100, 250)]), "g")
        self.assertEqual(len(r["band_rows"]), 1)

    def test_upper_endpoint_is_excluded(self):
        r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                            snap(1.0, L, 2, 3, 100, 275)]), "g")
        self.assertEqual(r["band_rows"], [])

    def test_every_rank_band_is_25_wide(self):
        for rank in (1, 2, 3):
            lo, hi = C.band(rank)
            self.assertEqual(hi - lo, 25)
            self.assertEqual(lo, 150 + 100 * rank)
            self.assertEqual(hi, C.CULL_LIVE_DAMAGE[rank - 1])


class IllusionsDoNotManufactureDomain(unittest.TestCase):
    """The first way to conjure a domain here, and it is not hypothetical.

    Illusions carry a fraction of the hero's health, so a Manta/Chaos Knight
    illusion sits in a 25-point execute band far more often than the hero
    does -- and it shares the hero's NAME in the dump.  This corpus discarded
    656,762 illusion samples across 69 games; had they been counted, every
    number in the round's report would be an illusion census wearing a hero's
    name.  GH #176's guard is birth time: the real hero is the entity present
    at that name's own earliest sample.
    """

    def test_late_born_entity_is_discarded(self):
        snaps = [snap(1.0, AXE, 1, 2, 0, 2000), snap(1.0, L, 2, 3, 100, 900),
                 snap(2.0, AXE, 1, 2, 0, 2000), snap(2.0, L, 2, 3, 100, 900),
                 snap(2.0, L, 99, 3, 100, 260)]
        r = C.scan_game(tl(snaps), "g")
        self.assertEqual(r["discarded_illusion_samples"], 1)
        self.assertEqual(r["band_rows"], [])

    def test_illusion_modifier_is_also_excluded_directly(self):
        # belt and braces: X.HasSpecialModifier names modifier_illusion, so an
        # illusion that somehow won the birth race is still refused.
        ev = [{"t": 0.5, "type": "MODIFIER_ADD", "target": L,
               "inflictor": "modifier_illusion"}]
        r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                            snap(1.0, L, 2, 3, 100, 260)], ev), "g")
        self.assertEqual(r["band_rows"], [])


class CrossingsAreDirectionalAndBounded(unittest.TestCase):
    """The second way: count every adjacent pair that straddles the band.

    The crossing caliber only means anything if it counts DESCENTS through the
    band.  Counting rises too (a regenerating hero climbing back past 260, a
    respawn) would roughly double the headline for free, and counting segments
    that merely lie near the band would inflate it further.
    """

    def test_rising_health_is_not_a_crossing(self):
        snaps = [snap(1.0, AXE, 1, 2, 0, 2000), snap(1.0, L, 2, 3, 100, 200),
                 snap(2.0, AXE, 1, 2, 0, 2000), snap(2.0, L, 2, 3, 100, 400)]
        self.assertEqual(C.scan_game(tl(snaps), "g")["crossings"], [])

    def test_segment_must_actually_touch_the_band(self):
        for a, b in ((900, 400), (240, 100), (275, 275)):
            snaps = [snap(1.0, AXE, 1, 2, 0, 2000),
                     snap(1.0, L, 2, 3, 100, a),
                     snap(2.0, AXE, 1, 2, 0, 2000),
                     snap(2.0, L, 2, 3, 100, b)]
            self.assertEqual(C.scan_game(tl(snaps), "g")["crossings"], [],
                             f"{a} -> {b} must not count")

    def test_capture_probability_is_capped_at_one(self):
        # a slow crossing must not report p > 1 and inflate the expected-capture
        # sum the report prints as an UPPER bound.
        snaps = [snap(1.0, AXE, 1, 2, 0, 2000), snap(1.0, L, 2, 3, 100, 272),
                 snap(2.0, AXE, 1, 2, 0, 2000), snap(2.0, L, 2, 3, 100, 270)]
        c = C.scan_game(tl(snaps), "g")["crossings"]
        self.assertEqual(len(c), 1)
        self.assertLessEqual(c[0]["p_capture"], 1.0)


class ReadinessAndEligibilityAreNotAssumed(unittest.TestCase):
    """The third way: count instants where the branch could not have run.

    A domain census that ignores cooldown, mana, rank or the exclusion list is
    counting the map, not the branch.  Culling Blade's cooldown is 80/75/70s
    and Axe casts it ~6.5 times a game, so "ignore cd" alone would multiply
    the ready-frame denominator several-fold.
    """

    def test_cooldown_mana_and_rank_all_gate_the_frame(self):
        base = [snap(1.0, AXE, 1, 2, 0, 2000), snap(1.0, L, 2, 3, 100, 260)]
        self.assertEqual(len(C.scan_game(tl(base), "g")["band_rows"]), 1)
        for mut, tag in (
                (lambda s: s.update(mp=99), "mana below 100"),
                (lambda s: s["abilities"][0].update(cd=3.0), "on cooldown"),
                (lambda s: s["abilities"][0].update(level=0), "untrained")):
            snaps = [snap(1.0, AXE, 1, 2, 0, 2000),
                     snap(1.0, L, 2, 3, 100, 260)]
            mut(snaps[0])
            self.assertEqual(C.scan_game(tl(snaps), "g")["band_rows"], [],
                             f"{tag} must not produce a band row")

    def test_magic_immune_and_aegis_targets_are_refused(self):
        for mod in ("modifier_black_king_bar_immune", "modifier_item_aegis",
                    "modifier_item_aeon_disk_buff"):
            ev = [{"t": 0.5, "type": "MODIFIER_ADD", "target": L,
                   "inflictor": mod}]
            r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                                snap(1.0, L, 2, 3, 100, 260)], ev), "g")
            self.assertEqual(r["band_rows"], [], mod)

    def test_ring_is_375_not_the_bare_cast_range(self):
        # the loop reads GetAroundEnemyHeroList(nCastRange + 200); the bare
        # 175u list is computed and never read.  Both are reported, but the
        # ring that counts is 375.
        r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                            snap(1.0, L, 2, 3, 300, 260)]), "g")
        self.assertEqual(len(r["band_rows"]), 1)
        self.assertFalse(r["band_rows"][0]["inside_175"])
        r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                            snap(1.0, L, 2, 3, 376, 260)]), "g")
        self.assertEqual(r["band_rows"], [])


class ControlColumnIsNotThePayoffColumn(unittest.TestCase):
    """The band and the shipped-line control must never pool.

    The round reports both: 98 band frames (what the lever would ADD) and 632
    instants already under the shipped line (whether the branch the lever
    widens fires at all).  Adding them would report a domain 7x too large --
    the 2026-08-28 attribution rule (charter 4a) in its simplest form.
    """

    def test_a_frame_is_in_exactly_one_column(self):
        for hp, band_n, ctl_n in ((200, 0, 1), (260, 1, 0), (300, 0, 0)):
            r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                                snap(1.0, L, 2, 3, 100, hp)]), "g")
            self.assertEqual(len(r["band_rows"]), band_n, hp)
            self.assertEqual(len(r["shipped_rows"]), ctl_n, hp)


class ContainmentIsHalfOpen(unittest.TestCase):
    """`add <= t < remove`, and the right endpoint is a SIGN FLIP not a rounding
    detail.

    Until 2026-09-07 `active_modifiers` used CLOSED containment.  A cast that
    KILLS its target removes the buff in the same 0.1s bucket, so the
    MODIFIER_REMOVE lands at exactly the cast timestamp -- closed containment
    then reads "fired while the buff was live" off the cast that ENDED the
    buff, and those two have opposite sign.  The rows below are the real ones
    from `20260828_124358_slot1__spot_20260828_121642_..._11c470`, the single
    game GH #570 drew both of its hits from; frozen with the surrounding
    arithmetic in tests/test_axe_cull_promise_premise.lua section 6.

    Pinned BEHAVIOURALLY, not as a source string: section 7 of that Lua file
    reads the comparison out of both instruments' text, which catches a drift
    but cannot say which way the drift decides.  The director wrote the
    premise into the ruling itself (`queue.json:hero-39` = APPROVED-SCAN,
    half-open mandatory -- iterations/reports/director/20260906T222000Z.md
    section 2).
    """

    # target, add, remove -- verbatim from the frozen WINDOWS table
    W_SNIPER = ("npc_dota_hero_sniper", 953.8, 958.7)
    W_ORACLE = ("npc_dota_hero_oracle", 1452.7, 1452.9)

    @staticmethod
    def _iv(target, add, remove, name="modifier_illusion"):
        ev = [{"t": add, "type": "MODIFIER_ADD", "target": target,
               "inflictor": name},
              {"t": remove, "type": "MODIFIER_REMOVE", "target": target,
               "inflictor": name}]
        return C.build_modifier_intervals(ev, {name})

    def test_left_endpoint_is_included(self):
        tgt, add, rem = self.W_SNIPER
        iv = self._iv(tgt, add, rem)
        self.assertEqual(C.active_modifiers(iv, tgt, add), {"modifier_illusion"})

    def test_right_endpoint_is_excluded(self):
        for tgt, add, rem in (self.W_SNIPER, self.W_ORACLE):
            iv = self._iv(tgt, add, rem)
            self.assertEqual(
                C.active_modifiers(iv, tgt, rem), set(),
                f"{tgt} @ {rem} sits ON the right endpoint: the cull's own kill "
                f"removed the buff.  Counting it is GH #570's miscount.")

    def test_strictly_inside_is_still_seen(self):
        # the negative control for the two above: half-open must not be a way
        # of never seeing anything.  A cull landing strictly inside a live
        # window is the frame GH #570 always needed and never had.
        tgt, add, rem = self.W_SNIPER
        iv = self._iv(tgt, add, rem)
        self.assertEqual(C.active_modifiers(iv, tgt, (add + rem) / 2.0),
                         {"modifier_illusion"})

    def test_still_open_window_has_no_right_endpoint(self):
        # build_modifier_intervals closes a dangling ADD at +inf; half-open
        # must not turn that into "never active".
        ev = [{"t": 953.8, "type": "MODIFIER_ADD",
               "target": self.W_SNIPER[0], "inflictor": "modifier_illusion"}]
        iv = C.build_modifier_intervals(ev, {"modifier_illusion"})
        self.assertEqual(C.active_modifiers(iv, self.W_SNIPER[0], 9999.0),
                         {"modifier_illusion"})

    def test_a_removal_on_the_sample_tick_does_not_veto_the_band_row(self):
        # the same endpoint, one layer up, where it decides a domain count:
        # REMOVE at exactly the snapshot's t must free the frame, ADD at
        # exactly the snapshot's t must veto it.
        rem = [{"t": 0.5, "type": "MODIFIER_ADD", "target": L,
                "inflictor": "modifier_item_aeon_disk_buff"},
               {"t": 1.0, "type": "MODIFIER_REMOVE", "target": L,
                "inflictor": "modifier_item_aeon_disk_buff"}]
        r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                            snap(1.0, L, 2, 3, 100, 260)], rem), "g")
        self.assertEqual(len(r["band_rows"]), 1,
                         "the buff came off ON this tick; the frame is in domain")

        add = [{"t": 1.0, "type": "MODIFIER_ADD", "target": L,
                "inflictor": "modifier_item_aeon_disk_buff"}]
        r = C.scan_game(tl([snap(1.0, AXE, 1, 2, 0, 2000),
                            snap(1.0, L, 2, 3, 100, 260)], add), "g")
        self.assertEqual(r["band_rows"], [],
                         "the buff went ON at this tick; the frame is refused")


class SelfcheckStillPasses(unittest.TestCase):
    def test_selfcheck_exits_zero(self):
        tool = os.path.join(os.path.dirname(__file__), "..", "tools",
                            "batch_test", "behavioral",
                            "cullthresh_domain.py")
        p = subprocess.run([sys.executable, tool, "--selfcheck"],
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("0 FAIL", p.stdout)


if __name__ == "__main__":
    unittest.main()
