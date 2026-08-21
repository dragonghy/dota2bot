#!/usr/bin/env python3
"""Seed-paired arm-A/arm-B recomputation of `lf_rescue`'s condition (a), with
the BASELINE-vs-BASELINE null channel measured on the same corpus and metric.

Why this exists
---------------
Director ruling AG.2 (test_set.md, 2026-08-21T19:0xZ) bans DiD in a mirrored
two-arm bisect and orders every (a) that was registered with one recomputed as
`ARMED A-B`; `lf_rescue` is named there.  Its (a) (#37, 08-19T12:50Z) rests on
a 2x2 whose arm-B cell is **zero**: "20 precondition-true TP casts / 11 landing-
attributed on arm A, 0 and 0 on arm B, p ~ 0.008".  That arm-B cell was 7
games, because the 12:12Z wave lost three instances to spot reclaim and the
14:11Z re-run of those seeds did not exist yet.  This script re-reads the
completed, symmetric corpus (16 vs 16, 8 runs, seeds 859-862, 8r/8d per arm --
batch-desk 20:06Z section 2) and adds the two cells #37 never had: the two
BASELINE legs, which run the same shipped tree with `lf_rescue` off on BOTH,
and therefore measure the signature's background rate directly instead of
assuming it is zero.

The four cells (per seed, 4 games each):
    A_armed  13 ids, lf_rescue ON      A_base   shipped
    B_armed  12 ids, lf_rescue OFF     B_base   shipped
`ARMED A-B` is the only contrast carrying a code difference (AG.2).  The
baseline legs are a DIAGNOSTIC: they must read zero, and what they read instead
is this metric's own resolution on 16 games per arm.

Signature
---------
`tp_attribution.scan` pass A: an `item_tpscroll` cast at an instant where every
OFFLINE-OBSERVABLE `J.GetRescueTpTarget` precondition held (the damage gates
`nVsMe` / `WillAllySurviveTpWindow` are not in the replay, so this is a
superset), then landing-attributed against the deterministic
`J.GetNearbyLocationToTp` prediction (nearest ALIVE own tower, offset 575
toward the ally).  ATTRIB_U is the landing/prediction tolerance.

ATTRIB_U is not a free parameter, and the script proves that rather than
asserting it: `--sweep-threshold` re-runs the whole table at 1000/1500/2000/
3000 u.  On the 08-19 corpus the land-vs-prediction distances are bimodal with
a gap from 922 to 3069 u, so every cell is identical across that range.  (This
is the discipline `[harness] #92` asked for after `l1trade`'s bearing clause
turned out to flip sign along its own threshold -- here it does not move.)

HONEST BOUNDARY (same as roamstale_null_channel.py): the two baseline sides are
not a certified zero.  A mirror game's baseline side plays AGAINST the
candidate side, and the two arms' candidate sides differ by `lf_rescue`, so an
opponent-mediated path exists in principle.  It is a near-zero, not a zero.

FIDELITY BOUNDARY: this does NOT reproduce #37's arm-A cell bit-for-bit
(reads 26 casts / 16 attributed where #37 registered 20 / 11).  `tp_attribution.py`
entered the repo only on 08-21 (183ea2a); the script #37 actually ran was never
committed, and the committed one takes hero positions from `seed_draft` (GH #57,
08-20) where #37 used `team_slot % 5 + 1`.  Forcing the old position source
recovers 23 / 12, so roughly half the drift is that and the rest is unattributed
tool drift.  Quote 26 / 16 for this corpus.

Usage:
    lf_rescue_null_channel.py --arm-a <sweep_dir> [...] --arm-b <sweep_dir> [...]
    lf_rescue_null_channel.py ... --sweep-threshold
    lf_rescue_null_channel.py ... --selfcheck

`--selfcheck` re-derives every cell from the raw `tp_attribution.scan` return
and aborts (exit 2) on drift, and the arm guard (cand-id set difference must be
exactly {'lf_rescue'}) aborts before any number is printed.  Read-only; no AWS,
no billable resource.
"""
import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tp_attribution as TA  # noqa: E402  -- the scanner is shared on purpose

ATTRIB_U = 1000.0
SWEEP_U = (1000.0, 1500.0, 2000.0, 3000.0)
OTHER = {'radiant': 'dire', 'dire': 'radiant'}
ID = 'lf_rescue'


def load_manifest(d):
    path = os.path.join(d, 'games_manifest.jsonl')
    if not os.path.exists(path):
        sys.exit('[fatal] %s has no games_manifest.jsonl -- point me at a '
                 'sweep_run.sh output dir, not a raw S3 download' % d)
    return [json.loads(line) for line in open(path) if line.strip()]


def cand_set(rows, d):
    sets = {frozenset(r['cand'].split(',')) for r in rows}
    if len(sets) != 1:
        sys.exit('[fatal] %s mixes candidate strings across games: %s' % (d, sets))
    return next(iter(sets))


def arm_identity(dirs_a, dirs_b):
    """AG.2's machine-checked guard: read the arm from each run's own stamp
    (never from the directory name) and refuse unless the arms differ by
    exactly {lf_rescue}."""
    def one(dirs, label):
        sets, man = set(), {}
        for d in dirs:
            rows = load_manifest(d)
            sets.add(cand_set(rows, d))
            man[d] = rows
        if len(sets) != 1:
            sys.exit('[fatal] arm %s is not internally consistent: %d distinct '
                     'candidate strings' % (label, len(sets)))
        return next(iter(sets)), man
    ca, ma = one(dirs_a, 'A')
    cb, mb = one(dirs_b, 'B')
    if set(ca) - set(cb) != {ID} or set(cb) - set(ca):
        sys.exit('[fatal] arm guard: A-B=%s B-A=%s, expected exactly {%r} and '
                 'empty. These are not the two arms of the %s bisect.'
                 % (sorted(set(ca) - set(cb)), sorted(set(cb) - set(ca)), ID, ID))
    ma.update(mb)
    return ma


def attributed(hit, thr):
    if 'land_xy' not in hit or 'pred_xy' not in hit:
        return False   # never landed within the trace window -> not attributable
    return math.hypot(hit['land_xy'][0] - hit['pred_xy'][0],
                      hit['land_xy'][1] - hit['pred_xy'][1]) <= thr


def collect(dirs_a, dirs_b, man):
    """-> list of per-(game, leg) records; each leg is a separate scan."""
    out = []
    for arm, dirs in (('A', dirs_a), ('B', dirs_b)):
        for d in dirs:
            for g in man[d]:
                tl = os.path.join(d, 'timelines', g['game'] + '.timeline.json')
                aj = os.path.join(d, 'analysis', g['game'] + '.analysis.json')
                if not (os.path.exists(tl) and os.path.exists(aj)):
                    sys.exit('[fatal] missing timeline/analysis for %s' % g['game'])
                for leg, side in (('armed', g['side']), ('base', OTHER[g['side']])):
                    hits, opps = TA.scan(tl, aj, side)
                    out.append(dict(arm=arm, leg=leg, seed=g['seed'], game=g['game'],
                                    run=os.path.basename(d.rstrip('/')), side=side,
                                    casts=len(hits), hits=hits,
                                    opp_eps=len({(o['responder'], o['ally'], int(o['t'] // 10))
                                                 for o in opps})))
                    print('[scan] %s %s seed%s %-5s side=%-7s casts=%d'
                          % (arm, g['game'], g['seed'], leg, side, len(hits)),
                          file=sys.stderr)
    return out


def mean_se(v):
    n = len(v)
    m = sum(v) / n
    if n < 2:
        return m, float('nan')
    sd = math.sqrt(sum((x - m) ** 2 for x in v) / (n - 1))
    return m, sd / math.sqrt(n)


def fisher_2x2(a, b, c, d):
    def lc(n, k):
        return math.lgamma(n + 1) - math.lgamma(k + 1) - math.lgamma(n - k + 1)
    n, r1, r2, c1 = a + b + c + d, a + b, c + d, a + c
    def p(x):
        return math.exp(lc(r1, x) + lc(r2, c1 - x) - lc(n, c1))
    p0, tot = p(a), 0.0
    for x in range(max(0, c1 - r2), min(r1, c1) + 1):
        px = p(x)
        if px <= p0 * (1 + 1e-9):
            tot += px
    return min(1.0, tot)


def table(recs, thr):
    cnt = collections.defaultdict(int)
    games = collections.defaultdict(int)
    hitg = collections.defaultdict(int)
    for r in recs:
        k = (r['arm'], r['leg'], r['seed'])
        games[k] += 1
        n = sum(1 for h in r['hits'] if attributed(h, thr))
        cnt[k] += n
        hitg[k] += 1 if n else 0
    return cnt, games, hitg


def report(recs, thr, verbose=True):
    cnt, games, hitg = table(recs, thr)
    seeds = sorted({r['seed'] for r in recs})
    per_arm = sum(games[('A', 'armed', s)] for s in seeds)
    if verbose:
        print('\n' + '=' * 74)
        print('ARMED A-B is the estimator (director ruling AG.2). The two BASELINE')
        print('legs are the SAME shipped code -- their difference is a diagnostic')
        print('that must read zero, NOT a term to subtract. Do not form a DiD.')
        print('=' * 74)
        print('\nattributed rescue-shaped TPs (landing within %du of the '
              'GetNearbyLocationToTp prediction)\n' % thr)
        print('| seed | A_armed | A_base | B_armed | B_base |')
        print('|---|---|---|---|---|')
        for s in seeds:
            print('| %s | %d | %d | %d | %d |'
                  % (s, cnt[('A', 'armed', s)], cnt[('A', 'base', s)],
                     cnt[('B', 'armed', s)], cnt[('B', 'base', s)]))
        print('| **total (%dg per cell)** | **%d** | **%d** | **%d** | **%d** |'
              % (per_arm,
                 sum(cnt[('A', 'armed', s)] for s in seeds),
                 sum(cnt[('A', 'base', s)] for s in seeds),
                 sum(cnt[('B', 'armed', s)] for s in seeds),
                 sum(cnt[('B', 'base', s)] for s in seeds)))

    def rate(arm, leg, s):
        return cnt[(arm, leg, s)] / games[(arm, leg, s)]

    armed = [rate('A', 'armed', s) - rate('B', 'armed', s) for s in seeds]
    null = [rate('A', 'base', s) - rate('B', 'base', s) for s in seeds]
    ma, sea = mean_se(armed)
    mn, sen = mean_se(null)
    if verbose:
        print('\nARMED A-B  %+.3f /game  SE %.3f  |t| %.2f   per-seed %s'
              % (ma, sea, abs(ma / sea) if sea else float('inf'),
                 [round(x, 2) for x in armed]))
        print('NULL  A-B  %+.3f /game  SE %.3f          per-seed %s   <- must be 0'
              % (mn, sen, [round(x, 2) for x in null]))
        print('the DiD AG.2 forbids would have read %+.3f (ARMED share %.0f%%)'
              % (ma - mn, 100 * ma / (ma - mn) if (ma - mn) else float('nan')))
        ga = sum(hitg[('A', 'armed', s)] for s in seeds)
        gb = sum(hitg[('B', 'armed', s)] for s in seeds)
        ba = sum(hitg[('A', 'base', s)] for s in seeds)
        bb = sum(hitg[('B', 'base', s)] for s in seeds)
        print('\ngames with >=1 attributed rescue TP (of %d per cell):' % per_arm)
        print('  ARMED  A %2d vs B %2d   Fisher p=%.4f' % (ga, gb, fisher_2x2(ga, per_arm - ga, gb, per_arm - gb)))
        print('  NULL   A %2d vs B %2d   Fisher p=%.4f' % (ba, bb, fisher_2x2(ba, per_arm - ba, bb, per_arm - bb)))
        # #92: never quote a domain rate without both arms' supply
        for leg in ('armed', 'base'):
            sa = sum(r['opp_eps'] for r in recs if r['arm'] == 'A' and r['leg'] == leg) / float(per_arm)
            sb = sum(r['opp_eps'] for r in recs if r['arm'] == 'B' and r['leg'] == leg) / float(per_arm)
            print('supply %-5s: A %.2f vs B %.2f opportunity-episodes/game  ratio %.2f'
                  % (leg, sa, sb, sa / sb if sb else float('nan')))
        # the BUGGY half of #37, now with a control arm
        print('\nlanding->ally distance at cast (the #37 pathology), by cell:')
        for arm, leg in (('A', 'armed'), ('B', 'armed'), ('A', 'base'), ('B', 'base')):
            d = sorted(h['land_to_ally_at_cast'] for r in recs
                       if r['arm'] == arm and r['leg'] == leg
                       for h in r['hits']
                       if attributed(h, thr) and h.get('land_to_ally_at_cast') is not None)
            if d:
                print('  %s/%-5s n=%2d  min %4d / median %4d / max %4d'
                      % (arm, leg, len(d), d[0], d[len(d) // 2], d[-1]))
    return dict(cells={k: cnt[k] for k in cnt}, armed=ma, null=mn)


def selfcheck(recs, thr):
    """Recount every cell straight off the raw scan return; exit 2 on drift."""
    cnt, games, _ = table(recs, thr)
    raw = collections.defaultdict(int)
    for r in recs:
        for h in r['hits']:
            if 'land_xy' in h and 'pred_xy' in h:
                dx = h['land_xy'][0] - h['pred_xy'][0]
                dy = h['land_xy'][1] - h['pred_xy'][1]
                if (dx * dx + dy * dy) ** 0.5 <= thr:
                    raw[(r['arm'], r['leg'], r['seed'])] += 1
    bad = [k for k in set(list(cnt) + list(raw)) if cnt[k] != raw[k]]
    if bad:
        print('[selfcheck] FAIL: %s' % bad, file=sys.stderr)
        sys.exit(2)
    empty = [k for k in games if games[k] == 0]
    if empty or len(games) != 16:
        print('[selfcheck] FAIL: expected 16 (arm,leg,seed) cells, got %d%s'
              % (len(games), ' with empties %s' % empty if empty else ''), file=sys.stderr)
        sys.exit(2)
    print('[selfcheck] OK: 16 cells, all non-empty, counts reproduce off the raw scan',
          file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--arm-a', nargs='+', required=True,
                    help='sweep_run.sh output dirs for the arm WITH lf_rescue')
    ap.add_argument('--arm-b', nargs='+', required=True,
                    help='sweep_run.sh output dirs for the arm WITHOUT it')
    ap.add_argument('--threshold', type=float, default=ATTRIB_U)
    ap.add_argument('--sweep-threshold', action='store_true',
                    help='re-run the whole table at %s u' % (SWEEP_U,))
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--json')
    a = ap.parse_args()

    man = arm_identity(a.arm_a, a.arm_b)   # aborts before any number is printed
    print('[guard] arm A - arm B = {%r}; arm B - arm A = {} -- single variable OK' % ID,
          file=sys.stderr)
    recs = collect(a.arm_a, a.arm_b, man)
    if a.selfcheck:
        selfcheck(recs, a.threshold)
    out = report(recs, a.threshold)
    if a.sweep_threshold:
        print('\nthreshold sensitivity (a moving cell here means ATTRIB_U is a '
              'free parameter -- see [harness] #92):')
        for thr in SWEEP_U:
            r = report(recs, thr, verbose=False)
            print('  %5du  A_armed=%2d A_base=%2d B_armed=%2d B_base=%2d  ARMED A-B %+.3f  NULL %+.3f'
                  % (thr,
                     sum(v for k, v in r['cells'].items() if k[0] == 'A' and k[1] == 'armed'),
                     sum(v for k, v in r['cells'].items() if k[0] == 'A' and k[1] == 'base'),
                     sum(v for k, v in r['cells'].items() if k[0] == 'B' and k[1] == 'armed'),
                     sum(v for k, v in r['cells'].items() if k[0] == 'B' and k[1] == 'base'),
                     r['armed'], r['null']))
    if a.json:
        json.dump([{k: v for k, v in r.items() if k != 'hits'} for r in recs],
                  open(a.json, 'w'), indent=1)


if __name__ == '__main__':
    main()
