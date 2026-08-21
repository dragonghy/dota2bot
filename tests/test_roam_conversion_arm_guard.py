#!/usr/bin/env python3
"""The armed-vs-baseline table must name its arm, or refuse to print.

WHY (director ruling 2026-08-21, test_set.md section AG, GH #94).
`roam_conversion.py` pools every directory it is handed into a single `armed`
cell.  Hand it both arms of a bisect and it averages a treated candidate side
with an untreated one and prints a number shaped exactly like a normal
measurement -- the same failure family as section 0b: a reading that is
structurally a mixture but is indistinguishable, on the page, from a
measurement.  It is not hypothetical: the corpus the `roamstale` bisect wrote
is eight run directories, four per arm, sitting side by side under the same
prefix (batch-desk 2026-08-21T18:13Z: "the flat replays/ prefix cannot tell you
whose"), and the natural thing to type is all eight.

The guard reads the candidate id string out of each run's games_manifest.jsonl
-- READ, not inferred from the directory name, because the name is a label a
human typed and the stamp is what the instance actually armed.

This file tests the guard, not the scanner: no timelines are needed, because
the guard must run BEFORE any scanning (a table that should never have been
printed must not be computed first and rejected after).
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral', 'roam_conversion.py')

failures = []


def check(name, cond, detail=''):
    if cond:
        print('  ok   %s' % name)
    else:
        print('  FAIL %s %s' % (name, detail))
        failures.append(name)


def make_run(root, name, cand, games=2, with_manifest=True):
    d = os.path.join(root, name)
    os.makedirs(os.path.join(d, 'timelines'), exist_ok=True)
    os.makedirs(os.path.join(d, 'analysis'), exist_ok=True)
    if with_manifest:
        with open(os.path.join(d, 'games_manifest.jsonl'), 'w') as fh:
            for i in range(games):
                fh.write(json.dumps({'game': '%s_g%d' % (name, i),
                                     'seed': 900 + i,
                                     'side': 'radiant' if i % 2 else 'dire',
                                     'cand': cand}) + '\n')
    return d


def run(dirs, extra=()):
    p = subprocess.run([sys.executable, SCRIPT] + list(extra) + list(dirs),
                       capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


ARM_A = 'roamstale,capmono,ownhalf'
ARM_B = 'capmono,ownhalf'

tmp = tempfile.mkdtemp(prefix='roamguard_')
try:
    a1 = make_run(tmp, 'runA1', ARM_A)
    a2 = make_run(tmp, 'runA2', ARM_A)
    b1 = make_run(tmp, 'runB1', ARM_B)
    nom = make_run(tmp, 'runNoManifest', ARM_A, with_manifest=False)

    print('1. one arm is accepted and named')
    rc, out, err = run([a1, a2])
    check('exit 0 for a single arm', rc == 0, '(rc=%d, stderr=%s)' % (rc, err[:200]))
    check('the arm is printed, not assumed', 'ARM: 3 ids armed in every stamp' in out,
          '(stdout head: %r)' % out[:200])
    for wanted in ('roamstale', 'capmono', 'ownhalf'):
        check('stamp id %s echoed' % wanted, wanted in out)

    print('2. two arms pooled into one table is refused')
    rc, out, err = run([a1, b1])
    check('exit 2 for mixed arms', rc == 2, '(rc=%d)' % rc)
    check('the error names the differing id', 'roamstale' in err, '(stderr=%r)' % err[:300])
    check('the error names the offending directory', 'runB1' in err, '(stderr=%r)' % err[:300])
    check('no table was printed before the refusal',
          'IN-DOMAIN' not in out and 'armed' not in out.replace('unattributed', ''),
          '(stdout=%r)' % out[:300])

    print('3. order does not matter (the guard compares, it does not privilege argv[0])')
    rc_ab, _, _ = run([a1, b1])
    rc_ba, _, err_ba = run([b1, a1])
    check('mixed arms refused in either order', rc_ab == 2 and rc_ba == 2,
          '(%d / %d)' % (rc_ab, rc_ba))
    check('reversed order still names roamstale', 'roamstale' in err_ba,
          '(stderr=%r)' % err_ba[:300])

    print('4. a missing stamp is refused, not silently attributed')
    rc, out, err = run([nom])
    check('exit 2 without a manifest', rc == 2, '(rc=%d)' % rc)
    check('the error names the unstamped directory', 'runNoManifest' in err,
          '(stderr=%r)' % err[:300])

    print('5. --allow-unattributed says so out loud instead of guessing')
    rc, out, err = run([nom], extra=['--allow-unattributed'])
    check('exit 0 with the escape hatch', rc == 0, '(rc=%d, stderr=%s)' % (rc, err[:200]))
    check('output is stamped UNATTRIBUTED', 'UNATTRIBUTED' in out, '(stdout=%r)' % out[:300])
    check('it does not invent an arm', 'ids armed in every stamp' not in out)

    print('6. the standing banner rides on every accepted table')
    rc, out, _ = run([a1])
    check('banner names the leg', 'ONE LEG of a bisect' in out, '(stdout=%r)' % out[:400])
    check('banner names the estimator', 'ARMED A-B' in out)
    check('banner bans the DiD', 'DiD' in out and 'AG' in out)

    print('7. MUTATION -- the guard must actually compare the sets')
    # A one-character difference in the stamp is a different arm.  If the guard
    # ever degrades to "is a manifest present", this case goes green and every
    # case above still passes.
    b2 = make_run(tmp, 'runB2', ARM_A.replace('roamstale', 'roamstalе'))  # cyrillic e
    rc, _, err = run([a1, b2])
    check('a one-character id difference is a different arm', rc == 2, '(rc=%d)' % rc)
    # ... and identical-but-reordered stamps are the SAME arm (a set, not a string):
    b3 = make_run(tmp, 'runA3', ','.join(reversed(ARM_A.split(','))))
    rc, _, err = run([a1, b3])
    check('reordering the stamp is not a different arm', rc == 0,
          '(rc=%d, stderr=%r)' % (rc, err[:300]))
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print('\n%d checks failed' % len(failures))
sys.exit(1 if failures else 0)
