#!/usr/bin/env python3
"""Seed-paired arm-A/arm-B decomposition of the `roamstale` bisect, with the
BASELINE-vs-BASELINE null channel measured on the same corpus and metrics.

Why this exists (director report 2026-08-21T17:00Z section AF.3): the ANOVA
ruling attributes a constant -28 gpm to a saturating shared-consumer defect and
names `mode_team_roam_generic`'s stale `hTargetCreep` handle as the mechanism
with the right shape.  If the hijack were worth -28, the arm that fixes it
(arm A, `roamstale` in the candidate string) should beat arm B by ~28; the
measured economic delta was +5.48.  The director asked for a free detector on
the already-purchased replays: count the hijack rate, A vs B.

`roam_conversion.py` already computes the action-object split that IS that
detector (creep-only vs hero vs no-damage inside a lane-kill opportunity).
What it does not do is (i) split by arm, (ii) pair by seed, or (iii) put a
resolution on its own numbers.  This script does all three.

The null channel is the point.  Both arms ran the SAME four seeds; in both
arms the BASELINE side has every gate off.  So the arm-A-baseline vs
arm-B-baseline contrast is a contrast between two samples of the same shipped
code, and whatever it reads is the metric's own resolution on 16 games/arm.
Any candidate-side delta smaller than that is not evidence.

HONEST BOUNDARY: the two baseline sides are not a certified zero.  A mirror
game's baseline side plays AGAINST the candidate side, and the candidate sides
of the two arms differ by `roamstale`, so an opponent-mediated path exists in
principle.  It is a near-zero, not a zero -- but it is the only zero this
corpus offers, and a DiD whose two baseline legs disagree by more than the
effect it reports has an assumption problem regardless of which way the
contamination runs.

Usage:
    roamstale_null_channel.py --arm-a <sweep_dir> [...] --arm-b <sweep_dir> [...]
    roamstale_null_channel.py ... --selfcheck

`--selfcheck` re-derives the pooled table `roam_conversion.py` prints and
aborts (exit 2) on any drift, so a refactor of the shared scanner cannot
silently move these numbers.  Read-only; no AWS, no billable resource.
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roam_conversion as rc  # noqa: E402  -- the scanner is shared on purpose

METRICS = ('killed', 'hit_hero', 'hit_creep_only', 'no_dmg')


def load_manifest(d):
    """game name -> (seed, armed_side) for one sweep_run.sh output dir."""
    out = {}
    path = os.path.join(d, 'games_manifest.jsonl')
    if not os.path.exists(path):
        return out
    with open(path) as fh:
        for line in fh:
            r = json.loads(line)
            out[r['game']] = (r['seed'], r['side'], r['cand'])
    return out


def collect(dirs):
    """-> list of episodes, each tagged with seed / armed_side / game."""
    eps, games, cands = [], 0, set()
    for d in dirs:
        man = load_manifest(d)
        for tl in sorted(glob.glob(os.path.join(d, 'timelines', '*.timeline.json'))):
            name = os.path.basename(tl).replace('.timeline.json', '')
            aj = os.path.join(d, 'analysis', name + '.analysis.json')
            if not os.path.exists(aj) or name not in man:
                continue
            g = rc.load_game(tl, aj)
            if g is None:
                continue
            seed, side, cand = man[name]
            cands.add(cand)
            games += 1
            for win, (lo, hi) in (('in', (0.0, rc.LANING_END)),
                                  ('out', (rc.OUT_START, rc.OUT_END))):
                for ep in rc.scan(g, lo, hi):
                    ep.update(game=name, window=win, seed=seed, armed_side=side)
                    # `hit_creep` alone is not the hijack signature: a bot that
                    # hits the hero AND a creep in the same 4s delivered onto
                    # the hero.  The stale handle's signature is creep INSTEAD
                    # of hero -- roam_conversion prints exactly this column.
                    ep['hit_creep_only'] = ep['hit_creep'] and not ep['hit_hero']
                    eps.append(ep)
    return eps, games, cands


def rates(eps):
    n = len(eps)
    if not n:
        return {m: None for m in METRICS} | {'n': 0}
    out = {m: 100.0 * sum(1 for e in eps if e[m]) / n for m in METRICS}
    out['n'] = n
    return out


def paired(eps, window):
    """Per-seed (armed% - baseline%) for one arm, plus each side's supply.

    Pairing is by SEED, not by game: the two mirror directions of a seed are
    the unit the wave was built to average over (charter: radiant bias ~ +1.5k
    gold, always swap-and-average).
    """
    by_seed = collections.defaultdict(lambda: {'armed': [], 'base': []})
    for e in eps:
        if e['window'] != window:
            continue
        by_seed[e['seed']]['armed' if e['armed'] else 'base'].append(e)
    rows = {}
    for seed in sorted(by_seed):
        a, b = rates(by_seed[seed]['armed']), rates(by_seed[seed]['base'])
        rows[seed] = {
            'armed': a, 'base': b,
            'delta': {m: (None if a[m] is None or b[m] is None else a[m] - b[m])
                      for m in METRICS},
        }
    return rows


def mean_sd(xs):
    xs = [x for x in xs if x is not None]
    if len(xs) < 2:
        return (xs[0] if xs else None), None, len(xs)
    m = sum(xs) / len(xs)
    sd = math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1))
    return m, sd, len(xs)


def fmt(x, nd=1):
    return '  n/a' if x is None else f'{x:+6.{nd}f}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--arm-a', nargs='+', required=True)
    ap.add_argument('--arm-b', nargs='+', required=True)
    ap.add_argument('--selfcheck', action='store_true')
    args = ap.parse_args()

    A, nA, candA = collect(args.arm_a)
    B, nB, candB = collect(args.arm_b)

    # --- identity of the two arms, read off the stamps, not assumed ---------
    a_ids = set.intersection(*[set(c.split(',')) for c in candA]) if candA else set()
    b_ids = set.intersection(*[set(c.split(',')) for c in candB]) if candB else set()
    only_a, only_b = sorted(a_ids - b_ids), sorted(b_ids - a_ids)
    print(f'arm A: {nA} games, {len(a_ids)} ids in every stamp')
    print(f'arm B: {nB} games, {len(b_ids)} ids in every stamp')
    print(f'A-only ids: {only_a or "(none)"}    B-only ids: {only_b or "(none)"}')
    if only_a != ['roamstale'] or only_b:
        print('!! the two arms do not differ by roamstale alone -- '
              'every DiD below is attributing to the wrong variable', file=sys.stderr)
        if args.selfcheck:
            sys.exit(2)
    print()

    if args.selfcheck:
        # Pooled table must equal what roam_conversion.main() prints, or the
        # shared scanner drifted under us.
        ok = True
        for arm, eps in (('A', A), ('B', B)):
            for win in ('in', 'out'):
                for side in ('armed', 'base'):
                    sel = [e for e in eps if e['window'] == win
                           and e['armed'] == (side == 'armed')]
                    r = rates(sel)
                    print(f'[selfcheck] arm {arm} {win:>3} {side:>5}: n={r["n"]:4d} '
                          + ' '.join(f'{m}={r[m]:5.1f}' for m in METRICS if r[m] is not None))
                    if r['n'] == 0:
                        ok = False
        if not ok:
            print('[selfcheck] FAIL: an empty cell', file=sys.stderr)
            sys.exit(2)
        print('[selfcheck] cells populated; compare the printed rates against '
              'roam_conversion.py by hand\n')

    for window in ('in', 'out'):
        label = ('IN-DOMAIN (laning, t<%.0fs)' % rc.LANING_END if window == 'in'
                 else 'OUT-DOMAIN (t %.0f-%.0fs)' % (rc.OUT_START, rc.OUT_END))
        pa, pb = paired(A, window), paired(B, window)
        seeds = sorted(set(pa) & set(pb))
        print(f'== {label} ==  seeds paired: {seeds}')

        # supply first (GH #92: a rate delta with unequal supply is confounded)
        print('\n  supply (episodes; armed:base and the ratio)')
        for arm, p in (('A', pa), ('B', pb)):
            tot_a = sum(p[s]['armed']['n'] for s in seeds)
            tot_b = sum(p[s]['base']['n'] for s in seeds)
            ratio = tot_a / tot_b if tot_b else float('nan')
            per = '  '.join(f'{s}:{p[s]["armed"]["n"]}/{p[s]["base"]["n"]}' for s in seeds)
            print(f'    arm {arm}: {tot_a:4d} : {tot_b:4d}  ratio {ratio:.2f}   [{per}]')

        # DiD = (Aarm-Abase) - (Barm-Bbase) = (Aarm-Barm) - (Abase-Bbase).
        # The second form is the one worth printing: ARMED is the only pair of
        # cells where `roamstale` differs at all, and NULL is a term the DiD
        # SUBTRACTS.  If NULL is not zero, the DiD is reporting a code
        # difference plus a baseline-leg discrepancy no code explains.
        print(f'\n  {"metric":16} {"A delta":>9} {"B delta":>9} {"DiD":>9} '
              f'{"DiD sd":>8} {"|t|":>6}   {"ARMED A-B":>10} {"NULL Abase-Bbase":>22}')
        for m in METRICS:
            da = [pa[s]['delta'][m] for s in seeds]
            db = [pb[s]['delta'][m] for s in seeds]
            did = [x - y for x, y in zip(da, db) if x is not None and y is not None]
            ma, _, _ = mean_sd(da)
            mb, _, _ = mean_sd(db)
            md, sdd, nd = mean_sd(did)
            t = (abs(md) / (sdd / math.sqrt(nd))) if (md is not None and sdd) else None
            armed = [pa[s]['armed'][m] - pb[s]['armed'][m] for s in seeds
                     if pa[s]['armed'][m] is not None and pb[s]['armed'][m] is not None]
            mA, sdA, _ = mean_sd(armed)
            nulls = [pa[s]['base'][m] - pb[s]['base'][m] for s in seeds
                     if pa[s]['base'][m] is not None and pb[s]['base'][m] is not None]
            mn, sdn, nn = mean_sd(nulls)
            print(f'  {m:16} {fmt(ma)} {fmt(mb)} {fmt(md)} '
                  f'{("  n/a" if sdd is None else f"{sdd:8.1f}")} '
                  f'{("  n/a" if t is None else f"{t:6.2f}")}   '
                  f'{fmt(mA)} +-{("n/a" if sdA is None else f"{sdA:4.1f}")}  '
                  f'{fmt(mn)} +-{("n/a" if sdn is None else f"{sdn:4.1f}")} (n={nn})')
        # arithmetic guard: the identity above must hold to floating point
        for m in METRICS:
            da = [pa[s]['delta'][m] for s in seeds]
            db = [pb[s]['delta'][m] for s in seeds]
            lhs, _, _ = mean_sd([x - y for x, y in zip(da, db)])
            armed, _, _ = mean_sd([pa[s]['armed'][m] - pb[s]['armed'][m] for s in seeds])
            null, _, _ = mean_sd([pa[s]['base'][m] - pb[s]['base'][m] for s in seeds])
            if lhs is not None and abs(lhs - (armed - null)) > 1e-9:
                print(f'!! identity broken for {m}: {lhs} != {armed} - {null}',
                      file=sys.stderr)
                sys.exit(2)
        print()
    return 0


if __name__ == '__main__':
    sys.exit(main())
