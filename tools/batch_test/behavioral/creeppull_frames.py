#!/usr/bin/env python3
"""Frame-by-frame printer for one hero around one instant (creeppull review).

Prints, per 1 Hz snapshot: position, HP, distance to the pull target, distance
to (and delta toward) our own fountain, the enemy lane creeps within 900, and
every combat event this hero authored or received in that second -- so a human
can read the decision the way the charter's hard rule requires (逐帧 first).

    creeppull_frames.py <sweep_dir> <game> <hero-substring> <t0> <t1> [--tgt X]
"""
import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creeppull_domain import Game, canon, dist, load_sweep, R_CREEP  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweep')
    ap.add_argument('game')
    ap.add_argument('hero')
    ap.add_argument('t0', type=float)
    ap.add_argument('t1', type=float)
    ap.add_argument('--tgt', default=None)
    a = ap.parse_args()

    side = None
    for m in load_sweep(a.sweep):
        if m['game'] == a.game:
            side = m['side']
    if side is None:
        sys.exit('game %s not in this sweep' % a.game)
    g = Game(os.path.join(a.sweep, 'timelines', a.game + '.timeline.json'),
             os.path.join(a.sweep, 'analysis', a.game + '.analysis.json'), side)

    hero = next(h for h in g.frames if a.hero in canon(h))
    team = g.teams[hero]
    fx, fy = g.fountain[team]
    tgt = next((h for h in g.frames if a.tgt and a.tgt in canon(h)), None)
    print('game %s  armed side=%s  hero=%s (leg=%s, pos=%s, team=%d)'
          % (a.game, side, canon(hero), g.leg(hero), g.pos.get(hero), team))
    print('own fountain (%.0f, %.0f); target=%s' % (fx, fy, canon(tgt) if tgt else '-'))
    print('%-7s %-14s %-5s %-7s %-8s %-7s %-6s %s'
          % ('t', 'pos', 'hp', 'd(tgt)', 'd(fount)', 'dFount', 'creep', 'events'))
    prev_df = None
    for t in sorted(x for x in g.frames[hero] if a.t0 <= x <= a.t1):
        s = g.frames[hero][t]
        df = dist(s['x'], s['y'], fx, fy)
        dtgt = ''
        if tgt:
            ts = g.frames[tgt].get(t)
            dtgt = '%d' % dist(s['x'], s['y'], ts['x'], ts['y']) if ts else '-'
        cs = g.creeps_at(t) or []
        nec = sum(1 for c in cs if c['team'] != team
                  and dist(s['x'], s['y'], c['x'], c['y']) <= R_CREEP)
        ev = []
        for e in g_events(g):
            if not (t <= e['t'] < t + 1):
                continue
            A, B = canon(e.get('actor')), canon(e.get('target'))
            hh = canon(hero)
            if e['type'] in ('DAMAGE', 'DEATH', 'ABILITY', 'ITEM') and (A == hh or B == hh):
                ev.append('%s %s%s%s%s' % (
                    e['type'][:3], '' if A == hh else A + '>',
                    '' if B == hh else B,
                    '(' + e['inflictor'] + ')' if e.get('inflictor') not in
                    (None, 'dota_unknown') else '',
                    '' if e['type'] not in ('DAMAGE',) else ' v=%d' % e['value']))
        print('%-7.1f (%6.0f,%6.0f) %-5.2f %-7s %-8.0f %-7s %-6d %s'
              % (t, s['x'], s['y'], s['hp_pct'], dtgt, df,
                 ('%+d' % (df - prev_df)) if prev_df is not None else '',
                 nec, '; '.join(ev[:6])))
        prev_df = df


_EV = {}


def g_events(g):
    """The raw event list is not kept on Game; rebuild once per process."""
    if id(g) not in _EV:
        _EV[id(g)] = sorted(g.raw_events, key=lambda e: e['t'])
    return _EV[id(g)]


if __name__ == '__main__':
    main()
