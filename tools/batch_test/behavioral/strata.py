#!/usr/bin/env python3
"""Iron rule 4(i-e): a mirrored wave's two `arm_side` layers are ONE pair of
half-readings, not two independent readings.

WHY THIS FILE EXISTS (GH #835, director RULING 54, 2026-09-15)
--------------------------------------------------------------
Rule 4(i-b) says: two strata of opposite sign => noise, drop the reading.  That
is correct for a quantity with NO paired structure (GH #148's `med n_rc`).  It
was being applied to detector counts from mirrored waves, which DO have paired
structure, and the cost is measured: of the 14 detectors in the 09-11 wave, 12
were dropped as "opposed" and not one number survived.

The mirrored-dispatch path makes the pairing a property of HOW WAVES ARE SENT,
not of any one wave:

  * `soak/seed_draft.py:91`  -- `draft(seed, pool, pos_order)` has NO `side`
    parameter, so the draft is a function of the seed alone.
  * `soak/validate_onspot.sh:89-90` -- both legs of a pair are handed the SAME
    `$SEED`.
  * `soak/write_soak_side.sh` -- the two legs differ in exactly one field,
    `side`.

=> Within one run, hero -> PHYSICAL team is constant: radiant is always those
five heroes, dire always the other five.  So a within-stratum delta is always a
comparison between two DISJOINT hero rosters, and per-game rates give

    d_ab = f_R(armed) - f_D(base)
    d_ba = f_D(armed) - f_R(base)

    d_ab + d_ba = [f_R(armed) - f_R(base)] + [f_D(armed) - f_D(base)]
                = the arm effect, with the roster term cancelling TERM BY TERM
    d_ab - d_ba = [f_R(armed) + f_R(base)] - [f_D(armed) + f_D(base)]
                = the pure roster term

Therefore `opposed <=> |roster| > |arm|`, which is an IDENTITY, not a
diagnosis: it says the roster split this wave happened to draw was larger than
the effect, and it carries ZERO information about how precisely `arm` was
measured.  Precision is `arm`'s own dispersion across seeds -- rule 4(i-c).

WHAT THIS MODULE REFUSES TO DO
------------------------------
It does NOT downgrade the opposed test everywhere.  (i-b) keeps its own domain.
`pair_arm` is only reachable through `pairing()`, which demands the corpus
DEMONSTRATE per-seed pairing (every contributing seed carries both arm sides).
A corpus that cannot show that gets `paired=False` and the caller stays on
(i-b).  That precondition is the whole difference between making (i-e) a gate
and making it a blanket amnesty.

Rule 4(i-d) is enforced structurally: `per_seed_arm` averages the per-seed arms
ARITHMETICALLY and never by games, because games-weighted pooling leaks the
roster term back in as `arm + roster * (N_ab - N_ba)/(N_ab + N_ba)` -- the
0.335 coefficient that read +26.60 as +9.20.
"""

from __future__ import annotations

SIDES = ('radiant', 'dire')


def pair_arm(d_ab, d_ba):
    """Decompose a stratum pair into its arm and roster halves.

    `d_ab` is the within-stratum per-game delta for the layer where the ARMED
    leg sat on radiant; `d_ba` the one where it sat on dire.  Both must already
    be RATES (per game).  Handing this raw counts silently reintroduces the
    games-weighting that (i-d) exists to forbid, so callers divide first.
    """
    arm = (d_ab + d_ba) / 2.0
    roster = (d_ab - d_ba) / 2.0
    return {
        'd_ab': d_ab,
        'd_ba': d_ba,
        'arm': arm,
        'roster': roster,
        # Registered because (i-a) wants both layer readings on the record --
        # NOT because it decides anything.  See `opposed_is_identity`.
        'opposed': (d_ab > 0 > d_ba) or (d_ab < 0 < d_ba),
        'one_layer_flat': (d_ab == 0) != (d_ba == 0),
    }


def opposed_is_identity(p, tol=1e-12):
    """`opposed <=> |roster| > |arm|`.  True for every pair; it is algebra.

    Kept as a callable so the selftest can assert it on real numbers rather
    than have a comment assert it on the reader.
    """
    return p['opposed'] == (abs(p['roster']) > abs(p['arm']) + tol)


def pairing(records, ngames_by_seed):
    """Does this corpus DEMONSTRATE the per-seed pairing (i-e) rests on?

    `ngames_by_seed` maps `(seed, arm_side) -> game count`.  A seed is paired
    when it was dealt games on BOTH arm sides; the corpus is paired when at
    least one seed is and NO seed is unpaired.  An unpaired seed means some
    run's roster term has no partner to cancel against, so the sum is not the
    identity above and (i-b) is still the right rule.

    Returns `(paired, seeds, unpaired)` -- the two lists are reported, not
    just counted, because a caller that prints "not paired" owes the reader
    the seed that made it so.
    """
    paired_seeds, unpaired = [], []
    for seed in sorted({s for (s, _side) in ngames_by_seed},
                       key=lambda v: (v is None, v)):
        have = [side for side in SIDES if ngames_by_seed.get((seed, side), 0)]
        (paired_seeds if len(have) == len(SIDES) else unpaired).append(seed)
    # A `None` seed is not a seed: it is a run whose metadata never recorded
    # one, and it cannot be shown to have a partner.  It lands in `unpaired`
    # by the same test as any other, which is why it is not special-cased.
    return (bool(paired_seeds) and not unpaired), paired_seeds, unpaired


def per_seed_arm(records, ngames_by_seed, pred=lambda r: True):
    """The (i-d) estimator: per-seed swap-average first, THEN arithmetic mean.

    `records` are per-event dicts carrying `seed`, `arm_side` and `leg`.
    Returns None when the corpus is not paired -- there is no estimator to
    hand back, and returning a number anyway is exactly the failure this
    module was written against.
    """
    paired, seeds, unpaired = pairing(records, ngames_by_seed)
    if not paired:
        return None

    per_seed = []
    for seed in seeds:
        d = {}
        for side in SIDES:
            n_games = ngames_by_seed[(seed, side)]
            rate = {}
            for leg in ('armed', 'baseline'):
                n = sum(1 for r in records
                        if r.get('seed') == seed and r['arm_side'] == side
                        and r['leg'] == leg and pred(r))
                rate[leg] = n / float(n_games)
            d[side] = rate['armed'] - rate['baseline']
        p = pair_arm(d['radiant'], d['dire'])
        p['seed'] = seed
        per_seed.append(p)

    arms = [p['arm'] for p in per_seed]
    mean = sum(arms) / float(len(arms))
    return {
        'arm': mean,
        'per_seed': per_seed,
        'n_seeds': len(per_seed),
        # (i-c): what governs precision is arm's OWN spread across seeds.
        'spread': (max(arms) - min(arms)) if len(arms) > 1 else None,
        'seeds_better': sum(1 for a in arms if a > 0),
    }


def per_seed_share_arm(records, ngames_by_seed, pred_num, pred_den):
    """(i-d) for a SHARE observable, whose denominator is episodes, not games.

    `per_seed_arm` divides by games, which is right for a per-game count and
    wrong for a share: a verdict taken on shares must have its arm formed from
    the same quantity its strata deltas describe, or the number quoted as the
    reading is not a swap-average of the thing being read.

    Pairing is still decided by `ngames_by_seed` -- that is the DISPATCH fact
    (both legs of a run were handed one seed), and it is what licenses the
    cancellation.  A seed whose denominator is empty in either stratum is
    skipped: there is no share to difference, and inventing a 0.0 would be the
    absent-vs-flat confusion GH #257 already paid for.
    """
    paired, seeds, _unpaired = pairing(records, ngames_by_seed)
    if not paired:
        return None

    per_seed, skipped = [], []
    for seed in seeds:
        d, ok = {}, True
        for side in SIDES:
            rate = {}
            for leg in ('armed', 'baseline'):
                sub = [r for r in records if r.get('seed') == seed
                       and r['arm_side'] == side and r['leg'] == leg
                       and pred_den(r)]
                if not sub:
                    ok = False
                    break
                rate[leg] = sum(1 for r in sub if pred_num(r)) / float(len(sub))
            if not ok:
                break
            d[side] = rate['armed'] - rate['baseline']
        if not ok:
            skipped.append(seed)
            continue
        p = pair_arm(d['radiant'], d['dire'])
        p['seed'] = seed
        per_seed.append(p)

    if not per_seed:
        return None
    arms = [p['arm'] for p in per_seed]
    mean = sum(arms) / float(len(arms))
    return {
        'arm': mean,
        'per_seed': per_seed,
        'n_seeds': len(per_seed),
        'skipped': skipped,
        'spread': (max(arms) - min(arms)) if len(arms) > 1 else None,
        'seeds_better': sum(1 for a in arms if a > 0),
    }


def pooled_demo(d_ab, d_ba):
    """A pooled multi-seed pair: a DEMONSTRATION that a number exists.

    Not the estimator.  Pooling across seeds cancels the roster term only to
    first order, so this is what you print when per-seed denominators are not
    recoverable -- labelled, never quoted as the reading.
    """
    p = pair_arm(d_ab, d_ba)
    p['is_demo'] = True
    return p


def note_for(p, paired):
    """The one-line note that replaces `OPPOSED => NOISE`.

    When the corpus is NOT paired the old note is returned VERBATIM: (i-b)
    still governs quantities without paired structure, and this module is not
    a licence to stop refusing them.
    """
    if not paired:
        return 'OPPOSED => NOISE (rule 4i-b, corpus not seed-paired)' \
            if p['opposed'] else ('one layer flat (not a contradiction)'
                                  if p['one_layer_flat']
                                  else 'both layers agree')
    tail = ('opposed <=> |roster|>|arm| -- identity, NOT a veto (4i-e)'
            if p['opposed'] else 'layers agree')
    return 'arm=%+.3f roster=%+.3f  %s' % (p['arm'], p['roster'], tail)


# ---------------------------------------------------------------- selftest

def _selftest():
    fails = []
    ran = []

    def chk(label, cond):
        ran.append(label)
        print('  %-4s %s' % ('ok' if cond else 'FAIL', label))
        if not cond:
            fails.append(label)

    print('--- the identity (4i-e): opposed <=> |roster| > |arm|')
    for d_ab, d_ba in ((0.7, -0.9), (0.7, 0.9), (-0.045, -1.104),
                       (-1.104, -0.045), (0.0, 0.5), (26.6, 26.6),
                       (326.6, -273.4), (-0.21, 0.0)):
        chk('identity holds for (%+.3f, %+.3f)' % (d_ab, d_ba),
            opposed_is_identity(pair_arm(d_ab, d_ba)))

    print('--- GH #835 self-证: the hand-computed cross-layer read IS the arm')
    # skywrath_solo_silence, as the replay-check report hand-computed it:
    # 33/47 and -31/34, cross-layer 0.70 vs 0.91 = -0.21.
    p = pair_arm(33 / 47.0, -(31 / 34.0))
    chk('skywrath_solo_silence sum reproduces -0.210 digit for digit',
        abs((p['d_ab'] + p['d_ba']) - -0.210) < 0.0005)

    print('--- the discriminator pair: same two numbers, swapped')
    a = pair_arm(-0.045, -1.104)
    b = pair_arm(-1.104, -0.045)
    chk('enemy_overchase_unpunished and lowhp_limbo have EQUAL arms',
        abs(a['arm'] - b['arm']) < 1e-12)
    chk('...and roster terms of equal size, opposite sign',
        abs(a['roster'] + b['roster']) < 1e-12)
    chk('neither is opposed (both layers negative) -- the old rule kept both',
        a['opposed'] is False and b['opposed'] is False)
    # The pair the old rule actually split: flip one layer's sign and the
    # arm is unchanged in magnitude while `opposed` flips.
    c = pair_arm(-0.045, 1.104)
    chk('flipping ONE layer flips `opposed` without telling us anything '
        'about precision', c['opposed'] is True)

    print('--- (i-d): games-weighted pooling is NOT the estimator')
    # DELIBERATELY NON-DEGENERATE, and the first draft was not: seeds whose
    # TOTAL game counts are equal make games-weighting arithmetically
    # identical to the arithmetic mean, so the forbidden weighting survives
    # every assertion.  It did -- mutant M3 lived.  Two things must differ for
    # this corpus to have teeth: the per-seed arms AND the per-seed totals.
    #   seed A: 3+1 = 4 games, arm = (2.0 + -1.0)/2 = +0.5
    #   seed B: 1+1 = 2 games, arm = (3.0 +  1.0)/2 = +2.0
    #   arithmetic  = (0.5 + 2.0)/2            = +1.25   <- the estimator
    #   games-weighted = (0.5*4 + 2.0*2)/6     = +1.00   <- forbidden by (i-d)
    recs, ng = [], {}
    for seed, (r_arm, r_base, d_arm, d_base, g_r, g_d) in {
            'A': (6, 0, 0, 1, 3, 1),
            'B': (3, 0, 1, 0, 1, 1)}.items():
        ng[(seed, 'radiant')] = g_r
        ng[(seed, 'dire')] = g_d
        for side, (na, nb) in (('radiant', (r_arm, r_base)),
                               ('dire', (d_arm, d_base))):
            for _ in range(na):
                recs.append({'seed': seed, 'arm_side': side, 'leg': 'armed'})
            for _ in range(nb):
                recs.append({'seed': seed, 'arm_side': side,
                             'leg': 'baseline'})
    est = per_seed_arm(recs, ng)
    chk('per-seed estimator returns a reading on a paired corpus',
        est is not None and est['n_seeds'] == 2)
    hand = []
    for seed in ('A', 'B'):
        d = {}
        for side in SIDES:
            g = float(ng[(seed, side)])
            d[side] = (sum(1 for r in recs if r['seed'] == seed
                           and r['arm_side'] == side and r['leg'] == 'armed')
                       - sum(1 for r in recs if r['seed'] == seed
                             and r['arm_side'] == side
                             and r['leg'] == 'baseline')) / g
        hand.append((d['radiant'] + d['dire']) / 2.0)
    chk('estimator == arithmetic mean of hand-computed per-seed arms',
        abs(est['arm'] - sum(hand) / 2.0) < 1e-12)
    # The assertion that kills the mutant "average the per-seed arms, but
    # weight them by games".  Equality with the arithmetic mean does NOT
    # exclude it on its own -- on a corpus with equal per-seed totals the two
    # formulas coincide, which is how it survived the first stand.
    w = [ng[(s, 'radiant')] + ng[(s, 'dire')] for s in ('A', 'B')]
    games_weighted = sum(h * x for h, x in zip(hand, w)) / float(sum(w))
    chk('estimator is NOT the games-weighted mean of the same per-seed arms '
        '(%+.4f vs %+.4f)' % (est['arm'], games_weighted),
        abs(est['arm'] - games_weighted) > 1e-9)
    # The forbidden alternative, computed explicitly so the gap is a number.
    n_ab = sum(ng[(s, 'radiant')] for s in ('A', 'B'))
    n_ba = sum(ng[(s, 'dire')] for s in ('A', 'B'))
    pooled_rate = {}
    for side, tot in (('radiant', n_ab), ('dire', n_ba)):
        pooled_rate[side] = (
            sum(1 for r in recs if r['arm_side'] == side
                and r['leg'] == 'armed')
            - sum(1 for r in recs if r['arm_side'] == side
                  and r['leg'] == 'baseline')) / float(tot)
    weighted = pair_arm(pooled_rate['radiant'], pooled_rate['dire'])
    chk('games-weighted pool DISAGREES with the estimator (this is (i-d)\'s '
        'whole point: %+.4f vs %+.4f)' % (weighted['arm'], est['arm']),
        abs(weighted['arm'] - est['arm']) > 1e-9)

    print('--- the precondition: an UNPAIRED corpus keeps (i-b)')
    ng_bad = dict(ng)
    del ng_bad[('B', 'dire')]
    paired, seeds, unpaired = pairing(recs, ng_bad)
    chk('a seed dealt only one arm side makes the corpus unpaired',
        paired is False and unpaired == ['B'])
    chk('unpaired corpus yields NO estimator (not a downgraded one)',
        per_seed_arm(recs, ng_bad) is None)
    chk('unpaired + opposed still reads as 4(i-b) noise',
        note_for(pair_arm(0.7, -0.9), paired=False)
        == 'OPPOSED => NOISE (rule 4i-b, corpus not seed-paired)')
    chk('paired + opposed reads as the identity, not a veto',
        'NOT a veto' in note_for(pair_arm(0.7, -0.9), paired=True))
    chk('a seed with no recorded seed id cannot be shown paired',
        pairing([], {(None, 'radiant'): 3})[0] is False)

    print('--- per_seed_share_arm: same discipline, episode denominators')
    # ab: armed 1/1 vs baseline 0/1 = +1.0;  ba: armed 1/2 vs baseline 1/1
    # = -0.5.  arm = +0.25.  Per-GAME rates on this same corpus give a
    # DIFFERENT number, which is the whole reason the share variant exists.
    def sh(side, leg, w, seed='S1'):
        return {'seed': seed, 'arm_side': side, 'leg': leg, 'w': w}
    corpus = [sh('radiant', 'armed', True), sh('radiant', 'baseline', False),
              sh('dire', 'armed', True), sh('dire', 'armed', False),
              sh('dire', 'baseline', True)]
    ng1 = {('S1', 'radiant'): 1, ('S1', 'dire'): 1}
    e = per_seed_share_arm(corpus, ng1, lambda r: r['w'] is True,
                           lambda r: r['w'] is not None)
    chk('share arm is +0.25 on the worked corpus',
        e is not None and abs(e['arm'] - 0.25) < 1e-12)
    g = per_seed_arm(corpus, ng1, lambda r: r['w'] is True)
    chk('the per-GAME arm on the same corpus is a DIFFERENT number '
        '(%+.3f vs %+.3f) -- the observables are not interchangeable'
        % (g['arm'], e['arm']), abs(g['arm'] - e['arm']) > 1e-9)
    chk('an unpaired corpus yields no share estimator either',
        per_seed_share_arm(corpus, {('S1', 'radiant'): 1},
                           lambda r: r['w'] is True,
                           lambda r: r['w'] is not None) is None)
    # A seed with an empty denominator in one stratum is SKIPPED, not scored
    # as a flat 0.0 -- absence is not a measured zero (GH #257).
    two = corpus + [sh('radiant', 'armed', True, 'S2'),
                    sh('radiant', 'baseline', False, 'S2')]
    ng2 = dict(ng1)
    ng2[('S2', 'radiant')] = 1
    ng2[('S2', 'dire')] = 1
    e2 = per_seed_share_arm(two, ng2, lambda r: r['w'] is True,
                            lambda r: r['w'] is not None)
    chk('a seed with an empty stratum denominator is skipped, not zeroed',
        e2['n_seeds'] == 1 and e2['skipped'] == ['S2'])
    chk('...and the surviving seed still carries the reading',
        abs(e2['arm'] - 0.25) < 1e-12)

    print('--- pooled_demo labels itself')
    chk('pooled_demo carries is_demo so a reader cannot quote it as the arm',
        pooled_demo(0.5, -0.1)['is_demo'] is True)

    print('\n%d checks, %d failed' % (len(ran), len(fails)))
    return 1 if fails else 0


if __name__ == '__main__':
    import sys
    sys.exit(_selftest())
