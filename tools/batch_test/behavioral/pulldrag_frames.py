#!/usr/bin/env python3
"""Frame-by-frame print of one puller around a `pulldrag` drag.

`pulldrag_walk.py` only says WHICH episodes to look at; the charter's hard rule
is that the conclusion lands on frames.  This prints, one game-second per line,
the quantities the call site at `bots/mode_roam_generic.lua:280-295` decides
between:

    d_camp   distance to the camp being poked
    d_home   distance to this team's fountain -- the SHIPPED destination
    d_lane   distance to the lane point -- the ARMED destination, under both
             corner models of the reconstructed lane (see pulldrag_walk.py);
             `d_lane2` is the corner-restored one
    step     this second's displacement, and its cosine against the two rays:
             `home` and `lane`.  A shipped drag step reads home~1; an armed
             one reads lane~1.  They are within 3 deg of perpendicular on
             every pull camp, so the two readings cannot both be high.
    foll     neutral creeps within 700 u -- did the camp actually follow
    hp       hp_pct
    poke     a DAMAGE event from this hero onto a non-hero within +-0.5 s

Entity identity is idx-locked exactly as pullcamp_domain does it (GH #176: an
illusion shares the hero's name and player_id, and interpolating across two
streams silently mixes them).

Usage:
    pulldrag_frames.py <timeline.json> --hero <name> --t0 <s> --t1 <s>
                       [--side radiant|dire] [--camp X,Y]

Read-only; touches no billable AWS resource.
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from pullcamp_domain import Game, canon, dist, RADIANT, DIRE   # noqa: E402
from pulldrag_walk import Lanes, unit                          # noqa: E402

R_FOLLOW = 700.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('timeline')
    ap.add_argument('--hero', required=True)
    ap.add_argument('--t0', type=float, required=True)
    ap.add_argument('--t1', type=float, required=True)
    ap.add_argument('--side', default='radiant',
                    choices=('radiant', 'dire'),
                    help='which physical side is the ARMED leg of this game')
    ap.add_argument('--camp', default=None, help='X,Y of the camp (default: '
                    'the nearest first-spawn neutral cluster to the hero at t0)')
    a = ap.parse_args()

    an = a.timeline.replace('.timeline.json', '.analysis.json')
    an = an if os.path.exists(an) else None
    g = Game(a.timeline, an, a.side)
    lanes = Lanes()

    hero = None
    for h in g.frames:
        if canon(h) == canon(a.hero):
            hero = h
    if hero is None:
        sys.exit('hero %r not in this game: %s'
                 % (a.hero, sorted(canon(h) for h in g.frames)))
    fr = g.frames[hero]
    team = g.teams[hero]
    fx, fy = g.fountain[team]

    if a.camp:
        cx, cy = [float(v) for v in a.camp.split(',')]
    else:
        # first-spawn neutrals, nearest cluster to where the hero is at t0
        near = [t for t in g.creep_t if 60.0 <= t <= 66.0]
        pts = [(c['x'], c['y']) for t in near for c in g.neutrals.get(t, [])]
        if not pts:
            sys.exit('no first-spawn neutrals in this timeline; pass --camp X,Y')
        s0 = min(fr, key=lambda t: abs(t - a.t0))
        cx, cy = min(pts, key=lambda p: dist(fr[s0]['x'], fr[s0]['y'], *p))

    ca, cb, moved = lanes.both_targets((cx, cy))
    print('# %s  hero=%s (team %d, leg=%s)  camp=(%.0f,%.0f)  lane=%s gap=%.0f'
          % (os.path.basename(a.timeline), canon(hero), team, g.leg(hero),
             cx, cy, ca[2], ca[1]))
    print('# home=(%.0f,%.0f)  lane_pt=(%.0f,%.0f)  lane_pt2=(%.0f,%.0f)  '
          'corner_shift=%.0f u' % (fx, fy, ca[0][0], ca[0][1],
                                   cb[0][0], cb[0][1], moved))
    print('# %-6s %6s %6s %7s %7s %7s %7s %6s %6s %6s %5s %5s %s'
          % ('t', 'x', 'y', 'd_camp', 'd_home', 'd_lane', 'd_lane2',
             'step', 'cos_h', 'cos_l', 'foll', 'hp', 'poke'))

    pokes = g.dmg_creep.get(hero, ())
    prev = None
    for t in sorted(fr):
        if not (a.t0 <= t <= a.t1):
            continue
        s = fr[t]
        step = cosh = cosl = None
        if prev is not None:
            mx, my = s['x'] - prev['x'], s['y'] - prev['y']
            n = math.hypot(mx, my)
            if n > 1.0:
                uh = unit(fx - prev['x'], fy - prev['y'])
                ul = unit(ca[0][0] - prev['x'], ca[0][1] - prev['y'])
                step = n
                cosh = (mx * uh[0] + my * uh[1]) / n
                cosl = (mx * ul[0] + my * ul[1]) / n
        nb = g.neutrals_at(t) or []
        foll = sum(1 for c in nb
                   if dist(s['x'], s['y'], c['x'], c['y']) <= R_FOLLOW)
        poked = any(abs(et - t) <= 0.5 for et in pokes)
        print('  %-6.1f %6d %6d %7d %7d %7d %7d %6s %6s %6s %5d %5.2f %s'
              % (t, s['x'], s['y'], dist(s['x'], s['y'], cx, cy),
                 dist(s['x'], s['y'], fx, fy),
                 dist(s['x'], s['y'], *ca[0]), dist(s['x'], s['y'], *cb[0]),
                 '%.0f' % step if step else '-',
                 '%+.2f' % cosh if cosh is not None else '-',
                 '%+.2f' % cosl if cosl is not None else '-',
                 foll, s['hp_pct'], 'POKE' if poked else ''))
        prev = s


if __name__ == '__main__':
    main()
