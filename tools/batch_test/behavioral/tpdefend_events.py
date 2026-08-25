#!/usr/bin/env python3
"""Tower-defense TP responses on the EVENT axis (the `midsupyield` unlock bar).

WHY THIS FILE EXISTS
--------------------
Director ruling 2026-08-23T17:xxZ (`test_set.md` AX.5 item 3) made
`midsupyield`'s W6 slot conditional on one number that nobody had measured:

    "`J.ShouldTpSupportTowerFight` 的产出是一次离散的塔防响应,付款在事件轴
     => 发波前必须给出事件轴的量级(每局塔防 TP 响应次数、其中核心占几次)"

The application's own domain figure -- ~3/966 corpus FRAMES -- is on the frame
axis, and a lever whose payment is a discrete event cannot be sized by a frame
share (AX.2).  This reads the event axis off `.dem` corpora already bought,
so it costs nothing and launches nothing.

WHAT ONE EVENT IS
-----------------
One TP press that ANSWERS A FRONT: a self-targeted `modifier_teleporting`
channel whose LANDING sits beside a friendly tower that had, at the press
instant, both an enemy hero and another living ally inside 1200 u, with the
caster more than 3500 u away when he pressed.  Those three clauses are read
straight out of the helper (`jmz_func.lua:7759-7873`): `> 3500`,
`J.GetEnemiesNearLoc(vTower, 1200)`, `J.GetAlliesNearLoc(vTower, 1200)`.

THE LANDING IS WHAT MAKES IT AN ANSWER, not the press instant.  A press whose
preconditions happen to hold but that lands at the fountain is a home TP whose
timing coincided -- the same separation `tp_attribution.py` had to make to tell
11 real rescues from 9 lookalikes.  A press that never lands (killed
mid-channel) is reported separately and is NOT an answer: no response arrived.

TWO POPULATIONS, PRINTED SIDE BY SIDE, NEVER SUMMED
---------------------------------------------------
  ALL      -- every answered front, whichever code path cast it (the shipped
              defend logic, `lf_rescue`, the gated response branches).  This is
              the denominator the application's own NEGATIVE CONTROL is stated
              against ("total tower-defense TP responses must NOT collapse
              toward 0"), so it has to be measured on both legs before the wave,
              not after.
  HELPER-SHAPED -- ALL plus every gate of `ShouldTpSupportTowerFight` that the
              dump can actually decide: caster level >= 6, a ready TP at the
              press instant (`snapshots[].tp_cd == 0`), the HEAT gate (an ally
              at the front below 75% HP or damaged by an enemy hero within 3 s),
              and the 45 s / 1600 u REPEAT-FRONT memory.  This is the closest
              observable proxy for the helper's output and is a SUPERSET of it.

WHAT THE DUMP CANNOT DECIDE (stated up front, do not quietly assume it away)
----------------------------------------------------------------------------
`J.IsRetreating`, `J.IsGoingOnSomeone`, the bot's active mode, `SafeToCommitFight`
(it needs `GetEstimatedDamageToTarget`), `WillAllySurviveTpWindow`, and the team
quota `J.TryTakeTpResponseSlot` are none of them in the behavioural dump.  So
HELPER-SHAPED over-counts, and the honest reading of both numbers is
"the event axis is this big", never "the helper fired this often".
Vision is the standing GH #27 gap: enemy/ally proximity here is god's-eye.

WHY THE CORE SHARE IS THE POINT
-------------------------------
`midsupyield` can only REALLOCATE an answer from a core (pos 1-3) to a support
(pos >= 4); it can never drop one and never raises core participation.  So the
quantity the wave would have to move is the CORE SHARE of these events, and the
quantity that must not collapse is their TOTAL.  Both are printed per stratum.

Positions come from the seed draft (`seed_draft.positions_for_game`), never
from `team_slot % 5 + 1` -- GH #57/#116, that fallback was 47.3% accurate.

Per GH #148 (i) every reading is given in BOTH physical strata (ab = candidate
armed on radiant, ba = candidate armed on dire); per (ii) these small-integer
per-game counts are reported as mean plus the zero/one shares, never as a bare
median.

Read-only.  Consumes sweep_run.sh output.  Touches no billable AWS resource.
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'soak'))

from creeppull_domain import load_sweep            # noqa: E402
from tp_channel_death import canon, interp         # noqa: E402
import seed_draft                                  # noqa: E402

RADIANT, DIRE = 2, 3

# --- constants read out of J.ShouldTpSupportTowerFight (jmz_func.lua) --------
FRONT_R_U = 1200.0      # J.GetEnemiesNearLoc / GetAlliesNearLoc( vTower, 1200 )
FAR_U = 3500.0          # GetUnitToUnitDistance( bot, building ) > 3500
HEAT_HP = 0.75          # J.GetHP( ally ) < 0.75
HEAT_S = 3.0            # ally:WasRecentlyDamagedByAnyHero( 3.0 )
REPEAT_S = 45.0         # bRepeatFront window
REPEAT_U = 1600.0       # bRepeatFront radius
MIN_LEVEL = 6           # bot:GetLevel() < 6 -> nil
# DotaTime() - math.max(lastDeadFrameTime, lastRespawnTime) < 15.0 -> nil.
# Found by reading a census row frame by frame, not by the selfcheck:
# `20260825_002534_slot10 lina t=412.6` presses from the fountain 7 s after
# respawning, and without this clause the census called it helper-shaped.
# The respawn instant is not a field in the dump; the first LIVING frame after
# a DEATH event is the observable stand-in, and it is late rather than early
# (1 Hz sampling), so this refuses slightly too few rows, never too many.
RESPAWN_S = 15.0

# --- measurement constants (ours, not the rule's) ---------------------------
# The wiring casts to J.GetNearbyLocationToTp(tower), which offsets ~575 u off
# the tower toward the destination; 1600 u leaves room for that plus one second
# of walking after touchdown.  Deliberately generous: this bounds the domain,
# and an over-generous landing radius over-counts answers, which is the
# conservative direction for a "does this population even exist" reading.
LAND_U = 1600.0
TP_TAIL_S = 1.5         # stayfield_domain.py:139 -- channel end -> feet down
CHANNEL_MAX_S = 12.0    # give up pairing an ADD with a REMOVE beyond this
CORE_MAX_POS = 3        # J.IsCore: J.GetPosition(bot) <= 3


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


class Frames(object):
    """Per-hero snapshot tracks plus the 5 s building samples."""

    def __init__(self, timeline):
        self.tl = timeline
        self.tracks = collections.defaultdict(list)
        self.team = {}
        for s in timeline['snapshots']:
            h = canon(s['hero'])
            self.tracks[h].append(s)
            self.team[h] = s['team']
        for h in self.tracks:
            self.tracks[h].sort(key=lambda s: s['t'])
        self.btimes = []
        self.towers = {}
        by_t = collections.defaultdict(lambda: {RADIANT: [], DIRE: []})
        for b in timeline.get('buildings', ()):
            if b.get('name') != 'tower' or not b.get('alive'):
                continue
            by_t[b['t']][b['team']].append((b['x'], b['y']))
        for t in sorted(by_t):
            self.btimes.append(t)
            self.towers[t] = by_t[t]

    def own_towers(self, t, team):
        """Live towers of `team` from the last building sample at or before t.

        A tower that fell between samples is treated as standing for up to 5 s
        afterwards.  For this reading that direction ADDS candidate fronts, so
        it can only over-count answers -- same conservative direction as
        LAND_U above.
        """
        if not self.btimes or t < self.btimes[0]:
            return []
        lo, hi = 0, len(self.btimes) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.btimes[mid] <= t:
                lo = mid
            else:
                hi = mid - 1
        return self.towers[self.btimes[lo]][team]

    def at(self, hero, t):
        return interp(self.tracks[hero], t) if hero in self.tracks else None

    def tp_cd_at(self, hero, t):
        """`tp_cd` from the last frame at or before t (a step field, not linear).

        Interpolating a cooldown would invent fractional readiness; the press
        decision is made on the value the engine had, which is the last sample.
        """
        best = None
        for s in self.tracks.get(hero, ()):
            if s['t'] <= t and (best is None or s['t'] > best['t']):
                best = s
        return None if best is None else best.get('tp_cd')


def channels(timeline):
    """[(hero, t_press, t_end_or_None)] for every self-targeted TP channel."""
    adds = collections.defaultdict(list)
    rems = collections.defaultdict(list)
    for e in timeline['events']:
        if e.get('inflictor') != 'modifier_teleporting':
            continue
        if canon(e.get('target')) != canon(e.get('actor')):
            continue
        if e['type'] == 'MODIFIER_ADD':
            adds[canon(e['actor'])].append(e['t'])
        elif e['type'] == 'MODIFIER_REMOVE':
            rems[canon(e['actor'])].append(e['t'])
    out = []
    for h, ts in adds.items():
        rs = sorted(rems.get(h, ()))
        for t in sorted(ts):
            end = None
            for r in rs:
                if t < r <= t + CHANNEL_MAX_S:
                    end = r
                    break
            out.append((h, t, end))
    return out


def landing(fr, hero, t_press, t_end):
    """First frame with both feet down, or None if the channel never ended.

    A death mid-channel leaves the ADD with no REMOVE inside CHANNEL_MAX_S (or
    a REMOVE with the hero dead), and the very next living frame is a fountain
    respawn.  Neither is a landing, and calling one a landing would invent an
    answer out of a death -- the same hole `towerfear_domain.episodes_from`
    paid for with a +10,802 u phantom retreat.
    """
    if t_end is None:
        return None
    for s in fr.tracks.get(hero, ()):
        if s['t'] >= t_end + TP_TAIL_S:
            return s if s.get('hp_pct', 0) > 0 else None
    return None


def hero_damage_times(timeline):
    """{victim: [t of every hit taken FROM A HERO]} -- WasRecentlyDamagedByAnyHero."""
    out = collections.defaultdict(list)
    for e in timeline['events']:
        if e['type'] == 'DAMAGE' and e.get('actor_hero') and e.get('target_hero'):
            out[canon(e['target'])].append(e['t'])
    for k in out:
        out[k].sort()
    return out


def fresh_respawn(fr, deaths, hero, t):
    """Is the press inside the helper's 15 s post-respawn cooldown?"""
    prior = [td for td in deaths.get(hero, ()) if td < t]
    if not prior:
        return False
    td = max(prior)
    for s in fr.tracks.get(hero, ()):
        if s['t'] > td and s.get('hp_pct', 0) > 0:
            return (t - s['t']) < RESPAWN_S
    return False


def fronts_at(fr, hero, t, team):
    """Every friendly tower that looked like a fight at the press instant."""
    foe = DIRE if team == RADIANT else RADIANT
    me = fr.at(hero, t)
    if me is None:
        return []
    live = {}
    for h2 in fr.tracks:
        s = fr.at(h2, t)
        if s is not None and s['hp_pct'] > 0:
            live[h2] = s
    out = []
    for tx, ty in fr.own_towers(t, team):
        if dist(me['x'], me['y'], tx, ty) <= FAR_U:
            continue
        enemies, allies = [], []
        for h2, s in live.items():
            if dist(s['x'], s['y'], tx, ty) > FRONT_R_U:
                continue
            if fr.team.get(h2) == foe:
                enemies.append(h2)
            elif h2 != hero:
                allies.append((h2, s))
        if enemies and allies:
            out.append((tx, ty, enemies, allies))
    return out


def viable_support(fr, hero, t, team, positions):
    """Observable half of `J.HasAvailableSupportResponder` (jmz_func.lua:7716).

    Mirrors, clause by clause, what the dump can decide: another living hero on
    my team, pos >= 4, level >= 6, TP off cooldown.  `J.IsInTeamFight(hAlly,
    1600)` is read GEOMETRICALLY (no living enemy inside 1600 u of him), which
    is a superset of the engine's vision-filtered list and therefore refuses
    slightly too often -- the conservative direction for a "does the yield
    population exist" reading.  `J.IsRetreating` has no observable analogue at
    all and is simply not applied; it can only shrink this set further.

    So: True is a SUPERSET claim ("a support that looks available existed"),
    and the honest use is as an upper bound on how often `midsupyield` could
    have fired, never as a count of firings.
    """
    if not positions:
        return None
    foe = DIRE if team == RADIANT else RADIANT
    live = {}
    for h2 in fr.tracks:
        s = fr.at(h2, t)
        if s is not None and s['hp_pct'] > 0:
            live[h2] = s
    for h2, s in live.items():
        if h2 == hero or fr.team.get(h2) != team:
            continue
        if (positions.get(h2) or 0) < CORE_MAX_POS + 1:
            continue
        if s['level'] < MIN_LEVEL:
            continue
        if fr.tp_cd_at(h2, t) != 0:
            continue
        if any(fr.team.get(h3) == foe
               and dist(s['x'], s['y'], s3['x'], s3['y']) <= REPEAT_U
               for h3, s3 in live.items()):
            continue                       # geometric J.IsInTeamFight(., 1600)
        return True
    return False


def events_for_game(timeline, game, positions):
    """One row per ANSWERED front.  `helper_shaped` marks the strict subset."""
    fr = Frames(timeline)
    dmg = hero_damage_times(timeline)
    deaths = collections.defaultdict(list)
    for e in timeline['events']:
        if e['type'] == 'DEATH' and e.get('target_hero'):
            deaths[canon(e['target'])].append(e['t'])
    rows = []
    answered = collections.defaultdict(list)   # hero -> [(t, x, y)] repeat memory
    for hero, t, t_end in sorted(channels(timeline), key=lambda c: c[1]):
        team = fr.team.get(hero)
        if team is None:
            continue
        me = fr.at(hero, t)
        if me is None or me['hp_pct'] <= 0:
            continue
        fs = fronts_at(fr, hero, t, team)
        if not fs:
            continue
        land = landing(fr, hero, t, t_end)
        if land is None:
            rows.append(dict(game=game, hero=hero, t=round(t, 1), answered=False,
                             died_or_no_landing=True, front=None,
                             helper_shaped=False, pos=None, level=me['level']))
            continue
        best = None
        for tx, ty, enemies, allies in fs:
            d = dist(land['x'], land['y'], tx, ty)
            if d <= LAND_U and (best is None or d < best[0]):
                best = (d, tx, ty, enemies, allies)
        if best is None:
            continue                       # pressed near a front, landed elsewhere
        d_land, tx, ty, enemies, allies = best
        heat = False
        for h2, s in allies:
            if s['hp_pct'] < HEAT_HP:
                heat = True
                break
            if any(t - HEAT_S <= td <= t for td in dmg.get(h2, ())):
                heat = True
                break
        repeat = any(t - REPEAT_S < at_ < t
                     and dist(ax, ay, tx, ty) < REPEAT_U
                     for at_, ax, ay in answered[hero])
        tp_cd = fr.tp_cd_at(hero, t)
        fresh = fresh_respawn(fr, deaths, hero, t)
        pos = positions.get(hero) if positions else None
        rows.append(dict(
            game=game, hero=hero, t=round(t, 1), answered=True,
            died_or_no_landing=False,
            front=[round(tx), round(ty)], d_land=round(d_land),
            n_enemy=len(enemies), n_ally=len(allies),
            level=me['level'], tp_ready=(tp_cd == 0 if tp_cd is not None else None),
            heat=heat, repeat_front=repeat, pos=pos,
            team=team, fresh_respawn=fresh,
            helper_shaped=(me['level'] >= MIN_LEVEL and heat and not repeat
                           and not fresh
                           and (tp_cd == 0 if tp_cd is not None else False)),
            sup_available=viable_support(fr, hero, t, team, positions),
        ))
        answered[hero].append((t, tx, ty))
    return rows


def positions_for(sweep_dir, game):
    aj = os.path.join(sweep_dir, 'analysis', '%s.analysis.json' % game)
    if not os.path.exists(aj):
        return None
    try:
        pm = seed_draft.positions_for_game(json.load(open(aj)))
    except Exception:
        return None
    return None if pm is None else {canon(k): v for k, v in pm.items()}


def scan(dirs):
    rows, games = [], []
    for d in dirs:
        manifest = {m['game']: m for m in load_sweep(d)}
        for p in sorted(glob.glob(os.path.join(d, 'timelines', '*.timeline.json'))):
            game = os.path.basename(p).replace('.timeline.json', '')
            m = manifest.get(game)
            if m is None:
                continue
            pos = positions_for(d, game)
            tl = json.load(open(p))
            teams = {canon(k): v for k, v in tl['game']['teams'].items()}
            armed_team = RADIANT if m['side'] == 'radiant' else DIRE
            games.append(dict(game=game, seed=m['seed'], side=m['side'],
                              has_pos=pos is not None))
            for r in events_for_game(tl, game, pos or {}):
                r['seed'] = m['seed']
                r['arm_side'] = m['side']
                r['leg'] = ('armed' if teams.get(r['hero']) == armed_team
                            else 'baseline')
                rows.append(r)
    return rows, games


# --------------------------------------------------------------------------
# reporting
# --------------------------------------------------------------------------
def cell(rows, games, side, leg, strict):
    sel = [r for r in rows if r['arm_side'] == side and r['leg'] == leg
           and r['answered'] and (r['helper_shaped'] if strict else True)]
    gs = [g for g in games if g['side'] == side]
    n = len(gs)
    per = collections.Counter(r['game'] for r in sel)
    counts = [per.get(g['game'], 0) for g in gs]
    cores = [r for r in sel if r['pos'] is not None and r['pos'] <= CORE_MAX_POS]
    known = [r for r in sel if r['pos'] is not None]
    # THE YIELD POPULATION: a core answered while a support that looks
    # available existed.  This is the only set `midsupyield` can touch.
    yieldable = [r for r in cores if r.get('sup_available')]
    return dict(
        games=n, events=len(sel),
        per_game=(len(sel) / n if n else 0.0),
        zero_share=(sum(1 for c in counts if c == 0) / n if n else 0.0),
        ge2_share=(sum(1 for c in counts if c >= 2) / n if n else 0.0),
        core=len(cores), pos_known=len(known),
        core_share=(len(cores) / len(known) if known else None),
        core_per_game=(len(cores) / n if n else 0.0),
        yieldable=len(yieldable),
        yield_per_game=(len(yieldable) / n if n else 0.0),
        yield_share=(len(yieldable) / len(cores) if cores else None),
    )


def fmt_share(v):
    return '  --  ' if v is None else '%5.1f%%' % (100.0 * v)


def table(rows, games, strict, title):
    print('\n  %s' % title)
    print('  %-22s %6s %7s %8s %7s %7s %6s %9s %8s %9s'
          % ('stratum/leg', 'games', 'events', 'ev/game', '=0', '>=2',
             'core', 'core shr', 'yieldbl', 'yld/game'))
    for side in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            c = cell(rows, games, side, leg, strict)
            if not c['games']:
                continue
            print('  %-22s %6d %7d %8.3f %7s %7s %6d %9s %8d %9.3f'
                  % ('%s-armed/%s' % (side, leg), c['games'], c['events'],
                     c['per_game'], fmt_share(c['zero_share']),
                     fmt_share(c['ge2_share']), c['core'],
                     fmt_share(c['core_share']), c['yieldable'],
                     c['yield_per_game']))
    # balanced estimator, GH #148 (i): the armed leg of each physical stratum
    ab = cell(rows, games, 'radiant', 'armed', strict)
    ba = cell(rows, games, 'dire', 'armed', strict)
    abb = cell(rows, games, 'radiant', 'baseline', strict)
    bab = cell(rows, games, 'dire', 'baseline', strict)
    d_ab = ab['per_game'] - abb['per_game']
    d_ba = ba['per_game'] - bab['per_game']
    print('  armed-baseline ev/game    ab %+.3f   ba %+.3f   balanced %+.3f   %s'
          % (d_ab, d_ba, (d_ab + d_ba) / 2.0,
             'SIGN-SPLIT (noise, do not read)'
             if d_ab * d_ba < 0 else 'same sign'))


def summary(rows, games):
    print('corpus: %d games, %d TP presses beside a front' % (len(games), len(rows)))
    nolan = [r for r in rows if r['died_or_no_landing']]
    print('  presses that never landed (died / channel unresolved): %d'
          % len(nolan))
    nopos = [g for g in games if not g['has_pos']]
    if nopos:
        print('  [warn] %d game(s) with no draft-attributable positions '
              '(core share excludes them)' % len(nopos))
    table(rows, games, False, 'ALL answered fronts (the negative control\'s denominator)')
    table(rows, games, True, 'HELPER-SHAPED subset (observable gates only; SUPERSET of the helper)')


# --------------------------------------------------------------------------
# selfcheck -- synthetic timelines, every assertion two-directional
# --------------------------------------------------------------------------
def _tl(snaps, events, buildings, teams):
    return {'game': {'teams': teams}, 'snapshots': snaps,
            'events': events, 'buildings': buildings}


def _snap(hero, t, x, y, hp_pct=1.0, level=9, tp_cd=0):
    return {'t': t, 'hero': hero, 'idx': 1, 'team': 2 if 'a_' in hero else 3,
            'x': x, 'y': y, 'hp': 500 * hp_pct, 'hp_pct': hp_pct,
            'level': level, 'items': [], 'tp_cd': tp_cd}


def _mk(press_t=100.0, end_t=103.0, caster_far=True, enemy_at_front=True,
        ally_at_front=True, land_at_front=True, ally_hp=0.5,
        level=9, tp_cd=0, second_press=False, sup_level=9, sup_tp_cd=0,
        sup_in_fight=False):
    """One synthetic game with exactly one (or two) TP press(es)."""
    TX, TY = 4000.0, 4000.0
    teams = {'npc_dota_hero_a_core': 2, 'npc_dota_hero_a_sup': 2,
             'npc_dota_hero_a_ally': 2, 'npc_dota_hero_b_foe': 3,
             'npc_dota_hero_b_foe2': 3}
    snaps, events = [], []
    far = (-6000.0, -6000.0) if caster_far else (TX + 500, TY + 500)
    land = (TX + 300, TY + 300) if land_at_front else (-7000.0, -7000.0)
    # The caster sits FAR except for a window after each landing, so a second
    # press 20 s later starts from far again (a hero who never walks back out
    # would fail the > 3500 clause and the repeat-front case could not be
    # posed at all).
    lands = [e for e in ([end_t] + ([press_t + 23.0] if second_press else []))
             if e is not None]
    for t in [x * 1.0 for x in range(80, 140)]:
        after = any(e + TP_TAIL_S <= t < e + 8.0 for e in lands)
        cx, cy = land if after else far
        snaps.append(_snap('a_core', t, cx, cy, level=level, tp_cd=tp_cd))
        # The support sits alone in his own corner unless the case wants him
        # dragged into a fight; `b_foe2` below is what makes that a fight.
        snaps.append(_snap('a_sup', t, -6000.0, -5000.0, level=sup_level,
                           tp_cd=sup_tp_cd))
        if sup_in_fight:
            snaps.append(_snap('b_foe2', t, -6000.0 + 800.0, -5000.0))
        snaps.append(_snap('a_ally', t, TX + 100 if ally_at_front else -9000.0,
                           TY + 100 if ally_at_front else -9000.0, hp_pct=ally_hp))
        snaps.append(_snap('b_foe', t, TX + 200 if enemy_at_front else -9000.0,
                           TY + 200 if enemy_at_front else -9000.0))
    events.append({'t': press_t, 'type': 'MODIFIER_ADD', 'actor': 'a_core',
                   'target': 'a_core', 'inflictor': 'modifier_teleporting'})
    if end_t is not None:
        events.append({'t': end_t, 'type': 'MODIFIER_REMOVE', 'actor': 'a_core',
                       'target': 'a_core', 'inflictor': 'modifier_teleporting'})
    if second_press:
        events.append({'t': press_t + 20.0, 'type': 'MODIFIER_ADD',
                       'actor': 'a_core', 'target': 'a_core',
                       'inflictor': 'modifier_teleporting'})
        events.append({'t': press_t + 23.0, 'type': 'MODIFIER_REMOVE',
                       'actor': 'a_core', 'target': 'a_core',
                       'inflictor': 'modifier_teleporting'})
    buildings = [{'t': bt, 'name': 'tower', 'team': 2, 'x': TX, 'y': TY,
                  'hp': 2500, 'hp_pct': 1.0, 'alive': True}
                 for bt in (-68.2, 0.0, 60.0, 90.0, 120.0)]
    # a DIRE tower far away: must never be picked as a RADIANT hero's front
    buildings += [{'t': bt, 'name': 'tower', 'team': 3, 'x': -TX, 'y': -TY,
                   'hp': 2500, 'hp_pct': 1.0, 'alive': True}
                  for bt in (-68.2, 0.0, 60.0, 90.0, 120.0)]
    return _tl(snaps, events, buildings, teams)


def selfcheck():
    ok = fail = 0

    def chk(name, cond, detail=''):
        nonlocal ok, fail
        if cond:
            ok += 1
        else:
            fail += 1
        print('  %-52s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))

    POS = {'a_core': 2, 'a_sup': 5, 'a_ally': 4, 'b_foe': 1}

    def run(**kw):
        return events_for_game(_mk(**kw), 'g', POS)

    base = run()
    ans = [r for r in base if r['answered']]
    chk('baseline: one answered front', len(ans) == 1, '(%d)' % len(ans))
    chk('baseline: helper-shaped', bool(ans and ans[0]['helper_shaped']))
    chk('baseline: position from draft (pos 2 = core)',
        bool(ans and ans[0]['pos'] == 2))
    chk('baseline: front is the OWN tower', bool(ans and ans[0]['front'] == [4000, 4000]))

    # --- each clause of the rule, negated one at a time --------------------
    chk('no enemy at the front -> no event',
        not [r for r in run(enemy_at_front=False) if r['answered']])
    chk('no other ally at the front -> no event',
        not [r for r in run(ally_at_front=False) if r['answered']])
    chk('caster within 3500 u -> no event (walk, not TP)',
        not [r for r in run(caster_far=False) if r['answered']])
    chk('landed elsewhere -> not an answer',
        not [r for r in run(land_at_front=False) if r['answered']])

    # --- the landing/death separation --------------------------------------
    nolan = run(end_t=None)
    chk('channel never ended -> no answer, but row kept',
        (not [r for r in nolan if r['answered']]
         and any(r['died_or_no_landing'] for r in nolan)))

    # --- helper gates: each flips helper_shaped WITHOUT dropping the event --
    lvl = [r for r in run(level=5) if r['answered']]
    chk('level 5 -> answered but NOT helper-shaped',
        len(lvl) == 1 and not lvl[0]['helper_shaped'])
    cold = [r for r in run(tp_cd=12.0) if r['answered']]
    chk('TP on cooldown -> answered but NOT helper-shaped',
        len(cold) == 1 and not cold[0]['helper_shaped'])
    cool = [r for r in run(ally_hp=0.95) if r['answered']]
    chk('healthy undamaged ally (heat gate off) -> not helper-shaped',
        len(cool) == 1 and not cool[0]['heat'] and not cool[0]['helper_shaped'])

    # --- repeat-front memory: second answer to the SAME front is suppressed -
    two = [r for r in run(second_press=True) if r['answered']]
    chk('two presses at one front -> both answered, second is repeat',
        len(two) == 2 and not two[0]['repeat_front'] and two[1]['repeat_front'])
    chk('repeat front -> second is NOT helper-shaped, first still is',
        len(two) == 2 and two[0]['helper_shaped']
        and not two[1]['helper_shaped'])

    # --- the 15 s post-respawn cooldown (found frame-by-frame, not here) ----
    dead = _mk()
    dead['events'].append({'t': 92.0, 'type': 'DEATH', 'actor': 'b_foe',
                           'target': 'a_core', 'target_hero': True})
    for s in dead['snapshots']:
        if s['hero'] == 'a_core' and 92.0 <= s['t'] < 95.0:
            s['hp_pct'], s['hp'] = 0.0, 0
    dr = [r for r in events_for_game(dead, 'g', POS) if r['answered']]
    chk('press 5 s after respawn -> answered but NOT helper-shaped',
        len(dr) == 1 and dr[0]['fresh_respawn'] and not dr[0]['helper_shaped'])
    old = _mk()
    old['events'].append({'t': 40.0, 'type': 'DEATH', 'actor': 'b_foe',
                          'target': 'a_core', 'target_hero': True})
    for s in old['snapshots']:
        if s['hero'] == 'a_core' and 40.0 <= s['t'] < 43.0:
            s['hp_pct'], s['hp'] = 0.0, 0
    orr = [r for r in events_for_game(old, 'g', POS) if r['answered']]
    chk('a death 60 s earlier does NOT suppress the answer',
        len(orr) == 1 and not orr[0]['fresh_respawn']
        and orr[0]['helper_shaped'])
    chk('RESPAWN_S is the rule\'s 15 s', RESPAWN_S == 15.0)

    # --- the yield population (the only set midsupyield can touch) ---------
    chk('a free pos-5 elsewhere on the map -> sup_available',
        bool(ans and ans[0]['sup_available'] is True))
    chk('the pos-4 STANDING AT THE FRONT is not available (in the fight)',
        # a_ally is pos 4, alive, level 9, TP ready -- the only thing that
        # disqualifies him is the enemy 141 u away.  If the geometric
        # IsInTeamFight read were dropped, this case would still say True and
        # nothing else in this file would notice.
        bool([r for r in run(sup_in_fight=True, sup_level=1) if r['answered']])
        and [r for r in run(sup_in_fight=True, sup_level=1)
             if r['answered']][0]['sup_available'] is False)
    for label, kw in (('under level 6', dict(sup_level=5)),
                      ('TP on cooldown', dict(sup_tp_cd=9.0)),
                      ('already in a fight', dict(sup_in_fight=True))):
        got = [r for r in run(**kw) if r['answered']]
        chk('support %s -> NOT available, event still answered' % label,
            len(got) == 1 and got[0]['sup_available'] is False)
    yg = [dict(r, arm_side='radiant', leg='armed', seed='888') for r in base]
    yc = cell(yg, [dict(game='g', seed='888', side='radiant', has_pos=True)],
              'radiant', 'armed', False)
    chk('cell(): a core answer with a free support is yieldable',
        yc['yieldable'] == 1 and abs(yc['yield_share'] - 1.0) < 1e-9)
    ys = [dict(r, arm_side='radiant', leg='armed', seed='888', pos=5)
          for r in base if r['answered']]
    yc2 = cell(ys, [dict(game='g', seed='888', side='radiant', has_pos=True)],
               'radiant', 'armed', False)
    chk('cell(): a SUPPORT answer is never yieldable (nothing to reallocate)',
        yc2['events'] == 1 and yc2['yieldable'] == 0
        and yc2['yield_share'] is None)

    # --- constants are the rule's, not invented ----------------------------
    chk('FAR_U is the rule\'s 3500', FAR_U == 3500.0)
    chk('FRONT_R_U is the rule\'s 1200', FRONT_R_U == 1200.0)
    chk('HEAT_HP is the rule\'s 0.75', HEAT_HP == 0.75)
    chk('repeat memory is the rule\'s 45 s / 1600 u',
        REPEAT_S == 45.0 and REPEAT_U == 1600.0)
    chk('core band is J.IsCore (pos 1-3)', CORE_MAX_POS == 3)

    # --- the aggregate the ruling actually asked for ------------------------
    games = [dict(game='g', seed='888', side='radiant', has_pos=True)]
    rows = []
    for r in base:
        r['arm_side'], r['leg'], r['seed'] = 'radiant', 'armed', '888'
        rows.append(r)
    c = cell(rows, games, 'radiant', 'armed', False)
    chk('cell(): ev/game and core share are computable',
        c['events'] == 1 and abs(c['per_game'] - 1.0) < 1e-9
        and abs(c['core_share'] - 1.0) < 1e-9)
    chk('cell(): a support answer moves the core share off 1.0',
        _core_share_with_support(rows, games) < 1.0)
    empty = cell([], [], 'radiant', 'armed', False)
    chk('cell(): empty corpus -> core share None, not 0 or 1',
        empty['core_share'] is None and empty['events'] == 0)

    print('\n%d PASS / %d FAIL' % (ok, fail))
    return 0 if fail == 0 else 1


def _core_share_with_support(rows, games):
    extra = dict(rows[0])
    extra['pos'] = 5
    extra['hero'] = 'a_sup'
    return cell(rows + [extra], games, 'radiant', 'armed', False)['core_share']


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('sweeps', nargs='*', help='sweep_run.sh output dir(s)')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--jsonl', help='write every row here')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.sweeps:
        ap.error('need at least one sweep dir (or --selfcheck)')
    rows, games = scan(a.sweeps)
    if a.jsonl:
        with open(a.jsonl, 'w') as fh:
            for r in rows:
                fh.write(json.dumps(r) + '\n')
    summary(rows, games)
    return 0


if __name__ == '__main__':
    sys.exit(main())
