#!/usr/bin/env python3
"""Ratchet for tools/agent/argmax_ring_census.py (hero group, 2026-09-17).

WHAT THIS FILE PINS, AND WHY IT DELIBERATELY DOES NOT PIN THE TREE-WIDE COUNT
----------------------------------------------------------------------------
The census walks all 127 shipped hero files.  A ratchet that asserted "the set
of copies is exactly today's set" would be GH #624's shape verbatim: ANY group
landing a new branch with this argmax body turns it red, the red names a file
the author never touched, and it is found hours later by whoever opens next.
So this file pins two things and reports the third:

  (1) THE PARSER'S OWN CORRECTNESS -- properties that must hold no matter what
      the tree looks like.  These are the assertions that would have caught the
      three defects this census actually had while it was being written:
        - a bare literal ring read as CONSISTENT (it is UNCOMPARABLE: source
          cannot say whether a fixed 1600u ring is inside the cast range);
        - a base trusted because it is SPELLED `nCastRange` rather than because
          it is assigned from `GetCastRange()`;
        - a fanout count that merged four same-named `local`s into one variable
          (hero_arc_warden.lua declares `nInRangeEnemy` four separate times).
  (2) THE ROWS THIS GROUP OWNS -- the three focus-five copies, which are the
      table GH #873 §二 published.  If one of those rings moves, the reading in
      that issue is stale and the red says so on the change that moved it.
  (3) The tree-wide totals are PRINTED, not asserted.

⛔ (2) is also the anti-drift term for GH #873 itself: that issue's table says
Crystal Maiden is correct, Wraith King over-reaches 43u and Lion self-vetoes a
250u annulus.  Those three claims are quoted elsewhere (queue `hero-102`,
`state.json:lionwfight_20260917`, tests/test_lion_w_fight_reach.lua §2), so they
need one place that goes red when they stop being true.
"""

import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'agent'))

import argmax_ring_census as arc  # noqa: E402


def rows_by_site():
    rows, _unresolved = arc.census(ROOT)
    return {(r['file'], r['line']): r for r in rows}


class TestParserCorrectness(unittest.TestCase):
    """(1) properties that hold whatever the tree looks like."""

    def test_selfcheck_passes_through_its_own_entry_point(self):
        # ⛔ Run the script the way a reader runs it, and read the process's own
        # exit code -- not a pipe's (evidence discipline 3).
        proc = subprocess.run(
            [sys.executable, os.path.join(ROOT, 'tools', 'agent', 'argmax_ring_census.py'),
             '--selfcheck'],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT)
        self.assertEqual(proc.returncode, 0, proc.stdout.decode('utf-8', 'replace'))
        self.assertIn(b'ALL PASS', proc.stdout)

    def test_a_numeric_ring_parses_as_a_literal_not_as_an_identifier(self):
        """⭐ This assertion exists because its mutant SURVIVED without it.

        The first version's base regex was `^(\\w+)$`, and `\\w` includes
        digits, so `1600` parsed as an identifier named "1600".  Restoring that
        regex does NOT flip any verdict today -- the provenance guard rejects a
        base named `1600` too, for the different reason that nothing assigns it
        from `GetCastRange()` -- so the two guards overlap and the row stays
        UNCOMPARABLE either way.  ⛔ What DOES change is the sentence the table
        hands a reader: "the searched ring is the bare literal 1600" becomes
        "base `1600` is never assigned from GetCastRange()", which is not a
        thing anyone can act on.  A census is read, so the diagnosis is part of
        the output, not commentary on it.
        """
        self.assertEqual(arc.parse_ring('1600')[0], arc.LITERAL_BASE)
        self.assertEqual(arc.parse_ring('1600')[1], 1600.0)
        self.assertEqual(arc.parse_ring('nCastRange')[0], 'nCastRange')
        rows = rows_by_site()
        necro = rows[('bots/BotLib/hero_necrolyte.lua', 643)]
        self.assertEqual(necro['search_base'], arc.LITERAL_BASE)
        self.assertIn('literal', necro['why'])

    def test_a_bare_literal_ring_is_never_consistent(self):
        v, why = arc.classify({
            'search_ring': '1600', 'search_base': arc.LITERAL_BASE, 'search_delta': 1600.0,
            'admission_ring': None, 'admission_place': 'none'})
        self.assertEqual(v, 'UNCOMPARABLE', why)

    def test_a_base_is_trusted_from_provenance_not_from_its_name(self):
        named_but_unproven = arc.classify({
            'search_ring': 'nCastRange', 'search_base': 'nCastRange', 'search_delta': 0.0,
            'base_is_cast_range': False,
            'admission_ring': None, 'admission_place': 'none'})
        self.assertEqual(named_but_unproven[0], 'UNCOMPARABLE', named_but_unproven[1])
        proven = arc.classify({
            'search_ring': 'nCastRange', 'search_base': 'nCastRange', 'search_delta': 0.0,
            'base_is_cast_range': True,
            'admission_ring': None, 'admission_place': 'none'})
        self.assertEqual(proven[0], 'CONSISTENT', proven[1])

    def test_the_place_of_the_reach_test_changes_the_verdict(self):
        """Same two rings, two places, two different consequences.

        This is the whole thesis of GH #873 §一: a reach test inside the loop
        filter cannot self-veto, because a rejected candidate never wins and the
        argmax falls back.  The same test on the winner ONLY kills the branch.
        """
        pair = {'search_ring': 'R + 300', 'search_base': 'R', 'search_delta': 300.0,
                'admission_ring': 'R + 50', 'admission_base': 'R', 'admission_delta': 50.0}
        post = dict(pair, admission_place='post-loop')
        inl = dict(pair, admission_place='in-loop')
        self.assertEqual(arc.classify(post)[0], 'SELF-VETO')
        self.assertEqual(arc.classify(inl)[0], 'FILTERED')

    def test_a_winner_test_wider_than_the_search_ring_is_vacuous(self):
        v, _why = arc.classify({
            'search_ring': 'R', 'search_base': 'R', 'search_delta': 0.0,
            'admission_ring': 'R + 50', 'admission_base': 'R', 'admission_delta': 50.0,
            'admission_place': 'post-loop'})
        self.assertEqual(v, 'VACUOUS-TEST')

    def test_shadowed_bindings_are_not_counted_as_co_readers(self):
        """hero_arc_warden.lua declares `nInRangeEnemy` four separate times.

        The first version of the fanout column reported 13 co-readers for a list
        that has none; the number is load-bearing (it is what says whether a gap
        is this leg's to fix), so the shadowing correction is pinned here on the
        row that exposed it.
        """
        row = rows_by_site()[('bots/BotLib/hero_arc_warden.lua', 254)]
        self.assertEqual(row['other_reads'], [], row['other_reads'])
        self.assertGreater(row['shadowed_reads'], 0)

    def test_every_builder_shape_the_tree_uses_at_these_sites_is_resolved(self):
        """⛔ The tree-wide table is reported, not asserted (see the header), so
        a resolver regression on a non-focus hero would otherwise be silent.
        These four shapes are pinned as a PROPERTY instead: they are the four
        the corpus actually uses, and losing one turns some hero's row into
        UNRESOLVED with nothing raising a hand.
        """
        self.assertEqual(
            arc.ring_of_rhs('J.GetNearbyHeroes(bot, nCastRange + 43, true, BOT_MODE_NONE )')[0],
            'nCastRange + 43')
        self.assertEqual(
            arc.ring_of_rhs('bot:GetNearbyHeroes( nCastRange + 299, true, BOT_MODE_NONE )')[0],
            'nCastRange + 299')
        expr, how = arc.ring_of_rhs('J.GetEnemyList( bot, nCastRange + 420 )')
        self.assertEqual(expr, 'nCastRange + 420')
        # the helper clamps at 1600 (jmz_func.lua:4506); the caller's text does
        # not say so, so the census has to carry it
        self.assertIn('clamped', how)
        self.assertEqual(arc.ring_of_rhs('J.CombineTwoTable( a, b )')[0], None)

    def test_the_block_counter_closes_every_file_it_parses(self):
        """The hand-rolled Lua block counter earns its keep only if it balances."""
        # ⛔ via lua_corpus, never os.walk + open (GH #243 / GH #856)
        checked = 0
        for rel in arc.bots_lua_relpaths(ROOT):
            text = arc.read_lua(os.path.join(ROOT, rel))
            if 'local npcMostDangerousEnemy = nil' not in text:
                continue
            _raw, clean = arc.clean_lines(text)
            _depths, tail = arc.block_depths(clean)
            self.assertEqual(tail, 0, '%s: block depth ends at %d' % (rel, tail))
            checked += 1
        self.assertGreaterEqual(checked, 15)


class TestFocusFiveRows(unittest.TestCase):
    """(2) the three rows GH #873 §二 published, and nothing this group does not own."""

    EXPECTED = {
        ('bots/BotLib/hero_crystal_maiden.lua', 1804): ('nCastRange', None, 'CONSISTENT'),
        ('bots/BotLib/hero_skeleton_king.lua', 1354): ('nCastRange + 43', None, 'OVER-REACH'),
        ('bots/BotLib/hero_lion.lua', 1554): ('nCastRange + 300', 'nCastRange + 50', 'SELF-VETO'),
    }

    def test_the_published_table_still_reads_the_way_the_issue_says(self):
        rows = rows_by_site()
        for site, (search, admission, verdict) in self.EXPECTED.items():
            self.assertIn(site, rows, 'GH #873 names %s:%d and the census no longer finds it' % site)
            r = rows[site]
            self.assertEqual(r['search_ring'], search, '%s:%d search ring' % site)
            self.assertEqual(r['admission_ring'], admission, '%s:%d admission ring' % site)
            self.assertEqual(r['verdict'], verdict, '%s:%d verdict (%s)' % (site[0], site[1], r['why']))

    def test_no_focus_five_copy_is_unresolved(self):
        """A copy this group OWNS must parse; an unowned one may not, and that
        is reported rather than asserted (see the file header)."""
        for site, r in rows_by_site().items():
            if r['attribution'] != 'focus-five':
                continue
            self.assertNotEqual(r['verdict'], 'UNRESOLVED', '%s:%d -- %s' % (site[0], site[1], r['why']))

    def test_the_fanout_column_on_the_rows_this_group_owns(self):
        """⭐ The column that says whether a gap is THIS leg's to fix.

        Wraith King's `nEnemysHerosInRange` is read by four other shipping sites
        in the same function, so the 43u in its ring is not a number this branch
        can move on its own -- which is one of the three independent reasons GH
        #873 §四 was priced DO-NOT-ARM.  Crystal Maiden's list has no other
        reader at all.  These numbers are also the ratchet on comment stripping:
        hero_skeleton_king.lua mentions the same identifier on five COMMENT
        lines, and a census that counted those would read 10 where the truth
        is 5.
        """
        rows = rows_by_site()
        wk = rows[('bots/BotLib/hero_skeleton_king.lua', 1354)]
        self.assertEqual(len(wk['other_reads']), 5, wk['other_reads'])
        self.assertEqual(wk['other_shipping_sites'], 4)
        cm = rows[('bots/BotLib/hero_crystal_maiden.lua', 1804)]
        self.assertEqual(cm['other_reads'], [])
        self.assertEqual(cm['other_shipping_sites'], 0)
        lion = rows[('bots/BotLib/hero_lion.lua', 1554)]
        self.assertEqual(lion['other_shipping_sites'], 1)

    def test_lions_self_veto_annulus_is_the_250_units_the_issue_quotes(self):
        r = rows_by_site()[('bots/BotLib/hero_lion.lua', 1554)]
        self.assertEqual(r['search_delta'] - r['admission_delta'], 250.0)
        self.assertEqual(r['admission_place'], 'post-loop')


class TestTreeWideReport(unittest.TestCase):
    """(3) printed, not asserted -- so another group's new branch is not our red."""

    def test_report(self):
        rows, _unres = arc.census(ROOT)
        counts = {}
        for r in rows:
            counts[r['verdict']] = counts.get(r['verdict'], 0) + 1
        differ = sum(counts.get(v, 0) for v in arc.DIFFER_VERDICTS)
        costly = sum(counts.get(v, 0) for v in arc.COSTLY_VERDICTS)
        sys.stderr.write(
            '\n[argmax ring census] %d copies; rings differ in %d, of which costly %d; '
            'by verdict %s\n' % (len(rows), differ, costly, sorted(counts.items())))
        self.assertGreater(len(rows), 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
