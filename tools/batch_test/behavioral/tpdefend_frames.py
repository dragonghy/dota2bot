#!/usr/bin/env python3
"""Frame-by-frame print of one tower-defense TP answer (charter: 先逐帧后聚合).

`tpdefend_events.py` aggregates; this reconstructs a single row second by
second so a human can read the decision instead of trusting the census.  Every
column it prints is one clause of `J.ShouldTpSupportTowerFight`, so a row that
the census called an answer can be checked clause by clause -- and, crucially,
the SUPPORT column shows who was standing free while the core answered, which
is the entire premise of `midsupyield`.

Usage:
  tpdefend_frames.py <sweep_dir> <game> <hero> --t <press_seconds> [--pre 8] [--post 8]

Read-only.  Costs nothing, launches nothing.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from tpdefend_events import (Frames, canon, dist, channels, positions_for,   # noqa: E402
                             fronts_at, landing, hero_damage_times,
                             FRONT_R_U, FAR_U, HEAT_HP, HEAT_S, MIN_LEVEL,
                             CORE_MAX_POS, REPEAT_U, RADIANT, DIRE)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweep')
    ap.add_argument('game')
    ap.add_argument('hero')
    ap.add_argument('--t', type=float, required=True)
    ap.add_argument('--pre', type=float, default=8.0)
    ap.add_argument('--post', type=float, default=8.0)
    a = ap.parse_args()

    tl = json.load(open(os.path.join(a.sweep, 'timelines',
                                     '%s.timeline.json' % a.game)))
    fr = Frames(tl)
    pos = positions_for(a.sweep, a.game) or {}
    dmg = hero_damage_times(tl)
    hero = canon(a.hero)
    team = fr.team[hero]
    foe = DIRE if team == RADIANT else RADIANT

    ch = [c for c in channels(tl) if c[0] == hero
          and abs(c[1] - a.t) < 1.0]
    print('game %s  hero %s (pos %s, team %s, leg-neutral print)'
          % (a.game, hero, pos.get(hero), team))
    if ch:
        h, t0, t1 = ch[0]
        land = landing(fr, hero, t0, t1)
        print('TP channel: press t=%.1f  end=%s  landing t=%s'
              % (t0, '%.1f' % t1 if t1 else 'NONE',
                 '%.1f' % land['t'] if land else 'NONE'))
    else:
        print('[warn] no TP channel within 1 s of t=%.1f' % a.t)
        t0 = a.t

    fs = fronts_at(fr, hero, t0, team)
    print('fronts at the press instant (own tower, >%du away, enemy+ally within %du):'
          % (FAR_U, FRONT_R_U))
    for tx, ty, en, al in fs:
        me = fr.at(hero, t0)
        print('   tower (%d,%d)  d(me)=%d  enemies=%s  allies=%s'
              % (tx, ty, dist(me['x'], me['y'], tx, ty), en, [x[0] for x in al]))
    if not fs:
        print('   (none)')

    print('\nper-second, %.1f..%.1f:' % (t0 - a.pre, t0 + a.post))
    print('  %6s %8s %6s %5s %6s   %s'
          % ('t', 'd_front', 'hp', 'lvl', 'tp_cd', 'front: enemies / allies(hp)'))
    tx, ty = (fs[0][0], fs[0][1]) if fs else (0, 0)
    t = t0 - a.pre
    while t <= t0 + a.post:
        me = fr.at(hero, t)
        if me is not None:
            en, al = [], []
            for h2 in fr.tracks:
                s = fr.at(h2, t)
                if s is None or s['hp_pct'] <= 0:
                    continue
                if dist(s['x'], s['y'], tx, ty) > FRONT_R_U:
                    continue
                if fr.team.get(h2) == foe:
                    en.append(h2)
                elif h2 != hero:
                    al.append('%s(%.2f%s)' % (h2, s['hp_pct'],
                                              '!' if any(t - HEAT_S <= td <= t
                                                         for td in dmg.get(h2, ()))
                                              else ''))
            print('  %6.1f %8d %6.2f %5d %6s   %s / %s'
                  % (t, dist(me['x'], me['y'], tx, ty), me['hp_pct'],
                     me['level'],
                     fr.tp_cd_at(hero, t), ','.join(en) or '-',
                     ','.join(al) or '-'))
        t += 1.0

    print('\nteam roster at the press instant (who could have gone instead):')
    print('  %-22s %4s %6s %6s %7s %8s  %s'
          % ('hero', 'pos', 'hp', 'lvl', 'tp_cd', 'd_front', 'nearest enemy'))
    for h2 in sorted(fr.tracks, key=lambda x: (pos.get(x) or 9)):
        if fr.team.get(h2) != team:
            continue
        s = fr.at(h2, t0)
        if s is None:
            continue
        ne = None
        for h3 in fr.tracks:
            if fr.team.get(h3) != foe:
                continue
            s3 = fr.at(h3, t0)
            if s3 is None or s3['hp_pct'] <= 0:
                continue
            d = dist(s['x'], s['y'], s3['x'], s3['y'])
            if ne is None or d < ne:
                ne = d
        p = pos.get(h2)
        tag = ''
        if h2 != hero and p and p > CORE_MAX_POS:
            free = (s['hp_pct'] > 0 and s['level'] >= MIN_LEVEL
                    and fr.tp_cd_at(h2, t0) == 0
                    and (ne is None or ne > REPEAT_U))
            tag = '  <-- VIABLE SUPPORT' if free else '  (support, not viable)'
        if h2 == hero:
            tag = '  <-- THE RESPONDER'
        print('  %-22s %4s %6.2f %6d %7s %8d  %s%s'
              % (h2, p, s['hp_pct'], s['level'], fr.tp_cd_at(h2, t0),
                 dist(s['x'], s['y'], tx, ty),
                 '%d' % ne if ne is not None else '-', tag))
    print('\n(heat gate: an ally at the front below %.2f HP or marked ! = hit by '
          'a hero within %.0f s)' % (HEAT_HP, HEAT_S))
    return 0


if __name__ == '__main__':
    sys.exit(main())
