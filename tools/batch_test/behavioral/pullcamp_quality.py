#!/usr/bin/env python3
"""Quality readings for the `pullcamp` pulls that pullcamp_domain.py found.

pullcamp_domain answers "did the action execute" ((a)-evidence).  This answers
"was the pull worth doing", which is a different question and must not be
folded into the same verdict:

  WHERE   -- how far from our own fountain the hero is standing when it pokes
             the camp.  A safelane pull happens BEHIND our lane; a pull at a
             far-jungle camp is a different (and much more dangerous) act, and
             `J.ShouldPullNeutralCamp` picks the camp NEAREST THE BOT with no
             clause about which half of the map that is.
  COST    -- HP lost to the camp within 15 s of the first poke, and deaths
             within 20 s (the "wave13" fingerprint: a puller that stands and
             TANKS the camp).  A death near a poke is NOT asserted to be caused
             by it -- the number is reported so a human can read the frames.
  CONNECT -- did the dragged neutrals reach a lane wave?  Reported under TWO
             estimators because they disagree and the disagreement is real:
               (i)  episode-level, as pullcamp_domain scores it: the neutrals
                    following at the drag frame, tracked forward by proximity;
               (ii) per-sample re-derivation of the following set.
             Both are LOWER bounds: neutral creeps carry no idx in the dump, so
             identity is proximity, and a contact after CONNECT_S is missed.
  LEASH   -- how far the following neutrals get from any camp at all.  This is
             the edge-condition control the charter requires before reporting a
             low CONNECT: if the neutrals never travel, the low connect rate is
             about the drag, not about the measurement.

Usage:
    pullcamp_quality.py <sweep_dir> [<sweep_dir> ...] [--rows FILE]

Reads the domain frames pullcamp_domain.py wrote (default /tmp/pullcamp_rows.jsonl)
so the two tools cannot drift apart on what counts as an episode.

Read-only; touches no billable AWS resource.
"""
import argparse
import json
import os
import statistics
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pullcamp_domain import (Game, canon, dist, load_sweep, derive_camps,   # noqa: E402
                             episodes, CONNECT_S, R_CONNECT, R_FOLLOW,
                             RADIANT, DIRE)

HP_WINDOW = 15.0
DEATH_WINDOW = 20.0


def pct(n, d):
    return '%d/%d (%.1f%%)' % (n, d, 100.0 * n / d) if d else '%d/0' % n


def q(xs):
    xs = sorted(xs)
    if not xs:
        return 'n/a'
    return ('median %.0f  p90 %.0f  max %.0f'
            % (statistics.median(xs), xs[int(0.9 * (len(xs) - 1))], xs[-1]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='+')
    ap.add_argument('--rows', default='/tmp/pullcamp_rows.jsonl')
    ap.add_argument('--leg', default='armed')
    a = ap.parse_args()

    # Key on (sweep_dir, game).  `.dem` basenames COLLIDE across runs of the
    # same wave -- measured here: 283 manifest lines, 282 unique names
    # (`20260822_122615_slot1` is run_121209/s888 AND run_121214/s895).  A
    # global basename -> run map silently hands one game the other's timeline;
    # the charter records this exact failure (2026-08-22T08:50Z (丙)).
    man = {}
    for d in a.sweeps:
        for m in load_sweep(d):
            man[(d, m['game'])] = m
    rows = [json.loads(l) for l in open(a.rows)]
    eps = [e for e in episodes([r for r in rows if r['leg'] == a.leg])
           if any(r['poke'] for r in e)]
    print('%s leg: %d poke episodes over %d games (%d unique basenames)'
          % (a.leg, len(eps), len(man), len({k[1] for k in man})))
    if not eps:
        return

    cache, camps_of = {}, {}

    def game(key):
        d, name = key
        if key not in cache:
            cache[key] = Game(
                os.path.join(d, 'timelines', name + '.timeline.json'),
                os.path.join(d, 'analysis', name + '.analysis.json'),
                man[key]['side'])
            camps_of[key] = derive_camps([(cache[key], name, '')])
        return cache[key]

    d_own, d_enm, drops, lows, leash, near_wave = [], [], [], [], [], []
    deaths = far = flipped = 0
    conn_i = conn_ii = n_drag = 0
    per_hero = defaultdict(lambda: defaultdict(int))

    for e in eps:
        key = (e[0].get('sweep', a.sweeps[0]), e[0]['game'])
        hero = e[0]['hero']
        g = game(key)
        team = g.teams[hero]
        fx, fy = g.fountain[team]
        ex, ey = g.fountain[DIRE if team == RADIANT else RADIANT]
        t0 = min(r['t'] for r in e if r['poke'])
        s0 = g.frames[hero][t0]
        do = dist(s0['x'], s0['y'], fx, fy)
        de = dist(s0['x'], s0['y'], ex, ey)
        d_own.append(do); d_enm.append(de)
        far += 1 if do > 9000 else 0
        flipped += 1 if de < do else 0
        per_hero[canon(hero)]['poke_eps'] += 1

        win = [g.frames[hero][t]['hp_pct'] for t in g.frames[hero]
               if t0 <= t <= t0 + HP_WINDOW and g.frames[hero][t]['hp_pct'] > 0]
        lo = min(win) if win else s0['hp_pct']
        drops.append(s0['hp_pct'] - lo); lows.append(lo)
        if any(t0 <= dt <= t0 + DEATH_WINDOW for dt in g.deaths.get(hero, ())):
            deaths += 1
            per_hero[canon(hero)]['deaths'] += 1

        if not any(r['drag'] for r in e):
            continue
        n_drag += 1
        per_hero[canon(hero)]['drag_eps'] += 1
        if any(r['connect_own'] or r['connect_enemy'] for r in e):
            conn_i += 1
        t1 = min(r['t'] for r in e if r['drag'])
        best, closest = 0.0, 1e9
        for t in [x for x in g.creep_t if t1 <= x <= t1 + CONNECT_S]:
            hs = [g.frames[hero][u] for u in g.frames[hero] if abs(u - t) < 1.0]
            if not hs:
                continue
            h = hs[0]
            foll = [c for c in g.neutrals.get(t, [])
                    if dist(h['x'], h['y'], c['x'], c['y']) <= R_FOLLOW]
            for c in foll:
                best = max(best, min((dist(c['x'], c['y'], cx, cy)
                                      for cx, cy, _ in camps_of[key]), default=0.0))
                for w in g.lane_creeps.get(t, []):
                    closest = min(closest, dist(c['x'], c['y'], w['x'], w['y']))
        leash.append(best)
        if closest < 1e9:
            near_wave.append(closest)
        if closest <= R_CONNECT:
            conn_ii += 1

    n = len(eps)
    print('\n--- WHERE the pull happens (at the first poke frame) ---')
    print('  distance to OUR fountain : %s' % q(d_own))
    print('  distance to ENEMY fountain: %s' % q(d_enm))
    print('  fountains are %.0f u apart in this corpus'
          % dist(*game((eps[0][0].get('sweep', a.sweeps[0]),
                        eps[0][0]['game'])).fountain[RADIANT],
                 *game((eps[0][0].get('sweep', a.sweeps[0]),
                        eps[0][0]['game'])).fountain[DIRE]))
    print('  poked >9000 u from our own fountain : %s' % pct(far, n))
    print('  closer to the ENEMY fountain than ours: %s' % pct(flipped, n))

    print('\n--- COST to the puller ---')
    print('  HP lost within %gs of the first poke : %s'
          % (HP_WINDOW, q([d * 100 for d in drops])))
    print('  lowest HP%% reached                  : %s' % q([x * 100 for x in lows]))
    print('  episodes dropping below 35%% HP      : %s'
          % pct(sum(1 for x in lows if x < 0.35), n))
    print('  DIED within %gs of a poke           : %s   '
          '(proximity, NOT an attribution)' % (DEATH_WINDOW, pct(deaths, n)))

    print('\n--- did the pull CONNECT to a wave? ---')
    print('  drag episodes                       : %d' % n_drag)
    print('  (i)  episode estimator (domain tool): %s' % pct(conn_i, n_drag))
    print('  (ii) per-sample re-derivation       : %s' % pct(conn_ii, n_drag))
    print('  closest a following neutral gets to any lane creep: %s'
          % q(near_wave))
    print('  EDGE CONTROL -- how far the following neutrals travel from any camp')
    print('    (if this is small the drag, not the estimator, is what failed)')
    print('    max distance from any camp        : %s' % q(leash))

    print('\n--- per hero (%s leg) ---' % a.leg)
    print('  %-18s %9s %9s %7s' % ('hero', 'poke_eps', 'drag_eps', 'deaths'))
    for h, v in sorted(per_hero.items(), key=lambda kv: -kv[1]['poke_eps']):
        print('  %-18s %9d %9d %7d' % (h, v['poke_eps'], v['drag_eps'], v['deaths']))


if __name__ == '__main__':
    main()
