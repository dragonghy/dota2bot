#!/usr/bin/env python3
"""Condition (a) for soak candidate `tpdying` -- the response-TP landing pin.

WHAT THE LEVER IS (source read 2026-09-06, `bots/FunLib/jmz_func.lua:8912-8963`)
--------------------------------------------------------------------------------
`J.GetTpCommitDefendDesire( bot, nLane )` is the `tpcommit` landing floor: a
responder that TP'd to answer a trigger is held in the DEFEND mode of the lane
it answered for a 12 s commitment window (`bot.tpRespondUntil = DotaTime() +
12.0`, stamped at all three response-TP call sites in
`ability_item_usage_generic.lua`: the gated rescue TP :5207, the gated `midtp`
tower-fight TP :5229, and the SHIPPED defend TP :5412).

The floor already carries a SURVIVAL RELEASE:

    if J.GetHP( bot ) < 0.40 or J.ShouldRetreatLaneBurst( bot ) then ... return nil

`tpdying` adds a third release clause immediately below it:

    if J.IsSoakCandidate( 'tpdying' )
    and J.IsIncomingBurstLethal( bot, 3.0 ) then ... return nil

Structurally the clause can only ever RELEASE a pin sooner (return nil
earlier); it can never raise or create one.  So its (a) signature is
DIRECTIONAL and one-sided:

    armed  =>  FEWER pinned frames after landing, and no other change;
               and, if the release is worth anything, a LOWER death rate in
               the seconds right after landing.

⚠️ REACHABILITY: THIS ID IS A NO-OP UNLESS `tpcommit` IS ALSO ARMED.
The clause sits INSIDE `J.GetTpCommitDefendDesire`, whose second line is
`if not J.IsSoakCandidate( 'tpcommit' ) then return nil end`.  `tpdying`
armed alone is byte-for-byte inert (test_set.md §A'.4).  This is the CONVERSE
of the 2026-09-06 `suptp` finding -- there an `A or B` disjunction made B
weightless whenever A was co-armed; here an enclosing gate makes this id
weightless unless its partner IS co-armed.  Both shapes are "whether an id has
any effect depends on another id in the same arm string", and both are invisible
to `check_armed_wiring.py`, which only checks that a call site exists.
This tool therefore REFUSES to read a wave whose arm string lacks `tpcommit`
(`--assert-arm`), rather than reporting a clean-looking zero.

THE TWO DETECTORS ARE NOT MINE TO CHOOSE (§A'.3 constraint 3)
--------------------------------------------------------------
`tpdying` entered the set on 2026-08-19 with its (a) acceptance written down
in the same breath: it must be judged on BEHAVIOURAL detectors, never on
gpm/xpm, and two were named --

  (1) "the death rate within 10 s of a response TP landing";
  (2) "the number of frames still pinned in DEFEND after landing".

Both are built here, and nothing else is offered as (a) evidence.

WHAT THE DUMP CANNOT SEE, DECLARED UP FRONT
-------------------------------------------
There is no bot-mode field in the behavioural dump, so "still pinned in
DEFEND" is not directly observable.  Detector (2) is a POSITIONAL PROXY: the
pin holds the responder at the lane it answered, and the release lets the
promoted retreat (which the 0.85 floor was outbidding) win -- a released
responder walks away, a pinned one does not.  So (2) counts post-landing
snapshots in which the hero is still within `--pin-radius` of the point it
landed on, inside the 12 s commitment window the source itself stamps.

That proxy is NECESSARY, not sufficient: a responder can stand near its
landing spot because it is winning a fight there, with no pin involved.  It is
read as a LEG DELTA (armed minus baseline on the same mirrored draft), never
as an absolute count -- exactly the reading `tpreach_domain` takes on ADDED.

DOMAIN: WHICH TP PRESSES ARE "RESPONSE TPs"
-------------------------------------------
The stamp sites are not in the dump either.  Their observable signature is:

  * the channel COMPLETED (the hero is somewhere else afterwards) -- an
    interrupted channel never lands, so it can never be pinned;
  * the destination is NOT the bot's own fountain -- a retreat TP goes home
    (`J.GetTeamFountain()`), all three response branches go to a lane front,
    a tower, or an ally;
  * the trip is long: the shipped defend TP requires
    `GetUnitToLocationDistance( bot, tpLoc ) > nMinTPDistance - 500` with
    `nMinTPDistance = 5500` (:5243, :5403) => > 5000 u.

`--trip-floor` defaults to 5000 for that reason.  It is the DEFEND branch's own
number; the two gated branches (rescue, midtp) have no distance floor of their
own, so this domain is a subset and under-counts them.  Under-counting is the
safe direction for a leg-delta reading: it costs power, not validity, and it
is applied identically to both legs.

BIAS DIRECTION OF EVERY ESTIMATOR HERE, DECLARED
------------------------------------------------
  * landing time is read from the `modifier_teleporting` MODIFIER_REMOVE
    event, which carries the exact instant; the landing POSITION is the first
    snapshot STRICTLY AFTER it (~1 Hz), so the position lags the instant by up
    to one tick in the direction the hero then walked.  That inflates
    `--pin-radius` slightly and does so on BOTH legs.  "Strictly after" is not
    a detail: a sample sitting exactly on the removal instant still shows the
    hero at his DEPARTURE point, which reads as trip 0 and throws the landing
    away as an interruption.
  * deaths come from DEATH EVENTS, never from an interpolated `hp_pct`
    (GH #176 ②), and never from "did the hero jump to the fountain" -- Wraith
    King reincarnates in place (charter 2026-08-21), which is precisely the
    hero a response TP most often is.
  * the presser's own frames are read with plain `interp`, deliberately: at a
    fatal landing his bracket is [alive, dead] by construction, and filtering
    the ACTOR would delete exactly the numerator of detector (1).  Only
    cross-entity geometry needs the corpse filter, and this file has none.
  * illusions are dropped by `frames_by_hero` (GH #176 ①) before anything is
    measured; an illusion cannot press a TP scroll, so a press keyed to a
    dropped entity is a dump we do not understand and is COUNTED, not invented
    (`--verbose` prints them).
"""
import argparse
import collections
import glob
import json
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Shared, never re-implemented: a second copy of the entity keying or the
# fountain construction is how two estimators in this tree drifted apart once
# already (GH #176, and the `pullcamp_frames` lesson of 2026-08-25).
from entities import (canon, frames_by_hero, interp, death_times,  # noqa: E402
                      DROPPED_ENTITIES)
from creeppull_domain import load_sweep  # noqa: E402
from tp_channel_death import fountains, HOME_RADIUS_U, _team_of  # noqa: E402

# `bot.tpRespondUntil = DotaTime() + 12.0` -- all three stamp sites.
COMMIT_WINDOW_S = 12.0
# §A'.3 constraint 3 names "within 10 s of landing" for detector (1).
DEATH_WINDOW_S = 10.0
# `nMinTPDistance - 500` with nMinTPDistance = 5500 (the shipped defend TP).
DEFAULT_TRIP_FLOOR_U = 5000.0
# "Still at the spot it landed on."  A tower's fighting neighbourhood; the
# release lets retreat win, and a retreating hero clears this inside one tick
# (300+ u/s).  Sensitivity across 800/1200/1600 is printed, because a
# conclusion that survives only one radius is a conclusion about the radius.
DEFAULT_PIN_RADIUS_U = 1200.0
PIN_RADII_U = (800.0, 1200.0, 1600.0)
# A completed channel moves the hero across the map; an interrupted one leaves
# him where he stood.  Well under the trip floor on purpose -- this test only
# has to separate "landed" from "did not land".
LANDED_JUMP_U = 2000.0
# The id whose gate ENCLOSES this one.  Without it armed, `tpdying` is inert.
REQUIRED_PARTNER = 'tpcommit'


def tp_episodes(timeline, game, trip_floor):
    """Every completed, non-home TP landing in one game, with its outcome.

    A press is a `modifier_teleporting` MODIFIER_ADD on oneself; the matching
    MODIFIER_REMOVE is the channel ending -- either by landing or by being
    interrupted.  The two are told apart by where the hero is afterwards, not
    by any flag: only a completed teleport moves him.
    """
    fr, team = frames_by_hero(timeline)
    deaths = death_times(timeline)
    fount = fountains(timeline['snapshots'])

    adds = collections.defaultdict(list)
    removes = collections.defaultdict(list)
    for e in timeline['events']:
        if e.get('inflictor') != 'modifier_teleporting':
            continue
        if canon(e.get('target')) != canon(e.get('actor')):
            continue
        if e['type'] == 'MODIFIER_ADD':
            adds[canon(e['actor'])].append(e['t'])
        elif e['type'] == 'MODIFIER_REMOVE':
            removes[canon(e['actor'])].append(e['t'])
    for h in removes:
        removes[h].sort()

    out, dropped = [], 0
    for h, ts in adds.items():
        if h not in fr:
            # An illusion cannot press a TP scroll -- this is an entity the
            # dump did not let us key, so it is counted, not guessed at.
            dropped += 1
            continue
        frames = fr[h]
        for t in sorted(ts):
            s0 = interp(frames, t)
            if s0 is None:
                continue
            end_t = next((r for r in removes.get(h, ()) if r >= t), None)
            if end_t is None:
                continue
            # Landing POSITION: first sample STRICTLY AFTER the channel ended.
            # `>=` is wrong and was caught by the selfcheck's clean-landing
            # case: a sample landing exactly on the removal instant has not
            # necessarily resolved the teleport yet, so it reads the hero at
            # his DEPARTURE point -- trip 0 -- and the episode is then thrown
            # away as "interrupted".  On a ~1 Hz dump that silently deletes
            # every landing whose tick happens to coincide with the event.
            land = next((s for s in frames if s['t'] > end_t), None)
            if land is None:
                continue
            trip = math.dist((s0['x'], s0['y']), (land['x'], land['y']))
            if trip < LANDED_JUMP_U:
                continue                       # interrupted: never landed
            f = fount.get(team.get(h))
            if f is not None and math.dist((land['x'], land['y']), f) <= HOME_RADIUS_U:
                continue                       # went home: a retreat TP
            if trip < trip_floor:
                continue                       # under the defend branch's floor
            land_t = land['t']
            died = [d for d in deaths.get(h, ())
                    if land_t < d <= land_t + DEATH_WINDOW_S]
            pinned = {}
            for r in PIN_RADII_U:
                pinned[r] = sum(
                    1 for s in frames
                    if land_t < s['t'] <= land_t + COMMIT_WINDOW_S
                    and math.dist((s['x'], s['y']),
                                  (land['x'], land['y'])) <= r)
            # How far he had walked by the end of the commitment window -- the
            # same question detector (2) asks, read as a distance instead of a
            # count, so the two cannot agree by construction.
            sEnd = interp(frames, land_t + COMMIT_WINDOW_S)
            out.append(dict(
                game=game, hero=h, press_t=round(t, 1),
                land_t=round(land_t, 1), trip=round(trip),
                hp_at_land=round(land['hp_pct'], 3), level=land['level'],
                died_10s=bool(died),
                death_t=round(died[0], 1) if died else None,
                pinned=pinned,
                drift=(round(math.dist((sEnd['x'], sEnd['y']),
                                       (land['x'], land['y'])))
                       if sEnd is not None else None),
            ))
    return out, dropped


def scan_sweep(d, trip_floor):
    rows, dropped = [], 0
    manifest = {m['game']: m for m in load_sweep(d)}
    for p in sorted(glob.glob(os.path.join(d, 'timelines', '*.timeline.json'))):
        game = os.path.basename(p).replace('.timeline.json', '')
        m = manifest.get(game)
        if m is None:
            continue
        tl = json.load(open(p))
        eps, dr = tp_episodes(tl, game, trip_floor)
        dropped += dr
        for r in eps:
            r['seed'] = m['seed']
            # The PHYSICAL side the candidate build sat on: the stratum.
            r['arm_side'] = m['side']
            r['leg'] = 'armed' if (
                (m['side'] == 'radiant' and _team_of(tl, r['hero']) == 2)
                or (m['side'] == 'dire' and _team_of(tl, r['hero']) == 3)
            ) else 'baseline'
            rows.append(r)
    return rows, dropped


def _leg(rows, side, leg):
    return [r for r in rows if r['arm_side'] == side and r['leg'] == leg]


def by_seed(rows, pin_radius):
    """Per-seed swap-average -- the estimator that HAS no side bias left.

    WHY THIS EXISTS BESIDE THE PER-SIDE TABLE (iron rule 4(i-c), GH #329).
    The table above reports the two physical sides separately, and a sign
    split there is read as noise by 4(i-b).  That reading is correct for a raw
    per-side detector COUNT, and WRONG for this quantity: each seed carries
    both an ab and a ba game set, so `arm = (ab + ba) / 2` is a 50/50
    swap-average and the side bias is gone from it.  For such an estimator
    4(i-c) says in as many words that a stratum sign flip is NOT a rejection
    reason -- `ab*ba < 0` is exactly `|side| > |arm|`, an identity about this
    draw's side bias, not a statement about how well `arm` is measured.  What
    measures `arm` is its dispersion ACROSS SEEDS, which is what this prints.

    It is computed here, and never by hand, for the reason 4(i-d) gives: the
    six rounds that hand-computed the economy strata satisfied the rule with
    the wrong quantity.  Pooling is arithmetic across seeds -- NEVER weighted
    by landings or games, which is the `arm + side*(N_ab-N_ba)/(N_ab+N_ba)`
    trap that reads a +26.60 as +9.20 and looks like an ordinary number.
    """
    seeds = collections.defaultdict(lambda: collections.defaultdict(list))
    for r in rows:
        seeds[r['seed']][(r['arm_side'], r['leg'])].append(r)

    def metrics(g):
        drifts = [r['drift'] for r in g if r['drift'] is not None]
        return (sum(1 for r in g if r['died_10s']) / len(g),
                sum(r['pinned'][pin_radius] for r in g) / len(g),
                statistics.median(drifts) if drifts else None)

    names = ('death rate /landing (predict DOWN)',
             'pinned frames /landing (predict DOWN)',
             'median drift at +%.0fs (predict UP)' % COMMIT_WINDOW_S)
    want_down = (True, True, False)
    cols = [[], [], []]
    print('\nper-seed swap-average (4(i-c): side bias eliminated, so a stratum '
          'sign flip is NOT a rejection reason -- cross-seed dispersion is):')
    print('  %-7s %-38s %9s %9s %9s' % ('seed', 'quantity', 'ab', 'ba', 'arm'))
    for s in sorted(seeds):
        legs = {k: metrics(v) for k, v in seeds[s].items() if v}
        for i, nm in enumerate(names):
            vals = {}
            for side in ('radiant', 'dire'):
                a, b = legs.get((side, 'armed')), legs.get((side, 'baseline'))
                if a and b and a[i] is not None and b[i] is not None:
                    vals[side] = a[i] - b[i]
            if len(vals) != 2:
                continue
            arm = (vals['radiant'] + vals['dire']) / 2
            cols[i].append(arm)
            print('  %-7s %-38s %+9.4f %+9.4f %+9.4f'
                  % (s, nm, vals['radiant'], vals['dire'], arm))
    print('\n  %-38s %10s %8s' % ('quantity', 'mean arm', 'seeds ok'))
    for i, nm in enumerate(names):
        if not cols[i]:
            continue
        ok = sum(1 for a in cols[i] if (a < 0 if want_down[i] else a > 0))
        print('  %-38s %+10.4f %6d/%d' % (nm, sum(cols[i]) / len(cols[i]),
                                          ok, len(cols[i])))
    print('  (arithmetic mean across seeds -- NEVER weighted by landings or '
          'games, iron rule 4(i-d))')


def report(rows, label, pin_radius, arm_note):
    games = len({(r['game'], r['arm_side']) for r in rows})
    print('== %s -- tpdying condition (a), %d game-legs, %d landings =='
          % (label, games, len(rows)))
    print(arm_note)
    print('domain: completed, non-home TP landings with trip >= floor '
          '(the shipped defend TP\'s own 5000 u)')
    print('\n#148(i-a): BOTH strata are registered below, always -- the two '
          'physical sides are separate strata.')
    print('\n%-8s %-9s %7s %8s %9s %9s %9s'
          % ('stratum', 'leg', 'landings', 'died10s', 'death/ld',
             'pinnedfr', 'pin/ld'))
    agg = {}
    for side in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            g = _leg(rows, side, leg)
            if not g:
                continue
            d = sum(1 for r in g if r['died_10s'])
            p = sum(r['pinned'][pin_radius] for r in g)
            agg[(side, leg)] = (len(g), d, p)
            print('%-8s %-9s %7d %8d %9.3f %9d %9.2f'
                  % (side, leg, len(g), d, d / len(g), p, p / len(g)))

    print('\nleg delta per stratum (armed - baseline; #148(i-b): a sign flip '
          'across the two strata is noise and does NOT enter a conclusion):')
    deltas = {}
    for side in ('radiant', 'dire'):
        a, b = agg.get((side, 'armed')), agg.get((side, 'baseline'))
        if not a or not b:
            continue
        dd = (a[1] / a[0]) - (b[1] / b[0])
        dp = (a[2] / a[0]) - (b[2] / b[0])
        deltas[side] = (dd, dp)
        print('  %-8s  death-rate/landing %+.4f    pinned-frames/landing %+.3f'
              % (side, dd, dp))
    if len(deltas) == 2:
        (d1, p1), (d2, p2) = deltas['radiant'], deltas['dire']
        for name, x, y in (('death rate', d1, d2),
                           ('pinned frames', p1, p2)):
            flip = (x > 0) != (y > 0) and x != 0 and y != 0
            print('  %-15s strata agree: %-5s%s'
                  % (name, 'no' if flip else 'yes',
                     '   <- #148(i-b): noise, not a reading' if flip else ''))

    print('\npin-radius sensitivity (pinned frames per landing):')
    print('  %-8s %-9s %s'
          % ('stratum', 'leg', '  '.join('r=%d' % r for r in PIN_RADII_U)))
    for side in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            g = _leg(rows, side, leg)
            if not g:
                continue
            print('  %-8s %-9s %s'
                  % (side, leg,
                     '  '.join('%5.2f' % (sum(r['pinned'][r2] for r in g)
                                          / len(g)) for r2 in PIN_RADII_U)))

    by_seed(rows, pin_radius)

    drifts = [r['drift'] for r in rows if r['drift'] is not None]
    if drifts:
        print('\ndrift at +%.0f s (independent of the pin count, same '
              'question): median %.0f u over %d landings'
              % (COMMIT_WINDOW_S, statistics.median(drifts), len(drifts)))
        for side in ('radiant', 'dire'):
            for leg in ('armed', 'baseline'):
                g = [r['drift'] for r in _leg(rows, side, leg)
                     if r['drift'] is not None]
                if g:
                    print('  %-8s %-9s median %6.0f u  (n=%d)'
                          % (side, leg, statistics.median(g), len(g)))

    if DROPPED_ENTITIES:
        print('\nentities dropped by the GH #176 keying: %d name(s), %d total'
              % (len(DROPPED_ENTITIES), sum(DROPPED_ENTITIES.values())))


# ---------------------------------------------------------------- selfcheck

def _mk(hero, pts, team=2, idx=1, hp=1.0, level=10):
    return [dict(t=t, hero=hero, idx=idx, team=team, player_id=idx, x=x, y=y,
                 hp=600, hp_pct=hp, mp=300, max_mp=300, mp_pct=1.0,
                 level=level, items=[], abilities=[], tp_cd=0, tp_cdlen=0,
                 net_worth=1000)
            for (t, x, y) in pts]


def _tl(snaps, events, game='g'):
    return dict(game=game, snapshots=snaps, events=events,
                buildings=[], creeps=[], wards=[])


def _tp(hero, t, kind='MODIFIER_ADD'):
    return dict(type=kind, t=t, actor=hero, target=hero,
                inflictor='modifier_teleporting')


def _death(hero, t):
    return dict(type='DEATH', t=t, actor='x', target=hero, target_hero=True)


def selfcheck():
    ran, fails = [], []

    def chk(name, cond, detail=''):
        ran.append(name)
        if not cond:
            fails.append(name)
        # stderr on purpose: tests/mock/bot_api.lua's install() blanks `print`
        # and a stand that writes to stdout can come back empty with exit 0,
        # which looks exactly like "ran, found nothing" (charter 2026-09-06,
        # GH #546).  Same family as evidence-discipline 3.
        sys.stderr.write('%-4s %s %s\n'
                         % ('PASS' if cond else 'FAIL', name, detail))

    H = 'npc_dota_hero_lion'
    # A clean response landing: presses at (0,0) t=10, channel ends t=13,
    # lands 6000 u away, stands there for the whole window.
    home = _mk(H, [(-60, 0, 0), (-59, 0, 0)])
    walk = _mk(H, [(t, 0.0, 0.0) for t in (8, 9, 10, 11, 12, 13)])
    stay = _mk(H, [(t, 6000.0, 0.0) for t in range(14, 30)])
    snaps = home + walk + stay
    tl = _tl(snaps, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE')])
    eps, dr = tp_episodes(tl, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('a completed long non-home TP is one landing', len(eps) == 1,
        '%d episode(s)' % len(eps))
    chk('landing time comes from MODIFIER_REMOVE, not press+constant',
        eps and eps[0]['land_t'] == 14.0, 'land_t=%s' % (eps[0]['land_t'] if eps else None))
    chk('trip is press-to-landing distance',
        eps and eps[0]['trip'] == 6000, 'trip=%s' % (eps[0]['trip'] if eps else None))
    chk('a hero that never moves is pinned for the whole window',
        eps and eps[0]['pinned'][DEFAULT_PIN_RADIUS_U] == 12,
        'pinned=%s' % (eps[0]['pinned'][DEFAULT_PIN_RADIUS_U] if eps else None))
    chk('no death event => died_10s is False', eps and eps[0]['died_10s'] is False)
    chk('no entity dropped on a clean game', dr == 0)

    # THE RELEASE SHAPE: same landing, but the hero walks away immediately.
    away = _mk(H, [(t, 6000.0 + 400.0 * (t - 13), 0.0) for t in range(14, 30)])
    tl2 = _tl(home + walk + away, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE')])
    eps2, _ = tp_episodes(tl2, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('a released (walking) lander counts FEWER pinned frames',
        eps2 and eps2[0]['pinned'][DEFAULT_PIN_RADIUS_U]
        < eps[0]['pinned'][DEFAULT_PIN_RADIUS_U],
        '%s vs %s' % (eps2[0]['pinned'][DEFAULT_PIN_RADIUS_U] if eps2 else None,
                      eps[0]['pinned'][DEFAULT_PIN_RADIUS_U]))
    chk('drift separates the two shapes independently of the pin count',
        eps2 and eps and eps2[0]['drift'] > eps[0]['drift'],
        '%s vs %s' % (eps2[0]['drift'] if eps2 else None, eps[0]['drift']))

    # An INTERRUPTED channel never lands and must not enter the domain.
    stuck = _mk(H, [(t, 0.0, 0.0) for t in range(14, 30)])
    tl3 = _tl(home + walk + stuck, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE')])
    eps3, _ = tp_episodes(tl3, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('an interrupted channel is not a landing', eps3 == [], '%d' % len(eps3))

    # A RETREAT TP lands in the bot's own fountain and must be excluded: the
    # response branches never go home, and the pin is only ever stamped by them.
    fh = _mk(H, [(-60, -6600.0, -6300.0), (-59, -6600.0, -6300.0)])
    fwalk = _mk(H, [(t, 0.0, 0.0) for t in (8, 9, 10, 11, 12, 13)])
    fstay = _mk(H, [(t, -6600.0, -6300.0) for t in range(14, 30)])
    tl4 = _tl(fh + fwalk + fstay, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE')])
    eps4, _ = tp_episodes(tl4, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('a TP home is a retreat, not a response landing', eps4 == [],
        '%d' % len(eps4))

    # A landing SHORTER than the defend branch's own floor is out of domain.
    near = _mk(H, [(t, 3000.0, 0.0) for t in range(14, 30)])
    tl5 = _tl(home + walk + near, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE')])
    eps5, _ = tp_episodes(tl5, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('a trip under the 5000 u floor is out of domain', eps5 == [],
        '%d' % len(eps5))
    eps5b, _ = tp_episodes(tl5, 'g', 2500.0)
    chk('...and the floor is the only thing keeping it out', len(eps5b) == 1)

    # DETECTOR (1) is anchored on DEATH EVENTS -- inside and outside the window.
    tl6 = _tl(snaps, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE'),
                      _death(H, 20.0)])
    eps6, _ = tp_episodes(tl6, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('a death 6 s after landing is inside the 10 s window',
        eps6 and eps6[0]['died_10s'] is True)
    tl7 = _tl(snaps, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE'),
                      _death(H, 26.0)])
    eps7, _ = tp_episodes(tl7, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('a death 12 s after landing is outside it', eps7 and eps7[0]['died_10s'] is False)
    tl8 = _tl(snaps, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE'),
                      _death(H, 12.0)])
    eps8, _ = tp_episodes(tl8, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('a death DURING the channel is not a landing death',
        eps8 and eps8[0]['died_10s'] is False,
        'the channel death census is tp_channel_death.py, not this file')

    # GH #176 ①: an illusion sharing the hero's NAME must not create or move a
    # landing.  It appears post-horn, so frames_by_hero drops it; the real
    # hero's episode must survive byte-identically.
    illu = _mk(H, [(t, 500.0, 500.0) for t in range(14, 30)], idx=99)
    tl9 = _tl(snaps + illu, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE')])
    eps9, _ = tp_episodes(tl9, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('a post-horn twin does not disturb the landing',
        len(eps9) == 1 and eps9[0]['pinned'] == eps[0]['pinned'],
        'pinned=%s' % (eps9[0]['pinned'] if eps9 else None))

    # Wraith King reincarnates IN PLACE (charter 2026-08-21): a death-detector
    # that required a jump to the fountain would miss him.  Ours reads events.
    WK = 'npc_dota_hero_skeleton_king'
    wsn = (_mk(WK, [(-60, 0, 0), (-59, 0, 0)])
           + _mk(WK, [(t, 0.0, 0.0) for t in (8, 9, 10, 11, 12, 13)])
           + _mk(WK, [(t, 6000.0, 0.0) for t in range(14, 30)]))
    tlw = _tl(wsn, [_tp(WK, 10.0), _tp(WK, 13.0, 'MODIFIER_REMOVE'),
                    _death(WK, 18.0)])
    epsw, _ = tp_episodes(tlw, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('an in-place reincarnation is still a death (event-anchored)',
        epsw and epsw[0]['died_10s'] is True)

    # The pin radius must actually bind.  He LANDS at 6000 (t=14, the first
    # sample after the channel) and is 1000 u away from there for the rest of
    # the window -- so r=800 must exclude exactly what r=1200 keeps.
    mid = (_mk(H, [(14, 6000.0, 0.0)])
           + _mk(H, [(t, 7000.0, 0.0) for t in range(15, 30)]))
    tlm = _tl(home + walk + mid, [_tp(H, 10.0), _tp(H, 13.0, 'MODIFIER_REMOVE')])
    epsm, _ = tp_episodes(tlm, 'g', DEFAULT_TRIP_FLOOR_U)
    chk('r=800 excludes what r=1200 includes',
        epsm and epsm[0]['pinned'][800.0] == 0 and epsm[0]['pinned'][1200.0] > 0,
        'r800=%s r1200=%s' % (epsm[0]['pinned'][800.0] if epsm else None,
                              epsm[0]['pinned'][1200.0] if epsm else None))

    # SOURCE PINS -- these fail the day the lever moves under the tool.
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            '..', '..', '..', 'bots', 'FunLib',
                            'jmz_func.lua')).read()
    chk('tpdying is still gated and still turbo-only',
        "J.IsSoakCandidate( 'tpdying' )" in src)
    chk('tpdying still sits INSIDE the tpcommit gate',
        src.index("if not J.IsSoakCandidate( 'tpcommit' ) then return nil end")
        < src.index("if J.IsSoakCandidate( 'tpdying' )"),
        'the enclosing gate is what makes --assert-arm necessary')
    chk('the commitment window is still 12 s',
        'DotaTime() + 12.0' in open(
            os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         '..', '..', '..', 'bots',
                         'ability_item_usage_generic.lua')).read())
    chk('the defend TP floor is still 5500',
        'nMinTPDistance = 5500' in open(
            os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         '..', '..', '..', 'bots',
                         'ability_item_usage_generic.lua')).read())
    chk('tpdying can only RELEASE (it returns nil, never a desire)',
        "and J.IsIncomingBurstLethal( bot, 3.0 ) then" in src
        and src.split("and J.IsIncomingBurstLethal( bot, 3.0 ) then")[1]
               .split('end')[0].strip().endswith('return nil'))

    sys.stderr.write('\n%d PASS / %d FAIL\n' % (len(ran) - len(fails), len(fails)))
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*', help='sweep_run.sh output dirs')
    ap.add_argument('--label', default='wave')
    ap.add_argument('--trip-floor', type=float, default=DEFAULT_TRIP_FLOOR_U)
    ap.add_argument('--pin-radius', type=float, default=DEFAULT_PIN_RADIUS_U,
                    choices=PIN_RADII_U)
    ap.add_argument('--assert-arm', default=None,
                    help='the wave arm string; refuses to read a wave in '
                         'which `tpcommit` is not armed, because `tpdying` '
                         'is then a byte-for-byte no-op')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--out', default=None)
    args = ap.parse_args()

    if args.selfcheck:
        sys.exit(selfcheck())

    arm_note = ('arm string NOT supplied: reachability unverified -- a zero '
                'delta below could be "no effect" OR "tpcommit not armed"')
    if args.assert_arm is not None:
        ids = {s.strip() for s in args.assert_arm.split(',') if s.strip()}
        if REQUIRED_PARTNER not in ids:
            sys.exit('[fatal] `%s` is NOT in the arm string, so `tpdying` is '
                     'byte-for-byte inert in this wave -- there is no (a) to '
                     'buy here.  Refusing to print a clean-looking zero.'
                     % REQUIRED_PARTNER)
        if 'tpdying' not in ids:
            sys.exit('[fatal] `tpdying` is not in the arm string either.')
        arm_note = ('reachability VERIFIED: both `tpdying` and its enclosing '
                    '`%s` gate are armed in this wave (%d ids)'
                    % (REQUIRED_PARTNER, len(ids)))

    rows, dropped = [], 0
    for d in args.sweeps:
        r, dr = scan_sweep(d, args.trip_floor)
        rows += r
        dropped += dr
    if not rows:
        print('no response-TP landings found under: %s' % ' '.join(args.sweeps))
        return
    report(rows, args.label, args.pin_radius, arm_note)
    if dropped:
        print('\npresses keyed to a dropped entity (counted, not invented): %d'
              % dropped)
    if args.out:
        with open(args.out, 'w') as fh:
            for r in rows:
                fh.write(json.dumps(
                    {k: (v if k != 'pinned'
                         else {str(kk): vv for kk, vv in v.items()})
                     for k, v in r.items()}) + '\n')
        print('\nwrote %d landings -> %s' % (len(rows), args.out))


if __name__ == '__main__':
    main()
