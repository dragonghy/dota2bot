#!/usr/bin/env python3
"""Necessary-condition domain of hero_spirit_breaker.lua:302-309.

THE SITE (ungated, no soak-candidate id):

    local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nRadius, true)
    if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 3
    and nLocationAoE.count >= 3
    then
        if J.CanBeAttacked(nEnemyLaneCreeps[1])
        then
            return BOT_ACTION_DESIRE_HIGH, nNeutralCreeps[3]
        end
    end

The guard reads a LANE creep; the returned charge target is a NEUTRAL creep.
The enclosing `#nNeutralCreeps >= 3 or (>=2 and ancient)` test closed at :300,
so nothing on this path constrains #nNeutralCreeps -- `nNeutralCreeps[3]` is
nil whenever fewer than 3 neutrals are in nRadius.

WHAT THIS SCRIPT MEASURES, AND WHAT IT DOES NOT.  Three conjuncts of the
branch are engine-side and cannot be read offline: J.IsFarming(bot),
J.IsAttacking(bot) and nLocationAoE.count (FindAoELocation).  So the count
below is a NECESSARY condition only -- a strict SUPERSET of the real firing
set.  It answers "is this reachable at all", never "how often it fired".
A zero here would refute the defect; a large number does not prove it.

Read at several radii on purpose: bash_radius is an engine special value this
session cannot read, so the shape across radii is reported instead of one
number resting on a guessed constant.

Entity discipline (GH #176): streams keyed (hero, idx), only streams sampled
before the horn (t < 0) kept -- spirit_breaker carries illusion streams in
this corpus (3 streams in 182234_slot7).  Aliveness is read by BRACKETING
samples, never by interpolated hp_pct.
"""
import json, glob, os, sys, math, collections

SB = 'npc_dota_hero_spirit_breaker'
RADII = [250, 300, 400, 500, 600]


def real_stream(d, name):
    by = collections.defaultdict(list)
    for s in d['snapshots']:
        if s['hero'] == name:
            by[s['idx']].append(s)
    out = {}
    for k, fr in by.items():
        fr.sort(key=lambda s: s['t'])
        if fr[0]['t'] < 0:            # sampled before the horn => not an illusion
            out[k] = fr
    return out


def main(paths):
    grand = collections.Counter()
    per_game = []
    for p in sorted(paths):
        d = json.load(open(p))
        g = os.path.basename(p).split('.')[0]
        st = real_stream(d, SB)
        if len(st) != 1:
            print('%s: %d real SB streams -- skipped' % (g, len(st)))
            continue
        fr = list(st.values())[0]
        team = fr[0]['team']
        enemy_team = 3 if team == 2 else 2

        # creep samples bucketed by their own timestamp (3 s grid)
        creeps = collections.defaultdict(list)
        for c in d['creeps']:
            creeps[c['t']].append(c)

        # SB frames indexed by t for bracketing
        ft = {s['t']: s for s in fr}
        ts = sorted(ft)

        cnt = collections.Counter()
        first = {}
        for ct in sorted(creeps):
            # BRACKETING aliveness: need a sample at or before and at or after,
            # both with hp > 0.  No interpolation across a death.
            lo = [t for t in ts if t <= ct]
            hi = [t for t in ts if t >= ct]
            if not lo or not hi:
                continue
            a, b = ft[lo[-1]], ft[hi[0]]
            if a['hp_pct'] <= 0 or b['hp_pct'] <= 0:
                continue
            if b['t'] - a['t'] > 3.0:
                continue
            x, y = a['x'], a['y']
            for R in RADII:
                nl = nn = 0
                for c in creeps[ct]:
                    if math.hypot(c['x'] - x, c['y'] - y) > R:
                        continue
                    if c['team'] == enemy_team:
                        nl += 1
                    elif c['team'] == 4:
                        nn += 1
                if nl >= 3 and nn < 3:
                    cnt['R%d' % R] += 1
                    first.setdefault(R, (ct, nl, nn, x, y))
                if nl >= 3:
                    cnt['R%d_lane3' % R] += 1
        per_game.append((g, len(creeps), cnt, first))
        grand += cnt

    print('== hero_spirit_breaker.lua:309 nil-target necessary condition ==')
    print('   (#enemy lane creeps in R >= 3)  AND  (#neutrals in R < 3)')
    print()
    hdr = 'game            frames ' + ' '.join('%12s' % ('R=%d' % R) for R in RADII)
    print(hdr)
    for g, nf, cnt, _ in per_game:
        cells = []
        for R in RADII:
            a, b = cnt['R%d' % R], cnt['R%d_lane3' % R]
            cells.append('%12s' % ('%d/%d' % (a, b)))
        print('%-15s %6d %s' % (g[9:], nf, ' '.join(cells)))
    print()
    print('GRAND  ' + '  '.join('R=%d: %d/%d' % (R, grand['R%d' % R],
                                                 grand['R%d_lane3' % R]) for R in RADII))
    print('   (a/b = frames meeting the nil-target condition / frames with >=3 enemy lane creeps)')
    print()
    for g, nf, cnt, first in per_game:
        if 400 in first:
            ct, nl, nn, x, y = first[400]
            print('first R=400 instant  %s  t=%.1f  lane=%d neutrals=%d  SB=(%.0f,%.0f)'
                  % (g[9:], ct, nl, nn, x, y))


if __name__ == '__main__':
    main(sys.argv[1:] or glob.glob('timelines/*.json'))
