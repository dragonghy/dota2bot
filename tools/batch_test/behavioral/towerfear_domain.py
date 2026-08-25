#!/usr/bin/env python3
"""towerfear (soak-candidate) condition-(a) domain reader.

WHAT THE LEVER IS
-----------------
`bots/mode_retreat_generic.lua:906-914`, inside `X.ShouldRun()`:

    if botLevel <= 10 and DotaTime() > 0
       and (#hEnemyHeroList > 0 or bot:GetHealth() < 800) then
        ...
        local nFearClock = 5 * 60
        if J.IsSoakCandidate('towerfear') and J.IsModeTurbo() then
            nFearClock = nFearClock / 2          -- <-- the ONE lever
        end
        if (botLevel <= 5 or DotaTime() < nFearClock)
           and nEnemyTowers[1] ~= nil then
            return 2;
        end

`nEnemyTowers = bot:GetNearbyTowers(898, true)` (`:823`; LANE_MID overrides it
to 980 at `:883`).  A non-zero `ShouldRun()` return is latched upstream into
`BOT_MODE_DESIRE_ABSOLUTE * 1.1` for that many seconds
(`GetDesireHelper`, `:498-503`) -- i.e. a 2 s forced retreat that outbids
every other mode.

So the armed predicate is a strict SUBSET of the shipped one, and the frames
it releases form a RECTANGLE in (game-time, hero-level) space:

    R_lever :  level 6..10   and  150 s <= t < 300 s

Everything adjacent is untouched by construction, which gives three negative
controls that cost nothing extra:

    C_pre   :  level 6..10   and    0 s <= t < 150 s   (clock leg true in BOTH)
    C_low   :  level <= 5    and  150 s <= t < 300 s   (level leg true in BOTH)
    C_post  :  level 6..10   and  300 s <= t < 450 s   (BOTH legs released)

WORKING means: on the armed leg the released rectangle shows MORE time spent
inside the 898 u enemy-tower ring (and less of the latch's retreat signature),
while all three controls stay put.  A shift that also shows up in the controls
is not this lever -- it is the wave's other 27 ids, or noise.

WHAT IS OBSERVABLE AND WHAT IS NOT
----------------------------------
Observable from the dump: hero position/level/hp per second, every tower's
position and `alive` flag every 5 s, every hero's position (hence a geometric
"enemy within 1600 u").

NOT observable: the bot's active mode, its vision, `GetAssignedLane()`.  So

  * the gate context `#hEnemyHeroList > 0` is read GEOMETRICALLY (any living
    enemy hero within 1600 u).  That is a SUPERSET of the engine's list, which
    is vision-filtered -- it can only make the domain too big, never too small.
    `bot:GetHealth() < 800` is read exactly (`snapshots[].hp` is absolute).
  * the ring radius is 898 u for every hero; the mid-lane 980 u variant is
    reported as a sensitivity, not mixed in.

Per GH #148 (i) every reading is given in BOTH physical strata (ab = candidate
armed on radiant, ba = candidate armed on dire) plus the balanced estimator
(ab+ba)/2; per (ii) the small-integer counts are reported as mean + a share,
never as a bare median.

Read-only.  Touches no AWS resource.
"""
import argparse
import json
import math
import os
import sys
from collections import defaultdict

RADIANT, DIRE = 2, 3

RING_U = 898.0          # mode_retreat_generic.lua:823
RING_MID_U = 980.0      # mode_retreat_generic.lua:883 (LANE_MID override)
CTX_U = 1600.0          # J.GetEnemyList(bot, 1600) at :772
CTX_HP = 800.0          # bot:GetHealth() < 800 at :877
LEVEL_CAP = 10          # botLevel <= 10 at :876
LEVEL_LEG = 5           # botLevel <= 5 at :910
SHIPPED_CLOCK = 300.0   # 5 * 60
ARMED_CLOCK = 150.0     # halved under the candidate
POST_HI = 450.0         # C_post upper edge (same 150 s width as R_lever)
BOUNCE_S = 3.0          # "did the latch throw him out" window (latch is 2 s)
# A hero who moves further than this in one game-second did not WALK there.
# Deliberately far above any real movement: GH #169 measured 772 u/s of
# ordinary buffed marching against a 660 u/s "walk cap" and lost a whole
# corpus to it, so this guard is set to separate walking from TELEPORTING
# (a TP home is ~10,000 u in one step), not to fence movement.
TELEPORT_U = 2000.0

RECTS = ('R_lever', 'C_pre', 'C_low', 'C_post')


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def rect_of(t, level):
    """Which analysis rectangle this frame falls in, or None.

    Disjoint by construction: the level split (<=5 vs 6..10) and the time
    split ([0,150) / [150,300) / [300,450)) are both partitions.
    """
    if t <= 0 or level > LEVEL_CAP:
        return None
    if level > LEVEL_LEG:
        if t < ARMED_CLOCK:
            return 'C_pre'
        if t < SHIPPED_CLOCK:
            return 'R_lever'
        if t < POST_HI:
            return 'C_post'
        return None
    if ARMED_CLOCK <= t < SHIPPED_CLOCK:
        return 'C_low'
    return None


class Game(object):
    def __init__(self, tl_path, armed_side):
        d = json.load(open(tl_path))
        self.teams = {h: t for h, t in d['game']['teams'].items()}
        self.armed_team = RADIANT if armed_side == 'radiant' else DIRE
        self.snaps = d['snapshots']
        # towers: one bucket per building sample time, per team, alive only.
        # Buildings are sampled every 5 s, heroes every 1 s -- a hero frame
        # uses the LAST building sample at or before it (a tower that fell at
        # t is treated as standing for at most 5 s afterwards; that direction
        # is the conservative one for a "did he stay in the ring" reading).
        self.btimes = []
        self.towers = {}
        by_t = defaultdict(lambda: {RADIANT: [], DIRE: []})
        for b in d.get('buildings', ()):
            if b.get('name') != 'tower':
                continue
            if b.get('alive'):
                by_t[b['t']][b['team']].append((b['x'], b['y']))
        for t in sorted(by_t):
            self.btimes.append(t)
            self.towers[t] = by_t[t]
        self.raw_buildings = d.get('buildings', ())

    def leg(self, hero):
        return 'armed' if self.teams.get(hero) == self.armed_team else 'baseline'

    def _tower_bucket(self, t):
        # last building sample <= t (bisect by hand; btimes is small)
        lo, hi = 0, len(self.btimes) - 1
        if hi < 0 or t < self.btimes[0]:
            return None
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.btimes[mid] <= t:
                lo = mid
            else:
                hi = mid - 1
        return self.towers[self.btimes[lo]]

    def nearest_enemy_tower(self, t, team, x, y):
        buck = self._tower_bucket(t)
        if buck is None:
            return None
        foe = DIRE if team == RADIANT else RADIANT
        best = None
        for tx, ty in buck[foe]:
            dd = dist(x, y, tx, ty)
            if best is None or dd < best:
                best = dd
        return best

    def frames(self):
        """Per-frame rows carrying everything the rectangles need."""
        by_t = defaultdict(list)
        for s in self.snaps:
            by_t[s['t']].append(s)
        rows = []
        for t in sorted(by_t):
            here = by_t[t]
            for s in here:
                lvl = s.get('level', 0)
                r = rect_of(t, lvl)
                if r is None:
                    continue
                if s.get('hp', 0) <= 0:
                    continue                       # dead: no decision to make
                dt = self.nearest_enemy_tower(t, s['team'], s['x'], s['y'])
                if dt is None:
                    continue
                foe_near = False
                for o in here:
                    if o['team'] == s['team'] or o.get('hp', 0) <= 0:
                        continue
                    if dist(s['x'], s['y'], o['x'], o['y']) <= CTX_U:
                        foe_near = True
                        break
                rows.append({
                    't': t, 'hero': s['hero'], 'team': s['team'],
                    'level': lvl, 'rect': r, 'd_tower': dt,
                    'x': s['x'], 'y': s['y'],
                    'ctx': foe_near or s.get('hp', 0) < CTX_HP,
                    'leg': self.leg(s['hero']),
                })
        return rows


def stratum(side):
    return 'ab' if side == 'radiant' else 'ba'


def episodes_from(rows, ring):
    """Entries into the ring, per (game, hero), within one rectangle.

    An episode = a maximal run of consecutive in-ring frames.  `dwell` is its
    length in seconds; `d3` is (distance 3 s after the entry frame) minus
    (distance at the entry frame) -- the latch's retreat signature, positive
    when the hero is being pushed back out.

    DEATH IS NOT AN EXIT.  `Game.frames()` drops dead frames, so a hero who
    dies inside the ring leaves a HOLE in the row sequence, and the next row
    is his respawn at the fountain.  Read naively that hole says "left the
    ring in 1 s and is now 10,802 u away" -- measured, on
    `364fb1/003056_slot11 lina t=243.5`, whose raw `d3` was +10,802 u, i.e.
    one death outweighed every real retreat in the corpus put together, and
    it landed on the BASELINE leg (the direction that flatters the lever).
    So an episode whose end or whose +3 s frame is not covered by an unbroken
    1 s chain of living frames is marked `closed='gap'` and contributes to
    neither `d3` nor the bounce rate; it still counts as an entry and still
    carries its (lower-bound) dwell.
    """
    def contiguous(a, b):
        """Same hero, next sample, and he WALKED there.

        Two ways the frame chain lies about a retreat: a death (the dead
        frames are dropped, leaving a hole) and a TP home (no hole at all --
        every frame alive, hp climbing, and the hero 11,000 u away one second
        later).  Measured: `364fb1/003056_slot11 lina t=243.5` is the second
        kind, +10,802 u of "retreat" on the BASELINE leg from one TP scroll.
        """
        dt = b['t'] - a['t']
        if not (0 < dt <= 1.5):
            return False
        return dist(a['x'], a['y'], b['x'], b['y']) <= TELEPORT_U * dt

    out = []
    by = defaultdict(list)
    for r in rows:
        by[(r['key'], r['hero'], r['rect'])].append(r)
    for k, rs in by.items():
        rs.sort(key=lambda r: r['t'])
        i = 0
        while i < len(rs):
            if not (rs[i]['d_tower'] <= ring and rs[i]['ctx']):
                i += 1
                continue
            j = i
            while (j + 1 < len(rs) and contiguous(rs[j], rs[j + 1])
                   and rs[j + 1]['d_tower'] <= ring and rs[j + 1]['ctx']):
                j += 1
            entry = rs[i]
            # the episode closed cleanly only if the very next frame exists,
            # follows within one sample step, and is reachable on foot
            # (otherwise: death, TP, or the rectangle/game ended under him)
            if j + 1 >= len(rs):
                closed = 'edge'          # rectangle or game ended under him
            elif rs[j + 1]['t'] - rs[j]['t'] > 1.5:
                closed = 'death'         # dead frames were dropped: a hole
            elif not contiguous(rs[j], rs[j + 1]):
                closed = 'tp'            # alive, next frame a map away
            else:
                closed = 'exit'
            d3 = None
            if closed == 'exit':
                prev = entry
                for r in rs[i + 1:]:
                    if not contiguous(prev, r):
                        break              # hole or teleport: not a retreat
                    prev = r
                    if abs(r['t'] - (entry['t'] + BOUNCE_S)) <= 0.75:
                        d3 = r['d_tower'] - entry['d_tower']
                        break
            dwell = rs[j]['t'] - entry['t'] + 1.0
            out.append({
                'key': k[0], 'hero': k[1], 'rect': k[2], 'leg': entry['leg'],
                'stratum': entry['stratum'], 't': entry['t'],
                'dwell': dwell, 'd3': d3, 'closed': closed,
                'bounced': (dwell <= BOUNCE_S) if closed == 'exit' else None,
            })
            i = j + 1
    return out


def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


def fmt(v, nd=2):
    return '-' if v is None else ('%.*f' % (nd, v))


def tabulate(rows, eps, ring):
    """(rect, stratum, leg) -> the four readings, plus balanced estimators."""
    occ = defaultdict(lambda: [0, 0])       # in-ring frames, rectangle frames
    hero_games = defaultdict(set)
    for r in rows:
        k = (r['rect'], r['stratum'], r['leg'])
        occ[k][1] += 1
        if r['d_tower'] <= ring and r['ctx']:
            occ[k][0] += 1
        hero_games[k].add((r['key'], r['hero']))
    ep = defaultdict(list)
    for e in eps:
        ep[(e['rect'], e['stratum'], e['leg'])].append(e)

    print()
    print('ring %d u   [in-ring frames need the gate context too: '
          'enemy <=1600 u or hp<800]' % ring)
    hdr = ('%-8s %-3s %-9s %7s %8s %8s %8s %7s %7s %7s %6s %5s' %
           ('rect', 'str', 'leg', 'heroGm', 'occ%', 'ent/100', 'dwell',
            'd+3s', 'bnc%', 'dth%', 'nEp', 'gap'))
    print(hdr)
    print('-' * len(hdr))
    table = {}
    for rect in RECTS:
        for st in ('ab', 'ba'):
            for leg in ('armed', 'baseline'):
                k = (rect, st, leg)
                inr, tot = occ[k]
                hg = len(hero_games[k])
                es = ep[k]
                clean = [e for e in es if e['closed'] == 'exit']
                row = {
                    'occ': 100.0 * inr / tot if tot else None,
                    'ent': 100.0 * len(es) / hg if hg else None,
                    'dwell': mean([e['dwell'] for e in es]),
                    'd3': mean([e['d3'] for e in es]),
                    'bnc': (100.0 * sum(1 for e in clean if e['bounced'])
                            / len(clean) if clean else None),
                    'dth': (100.0 * sum(1 for e in es
                                        if e['closed'] == 'death') / len(es)
                            if es else None),
                    'n_ep': len(es), 'hg': hg, 'frames': tot,
                    'gap': len(es) - len(clean),
                }
                table[k] = row
                print('%-8s %-3s %-9s %7d %8s %8s %8s %7s %7s %7s %6d %5d' %
                      (rect, st, leg, hg, fmt(row['occ']), fmt(row['ent'], 1),
                       fmt(row['dwell']), fmt(row['d3'], 0), fmt(row['bnc'], 1),
                       fmt(row['dth'], 1), row['n_ep'], row['gap']))
        print('-' * len(hdr))
    print()
    print('balanced armed-minus-baseline  (ab+ba)/2, and each stratum alone')
    hdr2 = ('%-8s %-14s %9s %9s %9s' %
            ('rect', 'metric', 'ab', 'ba', 'balanced'))
    print(hdr2)
    print('-' * len(hdr2))
    deltas = {}
    for rect in RECTS:
        for m in ('occ', 'ent', 'dwell', 'd3', 'bnc', 'dth'):
            per = {}
            for st in ('ab', 'ba'):
                a = table[(rect, st, 'armed')][m]
                b = table[(rect, st, 'baseline')][m]
                per[st] = None if (a is None or b is None) else a - b
            bal = (None if per['ab'] is None or per['ba'] is None
                   else (per['ab'] + per['ba']) / 2.0)
            deltas[(rect, m)] = (per['ab'], per['ba'], bal)
            same = (per['ab'] is not None and per['ba'] is not None
                    and per['ab'] * per['ba'] > 0)
            print('%-8s %-14s %9s %9s %9s %s' %
                  (rect, m, fmt(per['ab'], 2), fmt(per['ba'], 2),
                   fmt(bal, 2), 'both-strata' if same else 'SIGN-SPLIT'))
        print('-' * len(hdr2))
    return table, deltas


# ---------------------------------------------------------------- selfcheck

def _synth_game(shift_armed=0.0, level=8, tlo=151, thi=299):
    """A hand-built two-hero game: one armed, one baseline, mirrored geometry.

    `shift_armed` moves the armed hero that many units CLOSER to the enemy
    tower inside the window, so a positive shift must read as positive occ.
    """
    tower_r = (0.0, 0.0)          # radiant tower (enemy of the dire hero)
    tower_d = (10000.0, 0.0)      # dire tower   (enemy of the radiant hero)
    snaps, builds = [], []
    for t in [x * 5.0 for x in range(-14, 121)]:
        for (nm, tm, xy) in (('t_r', RADIANT, tower_r), ('t_d', DIRE, tower_d)):
            builds.append({'t': t, 'name': 'tower', 'team': tm,
                           'x': xy[0], 'y': xy[1], 'hp': 1, 'hp_pct': 1,
                           'alive': True})
    for t in [x * 1.0 for x in range(-60, 500)]:
        inwin = tlo <= t <= thi
        # radiant hero (armed), 950 u from the dire tower, closes by the shift
        dr = 950.0 - (shift_armed if inwin else 0.0)
        snaps.append({'t': t, 'hero': 'npc_dota_hero_a', 'team': RADIANT,
                      'x': tower_d[0] - dr, 'y': 0.0, 'hp': 1000, 'level': level,
                      'items': []})
        # dire hero (baseline), mirrored, never moves
        snaps.append({'t': t, 'hero': 'npc_dota_hero_b', 'team': DIRE,
                      'x': tower_r[0] + 950.0, 'y': 0.0, 'hp': 1000,
                      'level': level, 'items': []})
        # one enemy of each, parked 1000 u away so the gate context holds
        snaps.append({'t': t, 'hero': 'npc_dota_hero_c', 'team': DIRE,
                      'x': tower_d[0] - dr, 'y': 1000.0, 'hp': 1000,
                      'level': level, 'items': []})
        snaps.append({'t': t, 'hero': 'npc_dota_hero_d', 'team': RADIANT,
                      'x': tower_r[0] + 950.0, 'y': 1000.0, 'hp': 1000,
                      'level': level, 'items': []})
    return {'game': {'teams': {'npc_dota_hero_a': RADIANT,
                              'npc_dota_hero_c': DIRE,
                              'npc_dota_hero_b': DIRE,
                              'npc_dota_hero_d': RADIANT},
                     'start_time': 0, 'vision_note': ''},
            'snapshots': snaps, 'buildings': builds, 'creeps': [],
            'events': [], 'wards': []}


def _rows_for(tl_dict, side, key, tmp):
    p = os.path.join(tmp, key + '.json')
    with open(p, 'w') as f:
        json.dump(tl_dict, f)
    g = Game(p, side)
    rows = g.frames()
    for r in rows:
        r['key'] = key
        r['stratum'] = stratum(side)
    return g, rows


def selfcheck(real_games):
    import tempfile
    ok = [True]

    def chk(name, cond, detail=''):
        print('  %-46s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok[0] = ok[0] and bool(cond)

    tmp = tempfile.mkdtemp(prefix='towerfear_sc_')

    # --- rectangle algebra ------------------------------------------------
    chk('rect: level 6..10 @ t=200 is the lever',
        rect_of(200, 8) == 'R_lever', rect_of(200, 8))
    chk('rect: level 5 @ t=200 is a control (level leg)',
        rect_of(200, 5) == 'C_low', rect_of(200, 5))
    chk('rect: level 8 @ t=100 is a control (both clocks true)',
        rect_of(100, 8) == 'C_pre', rect_of(100, 8))
    chk('rect: level 8 @ t=350 is a control (both released)',
        rect_of(350, 8) == 'C_post', rect_of(350, 8))
    chk('rect: level 11 is outside the whole clause',
        rect_of(200, 11) is None, rect_of(200, 11))
    chk('rect: t<=0 excluded (DotaTime() > 0)',
        rect_of(0, 8) is None and rect_of(-30, 8) is None)
    chk('rect: edges are half-open, no frame in two rects',
        rect_of(150, 8) == 'R_lever' and rect_of(149.9, 8) == 'C_pre'
        and rect_of(300, 8) == 'C_post' and rect_of(299.9, 8) == 'R_lever')
    chk('rect: constants match the source (150 = 300/2)',
        ARMED_CLOCK == SHIPPED_CLOCK / 2 and SHIPPED_CLOCK == 5 * 60)

    # --- positive control: an injected shift must be recovered -------------
    g1, r1 = _rows_for(_synth_game(shift_armed=100.0), 'radiant', 'g1', tmp)
    e1 = episodes_from(r1, RING_U)
    lev = [x for x in r1 if x['rect'] == 'R_lever']
    a_in = sum(1 for x in lev if x['leg'] == 'armed' and x['d_tower'] <= RING_U)
    b_in = sum(1 for x in lev if x['leg'] == 'baseline'
               and x['d_tower'] <= RING_U)
    chk('synthetic: armed steps inside the ring, baseline does not',
        a_in > 100 and b_in == 0, 'armed=%d baseline=%d' % (a_in, b_in))
    pre = [x for x in r1 if x['rect'] == 'C_pre' and x['d_tower'] <= RING_U]
    chk('synthetic: the control rectangle stays empty',
        len(pre) == 0, 'C_pre in-ring frames=%d' % len(pre))
    chk('synthetic: exactly one episode on the armed leg',
        len([e for e in e1 if e['leg'] == 'armed'
             and e['rect'] == 'R_lever']) == 1,
        '%d' % len([e for e in e1 if e['leg'] == 'armed']))

    # --- negative control: identical legs must read ~0 ---------------------
    g0, r0 = _rows_for(_synth_game(shift_armed=0.0), 'radiant', 'g0', tmp)
    lev0 = [x for x in r0 if x['rect'] == 'R_lever']
    a0 = sum(1 for x in lev0 if x['leg'] == 'armed' and x['d_tower'] <= RING_U)
    b0 = sum(1 for x in lev0 if x['leg'] == 'baseline'
             and x['d_tower'] <= RING_U)
    chk('null: identical legs give an identical reading',
        a0 == b0 == 0, 'armed=%d baseline=%d' % (a0, b0))

    # --- the stratum label is not the leg label ---------------------------
    gD, rD = _rows_for(_synth_game(shift_armed=100.0), 'dire', 'gD', tmp)
    dl = {x['leg'] for x in rD if x['team'] == DIRE}
    chk('side=dire flips which team is the armed leg',
        dl == {'armed'}, str(dl))
    chk('side=dire lands in the ba stratum',
        {x['stratum'] for x in rD} == {'ba'})

    # --- retreat signature: d+3s is signed the way the latch would push ----
    def _drift(sign):
        tl = _synth_game(shift_armed=100.0)
        for s in tl['snapshots']:
            if s['hero'] == 'npc_dota_hero_a' and 151 <= s['t'] <= 299:
                s['x'] -= sign * 40.0 * (s['t'] - 151)   # walk away / closer
        return tl
    _, rout = _rows_for(_drift(+1), 'radiant', 'gOut', tmp)
    eout = [e for e in episodes_from(rout, RING_U)
            if e['leg'] == 'armed' and e['rect'] == 'R_lever']
    chk('d+3s is POSITIVE when the hero is pushed out',
        eout and eout[0]['d3'] is not None and eout[0]['d3'] > 60,
        fmt(eout[0]['d3'], 0) if eout else 'no episode')
    _, rin = _rows_for(_drift(-1), 'radiant', 'gIn', tmp)
    ein = [e for e in episodes_from(rin, RING_U)
           if e['leg'] == 'armed' and e['rect'] == 'R_lever']
    chk('d+3s is NEGATIVE when the hero dives further in',
        ein and ein[0]['d3'] is not None and ein[0]['d3'] < -60,
        fmt(ein[0]['d3'], 0) if ein else 'no episode')

    # --- gate context has teeth ------------------------------------------
    tl = _synth_game(shift_armed=100.0)
    tl['snapshots'] = [s for s in tl['snapshots']
                       if s['hero'] not in ('npc_dota_hero_c',
                                            'npc_dota_hero_d')]
    tl['game']['teams'] = {k: v for k, v in tl['game']['teams'].items()
                           if k not in ('npc_dota_hero_c', 'npc_dota_hero_d')}
    _, rno = _rows_for(tl, 'radiant', 'gNoCtx', tmp)
    ctx_on = sum(1 for x in rno if x['ctx'])
    chk('no enemy within 1600 u and hp>=800 -> context false',
        ctx_on == 0, '%d frames still ctx-true' % ctx_on)
    tl2 = _synth_game(shift_armed=100.0)
    tl2['snapshots'] = [s for s in tl2['snapshots']
                        if s['hero'] not in ('npc_dota_hero_c',
                                             'npc_dota_hero_d')]
    tl2['game']['teams'] = {k: v for k, v in tl2['game']['teams'].items()
                            if k not in ('npc_dota_hero_c', 'npc_dota_hero_d')}
    for s in tl2['snapshots']:
        s['hp'] = 700
    _, rhp = _rows_for(tl2, 'radiant', 'gHp', tmp)
    chk('hp<800 alone re-opens the context (the OR leg)',
        all(x['ctx'] for x in rhp), '')

    # --- dead frames are not decisions -----------------------------------
    tl3 = _synth_game(shift_armed=100.0)
    for s in tl3['snapshots']:
        if s['hero'] == 'npc_dota_hero_a' and 200 <= s['t'] <= 220:
            s['hp'] = 0
    _, rdead = _rows_for(tl3, 'radiant', 'gDead', tmp)
    dead = [x for x in rdead
            if x['hero'] == 'npc_dota_hero_a' and 200 <= x['t'] <= 220]
    chk('hp==0 frames are dropped', len(dead) == 0, '%d kept' % len(dead))

    # --- REGRESSION: a death inside the ring must not read as a retreat ---
    # Measured on 364fb1/003056_slot11 lina t=243.5: the naive reader called
    # that death a +10,802 u push-out, on the baseline leg.
    tl4 = _synth_game(shift_armed=100.0)
    for s in tl4['snapshots']:
        if s['hero'] == 'npc_dota_hero_a' and 200 <= s['t'] < 210:
            s['hp'] = 0                      # dies inside the ring at t=200
        elif s['hero'] == 'npc_dota_hero_a' and s['t'] >= 210:
            s['x'], s['y'] = -6700.0, -6700.0        # respawns at fountain
    _, rd4 = _rows_for(tl4, 'radiant', 'gDeath', tmp)
    e4 = [e for e in episodes_from(rd4, RING_U)
          if e['leg'] == 'armed' and e['rect'] == 'R_lever']
    died = [e for e in e4 if e['t'] < 200 <= e['t'] + e['dwell']]
    chk('death-truncated episode is marked closed=death',
        died and all(e['closed'] == 'death' for e in died),
        str([e['closed'] for e in died]))
    chk('death-truncated episode contributes no d+3s',
        died and all(e['d3'] is None for e in died),
        str([e['d3'] for e in died]))
    chk('death-truncated episode contributes no bounce',
        died and all(e['bounced'] is None for e in died),
        str([e['bounced'] for e in died]))
    huge = [e for e in e4 if e['d3'] is not None and abs(e['d3']) > 5000]
    chk('no fountain-sized d+3s survives anywhere',
        not huge, '%d such episodes' % len(huge))
    # --- REGRESSION: a TP home inside the ring is not a retreat either ----
    # Measured on 364fb1/003056_slot11 lina t=243.5-246.5: hp 390 -> 444 and
    # climbing, level unchanged, no dead frame anywhere -- and 11,625 u from
    # the tower one second later.  The death guard above cannot see this one.
    tl6 = _synth_game(shift_armed=100.0)
    for s in tl6['snapshots']:
        if s['hero'] == 'npc_dota_hero_a' and s['t'] >= 200:
            s['x'], s['y'] = -6700.0, -6700.0        # TP home, still alive
    _, rd6 = _rows_for(tl6, 'radiant', 'gTp', tmp)
    e6 = [e for e in episodes_from(rd6, RING_U)
          if e['leg'] == 'armed' and e['rect'] == 'R_lever']
    chk('TP-home-truncated episode is closed=tp, not death',
        e6 and all(e['closed'] == 'tp' for e in e6),
        str([e['closed'] for e in e6]))
    chk('TP home contributes no d+3s and no bounce',
        e6 and all(e['d3'] is None and e['bounced'] is None for e in e6),
        str([(e['d3'], e['bounced']) for e in e6]))
    chk('teleport guard is far above real movement (GH #169)',
        TELEPORT_U > 2 * 772.0, 'cap=%.0f u/s' % TELEPORT_U)
    # a 700 u/s sprint (buffed marching, #169's measured 772 u/s neighbourhood)
    # must NOT be mistaken for a teleport
    tl7 = _synth_game(shift_armed=100.0)
    for s in tl7['snapshots']:
        if s['hero'] == 'npc_dota_hero_a' and 200 <= s['t'] <= 299:
            s['x'] -= 700.0 * (s['t'] - 200)
    _, rd7 = _rows_for(tl7, 'radiant', 'gSprint', tmp)
    e7 = [e for e in episodes_from(rd7, RING_U)
          if e['leg'] == 'armed' and e['rect'] == 'R_lever']
    chk('a 700 u/s sprint out still closes as exit',
        e7 and e7[0]['closed'] == 'exit', str([e['closed'] for e in e7[:2]]))

    # ... and a clean exit in the same shape still reads normally
    tl5 = _synth_game(shift_armed=100.0)
    for s in tl5['snapshots']:
        if s['hero'] == 'npc_dota_hero_a' and s['t'] >= 200:
            s['x'] -= 400.0            # walks AWAY from the tower, never dies
    _, rd5 = _rows_for(tl5, 'radiant', 'gExit', tmp)
    e5 = [e for e in episodes_from(rd5, RING_U)
          if e['leg'] == 'armed' and e['rect'] == 'R_lever']
    chk('a real walk-out still closes as exit',
        e5 and e5[0]['closed'] == 'exit' and e5[0]['bounced'] is not None,
        str([(e['closed'], e['bounced']) for e in e5[:2]]))

    # --- real-corpus invariants ------------------------------------------
    if real_games:
        g = real_games[0][0]
        first = g.btimes[0]
        n_r = len(g.towers[first][RADIANT])
        n_d = len(g.towers[first][DIRE])
        chk('11 towers a side at the first building sample',
            n_r == 11 and n_d == 11, 'r=%d d=%d' % (n_r, n_d))
        # a tower never comes back to life
        seen_dead = set()
        resurrect = 0
        for b in g.raw_buildings:
            if b.get('name') != 'tower':
                continue
            k = (b['team'], round(b['x']), round(b['y']))
            if not b.get('alive'):
                seen_dead.add(k)
            elif k in seen_dead:
                resurrect += 1
        chk('no tower resurrects', resurrect == 0, '%d' % resurrect)
        legs = defaultdict(int)
        for entry in real_games:
            gg = entry[0]
            for h in gg.teams:
                legs[gg.leg(h)] += 1
        chk('legs balanced 5v5 across the corpus',
            legs['armed'] == legs['baseline'], dict(legs))
        # heroes start at their own fountain: far from every enemy tower
        early = [s for s in g.snaps if -60 <= s['t'] <= -50]
        far = [g.nearest_enemy_tower(s['t'], s['team'], s['x'], s['y'])
               for s in early]
        far = [x for x in far if x is not None]
        chk('pre-horn frames sit outside the ring',
            far and min(far) > RING_U, 'min=%s' % fmt(min(far), 0) if far
            else 'no frames')
        # the building sample step is the 5 s the reader assumes
        step = (g.btimes[1] - g.btimes[0]) if len(g.btimes) > 1 else None
        chk('building sample step is 5 s', step is not None
            and abs(step - 5.0) < 1e-6, 'step=%s' % step)
    return ok[0]


def load_sweep(d):
    """Charter #102 completeness sentinel: summary exists AND counts match."""
    mpath = os.path.join(d, 'games_manifest.jsonl')
    if not os.path.exists(mpath):
        sys.exit('[fatal] %s: no games_manifest.jsonl' % d)
    rows = [json.loads(l) for l in open(mpath) if l.strip()]
    spath = os.path.join(d, 'sweep_summary.md')
    if not os.path.exists(spath):
        sys.exit('[fatal] %s: no sweep_summary.md -- PARTIAL sweep (%d games)'
                 % (d, len(rows)))
    claimed = None
    for line in open(spath):
        if line.startswith('games swept:'):
            claimed = int(line.split(':', 1)[1].split('(')[0].strip())
            break
    if claimed is None or claimed != len(rows):
        sys.exit('[fatal] %s: summary says %s, manifest holds %d -- re-sweep'
                 % (d, claimed, len(rows)))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--ring', type=float, default=RING_U,
                    help='ring radius in units (898 default; 980 = the '
                         'LANE_MID override, run it as a sensitivity)')
    ap.add_argument('--require-cand', default='towerfear',
                    help='only sweep dirs whose manifest arms this id; '
                         'empty string disables the check (control waves)')
    ap.add_argument('--out', default='/tmp/towerfear_rows.jsonl')
    a = ap.parse_args()

    games, rows = [], []
    cands = set()
    for d in a.sweeps:
        for m in load_sweep(d):
            cands.add(m['cand'])
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            if not os.path.exists(tl):
                print('[warn] missing timeline %s' % tl, file=sys.stderr)
                continue
            g = Game(tl, m['side'])
            key = os.path.basename(d.rstrip('/')) + '/' + m['game']
            games.append((g, key, m['seed'], m['side']))
            for r in g.frames():
                r['key'] = key
                r['seed'] = m['seed']
                r['stratum'] = stratum(m['side'])
                rows.append(r)

    if a.require_cand and cands:
        armed = [c for c in cands if a.require_cand in c.split(',')]
        print('manifest: %d distinct cand string(s); %d arm %r'
              % (len(cands), len(armed), a.require_cand))
        if not armed:
            sys.exit('[fatal] no swept game arms %r -- wrong wave?'
                     % a.require_cand)

    if a.selfcheck:
        print('selfcheck:')
        good = selfcheck(games)
        print('selfcheck: %s' % ('ALL PASS' if good else 'FAILURES'))
        if not games:
            return 0 if good else 1
        if not good:
            return 1

    if not games:
        print('no sweep dirs given; nothing to read')
        return 0

    hero_games = len({(r['key'], r['hero']) for r in rows})
    print('corpus: %d games, %d hero-games, %d in-rectangle frames'
          % (len(games), hero_games, len(rows)))
    eps = episodes_from(rows, a.ring)
    tabulate(rows, eps, a.ring)
    with open(a.out, 'w') as f:
        for e in eps:
            f.write(json.dumps(e) + '\n')
    print('\nepisodes -> %s (%d)' % (a.out, len(eps)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
