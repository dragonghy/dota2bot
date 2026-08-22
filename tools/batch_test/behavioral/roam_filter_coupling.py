#!/usr/bin/env python3
"""VICTIM_HP sensitivity scan for the `roamstale` in-domain cost (AG.4 step 1).

WHY THIS EXISTS
---------------
`roam_conversion.py:VICTIM_HP = 0.40` is a FREE PARAMETER.  It is a proxy for
the clause that actually gates `J.ShouldInitiateLaneKill` -- an absolute burst
-vs-health comparison (`jmz_func.lua:6932`) that the dumper stream cannot
reconstruct, because `GetEstimatedDamageToTarget` is not in it.  The docstring
of the sibling scanner declares the proxy honestly; what nobody had measured is
whether the READING is stable along it.

GH #92 measured exactly that for the other consumer of the same 0.40 constant
(`lanekill_commit.py`) and found the registered -17.5pp walks monotonically to
+9.3pp as the threshold is relaxed, in lockstep with the armed:baseline SUPPLY
RATIO (1.26 -> 0.83).  There the delta was a supply artifact.  The director
pre-registered (test_set.md AG.4) that the `roamstale` in-domain cost -- ARMED
A-B `no_dmg +7.1pp` / `hit_hero -7.2pp`, supply ratio 0.98 -- stays PROVISIONAL
until the same scan is run here, and that the rollback ladder for `roamstale`
(-> `roamreach` -> re-gate) may not be climbed before it.

WHAT IT MEASURES, AND ON WHICH CHANNEL
--------------------------------------
The estimator is the two-arm **ARMED A-B** (arm A candidate side vs arm B
candidate side, seed-paired), NOT the within-arm armed-vs-baseline leg.  That
is the AG ruling: in a mirrored wave the two sides play each other, so a
within-arm delta is negatively coupled with itself.  #92's scan ran on a leg
because that is what #77 had registered; this one must not repeat that.

Alongside every ARMED A-B number the scan prints the BASELINE-leg contrast
(arm-A-baseline vs arm-B-baseline).  Both arms ran the same seeds with every
gate off on the baseline side, so that column is the metric's own resolution:
a candidate-side delta smaller than it is not evidence.  This is the free null
channel that GH #96 / test_set.md AI.4 made mandatory.

THE DEDUP CLOCK IS NOT SEPARABLE FROM THE THRESHOLD (#92 section 6)
-------------------------------------------------------------------
`rc.scan` keeps one 6s clock per (actor, victim) and stamps it BEFORE the
outcome is scored, so relaxing the threshold does not merely add episodes -- it
DELETES registered ones (a t=76.4 high-HP episode masks the t=77.4 low-HP
episode that the strict threshold would have kept).  Every threshold therefore
re-runs the whole scan from a clean clock.  Band-scanning and summing is a
different function and is not what this computes.

`--selfcheck` re-derives, at the registered T=0.40, the episode set that
`roamstale_null_channel.collect()` builds and compares it field-for-field;
any drift aborts with exit 2.  The games are parsed once and re-scanned per
threshold, and that cache is the thing the selfcheck exists to police.

Usage:
    roam_filter_coupling.py --arm-a <sweep_dir> [...] --arm-b <sweep_dir> [...]
                            [--thresholds 0.25,0.40,...] [--selfcheck]

Read-only; no AWS, no billable resource.
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roam_conversion as rc            # noqa: E402 -- shared scanner on purpose
import roamstale_null_channel as nc     # noqa: E402 -- shared collect/pairing

METRICS = nc.METRICS
DEFAULT_T = (0.25, 0.40, 0.55, 0.70, 0.85, 1.01)
REGISTERED_T = 0.40


def load_games(dirs):
    """Parse every attributable game ONCE.

    Mirrors nc.collect()'s selection exactly (same manifest requirement, same
    load_game, same skip conditions); it stops short of scanning so that the
    scan can be re-run per threshold with a clean dedup clock.
    """
    out = []
    for d in dirs:
        man = nc.load_manifest(d)
        for tl in sorted(glob.glob(os.path.join(d, 'timelines', '*.timeline.json'))):
            name = os.path.basename(tl).replace('.timeline.json', '')
            aj = os.path.join(d, 'analysis', name + '.analysis.json')
            if not os.path.exists(aj) or name not in man:
                continue
            g = rc.load_game(tl, aj)
            if g is None:
                continue
            seed, side, cand = man[name]
            out.append({'g': g, 'name': name, 'seed': seed, 'side': side, 'cand': cand})
    return out


def episodes_at(games, threshold):
    """Full re-scan of every game at `threshold`, clean clock, both windows."""
    saved, rc.VICTIM_HP = rc.VICTIM_HP, threshold
    try:
        eps = []
        for rec in games:
            for win, (lo, hi) in (('in', (0.0, rc.LANING_END)),
                                  ('out', (rc.OUT_START, rc.OUT_END))):
                for ep in rc.scan(rec['g'], lo, hi):
                    ep.update(game=rec['name'], window=win,
                              seed=rec['seed'], armed_side=rec['side'])
                    ep['hit_creep_only'] = ep['hit_creep'] and not ep['hit_hero']
                    eps.append(ep)
        return eps
    finally:
        rc.VICTIM_HP = saved


def _key(e):
    """Identity of an episode for the selfcheck, including every scored field."""
    return (e['game'], e['window'], round(e['t'], 3), e['actor'], e['victim'],
            e['actor_team'], e['armed'], e['killed'], e['hit_hero'],
            e['hit_creep'], e['no_dmg'], e['hit_creep_only'])


def selfcheck(games, dirs_a, dirs_b):
    """The cached re-scan at T=0.40 must equal what nc.collect() builds."""
    ok = True
    for label, dirs in (('A', dirs_a), ('B', dirs_b)):
        ref, _, _ = nc.collect(dirs)
        mine = [e for e in episodes_at([r for r in games if r['side_of'] == label],
                                       REGISTERED_T)]
        r, m = sorted(map(_key, ref)), sorted(map(_key, mine))
        if r != m:
            print(f'[selfcheck] FAIL arm {label}: cached re-scan differs from '
                  f'nc.collect() ({len(m)} vs {len(r)} episodes)', file=sys.stderr)
            for x in [k for k in r if k not in set(m)][:3]:
                print(f'  only in nc.collect(): {x}', file=sys.stderr)
            for x in [k for k in m if k not in set(r)][:3]:
                print(f'  only in re-scan:      {x}', file=sys.stderr)
            ok = False
        else:
            print(f'[selfcheck] arm {label}: {len(m)} episodes identical to '
                  f'nc.collect() at T={REGISTERED_T}')
    if not ok:
        sys.exit(2)


def armed_ab(eps_a, eps_b, window):
    """Seed-paired ARMED A-B and the baseline-leg NULL, per metric.

    Returns (armed_stats, null_stats, supply) where supply carries both the
    episode counts the rates are computed on and the per-game rate -- #92's
    acceptance criterion demands the ratio AND the absolute count, because a
    stable ratio can still hide both arms drifting together.
    """
    pa, pb = nc.paired(eps_a, window), nc.paired(eps_b, window)
    seeds = sorted(set(pa) & set(pb))
    armed, null = {}, {}
    for m in METRICS:
        a = [pa[s]['armed'][m] - pb[s]['armed'][m] for s in seeds
             if pa[s]['armed'][m] is not None and pb[s]['armed'][m] is not None]
        n = [pa[s]['base'][m] - pb[s]['base'][m] for s in seeds
             if pa[s]['base'][m] is not None and pb[s]['base'][m] is not None]
        armed[m] = nc.mean_sd(a)
        null[m] = nc.mean_sd(n)
    supply = {
        'a_armed': sum(pa[s]['armed']['n'] for s in seeds),
        'b_armed': sum(pb[s]['armed']['n'] for s in seeds),
        'a_base': sum(pa[s]['base']['n'] for s in seeds),
        'b_base': sum(pb[s]['base']['n'] for s in seeds),
        'seeds': seeds,
    }
    return armed, null, supply


def t_stat(mean, sd, n):
    if mean is None or not sd or n < 2:
        return None
    return abs(mean) / (sd / math.sqrt(n))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--arm-a', nargs='+', required=True)
    ap.add_argument('--arm-b', nargs='+', required=True)
    ap.add_argument('--thresholds', default=','.join(str(t) for t in DEFAULT_T))
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--json-out')
    args = ap.parse_args()

    thresholds = [float(x) for x in args.thresholds.split(',') if x.strip()]
    if REGISTERED_T not in thresholds:
        print(f'!! T={REGISTERED_T} (the registered value) is not in the scan; '
              'the scan cannot show where the registered number sits',
              file=sys.stderr)
        sys.exit(2)

    ga = load_games(args.arm_a)
    gb = load_games(args.arm_b)
    for r in ga:
        r['side_of'] = 'A'
    for r in gb:
        r['side_of'] = 'B'
    print(f'arm A: {len(ga)} games   arm B: {len(gb)} games')

    a_ids = set.intersection(*[set(r['cand'].split(',')) for r in ga]) if ga else set()
    b_ids = set.intersection(*[set(r['cand'].split(',')) for r in gb]) if gb else set()
    only_a, only_b = sorted(a_ids - b_ids), sorted(b_ids - a_ids)
    print(f'A-only ids: {only_a or "(none)"}    B-only ids: {only_b or "(none)"}')
    if only_a != ['roamstale'] or only_b:
        print('!! the two arms do not differ by roamstale alone -- the scan '
              'below would be attributing to the wrong variable', file=sys.stderr)
        sys.exit(2)
    print()

    if args.selfcheck:
        selfcheck(ga + gb, args.arm_a, args.arm_b)
        print()

    rows = []
    for window in ('in', 'out'):
        label = ('IN-DOMAIN (laning, t<%.0fs)' % rc.LANING_END if window == 'in'
                 else 'OUT-DOMAIN (t %.0f-%.0fs)' % (rc.OUT_START, rc.OUT_END))
        print(f'== {label} ==   estimator: seed-paired ARMED A-B; '
              'NULL = baseline leg (same shipped code both arms)')
        print(f'  {"T":>5} {"nA":>5} {"nB":>5} {"supply":>7} {"ep/game":>8}  '
              + '  '.join(f'{m:>22}' for m in METRICS))
        for T in thresholds:
            ea, eb = episodes_at(ga, T), episodes_at(gb, T)
            armed, null, sup = armed_ab(ea, eb, window)
            ratio = sup['a_armed'] / sup['b_armed'] if sup['b_armed'] else float('nan')
            per_game = (sup['a_armed'] + sup['b_armed']) / (len(ga) + len(gb))
            cells = []
            for m in METRICS:
                ma, sda, na = armed[m]
                mn, _, _ = null[m]
                t = t_stat(ma, sda, na)
                cells.append(f'{nc.fmt(ma)}{"" if t is None else f"/t{t:4.2f}"}'
                             f'[N{nc.fmt(mn)}]')
            mark = ' <-- REGISTERED' if abs(T - REGISTERED_T) < 1e-9 else ''
            print(f'  {T:5.2f} {sup["a_armed"]:5d} {sup["b_armed"]:5d} '
                  f'{ratio:7.2f} {per_game:8.2f}  ' + '  '.join(cells) + mark)
            rows.append({'window': window, 'threshold': T, 'supply_ratio': ratio,
                         'episodes_per_game': per_game,
                         'n_a_armed': sup['a_armed'], 'n_b_armed': sup['b_armed'],
                         'armed_ab': {m: armed[m][0] for m in METRICS},
                         'null': {m: null[m][0] for m in METRICS},
                         't': {m: t_stat(*armed[m]) for m in METRICS}})
        print()

    print('READING RULE (pre-registered, test_set.md AG.4 / AJ):')
    print('  * a delta that tracks the supply ratio monotonically along T is a')
    print('    supply artifact, not an effect -- that is how #92 died;')
    print('  * a delta smaller than |NULL| at the same T is below the metric\'s')
    print('    own resolution and is not evidence either way;')
    print('  * per #92 section 7, any downstream citation of a number from this')
    print('    table must carry (i) the supply ratio, (ii) episodes/game and')
    print('    (iii) the threshold it was read at;')
    print('  * (iv) NEW, #101 section 4.1 promoted to a hard column by the')
    print('    director ruling of 2026-08-22T14:5xZ: also carry the')
    print('    COMPOSITION-ATTRIBUTABLE NULL, SUM_h (s_A(h) - s_B(h)) * rbar(h),')
    print('    in pp -- the same unit as the effect being reported, so the two')
    print('    can be read against each other. Computed by')
    print('    null_leg_occupancy.py:report_composition_null. It is NOT the')
    print('    occupancy correlation r: r is a per-corpus property, while the')
    print('    quantity that can fake an effect is the PRODUCT of the mix')
    print('    difference and the per-hero rate spread. On `capmono` that')
    print('    product explained only -27% of the NULL and came out with the')
    print('    WRONG SIGN, which is the reason the column is mandatory rather')
    print('    than a screening step: a small r does not license skipping it.')

    if args.json_out:
        with open(args.json_out, 'w') as fh:
            json.dump({'registered_t': REGISTERED_T, 'rows': rows}, fh, indent=1)
        print(f'\nwrote {args.json_out}')


if __name__ == '__main__':
    main()
