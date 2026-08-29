#!/usr/bin/env python3
"""`campvoid` condition (a): does the lane-creep escape actually open?

WHY THIS FILE EXISTS
--------------------
`campvoid` (GH #265, strategy 2026-08-28) wraps ONE read in
`bots/mode_farm_generic.lua`:

    local nNeutrals = NeutralPresenceList(bot, bot:GetNearbyNeutralCreeps(nSearchRange));
    if J.IsValid(farmTarget) and #nNeutrals == 0 then   -- go hit a lane creep

`NeutralPresenceList` runs `J.Site.FilterFarmNeutrals`, which DROPS ancient
creeps when the bot is below `ANCIENT_MIN_LEVEL`.  The lever is monotone: the
filter can only REMOVE entries, so `#nNeutrals == 0` can only flip false ->
true, and the armed leg can only ever OPEN that escape.  The state it exists
to dissolve is a deadlock: with `campfarm` armed an under-tier bot standing in
an ancient camp may not ATTACK the camp, while this unfiltered PRESENCE list
still counts the very ancients `campfarm` dropped and holds the escape SHUT --
nothing to hit and no reason to leave.

WHAT THIS TOOL CAN AND CANNOT SEE (read this before quoting any number)
----------------------------------------------------------------------
The dumper emits hero snapshots, buildings, wards, couriers and a combat log.
It emits NO creep entities: `dumper/main.go` keeps a combat-log entry only
when at least one side is a hero, and there is no creep snapshot type at all.

  => `bot:GetNearbyNeutralCreeps(nSearchRange)` and `bot:GetNearbyLaneCreeps(900)`
     are BOTH structurally unreadable offline.  NEITHER CONJUNCT OF THE GATE
     CAN BE EVALUATED ON THIS CORPUS.

So this file does NOT buy the trigger-level evidence replay-check's charter
§4a asks for ("`#nNeutrals` becomes 0 BECAUSE OF the filter, and the lane exit
was really walked").  It buys the closest observable thing: the CONSEQUENCE
the escape must produce if it fires, plus its counterfactual.  That is stated
here so no downstream reader can mistake one for the other.

THE EPISODE
-----------
A maximal run of 1 Hz frames on which a bot hero is

  * alive by BRACKETING samples (GH #176: an interpolated hp_pct blends a live
    frame with a death frame and answers 0.05 > 0),
  * a real hero, not an illusion (entities.frames_by_hero),
  * level <= ANCIENT_MIN_LEVEL - 1, the band in which FilterFarmNeutrals bites,
  * within --in-camp of an ANCIENT-camp centroid, and
  * with no enemy hero inside --fight-near (an ancient-camp trade with a hero
    on top of it is a fight, not a farm decision).

The camp centroids are derived from THIS corpus (hero standing positions on
hero<->ancient DAMAGE rows, clustered), never typed in, and the two-cluster /
|x| >= 3500 tier property `ancient_camp_domain` established is asserted.

POSITIONAL PROXY, AND WHICH WAY IT LEANS
----------------------------------------
"Hero within R of the camp centroid" is a proxy for "a neutral is inside
nSearchRange = min(GetAttackRange()+180, 1600)".  It is not a clean subset or
superset: the centroid is the mean standing position of heroes TRADING with
the camp, so it already carries their attack range, and R=600 is generous for
a 330 u melee sweep and tight for a 780 u ranged one.  --in-camp is therefore
swept (400 / 600 / 800) and all three printed; a reading that only survives at
one radius is not a reading.

EPISODE OUTCOMES
----------------
  trade_anc  -- the hero dealt DAMAGE to an ANCIENT during the episode.  He
                could attack the camp, so no deadlock.  This share is a JOINT
                `campfarm`+`campvoid` reading (campfarm owns the attack list)
                and is NOT attributed to campvoid.
  trade_norm -- he dealt DAMAGE to a NON-ancient neutral and to no ancient.
                Also not a deadlock: he had something to hit.
  escape     -- NO neutral trade of any kind, and within --escape-w of the
                last in-camp frame the hero dealt DAMAGE to an enemy LANE
                creep.  This is the shape :752's escape produces and the ONLY
                outcome campvoid can author: `campfarm` empties an attack
                list, it has no branch that walks a bot to a lane creep.
  left       -- no neutral trade, no lane-creep contact, but the hero was >
                --left-r from the centroid within --escape-w (he moved off for
                some other reason: a mode change, a regroup, a pull).
  stuck      -- none of the above.  The GH #265 photograph: standing in the
                box with nothing to hit and no reason to go.

⚠️ WHY `trade_norm` EXISTS -- A FALSE POSITIVE CAUGHT FRAME BY FRAME
---------------------------------------------------------------------
The first cut of this file asked only about ANCIENT damage, and on W25
`6df84c/20260829_124418_slot1` it reported a 27 s `stuck` episode: vengeful
spirit, level 10, hp 1.000 -> 0.704, motionless at (-5005, -68), 592 u from
the derived ancient centroid.  The frames say the opposite of a deadlock:
from t=758.1 to t=782.9 she is farming a NORMAL camp inside that radius --
`wave_of_terror` on `ice_shaman` + two `frostbitten_golem`, then ~90-damage
autoattacks every 0.7 s, three neutral DEATH rows credited to her, +180/+88/
+162 gold.  She had plenty to attack; she was never stuck.

A normal camp box sits well inside 600 u of the ancient one, and a positional
proxy cannot tell them apart.  So the deadlock test is NOT "no ancient damage"
but "NO OWN DAMAGE TO ANY NEUTRAL", which is exactly what GH #265's photograph
asserted ("ZERO damage events of its own").  The selfcheck pins that episode's
shape so this cannot regress.

⚠️ AND WHY `escape` IS REACHABILITY-CAPPED -- THE SECOND FALSE POSITIVE
------------------------------------------------------------------------
Same corpus, `6df84c/20260829_123218_slot8`: crystal maiden, level 10, sat at
(-4277, -183) -- 568 u from the ancient centroid -- from t=594.4 to t=598.4
and then hit `npc_dota_creep_badguys_ranged` at t=603.8.  The first cut called
that an ESCAPE, i.e. campvoid's own signature.  The frames say she TELEPORTED:
`ITEM item_tpscroll` at t=593.6 and the very next sample, t=599.4, puts her at
(4025, -6211) -- **10,417 u away, on the other side of the map**.  The creep
she hit was never within `GetNearbyLaneCreeps(900)` of the camp.

The escape at :752 is a local order on a creep the 900 u sweep already found,
so a contact is only campvoid-shaped if the hero could have WALKED there:
`900 + 550 u/s * escape_w`.

⚠️ AND WHY THE CONTACT MUST BE AN AUTO-ATTACK -- THE THIRD FALSE POSITIVE
--------------------------------------------------------------------------
W26 `8d47de/20260829_184550_slot1`, and this one was on the BASELINE leg,
where campvoid is gate-OFF and cannot fire at all: oracle, level 11, crossed
the camp box t=895.5-898.5 and then "hit a lane creep" at t=901.7.  The frames
say it was a TEAMFIGHT -- he was mid-`oracle_purifying_flames` on an ally
viper, took 217 from `dragon_knight_breathe_fire` at t=900.8, and the lane-
creep rows are `oracle_fortunes_end` SPLASH on a flagbearer and a melee creep
while he cast at skeleton king.  The enemy heroes arrived AFTER the episode
closed, so FIGHT_NEAR could not see them.

:752 issues `Action_AttackUnit(farmTarget, true)`, and the combat log writes a
bare attack with no named inflictor -- so only `dota_unknown` rows count.

All three false positives are one mistake in three costumes: reading an
OUTCOME as a MECHANISM without asking whether that mechanism could physically
have produced it.  Every one of them was caught by looking at the frames and
none of them by looking at the table -- which is the charter's hard rule
(先逐帧后聚合) paying rent three times in one round.

ATTRIBUTION (charter §4a)
-------------------------
`campfarm` and `campvoid` are armed in the same 44-id string, so the armed leg
carries both.  The split THIS file reports as campvoid's is the escape share
INSIDE the non-traded population -- the population campfarm creates but cannot
resolve.  That is an argument, not a trigger count, and the report says so.

铁律 4(i): every leg number is given in both physical strata (ab = armed on
radiant, ba = armed on dire); a quantity whose two strata disagree in sign is
noise and is not carried into a conclusion.
铁律 4(ii): small-integer counts are reported as means plus a share above a
threshold, never as a lone median.

Read-only.  No AWS spend, no bot Lua touched.

Usage:
    campvoid_escape.py <sweep_dir> [<sweep_dir> ...] [--out recs.jsonl]
    campvoid_escape.py --selfcheck
"""
import argparse
import json
import math
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402
from ancient_camp_domain import (  # noqa: E402
    ANCIENT_CLUSTER_MAX_ABS_Y, ANCIENT_CLUSTER_MIN_ABS_X, cluster_points,
    is_ancient, is_hero, load)
from creeppull_domain import DIRE, RADIANT, load_sweep  # noqa: E402
from source_constants import assignment  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..', '..'))
ABA_SITE = os.path.join(REPO, 'bots', 'FunLib', 'aba_site.lua')

# Never copied -- read out of the shipped Lua (source_constants contract).
ANCIENT_MIN_LEVEL = int(assignment('____exports.ANCIENT_MIN_LEVEL', ABA_SITE))
BAND_MAX = ANCIENT_MIN_LEVEL - 1          # the levels the filter bites at

LANE_RE = re.compile(r'^npc_dota_creep_(goodguys|badguys)_')

IN_CAMP_SWEEP = (400.0, 600.0, 800.0)
IN_CAMP_PRIMARY = 600.0
FIGHT_NEAR = 1500.0        # enemy hero this close => it is a fight
ESCAPE_W = 6.0             # seconds after the last in-camp frame
LEFT_R = 1200.0            # "he walked off" radius
# The escape at :752 is a LOCAL order -- Action_MoveToLocation(farmTarget) or
# Action_AttackUnit -- on a creep that `GetNearbyLaneCreeps(900)` already found
# inside 900 u.  A hero cannot outrun 550 u/s (the engine's movespeed cap), so
# in --escape-w seconds the contact point cannot be further than this from the
# last in-camp frame.  Without the cap a TELEPORT reads as an escape: see the
# second false positive pinned in the selfcheck.
MAX_MS = 550.0
LANE_SWEEP_R = 900.0
# The escape's action is `Action_AttackUnit(farmTarget, true)` -- a bare
# auto-attack, which the combat log writes with no named inflictor.  An AoE
# spell that happens to splash a lane creep is NOT that order (see the third
# false positive in the header), so only this marker counts.  Same constant
# campfarm_target.ATTACK_INFLICTOR uses for the same distinction.
ATTACK_INFLICTOR = 'dota_unknown'
MIN_FRAMES = 3             # >= 3 s in the box; a pass-through is not a decision
CLUSTER_R = 900.0
CENTROID_MIN_HITS = 8
# Share of all ancient-trade samples a cluster must carry to be a CAMP rather
# than a drifting fight.  Measured on W25 run 6df84c: the two real boxes hold
# 2084 and 1247 samples, the third-largest 88 -- a 15x gap, so any cut in
# [0.03, 0.3] gives the same two.  campfarm_target uses 0.05 for the same
# quantity; kept identical so the two files cannot drift apart silently.
ANC_SUPPORT = 0.05
# Normal camps are ~18 unequal boxes, so their support cut is an order of
# magnitude looser -- same split campfarm_target uses, kept identical.
NORM_SUPPORT = 0.01
WARMUP_GAMES = 10          # games used to derive the centroids


def is_lane_creep(name):
    return bool(LANE_RE.match(name))


def keep_supported(clusters, frac=ANC_SUPPORT):
    """Drop clusters that carry less than `frac` of all samples.

    A chase or a drifting fight leaves a handful of hero<->ancient rows a long
    way from the box; without this cut those tails are indistinguishable from
    camps by count, and the tier geometry test then fails on a cluster that
    was never a camp.  Returns (kept, dropped_samples, total_samples)."""
    tot = sum(c[2] for c in clusters)
    kept = [c for c in clusters if tot and c[2] >= frac * tot]
    return kept, tot - sum(c[2] for c in kept), tot


def camp_centroids(paths, min_hits=CENTROID_MIN_HITS):
    """Ancient AND normal camp boxes, derived from where heroes stand when
    they trade with each kind.  Returns (ancient_clusters, normal_clusters),
    each [(x, y, n), ...] sorted by support."""
    anc, norm = [], []
    for p in paths:
        tl = load(p)
        fr, _ = entities.frames_by_hero(tl)
        for e in tl['events']:
            if e['type'] != 'DAMAGE':
                continue
            a, tg = e['actor'], e['target']
            if is_hero(a) and tg.startswith('npc_dota_neutral'):
                h, n = a, tg
            elif a.startswith('npc_dota_neutral') and is_hero(tg):
                h, n = tg, a
            else:
                continue
            s = entities.interp(fr.get(entities.canon(h)) or [], e['t'])
            if s:
                (anc if is_ancient(n) else norm).append((s['x'], s['y']))
    keep = lambda pts: [c for c in cluster_points(pts, CLUSTER_R)
                        if c[2] >= min_hits]
    return keep(anc), keep(norm)


def ancient_centroids(paths, min_hits=CENTROID_MIN_HITS):
    return camp_centroids(paths, min_hits)[0]


def nearest_normal(anc, norm):
    """For each ancient box, the distance to the nearest NORMAL camp box.

    This is the number that decides whether a positional ancient/normal test
    is possible at all.  On W25 it is 146 u and 338 u -- i.e. it is NOT."""
    out = []
    for cx, cy, n in anc:
        best = min((math.dist((cx, cy), (x, y)), x, y, k) for x, y, k in norm) \
            if norm else None
        out.append(((cx, cy, n), best))
    return out


def centroids_are_ancient_tier(cs):
    """The geometric tier test ancient_camp_domain established: every kept
    cluster sits far out on x and near the river band on y."""
    return bool(cs) and all(abs(x) >= ANCIENT_CLUSTER_MIN_ABS_X
                            and abs(y) <= ANCIENT_CLUSTER_MAX_ABS_Y
                            for x, y, _ in cs)


def _near(x, y, cs, r):
    for cx, cy, _ in cs:
        if math.dist((x, y), (cx, cy)) <= r:
            return (cx, cy)
    return None


def scan_game(tl, cs, in_camp=IN_CAMP_PRIMARY, escape_w=ESCAPE_W,
              fight_near=FIGHT_NEAR, min_frames=MIN_FRAMES, left_r=LEFT_R):
    """Episodes for one game.  `cs` = ancient centroids."""
    fr, team = entities.frames_by_hero(tl)
    deaths = entities.death_times(tl)

    # Damage rows keyed by the hero who authored / received them.
    anc_hit = defaultdict(list)     # hero -> [t] hero DEALT damage to an ancient
    norm_hit = defaultdict(list)    # hero -> [t] hero DEALT damage to any other neutral
    lane_hit = defaultdict(list)    # hero -> [t] hero DEALT damage to a lane creep
    killed_by_neutral = defaultdict(list)
    for e in tl['events']:
        if e['type'] != 'DAMAGE':
            continue
        a, tg = e['actor'], e['target']
        if is_hero(a) and tg.startswith('npc_dota_neutral'):
            (anc_hit if is_ancient(tg) else norm_hit)[entities.canon(a)].append(e['t'])
        elif (is_hero(a) and is_lane_creep(tg)
              and e.get('inflictor') == ATTACK_INFLICTOR):
            lane_hit[entities.canon(a)].append(e['t'])
        elif a.startswith('npc_dota_neutral') and is_hero(tg):
            killed_by_neutral[entities.canon(tg)].append(e['t'])

    out = []
    for h, frames in fr.items():
        if not frames:
            continue
        hteam = team[h]
        run = []
        for s in frames:
            t = s['t']
            ok = (s['hp_pct'] > 0 and s['level'] <= BAND_MAX
                  and _near(s['x'], s['y'], cs, in_camp) is not None
                  and entities.alive_interp(frames, t, deaths.get(h)) is not None)
            if ok:
                # an enemy hero on top of the camp makes this a fight
                for o, ofr in fr.items():
                    if o == h or team[o] == hteam:
                        continue
                    os_ = entities.alive_interp(ofr, t, deaths.get(o))
                    if os_ and math.dist((s['x'], s['y']),
                                         (os_['x'], os_['y'])) <= fight_near:
                        ok = False
                        break
            if ok:
                run.append(s)
            elif run:
                ep = _close(h, hteam, run, anc_hit, norm_hit, lane_hit,
                            killed_by_neutral, cs, escape_w, min_frames,
                            left_r, frames, deaths)
                if ep:
                    out.append(ep)
                run = []
        if run:
            ep = _close(h, hteam, run, anc_hit, norm_hit, lane_hit,
                        killed_by_neutral, cs, escape_w, min_frames,
                        left_r, frames, deaths)
            if ep:
                out.append(ep)
    return out


def _close(h, hteam, run, anc_hit, norm_hit, lane_hit, killed_by_neutral, cs,
           escape_w, min_frames, left_r, frames, deaths):
    if len(run) < min_frames:
        return None
    t0, t1 = run[0]['t'], run[-1]['t']
    anc = any(t0 - 1.0 <= t <= t1 + 1.0 for t in anc_hit.get(h, ()))
    norm = any(t0 - 1.0 <= t <= t1 + 1.0 for t in norm_hit.get(h, ()))
    # REACHABILITY: the contact must be somewhere he could have WALKED to.
    reach = LANE_SWEEP_R + MAX_MS * escape_w
    x1, y1 = run[-1]['x'], run[-1]['y']
    lane, lane_far = [], 0
    for t in lane_hit.get(h, ()):
        if not (t1 < t <= t1 + escape_w):
            continue
        s_at = entities.alive_interp(frames, t, deaths.get(h))
        if s_at is None:
            continue
        if math.dist((x1, y1), (s_at['x'], s_at['y'])) <= reach:
            lane.append(t)
        else:
            lane_far += 1
    died = any(t1 - 1.0 <= t <= t1 + escape_w for t in killed_by_neutral.get(h, ()))
    # did he physically leave the box within the window?
    left = False
    for s in frames:
        if t1 < s['t'] <= t1 + escape_w:
            c = _near(s['x'], s['y'], cs, left_r)
            if c is None:
                left = True
                break
    if anc:
        outcome = 'trade_anc'
    elif norm:
        outcome = 'trade_norm'
    elif lane:
        outcome = 'escape'
    elif left:
        outcome = 'left'
    else:
        outcome = 'stuck'
    return {
        'hero': h, 'team': hteam, 't0': t0, 't1': t1, 'dur': t1 - t0,
        'frames': len(run), 'level0': run[0]['level'],
        'hp0': run[0]['hp_pct'], 'hp1': run[-1]['hp_pct'],
        'hp_burn': run[0]['hp_pct'] - run[-1]['hp_pct'],
        'outcome': outcome, 'died_to_neutral': died,
        'traded_any': bool(anc or norm),
        'lane_unreachable': lane_far,
        'x0': run[0]['x'], 'y0': run[0]['y'],
    }


def leg_of(hteam, armed_side):
    armed = RADIANT if armed_side == 'radiant' else DIRE
    return 'armed' if hteam == armed else 'baseline'


def stratum_of(armed_side):
    return 'ab' if armed_side == 'radiant' else 'ba'


def aggregate(recs):
    """cell -> counts.  cell = (stratum, leg)."""
    cells = defaultdict(lambda: defaultdict(float))
    for r in recs:
        c = cells[(r['stratum'], r['leg'])]
        c['episodes'] += 1
        c[r['outcome']] += 1
        c['dur_sum'] += r['dur']
        c['burn_sum'] += r['hp_burn']
        if r['died_to_neutral']:
            c['died'] += 1
            if r['outcome'] not in ('trade_anc', 'trade_norm'):
                c['died_nontraded'] += 1
        if r['dur'] >= 10.0:
            c['dur_ge10'] += 1
    return cells


def pct(n, d):
    return '%.1f%%' % (100.0 * n / d) if d else 'n/a'


def report(recs, games_by_cell, in_camp):
    cells = aggregate(recs)
    print()
    print('== in-camp radius %.0f u, band level <= %d, episode >= %d frames =='
          % (in_camp, BAND_MAX, MIN_FRAMES))
    hdr = ('%-14s %6s %6s %11s %11s %10s %9s %9s %9s'
           % ('cell', 'games', 'episod', 'trade_anc', 'trade_norm', 'escape',
              'left', 'stuck', 'mean_dur'))
    print(hdr)
    print('-' * len(hdr))
    for st in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            c = cells.get((st, leg))
            g = games_by_cell.get((st, leg), 0)
            if not c:
                print('%-14s %6d %6d %11s %11s %10s %9s %9s %9s'
                      % ('%s/%s' % (st, leg), g, 0, '-', '-', '-', '-', '-',
                         'n=0'))
                continue
            n = c['episodes']
            print('%-14s %6d %6d %11s %11s %10s %9s %9s %9.1f'
                  % ('%s/%s' % (st, leg), g, n,
                     '%d (%s)' % (c['trade_anc'], pct(c['trade_anc'], n)),
                     '%d (%s)' % (c['trade_norm'], pct(c['trade_norm'], n)),
                     '%d (%s)' % (c['escape'], pct(c['escape'], n)),
                     '%d (%s)' % (c['left'], pct(c['left'], n)),
                     '%d (%s)' % (c['stuck'], pct(c['stuck'], n)),
                     c['dur_sum'] / n))
    print()
    print('nothing-to-hit population (zero own damage to ANY neutral) -- '
          'the only split campvoid can author:')
    for st in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            c = cells.get((st, leg))
            if not c:
                print('  %-12s n=0' % ('%s/%s' % (st, leg)))
                continue
            nt = c['episodes'] - c['trade_anc'] - c['trade_norm']
            print('  %-12s non-traded %3d  escape %3d (%s)  stuck %3d (%s)  '
                  'died_to_neutral %d/%d (nothing-to-hit/all)'
                  % ('%s/%s' % (st, leg), nt, c['escape'], pct(c['escape'], nt),
                     c['stuck'], pct(c['stuck'], nt),
                     c['died_nontraded'], c['died']))


def _mk_tl(snaps, events):
    return {'snapshots': snaps, 'events': events, 'buildings': [],
            'wards': [], 'couriers': []}


def _snap(t, hero, idx, team, x, y, level=10, hp=1.0):
    return {'t': t, 'hero': hero, 'idx': idx, 'team': team, 'x': x, 'y': y,
            'hp': 500, 'hp_pct': hp, 'mp': 100, 'max_mp': 200, 'mp_pct': 0.5,
            'level': level, 'items': [], 'abilities': [], 'tp_cd': 0.0,
            'tp_cdlen': 0.0, 'net_worth': 1000, 'player_id': idx}


def _dmg(t, actor, target, value=30, infl=ATTACK_INFLICTOR):
    return {'t': t, 'type': 'DAMAGE', 'actor': actor, 'target': target,
            'inflictor': infl, 'value': value,
            'actor_hero': is_hero(actor), 'target_hero': is_hero(target)}


def selfcheck():
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-46s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    chk('ANCIENT_MIN_LEVEL read from aba_site.lua', ANCIENT_MIN_LEVEL == 12,
        'got %r' % ANCIENT_MIN_LEVEL)
    chk('band top is one below the tier', BAND_MAX == ANCIENT_MIN_LEVEL - 1)
    chk('lane classifier: badguys melee', is_lane_creep('npc_dota_creep_badguys_melee'))
    chk('lane classifier: goodguys flagbearer',
        is_lane_creep('npc_dota_creep_goodguys_flagbearer'))
    chk('lane classifier rejects a neutral',
        not is_lane_creep('npc_dota_neutral_black_drake'))
    chk('lane classifier rejects an ancient-camp golem',
        not is_lane_creep('npc_dota_neutral_granite_golem'))
    chk('ancient classifier still rejects the frog family',
        not is_ancient('npc_dota_neutral_ancient_frog_mage'))
    chk('ancient classifier accepts black_drake',
        is_ancient('npc_dota_neutral_black_drake'))

    # tier geometry gate
    chk('tier gate rejects a mid-map cluster',
        not centroids_are_ancient_tier([(1000, 200, 40)]))
    chk('tier gate rejects a far-y cluster',
        not centroids_are_ancient_tier([(4200, 3000, 40)]))
    chk('tier gate accepts the two real boxes',
        centroids_are_ancient_tier([(4200, 300, 40), (-4300, -200, 33)]))
    chk('tier gate rejects an empty cluster list',
        not centroids_are_ancient_tier([]))

    # support cut: the real W25 shape (two boxes + a tail of drifting fights)
    raw = [(-4812, 9, 2084), (4005, 115, 1247), (3890, -627, 88),
           (-5777, 552, 61), (-5213, -1228, 41), (2893, -893, 38),
           (-7036, 1042, 22), (-3908, 683, 19), (1225, -1426, 11),
           (3582, 1058, 9), (-261, -330, 8)]
    kept, dropped, tot = keep_supported(raw)
    chk('support cut keeps exactly the two real boxes', len(kept) == 2,
        '%r' % [c[:2] for c in kept])
    chk('support cut accounts for every sample',
        sum(c[2] for c in kept) + dropped == tot)
    chk('the tail alone fails the tier gate (why the cut exists)',
        not centroids_are_ancient_tier(raw))
    chk('the kept pair passes the tier gate',
        centroids_are_ancient_tier(kept))
    chk('the cut is not knife-edge on this shape',
        all(len(keep_supported(raw, f)[0]) == 2 for f in (0.03, 0.1, 0.3)))
    # camp adjacency: the measured W25 shape, and why no radius separates them
    nn = nearest_normal([(-4812, 9, 2084), (4005, 115, 1247)],
                        [(-4894, -113, 409), (4249, -119, 273),
                         (-3924, 700, 1952)])
    chk('nearest normal camp is inside every usable radius',
        all(best[0] < min(IN_CAMP_SWEEP) for _, best in nn),
        '%r' % [int(b[0]) for _, b in nn])
    chk('nearest_normal survives an empty normal list',
        nearest_normal([(1, 2, 3)], []) == [((1, 2, 3), None)])
    chk('an empty cluster list does not divide by zero',
        keep_supported([]) == ([], 0, 0))

    CS = [(4200.0, 300.0, 40)]
    H = 'npc_dota_hero_earthshaker'

    # frames_by_hero drops any stream whose first sample is post-horn: that is
    # the illusion discriminator (GH #176), so every REAL synthetic hero needs
    # a pre-horn anchor frame or the fixture would test the wrong thing.
    def frames(n, x=4200.0, y=300.0, level=10, t0=200.0, hp=1.0):
        return ([_snap(-30.0, H, 11, RADIANT, -6500.0, -6500.0, 1)]
                + [_snap(t0 + i, H, 11, RADIANT, x, y, level, hp)
                   for i in range(n)])

    # A lone enemy hero far away so the fr/team maps hold two teams.
    far = ([_snap(-30.0, 'npc_dota_hero_lion', 22, DIRE, 6500.0, 6500.0, 1)]
           + [_snap(200.0 + i, 'npc_dota_hero_lion', 22, DIRE, -6000.0, -6000.0)
              for i in range(30)])

    eps = scan_game(_mk_tl(frames(8) + far, []), CS)
    chk('stuck episode found with no events', len(eps) == 1
        and eps[0]['outcome'] == 'stuck',
        '%r' % [e['outcome'] for e in eps])
    chk('stuck episode duration is 7 s', eps and abs(eps[0]['dur'] - 7.0) < 1e-6,
        '%r' % (eps[0]['dur'] if eps else None))

    eps = scan_game(_mk_tl(frames(2) + far, []), CS)
    chk('a 2-frame pass-through is NOT an episode', eps == [])

    eps = scan_game(_mk_tl(frames(8, level=12) + far, []), CS)
    chk('level 12 is outside the band', eps == [])

    eps = scan_game(_mk_tl(frames(8, x=0.0, y=0.0) + far, []), CS)
    chk('a hero nowhere near a camp is outside the domain', eps == [])

    ev = [_dmg(203.0, H, 'npc_dota_neutral_black_drake')]
    eps = scan_game(_mk_tl(frames(8) + far, ev), CS)
    chk('an ancient trade inside the run reads as trade_anc',
        len(eps) == 1 and eps[0]['outcome'] == 'trade_anc',
        '%r' % [e['outcome'] for e in eps])

    # escape: hero leaves the box, then hits a lane creep inside the window
    run = frames(8)
    walk = [_snap(208.0 + i, H, 11, RADIANT, 4200.0 + 400 * (i + 1), 300.0)
            for i in range(5)]
    ev = [_dmg(210.0, H, 'npc_dota_creep_badguys_melee')]
    eps = scan_game(_mk_tl(run + walk + far, ev), CS)
    chk('lane-creep contact in the window reads as escape',
        len(eps) == 1 and eps[0]['outcome'] == 'escape',
        '%r' % [e['outcome'] for e in eps])

    ev = [_dmg(230.0, H, 'npc_dota_creep_badguys_melee')]
    eps = scan_game(_mk_tl(run + walk + far, ev), CS)
    chk('lane contact AFTER the window is not an escape',
        len(eps) == 1 and eps[0]['outcome'] == 'left',
        '%r' % [e['outcome'] for e in eps])

    # ordering: an ancient trade wins over a later lane hit (the deadlock did
    # not exist on that episode, so it is not campvoid's population)
    ev = [_dmg(203.0, H, 'npc_dota_neutral_black_drake'),
          _dmg(210.0, H, 'npc_dota_creep_badguys_melee')]
    eps = scan_game(_mk_tl(run + walk + far, ev), CS)
    chk('an ancient trade outranks a later lane hit',
        len(eps) == 1 and eps[0]['outcome'] == 'trade_anc')

    # THE W25 FALSE POSITIVE, pinned.  6df84c/20260829_124418_slot1: vengeful
    # spirit farming npc_dota_neutral_ice_shaman inside the ancient radius read
    # as a 27 s `stuck` deadlock while the first cut only asked about ancients.
    ev = [_dmg(203.0, H, 'npc_dota_neutral_ice_shaman', 90)]
    eps = scan_game(_mk_tl(frames(8) + far, ev), CS)
    chk('a NORMAL-camp trade in the radius is not a deadlock',
        len(eps) == 1 and eps[0]['outcome'] == 'trade_norm',
        '%r' % [e['outcome'] for e in eps])
    chk('the trap is real: ice_shaman is not an ancient',
        not is_ancient('npc_dota_neutral_ice_shaman'))
    chk('a normal-camp trade still counts as traded_any',
        eps and eps[0]['traded_any'] is True)

    # THE SECOND W25 FALSE POSITIVE, pinned.  6df84c/20260829_123218_slot8:
    # crystal maiden TP'd out (item_tpscroll t=593.6) and hit a lane creep
    # 10,417 u away at t=603.8; the first cut called that campvoid's escape.
    tp_walk = [_snap(208.0 + i, H, 11, RADIANT, 9000.0, -9000.0)
               for i in range(6)]
    ev = [_dmg(210.0, H, 'npc_dota_creep_badguys_ranged')]
    eps = scan_game(_mk_tl(run + tp_walk + far, ev), CS)
    chk('a lane hit across the map is NOT an escape',
        len(eps) == 1 and eps[0]['outcome'] == 'left',
        '%r' % [e['outcome'] for e in eps])
    chk('the unreachable contact is counted, not silently dropped',
        eps and eps[0]['lane_unreachable'] == 1,
        '%r' % (eps[0].get('lane_unreachable') if eps else None))
    chk('the reachability cap is derived, not guessed',
        LANE_SWEEP_R + MAX_MS * ESCAPE_W == 4200.0)

    # THE THIRD W25/W26 FALSE POSITIVE, pinned.  8d47de/20260829_184550_slot1:
    # oracle_fortunes_end SPLASHED a flagbearer mid-teamfight, on the leg where
    # campvoid is gate-OFF, and the first cut called it campvoid's escape.
    ev = [_dmg(210.0, H, 'npc_dota_creep_badguys_flagbearer',
               infl='oracle_fortunes_end')]
    eps = scan_game(_mk_tl(run + walk + far, ev), CS)
    chk('a SPELL splash on a lane creep is not an escape',
        len(eps) == 1 and eps[0]['outcome'] == 'left',
        '%r' % [e['outcome'] for e in eps])
    ev = [_dmg(210.0, H, 'npc_dota_creep_badguys_flagbearer')]
    eps = scan_game(_mk_tl(run + walk + far, ev), CS)
    chk('the same contact as a bare ATTACK is an escape',
        len(eps) == 1 and eps[0]['outcome'] == 'escape',
        '%r' % [e['outcome'] for e in eps])

    # an enemy hero standing on the camp makes it a fight, not a farm decision
    near = ([_snap(-30.0, 'npc_dota_hero_lion', 22, DIRE, 6500.0, 6500.0, 1)]
            + [_snap(200.0 + i, 'npc_dota_hero_lion', 22, DIRE, 4300.0, 300.0)
               for i in range(30)])
    eps = scan_game(_mk_tl(frames(8) + near, []), CS)
    # the lion is standing in the box too, so it owns the tail of its own run
    # once the earthshaker's stream ends -- the assertion is about HIM.
    chk('enemy hero inside FIGHT_NEAR removes the frames',
        not [e for e in eps if e['hero'] == entities.canon(H)],
        '%r' % [(e['hero'], e['frames']) for e in eps])

    # GH #176: an illusion must not author or extend an episode.  The
    # discriminator is the POST-HORN first sample, not hp and not motion.
    illu = [_snap(200.0 + i, H, 99, RADIANT, 4200.0, 300.0) for i in range(8)]
    tl = _mk_tl(frames(8) + illu + far, [])
    fr, _ = entities.frames_by_hero(tl)
    chk('illusion stream dropped by frames_by_hero',
        len(fr[entities.canon(H)]) == 9, 'got %d' % len(fr[entities.canon(H)]))
    eps = scan_game(tl, CS)
    chk('illusion does not double the episode',
        len(eps) == 1 and eps[0]['frames'] == 8,
        '%r' % [e['frames'] for e in eps])

    # GH #176 (2): a death frame must not be blended into a live one.  The
    # last live sample sits BETWEEN a live and a dead bracket, so it is
    # dropped -- 4 in-camp samples yield a 3-frame episode, by design.
    dead = frames(4) + [_snap(204.0 + i, H, 11, RADIANT, 4200.0, 300.0, hp=0.0)
                        for i in range(4)]
    eps = scan_game(_mk_tl(dead + far, []), CS)
    chk('bracketing drops the frame adjacent to a death frame',
        len(eps) == 1 and eps[0]['frames'] == 3,
        '%r' % [e['frames'] for e in eps])

    # leg / stratum wiring
    chk('ab: radiant armed -> radiant hero is the armed leg',
        leg_of(RADIANT, 'radiant') == 'armed'
        and leg_of(DIRE, 'radiant') == 'baseline')
    chk('ba: dire armed -> dire hero is the armed leg',
        leg_of(DIRE, 'dire') == 'armed'
        and leg_of(RADIANT, 'dire') == 'baseline')
    chk('stratum names follow the physical armed side',
        stratum_of('radiant') == 'ab' and stratum_of('dire') == 'ba')

    # aggregate: the four cells partition the records exactly
    recs = [{'stratum': 'ab', 'leg': 'armed', 'outcome': 'stuck', 'dur': 5.0,
             'hp_burn': 0.1, 'died_to_neutral': False},
            {'stratum': 'ab', 'leg': 'armed', 'outcome': 'escape', 'dur': 12.0,
             'hp_burn': 0.0, 'died_to_neutral': False},
            {'stratum': 'ba', 'leg': 'baseline', 'outcome': 'trade_anc',
             'dur': 4.0, 'hp_burn': 0.2, 'died_to_neutral': True},
            {'stratum': 'ba', 'leg': 'baseline', 'outcome': 'trade_norm',
             'dur': 4.0, 'hp_burn': 0.2, 'died_to_neutral': True},
            {'stratum': 'ba', 'leg': 'baseline', 'outcome': 'stuck', 'dur': 4.0,
             'hp_burn': 0.2, 'died_to_neutral': True}]
    cells = aggregate(recs)
    chk('cells partition the records',
        sum(c['episodes'] for c in cells.values()) == len(recs))
    chk('dur>=10 threshold counts the 12 s one only',
        cells[('ab', 'armed')]['dur_ge10'] == 1)
    chk('an empty cell is absent, not zero-valued',
        ('ba', 'armed') not in cells)
    # a death inside a `traded` episode is not a deadlock death: the two
    # counters must not be the same number.
    chk('deaths are split traded vs nothing-to-hit',
        cells[('ba', 'baseline')]['died'] == 3
        and cells[('ba', 'baseline')]['died_nontraded'] == 1)
    chk('pct on an empty denominator says n/a, not 0.0%',
        pct(0, 0) == 'n/a')

    print()
    print('selfcheck: %s' % ('OK' if ok else 'FAILED'))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('sweep_dirs', nargs='*')
    ap.add_argument('--out')
    ap.add_argument('--in-camp', type=float, default=None,
                    help='single radius; default sweeps %s' % (IN_CAMP_SWEEP,))
    ap.add_argument('--escape-w', type=float, default=ESCAPE_W)
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.sweep_dirs:
        ap.error('need at least one sweep dir (or --selfcheck)')

    games = []
    for d in a.sweep_dirs:
        # `<timestamp>_slotN.dem` COLLIDES ACROSS RUNS in one wave (the charter's
        # standing trap; 20260829_123240_slot1 exists in both b1386e and a29ed3
        # of W25).  Every record therefore carries its run, or a frame citation
        # cannot be resolved back to a file.
        run = os.path.basename(os.path.normpath(d)).split('_')[-1]
        for row in load_sweep(d):
            p = os.path.join(d, 'timelines', '%s.timeline.json' % row['game'])
            if os.path.exists(p):
                games.append((p, dict(row, run=run)))
    print('games with a timeline: %d' % len(games))

    warm = [p for p, _ in games[:WARMUP_GAMES]]
    raw, raw_norm = camp_centroids(warm)
    cs, dropped, tot = keep_supported(raw)
    print('ancient-trade samples: %d in %d raw clusters; %d kept at >=%.0f%% '
          'support, %d samples dropped as tails'
          % (tot, len(raw), len(cs), 100 * ANC_SUPPORT, dropped))
    print('ancient centroids from %d warmup games: %s' % (len(warm), cs))
    norm, _, ntot = keep_supported(raw_norm, NORM_SUPPORT)
    print('normal-camp clusters kept: %d (>=%.0f%% of %d samples)'
          % (len(norm), 100 * NORM_SUPPORT, ntot))
    for box, best in nearest_normal(cs, norm):
        print('  ancient box (%d, %d) n=%d -- nearest NORMAL camp %s'
              % (box[0], box[1], box[2],
                 ('%d u away at (%d, %d) n=%d' % (int(best[0]), int(best[1]),
                                                  int(best[2]), best[3]))
                 if best else 'n/a'))
    print('  => a positional ancient-vs-normal test is impossible below that '
          'separation; see the tool header.')
    if len(cs) != 2:
        sys.exit('[fatal] %d supported clusters, expected exactly 2 ancient '
                 'boxes -- refusing to report' % len(cs))
    if not centroids_are_ancient_tier(cs):
        sys.exit('[fatal] derived centroids fail the ancient tier geometry '
                 '(|x|>=%.0f, |y|<=%.0f) -- refusing to report'
                 % (ANCIENT_CLUSTER_MIN_ABS_X, ANCIENT_CLUSTER_MAX_ABS_Y))

    radii = [a.in_camp] if a.in_camp else list(IN_CAMP_SWEEP)
    all_recs = {r: [] for r in radii}
    games_by_cell = defaultdict(int)
    for p, row in games:
        tl = load(p)
        st = stratum_of(row['side'])
        seen = set()
        for r in radii:
            for ep in scan_game(tl, cs, in_camp=r, escape_w=a.escape_w):
                ep.update({'game': row['game'], 'run': row['run'],
                           'seed': row['seed'],
                           'side': row['side'], 'stratum': st,
                           'leg': leg_of(ep['team'], row['side']),
                           'in_camp': r})
                all_recs[r].append(ep)
        for leg in ('armed', 'baseline'):
            if (st, leg) not in seen:
                games_by_cell[(st, leg)] += 1
                seen.add((st, leg))

    for r in radii:
        report(all_recs[r], games_by_cell, r)

    if a.out:
        with open(a.out, 'w') as fh:
            for r in radii:
                for ep in all_recs[r]:
                    fh.write(json.dumps(ep) + '\n')
        print('\nwrote %s' % a.out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
