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

and, for the CALIBRATED clause directly below the lever (`:915-922`) -- the
one the source comment says catches whatever the lever releases -- four more
columns, so a released frame can be read as caught or not caught on its face:

    L9       `botLevel <= 9`                 (the block cap is 10: one narrower)
    aly      living non-illusion allies within 1600 u; the clause wants <= 1
    <700     inside a tower's 700 u attack range -- outside it,
             `GetAttackTarget() == bot` is arithmetically impossible
    shot     a tower `DAMAGE` event landed on this hero within +-1 s: the
             direct witness that the tower really was shooting HIM
    calib    'CAUGHT' when every observable leg holds, 'no:<leg>' otherwise

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
from towerfear_catch import (CALIB_LEVEL, ALLY_CAP, ALLY_R_U,  # noqa
                             TOWER_ATTACK_RANGE_U, SHOT_WINDOW_S, canon,
                             ally_counts, tower_shots)


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
    raw = json.load(open(a.timeline))
    allies = ally_counts(raw)
    shots = defaultdict(list)
    for h, t, _a in tower_shots(raw):
        shots[h].append(t)
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
    hdr = ('%7s %5s %8s %4s %6s %7s %4s %8s %-9s %3s %3s %4s %4s %-12s %s' %
           ('t', 'lvl', 'd_tower', 'ring', 'hp', 'foe', 'ctx', 'rect',
            'fear', 'L9', 'aly', '<700', 'shot', 'calib', 'note'))
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
            print('%7.1f %5s %8s %4s %6s %7s %4s %8s %-9s %3s %3s %4s %4s '
                  '%-12s %s'
                  % (t, s.get('level'), '-', '', 0, '-', '', '-', '-',
                     '', '', '', '', '', 'DEAD'))
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
        # the calibrated clause, leg by leg
        h = canon(hero)
        n_aly = allies.get((t, h))
        l9 = lvl <= CALIB_LEVEL
        alone = n_aly is not None and n_aly <= ALLY_CAP
        inrange = dt is not None and dt <= TOWER_ATTACK_RANGE_U
        shot = any(abs(x - t) <= SHOT_WINDOW_S for x in shots.get(h, ()))
        if not inring:
            calib = ''
        elif not l9:
            calib = 'no:lvl10'
        elif not alone:
            calib = 'no:aly=%s' % n_aly
        elif not inrange:
            calib = 'no:>700'
        elif not shot:
            calib = 'unwitnessed'
        else:
            calib = 'CAUGHT'
        print('%7.1f %5d %8.0f %4s %6.0f %7s %4s %8s %-9s %3s %3s %4s %4s '
              '%-12s %s'
              % (t, lvl, dt if dt is not None else -1, '*' if inring else '',
                 s.get('hp', 0), '%.0f' % foe if foe is not None else '-',
                 'Y' if ctx else 'n', rect_of(t, lvl) or '-',
                 'ship=%s armed=%s' % ('Y' if ship else 'n',
                                       'Y' if armed else 'n'),
                 'Y' if l9 else 'n',
                 '-' if n_aly is None else str(n_aly),
                 'Y' if inrange else 'n', 'Y' if shot else 'n',
                 calib, note))
    return 0


if __name__ == '__main__':
    sys.exit(main())
