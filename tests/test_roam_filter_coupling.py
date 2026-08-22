#!/usr/bin/env python3
"""A threshold sweep must re-run the dedup clock, or it measures another function.

GH #92 section 6 (director ruling 2026-08-22, test_set.md AJ).  `rc.scan` keeps
one DEDUP_S clock per (actor, victim) and stamps it BEFORE the episode's outcome
is scored.  So relaxing the victim-HP threshold does not merely ADD episodes --
it DELETES registered ones: a high-HP episode admitted at the loose threshold
occupies the clock and masks the low-HP episode 1s later that the strict
threshold would have kept.

That makes the bands NON-NESTED, and it kills the two obvious ways to write a
sweep:
  * scanning once and filtering by HP afterwards (one clock, wrong episode set);
  * scanning disjoint bands and summing them (N clocks, also wrong).
`lanekill_filter_coupling.py`'s author caught exactly this in their own first
draft, with a real frame (crystalmaiden->sven, 20260820_163252_slot1, 76.4 vs
77.4) -- 46% of the registered episodes had been masked away.  Without a
per-threshold re-scan the whole analysis sits on the wrong denominator, and the
output looks completely normal.

This file pins that property on a synthetic two-frame game built to the shape of
that real pair, so the tool cannot be "optimised" back into a filter or a band
sum.  Section 3 additionally pins the global-restore contract, because the
sweep mutates a module constant that every other consumer of the shared scanner
reads -- a leaked threshold would silently re-point every later detector in the
same process.

Run: python3 tests/test_roam_filter_coupling.py   (or tests/run_py_tests.sh)
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEHAV = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral')
sys.path.insert(0, BEHAV)

import roam_conversion as rc            # noqa: E402
import roam_filter_coupling as rfc      # noqa: E402

fails = []


def check(name, cond, detail=''):
    if cond:
        print(f'PASS  {name}')
    else:
        print(f'FAIL  {name}  {detail}')
        fails.append(name)


def snap(hero, team, x, hp):
    return {'hero': hero, 'idx': 0, 'team': team, 'x': x, 'y': 0.0, 'hp_pct': hp}


def masking_game():
    """Two opportunity frames 1.0s apart, straddling the registered threshold.

    t=76.4  victim at 80% HP -- admitted only when the threshold is loose
    t=77.4  victim at 20% HP -- admitted at every threshold in the scan

    They share an (actor, victim) key and sit inside DEDUP_S, so at most one of
    them can survive any single scan.  Which one survives is decided by the
    threshold, and the LOW-HP one is the casualty of relaxing it.
    """
    # lion is inside ALLY_RANGE of axe (1000 <= 1200) but outside VICTIM_RANGE
    # of sven (900 > 800), so exactly ONE actor opens an episode per frame --
    # otherwise the counts double and the masking property is harder to read.
    frames = {
        76.4: [snap('axe', 2, 0.0, 1.00), snap('lion', 2, 1000.0, 1.00),
               snap('sven', 3, 100.0, 0.80)],
        77.4: [snap('axe', 2, 0.0, 1.00), snap('lion', 2, 1000.0, 1.00),
               snap('sven', 3, 100.0, 0.20)],
    }
    return {'frames': frames, 'pos': {}, 'pauses': [], 'armed_team': 2,
            'tl': {'events': []}}


def times_at(threshold):
    rec = {'g': masking_game(), 'name': 'synthetic', 'seed': '1', 'side': 2,
           'cand': 'roamstale'}
    eps = rfc.episodes_at([rec], threshold)
    return sorted(round(e['t'], 1) for e in eps if e['window'] == 'in')


print('== 1. the two frames really do straddle the registered threshold ==')
loose = times_at(1.01)
tight = times_at(rfc.REGISTERED_T)
check('tight threshold keeps the low-HP frame', tight == [77.4], f'got {tight}')
check('loose threshold keeps the high-HP frame', loose == [76.4], f'got {loose}')

print('\n== 2. bands are NOT nested: relaxing the threshold DELETES an episode ==')
check('the low-HP episode is absent from the loose scan',
      77.4 in tight and 77.4 not in loose,
      f'tight={tight} loose={loose}')
check('neither scan is a superset of the other',
      not set(tight) <= set(loose) and not set(loose) <= set(tight),
      f'tight={tight} loose={loose}')
# A filter-after-one-scan implementation would return [77.4] for BOTH (it would
# scan once at the loose threshold and drop the high-HP row) or [76.4] for both.
# A band-sum implementation would return [76.4, 77.4] for the loose scan.
check('loose scan is not a band sum', loose != [76.4, 77.4], f'got {loose}')

print('\n== 3. the mutated module constant is restored ==')
before = rc.VICTIM_HP
times_at(0.99)
check('VICTIM_HP restored after a sweep step', rc.VICTIM_HP == before,
      f'{before} -> {rc.VICTIM_HP}')


class Boom(Exception):
    pass


def exploding():
    raise Boom()


saved = rc.scan
rc.scan = lambda *a, **k: exploding()
try:
    times_at(0.99)
except Boom:
    pass
finally:
    rc.scan = saved
check('VICTIM_HP restored even when the scan raises', rc.VICTIM_HP == before,
      f'{before} -> {rc.VICTIM_HP}')

print('\n== 4. the registered threshold is a mandatory member of any scan ==')
# A sweep that omits T=0.40 cannot show where the registered number sits, and a
# reader comparing it against the registered figure would be comparing two
# different functions.  main() exits 2; assert the constant it guards on.
check('REGISTERED_T matches the scanner default', rfc.REGISTERED_T == 0.40,
      f'got {rfc.REGISTERED_T}')
check('REGISTERED_T is in the default sweep', rfc.REGISTERED_T in rfc.DEFAULT_T,
      f'got {rfc.DEFAULT_T}')

print('\n== 5. the pre-registered READING RULE still carries all four columns ==')
# #101's (iv) was ADOPTED on 2026-08-22T14:5xZ and then sat in prose for four
# rounds.  A column that lives only in a report nobody re-reads is not a column.
# The rule text is printed by main() before any number is shown, so pin it in
# the SOURCE -- deleting the (iv) block goes red here, and section 2b of
# test_detector_source_constants.py covers the constant it is read at.
#
# WHY THE SOURCE AND NOT THE OUTPUT: main() needs a corpus on disk, and a test
# that needs a corpus is a test that gets skipped.  The tradeoff is honest and
# bounded -- this asserts the rule is PRINTED, not that a reader obeyed it.
with open(os.path.join(BEHAV, 'roam_filter_coupling.py')) as fh:
    rule_src = fh.read()

for col, needle in (
        ('(i) supply ratio', 'the supply ratio'),
        ('(ii) episodes/game', 'episodes/game'),
        ('(iii) threshold', 'the threshold it was read at'),
        ('(iv) composition-attributable NULL', 'COMPOSITION-ATTRIBUTABLE NULL'),
):
    check(f'READING RULE names {col}', needle in rule_src)

check('(iv) states its unit (pp), so it can be read against the effect size',
      "in pp -- the same unit as the effect" in rule_src)
check('(iv) points at a real implementation, not at a memory',
      'null_leg_occupancy.py:report_composition_null' in rule_src)

# ... and that implementation must exist and be reachable, or the citation
# above is the same kind of dead pointer as test_set.md AJ.5's
# `jmz_func.lua:6932`.
import null_leg_occupancy as nlo                   # noqa: E402
check('report_composition_null exists and is callable',
      callable(getattr(nlo, 'report_composition_null', None)))
with open(os.path.join(BEHAV, 'null_leg_occupancy.py')) as fh:
    nlo_src = fh.read()
check('report_composition_null is actually CALLED, not just defined',
      nlo_src.count('report_composition_null(') >= 2,
      '(defined once and never invoked is the #67 three-writes-no-reads shape)')

print(f'\n{len(fails)} failed' if fails else '\nall passed')
sys.exit(1 if fails else 0)
