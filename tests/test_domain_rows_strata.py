#!/usr/bin/env python3
"""[detector] domain_rows_strata.py must swap-average per seed, never pool by games.

WHY THIS FILE EXISTS
--------------------
`tools/batch_test/behavioral/domain_rows_strata.py` is the id-level twin of
`sweep_strata.py`: it re-reads a `<id>_domain.py` rows file in the two physical
strata so a condition-(a) reading is not a pooled `armed - baseline` number.
The whole value of the tool is one line of arithmetic -- per-seed
`(r_ab + r_ba) / 2`, then the ARITHMETIC MEAN across seeds -- and 铁律 4(i-d)
exists because the WRONG version of that line (weight each stratum by its game
count) produces a number that looks completely ordinary:

    games-weighted = arm + side * (N_ab - N_ba) / (N_ab + N_ba)

The corpus this tool was written on splits 53:35, so the coefficient is 0.205
and a side term of any size leaks straight into the answer.  Case 1 below is
built so the two formulas disagree by a factor the reader cannot miss.

Case 3 is the lesson from the W62 `ownhalf` mutation stand, applied in advance:
a control that never moves cannot prove it was subtracted.  The baseline leg
here carries its OWN episodes, so deleting the `- baseline` term changes the
answer and the test goes red.

Run:  python3 tests/test_domain_rows_strata.py
"""
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))

import domain_rows_strata as S  # noqa: E402

FAILURES = []


def check(name, cond, detail=''):
    if cond:
        print('  PASS  %s' % name)
    else:
        print('  FAIL  %s  %s' % (name, detail))
        FAILURES.append(name)


def rows_for(spec):
    """spec: {(game, leg): n_episodes} -> rows with one poke frame per episode.

    Episodes are separated by more than EPISODE_GAP so each poke frame is its
    own episode, and every row carries the columns episodes() keys on.

    The two legs get DIFFERENT hero names, because that is what a mirrored
    game is: the armed leg is one team and the baseline leg is the other.
    `episodes()` keys on (sweep, game, hero) and reads the leg off the first
    row of the chain, so one hero name for both legs would merge them into one
    chain and hand the whole episode to whichever leg sorted first -- the first
    draft of this file did exactly that, and case 3 caught it.
    """
    hero = {'armed': 'npc_dota_hero_lion', 'baseline': 'npc_dota_hero_zuus'}
    out = []
    for (game, leg), n in spec.items():
        for i in range(n):
            out.append(dict(sweep='sw', game=game, hero=hero[leg],
                            leg=leg, t=100.0 + 30.0 * i, poke=True, drag=False))
    return out


def manifest_for(games):
    """games: {game: (seed, side)}"""
    return {('sw', g): dict(game=g, seed=s, side=side)
            for g, (s, side) in games.items()}


print('1. the two strata are swap-averaged, not pooled by game count')
# One seed. ab: 3 games, armed 6 episodes, baseline 0  -> r_ab = +2.0
#           ba: 1 game,  armed 0 episodes, baseline 1  -> r_ba = -1.0
# arm = +0.5 ; side = +1.5 ; games-weighted = 0.5 + 1.5*(3-1)/4 = +1.25.
games = {'g1': (1, 'radiant'), 'g2': (1, 'radiant'), 'g3': (1, 'radiant'),
         'g4': (1, 'dire')}
spec = {('g1', 'armed'): 3, ('g2', 'armed'): 3, ('g4', 'baseline'): 1}
per_seed, complaints = S.tabulate(rows_for(spec), manifest_for(games), 'poke')
check('one paired seed survives', len(per_seed) == 1, per_seed)
s = per_seed[0]
check('r_ab is the ab stratum rate', abs(s['r_ab'] - 2.0) < 1e-9, s['r_ab'])
check('r_ba is the ba stratum rate', abs(s['r_ba'] + 1.0) < 1e-9, s['r_ba'])
check('arm is the swap-average', abs(s['arm'] - 0.5) < 1e-9, s['arm'])
check('side is what the swap-average removed',
      abs(s['side'] - 1.5) < 1e-9, s['side'])
check('arm is NOT the games-weighted pool (+1.25)',
      abs(s['arm'] - 1.25) > 0.1, s['arm'])
check('no complaint on a clean pair', complaints == [], complaints)

print('2. a seed with one stratum contributes NOTHING and says so')
games2 = dict(games)
games2['g5'] = (2, 'radiant')          # seed 2 has an ab leg only
spec2 = dict(spec)
spec2[('g5', 'armed')] = 4
per_seed2, complaints2 = S.tabulate(rows_for(spec2), manifest_for(games2), 'poke')
check('the unpaired seed is dropped', [p['seed'] for p in per_seed2] == [1],
      [p['seed'] for p in per_seed2])
check('and it is registered, not silently dropped',
      any('NO-PAIR' in c for c in complaints2), complaints2)
check('the paired seed reads exactly what it read alone',
      abs(per_seed2[0]['arm'] - 0.5) < 1e-9, per_seed2[0]['arm'])

print('3. the baseline leg is really subtracted (a control that never moves '
      'proves nothing)')
spec3 = dict(spec)
spec3[('g1', 'baseline')] = 3          # the SAME games gain baseline episodes
per_seed3, _ = S.tabulate(rows_for(spec3), manifest_for(games), 'poke')
check('adding baseline episodes moves the ab rate',
      abs(per_seed3[0]['r_ab'] - 1.0) < 1e-9, per_seed3[0]['r_ab'])
check('and therefore moves arm', abs(per_seed3[0]['arm'] - 0.0) < 1e-9,
      per_seed3[0]['arm'])

print('4. rows whose (sweep, game) is in no manifest are a FINDING, not a drop')
spec4 = dict(spec)
spec4[('ghost', 'armed')] = 2
_, complaints4 = S.tabulate(rows_for(spec4), manifest_for(games), 'poke')
check('the orphan row is named',
      any('ghost' in c for c in complaints4), complaints4)

print('5. the report prints BOTH strata unconditionally (4(i-a))')
buf = io.StringIO()
S.report(per_seed, 'poke', out=buf)
text = buf.getvalue()
check('r_ab and r_ba are both in the output',
      'r_ab' in text and 'r_ba' in text, text[:120])
check('the games-weighted number is shown as NOT the estimator',
      'NOT the estimator' in text, text[-200:])

print('6. exit codes: refused is not clean (GH #171)')
tmp = tempfile.mkdtemp()
try:
    empty = os.path.join(tmp, 'empty.jsonl')
    open(empty, 'w').close()
    r = subprocess.run([sys.executable,
                        os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                                     'domain_rows_strata.py'),
                        tmp, '--rows', empty],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    check('an empty rows file exits 2, not 0', r.returncode == 2, r.returncode)
    missing = os.path.join(tmp, 'nope.jsonl')
    r2 = subprocess.run([sys.executable,
                         os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                                      'domain_rows_strata.py'),
                         tmp, '--rows', missing],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    check('a missing rows file exits 2, not 0', r2.returncode == 2, r2.returncode)
    rowf = os.path.join(tmp, 'rows.jsonl')
    with open(rowf, 'w') as fh:
        for r_ in rows_for(spec):
            fh.write(json.dumps(r_) + '\n')
    r3 = subprocess.run([sys.executable,
                         os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                                      'domain_rows_strata.py'),
                         tmp, '--rows', rowf, '--column', 'no_such_column'],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    check('an unknown column exits 2 and names the columns it has',
          r3.returncode == 2 and b'no column' in r3.stderr, r3.returncode)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print('\n%d checks, %d failed' % (6, len(FAILURES)))
if FAILURES:
    for f in FAILURES:
        print('FAIL: %s' % f)
    sys.exit(1)
