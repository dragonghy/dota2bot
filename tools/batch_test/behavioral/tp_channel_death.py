#!/usr/bin/env python3
"""Census of TP presses started with an enemy hero already in strike range.

WHAT THIS MEASURES AND WHY IT IS NOT AN A/B
-------------------------------------------
`J.ShouldNotStartInterruptibleTp` (`bots/FunLib/jmz_func.lua`) is a PROMOTED
turbo default -- no soak gate, live in every turbo game on BOTH legs of a
mirrored wave.  Its core, `J.CanEnemyInterruptTpChannel`, scans enemy heroes
within 700 u and answers true when any of them is within
`GetAttackRange() + 150` of us, or is closing the gap.  When it answers true
the bot is supposed to NOT begin the channel this frame.

So this file is not an armed/baseline comparison -- there is nothing to
compare, the guard is on everywhere.  The leg split below is a NEGATIVE
CONTROL: a promoted default must read the same on both legs, and a leg
difference would mean the population is being driven by whatever candidate
the wave is arming rather than by the guard.

WHAT IT CANNOT SETTLE, STATED UP FRONT
--------------------------------------
`J.ShouldWalkNotTp` has three deliberate fall-throughs that return false
(= let it TP anyway): the bot is rooted/stunned/hexed/nightmared, its
movement speed is under 285, or the on-face burst would kill it before a
walk step lands.  NONE of the three is in the behavioural dump -- there is no
movement-speed field and no crowd-control state.  A row in this census is
therefore NOT by itself a guard failure; it is the population inside which
guard failures must live.  Read the count as a domain size, and settle
individual rows frame by frame.

DECISION SIDE, NOT RESULT SIDE
------------------------------
The distance reported as `near` is measured AT THE PRESS INSTANT, linearly
interpolated between the bracketing snapshots (the dumper samples at ~1.0 s,
which is coarser than the decision).  `near_min` -- the minimum over the
whole channel -- is reported beside it and is a RESULT-side quantity: an
enemy who arrives after the press says nothing about whether pressing was
right.  The two come apart in both directions here (unlike a
min-over-episode, an interpolated instant can be larger OR smaller), which
is exactly why both columns are printed.  Same lesson as the
`ancient_camp_domain.nearest_enemy` / `nearest_enemy_t0` pair and the
2026-08-23 `stayfield2` anchor bug: never anchor on a frame from the
decision's future.
"""
import argparse
import collections
import json
import glob
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from creeppull_domain import load_sweep  # noqa: E402

# GetAttackRange() + 150 for the longest-ranged hero in the pool; the guard
# uses each enemy's own range, which is not in the dump, so this is the
# permissive bound -- it over-counts rather than silently dropping rows.
DEFAULT_REACH_U = 725.0
# J.CanEnemyInterruptTpChannel's own scan radius.
SCAN_RADIUS_U = 700.0
# A turbo TP channel is ~3 s; deaths past this are not "in the channel".
CHANNEL_WINDOW_S = 5.0


def canon(name):
    return (name or '').replace('npc_dota_hero_', '')


def interp(frames, t):
    """Hero state at an arbitrary instant, linearly interpolated.

    Returns None outside the sampled range rather than clamping: a press
    before the first snapshot or after the last one has no honest position,
    and clamping would silently invent one.
    """
    lo = hi = None
    for s in frames:
        if s['t'] <= t and (lo is None or s['t'] > lo['t']):
            lo = s
        if s['t'] >= t and (hi is None or s['t'] < hi['t']):
            hi = s
    if lo is None or hi is None:
        return None
    if hi['t'] == lo['t']:
        return dict(t=t, x=float(lo['x']), y=float(lo['y']),
                    hp_pct=float(lo['hp_pct']), level=lo['level'])
    a = (t - lo['t']) / (hi['t'] - lo['t'])
    return dict(t=t,
                x=lo['x'] + a * (hi['x'] - lo['x']),
                y=lo['y'] + a * (hi['y'] - lo['y']),
                hp_pct=lo['hp_pct'] + a * (hi['hp_pct'] - lo['hp_pct']),
                level=lo['level'])


def presses_for_game(timeline, game, reach=DEFAULT_REACH_U):
    fr = collections.defaultdict(list)
    team = {}
    for s in timeline['snapshots']:
        h = canon(s['hero'])
        fr[h].append(s)
        team[h] = s['team']
    for h in fr:
        fr[h].sort(key=lambda s: s['t'])

    press = collections.defaultdict(list)
    deaths = collections.defaultdict(list)
    for e in timeline['events']:
        if (e.get('inflictor') == 'modifier_teleporting'
                and e['type'] == 'MODIFIER_ADD'
                and canon(e.get('target')) == canon(e.get('actor'))):
            press[canon(e['actor'])].append(e['t'])
        if e['type'] == 'DEATH' and e.get('target_hero'):
            deaths[canon(e['target'])].append(e['t'])

    out = []
    for h, ts in press.items():
        for t in ts:
            s0 = interp(fr[h], t)
            if s0 is None:
                continue
            near = near_min = None
            who = None
            for h2 in fr:
                if h2 == h or team.get(h2) == team.get(h):
                    continue
                s2 = interp(fr[h2], t)
                if s2 is not None and s2['hp_pct'] > 0:
                    dd = math.dist((s0['x'], s0['y']), (s2['x'], s2['y']))
                    if near is None or dd < near:
                        near, who = dd, h2
                # result side: min over the channel, for contrast only
                for s2b in fr[h2]:
                    if not (t <= s2b['t'] <= t + CHANNEL_WINDOW_S):
                        continue
                    s0b = interp(fr[h], s2b['t'])
                    if s0b is None or s2b['hp_pct'] <= 0:
                        continue
                    dd = math.dist((s0b['x'], s0b['y']), (s2b['x'], s2b['y']))
                    if near_min is None or dd < near_min:
                        near_min = dd
            died = [dt for dt in deaths.get(h, []) if t <= dt <= t + CHANNEL_WINDOW_S]
            out.append(dict(
                game=game, hero=h, t=round(t, 1),
                hp=round(s0['hp_pct'], 3), level=s0['level'],
                near=round(near) if near is not None else None,
                near_min=round(near_min) if near_min is not None else None,
                nearest_hero=who,
                on_face=near is not None and near <= reach,
                in_scan=near is not None and near <= SCAN_RADIUS_U,
                died_in_channel=bool(died),
                death_t=round(died[0], 1) if died else None,
            ))
    return out


def scan_sweep(d, reach):
    rows = []
    manifest = {m['game']: m for m in load_sweep(d)}
    for p in sorted(glob.glob(os.path.join(d, 'timelines', '*.timeline.json'))):
        game = os.path.basename(p).replace('.timeline.json', '')
        m = manifest.get(game)
        if m is None:
            continue
        tl = json.load(open(p))
        for r in presses_for_game(tl, game, reach):
            r['seed'] = m['seed']
            r['arm_side'] = m['side']
            r['leg'] = 'armed' if (
                (m['side'] == 'radiant' and _team_of(tl, r['hero']) == 2)
                or (m['side'] == 'dire' and _team_of(tl, r['hero']) == 3)
            ) else 'baseline'
            rows.append(r)
    return rows


def _team_of(timeline, hero):
    for s in timeline['snapshots']:
        if canon(s['hero']) == hero:
            return s['team']
    return None


def table(rows, title, key):
    print('\n  %s' % title)
    print('  %-16s %8s %10s %10s %9s'
          % ('stratum/leg', 'presses', 'on-face', 'fatal', 'fatal/game'))
    for side in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            g = [r for r in rows if r['arm_side'] == side and r['leg'] == leg]
            if not g:
                continue
            games = len({r['game'] for r in g})
            of = [r for r in g if r[key]]
            fatal = [r for r in of if r['died_in_channel']]
            print('  %-16s %8d %10d %10d %9.3f'
                  % ('%s-armed/%s' % (side, leg), len(g), len(of), len(fatal),
                     len(fatal) / games if games else 0.0))
    of = [r for r in rows if r[key]]
    fatal = [r for r in of if r['died_in_channel']]
    games = len({r['game'] for r in rows})
    print('  %-16s %8d %10d %10d %9.3f'
          % ('POOLED', len(rows), len(of), len(fatal),
             len(fatal) / games if games else 0.0))


def selfcheck():
    ok = fail = 0

    def chk(name, cond, detail=''):
        nonlocal ok, fail
        if cond:
            ok += 1
            print('  PASS %-58s %s' % (name, detail))
        else:
            fail += 1
            print('  FAIL %-58s %s' % (name, detail))

    def snaps(hero, team, pts, level=9):
        return [{'t': float(t), 'hero': hero, 'team': team, 'x': float(x),
                 'y': float(y), 'hp_pct': hp, 'level': level, 'items': []}
                for t, x, y, hp in pts]

    H, E = 'npc_dota_hero_jakiro', 'npc_dota_hero_viper'
    # Enemy is FAR at the press (t=10) and walks in afterwards.  near must
    # report the press instant; near_min must report the arrival.
    sn = (snaps(H, 3, [(t, 0, 0, 1.0) for t in range(0, 20)])
          + snaps(E, 2, [(t, 5000 if t < 12 else 100, 0, 1.0)
                         for t in range(0, 20)]))
    ev = [{'t': 10.0, 'type': 'MODIFIER_ADD', 'actor': H, 'target': H,
           'inflictor': 'modifier_teleporting', 'value': 0}]
    r = presses_for_game({'snapshots': sn, 'events': ev}, 'g')[0]
    chk('near is the press instant, not the channel', r['near'] == 5000,
        'near=%s' % r['near'])
    chk('near_min is the result side and sees the arrival',
        r['near_min'] == 100, 'near_min=%s' % r['near_min'])
    chk('a far press is not on_face', r['on_face'] is False)
    chk('no death event -> not fatal', r['died_in_channel'] is False)

    # Enemy on face at the press; interpolation must land between snapshots.
    sn2 = (snaps(H, 3, [(t, 0, 0, 1.0) for t in range(0, 20)])
           + snaps(E, 2, [(t, 200 if t <= 10 else 1200, 0, 1.0)
                          for t in range(0, 20)]))
    ev2 = [{'t': 10.5, 'type': 'MODIFIER_ADD', 'actor': H, 'target': H,
            'inflictor': 'modifier_teleporting', 'value': 0},
           {'t': 12.5, 'type': 'DEATH', 'actor': E, 'target': H,
            'inflictor': 'x', 'value': 1, 'target_hero': True}]
    r2 = presses_for_game({'snapshots': sn2, 'events': ev2}, 'g')[0]
    chk('press between samples is interpolated, not clamped',
        r2['near'] == 700, 'near=%s (200 and 1200 brackets)' % r2['near'])
    chk('700 u is inside the 725 u reach bound', r2['on_face'] is True)
    chk('a death inside the channel window is tagged',
        r2['died_in_channel'] is True and r2['death_t'] == 12.5)

    # A death AFTER the channel window must not be attributed to the channel.
    ev3 = [ev2[0], dict(ev2[1], t=17.0)]
    r3 = presses_for_game({'snapshots': sn2, 'events': ev3}, 'g')[0]
    chk('a death past the channel window is NOT tagged',
        r3['died_in_channel'] is False)

    # An ALLY on face must never count -- the guard scans enemies only.
    sn4 = (snaps(H, 3, [(t, 0, 0, 1.0) for t in range(0, 20)])
           + snaps(E, 3, [(t, 100, 0, 1.0) for t in range(0, 20)]))
    r4 = presses_for_game({'snapshots': sn4, 'events': [ev2[0]]}, 'g')[0]
    chk('a same-team hero on face is not an interrupter',
        r4['near'] is None and r4['on_face'] is False)

    # A DEAD enemy on face must not count either.
    sn5 = (snaps(H, 3, [(t, 0, 0, 1.0) for t in range(0, 20)])
           + snaps(E, 2, [(t, 100, 0, 0.0) for t in range(0, 20)]))
    r5 = presses_for_game({'snapshots': sn5, 'events': [ev2[0]]}, 'g')[0]
    chk('a dead enemy on face is not an interrupter',
        r5['near'] is None and r5['on_face'] is False)

    # A press outside the sampled range has no honest position.
    ev6 = [{'t': 99.0, 'type': 'MODIFIER_ADD', 'actor': H, 'target': H,
            'inflictor': 'modifier_teleporting', 'value': 0}]
    chk('a press past the last snapshot is dropped, not clamped',
        presses_for_game({'snapshots': sn2, 'events': ev6}, 'g') == [])

    # MODIFIER_REMOVE must not be read as a press.
    ev7 = [dict(ev2[0], type='MODIFIER_REMOVE')]
    chk('channel END is not a press',
        presses_for_game({'snapshots': sn2, 'events': ev7}, 'g') == [])

    print('\nselfcheck: %d PASS / %d FAIL' % (ok, fail))
    return 0 if fail == 0 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--reach', type=float, default=DEFAULT_REACH_U)
    ap.add_argument('--top', type=int, default=15)
    ap.add_argument('--out', default='/tmp/tp_channel_death.jsonl')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.sweeps:
        ap.error('give at least one sweep dir (or --selfcheck)')

    rows = []
    for d in a.sweeps:
        rows.extend(scan_sweep(d, a.reach))
    games = len({(r['game'], r['arm_side']) for r in rows})
    print('corpus: %d games / %d TP presses from %d sweep dir(s)'
          % (games, len(rows), len(a.sweeps)))
    print('reach bound %.0f u (GetAttackRange()+150, permissive), '
          'guard scan radius %.0f u, channel window %.1f s'
          % (a.reach, SCAN_RADIUS_U, CHANNEL_WINDOW_S))

    table(rows, 'enemy hero within the REACH bound at the press instant',
          'on_face')
    table(rows, 'enemy hero inside the guard SCAN radius at the press',
          'in_scan')

    allfatal = [r for r in rows if r['died_in_channel']]
    onface = [r for r in rows if r['on_face']]
    fatal = [r for r in onface if r['died_in_channel']]
    print('\n  base rate: %d/%d presses (%.1f%%) end in death within %.0f s'
          % (len(allfatal), len(rows),
             100.0 * len(allfatal) / len(rows) if rows else 0.0,
             CHANNEL_WINDOW_S))
    print('  on-face  : %d/%d (%.1f%%) -- the lift is the whole finding'
          % (len(fatal), len(onface),
             100.0 * len(fatal) / len(onface) if onface else 0.0))

    # Result-side contrast: how many rows would flip if `near` were read as a
    # min over the channel instead of at the press.
    flip = [r for r in rows if r['near'] is not None and r['near_min'] is not None
            and r['near'] > a.reach >= r['near_min']]
    print('  presses that look on-face ONLY under the result-side column: %d'
          % len(flip))

    print('\n--- on-face presses that ended in death, closest first ---')
    for r in sorted(fatal, key=lambda r: r['near'])[:a.top]:
        print('  %s %-15s t=%6.1f hp=%.3f L%-2d near=%4d/min=%s (%s) '
              'death=%.1f leg=%s'
              % (r['game'], r['hero'], r['t'], r['hp'], r['level'], r['near'],
                 r['near_min'], r['nearest_hero'], r['death_t'], r['leg']))

    with open(a.out, 'w') as fh:
        for r in rows:
            fh.write(json.dumps(r) + '\n')
    print('\nwrote %d records to %s' % (len(rows), a.out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
