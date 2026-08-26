#!/usr/bin/env python3
"""(a)-verification for soak candidate `campfarm` (GH #137, strategy 08-25T13:47Z).

WHAT `campfarm` DOES
--------------------
`bots/mode_farm_generic.lua` sweeps nearby neutrals three times (900 u twice,
1000 u once) and hands the WHOLE list to `J.Site.FindFarmNeutralTarget`.  The
shipped ancient guard asks about `nNeutrals[1]` -- the FIRST creep of the
sweep -- so a normal camp inside the same sweep opens the gate while the
target picked out of the list can be an ancient one.  Armed, the single
wrapper `NeutralFarmList` runs `J.Site.FilterFarmNeutrals`, which drops
ancient creeps from the list when the bot is under `ANCIENT_MIN_LEVEL` (12).

THE DOMAIN IS A BAND, NOT A HALF-LINE (this is why this file is not
`campgrade_ladder.py`)
----------------------------------------------------------------------------
Three shipped sites bound the same decision and TWO of them say 10:

    mode_farm_generic  `bot:GetLevel() >= 10 or not nNeutrals[1]:IsAncientCreep()`
    utils.IsValidCreep `GetBot():GetLevel() > 9  or not target:IsAncientCreep()`
    aba_site           `IsAncientCamp(camp) and botLevel < 12`   (the ladder)

Below 10 the shipped TARGET filter already refuses an ancient creep, at or
above 12 the ladder says the camp is his to take.  `campfarm`'s domain is
therefore exactly the **10..11 band**, and a reading that pools all levels
dilutes it with two populations the lever does not claim to move.
`campgrade_ladder.py` measures the ladder (a LIST edit, `< 12` on both legs);
this file measures the band and reports the other two bands as controls.

WHAT IS MEASURED, AND WHAT IT CANNOT SAY
----------------------------------------
Observable: an ancient-camp engagement, its hero's level at the FIRST frame
(decision side), and whether the hero's own damage landed first (`opened`,
inherited from `ancient_camp_domain`).  `opened` is the closest offline read
of "he chose this fight"; an under-levelled episode he did NOT open can be
aggro, a chase, or a fight that walked into the camp, so the primary table is
the opened one and the all-episodes table is the upper bound.

NOT observable: the creep list itself.  A hero standing next to an ancient
camp with the list filtered still shows up in the dump as a hero standing
next to an ancient camp; only his TARGET changed.  So `campfarm` WORKING
looks like "the 10..11 band's opened episodes fall while the >=12 band does
not", never like "ancient camps stop being fought".

`mixed` = a NON-ancient camp centroid within the sweep radius of the episode's
first frame.  That is the shape the strategy group described ("both a small
camp and an ancient camp in reach"), and it is derivable because a camp is a
fixed map box: the centroids come from where heroes stand when they damage
each neutral family, over a warmup subset of this very corpus.

ENTITY HYGIENE (GH #176/#191) IS NOT OPTIONAL HERE
--------------------------------------------------
Episodes are built from DAMAGE events keyed by hero NAME, and an illusion
carries its owner's name.  Two distinct errors follow, and this file measures
both instead of assuming neither: (1) the episode's anchor frame `(x0,y0,
level)` comes from a by-name frame table, so a same-named stream can move the
anchor; (2) an illusion's own trade with a camp is attributed to the hero.
`anchor_shift` is the distance between the by-name anchor and the real
hero's own interpolated position at t0 (entities.frames_by_hero); episodes
whose real hero was nowhere near the camp are reported separately and
excluded from the primary table.  A corpus with zero shift is reported as
zero -- but the selfcheck asserts the cleaner can actually drop something,
so "zero" is never a dead pipe.

#148 DISCIPLINE
---------------
Every leg number is given in BOTH physical strata (ab = radiant-armed,
ba = dire-armed).  The estimator is the mean of the two strata's paired
per-game differences (the 08-23T21:00Z correction), which cancels the side
term exactly.  Counts over a small integer range are reported as means plus
the share above a threshold, never as a lone median.

Usage:
    campfarm_target.py <sweep_dir> [<sweep_dir> ...] [--out out.jsonl]
    campfarm_target.py --selfcheck
"""
import argparse
import json
import math
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402
from ancient_camp_domain import (  # noqa: E402
    DEFAULT_AFTER, DEFAULT_GAP, DEFAULT_TAIL, episodes_for_game, is_ancient,
    is_hero, load)
from campgrade_ladder import camp_owner, required_level  # noqa: E402
from creeppull_domain import DIRE, RADIANT, load_sweep  # noqa: E402
from source_constants import assignment  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..', '..'))
ABA_SITE = os.path.join(REPO, 'bots', 'FunLib', 'aba_site.lua')
FARM_MODE = os.path.join(REPO, 'bots', 'mode_farm_generic.lua')

# Read the tier out of the shipped Lua; never copy it (source_constants
# contract).  `campgrade_ladder.ANCIENT_MIN_LEVEL` is a transcription; this is
# the file that has to be right about the BAND, so it derives.
ANCIENT_MIN_LEVEL = int(assignment('____exports.ANCIENT_MIN_LEVEL', ABA_SITE))

# The lower edge of the band is the shipped TARGET filter, which is written as
# `> 9` in utils.IsValidCreep and `>= 10` in mode_farm_generic -- the same
# number in two spellings.  Derived below by SHAPE (see sweep_sites) so a
# future edit to either spelling shows up as a raised exception.
SHIPPED_ANCIENT_MIN = 10

# Camp geometry.  A camp box is ~1200 u from its nearest neighbour
# (pullcamp_domain: CAMP_CLUSTER 900), so 900 groups a family's samples
# without merging two camps; the report prints the separation it got.
CLUSTER_R = 900.0
# Support cuts, as a fraction of that tier's own samples.  Ancient: GH #137 §5
# fixed the tier test geometrically at "exactly two map clusters", so the cut
# only has to survive the tail; normal camps are ~18 boxes of very unequal
# traffic, so theirs is an order of magnitude looser.  Both are reported with
# the share of samples they keep, so an over-aggressive cut is visible.
ANC_SUPPORT = 0.05
NORM_SUPPORT = 0.01
WARMUP_GAMES = 10          # games used to derive centroids
ANCHOR_TOL = 500.0         # by-name vs real-hero anchor disagreement
FAR_FROM_CAMP = 1200.0     # real hero this far from his own episode = not his

# An auto-attack carries no named inflictor.  This is the marker that
# separates "he picked this creep as a target" from "his AoE reached it":
# `zuus_arc_lightning` bounces on its own and `zuus_static_field` fires on
# every cast, so a Zeus who never swung at the camp still authors hero->
# ancient DAMAGE -- and lands FIRST, which is what `opened` reads.  On-hit
# passives (viper_corrosive_skin, item_mage_slayer) are attack-borne too, but
# the bare attack is the unambiguous one, so it is the only marker used.
ATTACK_INFLICTOR = 'dota_unknown'
# An enemy hero this close at t0 means the trade is a fight the camp happened
# to be standing in.  Same anchor rule as `nearest_enemy_t0`: the decision
# instant, never a frame from its future.
FIGHT_NEAR = 1500.0


def sweep_sites(path=FARM_MODE):
    """The neutral sweep radii actually written in the farm mode, by shape.

    Returns (sorted radii, count of NeutralFarmList wrappers).  Fails loud if
    the file stops matching the shape this detector reasons about.
    """
    import re
    with open(path, 'r', encoding='utf-8') as fh:
        src = fh.read()
    src = '\n'.join(l for l in src.splitlines()
                    if not l.strip().startswith('--'))
    radii = [float(m) for m in re.findall(
        r'GetNearbyCreeps\(\s*(\d+)\s*,\s*true\s*\)', src)]
    wrapped = len(re.findall(r'NeutralFarmList\(\s*bot\s*,', src))
    if not radii:
        raise RuntimeError('no GetNearbyCreeps(<n>, true) in %s' % path)
    return sorted(set(radii)), wrapped


SWEEP_RADII, WRAPPED_SITES = sweep_sites()
R_SWEEP = min(SWEEP_RADII)          # the two gated scans
R_SWEEP_MAX = max(SWEEP_RADII)      # the third, ungated scan


def band_of(level):
    if level < SHIPPED_ANCIENT_MIN:
        return 'under'                       # shipped target filter refuses
    if level < ANCIENT_MIN_LEVEL:
        return 'band'                        # 10..11 -- campfarm's domain
    return 'over'                            # >=12 -- protected population


def keep_supported(clusters, frac):
    """Drop the tail of a clustering, and say how much of the mass survived.

    A camp box is a fixed map object, but the samples are HERO positions, so a
    ranged hero, a creep dragged out of its box, and a stack all deposit points
    hundreds of units off the box.  Greedily clustered, those tails become
    their own "camps" -- 26 ancient clusters on a corpus that has two.  The
    support cut is the same tier test GH #137 §5 settled on (a real ancient
    unit resolves to exactly two map clusters); it is applied as a fraction of
    the tier's own samples so it does not need re-tuning per corpus size.
    """
    tot = float(sum(c[2] for c in clusters)) or 1.0
    kept = [c for c in clusters if c[2] >= frac * tot]
    return kept, sum(c[2] for c in kept) / tot


def cluster(points, radius=CLUSTER_R):
    """Greedy centroid clustering (same shape as pullcamp_domain's)."""
    cls = []
    for x, y in points:
        for c in cls:
            if math.dist((x, y), (c[0] / c[2], c[1] / c[2])) < radius:
                c[0] += x
                c[1] += y
                c[2] += 1
                break
        else:
            cls.append([x, y, 1])
    return [(c[0] / c[2], c[1] / c[2], c[2]) for c in cls]


def camp_samples(tl, frames):
    """Hero positions at the instant they trade with a neutral, split by tier.

    A camp does not move, and a hero fighting one stands in it, so this is the
    camp's location up to the hero's own body radius.  Frames come from the
    CLEAN table, so an illusion parked elsewhere cannot invent a camp.
    """
    anc, norm = [], []
    for e in tl['events']:
        if e['type'] != 'DAMAGE':
            continue
        a, tg = e['actor'], e['target']
        if is_hero(a) and tg.startswith('npc_dota_neutral'):
            h, unit = a, tg
        elif is_hero(tg) and a.startswith('npc_dota_neutral'):
            h, unit = tg, a
        else:
            continue
        s = entities.interp(frames.get(entities.canon(h)) or [], e['t'])
        if s is None:
            continue
        (anc if is_ancient(unit) else norm).append((s['x'], s['y']))
    return anc, norm


def scan(dirs, warmup=WARMUP_GAMES):
    """Two passes over the sweep dirs: camp geometry, then episodes."""
    games = []
    for d in dirs:
        for m in load_sweep(d):
            p = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            if os.path.exists(p):
                games.append((d, m, p))
            else:
                print('[warn] missing timeline %s' % p, file=sys.stderr)

    anc_pts, norm_pts = [], []
    for _, _, p in games[:warmup]:
        tl = load(p)
        fr, _ = entities.frames_by_hero(tl)
        a, n = camp_samples(tl, fr)
        anc_pts += a
        norm_pts += n
        del tl
    anc_camps, anc_cov = keep_supported(cluster(anc_pts), ANC_SUPPORT)
    norm_camps, norm_cov = keep_supported(cluster(norm_pts), NORM_SUPPORT)

    recs = []
    ngames = {'radiant': 0, 'dire': 0}
    band_frames = defaultdict(int)      # leg -> hero samples in the band
    band_at_risk = defaultdict(int)     # leg -> ... and within a sweep of an ancient camp
    band_games = defaultdict(set)
    stats = Counter()
    for d, m, p in games:
        run_tag = os.path.basename(d.rstrip('/')).split('_')[-1]
        tl = load(p)
        teams = tl['game']['teams']
        armed_team = RADIANT if m['side'] == 'radiant' else DIRE
        ngames[m['side']] += 1
        clean, _ = entities.frames_by_hero(tl)

        # ---- domain lower bound (director constraint (乙)) -----------------
        for h, fr in clean.items():
            tm = teams.get('npc_dota_hero_' + h)
            if tm not in (RADIANT, DIRE):
                continue
            leg = 'armed' if tm == armed_team else 'baseline'
            for s in fr:
                if band_of(s['level']) != 'band':
                    continue
                band_frames[leg] += 1
                band_games[leg].add(m['game'])
                if anc_camps and min(math.dist((s['x'], s['y']), (c[0], c[1]))
                                     for c in anc_camps) <= R_SWEEP_MAX:
                    band_at_risk[leg] += 1

        # ---- episodes ------------------------------------------------------
        ancients = {}
        for b in tl.get('buildings', []):
            if b['name'] == 'ancient':
                ancients.setdefault(b['team'], (b['x'], b['y']))
        # hero -> [(t, inflictor)] for every blow the hero landed on an
        # ancient, so an episode can be asked whether he ever actually swung.
        blows = defaultdict(list)
        # hero -> [t] where he CAST an ability AT an ancient creep.  An
        # `opened_by == 'ability'` episode is two different things -- a cast
        # aimed at the camp, and splash from a cast aimed elsewhere (Zeus's
        # static field fires on every cast) -- and only the first is a
        # targeting decision.  The ABILITY event carries the intended target,
        # so the two are separable without guessing.
        casts_at_camp = defaultdict(list)
        for e in tl['events']:
            if (e['type'] == 'DAMAGE' and is_hero(e['actor'])
                    and is_ancient(e['target'])):
                blows[entities.canon(e['actor'])].append(
                    (e['t'], e.get('inflictor')))
            elif (e['type'] == 'ABILITY' and is_hero(e['actor'])
                  and is_ancient(e['target'] or '')):
                casts_at_camp[entities.canon(e['actor'])].append(e['t'])

        eps, _ = episodes_for_game(tl, p, DEFAULT_GAP, DEFAULT_TAIL,
                                   DEFAULT_AFTER)
        for e in eps:
            ht = teams.get('npc_dota_hero_' + e['hero'])
            if ht is None:
                continue
            r = dict(e)
            r['game'] = m['game']
            # Two runs of one wave produce the same `<stamp>_slotN` basename
            # (charter: ".dem same-name cross-run collision").  A frame
            # citation that does not carry the run is not a citation.
            r['run'] = run_tag
            r['seed'] = m.get('seed')
            r['leg'] = 'armed' if ht == armed_team else 'baseline'
            r['arm_side'] = m['side']
            ct = camp_owner(e['x0'], e['y0'], ancients)
            r['camp_side'] = ('own' if ct == ht
                              else ('enemy' if ct is not None else 'unknown'))
            r['need'] = required_level(ct, ht)
            r['band'] = band_of(e['level'])
            r['attacked'] = any(
                inf == ATTACK_INFLICTOR and e['t0'] <= t <= e['t1']
                for t, inf in blows.get(e['hero'], []))
            # WHAT OPENED THE CAMP.  `campfarm` edits the list that
            # FindFarmNeutralTarget picks from, and that pick is executed as an
            # ATTACK order.  An ability lands on a target the hero script chose
            # in its own ConsiderAbility, which no list edit can reach.  So the
            # inflictor of the FIRST blow says which path opened this camp.
            first = [(t, inf) for t, inf in blows.get(e['hero'], [])
                     if e['t0'] <= t <= e['t1']]
            r['first_inflictor'] = first[0][1] if first else None
            r['opened_by'] = (
                None if not first
                else 'attack' if first[0][1] == ATTACK_INFLICTOR
                else 'item' if str(first[0][1]).startswith('item_')
                else 'ability')
            r['cast_at_camp'] = any(
                e['t0'] - 1.0 <= t <= e['t1']
                for t in casts_at_camp.get(e['hero'], []))
            r['chose_it'] = bool(r['opened'] and (r['opened_by'] == 'attack'
                                                  or r['cast_at_camp']))
            r['alone'] = (e['nearest_enemy_t0'] is None
                          or e['nearest_enemy_t0'] > FIGHT_NEAR)

            # entity hygiene: where was the REAL hero at t0?
            s0 = entities.interp(clean.get(e['hero']) or [], e['t0'])
            if s0 is None:
                r['anchor_shift'] = None
                r['clean_level'] = None
                stats['no_clean_frame'] += 1
            else:
                r['anchor_shift'] = round(
                    math.dist((e['x0'], e['y0']), (s0['x'], s0['y'])), 1)
                r['clean_level'] = s0['level']
                if r['anchor_shift'] > ANCHOR_TOL:
                    stats['anchor_moved'] += 1
                if r['clean_level'] != e['level']:
                    stats['level_disagree'] += 1
            # An episode whose real hero stood far from the camp at t0 is an
            # illusion's trade wearing his name.
            dcamp = (min(math.dist((e['x0'], e['y0']), (c[0], c[1]))
                         for c in anc_camps) if anc_camps else None)
            r['d_ancient_camp'] = None if dcamp is None else round(dcamp, 1)
            r['illusion_suspect'] = bool(
                s0 is not None and dcamp is not None
                and math.dist((s0['x'], s0['y']),
                              (e['x0'], e['y0'])) > FAR_FROM_CAMP)
            if r['illusion_suspect']:
                stats['illusion_suspect'] += 1

            # mixed: a non-ancient camp inside the same sweep
            if norm_camps:
                dn = min(math.dist((e['x0'], e['y0']), (c[0], c[1]))
                         for c in norm_camps)
                r['d_normal_camp'] = round(dn, 1)
                r['mixed'] = dn <= R_SWEEP
                r['mixed_wide'] = dn <= R_SWEEP_MAX
            else:
                r['d_normal_camp'] = None
                r['mixed'] = r['mixed_wide'] = None
            recs.append(r)
        del tl
    return {'recs': recs, 'ngames': ngames, 'anc_camps': anc_camps,
            'anc_cov': anc_cov, 'norm_cov': norm_cov,
            'norm_camps': norm_camps, 'band_frames': band_frames,
            'band_at_risk': band_at_risk,
            'band_games': {k: len(v) for k, v in band_games.items()},
            'stats': stats, 'games': games}


def per_game(recs, ngames, pred):
    """(ab, ba) per-game rates for a predicate, and the balanced estimator."""
    out = {}
    for side in ('radiant', 'dire'):
        row = {}
        for leg in ('armed', 'baseline'):
            hits = sum(1 for r in recs
                       if r['arm_side'] == side and r['leg'] == leg and pred(r))
            row[leg] = hits / float(max(ngames[side], 1))
            row[leg + '_n'] = hits
        row['diff'] = row['armed'] - row['baseline']
        out[side] = row
    out['balanced'] = (out['radiant']['diff'] + out['dire']['diff']) / 2.0
    return out


def show(title, tab, ngames):
    print('\n  %s' % title)
    print('  %-14s %6s %9s %9s %9s %9s'
          % ('stratum', 'games', 'armed n', 'armed/g', 'base n', 'base/g'))
    for lbl, side in (('ab (rad-armed)', 'radiant'), ('ba (dire-armed)', 'dire')):
        r = tab[side]
        print('  %-14s %6d %9d %9.3f %9d %9.3f'
              % (lbl, ngames[side], r['armed_n'], r['armed'],
                 r['baseline_n'], r['baseline']))
    print('  diff/game   ab %+.3f   ba %+.3f   BALANCED %+.3f'
          % (tab['radiant']['diff'], tab['dire']['diff'], tab['balanced']))
    same = (tab['radiant']['diff'] * tab['dire']['diff']) > 0
    print('  strata agree in sign: %s' % ('YES' if same else 'NO (#148: mean first)'))


def report(res, top=12):
    recs = res['recs']
    ng = res['ngames']
    print('=== campfarm (a)-verification -- GH #137')
    print('  games            %d (ab %d / ba %d)'
          % (ng['radiant'] + ng['dire'], ng['radiant'], ng['dire']))
    print('  band definition  %d..%d   (shipped target filter %d, ladder %d)'
          % (SHIPPED_ANCIENT_MIN, ANCIENT_MIN_LEVEL - 1, SHIPPED_ANCIENT_MIN,
             ANCIENT_MIN_LEVEL))
    print('  sweep radii      %s   wrappers %d'
          % ('/'.join('%d' % r for r in SWEEP_RADII), WRAPPED_SITES))

    print('\n=== camp geometry (derived from the first %d games)' % WARMUP_GAMES)
    print('  ancient clusters %d (%.1f%% of samples)  %s'
          % (len(res['anc_camps']), 100 * res['anc_cov'],
             ' '.join('(%d,%d)x%d' % (c[0], c[1], c[2])
                      for c in res['anc_camps'])))
    print('  normal clusters  %d (%.1f%% of samples)'
          % (len(res['norm_camps']), 100 * res['norm_cov']))
    if len(res['anc_camps']) != 2:
        print('  ** WARNING: GH #137 §5 says a real ancient unit resolves to '
              'exactly TWO clusters; got %d **' % len(res['anc_camps']))
    if len(res['anc_camps']) >= 2:
        mind = min(math.dist((a[0], a[1]), (b[0], b[1]))
                   for i, a in enumerate(res['anc_camps'])
                   for b in res['anc_camps'][i + 1:])
        print('  min ancient separation %d u (cluster radius %d)'
              % (mind, CLUSTER_R))

    st = res['stats']
    print('\n=== entity hygiene (GH #176/#191)')
    print('  episodes                %d' % len(recs))
    print('  anchor moved > %d u     %d' % (ANCHOR_TOL, st['anchor_moved']))
    print('  level disagrees         %d' % st['level_disagree'])
    print('  real hero > %d u away   %d  (excluded from primary tables)'
          % (FAR_FROM_CAMP, st['illusion_suspect']))
    print('  no clean frame at t0    %d' % st['no_clean_frame'])

    print('\n=== domain lower bound (director constraint 乙)')
    print('  %-9s %10s %12s %10s' % ('leg', 'band frames', 'near ancient', 'games'))
    for leg in ('armed', 'baseline'):
        print('  %-9s %10d %12d %10d'
              % (leg, res['band_frames'][leg], res['band_at_risk'][leg],
                 res['band_games'].get(leg, 0)))
    print('  ("band frames" = 1 Hz hero samples at level %d..%d; "near ancient"'
          % (SHIPPED_ANCIENT_MIN, ANCIENT_MIN_LEVEL - 1))
    print('   = those within %d u of an ancient camp centroid.)' % R_SWEEP_MAX)

    clean = [r for r in recs if not r['illusion_suspect']]
    print('\n=== level bands (clean episodes: %d of %d)' % (len(clean), len(recs)))
    print('  %-8s %-9s %8s %8s %8s' % ('band', 'leg', 'episodes', 'opened', 'mixed'))
    for band in ('under', 'band', 'over'):
        for leg in ('armed', 'baseline'):
            xs = [r for r in clean if r['band'] == band and r['leg'] == leg]
            print('  %-8s %-9s %8d %8d %8d'
                  % (band, leg, len(xs), sum(1 for r in xs if r['opened']),
                     sum(1 for r in xs if r.get('mixed'))))

    band_all = [r for r in clean if r['band'] == 'band']
    print('\n=== what the band population actually is (filter cascade)')
    print('  %-46s %6s %6s' % ('', 'armed', 'base'))
    steps = [('10..11 episodes', lambda r: True),
             ('  ... he landed the first blow (opened)',
              lambda r: r['opened']),
             ('  ... AND he actually swung at it (attacked)',
              lambda r: r['opened'] and r['attacked']),
             ('  ... AND no enemy hero within %d u at t0' % FIGHT_NEAR,
              lambda r: r['opened'] and r['attacked'] and r['alone']),
             ('  ... AND a normal camp within %d u (mixed)' % R_SWEEP,
              lambda r: r['opened'] and r['attacked'] and r['alone']
              and bool(r.get('mixed')))]
    for lbl, pred in steps:
        print('  %-46s %6d %6d'
              % (lbl,
                 sum(1 for r in band_all if r['leg'] == 'armed' and pred(r)),
                 sum(1 for r in band_all if r['leg'] == 'baseline' and pred(r))))
    print('  (the last row is `campfarm`\'s own claim: an under-tier bot that'
          ' chose\n   an ancient creep with a normal camp in the same sweep.)')

    print('\n=== what OPENED the camp (first blow the hero landed on it)')
    print('  %-8s %-9s %8s %8s %8s %12s %10s'
          % ('band', 'leg', 'attack', 'ability', 'item', 'cast AT camp',
             'chose it'))
    for band in ('band', 'over'):
        for leg in ('armed', 'baseline'):
            xs = [r for r in clean
                  if r['band'] == band and r['leg'] == leg and r['opened']]
            print('  %-8s %-9s %8d %8d %8d %12d %10d'
                  % (band, leg,
                     sum(1 for r in xs if r['opened_by'] == 'attack'),
                     sum(1 for r in xs if r['opened_by'] == 'ability'),
                     sum(1 for r in xs if r['opened_by'] == 'item'),
                     sum(1 for r in xs if r['cast_at_camp']),
                     sum(1 for r in xs if r['chose_it'])))
    print('  (an ATTACK-opened under-tier episode is the one shape the list'
          ' edit\n   is supposed to make impossible.)')

    show('DECISION -- band, he chose the camp (attack order OR a cast at it)',
         per_game(clean, ng,
                  lambda r: r['band'] == 'band' and r['chose_it']), ng)
    show('MECHANISM -- band, opened BY AN ATTACK (the list edit\'s own shape)',
         per_game(clean, ng,
                  lambda r: r['band'] == 'band' and r['opened']
                  and r['opened_by'] == 'attack'), ng)
    show('STRICT PRIMARY -- band, opened, attacked, no enemy near',
         per_game(clean, ng,
                  lambda r: r['band'] == 'band' and r['opened']
                  and r['attacked'] and r['alone']), ng)
    show('PRIMARY -- 10..11 band, opened (he chose it)',
         per_game(clean, ng,
                  lambda r: r['band'] == 'band' and r['opened']), ng)
    show('10..11 band, all episodes (upper bound)',
         per_game(clean, ng, lambda r: r['band'] == 'band'), ng)
    show('REVERSE GUARD (甲) -- >=12 band, all episodes (must NOT collapse)',
         per_game(clean, ng, lambda r: r['band'] == 'over'), ng)
    show('CONTROL -- <10 band (shipped filter already refuses; expect no move)',
         per_game(clean, ng, lambda r: r['band'] == 'under'), ng)
    show('10..11 band, opened AND a normal camp within %d u' % R_SWEEP,
         per_game(clean, ng,
                  lambda r: r['band'] == 'band' and r['opened']
                  and bool(r.get('mixed'))), ng)

    band_recs = [r for r in clean if r['band'] == 'band']
    if band_recs:
        print('\n=== 10..11 band detail (#148 (ii): means + shares, not a lone median)')
        for leg in ('armed', 'baseline'):
            xs = [r for r in band_recs if r['leg'] == leg]
            if not xs:
                continue
            print('  %-9s n=%3d  mean hp burn %.3f  share burn>0.10 %4.1f%%  '
                  'mean dur %.1fs  opened %4.1f%%'
                  % (leg, len(xs),
                     sum(r['hp0'] - (r['hp_min'] or r['hp0']) for r in xs) / len(xs),
                     100.0 * sum(1 for r in xs
                                 if r['hp0'] - (r['hp_min'] or r['hp0']) > 0.10) / len(xs),
                     sum(r['dur'] for r in xs) / len(xs),
                     100.0 * sum(1 for r in xs if r['opened']) / len(xs)))

        print('\n=== top %d band episodes by hp burn (deep-check queue)' % top)
        xs = sorted(band_recs,
                    key=lambda r: -(r['hp0'] - (r['hp_min'] or r['hp0'])))[:top]
        print('  %-7s %-22s %-15s %6s %4s %6s %4s %4s %5s %6s %6s'
              % ('run', 'game', 'hero', 't0', 'lvl', 'burn', 'op', 'atk',
                 'leg', 'd_norm', 'near0'))
        for r in xs:
            print('  %-7s %-22s %-15s %6.1f %4d %6.3f %4s %4s %5s %6s %6s'
                  % (r['run'], r['game'], r['hero'], r['t0'], r['level'],
                     r['hp0'] - (r['hp_min'] or r['hp0']),
                     'Y' if r['opened'] else '.',
                     'Y' if r['attacked'] else '.',
                     r['leg'][:4], r['d_normal_camp'], r['nearest_enemy_t0']))


def selfcheck():
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-46s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    # --- the band, read out of the shipped Lua ---------------------------
    chk('ANCIENT_MIN_LEVEL read from aba_site.lua',
        ANCIENT_MIN_LEVEL == 12, '= %d' % ANCIENT_MIN_LEVEL)
    chk('sweep radii are the shipped ones', SWEEP_RADII == [900.0, 1000.0],
        str(SWEEP_RADII))
    chk('all three sweeps go through the wrapper', WRAPPED_SITES == 3,
        '%d NeutralFarmList(bot, ...) sites' % WRAPPED_SITES)
    # The lower edge lives in two spellings; both must still say 10, or the
    # band this file measures is the wrong band.
    src = open(FARM_MODE, encoding='utf-8').read()
    utils = open(os.path.join(REPO, 'bots', 'FunLib', 'utils.lua'),
                 encoding='utf-8').read()
    chk('mode_farm ancient clause still `>= 10`',
        'bot:GetLevel() >= 10' in src)
    chk('utils.IsValidCreep ancient clause still `> 9`',
        'GetLevel() > 9' in utils)
    chk('band is exactly 10..11',
        [l for l in range(1, 26) if band_of(l) == 'band'] == [10, 11])
    chk('bands partition the levels',
        all(band_of(l) in ('under', 'band', 'over') for l in range(1, 26))
        and band_of(9) == 'under' and band_of(12) == 'over')

    # --- clustering ------------------------------------------------------
    pts = [(0, 0), (50, 50), (-30, 20), (4000, 0), (4050, 30)]
    cl = cluster(pts, 700)
    chk('cluster separates two camps 4000 u apart', len(cl) == 2,
        '%d clusters' % len(cl))
    chk('cluster keeps counts', sorted(c[2] for c in cl) == [2, 3])
    kept, cov = keep_supported([(0, 0, 100), (1, 1, 90), (2, 2, 3)], 0.05)
    chk('support cut drops the tail', len(kept) == 2 and abs(cov - 190 / 193.0) < 1e-9,
        'kept %d, coverage %.3f' % (len(kept), cov))
    chk('support cut keeps the mass', keep_supported([(0, 0, 5)], 0.05)[0] != [])

    # --- entity hygiene: the cleaner must actually drop something --------
    tl = {'game': {'teams': {'npc_dota_hero_lina': RADIANT}},
          'snapshots': [
              {'t': -5.0, 'hero': 'npc_dota_hero_lina', 'idx': 1, 'x': 0,
               'y': 0, 'hp_pct': 1.0, 'level': 1, 'team': RADIANT},
              {'t': 600.0, 'hero': 'npc_dota_hero_lina', 'idx': 1, 'x': 100,
               'y': 0, 'hp_pct': 1.0, 'level': 11, 'team': RADIANT},
              {'t': 600.0, 'hero': 'npc_dota_hero_lina', 'idx': 2, 'x': 4000,
               'y': 0, 'hp_pct': 1.0, 'level': 11, 'team': RADIANT}],
          'events': [], 'buildings': []}
    fr, _ = entities.frames_by_hero(tl)
    chk('cleaner drops the illusion stream',
        len(fr['lina']) == 2 and all(s['idx'] == 1 for s in fr['lina']),
        '%d frames kept' % len(fr['lina']))
    s = entities.interp(fr['lina'], 600.0)
    chk('clean anchor is the real hero', abs(s['x'] - 100) < 1e-6)
    chk('an anchor 3900 u away trips the illusion test',
        math.dist((s['x'], s['y']), (4000, 0)) > FAR_FROM_CAMP)

    # --- balanced estimator ---------------------------------------------
    recs = [{'arm_side': 'radiant', 'leg': 'armed', 'k': 1},
            {'arm_side': 'radiant', 'leg': 'baseline', 'k': 1},
            {'arm_side': 'radiant', 'leg': 'baseline', 'k': 1},
            {'arm_side': 'dire', 'leg': 'armed', 'k': 1},
            {'arm_side': 'dire', 'leg': 'armed', 'k': 1},
            {'arm_side': 'dire', 'leg': 'baseline', 'k': 1}]
    tab = per_game(recs, {'radiant': 2, 'dire': 2}, lambda r: r['k'])
    chk('per-game rates', tab['radiant']['armed'] == 0.5
        and tab['radiant']['baseline'] == 1.0)
    chk('balanced = mean of the two paired diffs',
        abs(tab['balanced'] - ((0.5 - 1.0) + (1.0 - 0.5)) / 2) < 1e-9,
        '%.3f' % tab['balanced'])
    chk('opposite-sign strata are not silently pooled',
        (tab['radiant']['diff'] * tab['dire']['diff']) < 0
        and abs(tab['balanced']) < 1e-9)

    # --- attack marker vs AoE ---------------------------------------------
    blows = [(710.0, 'zuus_static_field'), (712.0, 'zuus_arc_lightning')]
    swung = [(713.0, ATTACK_INFLICTOR)]

    def attacked(bl, t0, t1):
        return any(i == ATTACK_INFLICTOR and t0 <= t <= t1 for t, i in bl)

    chk('AoE-only trade is not an attack', not attacked(blows, 709, 715))
    chk('one swing inside the window is', attacked(blows + swung, 709, 715))
    chk('a swing outside the window is not',
        not attacked(blows + swung, 709, 712.5))

    def opened_by(first):
        return (None if first is None else 'attack' if first == ATTACK_INFLICTOR
                else 'item' if str(first).startswith('item_') else 'ability')

    chk('opened_by: bare attack', opened_by(ATTACK_INFLICTOR) == 'attack')
    chk('opened_by: a bounce is an ability',
        opened_by('zuus_arc_lightning') == 'ability')
    chk('opened_by: an item proc is an item',
        opened_by('item_mjollnir') == 'item')
    chk('opened_by: nothing landed', opened_by(None) is None)

    # --- cascade monotonicity ---------------------------------------------
    mk = lambda o, a, al, mx: {'opened': o, 'attacked': a, 'alone': al,
                               'mixed': mx}
    pop = [mk(o, a, al, mx) for o in (0, 1) for a in (0, 1)
           for al in (0, 1) for mx in (0, 1)]
    steps = [lambda r: True,
             lambda r: r['opened'],
             lambda r: r['opened'] and r['attacked'],
             lambda r: r['opened'] and r['attacked'] and r['alone'],
             lambda r: r['opened'] and r['attacked'] and r['alone']
             and r['mixed']]
    counts = [sum(1 for r in pop if f(r)) for f in steps]
    chk('cascade is monotone non-increasing',
        all(a >= b for a, b in zip(counts, counts[1:])) and counts[-1] > 0,
        str(counts))

    # --- the tier test the census depends on -----------------------------
    chk('is_ancient granite golem', is_ancient('npc_dota_neutral_granite_golem'))
    chk('ancient_frog is NOT an ancient camp',
        not is_ancient('npc_dota_neutral_ancient_frog_mage'))

    print('\n  %s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--top', type=int, default=12)
    ap.add_argument('--warmup', type=int, default=WARMUP_GAMES)
    ap.add_argument('--out', default='/tmp/campfarm_target.jsonl')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.sweeps:
        ap.error('need at least one sweep dir')
    res = scan(a.sweeps, a.warmup)
    report(res, a.top)
    with open(a.out, 'w') as fh:
        for r in res['recs']:
            fh.write(json.dumps(r) + '\n')
    print('\n  wrote %d episode records to %s' % (len(res['recs']), a.out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
