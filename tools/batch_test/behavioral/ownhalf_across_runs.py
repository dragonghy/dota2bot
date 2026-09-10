#!/usr/bin/env python3
"""Roll `ownhalf_domain.py` up across the runs of one wave -- WITHOUT pooling.

    ownhalf_across_runs.py <sweep_out_dir> [<sweep_out_dir> ...]

Why this exists rather than "just run the domain tool on all the games":
iron rule 4(i-d) forbids pooling by game count.  Each run is its own seed with
its own draft, and the ab/ba split is imbalanced (GH #686: W62 ran ~2.1:1), so
concatenating games silently weights the wave toward whichever leg happened to
finish more games.  This prints one row per run per stratum and then takes the
ARITHMETIC mean across runs, which is the estimator rule 4(i-d) asks for.

It prints the real DiD next to the PLACEBO DiD in the same row.  The placebo is
the same statistic computed on `shipped`, a band whose Lua is identical on both
legs -- so it is what the estimator returns when the lever is known absent.
On W62 that mattered: the `engaged` metric's placebo came back +22.7 / +23.2 /
+22.3 pp on the ba stratum of three separate runs, LARGER than the real reading
it was supposed to be evidence for.  Read `real` against `placebo`, never
against zero.

Reads nothing but the sweep dirs on disk; costs nothing.
"""
import re
import subprocess
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DOMAIN = os.path.join(HERE, 'ownhalf_domain.py')

BLOCK = {'DISCONTINUITY AT THE CONSTANT': 'real', 'PLACEBO': 'placebo'}
ROW = re.compile(r'^  (ab|ba): closed\s+([-+][\d.]+) pp\s+engaged\s+([-+][\d.]+) pp')
BAND = re.compile(r'^  ownhalf (\d+) : shipped (\d+)\s+=\s+([\d.]+)x')


def one_run(sweep_dir):
    out = subprocess.run([sys.executable, DOMAIN, '--sweep', sweep_dir],
                         capture_output=True, text=True).stdout
    vals, band, key = {}, None, None
    for line in out.splitlines():
        for prefix, name in BLOCK.items():
            if line.startswith(prefix):
                key = name
        if line.startswith('BAND SIZE'):
            key = None
        m = ROW.match(line)
        if m and key:
            vals[(key, m.group(1))] = (float(m.group(2)), float(m.group(3)))
        m = BAND.match(line)
        if m:
            band = float(m.group(3))
    return vals, band


def mean(xs):
    return sum(xs) / len(xs) if xs else float('nan')


def main():
    dirs = sys.argv[1:]
    if not dirs:
        sys.exit(__doc__)
    rows, bands = [], []
    for d in dirs:
        vals, band = one_run(d)
        rows.append((os.path.basename(d.rstrip('/'))[-6:], vals))
        if band is not None:
            bands.append(band)

    for metric, mi in (('closed', 0), ('engaged', 1)):
        print('=== %s (percentage points) ===' % metric)
        print('%-8s %-4s %9s %9s %9s' %
              ('run', 'str', 'real', 'placebo', 'real-plac'))
        for stratum in ('ab', 'ba'):
            got = []
            for name, vals in rows:
                r = vals.get(('real', stratum))
                p = vals.get(('placebo', stratum))
                if r is None or p is None:
                    print('%-8s %-4s %9s' % (name, stratum, 'n/a'))
                    continue
                got.append((r[mi], p[mi]))
                print('%-8s %-4s %+9.1f %+9.1f %+9.1f'
                      % (name, stratum, r[mi], p[mi], r[mi] - p[mi]))
            if got:
                print('%-8s %-4s %+9.2f %+9.2f %+9.2f   <- arithmetic mean '
                      'across runs (NOT game-weighted, rule 4(i-d))'
                      % ('MEAN', stratum, mean([g[0] for g in got]),
                         mean([g[1] for g in got]),
                         mean([g[0] - g[1] for g in got])))
                better = sum(1 for g in got if g[0] > g[1])
                print('%-8s %-4s runs where real > placebo: %d/%d'
                      % ('', stratum, better, len(got)))
        print('')

    if bands:
        print('=== band size, ownhalf : shipped (GH #695) ===')
        print('  per run: %s' % '  '.join('%.2fx' % b for b in bands))
        print('  mean %.2fx over %d run(s)' % (mean(bands), len(bands)))


if __name__ == '__main__':
    main()
