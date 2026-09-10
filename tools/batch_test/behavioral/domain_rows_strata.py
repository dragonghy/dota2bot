#!/usr/bin/env python3
"""Stratified (ab/ba) re-read of ANY `<id>_domain.py` rows file.

WHY THIS FILE EXISTS (replay-check 2026-09-10)
-----------------------------------------------
`sweep_strata.py` does this job for the WIDE sweep's detector table
(`all_findings.jsonl`).  Nothing did it for the id-specific domain tools,
and those are the ones that buy condition (a): every `<id>_domain.py`
prints one POOLED `armed vs baseline` table, e.g.

    poke_episodes            39          7

and 铁律 4(i-a) forbids that reading standing alone.  In a mirrored wave
the armed leg is ONE physical side per game (`mirror:<ids>:s<seed>:radiant`
= the `ab` layer, `:dire` = the `ba` layer -- `recover_verdict.py:279-281`),
so a pooled `armed - baseline` is `arm effect + side effect` weighted by
however the wave's games happened to split.  W62 splits 53:35 overall and
2.25 / 1.57 / 1.00 / 1.57 per run (GH #686), so the weighting is not a
rounding detail.

This tool consumes the rows file the domain tool already wrote, so the two
cannot drift apart on what a frame or an episode is: `episodes()` and
`load_sweep()` are IMPORTED from pullcamp_domain rather than re-implemented
(they are generic over the row schema every domain tool emits -- sweep,
game, hero, leg, t, plus boolean signature columns).

WHAT IT COMPUTES (4(i-c)/(i-d) verbatim)
----------------------------------------
Per seed, for the chosen signature column, using PER-GAME EPISODE RATES:

    r_ab = (armed_eps_ab - baseline_eps_ab) / n_games_ab     # armed = radiant
    r_ba = (armed_eps_ba - baseline_eps_ba) / n_games_ba     # armed = dire
    arm  = (r_ab + r_ba) / 2      # side bias ELIMINATED
    side = (r_ab - r_ba) / 2      # what the swap-average removed

then across seeds: the ARITHMETIC MEAN of the per-seed `arm`.  Never a
games-weighted pool -- 4(i-d): `games-weighted = arm + side*(N_ab-N_ba)/
(N_ab+N_ba)`, which on an unbalanced wave silently moves the number and
still looks like an ordinary number.

HOW TO READ THE OUTPUT (rule, not preference)
---------------------------------------------
* `r_ab` / `r_ba` are side-bias-UNCORRECTED.  4(i-b): opposite signs are
  noise -- register them (the tool prints them unconditionally, that is
  4(i-a)), do not conclude from them.  Marked `FLIP`.
* `arm` IS side-bias-eliminated.  4(i-c): a FLIP is not a veto on it;
  `FLIP <=> |side| > |arm|` is an identity.  Precision is `arm`'s own
  dispersion across seeds, printed as `seeds_pos/seeds` and `sd`.

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. A wave arms the WHOLE declared set at once.  Nothing here is an effect
   size for one id in isolation; it is this id's signature measured on a
   tree where 36 other ids are also armed.
2. Episode counts are execution, not quality.  WORKING/BUGGY/SILENT stays
   a frame-level question (charter hard rule: 先逐帧后聚合).
3. A seed with only one stratum (`NO-PAIR`) contributes NOTHING: half of a
   swap-average is a side reading, and printing it would be 4(i-d) by
   another route.
4. The baseline leg is the same game's other team, so `n_games` is the
   same denominator for both legs by construction -- that is why the
   difference is taken per game before it is averaged.

EXIT CODES (GH #171: "could not run" is not "passed")
    0  clean    -- a table was produced, every seed paired
    2  refused  -- no usable input (no rows, no manifest, no paired seed)
    3  findings -- a table AND a structural complaint (unpaired seed, or a
                   row whose (sweep, game) is not in any manifest)
"""
import argparse
import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pullcamp_domain import episodes, load_sweep  # noqa: E402

EXIT_CLEAN, EXIT_REFUSED, EXIT_FINDINGS = 0, 2, 3

AB, BA = 'radiant', 'dire'


def per_game_episode_counts(rows, column):
    """-> {(sweep, game): {leg: n_episodes_with_signature}}"""
    out = {}
    for ep in episodes(rows):
        if not any(r.get(column) for r in ep):
            continue
        key = (ep[0].get('sweep', ''), ep[0]['game'])
        out.setdefault(key, {}).setdefault(ep[0]['leg'], 0)
        out[key][ep[0]['leg']] += 1
    return out


def tabulate(rows, manifest, column):
    """-> (per_seed, complaints).  One entry per seed with both strata."""
    complaints = []
    counts = per_game_episode_counts(rows, column)
    for key in counts:
        if key not in manifest:
            complaints.append('rows carry %s, which is in no manifest' % (key,))

    # seed -> stratum -> [n_games, armed_eps, base_eps]
    acc = {}
    for key, m in manifest.items():
        stratum = m['side']
        cell = acc.setdefault(m['seed'], {}).setdefault(stratum, [0, 0, 0])
        cell[0] += 1
        c = counts.get(key, {})
        cell[1] += c.get('armed', 0)
        cell[2] += c.get('baseline', 0)

    per_seed = []
    for seed in sorted(acc):
        strata = acc[seed]
        if AB not in strata or BA not in strata:
            complaints.append('seed %s: NO-PAIR (only %s) -- contributes nothing'
                              % (seed, '+'.join(sorted(strata))))
            continue
        nab, aab, bab = strata[AB]
        nba, aba, bba = strata[BA]
        r_ab = (aab - bab) / nab
        r_ba = (aba - bba) / nba
        per_seed.append(dict(seed=seed, n_ab=nab, n_ba=nba,
                             armed_ab=aab, base_ab=bab,
                             armed_ba=aba, base_ba=bba,
                             r_ab=r_ab, r_ba=r_ba,
                             arm=(r_ab + r_ba) / 2.0,
                             side=(r_ab - r_ba) / 2.0))
    return per_seed, complaints


def report(per_seed, column, out=sys.stdout):
    print('signature: %s   (episodes per game, armed leg minus the SAME '
          'games\' baseline leg)' % column, file=out)
    print('%-8s %5s %5s %9s %9s %9s %9s %6s'
          % ('seed', 'n_ab', 'n_ba', 'r_ab', 'r_ba', 'arm', 'side', 'flip'),
          file=out)
    for s in per_seed:
        flip = 'FLIP' if s['r_ab'] * s['r_ba'] < 0 else ''
        print('%-8s %5d %5d %9.3f %9.3f %9.3f %9.3f %6s'
              % (s['seed'], s['n_ab'], s['n_ba'], s['r_ab'], s['r_ba'],
                 s['arm'], s['side'], flip), file=out)
    arms = [s['arm'] for s in per_seed]
    sides = [s['side'] for s in per_seed]
    sd = statistics.stdev(arms) if len(arms) > 1 else float('nan')
    print('\nACROSS SEEDS (arithmetic mean of per-seed arm -- never games-weighted)',
          file=out)
    print('  arm  mean %.3f   sd %.3f   seeds_pos %d/%d'
          % (statistics.mean(arms), sd, sum(1 for a in arms if a > 0), len(arms)),
          file=out)
    print('  side mean %.3f   (what the swap-average removed)'
          % statistics.mean(sides), file=out)
    # 4(i-d) made visible on THIS data rather than asserted in prose.
    n_ab = sum(s['n_ab'] for s in per_seed)
    n_ba = sum(s['n_ba'] for s in per_seed)
    if n_ab + n_ba:
        coef = (n_ab - n_ba) / float(n_ab + n_ba)
        print('  games-weighted pool would read %.3f (coefficient %.3f on the '
              'side term) -- NOT the estimator, printed so the gap is visible'
              % (statistics.mean(arms) + statistics.mean(sides) * coef, coef),
              file=out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='+')
    ap.add_argument('--rows', default='/tmp/pullcamp_rows.jsonl')
    ap.add_argument('--column', default='poke',
                    help='row boolean whose episodes are counted (poke, drag, '
                         'connect_own, at_camp, ...)')
    a = ap.parse_args()

    if not os.path.exists(a.rows):
        print('[refused] no rows file %s' % a.rows, file=sys.stderr)
        return EXIT_REFUSED
    rows = [json.loads(l) for l in open(a.rows) if l.strip()]
    if not rows:
        print('[refused] rows file is empty', file=sys.stderr)
        return EXIT_REFUSED
    if a.column not in rows[0]:
        print('[refused] rows carry no column %r (have: %s)'
              % (a.column, ', '.join(sorted(rows[0]))), file=sys.stderr)
        return EXIT_REFUSED

    manifest = {}
    for d in a.sweeps:
        for m in load_sweep(d):
            manifest[(d, m['game'])] = m
    if not manifest:
        print('[refused] no manifest rows', file=sys.stderr)
        return EXIT_REFUSED

    per_seed, complaints = tabulate(rows, manifest, a.column)
    if not per_seed:
        for c in complaints:
            print('  %s' % c, file=sys.stderr)
        print('[refused] no seed carries both strata', file=sys.stderr)
        return EXIT_REFUSED
    report(per_seed, a.column)
    if complaints:
        print('\nFINDINGS (%d):' % len(complaints))
        for c in complaints:
            print('  %s' % c)
        return EXIT_FINDINGS
    return EXIT_CLEAN


if __name__ == '__main__':
    sys.exit(main())
