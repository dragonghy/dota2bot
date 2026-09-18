#!/usr/bin/env python3
"""Where can `PULL_CAMP_LANE_GAP` land?  Arithmetic over the REGISTERED camp-gap readings.

WHY THIS EXISTS
---------------
`pullcamp_camp_gap.py` answers "what are the camp-to-lane perpendicular gaps in
THIS corpus".  It has now been run on four corpora (W62, W63, W64-a, W64-b) and
every one of those readings is archived in a replay-check report.  RULING 13's
acceptance sentence (`iterations/owed_executions.json:pullcamp_atom_readmission`,
`done_when_note`) asks a question none of those single-corpus runs answers on its
own, verbatim: the re-read "必须说明上限落在哪、依据是哪几次连上", and
"一个没有被语料证成的常数落地不算结清".

That is a question about the UNION of the corpora, and it is arithmetic, not a
measurement.  Before this file it was retyped by hand every time (that is how
`1350` was proposed on W63 and then how §GS.8 overturned the prescription on
W64).  This file is that arithmetic, made repeatable: when a fifth corpus lands,
append a row and re-run.

IT MEASURES NOTHING.  Every number below is transcribed from a report line named
in `SOURCE`; `--selfcheck` re-derives each corpus's published totals from its own
per-camp table so a typo in transcription fails loudly instead of propagating.

THE TWO DIRECTIONS ARE NOT SYMMETRIC (this is the whole point)
-------------------------------------------------------------
The gap is the MINIMUM over the three lane polylines (`pullcamp_camp_gap.py`
LIMIT (a)).  Therefore:

  * REJECT direction is SOUND.  `min_gap > C` means every lane is farther than
    C, so `J.IsCampBesideLane` rejects that camp whichever lane the bot was
    assigned.  A rejection count computed this way is a LOWER bound.
  * KEEP direction is NOT SOUND.  `min_gap <= C` does not mean the bot's own
    lane is within C, so "this cap keeps that connect" is necessary, not
    sufficient.  For episodes that DID connect there is a physical argument
    (measured drag reach is 1120u on W62 / 1272u on W63, so the lane the pull
    actually reached cannot be much farther than the minimum) -- an argument,
    not the instrument.  Printed as such.

And the reconstruction itself is only good to ~20-82u at the decision line, for
which `pullcamp_camp_gap.py` carries `BLIND_BAND = 100`.  Both bounds below are
widened by that band; `--band 0` prints the naive point reading for comparison.

USAGE
    pullcamp_cap_window.py [--band 100] [--selfcheck]
"""
import argparse

BAND_DEFAULT = 100  # == pullcamp_camp_gap.BLIND_BAND, same justification.

# gap -> episode count, per corpus, exactly as the report tables print them.
# `connects` is the per-episode list of connecting camps' gaps (not a per-camp
# count): the same camp can appear twice because two episodes connected there.
CORPORA = [
    {
        'name': 'W62',
        'source': 'iterations/reports/replay-check/20260910T131238Z.md §4.1/§4.2',
        'armed_episodes': 39,
        # Only aggregates were published for W62 (median 1200, p90 2334, max
        # 2914, >1200 = 15/39).  The per-camp table was never written down, so
        # this corpus can contribute its connects and nothing else.  Leaving it
        # None is deliberate: inventing the table would make the union look
        # better measured than it is.
        'per_camp': None,
        'connects': [1268, 1268, 1200],
        'gt1200': 15,
    },
    {
        'name': 'W63',
        'source': 'iterations/reports/replay-check/20260910T160103Z.md §4',
        'armed_episodes': 28,
        'per_camp': {958: 2, 1069: 4, 1074: 2, 1196: 3, 1228: 1, 1266: 4,
                     1431: 1, 1452: 1, 1492: 1, 1753: 1, 2178: 2, 2340: 3,
                     2372: 2, 2912: 1},
        'connects': [1196],
        'gt1200': 17,
    },
    {
        'name': 'W64-a',
        'source': 'iterations/reports/replay-check/20260911T035254Z.md §2/§2.1',
        'armed_episodes': 19,
        'per_camp': {1076: 2, 1078: 3, 1204: 5, 1271: 4, 1491: 3, 2336: 1,
                     2907: 1},
        'connects': [1271, 1271],
        'gt1200': 14,
    },
    {
        'name': 'W64-b',
        'source': 'iterations/reports/replay-check/20260911T070109Z.md §2',
        'armed_episodes': 23,
        # The 07:01Z report published the distribution summary and named the
        # connecting gaps plus the six comfortably-above-the-constant camps; it
        # did not print the full per-camp table, so the low tier is unknown and
        # this corpus, like W62, contributes bounds only on the high side.
        'per_camp': None,
        'high_tier': [1495, 1495, 2174, 2174, 2370, 2918],
        'connects': [1199, 1199, 1270, 1270, 1270],
        'gt1200': 12,
    },
]

# Constants that have actually been proposed or shipped, so the table below
# answers "is MY number justified" without a reader re-deriving it.
CANDIDATES = [
    (992, 'the value GH #117 once wanted'),
    (1200, 'shipped: PULL_CAMP_LANE_GAP, and what `pulllane` would re-arm'),
    (1272, 'W63 measured drag reach (max)'),
    (1350, "W63's empty-band midpoint proposal"),
    (1500, '§GS.8: "没有证成任何一个 <=1500 的常数"'),
]


def all_connects():
    out = []
    for c in CORPORA:
        out.extend(c['connects'])
    return sorted(out)


def high_gaps(c):
    """Per-episode gaps this corpus published ABOVE its connects, or []."""
    if c['per_camp']:
        return sorted(g for g, n in c['per_camp'].items() for _ in range(n))
    return sorted(c.get('high_tier', []))


def nearest_nonconnect_above(mx):
    """Smallest published gap strictly above the largest connect, and its corpus."""
    best = None
    for c in CORPORA:
        for g in high_gaps(c):
            if g > mx and (best is None or g < best[0]):
                best = (g, c['name'])
    return best


def certainly_rejected(cap, band):
    """Episodes whose gap exceeds cap by more than the instrument band."""
    rows = []
    for c in CORPORA:
        gaps = high_gaps(c)
        if not gaps and c['per_camp'] is None and not c.get('high_tier'):
            rows.append((c['name'], None, c['armed_episodes']))
            continue
        n = sum(1 for g in gaps if g - band > cap)
        known = c['per_camp'] is not None
        rows.append((c['name'], n, c['armed_episodes'] if known else None))
    return rows


def report(band):
    conn = all_connects()
    mx, mn = max(conn), min(conn)
    floor = mx + band
    near = nearest_nonconnect_above(mx)

    print('registered corpora (nothing here was measured by this file):')
    for c in CORPORA:
        print('  %-6s n=%-3d connects=%-28s %s'
              % (c['name'], c['armed_episodes'],
                 ','.join(str(g) for g in c['connects']), c['source']))
    print()
    print('CONNECTS  n=%d  range [%d, %d]   %s' % (len(conn), mn, mx, conn))
    print('  every connect ever observed lies in a %du-wide band.' % (mx - mn))
    print()
    print('band = +-%du (pullcamp_camp_gap.BLIND_BAND; reconstruction is '
          '~20-82u wide at the decision line)' % band)
    print()
    print('FLOOR   a cap that can preserve every observed connect must be '
          '>= %d  (= %d + %d)' % (floor, mx, band))
    print('        [necessary, NOT sufficient: min-over-three-lanes cannot '
          'certify the KEEP direction]')
    if near:
        g, name = near
        print('CEILING nearest published non-connecting camp above the '
              'connects: %du (%s)' % (g, name))
        sep = g - band
        if sep > floor:
            print('        a cap in [%d, %d) separates them WITH the band.'
                  % (floor, sep))
        else:
            print('        separating it from the connects needs cap < %d, '
                  'while the floor is %d' % (sep, floor))
            print('        => EMPTY. The empty band (%d -> %d = %du) is '
                  'narrower than 2x the instrument error (%du).'
                  % (mx, g, g - mx, 2 * band))
            print('        => the binding constraint is the INSTRUMENT, not '
                  'the sample size: more corpus cannot close this.')
    print()
    print('At cap = %d (the largest-rejection cap that clears the floor):' % floor)
    print('  certainly rejected = published gap - %d > %d, i.e. gap > %d'
          % (band, floor, floor + band))
    for name, n, denom in certainly_rejected(floor, band):
        if n is None:
            print('    %-6s  not computable from the archive '
                  '(per-camp table was never published)' % name)
        elif denom is None:
            print('    %-6s  >= %d episode(s) (high tier only; denominator '
                  'not published)' % (name, n))
        else:
            print('    %-6s  %d/%d = %.1f%% of armed poke episodes'
                  % (name, n, denom, 100.0 * n / denom))
    print()
    # The ceiling above rests on whichever single episode sits lowest, and a
    # single episode is exactly the kind of thing an attribution slip produces
    # (the 1431 and 1452 camps carry one episode each and NEITHER has a
    # published frame).  So walk the ceiling outwards and show when the window
    # would open, instead of letting one unframed episode decide it silently.
    ladder = sorted(g for c in CORPORA for g in high_gaps(c) if g > mx)
    print('SENSITIVITY  if the lowest non-connecting camp(s) were dropped, the '
          'ceiling walks out:')
    seen = []
    for g in ladder:
        if g in seen:
            continue
        seen.append(g)
        width = (g - band) - floor
        print('    ceiling %-5d -> window [%d, %d)  %s'
              % (g, floor, g - band,
                 'width %du' % width if width > 0 else 'EMPTY'))
        if width > 0:
            break
    print()
    print('candidate constants, judged against the floor:')
    for c, why in CANDIDATES:
        lost = [g for g in conn if g > c]
        if c < floor:
            verdict = 'NOT justified (below floor %d)' % floor
        else:
            verdict = 'clears the floor'
        print('  %-5d %-52s %s' % (c, why, verdict))
        if lost:
            print('        point reading: rejects %d/%d observed connects %s'
                  % (len(lost), len(conn), lost))
        elif c < floor:
            print('        point reading: rejects 0/%d, but %d of them sit '
                  'inside the +-%du band of it'
                  % (len(conn), sum(1 for g in conn if abs(g - c) <= band), band))


def selfcheck():
    ok = True

    def check(name, cond, detail=''):
        nonlocal ok
        print('%s   %s%s' % ('ok  ' if cond else 'FAIL', name,
                             ('  ' + detail) if detail else ''))
        ok = ok and cond

    for c in CORPORA:
        if c['per_camp']:
            tot = sum(c['per_camp'].values())
            check('%s per-camp table sums to its published n' % c['name'],
                  tot == c['armed_episodes'],
                  '%d vs %d' % (tot, c['armed_episodes']))
            gt = sum(n for g, n in c['per_camp'].items() if g > 1200)
            check('%s per-camp table reproduces its published >1200 count'
                  % c['name'], gt == c['gt1200'],
                  '%d vs %d' % (gt, c['gt1200']))
            for g in c['connects']:
                check('%s connect gap %d is a camp in its own table'
                      % (c['name'], g), g in c['per_camp'])
        check('%s publishes at least one connect or one high-tier gap'
              % c['name'], bool(c['connects']) or bool(high_gaps(c)))

    conn = all_connects()
    check('union has 11 connects across 4 corpora', len(conn) == 11,
          str(len(conn)))
    check('max connect is W64-a/W64-b territory (1271)', max(conn) == 1271)
    near = nearest_nonconnect_above(max(conn))
    check('nearest non-connecting camp above the connects is W63 1431',
          near == (1431, 'W63'), str(near))
    check('the empty band is narrower than 2x the default instrument band',
          near[0] - max(conn) < 2 * BAND_DEFAULT,
          '%du < %du' % (near[0] - max(conn), 2 * BAND_DEFAULT))
    # The claim that survives the band, stated as an assertion so a future
    # transcription error cannot quietly soften it.
    floor = max(conn) + BAND_DEFAULT
    rej = {name: n for name, n, _ in certainly_rejected(floor, BAND_DEFAULT)}
    check('at the floor, W63 certainly rejects 10 episodes', rej['W63'] == 10,
          str(rej['W63']))
    check('at the floor, W64-a certainly rejects 5 episodes', rej['W64-a'] == 5,
          str(rej['W64-a']))
    check('at the floor, W64-b certainly rejects 6 episodes', rej['W64-b'] == 6,
          str(rej['W64-b']))
    check('1200 and 1350 are both below the floor', 1200 < floor and 1350 < floor)
    print()
    print('all checks passed' if ok else 'SELFCHECK FAILED')
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--band', type=int, default=BAND_DEFAULT)
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()
    if a.selfcheck:
        raise SystemExit(selfcheck())
    report(a.band)


if __name__ == '__main__':
    main()
