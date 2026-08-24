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
# J.ShouldWalkNotTp's own on-face radius (`J.GetNearbyHeroes( bot, 350, ...)`,
# jmz_func.lua:5778).  This is the OTHER promoted TP guard ('tpsafe'), and it
# is the only one that runs in BOT_MODE_RETREAT -- see band_of() below.
WALK_GUARD_RADIUS_U = 350.0
# How far back to look for the vision witness below.  Short on purpose: it is
# evidence about the press instant, and a hero can break vision quickly.
VISION_LOOKBACK_S = 3.0
# The dumper's inflictor string for a plain auto-attack (every named ability /
# item writes its own inflictor).  An auto-attack needs a targetable unit, so
# the ATTACKER must have had vision of the target when it was issued.
ATTACK_INFLICTOR = 'dota_unknown'
# "Standing in my own fountain" -- generous, because the dumper samples at
# ~1 s and a landed hero walks out immediately.
HOME_RADIUS_U = 1500.0
# Turbo TP channel ~3 s; read the landing one sample after it completes.
LANDING_DELAY_S = 4.5


def canon(name):
    return (name or '').replace('npc_dota_hero_', '')


def band_of(near, reach=DEFAULT_REACH_U):
    """Which promoted guard, if any, could have refused this press.

    The two promoted TP guards do NOT tile the distance axis, and the gap is
    structural rather than a bug in either one (source read 2026-08-24, both
    line numbers on `origin/main` 03fb378):

      * `tpsafe2` (`J.ShouldNotStartInterruptibleTp`) scans 700 u and refuses
        at `GetAttackRange()+150` or on a closing enemy -- but its only call
        site, `ability_item_usage_generic.lua:5163`, is guarded by
        `nMode ~= BOT_MODE_RETREAT`.  In retreat mode it never runs.
      * `tpsafe` (`J.ShouldWalkNotTp`, called at
        `ability_item_usage_generic.lua:5442`, inside the
        `nMode == BOT_MODE_RETREAT` branch) is the retreat-mode guard, and its
        on-face test is **350 u**, not 700 u (jmz_func.lua:5778).

    So a retreat-mode press with the nearest enemy between 350 u and the reach
    bound is refused by NEITHER: tpsafe2 does not run, and tpsafe's own
    predicate is false before its later clauses are even reached.

    IMPORTANT -- WHAT THIS FIELD IS NOT.  The dump carries no bot mode, so this
    band is a NECESSARY condition, never a sufficient one: a `mid_gap` row is a
    press that WOULD fall through both guards *if* it was a retreat TP, and
    outside retreat mode tpsafe2 covers the same band.  Read the band as "which
    hypothesis is still alive for this row", and settle rows frame by frame.
    """
    if near is None:
        return 'no_enemy'
    if near <= WALK_GUARD_RADIUS_U:
        return 'walk_guard'      # inside BOTH guards' radii
    if near <= SCAN_RADIUS_U:
        return 'mid_gap'         # tpsafe2 only -> uncovered in retreat mode
    if near <= reach:
        return 'over_scan'       # past tpsafe2's 700 u scan: TOOL over-read
    return 'far'


def fountains(snapshots):
    """Each team's fountain = centroid of its earliest 3 s of frames.

    Same construction (and same positive control) as
    `creeppull_domain.Game.fountain`: before the horn every hero stands in its
    own fountain, so the pre-horn centroid IS the fountain.  Recomputed here
    rather than imported because this file only needs the two points.

    THE WINDOW IS PER TEAM, NOT GLOBAL, and that is load-bearing.  Each team
    enters the snapshot stream at its own first tick -- in
    `a0d128/20260824_181444_slot8` radiant appears at t=-69.2 and dire not
    until t=-53.2 -- so a single global `t0 + 3` window collects radiant only
    and returns a dict with ONE team in it.  Every dire press in that game
    then reads `dest='unknown'`, silently, including presses that ended in
    death.  `creeppull_domain` carries this same comment; the first cut of
    this function did not, and the missing half was caught by cross-checking
    a bearing frame against the table rather than by any assertion -- hence
    the staggered-entry case in the selfcheck below.
    """
    if not snapshots:
        return {}
    team_t0 = {}
    for s in snapshots:
        tm = s['team']
        if tm not in team_t0 or s['t'] < team_t0[tm]:
            team_t0[tm] = s['t']
    acc = collections.defaultdict(lambda: [0.0, 0.0, 0])
    for s in snapshots:
        if s['t'] <= team_t0[s['team']] + 3.0:
            a = acc[s['team']]
            a[0] += float(s['x'])
            a[1] += float(s['y'])
            a[2] += 1
    return {tm: (a[0] / a[2], a[1] / a[2]) for tm, a in acc.items() if a[2]}


def tp_destination(frames, fount, t, died):
    """Where did this TP land -- own fountain, or out in the field?

    THE POINT.  The bot's MODE is not in the dump, and the whole question
    raised by GH #159 is which of the two promoted guards owned a given press:
    `tpsafe2` never runs in BOT_MODE_RETREAT, and `tpsafe` (the retreat-mode
    guard) only looks 350 u.  Destination is the best proxy the dump offers,
    because the retreat branch
    (`ability_item_usage_generic.lua:5430`+) teleports to
    `J.GetTeamFountain()` while the travel branches (laning "go develop",
    push, defend, ally support) teleport to a lane or a tower.

    LIMITS, both real:
      * a press that was already AT home has a meaningless destination, so it
        is reported as `from_home` and must be excluded, not counted as home;
      * a fatal press never lands anywhere, so it is `died` -- the deaths this
        census is about are exactly the rows this column cannot classify.
        Destination therefore describes the SURVIVING on-face population and
        is evidence about the path, not about the deaths.
    """
    if not fount:
        return 'unknown'
    s0 = interp(frames, t)
    if s0 is None:
        return 'unknown'
    if math.dist((s0['x'], s0['y']), fount) <= HOME_RADIUS_U:
        return 'from_home'
    if died:
        return 'died'
    s1 = interp(frames, t + LANDING_DELAY_S)
    if s1 is None:
        return 'unknown'
    return ('home'
            if math.dist((s1['x'], s1['y']), fount) <= HOME_RADIUS_U
            else 'field')


def saw_enemy(events, bot, enemy, t, lookback=VISION_LOOKBACK_S):
    """Did `bot` demonstrably HAVE VISION of `enemy` just before pressing TP?

    THE PROBLEM THIS EXISTS FOR.  The behavioural dump is a replay's
    god's-eye view: `near` is the TRUE distance, not what the bot could see.
    `J.CanEnemyInterruptTpChannel` scans `bot:GetNearbyHeroes(700, ...)`, which
    only ever returns VISIBLE enemies -- so "an enemy was at 598 u and the
    guard did not refuse" has an innocent explanation that costs no bug at
    all: the enemy was in fog, the guard's list was empty, and it answered
    false truthfully.  Every row in this census is ambiguous between that and
    a real hole until vision is pinned.

    THE WITNESS.  An auto-attack requires a targetable unit.  If the BOT
    itself auto-attacked that same enemy inside the lookback window, the bot
    saw it -- there is no fog reading left.  This is one-directional and
    deliberately so:

      * True  => the bot had vision (strong, and it is the only claim made).
      * False => says NOTHING.  Melee bots retreating, casters, and anyone who
        simply chose not to attack all read False while seeing the enemy fine.

    Damage the ENEMY dealt to the bot is NOT a witness and is not used here:
    being hit from the fog is exactly the case this must not swallow.
    """
    for e in events:
        if (e['type'] == 'DAMAGE'
                and e.get('inflictor') == ATTACK_INFLICTOR
                and canon(e.get('actor')) == bot
                and canon(e.get('target')) == enemy
                and t - lookback <= e['t'] <= t):
            return True
    return False


def lift_stats(rows, reach=DEFAULT_REACH_U):
    """The magnitude judgement of GH #159, as a function instead of prose.

    The finding is not "some on-face presses are fatal" -- it is that the
    on-face fatality rate sits far ABOVE the all-press base rate.  Keeping
    that as a printed sentence made it unassertable; the 2026-08-24T15:57Z
    selfcheck could only pin single frames, so a regression that flattened the
    lift to 1.0 would have passed 12/12.  Returns None for `lift` when either
    denominator is empty rather than inventing a ratio.
    """
    presses = len(rows)
    fatal_all = [r for r in rows if r['died_in_channel']]
    onface = [r for r in rows if r['on_face']]
    fatal_on = [r for r in onface if r['died_in_channel']]
    base = len(fatal_all) / presses if presses else None
    on_rate = len(fatal_on) / len(onface) if onface else None
    lift = (on_rate / base) if (base and on_rate is not None) else None
    return dict(presses=presses, onface=len(onface),
                fatal_all=len(fatal_all), fatal_onface=len(fatal_on),
                base_rate=base, onface_rate=on_rate, lift=lift)


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

    fount = fountains(timeline['snapshots'])
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
                band=band_of(near, reach),
                saw_nearest=(who is not None
                             and saw_enemy(timeline['events'], h, who, t)),
                dest=tp_destination(fr[h], fount.get(team.get(h)), t,
                                    bool(died)),
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

    # ---- guard-coverage bands (source read, jmz_func.lua:5778 / 5857 and
    # ability_item_usage_generic.lua:5163 / 5442) ----------------------------
    chk('an enemy inside 350u is inside BOTH guards',
        band_of(200.0) == 'walk_guard', 'near=200 -> %s' % band_of(200.0))
    chk('350u exactly is still the walk guard (<=, as GetNearbyHeroes)',
        band_of(350.0) == 'walk_guard')
    chk('the 350-700u band is tpsafe2-only (retreat mode: nobody)',
        band_of(598.0) == 'mid_gap', 'the jakiro bearing frame, near=598')
    chk('past the 700u scan radius is the TOOL over-reading, not a gap',
        band_of(710.0) == 'over_scan')
    chk('past the reach bound is not on-face at all',
        band_of(900.0) == 'far')
    chk('no living enemy sampled is its own band, not 0u',
        band_of(None) == 'no_enemy')

    # ---- vision witness (saw_enemy) ----------------------------------------
    # sn2 already has the enemy on face at the press (t=10.5).
    atk = {'t': 9.0, 'type': 'DAMAGE', 'actor': H, 'target': E,
           'inflictor': ATTACK_INFLICTOR, 'value': 50,
           'actor_hero': True, 'target_hero': True}
    rv = presses_for_game({'snapshots': sn2, 'events': [ev2[0], atk]}, 'g')[0]
    chk('bot auto-attacking that enemy is a vision witness',
        rv['saw_nearest'] is True)
    rv2 = presses_for_game({'snapshots': sn2, 'events': [ev2[0]]}, 'g')[0]
    chk('no attack -> UNRESOLVED, never a witness',
        rv2['saw_nearest'] is False)
    # Being hit FROM the fog must not count as seeing.
    hitus = dict(atk, actor=E, target=H)
    rv3 = presses_for_game({'snapshots': sn2, 'events': [ev2[0], hitus]}, 'g')[0]
    chk('the ENEMY hitting us is not a vision witness',
        rv3['saw_nearest'] is False, 'fog damage must not exonerate')
    # An ability tick can land on a unit in fog; only a real attack witnesses.
    spell = dict(atk, inflictor='jakiro_macropyre')
    rv4 = presses_for_game({'snapshots': sn2, 'events': [ev2[0], spell]}, 'g')[0]
    chk('an ability tick is not a vision witness (AoE reaches fog)',
        rv4['saw_nearest'] is False)
    # Stale attacks outside the lookback must not carry vision forward.
    old = dict(atk, t=10.5 - VISION_LOOKBACK_S - 0.5)
    rv5 = presses_for_game({'snapshots': sn2, 'events': [ev2[0], old]}, 'g')[0]
    chk('an attack older than the lookback is not a witness',
        rv5['saw_nearest'] is False)
    # An attack on a DIFFERENT enemy says nothing about the nearest one.
    other = dict(atk, target='npc_dota_hero_lina')
    rv6 = presses_for_game({'snapshots': sn2, 'events': [ev2[0], other]}, 'g')[0]
    chk('attacking a different hero is not a witness for the nearest',
        rv6['saw_nearest'] is False)

    # ---- TP destination ----------------------------------------------------
    # Pre-horn spawn IS the fountain: team 3 spawns at (0,0) in these synths,
    # team 2 at (5000,0).  H is team 3, E is team 2.
    fo = fountains(sn2)
    chk('fountains are the pre-horn centroid of each team',
        fo[3] == (0.0, 0.0) and fo[2][0] == 200.0,
        'team3=%s team2=%s' % (fo[3], fo[2]))

    # THE REGRESSION THIS EXISTS FOR: teams enter the snapshot stream at
    # different first ticks (radiant t=-69.2, dire t=-53.2 in
    # a0d128/20260824_181444_slot8).  A global `t0+3` window sees only the
    # team that entered first, and every press by the other team then reads
    # dest='unknown' -- silently, deaths included.
    late = ([{'t': float(t), 'hero': 'a', 'team': 2, 'x': 7000.0, 'y': 7000.0,
              'hp_pct': 1.0, 'level': 1, 'items': []} for t in range(20, 24)]
            + [{'t': float(t), 'hero': 'b', 'team': 3, 'x': -7000.0,
                'y': -7000.0, 'hp_pct': 1.0, 'level': 1, 'items': []}
               for t in range(0, 4)])
    fl = fountains(late)
    chk('a team that enters the stream 20 s late still gets a fountain',
        set(fl) == {2, 3} and fl[2] == (7000.0, 7000.0),
        'got %s' % sorted(fl))

    def destsn(pts, died=False):
        """H walking a path; returns its destination reading for a press at 10.5."""
        s = snaps(H, 3, pts)
        return tp_destination(sorted(s, key=lambda x: x['t']),
                              (0.0, 0.0), 10.5, died)

    away = [(t, 8000, 0, 1.0) for t in range(0, 20)]
    home_after = [(t, 8000 if t < 14 else 100, 0, 1.0) for t in range(0, 20)]
    chk('teleporting to the fountain reads home',
        destsn(home_after) == 'home')
    chk('still in the field after the channel reads field',
        destsn(away) == 'field')
    chk('a press made AT home is excluded, not counted as home',
        destsn([(t, 100, 0, 1.0) for t in range(0, 20)]) == 'from_home')
    chk('a fatal press has no landing to classify',
        destsn(home_after, died=True) == 'died')
    chk('no fountain -> unknown, never a default corner',
        tp_destination(sorted(snaps(H, 3, away), key=lambda x: x['t']),
                       None, 10.5, False) == 'unknown')
    chk('a landing past the last snapshot is unknown, not clamped',
        tp_destination(sorted(snaps(H, 3, [(t, 8000, 0, 1.0)
                                           for t in range(0, 12)]),
                              key=lambda x: x['t']),
                       (0.0, 0.0), 10.5, False) == 'unknown')

    # ---- the MAGNITUDE judgement of GH #159 --------------------------------
    # Until now the selfcheck could only pin single frames: a regression that
    # flattened the on-face/base lift to 1.0 -- i.e. that destroyed the entire
    # finding -- would still have passed every assertion.  These three pin the
    # statistic itself, in both directions, so this file can serve as the
    # acceptance checker when a fix for #159 lands (issue §4).
    def synth(n, fatal_n, on_face):
        return [dict(died_in_channel=(i < fatal_n), on_face=on_face,
                     near=200.0 if on_face else 3000.0,
                     band=band_of(200.0 if on_face else 3000.0))
                for i in range(n)]

    hot = synth(90, 1, False) + synth(10, 5, True)   # 1.1% vs 50.0%
    s = lift_stats(hot)
    chk('lift recovers a planted on-face excess',
        s['lift'] is not None and s['lift'] > 4.0,
        'base=%.3f on-face=%.3f lift=%.1fx'
        % (s['base_rate'], s['onface_rate'], s['lift']))
    chk('the planted rates are read back exactly',
        abs(s['base_rate'] - 0.06) < 1e-9 and abs(s['onface_rate'] - 0.5) < 1e-9,
        'base=%.4f on-face=%.4f' % (s['base_rate'], s['onface_rate']))

    # NEGATIVE CONTROL: same fatality rate on and off face.  A tool that
    # manufactures a lift out of the on-face split alone would fail here.
    flatc = synth(90, 9, False) + synth(10, 1, True)  # 10% vs 10%
    s2 = lift_stats(flatc)
    chk('no lift when on-face and base rates agree',
        s2['lift'] is not None and abs(s2['lift'] - 1.0) < 0.01,
        'lift=%.3fx' % s2['lift'])

    # An empty denominator must read as unknown, never as 0x or 1x.
    s3 = lift_stats(synth(10, 0, False))
    chk('no on-face presses -> lift is None, not a number',
        s3['lift'] is None and s3['onface'] == 0)
    chk('no presses at all -> every rate is None, not 0.0',
        lift_stats([])['base_rate'] is None)

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

    st = lift_stats(rows, a.reach)
    onface = [r for r in rows if r['on_face']]
    fatal = [r for r in onface if r['died_in_channel']]
    print('\n  base rate: %d/%d presses (%.1f%%) end in death within %.0f s'
          % (st['fatal_all'], st['presses'],
             100.0 * st['base_rate'] if st['base_rate'] else 0.0,
             CHANNEL_WINDOW_S))
    print('  on-face  : %d/%d (%.1f%%) -- the lift is the whole finding'
          % (st['fatal_onface'], st['onface'],
             100.0 * st['onface_rate'] if st['onface_rate'] else 0.0))
    print('  LIFT     : %s  (on-face fatality / base fatality)'
          % ('%.2fx' % st['lift'] if st['lift'] is not None else 'n/a'))

    # Which promoted guard could have refused each press -- see band_of().
    print('\n  guard-coverage band at the press instant '
          '(NECESSARY condition only, mode is not in the dump):')
    print('  %-12s %8s %8s %8s   %s'
          % ('band', 'presses', 'fatal', 'fatal%', 'which guard owns it'))
    owner = {
        'walk_guard': 'tpsafe (350u) AND tpsafe2 (700u)',
        'mid_gap': 'tpsafe2 only -> NOBODY in retreat mode',
        'over_scan': 'neither -- past 700u scan (tool over-read)',
        'far': 'no enemy in reach',
        'no_enemy': 'no living enemy sampled',
    }
    for b in ('walk_guard', 'mid_gap', 'over_scan', 'far', 'no_enemy'):
        g = [r for r in rows if r['band'] == b]
        if not g:
            continue
        f = [r for r in g if r['died_in_channel']]
        print('  %-12s %8d %8d %7.1f%%   %s'
              % (b, len(g), len(f), 100.0 * len(f) / len(g), owner[b]))

    # Vision witness -- see saw_enemy().  A `near` from the replay's god's-eye
    # view is not what the guard's GetNearbyHeroes(700) could see, so the
    # fog-exonerated reading has to be separated out before any row is called
    # a guard failure.
    witnessed = [r for r in onface if r['saw_nearest']]
    wfatal = [r for r in witnessed if r['died_in_channel']]
    print('\n  vision witness (bot auto-attacked that same enemy within %.0f s '
          'before the press):' % VISION_LOOKBACK_S)
    print('    %d/%d on-face presses (%.1f%%) are vision-WITNESSED; %d of '
          'those died in channel'
          % (len(witnessed), len(onface),
             100.0 * len(witnessed) / len(onface) if onface else 0.0,
             len(wfatal)))
    print('    the remaining %d are UNRESOLVED (fog is still a live '
          'explanation), not exonerated' % (len(onface) - len(witnessed)))

    # Destination -- see tp_destination().  This is the only handle the dump
    # gives on WHICH guard owned the press, since the mode itself is absent.
    print('\n  TP destination of the SURVIVING presses '
          '(retreat branch teleports to J.GetTeamFountain()):')
    print('  %-12s %7s %7s %7s   %s'
          % ('band', 'home', 'field', 'home%', '(excl. died / from_home)'))
    for b in ('walk_guard', 'mid_gap', 'over_scan', 'far'):
        g = [r for r in rows if r['band'] == b]
        home = [r for r in g if r['dest'] == 'home']
        field = [r for r in g if r['dest'] == 'field']
        n = len(home) + len(field)
        if not n:
            continue
        print('  %-12s %7d %7d %6.1f%%'
              % (b, len(home), len(field), 100.0 * len(home) / n))

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
