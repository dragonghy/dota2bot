#!/usr/bin/env python3
"""Frame-by-frame printer for one hero around one instant (pullcamp review).

Prints, per 1 Hz snapshot: position, HP, distance to the nearest friendly camp,
distance to (and delta toward) our own fountain, how many NEUTRAL creeps are
within 700 u (the "did they follow" reading the drag signature rests on), how
many enemy heroes are inside the 1800 safety ring, and every combat event this
hero authored or received in that second -- so a human reads the decision the
way the charter's hard rule requires (逐帧 first, aggregate only to pick where
to look).

    pullcamp_frames.py <sweep_dir> <game> <hero-substring> <t0> <t1>

Read-only.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pullcamp_domain import (Game, canon, dist, load_sweep, derive_camps,   # noqa: E402
                             camp_team, R_FOLLOW, R_SAFE)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweep')
    ap.add_argument('game')
    ap.add_argument('hero')
    ap.add_argument('t0', type=float)
    ap.add_argument('t1', type=float)
    a = ap.parse_args()

    side = None
    for m in load_sweep(a.sweep):
        if m['game'] == a.game:
            side = m['side']
    if side is None:
        sys.exit('game %s not in this sweep' % a.game)
    g = Game(os.path.join(a.sweep, 'timelines', a.game + '.timeline.json'),
             os.path.join(a.sweep, 'analysis', a.game + '.analysis.json'), side)

    # camps from THIS game's own first spawn -- one game is enough to place
    # them (the corpus-wide derivation only exists to average out noise), and
    # keeping it local means the printer needs no second sweep dir.
    camps = derive_camps([(g, a.game, '')])
    hero = next(h for h in g.frames if a.hero in canon(h))
    team = g.teams[hero]
    fx, fy = g.fountain[team]
    mine = [(cx, cy) for cx, cy, _ in camps if camp_team(cx, cy, g.ancient) == team]

    print('game %s  armed side=%s  hero=%s (leg=%s, pos=%s, team=%d)'
          % (a.game, side, canon(hero), g.leg(hero), g.pos.get(hero), team))
    print('own fountain (%.0f, %.0f); %d friendly camps of %d derived'
          % (fx, fy, len(mine), len(camps)))
    print('%-7s %-15s %-5s %-8s %-9s %-7s %-6s %-4s %s'
          % ('t', 'pos', 'hp', 'd(camp)', 'd(fount)', 'dFount', 'neut', 'enm', 'events'))
    prev_df = None
    for t in sorted(x for x in g.frames[hero] if a.t0 <= x <= a.t1):
        s = g.frames[hero][t]
        df = dist(s['x'], s['y'], fx, fy)
        dc = min((dist(s['x'], s['y'], cx, cy) for cx, cy in mine), default=-1)
        nb = g.neutrals_at(t)
        nn = (sum(1 for c in nb if dist(s['x'], s['y'], c['x'], c['y']) <= R_FOLLOW)
              if nb is not None else -1)
        nenm = sum(1 for o in g.by_t.get(t, [])
                   if o['team'] != team and o['hp_pct'] > 0
                   and dist(s['x'], s['y'], o['x'], o['y']) <= R_SAFE)
        ev = []
        for e in g.raw_events:
            if not (t - 0.5 <= e['t'] < t + 0.5):
                continue
            act, tgt_ = canon(e.get('actor')), canon(e.get('target'))
            if canon(hero) not in (act, tgt_):
                continue
            ev.append('%s %s->%s%s' % (e['type'], act or '-', tgt_ or '-',
                                       (' [%s]' % e['inflictor'])
                                       if e.get('inflictor') else ''))
        print('%-7.1f (%6.0f,%6.0f) %-5.2f %-8.0f %-9.0f %-7s %-6s %-4d %s'
              % (t, s['x'], s['y'], s['hp_pct'], dc, df,
                 ('%+d' % (df - prev_df)) if prev_df is not None else '-',
                 nn if nn >= 0 else 'stale', nenm, '; '.join(ev[:4])))
        prev_df = df


if __name__ == '__main__':
    main()
