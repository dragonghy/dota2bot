#!/usr/bin/env python3
"""Frame-level print behind one `entity_key_audit --tpdefend` flip.

The audit says a column moved when the timeline is cleaned.  This says WHY, on
the frame: which hero's interpolated position moved, how far, and which
snapshot stream the shipped (name-keyed) read was actually interpolating
between.  Aggregate first, frame second -- the charter's hard rule is the other
way round, so this exists to make the second half cheap.

    entity_key_frames.py --root <sweep_dir> \
        --frame 20260825_211219_slot8:jakiro:956.6
"""
import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import entities                                            # noqa: E402
import tpdefend_events as tde                              # noqa: E402
from entity_key_audit import clean_timeline, streams_by_name  # noqa: E402


def show(tl, sweep, game, hero, t):
    raw = tde.Frames(tl)
    clean_tl, nrem = clean_timeline(tl)
    cln = tde.Frames(clean_tl)
    pos = tde.positions_for(sweep, game)
    team = raw.team.get(hero)
    print('=== %s  %s  t=%s   team=%s   cleaner removed %d samples'
          % (game, hero, t, team, nrem))

    st = streams_by_name(tl)
    print('\n-- snapshot streams under each name (idx: span, n, distinct xy)')
    for name in sorted(st):
        if len(st[name]) == 1:
            continue
        parts = []
        for idx, ss in sorted(st[name].items(), key=lambda kv: kv[1][0]['t']):
            parts.append('%s:[%.0f,%.0f]n=%d xy=%d'
                         % (idx, ss[0]['t'], ss[-1]['t'], len(ss),
                            len({(s['x'], s['y']) for s in ss})))
        print('   %-18s %s' % (name, '  '.join(parts)))

    print('\n-- interpolated position at t, shipped (name-keyed) vs cleaned')
    moved = []
    for h2 in sorted(raw.tracks):
        a, b = raw.at(h2, t), cln.at(h2, t)
        if a is None or b is None:
            print('   %-18s shipped=%s cleaned=%s' % (h2, a is not None,
                                                      b is not None))
            continue
        d = tde.dist(a['x'], a['y'], b['x'], b['y'])
        flag = ''
        if d > 1.0:
            moved.append((d, h2))
            flag = '  <== MOVED'
        print('   %-18s shipped=(%7.0f,%7.0f) hp=%.2f   cleaned=(%7.0f,%7.0f) '
              'hp=%.2f   d=%6.0f%s'
              % (h2, a['x'], a['y'], a['hp_pct'], b['x'], b['y'], b['hp_pct'],
                 d, flag))

    print('\n-- fronts_at() membership')
    for tag, fr in (('shipped', raw), ('cleaned', cln)):
        fs = tde.fronts_at(fr, hero, t, team) if team else []
        print('   %-8s %d front(s)' % (tag, len(fs)))
        for tx, ty, en, al in fs:
            print('      tower(%6.0f,%6.0f) enemies=%s allies=%s'
                  % (tx, ty, sorted(en), sorted(a2 for a2, _ in al)))
        print('   %-8s viable_support=%s' % (tag,
              tde.viable_support(fr, hero, t, team, pos) if team else None))

    if moved:
        d, h2 = max(moved)
        print('\n-- biggest mover: %s (%.0f u).  Its streams around t:' % (h2, d))
        for idx, ss in sorted(streams_by_name(tl)[h2].items()):
            near = [s for s in ss if abs(s['t'] - t) <= 3.0]
            if not near:
                continue
            print('   idx=%-6s %s' % (idx, ' '.join(
                '(t=%.1f x=%.0f y=%.0f hp=%.2f)'
                % (s['t'], s['x'], s['y'], s['hp_pct']) for s in near)))
        deaths = entities.death_times(tl).get(h2, [])
        print('   DEATH events near t: %s'
              % [round(x, 1) for x in deaths if abs(x - t) <= 30] or 'none')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', required=True)
    ap.add_argument('--frame', action='append', required=True,
                    help='game:hero:t')
    a = ap.parse_args()
    cache = {}
    for spec in a.frame:
        game, hero, t = spec.rsplit(':', 2)
        p = os.path.join(a.root, 'timelines', game + '.timeline.json')
        if p not in cache:
            cache.clear()
            cache[p] = json.load(open(p))
        show(cache[p], a.root, game, hero, float(t))
        print()


if __name__ == '__main__':
    main()
