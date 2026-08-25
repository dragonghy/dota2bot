#!/usr/bin/env python3
"""Frame-by-frame print of one hero around a towerfear decision instant.

The aggregate reader (`towerfear_domain.py`) only says WHERE to look; the
charter's hard rule is that the conclusion lands on frames.  This prints, one
game-second per line, everything the clause at
`bots/mode_retreat_generic.lua:906-914` reads:

    d_tower  distance to the nearest ALIVE enemy tower (the 898 u ring)
    ring     '*' when inside it -- `nEnemyTowers[1] ~= nil`
    lvl      botLevel            -- the `<= 10` cap and the `<= 5` leg
    hp       absolute health     -- the `< 800` leg of the gate context
    foe      distance to the nearest living enemy hero (the 1600 u leg)
    ctx      the gate context as a whole
    fear     which leg of `(botLevel <= 5 or DotaTime() < nFearClock)` holds,
             printed for BOTH the shipped clock (300 s) and the armed one
             (150 s), so the released frames are visible as `ship=Y armed=n`

Usage:
    towerfear_frames.py <timeline.json> --hero <substring> --t0 <s> --t1 <s>
                        [--side radiant|dire]
"""
import argparse
import json
import sys
from collections import defaultdict

sys.path.insert(0, __file__.rsplit('/', 1)[0])
from towerfear_domain import (Game, RING_U, CTX_U, CTX_HP, LEVEL_CAP,  # noqa
                              LEVEL_LEG, SHIPPED_CLOCK, ARMED_CLOCK, dist,
                              rect_of)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('timeline')
    ap.add_argument('--hero', required=True)
    ap.add_argument('--t0', type=float, required=True)
    ap.add_argument('--t1', type=float, required=True)
    ap.add_argument('--side', default='radiant',
                    help="the wave manifest's candidate-armed side")
    ap.add_argument('--ring', type=float, default=RING_U)
    a = ap.parse_args()

    g = Game(a.timeline, a.side)
    by_t = defaultdict(list)
    for s in g.snaps:
        by_t[s['t']].append(s)

    hero = None
    for h in g.teams:
        if a.hero in h:
            hero = h
            break
    if hero is None:
        sys.exit('no hero matching %r in %s' % (a.hero, sorted(g.teams)))
    print('%s  team=%d  leg=%s  (wave armed side: %s)'
          % (hero, g.teams[hero], g.leg(hero), a.side))
    hdr = ('%7s %5s %8s %4s %6s %7s %4s %8s %-9s %s' %
           ('t', 'lvl', 'd_tower', 'ring', 'hp', 'foe', 'ctx', 'rect',
            'fear', 'note'))
    print(hdr)
    print('-' * len(hdr))
    for t in sorted(by_t):
        if not (a.t0 <= t <= a.t1):
            continue
        me = [s for s in by_t[t] if s['hero'] == hero]
        if not me:
            continue
        s = me[0]
        if s.get('hp', 0) <= 0:
            print('%7.1f %5s %8s %4s %6s %7s %4s %8s %-9s %s'
                  % (t, s.get('level'), '-', '', 0, '-', '', '-', '-', 'DEAD'))
            continue
        dt = g.nearest_enemy_tower(t, s['team'], s['x'], s['y'])
        foe = None
        for o in by_t[t]:
            if o['team'] == s['team'] or o.get('hp', 0) <= 0:
                continue
            dd = dist(s['x'], s['y'], o['x'], o['y'])
            if foe is None or dd < foe:
                foe = dd
        ctx = (foe is not None and foe <= CTX_U) or s.get('hp', 0) < CTX_HP
        lvl = s.get('level', 0)
        ship = lvl <= LEVEL_LEG or t < SHIPPED_CLOCK
        armed = lvl <= LEVEL_LEG or t < ARMED_CLOCK
        inring = dt is not None and dt <= a.ring
        note = ''
        if lvl <= LEVEL_CAP and ctx and inring and t > 0:
            if ship and not armed:
                note = 'RELEASED: shipped forces retreat here, armed does not'
            elif ship and armed:
                note = 'both legs force retreat'
        print('%7.1f %5d %8.0f %4s %6.0f %7s %4s %8s %-9s %s'
              % (t, lvl, dt if dt is not None else -1, '*' if inring else '',
                 s.get('hp', 0), '%.0f' % foe if foe is not None else '-',
                 'Y' if ctx else 'n', rect_of(t, lvl) or '-',
                 'ship=%s armed=%s' % ('Y' if ship else 'n',
                                       'Y' if armed else 'n'),
                 note))
    return 0


if __name__ == '__main__':
    sys.exit(main())
