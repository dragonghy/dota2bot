#!/usr/bin/env python3
"""`arbheart` condition (a): does the 1 Hz heartbeat actually DROP a camp an
ally is already farming -- and does the bot then stay away from it?

WHAT THE LEVER IS
-----------------
`bots/mode_farm_generic.lua:830-940`.  The shipped code latches `preferedCamp`
once (`if preferedCamp == nil then preferedCamp = ClosestCamp(...) end`, six
call sites) and re-arbitrates it essentially never: `IsTheClosestOne` is only
queried on the tick the latch closes.  GH #455 §3 photographed the tail --
`crystal_maiden` 5,744 u from a camp that `spirit_breaker` was already 340 u
into farming, the latch having closed at t=816 when SB was still 5,003 u out.

Armed, `arbheart` inserts a re-ask into the 1 Hz repick heartbeat:

    for i = 1, #GetTeamPlayers(GetTeam()) do
        member = GetTeamMember(i)
        if member ~= bot and J.IsValidHero(member) and not member:IsIllusion()
           and GetUnitToLocationDistance(member, vCamp) <= 800
           and J.IsFarming(member)
        then  <release the latch AND retire the camp>  end

`preferedCamp = nil` plus `UpdateAvailableCamp` (GH #456: the release alone is
self-cancelling, because the re-pick hands the same camp straight back).
STRICT SUBSET: armed can only ever RELEASE a latch, never create one.

THE PRE-REGISTERED READING (do not re-invent it)
------------------------------------------------
`state.json:arbheart_retire_20260903.next_baton`, verbatim: "on an armed leg
the released camp must be ABSENT from that bot's next camp pick within the
same second, which is readable WITHOUT any camp-table snapshot".  So the
observable is not the release (bot-internal) but its CONSEQUENCE: the bot
stops arriving at the camp the ally holds.

TWO UNOBSERVABLES, BOTH DECLARED (neither is engineered around)
---------------------------------------------------------------
1. `J.IsFarming(member)` is engine-side and appears in no frame table.  Two
   tools on trunk already say so in as many words (`cmqreach_domain.py:70`,
   `sb_charge_target_domain.py:22`).  PROXY USED HERE: the ally is trading
   damage with THAT camp's neutrals within +/-`OCC_WIN` of the frame (the
   engagement stream `campswitch_domain.engagements` already snaps to camps).
   ** This proxy is NEITHER a subset NOR a superset of the engine predicate **:
   a bot can be in Farm mode walking up (IsFarming true, no damage yet -> we
   miss it), and a bot can trade with a neutral while in Roam/Push mode
   (damage, IsFarming false -> we over-count).  Direction of the error is
   therefore NOT signed, and no reading below may be quoted as a bound.

2. `preferedCamp` is bot-internal (`campswitch_domain` says the same thing for
   the same block).  THIS FILE DOES NOT PROXY THE LATCH AT ALL, and the reason
   is a measured one -- see THE FALSE POSITIVE THAT KILLED THE FIRST DESIGN.

THE FALSE POSITIVE THAT KILLED THE FIRST DESIGN (kept so nobody rebuilds it)
---------------------------------------------------------------------------
The first cut anchored the latch on a sustained CLOSING RUN toward the camp
(>= 5 samples of falling distance, >= 500 u closed), deliberately NOT on
arrival, because a working `arbheart` is exactly what stops the bot arriving --
anchoring on arrival would drive the armed leg's domain to zero BY CONSTRUCTION.
That reasoning is still right.  The design was still wrong, and one frame read
showed why.  `20260912_095226_slot1` (seed 13019, ARMED leg, radiant)
`crystal_maiden` scored a 7,232 u "approach" to camp 2 ending in an
"arrived anyway":

    t=1302.5..1307.5  pos frozen (1744,1290)  hp_pct=0.00   <- a CORPSE
    t=1308.5          pos=(-6645,-6568)       hp_pct=1.00   <- RESPAWN, fountain
    t=1333.3          first engagement at camp 2             <- "arrival"
    storm_spirit engaged camp 2 from t=1307.9 to t=1312.7    <- gone by t=1320

So the "approach" was a respawn walk out of the fountain, and by the time CM
reached the camp the ally had been gone for 21 s.  `arbheart` SHOULD let her
take that camp; the run scored it as the gate failing.  The defect is not the
corpse (alive_at already dropped those frames) -- it is that the outcome test
asked "did he arrive within 30 s" and never asked "was the ally STILL THERE
when he did".  A release predicate that has gone false cannot be violated.

WHAT IS MEASURED INSTEAD: THE CONTESTED ARRIVAL
-----------------------------------------------
No latch proxy is needed, because the harm #455 describes is directly
observable: a bot BEGINS farming a camp while a team-mate is already on it.

    CONTESTED ARRIVAL := hero B starts an engagement block on camp C at t0,
    and some living ally A != B is within `ALLY_R` of C at t0 AND is himself
    engaging C within +/-`OCC_WIN` of t0.

Both the numerator and the denominator (all arrivals) are read off the same
engagement stream; neither depends on bot-internal state, and neither is
conditioned on anything the armed leg changes except the behaviour under test.
A working `arbheart` removes exactly these, so the reading is the CONTESTED
SHARE and a working gate drives it DOWN.

WHAT IS EXACT.  The camp SET (clustered from the neutral-creep stream by
`campswitch_domain.derive_camps`, certified on two disjoint halves plus the
map's 180-degree symmetry) and the 800 u radius, which is read out of the Lua
by `release_constants()` rather than retyped.

#148 / RULING 54 DISCIPLINE
---------------------------
`arbheart` IS armed on one leg here, so the split is a real contrast, not a
null channel.  Both strata are always printed (rule 4 (i-a)).  The estimator is
the PAIRED arm via `strata.py` -- per seed first, then the arithmetic mean
across seeds, never pooled by game count (rule 4 (i-d)).

Usage:
    arbheart_release.py <sweep_dir> [<sweep_dir> ...] [--out out.json]
    arbheart_release.py --selfcheck
"""
import argparse
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402
from ancient_camp_domain import is_hero, load  # noqa: E402
from campswitch_domain import (blocks_of, derive_camps, engagements,  # noqa: E402
                               nearest_camp)
from creeppull_domain import DIRE, RADIANT, load_sweep  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..', '..'))
FARM_MODE = os.path.join(REPO, 'bots', 'mode_farm_generic.lua')

GEOM_GAMES = 6        # games used to derive the camp centroids
OCC_WIN = 5.0         # +/- seconds around a frame that an ally engagement counts






def release_constants(path=FARM_MODE):
    """Read the 800 u ally radius and the 1 Hz throttle out of the gate body.

    Never retyped from memory: a constant that drifts in the Lua and not here
    turns every reading into a measurement of a stale source file.
    """
    src = open(path).read()
    i = src.find("J.IsSoakCandidate('arbheart')")
    if i < 0:
        raise SystemExit('[fatal] arbheart gate not found in %s' % path)
    body = src[i:i + 2000]
    m = re.search(r'GetUnitToLocationDistance\(member, vCamp\)\s*<=\s*(\d+)', body)
    if not m:
        raise SystemExit('[fatal] ally radius not found in the arbheart body')
    t = re.search(r'_farm_repick_at\s*=\s*GameTime\(\)\s*\+\s*([\d.]+)', src)
    return float(m.group(1)), float(t.group(1) if t else 1.0)


ALLY_R, THROTTLE = release_constants()


def camp_engagement_index(engs):
    """camp -> hero -> sorted engagement times."""
    idx = defaultdict(lambda: defaultdict(list))
    for (h, t, ci) in engs:
        idx[ci][h].append(t)
    for ci in idx:
        for h in idx[ci]:
            idx[ci][h].sort()
    return idx


def _near_time(ts, t, win):
    import bisect
    i = bisect.bisect_left(ts, t - win)
    return i < len(ts) and ts[i] <= t + win


def scan_game(tl, camps):
    """Every camp ARRIVAL in one game, flagged contested / uncontested."""
    frames, team = entities.frames_by_hero(tl)
    deaths = entities.death_times(tl)
    engs, unsnapped = engagements(tl, frames, camps)
    cidx = camp_engagement_index(engs)

    per_hero_eng = defaultdict(list)
    for r in engs:
        per_hero_eng[r[0]].append(r)

    # exact-t index over the CLEAN frame table -- a hero absent from a tick is
    # simply absent; the index never interpolates a position (#176).
    by_t = defaultdict(dict)
    for h, rows in frames.items():
        dd = deaths.get(h, [])
        for s in rows:
            if entities.alive_at(rows, dd, s['t']):
                by_t[s['t']][h] = s

    tick = sorted(by_t)

    def snap(t):
        """The sample tick at or just before t (never an interpolation)."""
        import bisect
        i = bisect.bisect_right(tick, t) - 1
        return tick[i] if i >= 0 else None

    eps = []
    counts = Counter()
    for h, rows in per_hero_eng.items():
        for (_, ci, t0, t1) in blocks_of(rows):
            camp = camps[ci]
            counts['arrivals'] += 1
            st = snap(t0)
            holder = None
            if st is not None:
                for other, s in by_t.get(st, {}).items():
                    if other == h or team.get(other) != team.get(h):
                        continue
                    if math.dist(camp, (s['x'], s['y'])) > ALLY_R:
                        continue
                    # ... and that ally is himself working THIS camp
                    if not _near_time(cidx[ci].get(other, []), t0, OCC_WIN):
                        continue
                    holder = other
                    break
            contested = holder is not None
            counts['contested' if contested else 'clean'] += 1
            eps.append({'hero': h, 'team': team.get(h), 'camp': ci,
                        't': t0, 'end': t1, 'contested': contested,
                        'holder': holder})
    return eps, counts, unsnapped


def scan(dirs):
    games = []
    for d in dirs:
        for row in load_sweep(d):
            p = os.path.join(d, 'timelines', row['game'] + '.timeline.json')
            if os.path.exists(p):
                games.append((p, row))
    if not games:
        sys.exit('[fatal] no timelines under %s' % dirs)
    camps, geom = derive_camps([p for p, _ in games[:GEOM_GAMES]])
    out = []
    for p, row in games:
        tl = load(p)
        eps, counts, unsnapped = scan_game(tl, camps)
        armed_team = RADIANT if row['side'] == 'radiant' else DIRE
        for e in eps:
            e['leg'] = 'armed' if e['team'] == armed_team else 'baseline'
        out.append({'game': row['game'], 'seed': row['seed'],
                    'side': row['side'], 'eps': eps,
                    'counts': dict(counts), 'unsnapped': unsnapped})
        del tl
    return out, camps, geom


def report(res, camps, geom):
    print('camps: %d clusters (halves agree %s, sym share %.2f, worst %.0f u)'
          % (geom['n'], geom['halves_agree'], geom['sym_share'],
             geom['sym_worst']))
    print('constants read from the Lua: ally radius %.0f u, throttle %.1f s'
          % (ALLY_R, THROTTLE))
    print('games: %d' % len(res))
    tot = Counter()
    per_leg = defaultdict(Counter)
    per_seed = defaultdict(lambda: defaultdict(Counter))
    for g in res:
        for k, v in g['counts'].items():
            tot[k] += v
        for e in g['eps']:
            per_leg[e['leg']]['arrivals'] += 1
            stratum = 'ab' if g['side'] == 'radiant' else 'ba'
            per_seed[g['seed']][(e['leg'], stratum)]['arrivals'] += 1
            if e['contested']:
                per_leg[e['leg']]['contested'] += 1
                per_seed[g['seed']][(e['leg'], stratum)]['contested'] += 1
    print('\ncamp arrivals (denominator): %d' % tot['arrivals'])
    print('CONTESTED arrivals (an ally within %.0f u of that camp AND working '
          'it): %d' % (ALLY_R, tot['contested']))
    print('\nper leg (rule 4 (i-a): both strata registered)')
    for leg in ('armed', 'baseline'):
        c = per_leg[leg]
        n = c['arrivals']
        print('  %-9s arrivals=%-5d contested=%-4d share=%s'
              % (leg, n, c['contested'],
                 ('%.4f' % (c['contested'] / n)) if n else 'n/a'))
    print('\nper seed x stratum')
    for seed in sorted(per_seed):
        for leg in ('armed', 'baseline'):
            for st in ('ab', 'ba'):
                c = per_seed[seed][(leg, st)]
                print('  seed=%s %-9s %s arrivals=%-4d contested=%-3d'
                      % (seed, leg, st, c['arrivals'], c['contested']))
    return tot, per_leg, per_seed


def selfcheck():
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-42s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    chk('ally radius read from Lua == 800', ALLY_R == 800.0, 'got %.0f' % ALLY_R)
    chk('throttle read from Lua == 1.0', THROTTLE == 1.0, 'got %.1f' % THROTTLE)

    # _near_time window
    chk('_near_time inside window', _near_time([10.0], 12.0, OCC_WIN))
    chk('_near_time outside window', not _near_time([10.0], 20.0, OCC_WIN))

    # blocks_of: one visit, then a separate one after a long gap.
    b = blocks_of([('h', 10.0, 1), ('h', 11.0, 1), ('h', 60.0, 1)])
    chk('a 49 s gap splits one camp visit into two', len(b) == 2, str(b))

    # THE REGRESSION THAT MOTIVATED THE REWRITE.  Ally works the camp early and
    # leaves; the bot arrives long after.  The release predicate is FALSE at the
    # arrival instant, so this must NOT be contested -- the first design scored
    # exactly this shape as the gate failing (see the module docstring).
    camps = [(0.0, 0.0)]
    tl = {'snapshots': [], 'events': []}
    # pre-horn samples: frames_by_hero drops any entity first seen after the
    # horn (its anti-illusion guard), so a fixture that starts at t=1300 has
    # NO heroes at all -- which is how this selfcheck first failed.
    for h, idx in (('npc_dota_hero_crystal_maiden', 11),
                   ('npc_dota_hero_storm_spirit', 22)):
        tl['snapshots'].append({'t': -60.0, 'idx': idx, 'hero': h, 'team': 2,
                                'x': 6000.0, 'y': 0.0, 'hp_pct': 1.0, 'level': 1,
                                'gold': 0, 'hp': 500, 'mana': 100})
    for t in [float(x) for x in range(1300, 1341)]:
        # ally sits ON the camp from 1300-1313, then walks far away
        ax = 100.0 if t <= 1313.0 else 9000.0
        tl['snapshots'] += [
            {'t': t, 'idx': 11, 'hero': 'npc_dota_hero_crystal_maiden',
             'team': 2, 'x': max(0.0, 6000.0 - 200.0 * (t - 1300.0)), 'y': 0.0,
             'hp_pct': 1.0, 'level': 1, 'gold': 0, 'hp': 500, 'mana': 100},
            {'t': t, 'idx': 22, 'hero': 'npc_dota_hero_storm_spirit',
             'team': 2, 'x': ax, 'y': 0.0, 'hp_pct': 1.0, 'level': 1,
             'gold': 0, 'hp': 500, 'mana': 100}]
    def dmg(actor, t):
        return {'t': t, 'type': 'DAMAGE', 'actor': actor,
                'target': 'npc_dota_neutral_kobold', 'inflictor': '', 'value': 10,
                'actor_hero': True, 'target_hero': False}
    tl['events'] += [dmg('npc_dota_hero_storm_spirit', t)
                     for t in (1307.9, 1310.0, 1312.7)]
    tl['events'] += [dmg('npc_dota_hero_crystal_maiden', t)
                     for t in (1333.3, 1334.5, 1335.5)]
    eps, counts, _ = scan_game(tl, camps)
    cm = [e for e in eps if e['hero'] == 'crystal_maiden']
    chk('the ally-left-21s-ago arrival is NOT contested',
        len(cm) == 1 and not cm[0]['contested'], str(cm))

    # ... and the same shape WITH the ally still present must be contested.
    tl2 = json.loads(json.dumps(tl))
    for s in tl2['snapshots']:
        if s['hero'] == 'npc_dota_hero_storm_spirit':
            s['x'] = 100.0
    tl2['events'] += [dmg('npc_dota_hero_storm_spirit', t)
                      for t in (1332.0, 1334.0)]
    eps2, _, _ = scan_game(tl2, camps)
    cm2 = [e for e in eps2 if e['hero'] == 'crystal_maiden']
    chk('the ally-still-on-it arrival IS contested',
        len(cm2) == 1 and cm2[0]['contested'], str(cm2))

    print('SELFCHECK', 'ALL PASS' if ok else 'FAIL')
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dirs', nargs='*')
    ap.add_argument('--out')
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.dirs:
        ap.error('need at least one sweep dir')
    res, camps, geom = scan(a.dirs)
    report(res, camps, geom)
    if a.out:
        with open(a.out, 'w') as fh:
            json.dump({'games': res, 'geom': geom,
                       'ally_r': ALLY_R, 'throttle': THROTTLE}, fh, indent=1)
        print('\nwrote %s' % a.out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
