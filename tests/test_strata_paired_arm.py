#!/usr/bin/env python3
"""GH #835 / director RULING 54 -- iron rule 4(i-e) as a gate, not as prose.

WHY THIS FILE EXISTS ALONGSIDE THE TWO `--selfcheck`s
------------------------------------------------------
`strata.py`, `campsel_domain.py --selfcheck` and `abilanc_domain.py
--selfcheck` each cover their own piece.  Nothing runs them: `run_py_tests.sh`
loops `tests/test_*.py` and no test in the tree invokes those selfchecks.  A
check nobody runs is the shape this repo has rejected three times now (the dead
S3 lifecycle rule, test_set.md Z.4; the four runner-less `tests/*.py` that
motivated `run_py_tests.sh`; GH #257's note/verdict pair).  RULING 54's own
acceptance criterion is "turn (i-e) from prose into a gate", so the gate has to
live where the harness can see it.

WHAT IS UNDER TEST
------------------
(i-b) says opposite-signed strata are noise.  That is right for a quantity with
no paired structure and WRONG for a mirrored wave's detector counts, where the
two `arm_side` layers are one pair of half-readings: both legs of a run are
dealt the same seed, so the roster term cancels term by term in `d_ab + d_ba`,
and `opposed` is then the identity |roster| > |arm| -- which says nothing about
precision.  Measured cost of the old reading: of 14 detectors in the 09-11
wave, 12 were dropped and not one number survived.

THE THING THIS MUST NOT BECOME IS A BLANKET AMNESTY.  So every rescue assertion
below is PAIRED with the same corpus minus the pairing evidence, which must
still refuse.  If a future edit makes `pairing()` optimistic, the "still
REFUSEs" half goes red -- that is the real subject of this file.

THE MUTATION IS THE PRE-FIX PROGRAM
-----------------------------------
`strata.pairing` is patched to report "never paired", which is byte-for-byte
the behaviour before RULING 54: the rescued readings revert to REFUSE.  A
control corpus that never depended on the rescue must keep its verdict, or the
fix would have bought its effect by changing readings it had no business
touching.
"""
import contextlib
import io
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
BEHAV = os.path.join(HERE, '..', 'tools', 'batch_test', 'behavioral')
sys.path.insert(0, os.path.abspath(BEHAV))

try:
    import strata
    import campsel_domain as CD
    import abilanc_domain as AD
except Exception as exc:                                  # pragma: no cover
    print('UNCERTIFIABLE: cannot import the behavioral domain tools: %s' % exc)
    sys.exit(2)

ok = True


def chk(label, cond, detail=''):
    global ok
    print('  %-74s %s %s' % (label, 'PASS' if cond else 'FAIL', detail))
    ok = ok and bool(cond)


# ------------------------------------------------------------------ algebra
print('--- the identity: `opposed` IS |roster| > |arm|, for every pair')
for d_ab, d_ba in ((0.7, -0.9), (0.7, 0.9), (-0.045, -1.104),
                   (-1.104, -0.045), (0.0, 0.5), (26.6, 26.6),
                   (326.6, -273.4), (-0.21, 0.0), (-2.0, 2.0)):
    chk('identity holds for (%+.3f, %+.3f)' % (d_ab, d_ba),
        strata.opposed_is_identity(strata.pair_arm(d_ab, d_ba)))

# The discriminator GH #835 found in its own table: two detectors whose
# (arm, roster) pairs are the SAME TWO NUMBERS with the roles swapped.  The old
# rule kept one and dropped the other, and what decided it was which way this
# wave's roster split happened to fall -- not which was measured better.
a = strata.pair_arm(-0.045, -1.104)
b = strata.pair_arm(-1.104, -0.045)
chk('the two detectors GH #835 names have IDENTICAL arms',
    abs(a['arm'] - b['arm']) < 1e-12, '(%+.4f)' % a['arm'])
chk('...and roster terms of equal size and opposite sign',
    abs(a['roster'] + b['roster']) < 1e-12)

# skywrath_solo_silence, as the replay-check report hand-computed it.
chk('the hand-computed cross-layer read IS the arm sum (GH #835 self-证)',
    abs((33 / 47.0) + -(31 / 34.0) - -0.210) < 0.0005)


# ------------------------------------------------------ (i-d): never by games
print('\n--- rule 4(i-d): the arm is a per-seed swap-average, never '
      'games-weighted')
# Two seeds with DIFFERENT arms and DIFFERENT totals.  If the totals matched,
# the forbidden weighting would coincide with the arithmetic mean and nothing
# here would be asserting anything -- that degeneracy is how this exact mutant
# survived the first stand built for it.
recs, ng = [], {}
for seed, (r_a, r_b, d_a, d_b, g_r, g_d) in {'A': (6, 0, 0, 1, 3, 1),
                                             'B': (3, 0, 1, 0, 1, 1)}.items():
    ng[(seed, 'radiant')] = g_r
    ng[(seed, 'dire')] = g_d
    for side, (na, nb) in (('radiant', (r_a, r_b)), ('dire', (d_a, d_b))):
        recs += [{'seed': seed, 'arm_side': side, 'leg': 'armed'}] * na
        recs += [{'seed': seed, 'arm_side': side, 'leg': 'baseline'}] * nb

est = strata.per_seed_arm(recs, ng)
chk('per-seed estimator is the arithmetic mean of the per-seed arms',
    est is not None and abs(est['arm'] - 1.25) < 1e-12,
    '(%+.4f)' % (est['arm'] if est else float('nan')))
w = [ng[(s, 'radiant')] + ng[(s, 'dire')] for s in ('A', 'B')]
games_weighted = (0.5 * w[0] + 2.0 * w[1]) / float(sum(w))
chk('and is NOT the games-weighted mean of those same arms',
    abs(est['arm'] - games_weighted) > 1e-9,
    '(%+.4f vs %+.4f)' % (est['arm'], games_weighted))

chk('an unpaired corpus yields NO estimator rather than a downgraded one',
    strata.per_seed_arm(recs, {('A', 'radiant'): 3}) is None)


# ------------------------------------------------- campsel: rescue + control
print('\n--- campsel_domain.verdict: the same numbers, with and without the '
      'pairing evidence')
DL = CD.DECIDE_LEADS


def ep(side, leg, w, seed):
    r = {'arm_side': side, 'leg': leg, 'level': 8, 'ancient': False,
         'at_camp': True, 'seed': seed,
         'half': 'enemy' if w is not None else 'own'}
    for lead in DL:
        r['w%d' % int(lead)] = w
    return r


def cd_verdict(eps, ng_seed):
    return CD.verdict({'eps': eps, 'ngames': {'radiant': 1, 'dire': 1},
                       'camps': [], 'stats': Counter(), 'games': 0,
                       'ngames_seed': ng_seed})


# ab: armed 1/1 vs baseline 0/1 = +1.0;  ba: armed 1/2 vs baseline 1/1 = -0.5.
# Opposed, arm = +0.25 -- a real reading the old rule threw away.
ASYM = [ep('radiant', 'armed', True, 'S1'),
        ep('radiant', 'baseline', False, 'S1'),
        ep('dire', 'armed', True, 'S1'),
        ep('dire', 'armed', False, 'S1'),
        ep('dire', 'baseline', True, 'S1')]
PAIRED_NG = {('S1', 'radiant'): 1, ('S1', 'dire'): 1}
HALF_NG = {('S1', 'radiant'): 1}

v_unpaired = cd_verdict(ASYM, HALF_NG)[0]
v_paired, why_paired = cd_verdict(ASYM, PAIRED_NG)
chk('WITHOUT the pairing evidence the opposed corpus still REFUSEs',
    v_unpaired == 'REFUSE', '(%s)' % v_unpaired)
chk('WITH it the same numbers are read as an arm',
    v_paired == 'BUGGY-SUSPECT-OPPOSED-STRATA', '(%s)' % v_paired)
chk('the rescued verdict names the identity and the roster term',
    'identity' in why_paired and 'roster' in why_paired)
chk('the rescued verdict quotes the per-seed estimator, not a pooled number',
    'per-seed swap-average' in why_paired)

# An arm of exactly zero must read SILENT, not be forced into a direction.
SYMM = [ep('radiant', 'armed', True, 'S1'),
        ep('radiant', 'baseline', False, 'S1'),
        ep('dire', 'armed', False, 'S1'),
        ep('dire', 'baseline', True, 'S1')]
chk('a paired corpus whose arm cancels exactly reads SILENT, not a direction',
    cd_verdict(SYMM, PAIRED_NG)[0] == 'SILENT')

# The same discriminator on this side.  NOTE these are SHARES, so weighting a
# stratum means changing its RATIO, not repeating its episodes -- the first
# draft duplicated episodes, which left both shares untouched and produced an
# arm of exactly 0.
#   ab: armed 1/2 = 0.5, baseline 0/1 = 0.0  => +0.5  (alone: BUGGY)
#   ba: armed 0/1 = 0.0, baseline 1/1 = 1.0  => -1.0
#   arm = (+0.5 + -1.0)/2 = -0.25            => WORKING
FLIP = [ep('radiant', 'armed', True, 'S1'),
        ep('radiant', 'armed', False, 'S1'),
        ep('radiant', 'baseline', False, 'S1'),
        ep('dire', 'armed', False, 'S1'),
        ep('dire', 'baseline', True, 'S1')]
flip_cd = cd_verdict(FLIP, PAIRED_NG)[0]
chk('campsel: the direction follows the ARM, not the ab stratum alone',
    flip_cd == 'WORKING-OPPOSED-STRATA', '(%s)' % flip_cd)

# CONTROL: same-sign strata never went through the opposed branch at all, so
# the rescue must leave them exactly where they were.
AGREE = [ep('radiant', 'armed', False, 'S1'),
         ep('radiant', 'baseline', True, 'S1'),
         ep('dire', 'armed', False, 'S1'),
         ep('dire', 'baseline', True, 'S1')]
chk('CONTROL: a both-layers-agree corpus still reads WORKING',
    cd_verdict(AGREE, PAIRED_NG)[0] == 'WORKING')

# The composition guard is a SEPARATE refusal and must survive: its message
# always claimed a within-stratum, across-denominator comparison, and until
# RULING 54 its arithmetic compared strata instead -- which made it a second,
# silent copy of the (i-b) veto sitting behind the one being narrowed.
# ab, conditional denominator:  armed 2/2 = 1.0, baseline 1/2 = 0.5 => +0.5
# ab, leg-independent:          armed 2/8 = 0.25, baseline 1/2 = 0.5 => -0.25
# The stratum FLIPS SIGN between its two denominators -- that is a composition
# shift, and it is what this guard is for.  `ba` is built flat so the opposed
# test upstream has nothing to say and the guard is what actually answers.
COMP = ([ep('radiant', 'armed', True, 'S1')] * 2
        + [ep('radiant', 'armed', None, 'S1')] * 6
        + [ep('radiant', 'baseline', True, 'S1'),
           ep('radiant', 'baseline', False, 'S1'),
           ep('dire', 'armed', True, 'S1'),
           ep('dire', 'armed', False, 'S1'),
           ep('dire', 'baseline', True, 'S1'),
           ep('dire', 'baseline', False, 'S1')])
comp_v, comp_why = cd_verdict(COMP, PAIRED_NG)
chk('the composition guard still REFUSEs when a stratum flips sign between '
    'its two denominators', comp_v == 'REFUSE', '(%s)' % comp_v)
chk('...and says so, naming the stratum rather than the pair',
    'composition shift' in comp_why and 'ab stratum' in comp_why)


# ------------------------------------------------- abilanc: rescue + control
print('\n--- abilanc_domain.verdict: same pair')


def cast(side, leg, seed, cls='certain_under'):
    return {'run': 'r1', 'game': 'g1', 'seed': seed, 't': 100.0,
            'hero': 'lion', 'ability': 'lion_impale',
            'target': 'npc_dota_neutral_black_dragon', 'leg': leg,
            'arm_side': side, 'lvl_lo': 8, 'lvl_hi': 8, 'placed': cls,
            'band': 'under'}


def ad_verdict(casts, ng_seed):
    return AD.verdict({'casts': casts, 'ngames': {'radiant': 10, 'dire': 10},
                       'exposure': Counter({('armed', 'radiant', 'band'): 5}),
                       'fed_exposure': Counter(), 'engage': Counter(),
                       'ngames_seed': ng_seed})


A_NG = {('S1', 'radiant'): 10, ('S1', 'dire'): 10}
A_OPP = [cast('radiant', 'armed', 'S1'), cast('radiant', 'armed', 'S1'),
         cast('dire', 'baseline', 'S1')]
av_un = ad_verdict(A_OPP, {('S1', 'radiant'): 10})[0]
av_p, aw_p = ad_verdict(A_OPP, A_NG)
chk('WITHOUT the pairing evidence the opposed corpus still REFUSEs',
    av_un == 'REFUSE', '(%s)' % av_un)
chk('WITH it the same numbers are read as an arm',
    av_p == 'BUGGY-SUSPECT-OPPOSED-STRATA', '(%s)' % av_p)
# THE DISCRIMINATING CORPUS.  Above, `d_ab` and the arm happen to share a
# sign, so "the direction follows the arm" is not actually under test -- a
# build that read `d_ab` alone would score identically.  Here they DISAGREE:
#   ab = +1/10 = +0.1   (a one-stratum read says BUGGY)
#   ba = -3/10 = -0.3
#   arm = (+0.1 + -0.3)/2 = -0.1  => WORKING
A_FLIP = [cast('radiant', 'armed', 'S1'),
          cast('dire', 'baseline', 'S1'), cast('dire', 'baseline', 'S1'),
          cast('dire', 'baseline', 'S1')]
flip_v = ad_verdict(A_FLIP, A_NG)[0]
chk('the rescued direction follows the ARM, not the stratum with the larger '
    'magnitude (ab is +0.1 and would read BUGGY on its own)',
    flip_v == 'WORKING-OPPOSED-STRATA', '(%s)' % flip_v)
chk('CONTROL: a same-sign corpus is untouched (WORKING-WITH-RESIDUAL)',
    ad_verdict([cast('radiant', 'baseline', 'S1'),
                cast('radiant', 'baseline', 'S1'),
                cast('dire', 'baseline', 'S1'),
                cast('dire', 'baseline', 'S1'),
                cast('radiant', 'armed', 'S1'),
                cast('dire', 'armed', 'S1')], A_NG)[0]
    == 'WORKING-WITH-RESIDUAL')


# ----------------------------------------------- THE MUTATION (pre-fix prog)
print('\n--- the mutation: `pairing` reports "never paired" (the pre-RULING-54 '
      'program)')
real_pairing = strata.pairing
try:
    strata.pairing = lambda records, ng: (False, [], list(
        {s for (s, _x) in ng}))
    chk('campsel: the rescued reading reverts to REFUSE',
        cd_verdict(ASYM, PAIRED_NG)[0] == 'REFUSE')
    chk('abilanc: the rescued reading reverts to REFUSE',
        ad_verdict(A_OPP, A_NG)[0] == 'REFUSE')
    chk('CONTROL under mutation: the same-sign campsel corpus is unchanged, '
        'so the fix did not buy its effect by moving unrelated readings',
        cd_verdict(AGREE, PAIRED_NG)[0] == 'WORKING')
finally:
    strata.pairing = real_pairing

chk('the mutation was undone (the rescue works again)',
    cd_verdict(ASYM, PAIRED_NG)[0] == 'BUGGY-SUSPECT-OPPOSED-STRATA')


# --------------------------------------------------- the printed precondition
print('\n--- the precondition is PRINTED, so a reader can see why')
buf = io.StringIO()
try:
    with contextlib.redirect_stdout(buf):
        AD.report({'casts': A_OPP, 'ngames': {'radiant': 10, 'dire': 10},
                   'games': 20, 'keys': 20, 'collisions': 0,
                   'anc_camps': [(1000.0, 1000.0), (-1000.0, -1000.0)],
                   'anc_cov': 0.9, 'norm_camps': [], 'norm_cov': 0.0,
                   'exposure': Counter({('armed', 'radiant', 'under'): 40}),
                   'fed_exposure': Counter(), 'engage': Counter(),
                   'stats': Counter({'certain_under': len(A_OPP)}),
                   'ngames_seed': A_NG})
    out = buf.getvalue()
    chk('the report states whether the corpus is seed-paired',
        'rule 4(i-e) precondition' in out and 'PAIRED' in out)
    chk('and no table still prints the bare `OPPOSED => NOISE` verdict',
        'OPPOSED => NOISE' not in out)
except Exception as exc:                                  # pragma: no cover
    chk('report() renders with the 4(i-e) precondition line', False,
        '(raised %s)' % exc)

print('\n%s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
sys.exit(0 if ok else 1)
