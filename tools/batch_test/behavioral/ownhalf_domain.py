#!/usr/bin/env python3
"""Condition-(a) instrument for the `ownhalf` soak candidate (replay-check).

WHAT `ownhalf` IS
-----------------
`J.ShouldPunishDive` is PROMOTED (turbo default-on).  Its SHIPPED domain is
"an enemy hero within the collapse ring of me AND within 1200u of one of my
standing buildings".  The `ownhalf` candidate adds a SECOND admission door to
the same loop: an enemy with no building of ours nearby still counts as
in-domain when it is far enough onto our ground, measured as

    nInvadeDepth = dist(enemy, THEIR ancient) - dist(enemy, OUR ancient)

and compared against a margin (1600 since 2026-09-09; read from the source
below, never copied).  Both doors then hand the target to the SAME commit test
(`J.SafeToCommitFight` + `J.ShouldRefuseUnsupportedPunish`).

WHY THIS FILE EXISTS
--------------------
`ownhalf` has been in the armed set for weeks with `episodes=0`: three
replay-check rounds registered `VERIFY id=ownhalf verdict=INDETERMINATE
episodes=0`.  The 2026-09-10T00:5xZ round closed the cheapest of the open
questions -- the domain is NOT empty (28,912 armed-door pair-frames vs 3,055
shipped-door on W62 run 364764, i.e. 9.46x wider) -- and priced the nearest
GENERAL detector (`enemy_overchase_unpunished`), which does not resolve this
id: arm per seed +0.417 / -0.019 / +0.000 / -0.058, comps_better 2/4.  The
charter handoff for this round is therefore "now write the dedicated one, and
make it episode-shaped, not pair-frame-shaped".

WHAT THIS MEASURES, AND WHAT IT CANNOT
--------------------------------------
It measures the two admission doors exactly (geometry is fully in the dump)
and then reads the OBSERVABLE CONSEQUENCE of admission -- did the bot close on
that enemy in the seconds that follow.

It does NOT evaluate `J.SafeToCommitFight` or `J.ShouldRefuseUnsupportedPunish`
(both read visible-body counts and lethality estimates that the dump does not
carry), so a door count is an UPPER BOUND on fires and is labelled as one
everywhere it is printed.

The design answer to that limit is not a better estimator of the commit test;
it is a NEGATIVE CONTROL that shares the limit.  Two of them:

  * THE BASELINE LEG.  In a mirrored game the other side runs the same tree
    with `ownhalf` un-armed, so its own-half door is CLOSED.  Every own-half
    episode still EXISTS there as geometry, and any closing behaviour on it is
    what the rest of the bot does anyway.  armed-leg rate minus baseline-leg
    rate on the own-half band is the lever's behavioural signature.
  * THE SHIPPED BAND.  The building door is bit-identical on both legs, so the
    armed-vs-baseline difference measured on IT is this instrument's own noise
    floor, computed from the same corpus with the same statistic.

A signature that does not clear its own shipped-band floor is not a reading.

STRATA (iron rule 4(i-a)/(i-b))
-------------------------------
Every rate is printed for the `ab` stratum (armed side = radiant) and the `ba`
stratum (armed side = dire) separately, never only pooled.  Detector counts
are NOT side-de-biased, so a two-stratum sign flip is noise and must not enter
a conclusion.

USAGE
    ownhalf_domain.py --sweep <sweep_out_dir> [--max-games N]
    ownhalf_domain.py <timeline.json> --side radiant|dire

Read-only; no AWS, no network.
"""
from __future__ import annotations

import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from entities import canon, frames_by_hero  # noqa: E402
from source_constants import call_arg, literal  # noqa: E402

RADIANT, DIRE = 2, 3

# --- thresholds READ OUT OF the shipped Lua (GH #90 contract) ---------------
# Copying these would make the file correct today and silently wrong the day
# the margin moves -- which it did move, on 2026-09-09 (800 -> 1600).
COLLAPSE_RING = call_arg('J.ShouldPunishDive', 'J.GetNearbyHeroes',
                         index=1, where={2: 'true'})
BUILDING_RING = literal('J.ShouldPunishDive',
                        r'GetUnitToUnitDistance\(\s*enemy,\s*building\s*\)'
                        r'\s*<=\s*(?P<n>\d+)')
DEPTH_MARGIN = literal('J.ShouldPunishDive',
                       r'nInvadeDepth\s*>=\s*(?P<n>\d+)')

# --- episode + consequence shape -------------------------------------------
# Snapshots are 1 s apart, buildings 5 s apart.  Two consecutive admitted
# frames of the same (bot, enemy) pair are one episode; a gap wider than this
# starts a new one, so a pair that drifts out and back is two decisions.
EPISODE_GAP = 2.5
# How long after admission we look for the consequence.  The collapse is a
# move order, not an instant: the desire remap feeds team_roam, which walks.
CONSEQUENCE_WIN = 4.0
# "Closed on it": the bot cut this much distance off its own start distance.
CLOSE_DELTA = 250.0
# "Engaged it": the bot actually arrived in fighting range.
ENGAGE_RANGE = 600.0
# THE DISCONTINUITY CONTROL.  Pairs whose invade depth lands in
# [margin - NEARMISS_WIDTH, margin) are geometrically almost identical to the
# admitted ones -- same map region, same kind of enemy, same bot -- and the
# branch admits NEITHER LEG on them.  So the armed-vs-baseline difference
# measured on this band is the leg confound WITH the lever held out, at the
# exact constant the lever turns on.  Width is one screen of depth (half a
# screen of real ground: a depth is a difference, GH #687).
NEARMISS_WIDTH = 800.0


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


class Game(object):
    """One mirrored game: geometry, legs, and the two admission doors."""

    def __init__(self, tl_path, armed_side, name=None):
        with open(tl_path) as fh:
            d = json.load(fh)
        self.name = name or os.path.basename(tl_path)
        self.armed_team = RADIANT if armed_side == 'radiant' else DIRE
        self.side = armed_side
        frames, teams = frames_by_hero(d)
        self.teams = {h: teams[h] for h in frames}
        # per-time hero rows, real heroes only (illusions dropped upstream)
        self.by_t = collections.defaultdict(dict)
        for h in frames:
            for s in frames[h]:
                self.by_t[s['t']][h] = s
        self.times = sorted(self.by_t)

        # buildings: last sample at or before a hero frame, alive only.
        self.btimes, self.blds, self.ancients = [], {}, {}
        by_t = collections.defaultdict(lambda: {RADIANT: [], DIRE: []})
        anc_by_t = collections.defaultdict(dict)
        for b in d.get('buildings', ()):
            if not b.get('alive'):
                continue
            by_t[b['t']][b['team']].append((b['x'], b['y']))
            if b.get('name') == 'ancient':
                anc_by_t[b['t']][b['team']] = (b['x'], b['y'])
        for t in sorted(by_t):
            self.btimes.append(t)
            self.blds[t] = by_t[t]
            self.ancients[t] = anc_by_t.get(t, {})

    def leg(self, hero):
        return 'armed' if self.teams.get(hero) == self.armed_team else 'baseline'

    def _bucket(self, t):
        lo, hi = 0, len(self.btimes) - 1
        if hi < 0 or t < self.btimes[0]:
            return None
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.btimes[mid] <= t:
                lo = mid
            else:
                hi = mid - 1
        return self.btimes[lo]

    def doors(self, t, bot, enemy):
        """(shipped_admit, invade_depth) for one (bot, enemy) pair at t.

        The depth is only meaningful when the shipped door did NOT admit: the
        Lua tests the depth branch solely `if not bInDomain`, so the bands
        below are disjoint by construction and the own-half count is never
        inflated by frames the building door already owned.
        """
        bt = self._bucket(t)
        if bt is None:
            return None
        my_team = self.teams[bot]
        for bx, by in self.blds[bt][my_team]:
            if dist(enemy['x'], enemy['y'], bx, by) <= BUILDING_RING:
                return (True, None)
        anc = self.ancients[bt]
        foe = DIRE if my_team == RADIANT else RADIANT
        if my_team not in anc or foe not in anc:
            return None                       # cannot decide -> refuse to answer
        ox, oy = anc[my_team]
        ex, ey = anc[foe]
        depth = (dist(enemy['x'], enemy['y'], ex, ey)
                 - dist(enemy['x'], enemy['y'], ox, oy))
        return (False, depth)

    def admitted_frames(self):
        """Yield (t, bot_hero, enemy_hero, band, d_bot_enemy) rows."""
        for t in self.times:
            here = self.by_t[t]
            live = [(h, s) for h, s in here.items() if s.get('hp', 0) > 0]
            for bh, bs in live:
                bteam = self.teams[bh]
                for eh, es in live:
                    if self.teams[eh] == bteam:
                        continue
                    dd = dist(bs['x'], bs['y'], es['x'], es['y'])
                    if dd > COLLAPSE_RING:
                        continue
                    doors = self.doors(t, bh, es)
                    if doors is None:
                        continue
                    shipped, depth = doors
                    if shipped:
                        yield (t, bh, eh, 'shipped', dd)
                    elif depth >= DEPTH_MARGIN:
                        yield (t, bh, eh, 'ownhalf', dd)
                    elif depth >= DEPTH_MARGIN - NEARMISS_WIDTH:
                        yield (t, bh, eh, 'nearmiss', dd)

    def pair_dist(self, t0, bh, eh):
        """Minimum bot-enemy distance over [t0, t0+CONSEQUENCE_WIN]."""
        best = None
        for t in self.times:
            if t < t0:
                continue
            if t > t0 + CONSEQUENCE_WIN:
                break
            here = self.by_t[t]
            if bh not in here or eh not in here:
                continue
            b, e = here[bh], here[eh]
            if b.get('hp', 0) <= 0:
                continue
            dd = dist(b['x'], b['y'], e['x'], e['y'])
            if best is None or dd < best:
                best = dd
        return best

    def episodes(self):
        """Collapse admitted frames into (bot, enemy, band) episodes."""
        runs = {}
        out = []
        for t, bh, eh, band, dd in self.admitted_frames():
            k = (bh, eh, band)
            r = runs.get(k)
            if r is not None and t - r['t_last'] <= EPISODE_GAP:
                r['t_last'] = t
                r['frames'] += 1
                continue
            if r is not None:
                out.append(r)
            runs[k] = {'bot': bh, 'enemy': eh, 'band': band, 't0': t,
                       't_last': t, 'frames': 1, 'd0': dd}
        out.extend(runs.values())
        for ep in out:
            dmin = self.pair_dist(ep['t0'], ep['bot'], ep['enemy'])
            ep['dmin'] = dmin
            ep['closed'] = (dmin is not None
                            and ep['d0'] - dmin >= CLOSE_DELTA)
            ep['engaged'] = dmin is not None and dmin <= ENGAGE_RANGE
            ep['leg'] = self.leg(ep['bot'])
            ep['game'] = self.name
            ep['side'] = self.side
        out.sort(key=lambda e: e['t0'])
        return out


    def trace(self, bot, enemy, t0, span=10.0, pre=3.0):
        """Frame-by-frame rows around one admission instant.

        The charter's hard rule is frame-first, aggregate-second, and a frame
        claim has to be re-runnable by the next reader -- so the trace lives
        in the tool rather than in a scratchpad probe.  Prints, per sampled
        frame: the pair distance, the invade depth of the enemy, the distance
        from the enemy to our NEAREST standing building (the shipped door's
        own quantity, so a reader can see the shipped door was shut), and
        which band the frame fell in.
        """
        print('# trace %s  bot=%s  enemy=%s  t0=%.1f' % (self.name, bot,
                                                         enemy, t0))
        print('#%7s %8s %8s %9s %10s' % ('t', 'd_pair', 'depth', 'd_bldg',
                                          'band'))
        for t in self.times:
            if t < t0 - pre or t > t0 + span:
                continue
            here = self.by_t[t]
            if bot not in here or enemy not in here:
                continue
            b, e = here[bot], here[enemy]
            bt = self._bucket(t)
            if bt is None:
                continue
            my_team = self.teams[bot]
            db = None
            for bx, by in self.blds[bt][my_team]:
                dd = dist(e['x'], e['y'], bx, by)
                if db is None or dd < db:
                    db = dd
            doors = self.doors(t, bot, e)
            if doors is None:
                continue
            shipped, depth = doors
            dpair = dist(b['x'], b['y'], e['x'], e['y'])
            if shipped:
                band, dshow = 'shipped', float('nan')
            else:
                dshow = depth
                if depth >= DEPTH_MARGIN:
                    band = 'ownhalf'
                elif depth >= DEPTH_MARGIN - NEARMISS_WIDTH:
                    band = 'nearmiss'
                else:
                    band = '-'
            if dpair > COLLAPSE_RING:
                band += ' (out of ring)'
            if b.get('hp', 0) <= 0:
                band += ' (bot dead)'
            print(' %7.1f %8.0f %8.0f %9.0f %10s'
                  % (t, dpair, dshow, db if db is not None else -1, band))


def tally(eps):
    """{(stratum, leg, band): counters} -- never pooled without the strata."""
    c = collections.defaultdict(lambda: collections.Counter())
    for e in eps:
        stratum = 'ab' if e['side'] == 'radiant' else 'ba'
        k = (stratum, e['leg'], e['band'])
        c[k]['episodes'] += 1
        c[k]['frames'] += e['frames']
        c[k]['closed'] += 1 if e['closed'] else 0
        c[k]['engaged'] += 1 if e['engaged'] else 0
    return c


def pct(n, d):
    return '   n/a' if not d else '%5.1f%%' % (100.0 * n / d)


def report(c, games):
    print('=== ownhalf domain / condition (a) instrument ===')
    print('constants read from bots/FunLib/jmz_func.lua: '
          'collapse ring %.0f, building door %.0f, depth margin %.0f'
          % (COLLAPSE_RING, BUILDING_RING, DEPTH_MARGIN))
    print('games: %d   episode gap %.1fs   consequence window %.1fs'
          % (games, EPISODE_GAP, CONSEQUENCE_WIN))
    print('')
    print('%-4s %-9s %-8s %8s %8s %8s %8s'
          % ('str', 'leg', 'band', 'eps', 'frames', 'closed', 'engaged'))
    for stratum in ('ab', 'ba'):
        for band in ('shipped', 'nearmiss', 'ownhalf'):
            for leg in ('armed', 'baseline'):
                k = (stratum, leg, band)
                v = c.get(k)
                if not v:
                    print('%-4s %-9s %-8s %8s %8s %8s %8s'
                          % (stratum, leg, band, 0, 0, '   n/a', '   n/a'))
                    continue
                print('%-4s %-9s %-8s %8d %8d %8s %8s'
                      % (stratum, leg, band, v['episodes'], v['frames'],
                         pct(v['closed'], v['episodes']),
                         pct(v['engaged'], v['episodes'])))
    print('')
    print('SIGNATURE (armed - baseline, percentage points):')
    for stratum in ('ab', 'ba'):
        row = []
        for band in ('shipped', 'nearmiss', 'ownhalf'):
            a = c.get((stratum, 'armed', band), collections.Counter())
            b = c.get((stratum, 'baseline', band), collections.Counter())
            if not a['episodes'] or not b['episodes']:
                row.append('%s=n/a' % band)
                continue
            d_cl = 100.0 * (a['closed'] / a['episodes']
                            - b['closed'] / b['episodes'])
            d_en = 100.0 * (a['engaged'] / a['episodes']
                            - b['engaged'] / b['episodes'])
            row.append('%s closed %+5.1f engaged %+5.1f' % (band, d_cl, d_en))
        print('  %s: %s' % (stratum, '\n      '.join(row)))
    def did(stratum, treated, control):
        """[(armed-baseline) on `treated`] - [(armed-baseline) on `control`]."""
        parts = []
        for metric in ('closed', 'engaged'):
            vals = {}
            for band in (treated, control):
                a = c.get((stratum, 'armed', band), collections.Counter())
                b = c.get((stratum, 'baseline', band), collections.Counter())
                if not a['episodes'] or not b['episodes']:
                    vals = None
                    break
                vals[band] = (100.0 * a[metric] / a['episodes']
                              - 100.0 * b[metric] / b['episodes'])
            if vals is None:
                parts.append('%s=n/a' % metric)
            else:
                parts.append('%s %+5.1f pp' % (metric,
                                               vals[treated] - vals[control]))
        return '   '.join(parts)

    print('')
    print('DISCONTINUITY AT THE CONSTANT (difference in differences):')
    print('  [(armed-baseline) on ownhalf] - [(armed-baseline) on nearmiss]')
    print('  The nearmiss band holds the lever OUT while holding the map,')
    print('  the legs and the pairing geometry IN, so this is the estimate')
    print('  that does not credit the lever with ordinary leg asymmetry.')
    for stratum in ('ab', 'ba'):
        print('  %s: %s' % (stratum, did(stratum, 'ownhalf', 'nearmiss')))
    print('')
    print('PLACEBO (same statistic, lever known ABSENT -- internal null):')
    print('  [(armed-baseline) on shipped] - [(armed-baseline) on nearmiss]')
    print('  `shipped` is the SAME code on both legs, so this DiD has every')
    print('  ingredient of the line above EXCEPT the lever. Whatever it')
    print('  returns is what this estimator returns on nothing -- read the')
    print('  real DiD against THIS, not against zero.')
    for stratum in ('ab', 'ba'):
        print('  %s: %s' % (stratum, did(stratum, 'shipped', 'nearmiss')))
    print('')
    print('BAND SIZE (pair-frames, ownhalf : shipped -- GH #695 invariant):')
    of = sum(v['frames'] for (s, l, b), v in c.items() if b == 'ownhalf')
    sf = sum(v['frames'] for (s, l, b), v in c.items() if b == 'shipped')
    print('  ownhalf %d : shipped %d  = %s' %
          (of, sf, ('%.2fx' % (of / sf)) if sf else 'n/a'))
    print('')
    print('READ THIS BEFORE QUOTING A NUMBER:')
    print('  * band counts are UPPER BOUNDS on fires -- SafeToCommitFight and')
    print('    ShouldRefuseUnsupportedPunish are not evaluated here.')
    print('  * the `shipped` band is the NOISE FLOOR: its code is identical on')
    print('    both legs, so its armed-baseline difference is what this')
    print('    statistic returns when the lever is known to be absent.')
    print('  * a sign flip between ab and ba is noise (iron rule 4(i-b)):')
    print('    these are detector counts, not side-de-biased estimators.')


def load_sweep(sweep_dir, max_games=None):
    man = os.path.join(sweep_dir, 'games_manifest.jsonl')
    games = []
    with open(man) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            g = json.loads(line)
            tl = os.path.join(sweep_dir, 'timelines',
                              g['game'] + '.timeline.json')
            if not os.path.exists(tl):
                continue
            if 'ownhalf' not in (g.get('cand') or '').split(','):
                continue        # a game whose arm string lacks the id is not
                                # a leg of this experiment; skipping it is not
                                # a filter on outcome
            games.append((tl, g['side'], g['game']))
    if max_games:
        games = games[:max_games]
    return games


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('timeline', nargs='?')
    ap.add_argument('--side', choices=('radiant', 'dire'))
    ap.add_argument('--sweep')
    ap.add_argument('--max-games', type=int)
    ap.add_argument('--episodes-out', help='write every episode as JSONL')
    ap.add_argument('--trace', metavar='BOT:ENEMY:T0',
                    help='frame-by-frame rows around one admission instant '
                         '(single-timeline mode)')
    args = ap.parse_args()

    if args.trace:
        if not (args.timeline and args.side):
            ap.error('--trace needs <timeline.json> --side {radiant,dire}')
        bot, enemy, t0 = args.trace.split(':')
        Game(args.timeline, args.side,
             os.path.basename(args.timeline)).trace(bot, enemy, float(t0))
        return 0

    if args.sweep:
        todo = load_sweep(args.sweep, args.max_games)
    elif args.timeline and args.side:
        todo = [(args.timeline, args.side, os.path.basename(args.timeline))]
    else:
        ap.error('need --sweep DIR, or <timeline.json> --side {radiant,dire}')

    all_eps = []
    for tl, side, name in todo:
        g = Game(tl, side, name)
        all_eps.extend(g.episodes())

    if args.episodes_out:
        with open(args.episodes_out, 'w') as fh:
            for e in all_eps:
                fh.write(json.dumps(e) + '\n')

    report(tally(all_eps), len(todo))
    return 0


if __name__ == '__main__':
    sys.exit(main())
