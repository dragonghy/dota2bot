#!/usr/bin/env python3
"""What does SourceTV recording actually cost a soak slot?  Read it off the
archive we already paid for.

WHY THIS EXISTS (director ruling 2026-08-22, batch-desk 08:11Z section 3.7,
GH #75).  `--rec-slots` decides how big the frame-evidence channel is: at the
shipped default of 1, fifteen of every sixteen games a wave pays for keep no
`.dem` at all, and every owner priority that is blocked on "condition (a):
verified in a real game, with frames" is therefore rationed by one integer.
Raising it has been declined for months on one sentence in
`tools/batch_test/aws/spot_run.sh:31-37` -- "raise it only on instances that are
measuring the throughput cost of SourceTV".  Nobody ever measured it, because
measuring it was believed to need a paid wave.

It does not.  Every wave since the beginning writes `<TS>_slot<N>.analysis.json`
carrying `wall_s`, `duration_s` and `effective_timescale` (= game seconds per
wall second), and in a REC_SLOTS=1 wave slot 1 is the only recorder while slots
2..N are its untreated control, running the same pool on the same box at the
same time.  The cost of recording is the difference between those two
populations.  The corpus is free, already on S3, and about 900 games deep.

WHAT IT REFUSES TO DO.  The naive read -- "slot 1 mean vs the rest" -- is
confounded, and the confound is visible in the data: mean timescale rises
monotonically with slot index among the non-recorders (slots start staggered,
`soak_loop.sh:11`, and the tail of a wave is less contended).  Reporting a bare
difference against that gradient would be a reading that is structurally a
mixture, the failure family test_set.md section 0b is about.  So this tool fits
the trend on the CONTROL slots only and scores each recorder as a residual
against its own slot index.  It also prints, per section AJ general rule two,
every denominator and both channels -- never only the load-bearing one.

TWO CHANNELS, because they fail differently:
  timescale   in-game rate.  Answers "does tv_enable slow the simulation?"
  games/slot  the whole loop, including the post-game `.dem` upload that sits
              outside wall_s.  Answers "does recording cost us games?"
A cost that hides from one shows up in the other.

WHO RECORDED IS READ, NOT INFERRED.  The recorder set comes from the
`.demclaim.json` sidecars a recording slot uploads for every game
(`soak_loop.sh:147-154`) -- not from the directory name and not from the
assumption that slot 1 always records.  A corpus older than the sidecar carries
no such evidence, and this tool REFUSES it (exit 2) unless the caller states the
assumption explicitly with --assume-rec-slots, which is then printed in the
banner as an assumption rather than a reading.

REFUSALS (exit 2, always with the denominator that motivated them):
  * no run directories / no analysis files
  * a corpus with no sidecars and no explicit --assume-rec-slots
  * sidecars that disagree with each other about rec_slots
  * every slot recorded: there is no control leg, so nothing can be certified
  * fewer than --min-games on either side
An empty corpus must never print a clean table.  CANNOT CERTIFY is a result;
a table computed over zero games is not.

USAGE
  rec_slot_cost.py <run_dir> [<run_dir> ...]        # measure
  rec_slot_cost.py <run_dir> ... --emit-baseline b.json
  rec_slot_cost.py <run_dir> ... --baseline b.json  # acceptance test of a wave
                                                    # against a committed profile
"""
import argparse
import glob
import json
import os
import re
import sys

SLOT_RE = re.compile(r'_slot(\d+)\.analysis\.json$')
CLAIM_RE = re.compile(r'_slot(\d+)\.demclaim\.json$')


def die(msg, denom=''):
    """Refuse.  Never silently: say what the denominator was."""
    sys.stderr.write('CANNOT CERTIFY: %s\n' % msg)
    if denom:
        sys.stderr.write('  denominator: %s\n' % denom)
    sys.exit(2)


def load_run(d):
    """-> (games, claims).  games: list of dicts; claims: {slot: rec_slots}."""
    games = []
    for f in sorted(glob.glob(os.path.join(d, '*.analysis.json'))):
        m = SLOT_RE.search(os.path.basename(f))
        if not m:
            continue
        try:
            a = json.load(open(f))
        except (ValueError, IOError):
            continue
        ts, wall, dur = a.get('effective_timescale'), a.get('wall_s'), a.get('duration_s')
        if not ts or not wall or not dur:
            continue
        games.append({'run': os.path.basename(d.rstrip('/')), 'slot': int(m.group(1)),
                      'ts': float(ts), 'wall': float(wall), 'dur': float(dur),
                      'ver': a.get('script_version', '')})
    claims = {}
    for f in sorted(glob.glob(os.path.join(d, '*.demclaim.json'))):
        m = CLAIM_RE.search(os.path.basename(f))
        if not m:
            continue
        try:
            c = json.load(open(f))
        except (ValueError, IOError):
            continue
        claims[int(m.group(1))] = c.get('rec_slots')
    return games, claims


def ols(xs, ys):
    """Least-squares slope/intercept.  None when the x's do not span."""
    n = len(xs)
    if n < 2:
        return None
    mx = sum(xs) / n
    my = sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx == 0:
        return None
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    b = sxy / sxx
    return b, my - b * mx


def mean(v):
    return sum(v) / len(v) if v else None


def profile(games):
    """slot -> {n, ts, wall, dur} means."""
    by = {}
    for g in games:
        by.setdefault(g['slot'], []).append(g)
    return {s: {'n': len(v), 'ts': mean([g['ts'] for g in v]),
                'wall': mean([g['wall'] for g in v]),
                'dur': mean([g['dur'] for g in v])} for s, v in by.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('runs', nargs='*')
    ap.add_argument('--assume-rec-slots', type=int, default=None,
                    help='state the recorder count for a corpus older than the '
                         'claim sidecar; printed as an assumption, not a reading')
    ap.add_argument('--min-games', type=int, default=20,
                    help='refuse rather than report below this many games per side')
    ap.add_argument('--emit-baseline', metavar='JSON')
    ap.add_argument('--baseline', metavar='JSON',
                    help='acceptance test: compare this corpus per-slot against a '
                         'committed REC_SLOTS=1 profile')
    ap.add_argument('--tolerance', type=float, default=0.05,
                    help='acceptance test: max fractional timescale deficit a '
                         'recording slot may show against the baseline profile')
    args = ap.parse_args()

    if not args.runs:
        die('no run directories given', 'runs=0')

    games, claims, missing = [], {}, []
    for d in args.runs:
        if not os.path.isdir(d):
            die('not a directory: %s' % d, 'runs=%d' % len(args.runs))
        g, c = load_run(d)
        if not c:
            missing.append(os.path.basename(d.rstrip('/')))
        games += g
        for s, rs in c.items():
            claims.setdefault(s, set()).add(rs)

    if not games:
        die('no usable *.analysis.json in %d run dir(s)' % len(args.runs),
            'games=0')

    # --- who recorded: read, or explicitly assumed -------------------------
    declared = set()
    for s, vals in claims.items():
        declared |= vals
    if claims:
        if len(declared) > 1:
            die('claim sidecars disagree about rec_slots: %s' % sorted(declared),
                'sidecar slots=%s' % sorted(claims))
        rec_slots = declared.pop()
        rec_set = set(claims)
        source = 'read from %d claim sidecar slot(s)' % len(rec_set)
        if rec_slots is not None and rec_set - set(range(1, int(rec_slots) + 1)):
            die('a slot outside 1..%s uploaded a claim sidecar: %s'
                % (rec_slots, sorted(rec_set)), 'rec_slots=%s' % rec_slots)
        if args.assume_rec_slots is not None and rec_slots is not None \
                and int(args.assume_rec_slots) != int(rec_slots):
            die('--assume-rec-slots %d contradicts the sidecars, which say %s'
                % (args.assume_rec_slots, rec_slots),
                'sidecar slots=%s' % sorted(claims))
        if missing:
            source += ' + ASSUMED identical for %d sidecar-free run(s): %s' \
                % (len(missing), ','.join(missing[:3]) + ('...' if len(missing) > 3 else ''))
    elif args.assume_rec_slots is not None:
        rec_slots = args.assume_rec_slots
        rec_set = set(range(1, rec_slots + 1))
        source = 'ASSUMED by --assume-rec-slots %d (no sidecar in this corpus)' % rec_slots
    else:
        die('no .demclaim.json anywhere: who recorded is unknowable. '
            'Pass --assume-rec-slots N to state it explicitly.',
            'runs=%d games=%d sidecars=0' % (len(args.runs), len(games)))

    prof = profile(games)
    ctrl_slots = sorted(s for s in prof if s not in rec_set)
    rec_slots_seen = sorted(s for s in prof if s in rec_set)
    n_rec = sum(prof[s]['n'] for s in rec_slots_seen)
    n_ctrl = sum(prof[s]['n'] for s in ctrl_slots)

    print('=== SourceTV recording cost, measured on the free archive ===')
    print('runs            : %d' % len(args.runs))
    print('games           : %d  (recording %d / control %d)' % (len(games), n_rec, n_ctrl))
    print('recorder set    : %s   [%s]' % (sorted(rec_set) or '-', source))
    vers = sorted({g['ver'] for g in games})
    print('script_version  : %d distinct%s' % (len(vers), (' -- ' + vers[0]) if len(vers) == 1 else ''))

    if not ctrl_slots:
        die('every slot recorded: no control leg exists in this corpus',
            'control slots=0 of %d' % len(prof))
    if n_rec < args.min_games or n_ctrl < args.min_games:
        die('below --min-games %d on one side' % args.min_games,
            'recording=%d control=%d' % (n_rec, n_ctrl))

    # --- the per-slot table: every denominator, both channels --------------
    print('\nslot  n   timescale  wall_s  dur_s   recording')
    for s in sorted(prof):
        p = prof[s]
        print('%4d %3d   %8.3f %7.0f %6.0f   %s'
              % (s, p['n'], p['ts'], p['wall'], p['dur'], 'REC' if s in rec_set else '.'))

    # --- the confound, named and fitted on controls only -------------------
    fit = ols([float(s) for s in ctrl_slots], [prof[s]['ts'] for s in ctrl_slots])
    print('\ncontrol-slot trend (fitted on the %d NON-recording slots only):' % len(ctrl_slots))
    if fit is None:
        print('  not fittable (control slots do not span) -- residuals unavailable')
    else:
        b, a = fit
        print('  timescale ~ %.5f * slot + %.4f   (slot index is a real confound:'
              ' slots start staggered and wave tails are less contended)' % (b, a))
        print('\nrecorder residual vs its own slot index  (+ = recorder FASTER than trend):')
        for s in rec_slots_seen:
            pred = b * s + a
            obs = prof[s]['ts']
            print('  slot %-2d n=%-3d observed %.3f   trend-predicted %.3f   residual %+.3f (%+.1f%%)'
                  % (s, prof[s]['n'], obs, pred, obs - pred, 100.0 * (obs - pred) / pred))

    # --- second channel: games completed per slot --------------------------
    ctrl_n = [prof[s]['n'] for s in ctrl_slots]
    print('\ngames per slot (the loop, incl. the post-game .dem upload that sits'
          ' outside wall_s):')
    print('  control slots : n=%d slots, %.2f games/slot (min %d, max %d)'
          % (len(ctrl_slots), mean(ctrl_n), min(ctrl_n), max(ctrl_n)))
    for s in rec_slots_seen:
        print('  recorder %-2d   : %d games  (%+.2f vs control mean)'
              % (s, prof[s]['n'], prof[s]['n'] - mean(ctrl_n)))

    # --- optional: emit / check a committed profile ------------------------
    if args.emit_baseline:
        out = {'generated_by': 'tools/batch_test/soak/rec_slot_cost.py',
               'runs': [os.path.basename(d.rstrip('/')) for d in args.runs],
               'games': len(games), 'rec_set': sorted(rec_set),
               'rec_slots': rec_slots, 'recorder_source': source,
               'slots': {str(s): prof[s] for s in sorted(prof)}}
        with open(args.emit_baseline, 'w') as fh:
            json.dump(out, fh, indent=2, sort_keys=True)
            fh.write('\n')
        print('\nbaseline profile written: %s (%d slots, %d games)'
              % (args.emit_baseline, len(prof), len(games)))

    verdict = 0
    if args.baseline:
        try:
            base = json.load(open(args.baseline))
        except (IOError, ValueError) as e:
            die('baseline unreadable: %s' % e, args.baseline)
        bslots = base.get('slots') or {}
        if not bslots:
            die('baseline carries no per-slot profile', args.baseline)
        print('\n=== acceptance test against %s (%d games, rec_set %s) ==='
              % (os.path.basename(args.baseline), base.get('games', 0), base.get('rec_set')))
        ratios = {}
        for s in sorted(prof):
            b = bslots.get(str(s))
            if b and b.get('ts'):
                ratios[s] = prof[s]['ts'] / b['ts']
        if not ratios:
            die('no slot in this corpus overlaps the baseline profile',
                'compared=0 of %d' % len(prof))
        # A whole box can be slower than the day the baseline was taken -- a
        # noisy neighbour, a different spot pool, a heavier hero pool.  That is
        # not recording costing anything, and blaming recording for it would be
        # the same mistake as reading an A-B without its baseline leg.  So the
        # control slots' own drift IS the baseline leg here, and a recorder is
        # only charged for what it lost ON TOP of it.
        box = [ratios[s] for s in ratios if s not in rec_set]
        if not box:
            die('no control slot overlaps the baseline: the box factor is unknowable',
                'overlapping slots=%s rec_set=%s' % (sorted(ratios), sorted(rec_set)))
        box_factor = mean(box)
        print('  box factor (control slots, now/baseline): %.3f over %d slot(s)'
              ' -- everything below is NET of this' % (box_factor, len(box)))
        worse = []
        for s in sorted(ratios):
            rel = ratios[s] / box_factor - 1.0
            flag = ''
            if s in rec_set and rel < -args.tolerance:
                flag = '  <-- DEFICIT beyond --tolerance %.0f%%' % (100 * args.tolerance)
                worse.append(s)
            print('  slot %-2d  now %.3f  baseline %.3f  raw %+.1f%%  net %+.1f%%%s'
                  % (s, prof[s]['ts'], bslots[str(s)]['ts'], 100 * (ratios[s] - 1),
                     100 * rel, flag))
        print('  compared %d slot(s); %d recording slot(s) beyond tolerance'
              % (len(ratios), len(worse)))
        verdict = 1 if worse else 0

    print('\nOK: measured on %d games, %d control slots.' % (len(games), len(ctrl_slots)))
    return verdict


if __name__ == '__main__':
    sys.exit(main())
