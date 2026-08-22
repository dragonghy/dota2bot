#!/usr/bin/env python3
"""`rec_slot_cost.py` must refuse an unanswerable corpus and must never let the
slot-index confound leak into the number it reports.

WHY (director ruling 2026-08-22, GH #75, batch-desk 08:11Z section 3.7).  This
tool exists to unblock `--rec-slots`, i.e. to decide how many of a paid wave's
games keep frame evidence.  Two ways it could be wrong are expensive:

  1. It prints a clean table over a corpus that cannot answer the question --
     no recorder, no control, or nobody knows who recorded.  That is the
     `creeppull`/`pullcamp` shape: a wave read as "tested, neutral" when the
     thing under test never ran.  Every such case here must exit 2.

  2. It reports the raw recorder-minus-rest difference.  Mean timescale rises
     with slot index among NON-recorders, so a bare difference is part signal
     and part start-order.  The fit must be taken over control slots only; a
     recorder outlier must not be able to move it.  Case 8 is the mutation that
     catches a regression to pooled fitting -- it makes the recorder wildly
     fast, and the fitted slope must not budge.

The numeric cases build a synthetic corpus with a known planted trend and a
known planted recorder effect, so the residual has a right answer rather than
a plausible one.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, 'tools', 'batch_test', 'soak', 'rec_slot_cost.py')

failures = []


def check(name, cond, detail=''):
    if cond:
        print('  ok   %s' % name)
    else:
        print('  FAIL %s %s' % (name, detail))
        failures.append(name)


def run(args):
    p = subprocess.run([sys.executable, SCRIPT] + args, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def make_run(root, name, slots=16, games=4, rec=(1,), rec_slots=1,
             sidecar=True, slope=0.008, base=1.80, rec_effect=0.0,
             sidecar_slots=None):
    """A synthetic run directory with a PLANTED trend and recorder effect.

    timescale(slot) = base + slope*slot (+ rec_effect if the slot records)
    so the residual of a recorder against the control trend is exactly
    rec_effect, up to the noise we deliberately do not add.
    """
    d = os.path.join(root, name)
    os.makedirs(d, exist_ok=True)
    for slot in range(1, slots + 1):
        for g in range(games):
            ts = base + slope * slot + (rec_effect if slot in rec else 0.0)
            dur = 660.0
            tag = '2026082%d_%02d%02d%02d_slot%d' % (2, 6, g, slot, slot)
            with open(os.path.join(d, tag + '.analysis.json'), 'w') as fh:
                json.dump({'effective_timescale': round(ts, 6), 'wall_s': dur / ts,
                           'duration_s': dur, 'script_version': 'synthetic'}, fh)
        if sidecar and slot in (sidecar_slots if sidecar_slots is not None else rec):
            tag = '20260822_000000_slot%d' % slot
            with open(os.path.join(d, tag + '.demclaim.json'), 'w') as fh:
                json.dump({'slot': slot, 'method': 'logname', 'rec_slots': rec_slots}, fh)
    return d


tmp = tempfile.mkdtemp(prefix='recslot-')
try:
    print('1. REFUSALS -- an unanswerable corpus never prints a clean table')
    rc, out, err = run([])
    check('no run directories -> exit 2', rc == 2 and 'runs=0' in err, '(rc=%d)' % rc)

    rc, out, err = run([os.path.join(tmp, 'nope')])
    check('missing directory -> exit 2', rc == 2, '(rc=%d)' % rc)

    empty = os.path.join(tmp, 'empty')
    os.makedirs(empty, exist_ok=True)
    rc, out, err = run([empty])
    check('no analysis files -> exit 2 and says games=0', rc == 2 and 'games=0' in err,
          '(rc=%d, err=%r)' % (rc, err[:200]))

    print('\n2. WHO RECORDED is read, never guessed')
    nosc = make_run(tmp, 'nosidecar', sidecar=False)
    rc, out, err = run([nosc])
    check('no sidecar and no --assume -> exit 2', rc == 2 and 'unknowable' in err,
          '(rc=%d, err=%r)' % (rc, err[:200]))
    check('the refusal prints its denominator', 'sidecars=0' in err, err[:200])

    rc, out, err = run([nosc, '--assume-rec-slots', '1', '--min-games', '4'])
    check('--assume-rec-slots makes it usable', rc == 0, '(rc=%d, err=%r)' % (rc, err[:200]))
    check('and the banner calls it an assumption, not a reading', 'ASSUMED' in out, out[:400])

    withsc = make_run(tmp, 'withsidecar')
    rc, out, err = run([withsc, '--min-games', '4'])
    check('a sidecar corpus needs no assumption', rc == 0, '(rc=%d)' % rc)
    check('and the banner calls it read', 'read from' in out, out[:400])

    rc, out, err = run([withsc, '--assume-rec-slots', '8'])
    check('--assume contradicting the sidecars -> exit 2', rc == 2 and 'contradicts' in err,
          '(rc=%d, err=%r)' % (rc, err[:200]))

    bad = make_run(tmp, 'badslot', rec=(1,), rec_slots=1, sidecar_slots=(1, 9))
    rc, out, err = run([bad])
    check('a sidecar from outside 1..rec_slots -> exit 2', rc == 2 and 'outside' in err,
          '(rc=%d, err=%r)' % (rc, err[:200]))

    d1 = make_run(tmp, 'rs1', rec=(1,), rec_slots=1)
    d8 = make_run(tmp, 'rs8', rec=(1,), rec_slots=8)
    rc, out, err = run([d1, d8])
    check('sidecars disagreeing about rec_slots -> exit 2', rc == 2 and 'disagree' in err,
          '(rc=%d, err=%r)' % (rc, err[:200]))

    print('\n3. NO CONTROL LEG is a refusal, not a zero')
    allrec = make_run(tmp, 'allrec', slots=4, rec=tuple(range(1, 5)), rec_slots=4)
    rc, out, err = run([allrec, '--min-games', '4'])
    check('every slot recording -> exit 2', rc == 2 and 'no control leg' in err,
          '(rc=%d, err=%r)' % (rc, err[:200]))
    check('and it prints how many control slots there were', 'control slots=0' in err, err[:200])

    thin = make_run(tmp, 'thin', slots=16, games=1, rec=(1,))
    rc, out, err = run([thin, '--min-games', '20'])
    check('below --min-games -> exit 2 with both sides counted',
          rc == 2 and 'recording=1' in err, '(rc=%d, err=%r)' % (rc, err[:200]))

    print('\n4. DENOMINATORS -- every row carries its n (section AJ rule two)')
    rc, out, err = run([withsc, '--min-games', '4'])
    check('per-slot table prints n for all 16 slots',
          sum(1 for ln in out.splitlines() if ln.strip().startswith(tuple(str(i) for i in range(1, 17)))
              and 'REC' in ln or ln.strip().endswith('.')) >= 16, out[:600])
    check('both channels are printed, not only the load-bearing one',
          'games per slot' in out and 'timescale' in out, out[:200])

    print('\n5. THE NUMBER -- a planted recorder effect comes back exactly')
    for planted in (0.0, -0.20, +0.15):
        d = make_run(tmp, 'planted%s' % planted, rec=(1,), rec_effect=planted)
        rc, out, err = run([d, '--min-games', '4'])
        line = [ln for ln in out.splitlines() if 'residual' in ln and 'slot 1' in ln]
        got = float(line[0].split('residual')[1].split('(')[0]) if line else None
        check('planted %+.2f -> residual %+.2f' % (planted, planted),
              rc == 0 and got is not None and abs(got - planted) < 0.005,
              '(rc=%d, got=%r)' % (rc, got))

    print('\n6. THE CONFOUND is reported, not silently absorbed')
    d = make_run(tmp, 'slopey', rec=(1,), slope=0.008, rec_effect=0.0)
    rc, out, err = run([d, '--min-games', '4'])
    check('the fitted slope is the planted slope', rc == 0 and '0.00800' in out, out[:800])
    check('and the tool names the confound in words',
          'staggered' in out or 'confound' in out, out[:800])

    print('\n7. MULTI-RECORDER corpora score every recorder separately')
    d = make_run(tmp, 'rec8', rec=tuple(range(1, 9)), rec_slots=8, rec_effect=-0.10)
    rc, out, err = run([d, '--min-games', '4'])
    res = [ln for ln in out.splitlines() if 'residual' in ln and ln.strip().startswith('slot')]
    check('8 recorders -> 8 residual lines', rc == 0 and len(res) == 8, '(rc=%d, n=%d)' % (rc, len(res)))
    check('each recovers the planted -0.10',
          all(abs(float(ln.split('residual')[1].split('(')[0]) + 0.10) < 0.02 for ln in res),
          '\n'.join(res))

    print('\n8. MUTATION -- the fit must use control slots ONLY')
    # If the fit ever pools recorders in, this recorder (absurdly fast, at the
    # low end of the x-range) drags the intercept up and the slope down, and
    # the planted slope check below fails.  Every other case in this file still
    # passes under that mutation, which is what makes this the mutation case.
    d = make_run(tmp, 'outlier', rec=(1,), slope=0.008, rec_effect=+5.0)
    rc, out, err = run([d, '--min-games', '4'])
    check('a wild recorder does not move the fitted slope', rc == 0 and '0.00800' in out,
          [ln for ln in out.splitlines() if 'timescale ~' in ln])
    check('and its residual is the full planted +5.0',
          any('+5.000' in ln for ln in out.splitlines() if 'residual' in ln),
          [ln for ln in out.splitlines() if 'residual' in ln])

    print('\n9. ACCEPTANCE TEST against a committed baseline profile')
    base_json = os.path.join(tmp, 'baseline.json')
    b = make_run(tmp, 'baserun', rec=(1,), rec_effect=0.0)
    rc, out, err = run([b, '--min-games', '4', '--emit-baseline', base_json])
    check('baseline emits', rc == 0 and os.path.exists(base_json), '(rc=%d)' % rc)
    saved = json.load(open(base_json))
    check('baseline records its provenance and recorder set',
          saved.get('rec_set') == [1] and saved.get('games') == 64 and saved.get('runs'),
          json.dumps(saved)[:300])

    same = make_run(tmp, 'same', rec=tuple(range(1, 9)), rec_slots=8, rec_effect=0.0)
    rc, out, err = run([same, '--min-games', '4', '--baseline', base_json])
    check('a wave with no deficit passes (exit 0)', rc == 0 and 'beyond tolerance' in out,
          '(rc=%d)' % rc)

    slower = make_run(tmp, 'slower', rec=tuple(range(1, 9)), rec_slots=8, rec_effect=-0.30)
    rc, out, err = run([slower, '--min-games', '4', '--baseline', base_json])
    check('a wave whose recorders lost 16%% fails (exit 1)', rc == 1, '(rc=%d)' % rc)
    check('and it names the slots that failed', out.count('DEFICIT') == 8, out[-900:])

    print('\n10. THE BOX FACTOR -- a slower machine is not a recording cost')
    # Every slot, recorders included, is 17% slower than the day the baseline
    # was taken.  Charging that to recording would be reading an A-B without
    # its baseline leg.  The control slots ARE the baseline leg.
    allslow = make_run(tmp, 'allslow', rec=tuple(range(1, 9)), rec_slots=8,
                       rec_effect=0.0, base=1.50)
    rc, out, err = run([allslow, '--min-games', '4', '--baseline', base_json])
    check('a uniformly slower box does not fail the recording test', rc == 0,
          '(rc=%d)' % rc)
    check('and the box factor is printed, not hidden', 'box factor' in out, out[-600:])
    # ... but a deficit ON TOP of a slower box is still caught.
    slowplus = make_run(tmp, 'slowplus', rec=tuple(range(1, 9)), rec_slots=8,
                        rec_effect=-0.30, base=1.50)
    rc, out, err = run([slowplus, '--min-games', '4', '--baseline', base_json])
    check('a deficit on top of a slower box is still caught', rc == 1, '(rc=%d)' % rc)

    # No control slot overlapping the baseline means no box factor, so the
    # comparison is unanchored -- refuse rather than assume the box is the same.
    onlyrec = os.path.join(tmp, 'baseline_recorders_only.json')
    json.dump({'slots': {'1': {'ts': 1.81, 'n': 4}}, 'rec_set': [1], 'games': 4},
              open(onlyrec, 'w'))
    rc, out, err = run([withsc, '--min-games', '4', '--baseline', onlyrec])
    check('no overlapping CONTROL slot -> exit 2 (box factor unknowable)',
          rc == 2 and 'box factor is unknowable' in err, '(rc=%d, err=%r)' % (rc, err[:200]))

    empty_base = os.path.join(tmp, 'emptybase.json')
    json.dump({'slots': {}}, open(empty_base, 'w'))
    rc, out, err = run([withsc, '--min-games', '4', '--baseline', empty_base])
    check('a baseline with no per-slot profile -> exit 2', rc == 2 and 'no per-slot' in err,
          '(rc=%d, err=%r)' % (rc, err[:200]))

    nooverlap = os.path.join(tmp, 'faroff.json')
    json.dump({'slots': {str(s): {'ts': 1.8, 'n': 4} for s in range(100, 116)},
               'rec_set': [1], 'games': 64}, open(nooverlap, 'w'))
    rc, out, err = run([withsc, '--min-games', '4', '--baseline', nooverlap])
    check('a baseline whose slots do not overlap at all -> exit 2',
          rc == 2 and 'compared=0' in err, '(rc=%d, err=%r)' % (rc, err[:200]))
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print('\n%d checks failed' % len(failures))
sys.exit(1 if failures else 0)
