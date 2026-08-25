#!/usr/bin/env python3
"""Per-second reconstruction around one TP press, for `tpreach`'s condition (a).

Companion to `tpreach_domain.py`.  The aggregate says a press sat in the blind
band `[700, reach]`; this says what the frames actually looked like -- who the
band enemy was, how the distance moved second by second, whether the bot was
walking home (retreat, out of the candidate's scope) or out into the field, and
whether the press survived.

The columns exist because each one has been read wrong before:

  d(band)   the band enemy's distance AT EACH SAMPLED SECOND, not just at the
            interpolated press instant.  A press classified from a single
            interpolated instant is a press classified from a number that
            exists in no frame; the aggregate has to interpolate, a frame
            reconstruction must not pretend it did not.
  d(home)   distance to the bot's own fountain, before and after.  This is what
            separates a retreat TP (the branch that NEVER consults this
            predicate) from a travel/response TP (the branch that does).  It is
            reported as a series precisely because the destination proxy in the
            aggregate collapses it to one word.
  reach     the band enemy's estimated reach.  Printed per row so a row whose
            band membership depends on the reach TABLE rather than on the
            geometry is visible as such -- see --reach-mode in tpreach_domain.
"""
import argparse
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tpreach_domain import (canon, frames_by_hero, interp, measure_ranges,   # noqa: E402
                            reach_table, MELEE_RANGE_U, REACH_BUFFER_U,
                            NARROW_SCAN_U, WIDE_SCAN_U)
from tp_channel_death import fountains                                       # noqa: E402


def find_timeline(game, roots):
    for root in roots:
        for p in glob.glob(os.path.join(root, 'timelines',
                                        game + '.timeline.json')):
            return p
    for root in roots:
        for p in glob.glob(os.path.join(root, '*', 'timelines',
                                        game + '.timeline.json')):
            return p
    return None


def show(tl, hero, t0, reach, pre=6.0, post=8.0):
    fr, team = frames_by_hero(tl)
    h = canon(hero)
    if h not in fr:
        print('  hero %s not in this game (have: %s)'
              % (h, ', '.join(sorted(fr))))
        return
    fount = fountains(tl['snapshots']).get(team.get(h))
    default_reach = MELEE_RANGE_U + REACH_BUFFER_U

    # the band enemy at the press instant, named from the frames themselves
    band = []
    s0 = interp(fr[h], t0)
    for h2 in fr:
        if h2 == h or team.get(h2) == team.get(h):
            continue
        s2 = interp(fr[h2], t0)
        if s2 is None or s0 is None or s2['hp_pct'] <= 0:
            continue
        d = math.dist((s0['x'], s0['y']), (s2['x'], s2['y']))
        r = reach.get(h2, default_reach)
        if NARROW_SCAN_U < d <= min(r, WIDE_SCAN_U):
            band.append((h2, d, r))
    band.sort(key=lambda b: b[1])

    print('  band enemies at t=%.1f: %s' % (
        t0, ', '.join('%s d=%.0f reach=%.0f' % b for b in band) or 'NONE'))

    others = [h2 for h2 in fr if h2 != h and team.get(h2) != team.get(h)]
    watch = [b[0] for b in band] or others[:1]
    print('  %-7s %-6s %-5s %8s %9s  %s'
          % ('t', 'hp', 'lvl', 'd(home)', 'nearest', '  '.join(
              'd(%s)' % w for w in watch)))
    ts = sorted(s['t'] for s in fr[h] if t0 - pre <= s['t'] <= t0 + post)
    for t in ts:
        s = interp(fr[h], t)
        if s is None:
            continue
        nearest = None
        for h2 in others:
            s2 = interp(fr[h2], t)
            if s2 is None or s2['hp_pct'] <= 0:
                continue
            d = math.dist((s['x'], s['y']), (s2['x'], s2['y']))
            if nearest is None or d < nearest:
                nearest = d
        dh = math.dist((s['x'], s['y']), fount) if fount else float('nan')
        cols = []
        for w in watch:
            s2 = interp(fr[w], t)
            if s2 is None:
                cols.append('   --')
            elif s2['hp_pct'] <= 0:
                cols.append('  DEAD')
            else:
                cols.append('%6.0f' % math.dist((s['x'], s['y']),
                                                (s2['x'], s2['y'])))
        print('  %-7.1f %-6.2f %-5d %8.0f %9s  %s'
              % (t, s['hp_pct'], s['level'], dh,
                 '%.0f' % nearest if nearest is not None else '-',
                 '  '.join(cols)))

    # what the bot and the band enemy did in the window, from the event stream
    print('  events %.1f..%.1f:' % (t0 - pre, t0 + post))
    names = {h} | {b[0] for b in band}
    for e in tl['events']:
        if not (t0 - pre <= e['t'] <= t0 + post):
            continue
        a, tgt = canon(e.get('actor')), canon(e.get('target'))
        if a not in names and tgt not in names:
            continue
        if e['type'] in ('DEATH', 'ABILITY', 'ITEM'):
            print('    %-7.1f %-16s %s -> %s (%s)'
                  % (e['t'], e['type'], a or '-', tgt or '-',
                     e.get('inflictor')))
        elif e['type'] == 'MODIFIER_ADD' and 'teleport' in str(e.get('inflictor')):
            print('    %-7.1f %-16s %s (%s)'
                  % (e['t'], 'TP-PRESS', a, e.get('inflictor')))
        elif e['type'] == 'MODIFIER_REMOVE' and 'teleport' in str(e.get('inflictor')):
            print('    %-7.1f %-16s %s (%s)'
                  % (e['t'], 'TP-END', a, e.get('inflictor')))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', action='append', required=True,
                    help='sweep_run.sh output dir (repeatable)')
    ap.add_argument('--frame', action='append', required=True,
                    help='game:hero:t  e.g. 20260825_061900_slot11:spirit_breaker:574.8')
    ap.add_argument('--reach-mode', default='p50', choices=('p50', 'p90'))
    args = ap.parse_args()

    roots = []
    for r in args.root:
        roots.extend(sorted(glob.glob(r)))

    # the reach table is built from the SAME corpus the aggregate used, so a
    # frame and the table row that classified it can never disagree
    tls = []
    for root in roots:
        for p in sorted(glob.glob(os.path.join(root, 'timelines',
                                               '*.timeline.json')))[:40]:
            try:
                tls.append(json.load(open(p)))
            except (ValueError, OSError):
                pass
    import tpreach_domain
    tpreach_domain.RANGE_PCT = 50 if args.reach_mode == 'p50' else 90
    reach = reach_table(measure_ranges(tls))

    for spec in args.frame:
        game, hero, t = spec.split(':')
        p = find_timeline(game, roots)
        print('=' * 78)
        print('%s  %s  t=%s' % (game, hero, t))
        if p is None:
            print('  TIMELINE NOT FOUND under %s' % ', '.join(roots))
            continue
        tl = json.load(open(p))
        show(tl, hero, float(t), reach)
    return 0


if __name__ == '__main__':
    sys.exit(main())
