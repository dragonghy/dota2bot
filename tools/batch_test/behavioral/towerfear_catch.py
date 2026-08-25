#!/usr/bin/env python3
"""towerfear: does the CALIBRATED clause actually catch the released frames?

WHAT THIS ANSWERS (and what `towerfear_domain.py` already answered)
------------------------------------------------------------------
`towerfear_domain.py` bought condition (a)'s POSITIVE half: the armed leg does
spend more time inside the enemy-tower ring in the released rectangle
(level 6..10, 150 s <= t < 300 s).  That reading was reproduced on two waves.

This reader buys the two readings that request `queue.json:strategy-12`
registered up front and that nobody has measured yet:

  (4) "the total retreat under the tower must not collapse toward 0 -- that
      would not be a narrowing, it would be a shutdown; THE CALIBRATED CLAUSE
      MUST STILL BE CATCHING."
  (3) "deaths in the same window must not rise" -- the reverse criterion,
      explicitly not省-able, and explicitly NOT substitutable by the wave-level
      per-game deaths average (that is a 10-hero global mean).

The calibrated clause is `bots/mode_retreat_generic.lua:915-922`, sitting
directly under the lever:

    if botLevel <= 9
        and nEnemyTowers[1] ~= nil
        and nEnemyTowers[1]:CanBeSeen()
        and nEnemyTowers[1]:GetAttackTarget() == bot
        and #hAllyHeroList <= 1
    then
        return 2;
    end

and the source comment above the lever asserts, in prose:

    "What catches the released frames instead is the CALIBRATED clause
     directly below -- same tower ring, but it asks whether the tower is
     actually shooting this bot and whether it is alone."

That sentence is a testable claim about the corpus, and this reader tests it.

HOW EACH LEG IS READ (and which direction each error goes)
----------------------------------------------------------
Per released frame (level 6..10, t in [150,300), gate context true, nearest
enemy tower within the ring -- i.e. exactly the frames where the shipped
predicate returns 2 and the armed one does not):

  L_lvl   `botLevel <= 9`          EXACT.  `snapshots[].level`.  A level-10
                                   frame is released by the lever and is NOT
                                   catchable -- the clause's own level leg is
                                   one narrower than the block's `<= 10`.
  L_seen  `CanBeSeen()`            NOT read; assumed TRUE for every frame.
                                   A tower 898 u away is inside hero day
                                   vision (1800 u).  This is GENEROUS to the
                                   clause on purpose: assuming it can only
                                   make the catch estimate too BIG.
  L_alone `#hAllyHeroList <= 1`    Geometric, and near-exact: `J.GetAllyList`
                                   (`jmz_func.lua:3761`) is
                                   `GetNearbyHeroes(bot, 1600, false, ...)`
                                   minus dead and illusions.  Allies need no
                                   vision, so the only gap vs the engine is
                                   the `<= 1` early-return shortcut at :3767,
                                   which returns the UNFILTERED list -- and
                                   that shortcut can only fire when the list
                                   is already <= 1, i.e. it never changes the
                                   truth of `#list <= 1`.  Illusions and dead
                                   heroes ARE filtered here (GH #176).
  L_shot  `GetAttackTarget()==bot` WITNESS, one-directional.  A tower `DAMAGE`
                                   event whose actor is the nearest enemy
                                   tower and whose target is this hero, within
                                   +-1 s of the frame, PROVES the tower was
                                   shooting him.  Its absence does NOT prove
                                   the opposite (the tower may have acquired
                                   him and had him step out before the shot
                                   landed).

So the reading is a SANDWICH, not a point estimate:

    UPPER  = L_lvl and L_alone                      (L_seen granted,
                                                     L_shot granted)
    LOWER  = L_lvl and L_alone and L_shot           (witness required)
    HARD-0 = frames failing `d_tower <= 700`: a tower's attack range is 700 u,
             so at 700 < d <= 898 `GetAttackTarget() == bot` is ARITHMETICALLY
             impossible.  Those frames are inside the ring (they are released)
             and outside the clause, with no modelling in between.

Reporting follows GH #148: every armed-minus-baseline difference is given in
BOTH physical strata (ab = candidate armed on radiant, ba = on dire); counts
over a small integer range are reported as mean + a share, never as a bare
median.  The catch RATE is a per-frame conditional (a property of the released
frames themselves), so its headline is the armed leg's own number -- the
armed-minus-baseline column is printed beside it as a sanity check, not as the
claim.

Read-only.  Touches no AWS resource.
"""
import argparse
import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from towerfear_domain import (           # noqa: E402  (path set above)
    RADIANT, DIRE, RING_U, CTX_U, CTX_HP, ARMED_CLOCK, SHIPPED_CLOCK,
    LEVEL_CAP, LEVEL_LEG, Game, dist, fmt, load_sweep, stratum,
)

# mode_retreat_generic.lua:916 -- the clause's own level leg, ONE narrower
# than the enclosing block's `botLevel <= 10`.
CALIB_LEVEL = 9
# A Dota tower's attack range.  Not a tuning knob: `GetAttackTarget()` cannot
# return a unit the tower cannot reach, so this is the arithmetic floor under
# the L_shot leg.
TOWER_ATTACK_RANGE_U = 700.0
# J.GetAllyList(bot, 1600) at mode_retreat_generic.lua:773; `#list <= 1`.
ALLY_R_U = CTX_U
ALLY_CAP = 1
# A tower shot is a single instant; snapshots are 1 Hz.  +-1 s is one sample
# step either way -- wide enough that a shot between two samples is credited,
# narrow enough that a shot at the far end of the episode is not.
SHOT_WINDOW_S = 1.0


def canon(name):
    """Hero names are compared canonically -- charter tool-trap #1."""
    return (name or '').replace('npc_dota_hero_', '')


def tower_shots(timeline):
    """(hero, t) pairs where a tower's attack landed on that hero.

    `events[].type == 'DAMAGE'` with a tower actor and `target_hero` true.
    The dumper marks hero-ness explicitly, so no name sniffing is needed.
    """
    out = []
    for e in timeline.get('events', ()):
        if e.get('type') != 'DAMAGE' or not e.get('target_hero'):
            continue
        a = e.get('actor') or ''
        if '_tower' not in a:
            continue
        out.append((canon(e.get('target')), float(e['t']), a))
    return out


def hero_deaths(timeline):
    """Real hero deaths: a DEATH event that the snapshot chain corroborates.

    GH #176: an illusion carries its hero's name, so a DEATH event alone can
    be an illusion dying.  A real death also removes the hero from the live
    snapshot stream, so we require a corroborating gap: no living frame for
    that hero in (t, t + 2 s].  Illusion deaths leave the hero walking around
    and are dropped by that test.
    """
    live = defaultdict(list)
    for s in timeline['snapshots']:
        if s.get('hp', 0) > 0:
            live[canon(s['hero'])].append(float(s['t']))
    for k in live:
        live[k].sort()
    out = []
    for e in timeline.get('events', ()):
        if e.get('type') != 'DEATH' or not e.get('target_hero'):
            continue
        h = canon(e.get('target'))
        t = float(e['t'])
        if any(t < x <= t + 2.0 for x in live.get(h, ())):
            continue                       # still alive right after: illusion
        out.append((h, t, canon(e.get('actor'))))
    return out


def level_at(timeline, hero, t):
    """The hero's level at his last living frame at or before t."""
    best = None
    for s in timeline['snapshots']:
        if canon(s['hero']) != hero or s.get('hp', 0) <= 0:
            continue
        st = float(s['t'])
        if st <= t and (best is None or st > best[0]):
            best = (st, s.get('level', 0))
    return None if best is None else best[1]


def ally_counts(timeline):
    """(t, hero) -> living non-illusion allies within 1600 u.

    Illusion filter (GH #176): a snapshot row is the real hero only if its
    `idx` is the hero's PRIMARY idx -- the one that appears in the most frames
    for that (hero, player_id).  Illusions share the name and player_id and
    differ only in `idx`, and they are exactly what `J.GetAllyList` drops at
    `jmz_func.lua:3772`.
    """
    seen = defaultdict(lambda: defaultdict(int))
    for s in timeline['snapshots']:
        seen[(canon(s['hero']), s.get('player_id'))][s.get('idx')] += 1
    primary = {}
    for k, d in seen.items():
        primary[k] = max(d.items(), key=lambda kv: kv[1])[0]

    by_t = defaultdict(list)
    for s in timeline['snapshots']:
        k = (canon(s['hero']), s.get('player_id'))
        if s.get('idx') != primary[k]:
            continue                        # illusion
        if s.get('hp', 0) <= 0:
            continue                        # dead
        by_t[float(s['t'])].append(s)

    out = {}
    for t, here in by_t.items():
        for s in here:
            n = 0
            for o in here:
                if o is s or o['team'] != s['team']:
                    continue
                if dist(s['x'], s['y'], o['x'], o['y']) <= ALLY_R_U:
                    n += 1
            out[(t, canon(s['hero']))] = n
    return out


def released_frames(game, timeline, ring, key, st):
    """Frames the lever RELEASES, each tagged with the calibrated legs.

    Released = the shipped predicate fires and the armed one does not:
    level 6..10 (level leg false), 150 <= t < 300 (shipped clock leg true,
    armed clock leg false), gate context true, tower within the ring.
    """
    allies = ally_counts(timeline)
    by_hero_shot = defaultdict(list)
    for h, t, _a in tower_shots(timeline):
        by_hero_shot[h].append(t)

    rows = []
    for r in game.frames():
        if r['rect'] != 'R_lever':
            continue
        if not (r['d_tower'] <= ring and r['ctx']):
            continue
        h = canon(r['hero'])
        n_ally = allies.get((r['t'], h))
        if n_ally is None:
            continue                        # this frame was an illusion row
        shot = any(abs(t - r['t']) <= SHOT_WINDOW_S
                   for t in by_hero_shot.get(h, ()))
        rows.append({
            'key': key, 'hero': h, 'leg': r['leg'],
            'stratum': st, 't': r['t'], 'level': r['level'],
            'd_tower': r['d_tower'], 'n_ally': n_ally,
            'L_lvl': r['level'] <= CALIB_LEVEL,
            'L_alone': n_ally <= ALLY_CAP,
            'L_range': r['d_tower'] <= TOWER_ATTACK_RANGE_U,
            'L_shot': shot,
        })
    return rows


def death_rows(game, timeline):
    """In-window deaths, with the enemy-tower distance at the death instant."""
    pos = {}
    for s in timeline['snapshots']:
        pos[(float(s['t']), canon(s['hero']))] = s
    out = []
    for h, t, killer in hero_deaths(timeline):
        if not (ARMED_CLOCK <= t < SHIPPED_CLOCK):
            continue
        lvl = level_at(timeline, h, t)
        if lvl is None or lvl > LEVEL_CAP or lvl <= LEVEL_LEG:
            continue                        # outside the released rectangle
        # nearest living-frame snapshot at or before the death
        best = None
        for (st, hh), s in pos.items():
            if hh != h or st > t or s.get('hp', 0) <= 0:
                continue
            if best is None or st > best[0]:
                best = (st, s)
        d_t = None
        if best is not None:
            s = best[1]
            d_t = game.nearest_enemy_tower(best[0], s['team'], s['x'], s['y'])
        out.append({'key': game_key(game), 'hero': h, 'leg': game.leg(
            'npc_dota_hero_' + h), 'stratum': None, 't': t, 'level': lvl,
            'd_tower': d_t, 'killer': killer})
    return out


_GAME_KEYS = {}


def game_key(game, key=None):
    if key is not None:
        _GAME_KEYS[id(game)] = key
    return _GAME_KEYS.get(id(game))


def catch_table(rows):
    """The (4) reading: how much of the released band the clause can catch."""
    agg = defaultdict(lambda: defaultdict(int))
    for r in rows:
        k = (r['stratum'], r['leg'])
        a = agg[k]
        a['n'] += 1
        a['lvl'] += r['L_lvl']
        a['alone'] += r['L_alone']
        a['range'] += r['L_range']
        a['shot'] += r['L_shot']
        upper = r['L_lvl'] and r['L_alone']
        a['upper'] += upper
        a['upper_r'] += upper and r['L_range']
        a['lower'] += upper and r['L_shot']

    print()
    print('(4) CALIBRATED CLAUSE COVERAGE OF THE RELEASED BAND')
    print('    released frame = level 6..10, 150<=t<300, gate ctx, tower in '
          'ring')
    hdr = ('%-3s %-9s %8s %7s %7s %7s %7s %9s %9s %9s' %
           ('str', 'leg', 'released', 'lvl<=9', 'alone', 'd<=700', 'shot',
            'UPPER%', 'UPPER+r%', 'LOWER%'))
    print(hdr)
    print('-' * len(hdr))
    tab = {}
    for st in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            a = agg[(st, leg)]
            n = a['n']
            if not n:
                print('%-3s %-9s %8d %7s %7s %7s %7s %9s %9s %9s'
                      % (st, leg, 0, '-', '-', '-', '-', '-', '-', '-'))
                continue
            row = {
                'n': n,
                'lvl': 100.0 * a['lvl'] / n,
                'alone': 100.0 * a['alone'] / n,
                'range': 100.0 * a['range'] / n,
                'shot': 100.0 * a['shot'] / n,
                'upper': 100.0 * a['upper'] / n,
                'upper_r': 100.0 * a['upper_r'] / n,
                'lower': 100.0 * a['lower'] / n,
            }
            tab[(st, leg)] = row
            print('%-3s %-9s %8d %6.1f%% %6.1f%% %6.1f%% %6.1f%% %8.2f%% '
                  '%8.2f%% %8.2f%%'
                  % (st, leg, n, row['lvl'], row['alone'], row['range'],
                     row['shot'], row['upper'], row['upper_r'], row['lower']))
    print('-' * len(hdr))
    print('UPPER   = lvl<=9 and alone      (CanBeSeen and GetAttackTarget '
          'both GRANTED)')
    print('UPPER+r = UPPER and d<=700      (the arithmetic floor under '
          'GetAttackTarget)')
    print('LOWER   = UPPER and a witnessed tower shot within +-%.0f s'
          % SHOT_WINDOW_S)
    print()
    hdr2 = '%-9s %9s %9s %9s %s' % ('metric', 'ab', 'ba', 'balanced', '')
    print('armed-minus-baseline, per GH #148 (i) -- sanity column, not the '
          'claim')
    print(hdr2)
    print('-' * len(hdr2))
    for m in ('upper', 'upper_r', 'lower', 'alone', 'range', 'shot'):
        per = {}
        for st in ('ab', 'ba'):
            a = tab.get((st, 'armed'), {}).get(m)
            b = tab.get((st, 'baseline'), {}).get(m)
            per[st] = None if a is None or b is None else a - b
        bal = (None if per['ab'] is None or per['ba'] is None
               else (per['ab'] + per['ba']) / 2.0)
        same = (per['ab'] is not None and per['ba'] is not None
                and per['ab'] * per['ba'] > 0)
        print('%-9s %9s %9s %9s %s'
              % (m, fmt(per['ab']), fmt(per['ba']), fmt(bal),
                 'both-strata' if same else 'SIGN-SPLIT (do not read)'))
    return tab


def death_table(deaths, hero_games, ring):
    """The (3) reading: deaths in the released window must not rise.

    Small-integer count over a tiny range, so per GH #148 (ii): mean per
    hero-game plus the share of hero-games carrying at least one -- never a
    bare median.
    """
    n_d = defaultdict(int)
    n_d_tower = defaultdict(int)
    who = defaultdict(set)
    who_tower = defaultdict(set)
    for d in deaths:
        k = (d['stratum'], d['leg'])
        n_d[k] += 1
        who[k].add((d['key'], d['hero']))
        if d['d_tower'] is not None and d['d_tower'] <= ring:
            n_d_tower[k] += 1
            who_tower[k].add((d['key'], d['hero']))

    print()
    print('(3) REVERSE CRITERION -- in-window deaths (level 6..10, '
          '150<=t<300)')
    hdr = ('%-3s %-9s %8s %7s %8s %9s %8s %9s' %
           ('str', 'leg', 'heroGm', 'deaths', 'per hGm', 'share>=1',
            'nearTwr', 'twr/hGm'))
    print(hdr)
    print('-' * len(hdr))
    tab = {}
    for st in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            k = (st, leg)
            hg = hero_games.get(k, 0)
            if not hg:
                continue
            row = {'per': n_d[k] / hg, 'share': 100.0 * len(who[k]) / hg,
                   'twr': n_d_tower[k] / hg, 'n': n_d[k], 'hg': hg,
                   'ntwr': n_d_tower[k]}
            tab[k] = row
            print('%-3s %-9s %8d %7d %8.3f %8.1f%% %8d %9.3f'
                  % (st, leg, hg, n_d[k], row['per'], row['share'],
                     n_d_tower[k], row['twr']))
    print('-' * len(hdr))
    print()
    hdr2 = '%-9s %9s %9s %9s %s' % ('metric', 'ab', 'ba', 'balanced', '')
    print('armed-minus-baseline, per GH #148 (i)')
    print(hdr2)
    print('-' * len(hdr2))
    for m in ('per', 'share', 'twr'):
        per = {}
        for st in ('ab', 'ba'):
            a = tab.get((st, 'armed'), {}).get(m)
            b = tab.get((st, 'baseline'), {}).get(m)
            per[st] = None if a is None or b is None else a - b
        bal = (None if per['ab'] is None or per['ba'] is None
               else (per['ab'] + per['ba']) / 2.0)
        same = (per['ab'] is not None and per['ba'] is not None
                and per['ab'] * per['ba'] > 0)
        print('%-9s %9s %9s %9s %s'
              % (m, fmt(per['ab'], 3), fmt(per['ba'], 3), fmt(bal, 3),
                 'both-strata' if same else 'SIGN-SPLIT (do not read)'))
    return tab


# ---------------------------------------------------------------- selfcheck

def _tl(snaps, events, buildings, teams):
    return {'game': {'teams': teams, 'start_time': 0, 'vision_note': ''},
            'snapshots': snaps, 'events': events, 'buildings': buildings,
            'creeps': [], 'wards': []}


def selfcheck():
    import tempfile
    ok = [True]

    def chk(name, cond, detail=''):
        print('  %-52s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok[0] = ok[0] and bool(cond)

    tmp = tempfile.mkdtemp(prefix='towerfear_catch_sc_')

    def build(level=8, d_tower=600.0, n_ally=0, shot_t=None,
              ally_dist=500.0, illusion=False, tlo=200.0, thi=210.0):
        """One radiant hero standing d_tower from the dire tower."""
        tower = (10000.0, 0.0)
        builds, snaps, events = [], [], []
        for t in [x * 5.0 for x in range(-14, 121)]:
            builds.append({'t': t, 'name': 'tower', 'team': DIRE,
                           'x': tower[0], 'y': tower[1], 'hp': 1,
                           'hp_pct': 1, 'alive': True})
            builds.append({'t': t, 'name': 'tower', 'team': RADIANT,
                           'x': -10000.0, 'y': 0.0, 'hp': 1, 'hp_pct': 1,
                           'alive': True})
        teams = {'npc_dota_hero_a': RADIANT, 'npc_dota_hero_e': DIRE}
        for i in range(n_ally):
            teams['npc_dota_hero_al%d' % i] = RADIANT
        for t in [x * 1.0 for x in range(0, 400)]:
            inwin = tlo <= t <= thi
            dd = d_tower if inwin else 3000.0
            snaps.append({'t': t, 'hero': 'npc_dota_hero_a', 'team': RADIANT,
                          'x': tower[0] - dd, 'y': 0.0, 'hp': 1000,
                          'level': level, 'items': [], 'idx': 1,
                          'player_id': 0})
            # an enemy parked 1000 u away keeps the gate context true
            snaps.append({'t': t, 'hero': 'npc_dota_hero_e', 'team': DIRE,
                          'x': tower[0] - dd, 'y': 1000.0, 'hp': 1000,
                          'level': level, 'items': [], 'idx': 2,
                          'player_id': 5})
            for i in range(n_ally):
                snaps.append({'t': t, 'hero': 'npc_dota_hero_al%d' % i,
                              'team': RADIANT, 'x': tower[0] - dd,
                              'y': -ally_dist, 'hp': 1000, 'level': level,
                              'items': [], 'idx': 3 + i, 'player_id': 1 + i})
            if illusion:
                # same name, same player_id, different idx, standing right
                # next to him -- GH #176's pollution, must NOT count as an ally
                snaps.append({'t': t, 'hero': 'npc_dota_hero_al0',
                              'team': RADIANT, 'x': tower[0] - dd, 'y': -100.0,
                              'hp': 1000, 'level': level, 'items': [],
                              'idx': 99, 'player_id': 1})
        if shot_t is not None:
            events.append({'t': shot_t, 'type': 'DAMAGE',
                           'actor': 'npc_dota_badguys_tower1_mid',
                           'target': 'npc_dota_hero_a',
                           'inflictor': 'dota_unknown', 'value': 60,
                           'actor_hero': False, 'target_hero': True})
        return _tl(snaps, events, builds, teams)

    def rows_for(tl, key='g', side='radiant'):
        """Drive the REAL reader, not a re-implementation of it.

        The charter's `selfskip-trap` lesson: a fixture that rebuilds the
        predicate inside the test passes for its own reasons and says nothing
        about the shipped code path.  So this calls `released_frames()`
        itself; every leg assertion below is an assertion about that function.
        """
        p = os.path.join(tmp, key + '.json')
        with open(p, 'w') as f:
            json.dump(tl, f)
        g = Game(p, side)
        return g, released_frames(g, tl, RING_U, key, stratum(side))

    # --- the four legs, each negated one at a time -----------------------
    _, base = rows_for(build(level=8, d_tower=600.0, n_ally=0, shot_t=205.0),
                       'base')
    me = [r for r in base if r['hero'] == 'a']
    chk('baseline case: released frames exist', len(me) >= 5, '%d' % len(me))
    chk('L_lvl true at level 8', all(r['L_lvl'] for r in me))
    chk('L_alone true with zero allies', all(r['L_alone'] for r in me))
    chk('L_range true at 600 u', all(r['L_range'] for r in me))
    chk('L_shot true on the shot second',
        any(r['L_shot'] for r in me) and
        all(r['L_shot'] for r in me if abs(r['t'] - 205.0) <= SHOT_WINDOW_S))

    _, l10 = rows_for(build(level=10, shot_t=205.0), 'l10')
    m10 = [r for r in l10 if r['hero'] == 'a']
    chk('level 10 is RELEASED but NOT catchable (lvl leg)',
        m10 and not any(r['L_lvl'] for r in m10), '%d frames' % len(m10))

    _, far = rows_for(build(d_tower=800.0, shot_t=205.0), 'far')
    mf = [r for r in far if r['hero'] == 'a']
    chk('d=800 is in the 898 ring but out of the 700 attack range',
        mf and not any(r['L_range'] for r in mf), '%d frames' % len(mf))

    _, pals = rows_for(build(n_ally=2, shot_t=205.0), 'pals')
    mp = [r for r in pals if r['hero'] == 'a']
    chk('two allies inside 1600 u falsify L_alone',
        mp and not any(r['L_alone'] for r in mp),
        'n_ally=%s' % (mp[0]['n_ally'] if mp else '-'))
    _, one = rows_for(build(n_ally=1, shot_t=205.0), 'one')
    mo = [r for r in one if r['hero'] == 'a']
    chk('exactly ONE ally still satisfies L_alone (<=1, not <1)',
        mo and all(r['L_alone'] for r in mo),
        'n_ally=%s' % (mo[0]['n_ally'] if mo else '-'))
    _, farpal = rows_for(build(n_ally=1, ally_dist=1700.0, shot_t=205.0),
                         'farpal')
    mfp = [r for r in farpal if r['hero'] == 'a']
    chk('an ally at 1700 u is outside the 1600 u list',
        mfp and mfp[0]['n_ally'] == 0,
        'n_ally=%s' % (mfp[0]['n_ally'] if mfp else '-'))

    _, noshot = rows_for(build(shot_t=None), 'noshot')
    mn = [r for r in noshot if r['hero'] == 'a']
    chk('no tower DAMAGE event => L_shot false everywhere',
        mn and not any(r['L_shot'] for r in mn))

    # GH #176: the illusion decoy.  Two allies present in the raw rows, but
    # one is an illusion (same name+player_id, different idx) -- L_alone must
    # stay TRUE.  Delete the idx filter in ally_counts() and only this reddens.
    _, ill = rows_for(build(n_ally=1, illusion=True, shot_t=205.0), 'ill')
    mi = [r for r in ill if r['hero'] == 'a']
    chk('GH #176 decoy: an illusion is not an ally',
        mi and all(r['L_alone'] for r in mi) and mi[0]['n_ally'] == 1,
        'n_ally=%s' % (mi[0]['n_ally'] if mi else '-'))

    # --- the shot window is a window, not "any time in the game" ---------
    _, late = rows_for(build(shot_t=260.0), 'late')
    ml = [r for r in late if r['hero'] == 'a' and r['t'] <= 210.0]
    chk('a shot 50 s later does not light up these frames',
        ml and not any(r['L_shot'] for r in ml))

    # --- the tower-actor filter ------------------------------------------
    tl_hero = build(shot_t=None)
    tl_hero['events'].append({'t': 205.0, 'type': 'DAMAGE',
                              'actor': 'npc_dota_hero_e',
                              'target': 'npc_dota_hero_a',
                              'inflictor': 'x', 'value': 60,
                              'actor_hero': True, 'target_hero': True})
    _, hb = rows_for(tl_hero, 'herohit')
    mh = [r for r in hb if r['hero'] == 'a']
    chk('a HERO hitting him is not a tower shot',
        mh and not any(r['L_shot'] for r in mh))
    tl_creep = build(shot_t=None)
    tl_creep['events'].append({'t': 205.0, 'type': 'DAMAGE',
                               'actor': 'npc_dota_badguys_tower1_mid',
                               'target': 'npc_dota_creep_goodguys_melee',
                               'inflictor': 'x', 'value': 60,
                               'actor_hero': False, 'target_hero': False})
    _, cb = rows_for(tl_creep, 'creephit')
    mc = [r for r in cb if r['hero'] == 'a']
    chk('the tower shooting a CREEP is not a shot at him',
        mc and not any(r['L_shot'] for r in mc))

    # --- deaths: the illusion corroboration guard ------------------------
    tl_d = build(shot_t=None)
    tl_d['events'].append({'t': 205.0, 'type': 'DEATH',
                           'actor': 'npc_dota_hero_e',
                           'target': 'npc_dota_hero_a', 'inflictor': 'x',
                           'value': 1, 'actor_hero': True,
                           'target_hero': True})
    chk('an illusion "death" with the hero still walking is DROPPED',
        hero_deaths(tl_d) == [], str(hero_deaths(tl_d)))
    tl_d2 = build(shot_t=None)
    tl_d2['snapshots'] = [s for s in tl_d2['snapshots']
                          if not (s['hero'] == 'npc_dota_hero_a'
                                  and 205.0 < s['t'] <= 240.0)]
    tl_d2['events'].append({'t': 205.0, 'type': 'DEATH',
                            'actor': 'npc_dota_hero_e',
                            'target': 'npc_dota_hero_a', 'inflictor': 'x',
                            'value': 1, 'actor_hero': True,
                            'target_hero': True})
    hd = hero_deaths(tl_d2)
    chk('a real death (snapshot chain stops) is KEPT',
        len(hd) == 1 and hd[0][0] == 'a', str(hd))
    chk('level at death reads the last living frame',
        level_at(tl_d2, 'a', 205.0) == 8, str(level_at(tl_d2, 'a', 205.0)))

    # --- constants match the source --------------------------------------
    chk('CALIB_LEVEL is one narrower than the block cap',
        CALIB_LEVEL == LEVEL_CAP - 1, '%d vs %d' % (CALIB_LEVEL, LEVEL_CAP))
    chk('the released band is exactly the halved clock',
        ARMED_CLOCK == SHIPPED_CLOCK / 2.0)
    chk('attack range is strictly inside the ring',
        TOWER_ATTACK_RANGE_U < RING_U)
    chk('ally radius equals the list radius at :773',
        ALLY_R_U == CTX_U == 1600.0)
    return ok[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--ring', type=float, default=RING_U)
    ap.add_argument('--require-cand', default='towerfear')
    ap.add_argument('--out', default='/tmp/towerfear_catch_rows.jsonl')
    a = ap.parse_args()

    if a.selfcheck:
        print('selfcheck:')
        good = selfcheck()
        print('selfcheck: %s' % ('ALL PASS' if good else 'FAILURES'))
        if not a.sweeps:
            return 0 if good else 1
        if not good:
            return 1

    rows, deaths = [], []
    hero_games = defaultdict(int)
    cands = set()
    n_games = 0
    for d in a.sweeps:
        for m in load_sweep(d):
            cands.add(m['cand'])
            tl_path = os.path.join(d, 'timelines',
                                   m['game'] + '.timeline.json')
            if not os.path.exists(tl_path):
                print('[warn] missing timeline %s' % tl_path, file=sys.stderr)
                continue
            timeline = json.load(open(tl_path))
            g = Game(tl_path, m['side'])
            key = os.path.basename(d.rstrip('/')) + '/' + m['game']
            game_key(g, key)
            n_games += 1
            st = stratum(m['side'])
            for h in g.teams:
                hero_games[(st, g.leg(h))] += 1
            rows.extend(released_frames(g, timeline, a.ring, key, st))
            for dr in death_rows(g, timeline):
                dr['stratum'] = st
                deaths.append(dr)

    if a.require_cand and cands:
        armed = [c for c in cands if a.require_cand in c.split(',')]
        print('manifest: %d distinct cand string(s); %d arm %r'
              % (len(cands), len(armed), a.require_cand))
        if not armed:
            sys.exit('[fatal] no swept game arms %r -- wrong wave?'
                     % a.require_cand)

    if not n_games:
        print('no sweep dirs given; nothing to read')
        return 0

    print('corpus: %d games, %d released frames, %d in-window deaths'
          % (n_games, len(rows), len(deaths)))
    catch_table(rows)
    death_table(deaths, hero_games, a.ring)
    with open(a.out, 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')
    print('\nreleased frames -> %s (%d)' % (a.out, len(rows)))
    dpath = a.out.replace('.jsonl', '_deaths.jsonl')
    with open(dpath, 'w') as f:
        for r in deaths:
            f.write(json.dumps(r) + '\n')
    print('in-window deaths -> %s (%d)' % (dpath, len(deaths)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
