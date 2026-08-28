#!/usr/bin/env python3
"""Which branch produced each charge onto a NEUTRAL creep?

Exactly two sites in hero_spirit_breaker.lua return a neutral creep as the
Charge of Darkness target:

  B  :297-299  `if J.CanBeAttackedPair(nNeutralCreeps[1], nNeutralCreeps[2])
                then return DESIRE_HIGH, nNeutralCreeps[2]`      <- 'aimguard'
       reached only when  #nNeutralCreeps >= 3  (AoE>=3)
                      or  #nNeutralCreeps >= 2 and [1] is ancient (AoE>=2)

  C  :303-309  `if #nEnemyLaneCreeps >= 3 ... J.CanBeAttacked(nEnemyLaneCreeps[1])
                then return DESIRE_HIGH, nNeutralCreeps[3]`      <- ungated
       produces a NON-nil target only when #nNeutralCreeps >= 3 as well

So a charge that actually landed on a neutral came from B or C, and C
additionally requires >= 3 enemy LANE creeps in the same radius at the same
instant.  Counting both creep kinds around the charge instant separates them:
lane < 3  =>  C is excluded, the cast is B's, i.e. the 'aimguard' site.

Positions are read at the last creep sample at or before the cast (the creep
stream is on a 3 s grid; SB is on a 1 s grid).  Entity discipline as in the
sibling scripts: (hero, idx) keys, pre-horn streams only (GH #176).
"""
import json, glob, os, sys, math, collections

SB = 'npc_dota_hero_spirit_breaker'
CHARGE = 'spirit_breaker_charge_of_darkness'
RADII = [250, 300, 400, 500, 600]


def real_stream(d, name):
    by = collections.defaultdict(list)
    for s in d['snapshots']:
        if s['hero'] == name:
            by[s['idx']].append(s)
    for k, fr in by.items():
        fr.sort(key=lambda s: s['t'])
        if fr[0]['t'] < 0:
            return fr
    return None


def before(seq, t, key=lambda s: s['t']):
    p = None
    for s in seq:
        if key(s) > t:
            break
        p = s
    return p


def main(paths):
    rows = []
    tot = collections.Counter()
    for p in sorted(paths):
        d = json.load(open(p))
        g = os.path.basename(p).split('.')[0]
        fr = real_stream(d, SB)
        if fr is None:
            continue
        team = fr[0]['team']
        enemy_team = 3 if team == 2 else 2
        creeps = collections.defaultdict(list)
        for c in d['creeps']:
            creeps[c['t']].append(c)
        cts = sorted(creeps)

        for e in d['events']:
            if e['type'] != 'ABILITY' or e.get('inflictor') != CHARGE:
                continue
            if not (e.get('target') or '').startswith('npc_dota_neutral'):
                continue
            t = e['t']
            s = before(fr, t)
            ct = before([{'t': x} for x in cts], t)
            if s is None or ct is None:
                continue
            ct = ct['t']
            x, y = s['x'], s['y']
            counts = {}
            for R in RADII:
                nl = nn = 0
                for c in creeps[ct]:
                    if math.hypot(c['x'] - x, c['y'] - y) <= R:
                        if c['team'] == enemy_team:
                            nl += 1
                        elif c['team'] == 4:
                            nn += 1
                counts[R] = (nl, nn)
            # C needs >=3 enemy lane creeps at the SAME radius.  Use the most
            # generous radius as the conservative test: if even R=600 shows
            # fewer than 3 lane creeps, C is excluded at every radius.
            excl = counts[600][0] < 3
            tot['B only (C excluded at every radius)' if excl
                else 'ambiguous (>=3 lane creeps at R=600)'] += 1
            rows.append((g[9:], t, e['target'].replace('npc_dota_neutral_', ''),
                         counts[250], counts[400], counts[600], excl))
    print('== charges onto NEUTRAL creeps: branch attribution ==')
    n = sum(tot.values())
    for k, v in tot.most_common():
        print('   %-42s %2d  (%.0f%%)' % (k, v, 100.0 * v / n if n else 0))
    print()
    print('   %-15s %8s  %-22s %-14s %-14s %-14s' %
          ('game', 't', 'target', 'lane/neu R250', 'R400', 'R600'))
    for r in rows:
        print('   %-15s %8.1f  %-22s %-14s %-14s %-14s %s' %
              (r[0], r[1], r[2], '%d/%d' % r[3], '%d/%d' % r[4], '%d/%d' % r[5],
               'B' if r[6] else '?'))


if __name__ == '__main__':
    main(sys.argv[1:] or glob.glob('timelines/*.json'))
