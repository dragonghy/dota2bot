#!/usr/bin/env python3
"""Corpus-free battery for `stayfield_domain.py`, the `stayfield` (a)-probe.

WHY THIS FILE EXISTS.  `tests/run_py_tests.sh` loops over `tests/test_*.py`
only, so a probe invoked solely by hand is a probe nothing in the tree runs --
the GH #243 shape, same as `tests/test_od_stall_leg.py`,
`tests/test_tpreach_domain.py` and `tests/test_fieldsip_domain.py`.
`stayfield_domain.py` was in that state until 2026-08-30 despite being the
oldest probe in the family and the one two other tools import from.

⭐ WHAT IS ACTUALLY BEING PROTECTED: THE GATED FIFTH CLAUSE.
`J.IsFieldRegenSituation` has a fifth clause that only exists when the wave
armed `fieldcreep` (jmz_func.lua:5287):

    if J.IsSoakCandidate('fieldcreep') and bot:WasRecentlyDamagedByCreep(3.0)
    then return false end

Until 2026-08-30 this file's subject scored BOTH legs with the four-clause
situation, so on every wave that armed `fieldcreep` (W25..W28 all did) the
armed leg was measured with a predicate the engine was not running.  The
failure was SILENT and it was biased in the candidate's favour: an inflated
armed denominator with an unchanged numerator lowers the armed home_tp rate,
which is exactly the number a reader quotes as "the gate works".  Measured on
W28: 102 armed-leg SITUATION frames (甲) belonged to `fieldcreep`, not to
`stayfield`.

The frame that caught it -- W28 e706a3 / 20260830_063416_slot1, seed 2130,
side=radiant so RADIANT IS ARMED, hero lich, t=625.5..634.5: coordinates
frozen for ten seconds, hp 1.000 -> 0.229, nearest enemy HERO never inside
1646u, and 774 damage from grown_frog + ancient_frog_mage.  Four-clause
reading: SITUATION TRUE.  What that leg actually ran: FALSE.

⭐⭐ THE TWO WORLDS MUST NOT COLLAPSE INTO ONE.  §AR.1: 甲 counts neutrals
toward WasRecentlyDamagedByCreep, 乙 counts lane creeps only, and nobody knows
which the engine means.  A "simplification" that keeps one of them would erase
a real uncertainty rather than resolve it, and on W28 the two differ by 33
frames (102 vs 69).  Both are pinned below, from both sides.

⭐⭐⭐ AND THE INERTNESS CASES ARE THE LOAD-BEARING ONES.  The clause must be
false wherever `J.IsSoakCandidate('fieldcreep')` is false in the engine: the
baseline leg always, and every leg of a wave that did not arm it.  Get that
wrong in the other direction and the tool starts REMOVING baseline frames --
which would flip the same bias the other way and look just as clean.  Three
separate inertness paths are pinned because they are three separate `if`s.

Corpus-half note: the subject's `--selfcheck` needs sweep dirs, which CI does
not have.  This file therefore runs the PURE half only and says so in those
words -- a reader who sees no corpus lines must conclude they were not run,
never that the corpus was clean (铁律 10's SKIP/UNCERTIFIABLE wording).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BEHAV = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral')
TOOL = os.path.join(BEHAV, 'stayfield_domain.py')

fails = []


def ok(name, cond, why=''):
    print('%-64s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


if not os.path.exists(TOOL):
    print('could not read %s' % TOOL)
    sys.exit(2)

sys.path.insert(0, BEHAV)
try:
    import stayfield_domain as SD                              # noqa: E402
except Exception as exc:                                       # pragma: no cover
    print('could not import stayfield_domain: %s' % exc)
    sys.exit(2)

print('corpus checks SKIPPED, not passed '
      '(--selfcheck needs sweep dirs; CI has none)')

# ---------------------------------------------------------------------------
# the gated clause: inert wherever IsSoakCandidate('fieldcreep') is false
# ---------------------------------------------------------------------------
NEUTRAL = {'h': [(1.0, 'npc_dota_neutral_grown_frog', 40, 'neutral')]}
LANE = {'h': [(1.0, 'npc_dota_creep_badguys_melee', 40, 'lane')]}

ok('inert when the wave did not arm fieldcreep',
   SD.creep_world(NEUTRAL, 'h', 1.0, False, 'armed') == (False, False, 'none'))
ok('inert on the baseline leg even when armed',
   SD.creep_world(NEUTRAL, 'h', 1.0, True, 'baseline') == (False, False, 'none'))
ok('inert when no damage index was loaded',
   SD.creep_world(None, 'h', 1.0, True, 'armed') == (False, False, 'none'))

# ---------------------------------------------------------------------------
# the two worlds, pinned from both sides
# ---------------------------------------------------------------------------
SD.bind_fieldcreep()
ok('a NEUTRAL hit fires 甲 and not 乙',
   SD.creep_world(NEUTRAL, 'h', 1.0, True, 'armed') == (True, False, 'neutral'))
ok('a LANE hit fires BOTH worlds',
   SD.creep_world(LANE, 'h', 1.0, True, 'armed') == (True, True, 'lane'))
ok('the two worlds are distinct sets, not aliases',
   set(SD.WORLD_JIA) != set(SD.WORLD_YI)
   and set(SD.WORLD_YI) < set(SD.WORLD_JIA),
   '甲=%s 乙=%s' % (SD.WORLD_JIA, SD.WORLD_YI))
# 乙 is the SUBSET, so it can never remove a frame 甲 keeps.  If someone swaps
# the two constants the tool still runs and still prints two numbers -- it
# just labels the conservative world as the permissive one.
ok('乙 removes no frame 甲 keeps (甲 is the conservative world)',
   all(k in SD.WORLD_JIA for k in SD.WORLD_YI))
# 'none' must be in neither, or an undamaged bot leaves the domain.
ok("'none' is in neither world", 'none' not in SD.WORLD_JIA
   and 'none' not in SD.WORLD_YI)


# ---------------------------------------------------------------------------
# situation(): the clause is the FIFTH one, and defaults off
# ---------------------------------------------------------------------------
class FakeG(object):
    def __init__(self, enemies=False, dmg=False, tower=False):
        self._e, self._d, self._t = enemies, dmg, tower

    def enemies_within(self, hero, s, r):
        return [('e', 100.0)] if self._e else []

    def attributed_danger(self, hero, s):
        return self._d

    def enemy_tower_within(self, s, r):
        return self._t


def frame(hp=0.40):
    return {'t': 1.0, 'hp_pct': hp, 'x': 0.0, 'y': 0.0, 'team': 2}


ok('four-clause situation is unchanged when the clause is not passed',
   SD.situation(FakeG(), 'h', frame()) is True)
ok('the default is OFF, i.e. every pre-existing caller is untouched',
   SD.situation(FakeG(), 'h', frame())
   == SD.situation(FakeG(), 'h', frame(), creep_hits=None))
ok('creep_hits=True vetoes an otherwise-TRUE situation',
   SD.situation(FakeG(), 'h', frame(), creep_hits=True) is False)
# ...but it must not RESCUE a frame the four clauses already killed: the clause
# is a veto, never a permit.  (A `return True` in the wrong branch would do
# exactly that and every table would still look plausible.)
for kw in ({'enemies': True}, {'dmg': True}, {'tower': True}):
    ok('creep_hits cannot rescue a frame killed by %s' % list(kw)[0],
       SD.situation(FakeG(**kw), 'h', frame(), creep_hits=False) is False)
ok('the HP band still bounds the situation',
   SD.situation(FakeG(), 'h', frame(0.10)) is False
   and SD.situation(FakeG(), 'h', frame(0.90)) is False)

# ---------------------------------------------------------------------------
# 铁律 4(i): the stratum is a partition, and it uses the CANDIDATE side
# ---------------------------------------------------------------------------
ok('stratum_of: radiant-armed is ab, dire-armed is ba',
   SD.stratum_of('radiant') == 'ab' and SD.stratum_of('dire') == 'ba')
try:
    import fieldcreep_domain as FCD                            # noqa: E402
    ok('stratum_of agrees with fieldcreep_domain (one convention, two files)',
       all(SD.stratum_of(s) == FCD.stratum_of(s) for s in ('radiant', 'dire')))
except Exception as exc:                                       # pragma: no cover
    ok('stratum_of agrees with fieldcreep_domain', False, str(exc))

# ---------------------------------------------------------------------------
# the MANDATORY disclosure block.  Pinned as source text because the subject
# cannot be run corpus-free -- and because the failure this guards against is
# someone deleting the block, which would leave a tool that silently does not
# check the clause and a report that reads exactly like a clean one.
# ---------------------------------------------------------------------------
src = open(TOOL).read()
for line in ('=== gated 5th clause `fieldcreep` (jmz_func.lua:5287) ===',
             'SITUATION frames removed from the ARMED leg by this clause:',
             'NOT ARMED in this wave\'s cand string',
             'NOT check the clause -- never that the corpus was clean',
             '=== 铁律 4(i-a): the same two counts, per physical-side stratum ==='):
    ok('disclosure line still present: %s' % line[:40], line in src)

# The not-armed branch must exist as its own printed path.  A block that only
# prints when the clause IS live is the same silence in a new costume.
ok('the disclosure prints on the NOT-armed path too',
   'if not fc_live:' in src and 'Nothing removed; nothing to correct.' in src)

# The ladder must place the clause between the tower clause and the heal
# clause -- that is the source's own order (the clause is inside
# IsFieldRegenSituation; the heal is the wrapper's second conjunct).  Getting
# it backwards silently re-attributes rows between two clauses.
i_tower = src.index('return "enemy tower 1200"')
i_creep = src.index('return "fieldcreep (armed leg)"')
i_heal = src.index('return "no heal in bag"')
ok('ladder order is tower -> fieldcreep -> heal (the source\'s own)',
   i_tower < i_creep < i_heal)

if fails:
    print('\n%d FAILED:' % len(fails))
    for f in fails:
        print('  - %s' % f)
    sys.exit(1)
print('\nall checks ok')
