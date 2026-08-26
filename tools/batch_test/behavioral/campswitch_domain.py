#!/usr/bin/env python3
"""How often is the `campdanger` conjunct in farm mode's Think() reachable?

GH #201 (the baton the director handed replay-check when `strategy-19` /
`campdanger` was REJECTED + `readmit_on`).  The number wanted is the DOMAIN of
one conjunct in `bots/mode_farm_generic.lua`:

    bot._farm_repick_at = GameTime() + 1.0        -- outer throttle, 1 Hz
    ...
    if newDist + 200 < oldDist and J.IsCampSwitchSafe(nearest) then
        preferedCamp = nearest
    end

`and` short-circuits, so the denominator is the frames on which
`newDist + 200 < oldDist` holds.  Verdict rule from #201 §2, quoted so it
cannot drift: upper bound **< 1 frame/game** -> the ruling stands (the real
denominator is only smaller); **>= 1 frame/game** -> INCONCLUSIVE, which is
NOT a pass.

WHAT IS OBSERVABLE AND WHAT IS NOT
----------------------------------
`preferedCamp` is bot-internal state and appears in no frame table, so `oldDist`
cannot be read off the corpus.  Two facts decide how much that costs:

1. THE ASSUMPTION-FREE BOUND IS VACUOUS, AND THIS TOOL PRINTS IT AS SUCH.
   `preferedCamp` is only ever assigned `ClosestCamp(...)`, so the honest
   superset over "some earlier frame's nearest camp" admits, on a map of two
   dozen camps and a hero who roams, essentially EVERY alive frame.  Level L0x of the
   cascade below is that bound; it is reported precisely so nobody mistakes the
   estimator for something weaker than it is.

2. THE ESTIMATOR THEREFORE ANCHORS `preferedCamp` BEHAVIOURALLY: during the
   approach to a camp the bot actually engages, his preferred camp is taken to
   BE that camp.  Both error directions are declared, and both are printed:
   * over-count: he need not have been in farm mode at all on those frames
     (mode is unobservable), and any nearer camp counts even if an ally was
     farming it (`UpdateAvailableCamp` would have removed it).
   * under-count: if his real `preferedCamp` was staler than the camp he ends
     up hitting, the true `oldDist` is LARGER than the proxy, so some real
     domain frames are missed.  This is why the headline is called an ESTIMATE
     with a declared bound above it, never "the upper bound" on its own.

ONE THING THAT IS NOT AN APPROXIMATION.  The camp SET is exact for this corpus:
`RefreshCamp` filters by tier only when the soak candidate `campgrade` is armed,
and `campgrade` is armed in no leg of W11 or W12 (0/125 in W11, and it is absent
from the 36-id string).  Unarmed, `availableCampTable` is every camp on the map
-- which is exactly the set this tool clusters out of the neutral-creep stream.

THE CAMP SET IS MEASURED, NOT ASSUMED.  `timeline['creeps']` carries every
neutral sample (team 4) with its position, so camps are clustered from the
creeps themselves rather than from hero positions (which carry a hero's body
radius and his ranged stand-off).  The count is NOT checked against a
remembered map constant; it is certified on two disjoint halves of the geometry
corpus plus the map's 180-degree symmetry, and the run prints both.

#148 DISCIPLINE
---------------
This is a DOMAIN frequency, not an armed-vs-baseline difference: `campdanger`
is armed in no leg, so the two legs are the same code here.  Both strata are
still printed -- (i) as a null channel (a leg difference in a domain no armed
id touches is noise calibration), and per physical side because side effects
in this lab are routinely larger than leg effects.  Counts over a small integer
range are reported as means plus the share above a threshold, never a lone
median (#148 (ii)), and the per-game DISTRIBUTION is printed because #201 §4
asks for it by name: "most games 0, a few games dozens" is a different wave
decision from "1-2 every game".

Usage:
    campswitch_domain.py <sweep_dir> [<sweep_dir> ...] [--out out.jsonl]
    campswitch_domain.py --selfcheck
"""
import argparse
import bisect
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402
from ancient_camp_domain import is_hero, load  # noqa: E402
from campfarm_target import cluster, keep_supported  # noqa: E402
from creeppull_domain import DIRE, RADIANT, load_sweep  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..', '..'))
FARM_MODE = os.path.join(REPO, 'bots', 'mode_farm_generic.lua')

NEUTRAL_TEAM = 4           # timeline['creeps'] team id for neutral creeps
CAMP_CLUSTER_R = 900.0     # same radius campfarm_target/pullcamp_domain use
CAMP_SUPPORT = 0.002       # drop the dragged-creep tail (share of samples)
GEOM_GAMES = 6             # games used to derive the camp centroids
# THE CAMP COUNT IS NOT A MEMORIZED CONSTANT.  A count copied from memory of
# some patch's map is exactly the kind of second-hand knowledge the charter
# says not to trust; the map this corpus was played on is the authority.  What
# IS asserted is that the clustering is settled: two DISJOINT halves of the
# geometry corpus must agree on the count, and the camp field must be
# symmetric under the map's 180-degree rotation (every camp has a partner at
# -(x, y) within this tolerance).  Both are falsifiable, and both fail loud.
# Measured on the W12 geometry corpus: 28 clusters, every camp's 180-degree
# mirror within 994 u of another camp.  It is not 0 because a centroid is
# pulled by dragged creeps and stacks, which are not symmetric between the two
# jungles.  DECLARED: this tolerance was set AFTER seeing that 994, so the
# check is a DRIFT ALARM (the field stopped being symmetric, or the clustering
# started inventing camps), not an independent confirmation of the geometry.
# The worst miss is printed every run so the margin is never hidden.
GEOM_SYM_TOL = 1000.0

SNAP_R = 1000.0            # hero<->camp assignment radius at an engagement
BLOCK_GAP = 10.0           # engagements this far apart start a new block
APPROACH_S = 30.0          # how far before a block the approach window opens
# The anchor is only credible while he is committed to that camp.  1600 u is
# the farm mode's own longest sweep radius (GetNearbyCreeps(900)/(1600)); a
# hero farther out than his own widest scan is not yet "walking to this camp"
# in any sense a detector may assert.
COMMIT_R = 1600.0
# Farm mode returns DESIRE_NONE when enemy heroes are inside this ring and the
# team is not stronger (mode_farm_generic, the nEnemyHeroes block).  Used ONLY
# as a narrowing level below the headline, never to inflate it.
ENEMY_R = 1600.0
# Occupancy of a camp: neutral samples arrive every ~3 s and only where a team
# has vision, so a camp is called OCCUPIED when a neutral sample sits inside
# OCC_R of it within OCC_T of the frame.  A fog negative is real, so occupancy
# is only ever read for a camp the hero himself is standing near (OBS_R), where
# he supplies the vision -- and the share of hits that qualify is printed.
OCC_R = 500.0
OCC_T = 2.0
OBS_R = 1200.0
# `UpdateCommonCamp` SPLICES a camp out of `availableCampTable` as soon as a
# bot closes on a creep of that camp (any camp within 500 u of the creep), and
# `RefreshCamp` rebuilds the table only when `math.floor(DotaTime()) % 60` is
# in (0, 2) -- once per game minute.  So a camp a hero has just farmed is not
# in his own table, and `ClosestCamp` cannot return it, for the rest of that
# minute.  This is the level that separates a real domain frame from the "he
# is standing on the camp he just cleared" shape that dominates the raw count.
REFRESH_PERIOD = 60.0


def switch_constants(path=FARM_MODE):
    """The margin and the throttle, read out of the shipped Lua by shape.

    Never copied: an edit to either number in the bot source must show up here
    as a raised exception, not as a stale constant in a detector.
    """
    with open(path, 'r', encoding='utf-8') as fh:
        src = fh.read()
    src = '\n'.join(l for l in src.splitlines()
                    if not l.strip().startswith('--'))
    m = re.findall(r'newDist\s*\+\s*(\d+(?:\.\d+)?)\s*<\s*oldDist', src)
    if len(m) != 1:
        raise RuntimeError('%s: expected exactly 1 camp-switch margin, got %r'
                           % (path, m))
    thr = re.findall(r'_farm_repick_at\s*=\s*GameTime\(\)\s*\+\s*'
                     r'(\d+(?:\.\d+)?)', src)
    if len(thr) != 1:
        raise RuntimeError('%s: expected exactly 1 repick throttle, got %r'
                           % (path, thr))
    # The conjunct must still be the one this detector reasons about: the
    # switch is guarded by IsCampSwitchSafe, not by the nil field the repair
    # removed (48ff29fe).  If that changes, the domain question changed too.
    if not re.search(r'newDist\s*\+\s*\d+(?:\.\d+)?\s*<\s*oldDist\s+and\s+'
                     r'J\.IsCampSwitchSafe\(', src):
        raise RuntimeError('%s: camp-switch conjunct no longer reads '
                           '`newDist + N < oldDist and J.IsCampSwitchSafe(`'
                           % path)
    return float(m[0]), float(thr[0])


SWITCH_MARGIN, REPICK_THROTTLE = switch_constants()


def occupancy_index(tl):
    """{t: [(x, y), ...]} for neutral creeps -- the camps' own contents."""
    idx = defaultdict(list)
    for c in tl.get('creeps', ()):
        if c.get('team') == NEUTRAL_TEAM:
            idx[c['t']].append((c['x'], c['y']))
    return idx


def camp_points(tl):
    """Neutral creep positions -- the camps themselves, not hero stand-ins."""
    return [(c['x'], c['y']) for c in tl.get('creeps', ())
            if c.get('team') == NEUTRAL_TEAM]


def _camps_from_points(pts):
    camps, cov = keep_supported(cluster(pts, CAMP_CLUSTER_R), CAMP_SUPPORT)
    return [(c[0], c[1]) for c in camps], cov


def symmetry(camps, tol=GEOM_SYM_TOL):
    """Share of camps whose 180-degree mirror is also a camp, and the worst
    miss.  The Dota map is rotationally symmetric about the river, so a
    clustering that invents a camp on one side alone is visible here."""
    if not camps:
        return 0.0, -1.0
    misses = []
    for (x, y) in camps:
        misses.append(min(math.dist((-x, -y), c) for c in camps))
    good = sum(1 for m in misses if m <= tol)
    return good / float(len(camps)), max(misses)


def derive_camps(paths):
    """Cluster the camp field, and certify it on two disjoint halves."""
    halves = [[], []]
    for i, p in enumerate(paths):
        tl = load(p)
        halves[i % 2] += camp_points(tl)
        del tl
    pts = halves[0] + halves[1]
    camps, cov = _camps_from_points(pts)
    geom = {'n': len(camps), 'cov': cov, 'pts': len(pts)}
    if all(halves):
        a, _ = _camps_from_points(halves[0])
        b, _ = _camps_from_points(halves[1])
        geom['half_a'], geom['half_b'] = len(a), len(b)
        geom['halves_agree'] = (len(a) == len(b) == len(camps))
    else:
        geom['half_a'] = geom['half_b'] = -1
        geom['halves_agree'] = False
    geom['sym_share'], geom['sym_worst'] = symmetry(camps)
    return camps, geom


def nearest_camp(camps, x, y):
    best, bd = None, 9e9
    for i, (cx, cy) in enumerate(camps):
        d = math.dist((x, y), (cx, cy))
        if d < bd:
            best, bd = i, d
    return best, bd


def engagements(tl, frames, camps):
    """(hero, t, camp_idx) for every hero<->neutral trade, snapped to a camp."""
    out, unsnapped = [], 0
    for e in tl['events']:
        if e['type'] != 'DAMAGE':
            continue
        a, tg = e['actor'], e['target']
        if is_hero(a) and str(tg).startswith('npc_dota_neutral'):
            h = a
        elif is_hero(tg) and str(a).startswith('npc_dota_neutral'):
            h = tg
        else:
            continue
        s = entities.interp(frames.get(entities.canon(h)) or [], e['t'])
        if s is None:
            continue
        ci, d = nearest_camp(camps, s['x'], s['y'])
        if ci is None or d > SNAP_R:
            unsnapped += 1
            continue
        out.append((entities.canon(h), e['t'], ci))
    out.sort(key=lambda r: (r[0], r[1]))
    return out, unsnapped


def blocks_of(engs):
    """Group a hero's engagements into camp visits: (hero, camp, t0, t1)."""
    out = []
    cur = None
    for h, t, ci in engs:
        if (cur and cur[0] == h and cur[1] == ci
                and t - cur[3] <= BLOCK_GAP):
            cur[3] = t
            continue
        if cur:
            out.append(tuple(cur))
        cur = [h, ci, t, t]
    if cur:
        out.append(tuple(cur))
    return out


def scan_game(tl, camps):
    """Per-hero cascade counts for one game.

    L0    alive hero frames
    L0x   ... and SOME camp is more than the margin farther than the nearest
          one (the assumption-free superset -- vacuous by construction, printed
          to keep the estimator honest)
    L1    ... and the frame is inside an approach-or-visit window AND within
          COMMIT_R of that camp, so a behaviourally anchored `preferedCamp`
          exists and he is committed to it
    L2    ... and the nearest camp is not that camp
    L3    ... and newDist + MARGIN < oldDist   <- THE DOMAIN (headline)
    L4    ... and that nearer camp survives the picker's OWN ally filter:
          `IsTheClosestOne` drops any camp a living team-mate stands nearer to,
          so a camp an ally is sitting on is not `nearest` at all
    L5    ... and no living enemy hero within ENEMY_R (farm mode would have
          answered DESIRE_NONE otherwise, unless his team was stronger)
    L6    ... and he is closing on the anchored camp (distance falling)  <- the
          tightest defensible floor

    L4 is deliberately STRICTER than the engine: `IsTheClosestOne` only counts
    team-mates whose active mode is Farm, and mode is not in the frame table,
    so every living ally is counted instead.  That direction under-counts, and
    it is the only place in this cascade that does.
    """
    frames, team = entities.frames_by_hero(tl)
    deaths = entities.death_times(tl)
    occ = occupancy_index(tl)
    occ_ts = sorted(occ)
    engs, unsnapped = engagements(tl, frames, camps)
    per_hero_eng = defaultdict(list)
    for r in engs:
        per_hero_eng[r[0]].append(r)

    removals = defaultdict(list)   # hero -> [(t, camp)] engaged => spliced out
    for (h, t, ci) in engs:
        removals[h].append((t, ci))

    counts = Counter()
    hits = []                      # (hero, t, oldDist, newDist, camp, alt)
    windows = defaultdict(list)    # hero -> [(t0, t1, camp)]
    for h, rows in per_hero_eng.items():
        prev_end = -1e9
        for (_, ci, t0, t1) in blocks_of(rows):
            start = max(t0 - APPROACH_S, prev_end)
            windows[h].append((start, t1, ci))
            prev_end = t1

    # Exact-t index over the CLEAN frame table: every hero is sampled on the
    # same 1 Hz tick, so the other nine positions at this instant are a lookup,
    # never an interpolation.  A hero missing from a tick is simply absent --
    # the index never invents a position, which is the whole point of #176.
    by_t = defaultdict(dict)
    for h, rows in frames.items():
        dd = deaths.get(h, [])
        for s in rows:
            if entities.alive_at(rows, dd, s['t']):
                by_t[s['t']][h] = s

    def others(h, t, same_team):
        my = team.get(h)
        for other, s in by_t.get(t, {}).items():
            if other == h:
                continue
            if (team.get(other) == my) == same_team:
                yield s

    def enemy_near(h, t, x, y):
        """Is a living enemy hero inside ENEMY_R at t?  Corpses do not count
        (alive_at), and neither do illusions (the CLEAN table), which is the
        same population the engine-side ring asks for."""
        return any(math.dist((x, y), (s['x'], s['y'])) < ENEMY_R
                   for s in others(h, t, same_team=False))

    def in_table(h, ci, t):
        """Is camp `ci` still in this hero's availableCampTable at t?

        False once he has engaged it since the last minute refresh.  Modelled
        per-bot, which is the CONSERVATIVE choice: if `J.Role` turns out to be
        shared across a team's bots, more camps would be missing, not fewer,
        so this level can only over-count -- never under-count -- the domain.
        """
        last_refresh = math.floor(t / REFRESH_PERIOD) * REFRESH_PERIOD
        for (t_eng, c_eng) in removals.get(h, ()):
            if c_eng == ci and last_refresh <= t_eng <= t:
                return False
        return True

    def occupied(camp, t):
        """Is a neutral creep standing in this camp at (about) t?"""
        i = bisect.bisect_left(occ_ts, t - OCC_T)
        while i < len(occ_ts) and occ_ts[i] <= t + OCC_T:
            for (x, y) in occ[occ_ts[i]]:
                if math.dist(camp, (x, y)) <= OCC_R:
                    return True
            i += 1
        return False

    def ally_owns(h, t, camp, mine):
        """The picker's own `IsTheClosestOne`: a living ally nearer to this
        camp than the bot removes the camp from consideration entirely."""
        return any(math.dist(camp, (s['x'], s['y'])) < mine
                   for s in others(h, t, same_team=True))

    for h, rows in frames.items():
        wins = windows.get(h, ())
        prev_old = None
        for s in rows:
            t = s['t']
            if not entities.alive_at(rows, deaths.get(h, []), t):
                prev_old = None
                continue
            counts['L0'] += 1
            ni, nd = nearest_camp(camps, s['x'], s['y'])
            if any(math.dist((s['x'], s['y']), c) > nd + SWITCH_MARGIN
                   for c in camps):
                counts['L0x'] += 1
            win = next((w for w in wins if w[0] <= t <= w[1]), None)
            if win is None:
                prev_old = None
                continue
            ci = win[2]
            old = math.dist((s['x'], s['y']), camps[ci])
            closing = prev_old is not None and old < prev_old
            prev_old = old
            if old > COMMIT_R:
                continue
            counts['L1'] += 1
            if ni == ci:
                continue
            counts['L2'] += 1
            if nd + SWITCH_MARGIN >= old:
                continue
            counts['L3'] += 1
            # the best camp that also survives the picker's ally filter
            free = None
            for j, c in enumerate(camps):
                if j == ci:
                    continue
                dj = math.dist((s['x'], s['y']), c)
                if dj + SWITCH_MARGIN >= old:
                    continue
                if ally_owns(h, t, c, dj):
                    continue
                if free is None or dj < free[1]:
                    free = (j, dj)
            quiet = not enemy_near(h, t, s['x'], s['y'])
            occ_free = None
            if free is not None:
                counts['L4'] += 1
                if quiet:
                    counts['L5'] += 1
                    if closing:
                        counts['L6'] += 1
                        occ_free = occupied(camps[free[0]], t)
                        if occ_free:
                            counts['L7'] += 1
                            if in_table(h, free[0], t):
                                counts['L8'] += 1
            # observability of the occupancy read: only a camp he is standing
            # near is out of the fog for certain
            near_alt = free is not None and free[1] <= OBS_R
            if near_alt:
                counts['obs'] += 1
                if occ_free is None:
                    occ_free = occupied(camps[free[0]], t)
                if occ_free:
                    counts['obs_occ'] += 1
            hits.append((h, t, old, nd, ci, ni, team.get(h), quiet, closing,
                         free is not None, occ_free))
    return counts, hits, unsnapped, len(frames)


def scan(dirs):
    games = []
    for d in dirs:
        for m in load_sweep(d):
            p = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            if os.path.exists(p):
                games.append((d, m, p))
            else:
                print('[warn] missing timeline %s' % p, file=sys.stderr)
    if not games:
        sys.exit('[fatal] no timelines under %s' % ', '.join(dirs))

    camps, geom = derive_camps([p for _, _, p in games[:GEOM_GAMES]])

    recs = []
    ngames = Counter()
    stats = Counter()
    for d, m, p in games:
        run_tag = os.path.basename(d.rstrip('/')).split('_')[-1]
        tl = load(p)
        counts, hits, unsnapped, nheroes = scan_game(tl, camps)
        armed_team = RADIANT if m['side'] == 'radiant' else DIRE
        teams = tl['game']['teams']
        del tl
        ngames[m['side']] += 1
        stats['unsnapped'] += unsnapped
        by_leg = Counter()
        for hit in hits:
            by_leg['armed' if hit[6] == armed_team else 'baseline'] += 1
        recs.append({'run': run_tag, 'game': m['game'], 'seed': m['seed'],
                     'arm_side': m['side'], 'counts': dict(counts),
                     'hits': [{'hero': h, 't': t, 'old': round(old, 1),
                               'new': round(nd, 1), 'camp': ci, 'alt': ni,
                               'quiet': q, 'closing': cl, 'ally_free': af,
                               'alt_occupied': oc,
                               'leg': ('armed' if tm == armed_team
                                       else 'baseline')}
                              for (h, t, old, nd, ci, ni, tm, q, cl, af, oc)
                              in hits],
                     'by_leg': dict(by_leg), 'heroes': nheroes,
                     'teams': teams})
    return {'camps': camps, 'geom': geom,
            'recs': recs, 'ngames': ngames, 'stats': stats}


def report(res):
    camps, recs = res['camps'], res['recs']
    ng = sum(res['ngames'].values())
    print('\n=== campswitch domain (GH #201) ===')
    print('games %d   margin %g u   throttle %g s (corpus sample rate 1 Hz '
          '-- same frequency, no aliasing cost)'
          % (ng, SWITCH_MARGIN, REPICK_THROTTLE))
    g = res['geom']
    seps = [min(math.dist(camps[i], camps[j]) for j in range(len(camps))
                if j != i) for i in range(len(camps))]
    print('camps clustered %d   %.1f%% of %d neutral samples kept   '
          'min separation %d u' % (len(camps), 100.0 * g['cov'], g['pts'],
                                   min(seps) if seps else -1))
    print('geometry certified: disjoint halves %d / %d -> %s   '
          '180-deg symmetry %.0f%% of camps (worst miss %d u)'
          % (g['half_a'], g['half_b'],
             'AGREE' if g['halves_agree'] else '** DISAGREE **',
             100.0 * g['sym_share'], g['sym_worst']))
    if not g['halves_agree'] or g['sym_share'] < 1.0:
        print('  ** geometry is NOT settled; every number below inherits '
              'that **')

    tot = Counter()
    for r in recs:
        tot.update(r['counts'])
    print('\n  cascade (monotone; per game)')
    print('  %-5s %-58s %10s %9s' % ('level', 'what it adds', 'frames',
                                     'per game'))
    rows = [
        ('L0', 'alive hero frames'),
        ('L0x', 'assumption-free superset: SOME camp is farther by margin'),
        ('L1', '+ committed to an anchored camp (within %d u of it)'
         % COMMIT_R),
        ('L2', '+ nearest camp is not the anchored one'),
        ('L3', '+ newDist + margin < oldDist   <-- THE DOMAIN'),
        ('L4', "+ the nearer camp survives the picker's own ally filter"),
        ('L5', '+ no living enemy hero within %d u' % ENEMY_R),
        ('L6', '+ and closing on the anchored camp'),
        ('L7', '+ and that camp still has neutrals in it'),
        ('L8', "+ and it is still in his own camp table (not one he just "
         "farmed)   <-- floor"),
    ]
    for k, what in rows:
        print('  %-5s %-58s %10d %9.3f'
              % (k, what, tot[k], tot[k] / float(max(ng, 1))))
    if tot['L0']:
        print('  L0x/L0 = %.1f%% -- this is why the assumption-free bound is '
              'reported as VACUOUS and not used as the answer'
              % (100.0 * tot['L0x'] / tot['L0']))

    per = [r['counts'].get('L3', 0) for r in recs]
    zero = sum(1 for v in per if v == 0)
    print('\n  distribution of the domain over games (#201 §4)')
    print('  mean %.3f frames/game   games with 0 hits %d/%d (%.1f%%)   '
          'max %d' % (sum(per) / float(max(len(per), 1)), zero, len(per),
                      100.0 * zero / max(len(per), 1), max(per or [0])))
    for thr in (1, 3, 10):
        share = sum(1 for v in per if v >= thr) / float(max(len(per), 1))
        print('  share of games with >= %-2d hits: %.1f%%' % (thr, 100 * share))

    print('\n  strata (#148 (i)); campdanger is armed in NO leg, so a leg')
    print('  difference here is a null-channel reading, not an effect')
    print('  %-16s %6s %10s %10s %10s'
          % ('stratum', 'games', 'armed/g', 'base/g', 'diff'))
    diffs = {}
    for lbl, side in (('ab (rad-armed)', 'radiant'), ('ba (dire-armed)', 'dire')):
        n = max(res['ngames'][side], 1)
        a = sum(r['by_leg'].get('armed', 0) for r in recs
                if r['arm_side'] == side) / float(n)
        b = sum(r['by_leg'].get('baseline', 0) for r in recs
                if r['arm_side'] == side) / float(n)
        diffs[side] = a - b
        print('  %-16s %6d %10.3f %10.3f %+10.3f'
              % (lbl, res['ngames'][side], a, b, a - b))
    if diffs:
        agree = diffs.get('radiant', 0) * diffs.get('dire', 0) > 0
        print('  strata agree in sign: %s   balanced %+.3f'
              % ('YES' if agree else 'NO (#148 (i): noise, not a reading)',
                 (diffs.get('radiant', 0) + diffs.get('dire', 0)) / 2.0))

    hits = [h for r in recs for h in r['hits']]
    if hits:
        gains = sorted(h['old'] - h['new'] for h in hits)
        print('\n  when it does fire, how much closer is the alternative?')
        print('  n=%d  min %d u  median %d u  max %d u  share > 800 u %.1f%%'
              % (len(gains), gains[0], gains[len(gains) // 2], gains[-1],
                 100.0 * sum(1 for g in gains if g > 800) / len(gains)))
        top = Counter((h['camp'], h['alt']) for h in hits).most_common(5)
        print('  top camp pairs (anchored -> nearer): %s'
              % ', '.join('%s->%s x%d' % (a, b, n) for (a, b), n in top))
        ex = sorted(hits, key=lambda h: -(h['old'] - h['new']))[:3]
        for h in ex:
            print('  e.g. %s t=%.1f  anchored camp %d at %d u, camp %d at '
                  '%d u' % (h['hero'], h['t'], h['camp'], h['old'], h['alt'],
                            h['new']))
    if tot['obs']:
        print('\n  is the nearer camp actually full?  (%d of the %d domain '
              'frames put him within %d u of it, so his own vision answers)'
              % (tot['obs'], tot['L3'], OBS_R))
        print('  occupied on %.1f%% of those -- the rest are camps that were '
              'already cleared, which the picker does NOT filter out '
              '(RefreshCamp admits every spawner unarmed)'
              % (100.0 * tot['obs_occ'] / tot['obs']))

    print('\n  unsnapped neutral trades (>%d u from every camp): %d'
          % (SNAP_R, res['stats']['unsnapped']))

    rate = tot['L3'] / float(max(ng, 1))
    floor = tot['L8'] / float(max(ng, 1))
    print('\n  #201 §2 verdict rule, applied verbatim:')
    if rate < 1.0:
        print('  estimate %.3f frames/game < 1  -> the REJECTED ruling stands '
              'on this reading' % rate)
    else:
        print('  estimate %.3f frames/game >= 1 -> INCONCLUSIVE (explicitly '
              'NOT a pass)' % rate)
    print('  tightest floor (L8) %.3f frames/game -- the verdict rule reads '
          'the same on it: %s'
          % (floor, 'stands' if floor < 1.0 else 'INCONCLUSIVE'))
    print('  the estimator is behaviourally anchored, not a strict bound; its')
    print('  over- and under-count directions are in this file\'s docstring '
          'and must travel with the number.')


# ---------------------------------------------------------------------------
def selfcheck():
    ok = err = 0

    def chk(name, cond, detail=''):
        nonlocal ok, err
        if cond:
            ok += 1
            print('  PASS %s' % name)
        else:
            err += 1
            print('  FAIL %s %s' % (name, detail))

    chk('margin read from shipped Lua', SWITCH_MARGIN == 200.0,
        '%r' % SWITCH_MARGIN)
    chk('throttle read from shipped Lua', REPICK_THROTTLE == 1.0,
        '%r' % REPICK_THROTTLE)
    try:
        switch_constants(os.path.join(os.path.dirname(__file__),
                                      'campswitch_domain.py'))
        chk('constants fail loud on a file without the conjunct', False,
            'no exception')
    except RuntimeError:
        chk('constants fail loud on a file without the conjunct', True)

    camps = [(0.0, 0.0), (3000.0, 0.0)]
    ci, d = nearest_camp(camps, 100.0, 0.0)
    chk('nearest_camp picks the near one', ci == 0 and abs(d - 100) < 1e-6)

    # blocks: same camp inside the gap merges, a gap or a camp change splits
    engs = [('a', 1.0, 0), ('a', 5.0, 0), ('a', 40.0, 0), ('a', 42.0, 1)]
    bl = blocks_of(engs)
    chk('blocks merge inside the gap and split outside', len(bl) == 3,
        '%r' % (bl,))
    chk('block keeps its camp id', [b[1] for b in bl] == [0, 0, 1],
        '%r' % ([b[1] for b in bl],))

    # --- end-to-end on a synthetic timeline ---------------------------------
    # Hero walks from (0,0) to camp B at (2200,0) and fights it, passing camp
    # A at (1000,0) on the way.  The camps are 1200 u apart, which is the real
    # map's own neighbour spacing, so the walk-past is the situation the
    # conjunct exists for: while committed to B, A is nearer by more than the
    # margin on part of the approach.
    def snap(t, x):
        return {'t': t, 'hero': 'npc_dota_hero_axe', 'idx': 7, 'team': 2,
                'player_id': 0, 'x': float(x), 'y': 0.0, 'hp': 100,
                'hp_pct': 1.0, 'mp': 1, 'max_mp': 1, 'mp_pct': 1.0,
                'level': 10, 'items': [''], 'abilities': []}
    snaps = [snap(t, 200 * t) for t in range(0, 13)]
    tl = {'game': {'teams': {'2': 'r', '3': 'd'}},
          'snapshots': snaps,
          # both camps sampled on every tick, the way the dumper streams them
          'creeps': [{'t': float(t), 'team': NEUTRAL_TEAM, 'x': cx, 'y': 0.0}
                     for t in range(0, 13) for cx in (1000.0,) * 5
                     + (2200.0,) * 5],
          'events': [{'t': 11.0, 'type': 'DAMAGE',
                      'actor': 'npc_dota_hero_axe',
                      'target': 'npc_dota_neutral_kobold', 'value': 10,
                      'actor_hero': True, 'target_hero': False}]}
    tcamps, _ = _camps_from_points(camp_points(tl))
    chk('camps cluster out of the neutral stream', len(tcamps) == 2,
        '%r' % (tcamps,))
    counts, hits, unsnapped, nh = scan_game(tl, tcamps)
    chk('L0 counts every alive frame', counts['L0'] == 13,
        '%d' % counts['L0'])
    chk('the domain is non-empty on a walk-past', counts['L3'] > 0,
        '%d' % counts['L3'])
    chk('cascade is monotone',
        (counts['L0'] >= counts['L1'] >= counts['L2'] >= counts['L3']
         >= counts['L4'] >= counts['L5'] >= counts['L6'] >= counts['L7']
         >= counts['L8']), '%r' % dict(counts))
    chk('commitment ring really gates (L1 < every windowed frame)',
        0 < counts['L1'] < 12, 'L1=%d' % counts['L1'])
    chk('a lone hero has neither ally nor enemy, so L5 == L4 == L3',
        counts['L5'] == counts['L4'] == counts['L3'], '%r' % dict(counts))
    chk('closing test bites: L6 <= L5',
        counts['L6'] <= counts['L5'], '%r' % dict(counts))
    # L0x is the superset level, so it must dominate the domain -- and it must
    # still be able to REFUSE, or "vacuous" would be an untested word.  On this
    # two-camp synthetic the refusals are the frames where the hero stands
    # within the margin of the midpoint (|dA - dB| <= margin); on the real
    # 18-camp map that set is empty, which is the finding, not the assumption.
    chk('L0x dominates the domain', counts['L0x'] >= counts['L3'],
        '%r' % dict(counts))
    mid = sum(1 for s in snaps
              if abs(math.dist((s['x'], s['y']), tcamps[0])
                     - math.dist((s['x'], s['y']), tcamps[1]))
              <= SWITCH_MARGIN)
    chk('L0x can refuse (it is a predicate, not a constant)',
        counts['L0x'] == counts['L0'] - mid and mid > 0,
        'L0x=%d L0=%d midband=%d' % (counts['L0x'], counts['L0'], mid))
    chk('every hit really has a nearer camp',
        all(h[3] + SWITCH_MARGIN < h[2] for h in hits))
    chk('occupancy is read on the nearer camp and it is full here',
        counts['L7'] == counts['L6'] and counts['L7'] > 0, '%r' % dict(counts))
    # anti-selfskip-trap 5: occupancy must be able to answer NO.  Move every
    # neutral sample off the camps (they are still in the stream, so this is
    # not an empty-pipe pass) and L7 must empty while L6 does not.
    away = [dict(c, x=c['x'] + 5000.0) for c in tl['creeps']]
    c_emp, _, _, _ = scan_game(dict(tl, creeps=away), tcamps)
    chk('a cleared camp empties L7 but not L6',
        c_emp['L6'] == counts['L6'] and c_emp['L7'] == 0, '%r' % dict(c_emp))
    chk('with no prior engagement the table level is a no-op (L8 == L7)',
        counts['L8'] == counts['L7'] and counts['L8'] > 0, '%r' % dict(counts))
    # anti-selfskip-trap 6: the table level must BITE.  Let him trade with the
    # nearer camp first, inside the same minute: `UpdateCommonCamp` splices it
    # out, so `ClosestCamp` cannot return it and the frames stop being domain.
    tl6 = dict(tl, events=[{'t': 2.0, 'type': 'DAMAGE',
                            'actor': 'npc_dota_hero_axe',
                            'target': 'npc_dota_neutral_kobold', 'value': 10,
                            'actor_hero': True, 'target_hero': False}]
               + list(tl['events']))
    c_tab, _, _, _ = scan_game(tl6, tcamps)
    chk('a camp he already farmed this minute is out of the table (L8 empties)',
        c_tab['L7'] > 0 and c_tab['L8'] == 0, '%r' % dict(c_tab))
    # An enemy standing on top of him must be able to empty L4 -- otherwise
    # "no enemy nearby" would be an unexercised branch.
    foe = [dict(s, hero='npc_dota_hero_lion', idx=8, team=3) for s in snaps]
    tl_foe = dict(tl, snapshots=snaps + foe)
    c_foe, _, _, _ = scan_game(tl_foe, tcamps)
    chk('an enemy inside the ring empties L5 but not L4',
        (c_foe['L3'] == counts['L3'] and c_foe['L4'] == counts['L4']
         and c_foe['L5'] == 0), '%r' % dict(c_foe))
    # anti-selfskip-trap 4: the picker's ally filter must be able to bite.  An
    # ALLY standing on the nearer camp removes it from consideration, so L4
    # empties while L3 -- which does not know about the filter -- does not.
    mate = [dict(s, hero='npc_dota_hero_lion', idx=9, team=2,
                 x=tcamps[0][0], y=tcamps[0][1]) for s in snaps]
    c_ally, _, _, _ = scan_game(dict(tl, snapshots=snaps + mate), tcamps)
    # The one frame that survives is the tie: at t=5 the hero stands ON that
    # camp too, and `IsTheClosestOne` is a STRICT `<`, so a tie belongs to him.
    # Asserting the tie rather than 0 keeps the check from passing for the
    # wrong reason if the comparison is ever loosened to `<=`.
    chk('an ally sitting on the nearer camp all but empties L4 (tie survives)',
        c_ally['L3'] == counts['L3'] and c_ally['L4'] == 1,
        '%r' % dict(c_ally))
    chk('hits sit before the engagement, inside the approach window',
        all(11.0 - APPROACH_S <= h[1] <= 11.0 for h in hits))

    # anti-selfskip-trap 1: the window really restricts.  A hero who never
    # trades with a neutral has no anchor, so L1 must be 0 while L0 is not.
    tl2 = dict(tl, events=[])
    c2, h2, _, _ = scan_game(tl2, tcamps)
    chk('no engagement => no anchored frames (window really gates)',
        c2['L0'] == 13 and c2['L1'] == 0 and not h2, '%r' % dict(c2))

    # anti-selfskip-trap 2: the margin really bites.  Put the second camp
    # 100 u from the first: no alternative can beat 200 u, so L3 empties while
    # L2 does not.
    near = [(1000.0, 0.0), (1100.0, 0.0)]
    tl3 = dict(tl, events=[{'t': 24.0, 'type': 'DAMAGE',
                            'actor': 'npc_dota_hero_axe',
                            'target': 'npc_dota_neutral_kobold', 'value': 10,
                            'actor_hero': True, 'target_hero': False}],
               snapshots=[snap(t, 900 + 8 * t) for t in range(0, 25)])
    c3, h3, _, _ = scan_game(tl3, near)
    chk('margin bites: alternatives inside the margin do not count',
        c3['L2'] > 0 and c3['L3'] == 0, '%r' % dict(c3))

    # anti-selfskip-trap 3: a dead hero contributes nothing.  Same walk, but
    # a DEATH event at t=5 with no resurrection.
    tl4 = dict(tl, events=list(tl['events']) + [
        {'t': 5.0, 'type': 'DEATH', 'actor': 'npc_dota_hero_lion',
         'target': 'npc_dota_hero_axe', 'actor_hero': True,
         'target_hero': True}])
    c4, _, _, _ = scan_game(tl4, tcamps)
    chk('death event removes frames from every level',
        c4['L0'] < counts['L0'] and c4['L3'] <= counts['L3'],
        '%r vs %r' % (dict(c4), dict(counts)))

    # the snap radius must be able to refuse: a trade 5000 u from any camp
    tl5 = dict(tl, events=[{'t': 11.0, 'type': 'DAMAGE',
                            'actor': 'npc_dota_hero_axe',
                            'target': 'npc_dota_neutral_kobold', 'value': 10,
                            'actor_hero': True, 'target_hero': False}],
               snapshots=[snap(t, 20000) for t in range(0, 13)])
    _, _, uns, _ = scan_game(tl5, tcamps)
    chk('unsnappable trades are refused, not snapped', uns == 1, '%d' % uns)

    print('\n%d PASS / %d FAIL' % (ok, err))
    return 1 if err else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dirs', nargs='*')
    ap.add_argument('--out')
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()
    if a.selfcheck:
        sys.exit(selfcheck())
    if not a.dirs:
        sys.exit('usage: campswitch_domain.py <sweep_dir> ... | --selfcheck')
    res = scan(a.dirs)
    report(res)
    if a.out:
        with open(a.out, 'w', encoding='utf-8') as fh:
            for r in res['recs']:
                fh.write(json.dumps(r) + '\n')
        print('\nwrote %s' % a.out)


if __name__ == '__main__':
    main()
