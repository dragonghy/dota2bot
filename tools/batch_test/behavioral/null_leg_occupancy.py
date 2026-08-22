#!/usr/bin/env python3
"""Per-hero DOMAIN OCCUPANCY of the two BASELINE legs of a mirrored bisect.

This is the acceptance test issue #101 section 5 asked for.  #101 measured, on the
`capmono` corpus, that the two baseline legs of a mirrored A/B bisect -- same
seeds, same tree, every gate off on both, roster byte-identical -- nevertheless
put an almost UNCORRELATED set of heroes inside the detector's domain
(Pearson r = +0.01), while the in-domain behaviour rate depends strongly on
WHICH hero (42.5pp spread).  That is a mechanism for a non-zero NULL leg that
needs no opponent-mediated path: mirror pairing controls the DRAFT, it does not
control WHO WALKS INTO THE DOMAIN, because occupancy is a downstream outcome of
the game and was never randomised.

#101 section 5 states the acceptance verbatim:

    run the per-hero occupancy correlation on the two baseline legs of ANY
    existing bisect corpus (`roamstale`, `lf_rescue`, `capmono`); if r is near
    zero on all three, 4.1 should become a hard column; if some corpus reads
    r clearly > 0, that corpus's NULL needs another explanation.

So this script takes a corpus id and does exactly that, for all three, through
ONE code path.  `capmono` is carried not because it needs redoing but as the
POSITIVE CONTROL (charter trap list, 2026-08-21T10:51Z item (C): a null result
needs a probe proven to fire): the generic path must re-derive the registered
r = +0.01 / Jaccard 0.62/0.83/0.67/0.43 before its readings on the other two
corpora mean anything.  `--selfcheck` enforces that as an exit code.

ZERO SECOND IMPLEMENTATION.  Each corpus's domain is whatever that corpus's own
registered scanner already calls the domain; this file imports it and never
re-derives it:

    capmono    capmono_refusal.scan_game   domain frames (HP 42-50%, enemy
                                           1100-1500u, hurt ally within 1200u)
    roamstale  roam_conversion.scan        lane-kill opportunity episodes
                                           (both the IN and OUT windows that
                                           `roamstale_null_channel.py` reports)
    lf_rescue  tp_attribution.scan         gate-passing TP casts

BASELINE LEGS ONLY.  In a mirror game one physical team is the candidate side
and the other is stock code; only the stock side is read here.  The armed legs
are not part of this question and are deliberately not printed -- the claim
under test is about two samples of the SAME code.

Usage:
    null_leg_occupancy.py --corpus roamstale --arm-a <sweep_dir> [...] \
                                             --arm-b <sweep_dir> [...]
    null_leg_occupancy.py --corpus capmono ... --selfcheck

Sweep dirs are `sweep_run.sh` output dirs (they carry `games_manifest.jsonl`,
`timelines/`, `analysis/`).  Read-only; no AWS, no billable resource.

Reporting discipline this tool follows, from the charter trap list:
  * heroes are canon-ised on BOTH sides before comparison (2026-08-21);
  * the arm guard reads the candidate string from each game's own stamp, never
    from the directory name, and exits BEFORE printing any number (AG.2);
  * per-hero rates are printed with their denominators, and the spread line
    names the n>=MIN_RATE_N floor it used (#92);
  * `-interval` of the underlying sweep is echoed as UNKNOWN unless the caller
    passes it -- frame-level numbers are not comparable across intervals
    (2026-08-21T10:51Z item (B)).
"""
import argparse
import collections
import glob
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roam_conversion as rc      # noqa: E402  -- shared scanner, on purpose
import capmono_refusal as cr      # noqa: E402
import tp_attribution as TA       # noqa: E402

OTHER = {'radiant': 'dire', 'dire': 'radiant'}
MIN_RATE_N = 10          # #101 printed its per-hero rate spread at n >= 10
CORPORA = ('capmono', 'roamstale', 'lf_rescue')

# #101's registered capmono readings, used as the positive control.
CONTROL = {
    'r': 0.01,
    'jaccard': {'888': 0.62, '895': 0.83, '896': 0.67, '906': 0.43},
    'pooled': (86, 103),
}


# ---------------------------------------------------------------- utilities

def load_manifest(d):
    """Read a sweep dir's manifest, and REFUSE a partial sweep.

    `sweep_run.sh` appends to `games_manifest.jsonl` as it goes and writes
    `sweep_summary.md` only at the end, so a sweep that dies partway leaves a
    directory that is byte-for-byte indistinguishable from a complete one to
    every consumer in this directory -- they all key off the manifest alone.
    Measured 2026-08-22: two concurrent `sweep_run.sh` runs race on the shared
    `.dumper_cache/behav-dump` that `get_dumper.sh` re-fetches, one of them
    dies with `Permission denied` mid-run, and the dir is left holding 1 of 4
    games.  The corpus then reads 13 games instead of 16 and NOTHING says so.
    (GH [harness] issue filed; guard kept here so this tool is safe meanwhile.)

    So: require the end-of-run summary, and require its `games swept:` count to
    match the manifest's line count.
    """
    path = os.path.join(d, 'games_manifest.jsonl')
    if not os.path.exists(path):
        sys.exit('[fatal] %s has no games_manifest.jsonl -- point me at a '
                 'sweep_run.sh output dir, not a raw S3 download' % d)
    rows = [json.loads(line) for line in open(path) if line.strip()]
    summary = os.path.join(d, 'sweep_summary.md')
    if not os.path.exists(summary):
        sys.exit('[fatal] %s has games_manifest.jsonl but NO sweep_summary.md: '
                 'sweep_run.sh writes the summary last, so this sweep died '
                 'partway and the manifest is a PARTIAL corpus (%d games). '
                 'Re-run the sweep for this prefix.' % (d, len(rows)))
    claimed = None
    for line in open(summary):
        if line.startswith('games swept:'):
            claimed = int(line.split(':')[1].split('(')[0].strip())
            break
    if claimed is None:
        sys.exit('[fatal] %s/sweep_summary.md has no "games swept:" line' % d)
    if claimed != len(rows):
        sys.exit('[fatal] %s: sweep_summary.md claims %d games swept but '
                 'games_manifest.jsonl holds %d -- the dir was written by more '
                 'than one run. Re-sweep it.' % (d, claimed, len(rows)))
    return rows


def arm_guard(dirs_a, dirs_b, corpus):
    """AG.2's machine-checked guard.

    The arm identity comes from the games' own mirror stamps.  Aborts BEFORE
    any number is printed unless the two arms differ by exactly {corpus}.
    """
    def one(dirs, label):
        sets, man = set(), {}
        for d in dirs:
            rows = load_manifest(d)
            cs = {frozenset(r['cand'].split(',')) for r in rows}
            if len(cs) != 1:
                sys.exit('[fatal] %s mixes candidate strings across games: %s'
                         % (d, cs))
            sets.add(next(iter(cs)))
            man[d] = rows
        if not sets:
            sys.exit('[fatal] arm %s has no swept games' % label)
        if len(sets) != 1:
            sys.exit('[fatal] arm %s is not internally consistent: %d distinct '
                     'candidate strings' % (label, len(sets)))
        return next(iter(sets)), man

    ca, ma = one(dirs_a, 'A')
    cb, mb = one(dirs_b, 'B')
    only_a, only_b = set(ca) - set(cb), set(cb) - set(ca)
    if only_a != {corpus} or only_b:
        sys.exit('[fatal] arm guard: A-B=%s B-A=%s, expected exactly {%r} and '
                 'empty. These are not the two arms of the %s bisect.'
                 % (sorted(only_a), sorted(only_b), corpus, corpus))
    ma.update(mb)
    return ma, len(set(ca) & set(cb))


def pretty(h):
    """Display only.  `canon_hero` collapses underscores to make a JOIN KEY
    (GH #82); it is not a name.  Stripping the class prefix back off is
    cosmetic and never touches the key used for grouping."""
    return h[len('npcdotahero'):] if h.startswith('npcdotahero') else h


def pearson(xs, ys):
    n = len(xs)
    if n < 2:
        return None
    mx, my = sum(xs) / n, sum(ys) / n
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    sxx = sum((x - mx) ** 2 for x in xs)
    syy = sum((y - my) ** 2 for y in ys)
    if sxx <= 0 or syy <= 0:
        return None
    return sxy / math.sqrt(sxx * syy)


def spearman(xs, ys):
    def rank(v):
        order = sorted(range(len(v)), key=lambda i: v[i])
        r = [0.0] * len(v)
        i = 0
        while i < len(order):
            j = i
            while j + 1 < len(order) and v[order[j + 1]] == v[order[i]]:
                j += 1
            avg = (i + j) / 2.0 + 1
            for k in range(i, j + 1):
                r[order[k]] = avg
            i = j + 1
        return r
    return pearson(rank(xs), rank(ys))


# ------------------------------------------------------------- domain scans

def scan_capmono(d, g, man_row):
    """capmono_refusal domain frames on the BASELINE leg."""
    tl = os.path.join(d, 'timelines', g + '.timeline.json')
    aj = os.path.join(d, 'analysis', g + '.analysis.json')
    game = rc.load_game(tl, aj)
    if game is None:
        return []
    out = []
    for e in cr.scan_game(game, g):
        if e['armed']:
            continue                      # baseline leg only
        out.append({'hero': rc.canon_hero(e['hero']),
                    'outcome': bool(e['retreat']), 't': e['t']})
    return out


def scan_roamstale(d, g, man_row, window='out'):
    """roam_conversion lane-kill opportunity episodes on the BASELINE leg."""
    tl = os.path.join(d, 'timelines', g + '.timeline.json')
    aj = os.path.join(d, 'analysis', g + '.analysis.json')
    game = rc.load_game(tl, aj)
    if game is None:
        return []
    lo, hi = ((0.0, rc.LANING_END) if window == 'in'
              else (rc.OUT_START, rc.OUT_END))
    out = []
    for e in rc.scan(game, lo, hi):
        if e['armed']:
            continue                      # baseline leg only
        # the hijack signature roamstale_null_channel reports: creep INSTEAD
        # of hero.  Used here only as the in-domain "behaviour rate" whose
        # per-hero spread is the second half of #101's mechanism.
        out.append({'hero': rc.canon_hero(e['actor']),
                    'outcome': bool(e['hit_creep'] and not e['hit_hero']),
                    't': e['t']})
    return out


def scan_lf_rescue(d, g, man_row, domain='opps'):
    """tp_attribution on the BASELINE leg.

    Two domains, because they answer different questions and only one of them
    has an n worth correlating:

      `casts` -- gate-passing `item_tpscroll` casts.  This is the signature
                 #96 counted, but on a BASELINE leg it is a handful of events
                 per 16 games; a per-hero correlation on it is a coin flip.
      `opps`  -- pass B's opportunity frames: an ally below 35% HP with a
                 gate-passing potential responder.  This is the DOMAIN the
                 rescue rule is defined over -- who WALKS INTO it is exactly
                 #101's question -- and it is two orders of magnitude denser.
                 Frames are collapsed to (responder, ally, 10s bucket)
                 episodes, the same key `tp_attribution.py`'s own __main__
                 prints, so this is not a new definition.
    """
    tl = os.path.join(d, 'timelines', g + '.timeline.json')
    aj = os.path.join(d, 'analysis', g + '.analysis.json')
    base_side = OTHER[man_row['side']]
    hits, opps = TA.scan(tl, aj, base_side)
    out = []
    if domain == 'casts':
        for h in hits:
            att = ('land_xy' in h and 'pred_xy' in h
                   and math.hypot(h['land_xy'][0] - h['pred_xy'][0],
                                  h['land_xy'][1] - h['pred_xy'][1]) <= 1000.0)
            out.append({'hero': rc.canon_hero(h['responder']),
                        'outcome': bool(att), 't': h['t']})
        return out
    # `opps`: dedup to episodes first, then the outcome is "did this responder
    # actually cast a TP inside the episode" -- the in-domain behaviour rate.
    cast_t = collections.defaultdict(list)
    for h in hits:
        cast_t[rc.canon_hero(h['responder'])].append(h['t'])
    seen = {}
    for o in opps:
        key = (o['responder'], o['ally'], int(o['t'] // 10))
        if key in seen:
            continue
        seen[key] = True
        R = rc.canon_hero(o['responder'])
        acted = any(o['t'] - 2.0 <= ct <= o['t'] + 10.0 for ct in cast_t[R])
        out.append({'hero': R, 'outcome': bool(acted), 't': o['t']})
    return out


SCANNERS = {'capmono': scan_capmono,
            'roamstale': scan_roamstale,
            'lf_rescue': scan_lf_rescue}


def collect(corpus, dirs_a, dirs_b, man, window=None, domain=None):
    recs = []
    for arm, dirs in (('A', dirs_a), ('B', dirs_b)):
        for d in dirs:
            for row in man[d]:
                g = row['game']
                tl = os.path.join(d, 'timelines', g + '.timeline.json')
                if not os.path.exists(tl):
                    sys.exit('[fatal] missing timeline for %s under %s' % (g, d))
                if corpus == 'roamstale':
                    ev = scan_roamstale(d, g, row, window=window or 'out')
                elif corpus == 'lf_rescue':
                    ev = scan_lf_rescue(d, g, row, domain=domain or 'opps')
                else:
                    ev = SCANNERS[corpus](d, g, row)
                for e in ev:
                    e.update(arm=arm, seed=str(row['seed']), game=g,
                             run=os.path.basename(d.rstrip('/')))
                recs.append((arm, str(row['seed']), g, ev))
                print('[scan] %s %-28s seed%s base-leg n=%d'
                      % (arm, g, row['seed'], len(ev)), file=sys.stderr)
    return recs


# ------------------------------------------------------------------ reports

def occupancy(recs):
    """arm -> {hero: frames}, and arm -> games."""
    occ = {'A': collections.Counter(), 'B': collections.Counter()}
    games = {'A': 0, 'B': 0}
    for arm, seed, g, ev in recs:
        games[arm] += 1
        for e in ev:
            occ[arm][e['hero']] += 1
    return occ, games


def report_occupancy(occ, games, label):
    heroes = sorted(set(occ['A']) | set(occ['B']))
    xs = [occ['A'][h] for h in heroes]
    ys = [occ['B'][h] for h in heroes]
    r = pearson(xs, ys)
    rho = spearman(xs, ys)
    print('\n=== %s: per-hero domain occupancy, the two BASELINE legs ===' % label)
    print('    (both legs are stock code, gates all off; same seeds, same tree)')
    print('    %-18s %8s %8s' % ('hero', 'A-base', 'B-base'))
    for h in sorted(heroes, key=lambda h: -(occ['A'][h] + occ['B'][h])):
        print('    %-18s %8d %8d' % (pretty(h), occ['A'][h], occ['B'][h]))
    print('    %-18s %8d %8d   (%d games / %d games)'
          % ('POOLED', sum(xs), sum(ys), games['A'], games['B']))
    print('    heroes in domain (either leg) : %d' % len(heroes))
    print('    Pearson  r = %s' % ('%+.2f' % r if r is not None else 'n/a'))
    print('    Spearman rho = %s' % ('%+.2f' % rho if rho is not None else 'n/a'))
    return r, rho, sum(xs), sum(ys), len(heroes)


def report_jaccard(recs, label):
    by = collections.defaultdict(lambda: {'A': set(), 'B': set()})
    for arm, seed, g, ev in recs:
        for e in ev:
            by[seed][arm].add(e['hero'])
    print('\n--- %s: per-seed hero-set overlap in the domain ---' % label)
    print('    %-8s %6s %6s %8s %8s' % ('seed', 'nA', 'nB', 'shared', 'Jaccard'))
    out = {}
    for seed in sorted(by):
        a, b = by[seed]['A'], by[seed]['B']
        u = a | b
        j = (len(a & b) / len(u)) if u else None
        out[seed] = j
        print('    %-8s %6d %6d %8d %8s'
              % (seed, len(a), len(b), len(a & b),
                 ('%.2f' % j) if j is not None else 'n/a'))
    return out


def report_rate_spread(recs, label):
    """The second half of #101's mechanism: does the in-domain rate depend on
    WHICH hero?  Pooled over both baseline legs (this is a property of the
    behaviour, not of an arm)."""
    num = collections.Counter()
    den = collections.Counter()
    for arm, seed, g, ev in recs:
        for e in ev:
            den[e['hero']] += 1
            num[e['hero']] += 1 if e['outcome'] else 0
    rows = [(h, num[h], den[h]) for h in den if den[h] >= MIN_RATE_N]
    print('\n--- %s: in-domain behaviour rate by hero (pooled both baseline '
          'legs, n >= %d) ---' % (label, MIN_RATE_N))
    if not rows:
        print('    no hero reaches n >= %d -- spread not measurable here' % MIN_RATE_N)
        return None
    rows.sort(key=lambda r: r[1] / r[2])
    for h, k, n in rows:
        print('    %-18s %6.1f%%  (%d/%d)' % (pretty(h), 100.0 * k / n, k, n))
    spread = 100.0 * (rows[-1][1] / rows[-1][2] - rows[0][1] / rows[0][2])
    print('    spread (max-min over %d heroes with n >= %d) : %.1fpp'
          % (len(rows), MIN_RATE_N, spread))
    return spread


def report_composition_null(recs, label):
    """How much of the observed NULL does the composition difference explain?

    #101's mechanism has TWO ingredients: the legs hold different heroes
    (occupancy), and the in-domain rate depends on which hero.  Neither alone
    generates a NULL -- the risk quantity is the PRODUCT.  A standardisation
    identity makes that exact:

        NULL_obs  = rate_A - rate_B                       (what the leg reads)
        NULL_comp = SUM_h ( s_A(h) - s_B(h) ) * rbar(h)   (composition alone)

    where s_X(h) is hero h's share of leg X's domain occupancy and rbar(h) is
    h's rate POOLED over both legs.  NULL_comp is what the leg would read if
    every hero behaved identically on both legs and only the mix differed; the
    residual is the part composition does not explain.

    This is the number #101 section 4.1 was reaching for.  A high occupancy r
    does NOT by itself make a corpus safe: r and the per-hero rate spread are
    two separate factors and this corpus set shows them moving in OPPOSITE
    directions.  Report the product, not either factor.
    """
    occ = {'A': collections.Counter(), 'B': collections.Counter()}
    num = {'A': collections.Counter(), 'B': collections.Counter()}
    for arm, seed, g, ev in recs:
        for e in ev:
            occ[arm][e['hero']] += 1
            num[arm][e['hero']] += 1 if e['outcome'] else 0
    nA, nB = sum(occ['A'].values()), sum(occ['B'].values())
    if not nA or not nB:
        print('\n--- %s: composition-attributable NULL: one leg is empty ---' % label)
        return None
    heroes = sorted(set(occ['A']) | set(occ['B']))
    rate_a = 100.0 * sum(num['A'].values()) / nA
    rate_b = 100.0 * sum(num['B'].values()) / nB
    comp = 0.0
    for h in heroes:
        den = occ['A'][h] + occ['B'][h]
        if not den:
            continue
        rbar = 100.0 * (num['A'][h] + num['B'][h]) / den
        comp += (occ['A'][h] / nA - occ['B'][h] / nB) * rbar
    obs = rate_a - rate_b
    print('\n--- %s: composition-attributable NULL (the PRODUCT of #101\'s two '
          'ingredients) ---' % label)
    print('    baseline-leg rate      A %.1f%% (%d/%d)   B %.1f%% (%d/%d)'
          % (rate_a, sum(num['A'].values()), nA, rate_b, sum(num['B'].values()), nB))
    print('    NULL observed          %+.2fpp' % obs)
    print('    NULL from composition  %+.2fpp' % comp)
    print('    residual (behaviour)   %+.2fpp' % (obs - comp))
    if abs(obs) > 1e-9:
        print('    composition explains   %.0f%% of the observed NULL'
              % (100.0 * comp / obs))
    return obs, comp


def report_permutation(recs, label, iters=20000, seedval=20260822):
    """Is the observed per-hero occupancy DIFFERENCE bigger than relabelling
    games between the legs would give?  Games are permuted WITHIN seed, which
    respects the mirror pairing and the same-game frame clustering (#101 item 2:
    prefer a game-level permutation to a frame-level Fisher)."""
    rnd = random.Random(seedval)
    by_seed = collections.defaultdict(list)
    for arm, seed, g, ev in recs:
        by_seed[seed].append((arm, ev))

    def stat(assign):
        occ = {'A': collections.Counter(), 'B': collections.Counter()}
        for seed, items in assign.items():
            for arm, ev in items:
                for e in ev:
                    occ[arm][e['hero']] += 1
        heroes = sorted(set(occ['A']) | set(occ['B']))
        return pearson([occ['A'][h] for h in heroes], [occ['B'][h] for h in heroes])

    obs = stat(by_seed)
    if obs is None:
        return None, None
    hits, vals = 0, []
    for _ in range(iters):
        perm = {}
        for seed, items in by_seed.items():
            arms = [a for a, _ in items]
            rnd.shuffle(arms)
            perm[seed] = [(arms[i], items[i][1]) for i in range(len(items))]
        v = stat(perm)
        if v is None:
            continue
        vals.append(v)
        if v >= obs:
            hits += 1
    p = (hits + 1) / (len(vals) + 1) if vals else None
    mean = sum(vals) / len(vals) if vals else None
    sd = (math.sqrt(sum((v - mean) ** 2 for v in vals) / (len(vals) - 1))
          if vals and len(vals) > 1 else None)
    print('\n--- %s: game-level permutation of the leg label (within seed, '
          '%d draws) ---' % (label, iters))
    print('    observed Pearson r         : %+.3f' % obs)
    print('    permutation mean r         : %+.3f' % mean)
    print('    permutation SD             : %.3f' % sd)
    print('    one-sided p (r_perm >= obs): %.4f' % p)
    print('    reading: a permutation null that already sits near the observed r')
    print('    means the legs are exchangeable for occupancy at this n -- it does')
    print('    NOT rescue the DiD, it says the corpus cannot tell the two apart.')
    return obs, p


def run_selfcheck(corpus, r, jac, pooled):
    """Positive control: the generic path must re-derive #101's registered
    capmono readings, or every other corpus's reading from this file is
    unattributable to the corpus rather than to a broken probe."""
    if corpus != 'capmono':
        print('\n[selfcheck] SKIPPED: the registered control is the capmono '
              'corpus; --corpus %s has no registered prior.' % corpus)
        return
    bad = []
    if r is None or abs(r - CONTROL['r']) > 0.05:
        bad.append('Pearson r %s vs registered %+.2f' % (r, CONTROL['r']))
    for seed, want in CONTROL['jaccard'].items():
        got = jac.get(seed)
        if got is None or abs(got - want) > 0.03:
            bad.append('seed %s Jaccard %s vs registered %.2f' % (seed, got, want))
    if tuple(pooled) != CONTROL['pooled']:
        bad.append('pooled frames %s vs registered %s' % (tuple(pooled), CONTROL['pooled']))
    if bad:
        print('\n[selfcheck] FAILED -- refusing to certify this code path:')
        for b in bad:
            print('    ' + b)
        sys.exit(2)
    print('\n[selfcheck] PASSED: generic path reproduces #101 capmono control '
          '(r %+.2f, Jaccard %s, pooled %s).'
          % (r, CONTROL['jaccard'], CONTROL['pooled']))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--corpus', required=True, choices=CORPORA)
    ap.add_argument('--arm-a', nargs='+', required=True)
    ap.add_argument('--arm-b', nargs='+', required=True)
    ap.add_argument('--window', choices=('in', 'out'), default='out',
                    help='roamstale only: which roam_conversion window')
    ap.add_argument('--domain', choices=('opps', 'casts'), default='opps',
                    help='lf_rescue only: the rescue DOMAIN (opportunity '
                         'episodes, dense) or the gate-passing TP CASTS '
                         '(the #96 signature, sparse on a baseline leg)')
    ap.add_argument('--interval', default='UNKNOWN',
                    help='the -interval the sweep dumper ran at; echoed into '
                         'the header because frame-level counts are not '
                         'comparable across intervals')
    ap.add_argument('--permute', type=int, default=0,
                    help='game-level permutation draws (0 = skip)')
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()

    man, shared = arm_guard(a.arm_a, a.arm_b, a.corpus)   # exits before any number

    label = a.corpus + (':' + a.window if a.corpus == 'roamstale' else
                        ':' + a.domain if a.corpus == 'lf_rescue' else '')
    print('corpus            : %s' % a.corpus)
    print('arm guard         : A-B = {%s}, B-A = empty, %d shared ids'
          % (a.corpus, shared))
    print('dumper -interval  : %s' % a.interval)
    print('legs read         : BASELINE only (stock code on both arms)')

    recs = collect(a.corpus, a.arm_a, a.arm_b, man, window=a.window,
                   domain=a.domain)
    occ, games = occupancy(recs)
    r, rho, pa, pb, nh = report_occupancy(occ, games, label)
    jac = report_jaccard(recs, label)
    report_rate_spread(recs, label)
    report_composition_null(recs, label)
    if a.permute:
        report_permutation(recs, label, iters=a.permute)
    if a.selfcheck:
        run_selfcheck(a.corpus, r, jac, (pa, pb))


if __name__ == '__main__':
    main()
