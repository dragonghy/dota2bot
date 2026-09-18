#!/usr/bin/env python3
"""[ratchet] The ring-SUBJECT census: who anchors a ring on the ASKER, and who
reads a side-flag off an anchor that is not self.

WHY THIS FILE EXISTS.  strategy 2026-09-17T16:xxZ went after the lever the
previous round registered as "next round's first choice" -- `J.IsOtherAllysTarget`
and `J.IsAllysTarget` both centre their 800 ring on the ASKER while the question
("has somebody already got this unit") is about the UNIT.  Every exit priced to
ZERO, and the numbers are the point:

  * `J.IsOtherAllysTarget`: the shipped `#hAllyList <= 1` guard fires on 984 of
    1039 live hero frames (`ally2plus` = 55).  Frames that have BOTH >=2 allies
    in the asker's ring AND an ally near a visible enemy that the ring cannot
    see: 0 of 1039.  Moving the guard onto the wider list instead makes the
    lever live only when the UNPROMOTED `soloclaim` is also armed -- the
    `pullcad` conjunction trap (GH #622).  So: no independent lever.
  * `J.IsAllysTarget`: 16 of 16 call sites pass a creep, a neutral or a tower,
    and the corpus is 112 fixtures / 1120 hero units / **0 non-hero units**.
    Unpriceable, not unimportant.

⛔ SO THE CENSUS IS THE DELIVERABLE, NOT A LEVER.  Each row below carries the
REASON it is not a lever.  A NEW asker-anchored ring, or a new name/flag
disagreement, fails this test at push time -- in front of the person who wrote
it, which is the GH #624 failure mode (a census red found hours later by the
next desk) turned around.

⛔ EVERY REASON HERE DEPENDS ON ONE CONTRACT: `bEnemy` is relative to the
ANCHOR, not to the executing bot.  Section 2 asserts that contract against the
instrument, because if it ever flips, every "reads our own team" row below
silently becomes wrong.
"""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "agent"))

from lua_corpus import (  # noqa: E402
    UNCERTIFIABLE_EXIT, bots_lua_relpaths, read_lua, uncertifiable)

SUBJECT_PARAMS = ('unit', 'uUnit', 'hUnit', 'target', 'hTarget', 'nTarget',
                  'vLoc', 'nLoc', 'targetLoc', 'vTargetLoc')

# path -> function -> why this asker-anchored ring is NOT a lever today.
# ⛔ A reason is a MEASUREMENT or a source fact, never a preference.
ASKER_ANCHORED = {
    ('bots/FunLib/jmz_func.lua', 'J.IsOtherAllysTarget'):
        'domain 0/1039 with the shipped guard intact; widening the guard '
        'conjoins with unpromoted soloclaim (pullcad, GH #622)',
    ('bots/FunLib/jmz_func.lua', 'J.IsAllysTarget'):
        '16/16 call sites pass a creep/neutral/tower; corpus has 0 non-hero '
        'units',
    ('bots/FunLib/jmz_func.lua', 'J.IsHeroBetweenMeAndLocation'):
        'CORRECT BY INTENT: "between ME and" -- the asker IS the subject, and '
        'it reads BOTH sides off self by flipping the flag',
    ('bots/FunLib/jmz_func.lua', 'J.IsEnemyBetweenMeAndLocation'):
        'CORRECT BY INTENT: same family, enemy half',
    ('bots/FunLib/jmz_func.lua', 'J.GetVulnerableUnitNearLoc'):
        'CORRECT BY INTENT: the ring is nCastRange from the CASTER, then '
        'filtered to within nRadius of vLoc',
    ('bots/FunLib/jmz_func.lua', 'J.IsLaneFrontTooDeepToHold'):
        'already priced and registered by a prior round: loader refuses '
        'GetLaneFrontLocation (GH #61), lane geometry owed (GH #648/#652)',
    ('bots/FunLib/jmz_func.lua', 'J.GetAttackEnemysAllyCreepCount'):
        'creep ring; corpus has 0 non-hero units',
    ('bots/FunLib/jmz_func.lua', 'J.GetAllyCreepNearLoc'):
        'creep ring; corpus has 0 non-hero units',
    ('bots/FunLib/aba_push.lua', 'updateBotStateCache'):
        'creep ring; corpus has 0 non-hero units',
    ('bots/FunLib/jmz_func.lua', 'J.IsRoamAllysTarget'):
        'third copy of the same shape; args are creeps/neutrals, and '
        'GetTarget/GetAttackTarget is bot-VM state the .dem omits (GH #27).  '
        'RELOCATED 2026-09-18 (claimlone): this body was '
        'mode_team_roam_generic.lua X.IsAllysTarget, moved into jmz_func so a '
        'fixture test could reach it; the mode file now delegates one line and '
        'has no ring of its own.  The RING-SUBJECT defect this row prices is '
        'unchanged and still not a lever.  What DID move is a different defect '
        'in the same function -- the `#allies < 2` lone-ally guard, i.e. the '
        'one soloclaim repaired in J.IsOtherAllysTarget -- and this row is '
        'exactly why nobody carried it across: a triaged row reads as handled.',
    ('bots/mode_team_roam_generic.lua', 'X.IsEnemysTarget'):
        'same; J.GetProperTarget is nil on 1039/1039 frames (GH #27)',
}

# The proven outlier: a side-flag read off an anchor that is NOT self.
# jmz_func.lua:14276 does `J.GetNearbyHeroes(hTarget, 1600, true, ...)` and
# names the result nEnemyHeroes -- but `true` off an ENEMY anchor is OUR OWN
# team, so loop 2 rescans allies and the enemy team is never scanned at all.
WRONG_ANCHOR_FLAG_FN = 'J.IsAllyHeroBetweenMeAndTarget'
WRONG_ANCHOR_CALLSITE = 'bots/FunLib/rubick_hero/rattletrap.lua'


def read(rel):
    """⛔ Every corpus read goes through lua_corpus.read_lua (GH #856): a file
    that vanishes mid-scan must become "did not run" (exit 2), never a count
    that quietly moved. This round paid for that distinction the hard way --
    the round's own 开工自检 read jmz_func.lua WHILE the mutation stand was
    rewriting it, and reported a syntax error and three FALLEN frame counts as
    if they were trunk findings."""
    return read_lua(os.path.join(ROOT, rel))


def lua_files():
    """The shared corpus walk, not an open-coded os.walk of bots/ --
    tests/test_lua_corpus_stability.py makes that the contract."""
    return bots_lua_relpaths(ROOT)


def strip_comments(src):
    return re.sub(r'--[^\n]*', '', src)


FUNC_RE = re.compile(r'function\s+([\w.]+)\s*\(([^)]*)\)')
RING_RE = re.compile(r'(GetNearbyHeroes|GetNearbyCreeps|GetNearbyTowers)\s*\(([^)]*)\)')


def functions(src):
    """Yield (name, args, body) for every function in already-stripped src."""
    for m in FUNC_RE.finditer(src):
        end = src.find('\nend', m.end())
        yield m.group(1), m.group(2), src[m.end():end if end != -1 else len(src)]


class TestRingSubjectCensus(unittest.TestCase):

    # ===================== 1. the asker-anchored census
    def test_asker_anchored_set_is_exactly_the_triaged_set(self):
        found = {}
        n_subject_fns = 0
        for rel in lua_files():
            src = strip_comments(read(rel))
            for name, args, body in functions(src):
                subj = next((k for k in SUBJECT_PARAMS
                             if re.search(r'\b%s\b'.replace('%s', k), args)), None)
                if not subj:
                    continue
                n_subject_fns += 1
                if not re.search(r'\b%s\b'.replace('%s', subj), body):
                    continue
                for m in RING_RE.finditer(body):
                    anchor_args = m.group(2)
                    prefix = body[max(0, m.start() - 24):m.start()]
                    anchored_on_self = (
                        re.search(r'\bbot\s*[:.,]?\s*$', prefix) is not None
                        or re.match(r'\s*bot\s*,', anchor_args) is not None
                        or 'GetBot()' in prefix or 'GetBot()' in anchor_args)
                    if anchored_on_self:
                        found[(rel, name)] = True
                        break

        expected = set(ASKER_ANCHORED)
        self.assertGreater(n_subject_fns, 150,
                           'the scanner stopped finding subject-taking '
                           'functions -- it is not measuring any more')
        new = sorted(set(found) - expected)
        gone = sorted(expected - set(found))
        self.assertEqual([], new, (
            'NEW asker-anchored ring(s) in a function whose question is about '
            'its subject. Either fix the ring, or add a row to '
            'ASKER_ANCHORED with the REASON it is not a lever: %s' % (new,)))
        self.assertEqual([], gone, (
            'a triaged asker-anchored ring disappeared -- if it was repaired, '
            'delete its row and say so in the report: %s' % (gone,)))

    # ===================== 2. the contract every reason above rests on
    def test_bEnemy_is_anchor_relative_in_the_instrument(self):
        """If this flips, every 'reads our own team' reason above is wrong."""
        mock = read('tests/mock/replay_fixture.lua')
        self.assertIn('other:GetTeam() ~= self:GetTeam()', mock,
                      'the instrument no longer derives bEnemy from the RING '
                      "ANCHOR's team. The whole census triage above assumes "
                      'anchor-relative semantics -- re-price it.')

    # ===================== 3. the parked lever, and its trigger
    def test_wrong_anchor_flag_defect_is_still_exactly_one_callsite(self):
        src = read('bots/FunLib/jmz_func.lua')
        at = src.find('function ' + WRONG_ANCHOR_FLAG_FN)
        self.assertNotEqual(-1, at, WRONG_ANCHOR_FLAG_FN + ' is gone')
        body = src[at:src.find('\nend', at)]
        # The defect itself, in source: a `true` flag off the hTarget anchor.
        self.assertIsNotNone(
            re.search(r'GetNearbyHeroes\(\s*hTarget\s*,\s*\d+\s*,\s*true',
                      body),
            'the hTarget-anchored `true` ring is gone from '
            + WRONG_ANCHOR_FLAG_FN + '. If it was REPAIRED, this row and the '
            'report section that parks it both need updating.')
        # ⭐ THE REDUCTIO, pinned so nobody has to re-derive it: the loop that
        # scans that list rejects only hSource. If the list really held
        # ENEMIES, hTarget itself sits at vEnd -- distance 0, `within` true --
        # so the function would return TRUE on every call and the branch that
        # calls it could never fire. It fires, so the list is not enemies.
        self.assertIn('enemyHero ~= hSource', body,
                      'the loop no longer rejects only hSource; the reductio '
                      'that proves the list holds ALLIES rested on that')
        self.assertNotIn('~= hTarget', body,
                         'a hTarget exclusion appeared -- that is the repair, '
                         'and it changes what this row parks')

        # ⛔ Count CALLS, not the definition: `function J.IsAlly...(` matches
        # the same needle and would hide the day a second consumer appears.
        call_re = re.compile(r'(?<!function )' + re.escape(WRONG_ANCHOR_FLAG_FN)
                             + r'\s*\(')
        sites = [rel for rel in lua_files()
                 if call_re.search(strip_comments(read(rel)))]
        self.assertEqual([WRONG_ANCHOR_CALLSITE], sites, (
            'the call-site set moved. The lever is parked ONLY because its '
            'one consumer is Rubick-stolen-Clockwerk logic: %s' % (sites,)))

    def test_parked_reason_is_rederived_not_trusted(self):
        """⭐ The reason this lever is parked is an EXTERNAL fact that can
        change: Rubick is absent from the draft pool, so the one call site
        cannot execute in any batch game. Nothing would notice the day that
        changes -- so re-derive it instead of quoting the report."""
        pool = read('tools/batch_test/soak/hero_pool.txt').lower()
        self.assertNotIn('rubick', pool, (
            'RUBICK IS NOW IN THE DRAFT POOL. The '
            + WRONG_ANCHOR_FLAG_FN + ' defect (jmz_func.lua, hTarget-anchored '
            '`true` ring => rescans allies, never scans the enemy team) was '
            'parked with in-game domain 0 for exactly this reason. It is now '
            'reachable: ship it as a gated, turbo-only, ADDITIVE lever '
            '(J.GetEnemiesNearLoc(vEnd, 1600), excluding hTarget and '
            'hSource), which is FALSE->TRUE only and so a pure narrowing of '
            'the permission to fire into a body-block.'))


if __name__ == '__main__':
    # Every case here drives a REAL tree scan, so a file that vanishes
    # mid-scan surfaces as a unittest ERROR -- which prints identically to
    # "the census answer changed". The result object is the only place left to
    # tell the two apart: a traceback naming CorpusVanished means the scan
    # never read its input, and that is exit 2 (did not run), not exit 1.
    _prog = unittest.main(verbosity=0, exit=False)
    _vanished = [tb for _case, tb in _prog.result.errors
                 if 'CorpusVanished' in tb]
    if _vanished:
        uncertifiable(_vanished[0].strip().splitlines()[-1],
                      'tests/test_ring_subject_census.py')
        sys.exit(UNCERTIFIABLE_EXIT)          # unreachable; kept explicit
    sys.exit(0 if _prog.result.wasSuccessful() else 1)
