#!/usr/bin/env python3
"""Condition (a) for soak candidate `tpreach` -- the TP-interrupt scan's blind band.

WHAT THE LEVER IS (source read 2026-08-25, `bots/FunLib/jmz_func.lua:5878-5901`)
--------------------------------------------------------------------------------
`J.CanEnemyInterruptTpChannel( bot )` answers "would an enemy break a TP channel
started this frame?".  Its candidate list is `J.GetNearbyHeroes( bot, R, ... )`
and each candidate is then tested against TWO clauses:

    if nNow <= nReach                                     -- STRIKE
       or ( ( not bWide or nNow <= 700 ) and nSoon < nNow - 10 )   -- CLOSING

with `nReach = hEnemy:GetAttackRange() + 150`.

  * unarmed  R = 700, both clauses run on the whole list;
  * armed    R = 1200, and the enemies the widening ADDS -- those at
    `700 < nNow <= 1200` -- are held to STRIKE only.

So the domain the candidate ADDS is exactly

    ADDED = { press : no enemy fires the old predicate inside 700,
                      and some enemy sits at 700 < d <= reach(enemy) }

and `reach(enemy) > 700` requires `GetAttackRange() > 550` -- a ranged hero.
Every melee hero has reach 300 and can never be in ADDED.  The candidate is a
pure VETO widening: armed it refuses a strict superset of the frames unarmed
refuses, so its (a) signature is FEWER presses inside ADDED, and no other
change.

CALLER SCOPE, STATED UP FRONT
-----------------------------
The predicate is ungated; each caller carries its own gate.  Its `tpsafe2`
wrapper is called from `ability_item_usage_generic.lua` under
`nMode ~= BOT_MODE_RETREAT`, so a RETREAT TP never consults it.  The dump has
no bot mode.  ADDED is therefore a NECESSARY condition on the presses the
candidate can suppress, never a sufficient one, and a residue of ADDED presses
surviving in the armed leg is EXPECTED (retreat TPs).  Read the leg delta, not
the residue.

WHY THE REACH TABLE IS MEASURED AND NOT RECALLED
------------------------------------------------
`GetAttackRange()` is not in the behavioural dump -- the same shape as
`IsCampBesideLane`'s unobservable input (replay-check 2026-08-25T01:35Z): when
a predicate's input cannot be observed, measure the OUTPUT it leaves behind.
A hero's auto-attacks are in the dump (`DAMAGE` with the plain-attack
inflictor), so the distance at which it lands them bounds its range from the
data itself.  `--ranges` prints that distribution per hero and the table is
built from it (see `reach_table`), with the four heroes the source comment
names -- viper 575, lina 600, drow 625, skywrath 700 -- serving as ground truth
for the estimator.

BIAS DIRECTION OF THE ESTIMATOR, DECLARED
-----------------------------------------
`DAMAGE` is logged at IMPACT, not at launch.  A projectile in flight lets the
target keep running, so impact distance can exceed the attack range; the
dumper's ~1 s sampling adds interpolation error in both directions.  The upper
percentiles are therefore biased HIGH.  A reach estimate that is too high makes
ADDED too big -- it over-counts the domain rather than silently dropping rows,
which is the safe direction for a (a) census (same choice as
`tp_channel_death.DEFAULT_REACH_U`).  `--ranges` prints p50/p75/p90/p95/max so
the inflation is visible instead of assumed.
"""
import argparse
import collections
import contextlib
import io
import shutil
import tempfile
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Reused rather than reimplemented: `tp_channel_death` already carries the
# per-team-t0 fountain construction (and the staggered-entry bug that motivated
# it) and the destination proxy for "which guard owned this press".  A second
# copy of either is how two estimates drift apart -- the lesson `pullcamp_frames`
# paid for on 2026-08-25.
from entities import (canon, frames_by_hero, interp,  # noqa: E402
                      alive_interp, HORN_T, DROPPED_ENTITIES)
from tp_channel_death import fountains, tp_destination  # noqa: E402
import strata  # noqa: E402  -- iron rule 4(i-e)/(i-d), GH #835 / RULING 54

# Seed count the §BC.4 cell was read on the first time (4 seeds, the cell
# alive on 2 of them).  The director's re-entry condition is literally
# "reread this cell with MORE seeds", so the bar is a strict >.
BC4_MIN_SEEDS = 4
# Armed scan radius (`bWide and 1200 or 700`).
WIDE_SCAN_U = 1200.0
# Factory scan radius, and the CLOSING clause's domain in both configurations.
NARROW_SCAN_U = 700.0
# `GetAttackRange() + 150` -- the hull/step buffer the strike clause adds.
REACH_BUFFER_U = 150.0
# `nSoon < nNow - 10` -- the closing clause's own margin.
CLOSING_MARGIN_U = 10.0
# `GetExtrapolatedLocation( 0.5 )`.
EXTRAPOLATE_S = 0.5
# Plain auto-attack inflictor (every named ability/item writes its own).
ATTACK_INFLICTOR = 'dota_unknown'
# A hero needs this many observed auto-attacks before its reach is estimated
# from them; below it the pooled melee/ranged default is used instead.
MIN_ATTACKS = 40
# Percentile of observed impact distance used as the range estimate.  DEFAULT
# p50, not p90: measured against the source-cited base ranges on 35 W9 games,
# p90 overshoots by +198..+376 u (projectile flight) while p50 lands at
# -3..+85.  p90 is still reachable via --reach-mode and IS run, because a
# conclusion that only survives one reach table is a conclusion about the
# table.  See --reach-mode.
RANGE_PCT = 50
# Any hero whose estimated range is at or under this is melee for our purpose:
# reach <= 700 => it can never be in ADDED, so its exact value does not matter.
MELEE_RANGE_U = 400.0
# Percentile used to decide MELEE-vs-RANGED, always, whatever RANGE_PCT is.
#
# WHY THIS IS NOT JUST RANGE_PCT (replay-check 2026-08-30, W28).  `--reach-mode
# p90` on W28 handed a blind band to four MELEE heroes -- chaos_knight 980,
# juggernaut 2821, ember_spirit 2120, dragon_knight 770 -- and 14 of the 45
# ADDED rows it produced were driven by one of them as the band enemy.  The
# source's own rule is that a melee hero can NEVER be in ADDED (`reach > 700`
# needs `GetAttackRange() > 550`), so a third of that domain was impossible by
# construction.
#
# The mechanism is NOT the projectile-flight overshoot the RANGE_PCT comment
# describes, and the existing `ability-not-an-attack` guard cannot see it:
# `ATTACK_INFLICTOR` is `dota_unknown`, i.e. the ABSENCE of a named inflictor,
# so a hero's ILLUSIONS, summons and attack-modifier spells (Phantasm,
# Exorcism, Omnislash, Sleight of Fist) log under the hero's own actor name
# with no inflictor to filter on -- while the distance is measured from the
# REAL hero's interpolated position.  chaos_knight's W28 sample is n=1474,
# 2-3x every other core, p50 195 (its true 150 melee range) and max 14493 --
# a map diagonal.  It is a contaminated TAIL, not a shifted distribution, so
# a robust statistic survives it and a tail percentile does not: on the three
# ground-truth heroes p50 lands at -55..+6 while p90 lands at +94..+260.
#
# So melee-vs-ranged is decided on p50 in every mode, and RANGE_PCT only sizes
# the band of a hero already established to have one.  Direction of the error
# is declared: p50 under-reads witch_doctor by 55u and drops it from the band,
# which SHRINKS ADDED -- the safe direction for a (a) census of a veto, the
# same choice `reach_table` already makes for thin evidence.
MELEE_DECISION_PCT = 50

# Ground truth for the estimator: the four ranges the tpreach source comment
# names, `jmz_func.lua:5860-5863`.  These are ASSERTED against the measured
# table in --selfcheck, not used to build it.
# `GetAttackRange()` is the CURRENT range, so a Dragon Lance / Hurricane Pike
# carrier really does have a wider band than its base range says.  Measured on
# the W9 corpus, only drow_ranger and viper buy one; `--reach-mode source` adds
# it where the hero is seen holding it rather than assuming either way.
RANGE_ITEM_BONUS_U = {'dragon_lance': 140.0, 'hurricane_pike': 140.0}

SOURCE_CITED_RANGE = {
    'viper': 575.0,
    'lina': 600.0,
    'crystal_maiden': 600.0,
    'lion': 600.0,
    'witch_doctor': 600.0,
    'silencer': 600.0,
    'drow_ranger': 625.0,
    'skywrath_mage': 700.0,
}


def pct(vals, p):
    if not vals:
        return None
    s = sorted(vals)
    k = (len(s) - 1) * p / 100.0
    lo = int(math.floor(k))
    hi = int(math.ceil(k))
    if lo == hi:
        return s[lo]
    return s[lo] + (s[hi] - s[lo]) * (k - lo)


# GH #176 -- entity keying, interpolation and the corpse filter moved to
# `entities.py` (issue §5.3: this fix started here and was about to be copied
# into `tp_channel_death.py`; two estimators in this tree already drifted
# apart once by exactly that route).  Imported above, not redefined.


def velocity(frames, t, window=1.5):
    """Finite-difference stand-in for GetExtrapolatedLocation's velocity.

    The engine extrapolates from the unit's CURRENT velocity; the dump has only
    positions at ~1 Hz, so this differentiates over the sample bracketing t.
    Returns (vx, vy) in u/s, or (0,0) when the hero is not sampled around t.
    """
    a = interp(frames, t - window / 2)
    b = interp(frames, t + window / 2)
    if a is None or b is None:
        # fall back to a one-sided difference at the edges of the span
        a = a or interp(frames, t)
        b = b or interp(frames, t)
        if a is None or b is None or a['t'] == b['t']:
            return 0.0, 0.0
    dt = b['t'] - a['t']
    if dt <= 0:
        return 0.0, 0.0
    return (b['x'] - a['x']) / dt, (b['y'] - a['y']) / dt


def measure_ranges(timelines):
    """Per-hero auto-attack impact distances, pooled over the given timelines."""
    dists = collections.defaultdict(list)
    for tl in timelines:
        fr, team = frames_by_hero(tl)
        for e in tl['events']:
            if e['type'] != 'DAMAGE':
                continue
            if e.get('inflictor') != ATTACK_INFLICTOR:
                continue
            if not (e.get('actor_hero') and e.get('target_hero')):
                continue
            a, b = canon(e.get('actor')), canon(e.get('target'))
            if a == b or a not in fr or b not in fr:
                continue
            sa, sb = interp(fr[a], e['t']), interp(fr[b], e['t'])
            if sa is None or sb is None:
                continue
            dists[a].append(math.dist((sa['x'], sa['y']), (sb['x'], sb['y'])))
    return dists


def range_items_held(timelines):
    """hero -> best range-granting item bonus ever observed on it."""
    out = collections.defaultdict(float)
    for tl in timelines:
        for s in tl['snapshots']:
            h = canon(s['hero'])
            for it in s.get('items') or []:
                if it in RANGE_ITEM_BONUS_U:
                    out[h] = max(out[h], RANGE_ITEM_BONUS_U[it])
    return out


def reach_table(dists):
    """hero -> reach (= estimated GetAttackRange() + 150), from measured attacks.

    Heroes with too few observed attacks get MELEE_RANGE_U, i.e. they are
    excluded from ADDED.  That is the conservative direction for a (a) census
    of a VETO widening: a hero wrongly called melee can only make the measured
    ADDED domain smaller, so it cannot manufacture the effect we are looking
    for.  --ranges lists which heroes fell back.
    """
    out = {}
    for h, ds in dists.items():
        if len(ds) < MIN_ATTACKS:
            continue
        # THE MELEE FLOOR (see MELEE_DECISION_PCT).  This is the source's own
        # rule -- a blind band needs GetAttackRange() > 550 -- evaluated on the
        # robust statistic instead of the contaminated one.  Under `p50` it is
        # a no-op by construction; under `p90` it is what keeps a melee hero's
        # illusion tail from manufacturing a band it cannot have.
        if pct(ds, MELEE_DECISION_PCT) + REACH_BUFFER_U <= NARROW_SCAN_U:
            continue
        out[h] = pct(ds, RANGE_PCT) + REACH_BUFFER_U
    return out


def reach_diagnostics(dists, reach):
    """(floored, degenerate) -- the two ways this table can mislead its reader.

    `floored`   heroes the melee floor removed, with the band the raw
                percentile would have handed them.  Printed so a shrunken
                domain is visibly shrunken and not silently smaller.
    `degenerate` heroes whose reach is at or past WIDE_SCAN_U.  The band test
                is `d <= min(reach, WIDE_SCAN_U)`, so at that point it stops
                testing reach at all and ADDED degenerates into "any enemy in
                (700, 1200]".  On W28 `p90` put five heroes here.
    """
    floored, degenerate = [], []
    for h, ds in sorted(dists.items()):
        if len(ds) < MIN_ATTACKS:
            continue
        raw = pct(ds, RANGE_PCT) + REACH_BUFFER_U
        if h not in reach:
            if raw > NARROW_SCAN_U:
                floored.append((h, raw, pct(ds, MELEE_DECISION_PCT)))
        elif reach[h] >= WIDE_SCAN_U:
            degenerate.append((h, reach[h]))
    return floored, degenerate


def evaluate(fr, team, h, t, reach, default_reach):
    """The two predicates at one instant, for hero h.

    Returns (old_pred, new_band, nearest_enemy_distance, witness).  `new_band`
    is the raw band test -- it is NOT and-ed with `not old_pred` here, because
    the caller needs both halves separately (the ADDED domain is the
    conjunction, but the lookback witness below needs the band alone).
    """
    s0 = alive_interp(fr[h], t)
    if s0 is None:
        return False, False, None, None
    old_hit = new_hit = False
    near = None
    new_who = None
    for h2 in fr:
        if h2 == h or team.get(h2) == team.get(h):
            continue
        s2 = alive_interp(fr[h2], t)
        if s2 is None:
            continue
        d = math.dist((s0['x'], s0['y']), (s2['x'], s2['y']))
        if near is None or d < near:
            near = d
        r = reach.get(h2, default_reach)
        if d <= NARROW_SCAN_U:
            vx, vy = velocity(fr[h2], t)
            soon = math.dist((s0['x'], s0['y']),
                             (s2['x'] + vx * EXTRAPOLATE_S,
                              s2['y'] + vy * EXTRAPOLATE_S))
            if d <= r or soon < d - CLOSING_MARGIN_U:
                old_hit = True
        elif d <= min(r, WIDE_SCAN_U):
            new_hit = True
            if new_who is None:
                new_who = (h2, d, r)
    return old_hit, new_hit, near, new_who


def presses(timeline, reach, default_reach):
    """Every TP press in one game, classified by which predicate covers it."""
    fr, team = frames_by_hero(timeline)
    fount = fountains(timeline['snapshots'])
    deaths = collections.defaultdict(list)
    for e in timeline['events']:
        if e['type'] == 'DEATH' and e.get('target_hero'):
            deaths[canon(e['target'])].append(e['t'])
    out = []
    for e in timeline['events']:
        if not (e['type'] == 'MODIFIER_ADD'
                and e.get('inflictor') == 'modifier_teleporting'
                and canon(e.get('target')) == canon(e.get('actor'))):
            continue
        h = canon(e['actor'])
        if h not in fr:
            continue
        s0 = interp(fr[h], e['t'])
        if s0 is None:
            continue
        old_hit, new_hit, near, new_who = evaluate(
            fr, team, h, e['t'], reach, default_reach)
        # THE POSITIVE WITNESS.  A veto does not leave a record of the press it
        # prevented -- the only thing it can leave is a press that happens
        # LATER than it otherwise would.  So ask the same predicate at t-1/-2/-3:
        # a press whose added-domain was true a second ago and false now is a
        # press that waited for the band to clear.  Armed, that shape should be
        # commoner than in the baseline leg; it is the one signature of this
        # candidate that is a positive observation rather than an absence.
        waited = 0
        if not new_hit:
            for k in (1.0, 2.0, 3.0):
                o2, n2, _, _ = evaluate(fr, team, h, e['t'] - k,
                                        reach, default_reach)
                if n2 and not o2:
                    waited = k
                    break
        died = [dt for dt in deaths.get(h, []) if e['t'] <= dt <= e['t'] + 5.0]
        out.append(dict(
            game=timeline.get('game'), hero=h, t=round(e['t'], 1),
            dest=tp_destination(fr[h], fount.get(team.get(h)), e['t'],
                                bool(died)),
            hp=round(s0['hp_pct'], 3), level=s0['level'],
            near=round(near) if near is not None else None,
            old_pred=old_hit,
            added=(not old_hit) and new_hit,
            waited_s=waited,
            added_enemy=new_who[0] if new_who else None,
            added_d=round(new_who[1]) if new_who else None,
            added_reach=round(new_who[2]) if new_who else None,
        ))
    return out


def load_run(d):
    """Yield (timeline, manifest_row) for every swept game under one sweep dir."""
    man = {}
    mf = os.path.join(d, 'games_manifest.jsonl')
    if os.path.exists(mf):
        for line in open(mf):
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            man[r.get('game')] = r
    for p in sorted(glob.glob(os.path.join(d, 'timelines', '*.timeline.json'))):
        g = os.path.basename(p).replace('.timeline.json', '')
        if g not in man:
            continue          # warmup / unstamped -- sweep_run.sh already judged
        try:
            tl = json.load(open(p))
        except (ValueError, OSError):
            continue
        tl['game'] = g
        yield tl, man[g]


def leg_of(row, hero_team):
    """Which leg this hero played on: 'armed' if its team is the candidate side.

    `side` in the manifest is the physical side (radiant/dire) the CANDIDATE
    build was on.  team 2 = radiant, 3 = dire in the dump.
    """
    side = row.get('side')
    if side not in ('radiant', 'dire'):
        return None
    cand_team = 2 if side == 'radiant' else 3
    return 'armed' if hero_team == cand_team else 'baseline'


# ------------------------------------------------------------------ by-seed
# The three ADDED observables the BC.4 reread is about.  `press` is the
# denominator the other two live inside; `ADDED:field` IS the BC.4 cell.
#
# `ADDED:home` is deliberately NOT here.  Iron rule BC.1 (GH #3 paid -15 GPM
# for it) says the retreat cell carries no threshold and is reported as raw
# counts only -- a retreat TP never consults this predicate at all, so an arm
# estimate on it would be an estimate of a leg delta the lever cannot produce.
# It is printed below the table, as counts, for exactly that reason.
BY_SEED_QUANTITIES = (
    ('press/g', lambda r: True),
    ('ADDED/g', lambda r: r['added']),
    ('ADDED:field/g  [BC.4 cell]', lambda r: r['added'] and r['dest'] == 'field'),
)


def by_seed(detail, ngames_seed):
    """Per-seed swap-average, printed by the tool and never by hand.

    WHY THIS EXISTS (owed row `tpreach_bc4_cell_reread`, director
    2026-09-08T10:1xZ; upstream `a_evidence_tpreach.md` §8's self-registered
    debt).  Condition (a) for `tpreach` was judged WORKING, but the §BC.4
    non-retreat cell -- `ADDED:field` -- was carried at n=3 armed vs 13
    baseline, on 2 of 4 seeds, and only on the p50 reach table.  The director
    did not waive it; it was moved to a re-entry veto, and the veto's stated
    precondition is that THIS TOOL print the per-seed swap-average itself.

    The previous reading was hand-computed from `--out` rows.jsonl.  That is
    the exact shape iron rule 4(i-d) names: pooling across seeds weighted by
    games leaks the roster term back in as
    `arm + roster * (N_ab - N_ba)/(N_ab + N_ba)`, the 0.335 coefficient that
    read a +26.60 as +9.20 and looked like an ordinary number.  Delegating to
    `strata.py` (the sole implementation, RULING 57) makes the arithmetic mean
    structural rather than remembered.

    The per-side table above stays, unchanged: 4(i-a) wants BOTH layer
    readings registered whatever the estimator does with them.  What changes is
    which of the two is the READING -- the arm is, and by 4(i-c) an opposed
    stratum pair is no longer a veto on it.
    """
    paired, pseeds, unpaired = strata.pairing(detail, ngames_seed)
    print('\nper-seed swap-average (4(i-d): per-seed FIRST, then an arithmetic '
          'mean across seeds -- never weighted by games):')
    print('  corpus %s -- seeds paired %s%s'
          % ('PAIRED (opposed layers read as arm+roster, 4(i-e))' if paired
             else 'NOT PAIRED (opposed layers stay NOISE, 4(i-b))',
             ', '.join(str(s) for s in pseeds) or 'none',
             ('; UNPAIRED ' + ', '.join(str(s) for s in unpaired))
             if unpaired else ''))
    if not paired:
        # No estimator is handed back, on purpose: a number formed from seeds
        # that have no partner is not a swap-average, and printing one anyway
        # is the failure `strata.py` was written against.
        print('  no arm estimator: a seed without both arm sides has no roster '
              'term to cancel against.  Read the per-side table under 4(i-b).')
        return None

    ests = {}
    print('  %-7s %-30s %10s %10s %10s' % ('seed', 'quantity', 'ab', 'ba', 'arm'))
    for name, pred in BY_SEED_QUANTITIES:
        est = strata.per_seed_arm(detail, ngames_seed, pred)
        ests[name] = est
        if est is None:
            continue
        for p in est['per_seed']:
            print('  %-7s %-30s %+10.4f %+10.4f %+10.4f'
                  % (p['seed'], name, p['d_ab'], p['d_ba'], p['arm']))

    # The composition signal §BC.4's note asks about: of the ADDED presses the
    # candidate CAN refuse, what share are non-retreat?  Its denominator is
    # episodes, not games, so it needs the share estimator -- forming it from
    # `per_seed_arm` would quote a per-game arm as if it were a share arm.
    comp = strata.per_seed_share_arm(
        detail, ngames_seed,
        lambda r: r['added'] and r['dest'] == 'field',
        lambda r: r['added'])
    ests['ADDED:field share of ADDED'] = comp
    if comp is None:
        # MANDATORY, printed even when empty -- the same rule the melee-floor
        # header above states.  With no line here, a reader seeing no share row
        # cannot tell "the composition signal was flat" from "no seed had an
        # ADDED press in both strata, so there was nothing to difference", and
        # the second is what an empty BC.4 cell looks like.
        print('  ADDED:field/ADDED [share]: NOT FORMABLE -- no seed carried an '
              'ADDED press in both strata on both legs.  This is an absent '
              'denominator, not a flat share.')
    else:
        for p in comp['per_seed']:
            print('  %-7s %-30s %+10.4f %+10.4f %+10.4f'
                  % (p['seed'], 'ADDED:field/ADDED [share]',
                     p['d_ab'], p['d_ba'], p['arm']))
        if comp['skipped']:
            print('  (share skipped on seed(s) %s: an empty ADDED denominator '
                  'in one stratum is absent, not 0.0)'
                  % ', '.join(str(s) for s in comp['skipped']))

    print('\n  %-30s %10s %8s %10s   %s'
          % ('quantity', 'mean arm', 'seeds', 'spread', 'note'))
    for name in [n for n, _ in BY_SEED_QUANTITIES] + \
                ['ADDED:field share of ADDED']:
        est = ests.get(name)
        if est is None:
            continue
        # The note is formed on the MEAN pair, not on any one seed's, because
        # the mean arm is what a verdict would quote.
        mean_ab = sum(p['d_ab'] for p in est['per_seed']) / est['n_seeds']
        mean_ba = sum(p['d_ba'] for p in est['per_seed']) / est['n_seeds']
        print('  %-30s %+10.4f %4d/%-3d %10s   %s'
              % (name, est['arm'], est['seeds_better'], est['n_seeds'],
                 ('%.4f' % est['spread']) if est['spread'] is not None
                 else 'n/a(1 seed)',
                 strata.note_for(strata.pair_arm(mean_ab, mean_ba), True)))

    n_seeds = ests[BY_SEED_QUANTITIES[0][0]]['n_seeds']
    # Printed by the tool so a later reader cannot satisfy the veto by not
    # looking: the director's condition is "more seeds than last time", and
    # last time was 4 with the cell alive on 2 of them.
    print('\n  BC.4 re-entry bar: seeds = %d, required > %d -- %s'
          % (n_seeds, BC4_MIN_SEEDS,
             'MET' if n_seeds > BC4_MIN_SEEDS else 'NOT MET'))

    # BC.1: the retreat cell, counts only, no threshold, no estimator.
    home = collections.Counter()
    for r in detail:
        if r['added'] and r['dest'] in ('home', 'from_home'):
            home[(r['arm_side'], r['leg'])] += 1
    print('  BC.1 retreat cell (counts only, no threshold -- a RETREAT TP '
          'never consults this predicate): %s'
          % ('  '.join('%s/%s %d' % (s, l, home[(s, l)])
                       for s in ('radiant', 'dire')
                       for l in ('armed', 'baseline')) or 'none'))
    return ests


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*', help='sweep_run.sh output dirs')
    ap.add_argument('--label', default='', help='wave name for the table header')
    ap.add_argument('--ranges', action='store_true',
                    help='print the measured per-hero attack-range table only')
    ap.add_argument('--reach-mode', default='p50',
                    choices=('p50', 'p90', 'source'),
                    help='which reach table to classify ADDED with: a measured '
                         'percentile of auto-attack impact distance, or the '
                         'base ranges the source comment names plus any '
                         'range item the hero is seen holding')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--out', default='')
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()

    timelines = []
    rows_meta = []
    for d in args.sweeps:
        for tl, man in load_run(d):
            timelines.append(tl)
            rows_meta.append(man)
    if not timelines:
        print('no swept games found under: %s' % ' '.join(args.sweeps))
        return 1

    dists = measure_ranges(timelines)
    if args.reach_mode == 'source':
        held = range_items_held(timelines)
        reach = {h: SOURCE_CITED_RANGE[h] + held.get(h, 0.0) + REACH_BUFFER_U
                 for h in SOURCE_CITED_RANGE}
    else:
        global RANGE_PCT
        RANGE_PCT = 50 if args.reach_mode == 'p50' else 90
        reach = reach_table(dists)

    if args.ranges:
        print('measured auto-attack impact distance, %d games' % len(timelines))
        print('%-24s %6s %6s %6s %6s %6s %6s   %s'
              % ('hero', 'n', 'p50', 'p75', 'p90', 'p95', 'max', 'reach=p90+150'))
        for h in sorted(dists, key=lambda k: -(pct(dists[k], RANGE_PCT) or 0)):
            ds = dists[h]
            print('%-24s %6d %6.0f %6.0f %6.0f %6.0f %6.0f   %s'
                  % (h, len(ds), pct(ds, 50), pct(ds, 75), pct(ds, RANGE_PCT),
                     pct(ds, 95), max(ds),
                     '%6.0f' % reach[h] if h in reach
                     else ('FALLBACK (n<%d)' % MIN_ATTACKS
                           if len(ds) < MIN_ATTACKS
                           else 'MELEE FLOOR (p%d %.0f)'
                                % (MELEE_DECISION_PCT,
                                   pct(ds, MELEE_DECISION_PCT)))))
        cited = [(h, SOURCE_CITED_RANGE[h], pct(dists[h], RANGE_PCT))
                 for h in SOURCE_CITED_RANGE if h in dists and len(dists[h]) >= MIN_ATTACKS]
        if cited:
            print('\nground truth (ranges the tpreach source comment names):')
            for h, want, got in sorted(cited):
                print('  %-20s source %4.0f   measured p%d %6.0f   err %+.0f'
                      % (h, want, RANGE_PCT, got, got - want))
        return 0

    default_reach = MELEE_RANGE_U + REACH_BUFFER_U
    agg = collections.defaultdict(lambda: collections.Counter())
    # (seed, arm_side) -> games.  One game feeds BOTH legs (the two legs
    # are the two teams inside it), so this is not per-leg.
    ngames_seed = collections.Counter()
    detail = []
    for tl, man in zip(timelines, rows_meta):
        _, team = frames_by_hero(tl)
        side = man.get('side')
        for p in presses(tl, reach, default_reach):
            leg = leg_of(man, team.get(p['hero']))
            if leg is None:
                continue
            p['leg'], p['side'], p['seed'] = leg, side, man.get('seed')
            # `strata.py` names this field `arm_side`; `side` is kept
            # under its old name so the `--out` rows.jsonl a previous
            # reading was hand-computed from still parses.
            p['arm_side'] = side
            detail.append(p)
            k = (side, leg)
            agg[k]['press'] += 1
            agg[k]['added'] += 1 if p['added'] else 0
            agg[k]['old'] += 1 if p['old_pred'] else 0
            if p['added']:
                # Only a press that is NOT retreat-shaped is inside the
                # candidate's reachable scope at all: the retreat branch never
                # consults this predicate (see the CALLER SCOPE note).  A
                # `home`/`from_home`/`died` ADDED press is a press tpreach was
                # never able to refuse, and counting it as a miss would be
                # reading a leg delta the lever cannot produce.
                agg[k]['added_field'] += 1 if p['dest'] == 'field' else 0
                agg[k]['added_home'] += 1 if p['dest'] in ('home', 'from_home') else 0
            if p['waited_s']:
                agg[k]['waited'] += 1
                if p['dest'] == 'field':
                    agg[k]['waited_field'] += 1
        for leg in ('armed', 'baseline'):
            agg[(side, leg)]['games'] += 1
        ngames_seed[(man.get('seed'), side)] += 1

    banded = sorted(h for h, r in reach.items() if r > NARROW_SCAN_U)
    print('== %s -- %d games, reach-mode %s =='
          % (args.label or 'sweep', len(timelines), args.reach_mode))
    print('heroes with a blind band (reach > %d): %s'
          % (NARROW_SCAN_U, ', '.join('%s %.0f' % (h, reach[h]) for h in banded)
             or 'NONE -- ADDED is empty by construction'))
    # Both lines below are MANDATORY, printed even when empty.  An ADDED count
    # is only readable next to the table that produced it: W28's `p90` run had
    # 14 of 45 ADDED rows carrying a melee band enemy, and nothing in the
    # output said so.  A reader who sees no such line must be able to conclude
    # the tool did not check, never that the table was clean.
    if args.reach_mode == 'source':
        print('melee floor: n/a (source-cited table, not measured)')
        print('reach >= wide scan %d: n/a (source-cited table)' % WIDE_SCAN_U)
    else:
        floored, degenerate = reach_diagnostics(dists, reach)
        print('melee floor removed (p%d says melee, p%d would have banded): %s'
              % (MELEE_DECISION_PCT, RANGE_PCT,
                 ', '.join('%s p%d %.0f vs raw reach %.0f'
                           % (h, MELEE_DECISION_PCT, p50, raw)
                           for h, raw, p50 in floored) or 'none'))
        print('reach >= wide scan %d (band test stops testing reach): %s'
              % (WIDE_SCAN_U,
                 ', '.join('%s %.0f' % (h, r) for h, r in degenerate)
                 or 'none'))
    print('%-8s %-9s %6s %8s %8s %8s %8s %10s %10s'
          % ('side', 'leg', 'games', 'press', 'ADDED', 'A:field', 'A:home',
             'press/g', 'A:field/g'))
    # `waited` = presses whose added-domain was true 1-3 s earlier and is false
    # now -- see the POSITIVE WITNESS note in presses().
    for side in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            c = agg.get((side, leg))
            if not c or not c['games']:
                continue
            print('%-8s %-9s %6d %8d %8d %8d %8d %10.3f %10.3f'
                  % (side, leg, c['games'], c['press'], c['added'],
                     c['added_field'], c['added_home'],
                     c['press'] / c['games'], c['added_field'] / c['games']))
    print('\n(#148(i): the two physical sides are separate strata -- a sign '
          'split between them is noise and does not go in a conclusion.)')

    for side in ('radiant', 'dire'):
        a, b = agg.get((side, 'armed')), agg.get((side, 'baseline'))
        if not (a and b and a['games'] and b['games']):
            continue
        print('%-8s  ADDED/g %+.3f   ADDED:field/g %+.4f   press/g %+.3f   '
              'waited/g %+.4f (%d vs %d)'
              % (side, a['added'] / a['games'] - b['added'] / b['games'],
                 a['added_field'] / a['games'] - b['added_field'] / b['games'],
                 a['press'] / a['games'] - b['press'] / b['games'],
                 a['waited'] / a['games'] - b['waited'] / b['games'],
                 a['waited'], b['waited']))

    # Printed unconditionally, not behind a flag.  The debt this pays off is
    # "the last reading was hand-computed"; a flag would leave the forgetting
    # path open, and forgetting is what happened.
    by_seed(detail, ngames_seed)

    if args.out:
        with open(args.out, 'w') as fh:
            for p in detail:
                fh.write(json.dumps(p) + '\n')
        print('\nwrote %d presses -> %s' % (len(detail), args.out))
    return 0


def selfcheck():
    global RANGE_PCT           # the melee-floor battery below flips it to p90
    fails = []
    ran = []

    def chk(name, cond, detail=''):
        ran.append(name)
        if not cond:
            fails.append('%s %s' % (name, detail))
        print('%-4s %s %s' % ('PASS' if cond else 'FAIL', name, detail))

    def snaps(hero, team, pts, level=6, idx=None):
        if idx is None:
            idx = abs(hash(hero)) % 900 + 1
        return [dict(t=t, hero='npc_dota_hero_' + hero, team=team, x=x, y=y,
                     idx=idx, hp=500, hp_pct=1.0, mp_pct=1.0, level=level,
                     items=[], abilities=[]) for t, x, y in pts]

    def tl(bot_pts, enemy_pts, enemy='lina', t_press=10.0, extra_events=()):
        sn = snaps('sven', 2, bot_pts) + snaps(enemy, 3, enemy_pts)
        ev = [dict(t=t_press, type='MODIFIER_ADD',
                   actor='npc_dota_hero_sven', target='npc_dota_hero_sven',
                   inflictor='modifier_teleporting',
                   actor_hero=True, target_hero=True)]
        ev.extend(extra_events)
        return dict(snapshots=sn, events=ev, game='synthetic')

    # every fixture hero needs a pre-horn frame or frames_by_hero drops it as
    # an illusion -- which is itself asserted below
    still = lambda x, y: [(-5.0, x, y)] + [(t, x, y) for t in (8.0, 9.0, 10.0, 11.0, 12.0)]
    bot = still(0, 0)
    R = {'lina': 750.0}                      # 600 + 150, the source-cited value
    DEF = MELEE_RANGE_U + REACH_BUFFER_U

    # --- the whole point of the candidate: the blind band [700, reach] --------
    p = presses(tl(bot, still(720, 0)), R, DEF)[0]
    chk('band-added', p['added'] and not p['old_pred'],
        'lina standing 720u away (reach 750) -> ADDED, old predicate blind')
    chk('band-names-witness', p['added_enemy'] == 'lina' and p['added_d'] == 720)

    # inside the old scan: the factory predicate already covers it, so the
    # widening changes nothing -- ADDED must be False, not "also true".
    p = presses(tl(bot, still(650, 0)), R, DEF)[0]
    chk('inside-700-not-added', p['old_pred'] and not p['added'],
        'lina at 650u is the OLD predicate, not the new domain')

    # past the enemy's own reach: armed scans out to 1200 but the strike clause
    # still fails, so the widening must NOT fire.  This is the clause that
    # separates tpreach from "veto on anything within 1200".
    p = presses(tl(bot, still(900, 0)), R, DEF)[0]
    chk('past-reach-not-added', not p['added'] and not p['old_pred'],
        'lina at 900u > reach 750 -> neither predicate')

    # a MELEE enemy can never be in ADDED at any distance past 700
    p = presses(tl(bot, still(720, 0), enemy='axe'), R, DEF)[0]
    chk('melee-never-added', not p['added'],
        'axe reach 300 at 720u -> the band does not exist for melee')

    # --- the asymmetry that is "the whole point of the narrowing" ------------
    # An enemy CLOSING from beyond 700 must not fire: armed holds the added
    # enemies to STRIKE only.  If someone widens the closing clause to 1200,
    # this is the assertion that goes red.
    closing = [(-5.0, 1100, 0), (8.0, 1100, 0), (9.0, 1000, 0), (10.0, 900, 0),
               (11.0, 800, 0), (12.0, 700, 0)]
    p = presses(tl(bot, closing), R, DEF)[0]
    chk('closing-stays-at-700', not p['added'],
        'lina sprinting in from 900u -> closing clause does not reach it')

    # ...while a closing enemy INSIDE 700 still fires the old predicate, even
    # when it is outside its own reach right now.
    closing_in = [(-5.0, 900, 0), (8.0, 900, 0), (9.0, 800, 0), (10.0, 690, 0),
                  (11.0, 560, 0), (12.0, 430, 0)]
    p = presses(tl(bot, closing_in, enemy='axe'), R, DEF)[0]
    chk('closing-inside-700-fires', p['old_pred'],
        'melee axe closing through 690u -> old CLOSING clause, reach irrelevant')

    # a stationary enemy just outside its reach but inside 700 falls through
    p = presses(tl(bot, still(690, 0), enemy='axe'), R, DEF)[0]
    chk('stationary-out-of-reach-falls-through', not p['old_pred'] and not p['added'],
        'axe parked at 690u, not closing -> let the TP go')

    # the trap this fixture itself fell into first: naming the enemy the same
    # hero as the bot makes the `h2 == h` self-skip eat the whole case, and
    # every assertion above would pass for the wrong reason.
    same = tl(bot, still(720, 0), enemy='sven')
    chk('selfskip-trap', not presses(same, R, DEF)[0]['added'],
        'bot and enemy both npc_dota_hero_sven -> the enemy is skipped; any '
        'melee/closing case written this way is vacuous')

    # --- a hero who died just BEFORE the press is not a band enemy ----------
    dying = snaps('lina', 3, [(-5.0, 720, 0), (8.0, 720, 0), (9.0, 720, 0)],
                  idx=91)
    dying += [dict(t=t, hero='npc_dota_hero_lina', team=3, x=720, y=0, hp=0,
                   idx=91, hp_pct=0.0, mp_pct=0.0, level=6, items=[],
                   abilities=[]) for t in (11.0, 12.0)]
    g2 = tl(bot, still(9999, 9999))
    g2['snapshots'] = snaps('sven', 2, bot) + dying
    chk('death-bracket-not-a-band-enemy', not presses(g2, R, DEF)[0]['added'],
        'lina alive at t=9, dead at t=11; the press at t=10 must not see her')
    chk('death-bracket-alive-before', alive_interp(dying, 8.5) is not None,
        'the same track IS readable while both brackets are alive')

    # --- dead enemies do not guard anything ---------------------------------
    dead = [dict(t=t, hero='npc_dota_hero_lina', team=3, x=720, y=0, hp=0,
                 idx=77, hp_pct=0.0, mp_pct=0.0, level=6, items=[],
                 abilities=[])
            for t in (-5.0, 8.0, 9.0, 10.0, 11.0, 12.0)]
    g = tl(bot, still(9999, 9999))
    g['snapshots'] = snaps('sven', 2, bot) + dead
    chk('dead-enemy-ignored', not presses(g, R, DEF)[0]['added'],
        'a corpse at 720u cannot break a channel')

    # --- the reach estimator, on synthetic attacks ---------------------------
    atk_bot = [(float(t), 0, 0) for t in range(0, 120)]
    atk_en = [(float(t), 600, 0) for t in range(0, 120)]
    sn = snaps('lina', 3, atk_en) + snaps('sven', 2, atk_bot)
    ev = [dict(t=float(t) + 0.5, type='DAMAGE', actor='npc_dota_hero_lina',
               target='npc_dota_hero_sven', inflictor=ATTACK_INFLICTOR,
               actor_hero=True, target_hero=True, value=50)
          for t in range(0, 100)]
    d = measure_ranges([dict(snapshots=sn, events=ev, game='r')])
    chk('range-measured', abs(pct(d['lina'], RANGE_PCT) - 600) < 1,
        'measured p%d = %.0f for a hero attacking from exactly 600u'
        % (RANGE_PCT, pct(d['lina'], RANGE_PCT)))
    chk('range-to-reach', abs(reach_table(d)['lina'] - 750) < 1,
        'reach = measured range + %d' % REACH_BUFFER_U)

    # an ABILITY hit must not be counted as an auto-attack: a 1200u nuke would
    # inflate lina's measured range past her real one and manufacture ADDED.
    ev_ab = [dict(t=float(t) + 0.5, type='DAMAGE', actor='npc_dota_hero_lina',
                  target='npc_dota_hero_sven', inflictor='lina_dragon_slave',
                  actor_hero=True, target_hero=True, value=200)
             for t in range(0, 100)]
    sn2 = snaps('lina', 3, [(float(t), 1150, 0) for t in range(0, 120)]) \
        + snaps('sven', 2, atk_bot)
    d2 = measure_ranges([dict(snapshots=sn2, events=ev_ab, game='r')])
    chk('ability-not-an-attack', 'lina' not in d2,
        'a named inflictor is not GetAttackRange() evidence')

    # under MIN_ATTACKS the hero falls back to melee, i.e. OUT of ADDED --
    # the conservative direction, asserted rather than assumed.
    d3 = {'lina': [600.0] * (MIN_ATTACKS - 1)}
    chk('thin-evidence-falls-back', 'lina' not in reach_table(d3),
        'n=%d < %d -> no reach claim' % (MIN_ATTACKS - 1, MIN_ATTACKS))
    p = presses(tl(bot, still(720, 0)), reach_table(d3), DEF)[0]
    chk('fallback-shrinks-added', not p['added'],
        'a hero with no reach evidence cannot ENTER the added domain')

    # --- the melee floor (W28: 14 of 45 p90 ADDED rows were melee) -----------
    # A melee hero whose sample carries an illusion/summon tail.  80% of the
    # attacks land at 200u (its real range), 20% across the map -- the shape
    # of chaos_knight's W28 sample (p50 195, p90 830, max 14493), in miniature.
    # p90 alone calls that a 3150u reach and hands a 150-range hero a blind
    # band; the floor reads p50 and refuses.
    saved_pct = RANGE_PCT
    try:
        tail = {'chaos_knight': [200.0] * 80 + [3000.0] * 20}
        RANGE_PCT = 90
        chk('melee-floor-blocks-a-contaminated-tail',
            'chaos_knight' not in reach_table(tail),
            'p90 %.0f would band it; p%d %.0f says melee'
            % (pct(tail['chaos_knight'], 90), MELEE_DECISION_PCT,
               pct(tail['chaos_knight'], MELEE_DECISION_PCT)))
        p = presses(tl(bot, still(720, 0)), reach_table(tail), DEF)[0]
        chk('melee-floor-keeps-it-out-of-added', not p['added'],
            'a floored hero cannot be the band enemy of an ADDED press')

        # ...and the floor must not eat a genuinely ranged hero just because
        # its tail is long.  Same tail, real range 600 -> band survives.
        ranged = {'lina': [600.0] * 80 + [3000.0] * 20}
        chk('melee-floor-spares-a-ranged-hero',
            reach_table(ranged).get('lina') == pct(ranged['lina'], 90) + REACH_BUFFER_U,
            'p%d %.0f > melee -> the band is still sized by p%d'
            % (MELEE_DECISION_PCT, pct(ranged['lina'], MELEE_DECISION_PCT), 90))

        # the floor IS the source rule, so it must cut where the source cuts:
        # a blind band needs GetAttackRange() > 550, i.e. reach > 700.
        chk('melee-floor-cuts-where-the-source-cuts',
            'x' not in reach_table({'x': [550.0] * MIN_ATTACKS})
            and 'x' in reach_table({'x': [551.0] * MIN_ATTACKS}),
            'range 550 -> reach 700, not > 700; 551 -> 701, banded')

        # the diagnostics the header is required to print
        d_raw = {'chaos_knight': [200.0] * 80 + [3000.0] * 20,
                 'sniper': [1200.0] * MIN_ATTACKS}
        r_raw = reach_table(d_raw)
        floored, degenerate = reach_diagnostics(d_raw, r_raw)
        chk('diagnostics-name-the-floored-hero',
            [h for h, _, _ in floored] == ['chaos_knight'])
        chk('diagnostics-name-the-degenerate-band',
            [h for h, _ in degenerate] == ['sniper'],
            'reach %.0f >= wide scan %.0f -> the band test stops testing reach'
            % (r_raw['sniper'], WIDE_SCAN_U))
    finally:
        RANGE_PCT = saved_pct

    # under p50 -- the default -- the floor is a no-op by construction, and
    # that has to stay true or the default reading changes silently.
    chk('melee-floor-is-a-noop-at-p50',
        reach_table({'lina': [600.0] * MIN_ATTACKS}).get('lina') == 750.0,
        'p50 mode: the deciding and the sizing statistic are the same one')

    # --- the delayed-press witness ------------------------------------------
    # enemy sits in the band until t-1, then leaves; the press lands at t=10.
    leaving = [(-5.0, 720, 0), (6.0, 720, 0), (7.0, 720, 0), (8.0, 720, 0),
               (9.0, 780, 0), (10.0, 1000, 0), (11.0, 1400, 0), (12.0, 1800, 0)]
    bot7 = [(-5.0, 0, 0)] + [(float(t), 0, 0) for t in range(6, 13)]
    p = presses(tl(bot7, leaving), R, DEF)[0]
    chk('waited-witness', p['waited_s'] and not p['added'],
        'band cleared %.0fs before the press -> the press WAITED' % (p['waited_s'] or 0))

    # ...and a press with no band anywhere near it must NOT be called a wait,
    # or every fountain TP in the corpus becomes evidence for the candidate.
    p = presses(tl(bot7, [(-5.0, 5000, 5000)]
                  + [(float(t), 5000, 5000) for t in range(6, 13)]), R, DEF)[0]
    chk('waited-needs-a-band', not p['waited_s'],
        'enemy 7000u away for the whole window -> not a wait')

    # a press that IS in the added domain is not also a wait (it did not wait)
    p = presses(tl(bot7, [(-5.0, 720, 0)]
                  + [(float(t), 720, 0) for t in range(6, 13)]), R, DEF)[0]
    chk('added-is-not-waited', p['added'] and not p['waited_s'],
        'still in the band at the press instant -> ADDED, never waited')

    # --- leg mapping (team 2 = radiant) --------------------------------------
    chk('leg-radiant-armed', leg_of(dict(side='radiant'), 2) == 'armed')
    chk('leg-radiant-baseline', leg_of(dict(side='radiant'), 3) == 'baseline')
    chk('leg-dire-armed', leg_of(dict(side='dire'), 3) == 'armed')
    chk('leg-dire-baseline', leg_of(dict(side='dire'), 2) == 'baseline')
    chk('leg-unstamped-dropped', leg_of(dict(side=None), 2) is None,
        'no stamp -> no leg, never a default')

    # --- interp must not clamp ----------------------------------------------
    f = snaps('lina', 3, [(t, 100, 0) for t in (8.0, 9.0, 10.0, 11.0, 12.0)])
    chk('interp-before-span', interp(f, 0.0) is None)
    chk('interp-after-span', interp(f, 99.0) is None)
    chk('interp-mid', abs(interp(f, 9.5)['x'] - 100) < 1e-6)

    # --- THE ILLUSION TRAP (this file's first cut got this wrong) ------------
    # An illusion standing right where a band enemy would be must NOT make the
    # press ADDED: it spawns after the horn, and the engine predicate skips
    # J.IsSuspiciousIllusion before it ever measures reach.
    ill = tl(bot, still(9999, 9999))
    ill['snapshots'] = ill['snapshots'] + snaps(
        'lina', 3, [(t, 720, 0) for t in (8.0, 9.0, 10.0, 11.0, 12.0)], idx=4242)
    chk('illusion-not-a-band-enemy', not presses(ill, R, DEF)[0]['added'],
        'a post-horn lina entity 720u away is an illusion, not a guard')

    # ...and the real hero of the same NAME must survive alongside it, keyed by
    # entity: if the illusion evicted her, the corpus would lose real enemies.
    both = tl(bot, still(650, 0))
    both['snapshots'] = both['snapshots'] + snaps(
        'lina', 3, [(t, 9000, 9000) for t in (8.0, 9.0, 10.0, 11.0, 12.0)],
        idx=4242)
    chk('real-hero-survives-her-illusion', presses(both, R, DEF)[0]['old_pred'],
        'the pre-horn lina at 650u still fires the old predicate')

    # the interleaving that produced the phantom: two streams under one name
    # must not be concatenated into one track
    fr_, _ = frames_by_hero(ill)
    chk('one-track-per-name', len(fr_['lina']) == 6,
        'lina resolves to ONE entity stream (%d frames), not the union'
        % len(fr_['lina']))

    # --- source constants that must not drift --------------------------------
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            '..', '..', '..', 'bots', 'FunLib',
                            'jmz_func.lua')).read()
    chk('src-wide-scan', "bWide and 1200 or 700" in src,
        'the two scan radii are still 1200/700 in jmz_func.lua')
    chk('src-closing-domain', "( not bWide or nNow <= 700 ) and nSoon < nNow - 10" in src,
        'the closing clause is still pinned to the ORIGINAL 700')
    chk('src-reach-buffer', "hEnemy:GetAttackRange() + 150" in src,
        'reach is still GetAttackRange()+150')
    chk('src-gate', "J.IsModeTurbo() and J.IsSoakCandidate( 'tpreach' )" in src,
        "tpreach is still turbo-only and still gated")

    # --- the by-seed estimator (owed row `tpreach_bc4_cell_reread`) ----------
    # No corpus is needed to check the arithmetic, and the arithmetic is the
    # whole subject: the previous §BC.4 reading was hand-pooled, and 4(i-d)
    # names hand-pooling by games as the way a +26.60 gets read as a +9.20.
    def rec(seed, side, leg, added=True, dest='field'):
        return dict(seed=seed, arm_side=side, leg=leg, added=added, dest=dest)

    def cap(detail, ngames):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            est = by_seed(detail, ngames)
        return est, buf.getvalue()

    # One seed, both arm sides, unequal rates: arm must be the plain mean of
    # the two stratum deltas.
    d1 = ([rec(1, 'radiant', 'armed')] * 1 + [rec(1, 'radiant', 'baseline')] * 3
          + [rec(1, 'dire', 'armed')] * 5 + [rec(1, 'dire', 'baseline')] * 2)
    n1 = {(1, 'radiant'): 1, (1, 'dire'): 1}
    est, out = cap(d1, n1)
    ab, ba = 1 - 3, 5 - 2
    chk('byseed-arm-is-the-swap-average',
        est is not None
        and abs(est['ADDED:field/g  [BC.4 cell]']['arm'] - (ab + ba) / 2.0) < 1e-9,
        'ab %+d ba %+d -> arm %+.4f'
        % (ab, ba, est['ADDED:field/g  [BC.4 cell]']['arm'] if est else float('nan')))
    chk('byseed-registers-both-layers', ' ab ' in out and ' ba ' in out,
        'rule 4(i-a): both stratum readings on the record, always')

    # A seed dealt games on only ONE arm side has no partner for its roster
    # term.  The estimator must refuse rather than average what is left.
    d2 = d1 + [rec(2, 'radiant', 'armed')]
    n2 = dict(n1)
    n2[(2, 'radiant')] = 1
    est2, out2 = cap(d2, n2)
    # Line-scoped on purpose.  A whole-output `'4(i-b)' in out2` is satisfied
    # by the header's own citation, so a mutant that strips the rule from the
    # REFUSAL line survives it -- measured, not imagined (mutation M4 below in
    # the round report).  The check has to look at the line it is about.
    refusal = [ln for ln in out2.splitlines() if 'no arm estimator' in ln]
    chk('byseed-refuses-an-unpaired-seed',
        est2 is None and 'NOT PAIRED' in out2
        and len(refusal) == 1 and '4(i-b)' in refusal[0],
        'an unpaired seed must drop the corpus back to (i-b), not be dropped')
    chk('byseed-names-the-unpaired-seed', 'UNPAIRED 2' in out2,
        'a caller that prints "not paired" owes the reader which seed')

    # (i-d) as a mutation-shaped check: two seeds whose GAME counts differ, so
    # a games-weighted pool and the arithmetic mean of per-seed arms are
    # different numbers.  The tool must print the second.
    # A fat seed whose arm is 1.0 and a thin seed whose arm is 5.0: the
    # arithmetic mean is 3.0, the games-weighted pool is 26/18 = 1.444.  The
    # two numbers must not be allowed to coincide, or this check is decoration.
    d3 = ([rec(1, 'radiant', 'armed')] * 8 + [rec(1, 'dire', 'armed')] * 8
          + [rec(2, 'radiant', 'armed')] * 5 + [rec(2, 'dire', 'armed')] * 5)
    n3 = {(1, 'radiant'): 8, (1, 'dire'): 8, (2, 'radiant'): 1, (2, 'dire'): 1}
    est3, _ = cap(d3, n3)
    arm3 = est3['ADDED:field/g  [BC.4 cell]']['arm']
    weighted = 26 / 18.0
    chk('byseed-is-an-arithmetic-mean-across-seeds',
        abs(arm3 - 3.0) < 1e-9 and abs(arm3 - weighted) > 1.0
        and est3['ADDED:field/g  [BC.4 cell]']['n_seeds'] == 2,
        'arm %.4f over %d seeds (games-weighted pool would read %.4f)'
        % (arm3, est3['ADDED:field/g  [BC.4 cell]']['n_seeds'], weighted))

    # 4(i-c)/(i-e): opposed strata are an identity about this draw's roster
    # split, NOT a veto.  The arm must survive and be quoted.
    d4 = ([rec(1, 'radiant', 'armed')] * 3 + [rec(1, 'radiant', 'baseline')] * 1
          + [rec(1, 'dire', 'armed')] * 1 + [rec(1, 'dire', 'baseline')] * 2
          + [rec(2, 'radiant', 'armed')] * 3 + [rec(2, 'radiant', 'baseline')] * 1
          + [rec(2, 'dire', 'armed')] * 1 + [rec(2, 'dire', 'baseline')] * 2)
    n4 = {(1, 'radiant'): 1, (1, 'dire'): 1, (2, 'radiant'): 1, (2, 'dire'): 1}
    est4, out4 = cap(d4, n4)
    p4 = est4['ADDED:field/g  [BC.4 cell]']
    chk('byseed-opposed-is-not-a-veto',
        p4['per_seed'][0]['opposed'] and abs(p4['arm'] - 0.5) < 1e-9
        and 'NOT a veto' in out4,
        'ab +2 ba -1 -> arm %+.4f, still quoted' % p4['arm'])
    chk('byseed-bc4-bar-is-printed',
        'BC.4 re-entry bar' in out4 and 'NOT MET' in out4 and BC4_MIN_SEEDS == 4,
        '2 seeds must read NOT MET against the bar of >%d' % BC4_MIN_SEEDS)

    # BC.1: the retreat cell is counted, never estimated.  A `home` ADDED press
    # must not move the BC.4 cell at all.
    d5 = d1 + [rec(1, 'radiant', 'armed', dest='home')] * 5
    est5, out5 = cap(d5, n1)
    chk('byseed-retreat-cell-stays-out-of-the-bc4-arm',
        abs(est5['ADDED:field/g  [BC.4 cell]']['arm']
            - est['ADDED:field/g  [BC.4 cell]']['arm']) < 1e-9,
        'a home-destined ADDED press is one the lever never saw')
    chk('byseed-retreat-cell-is-reported-as-counts',
        'BC.1 retreat cell' in out5 and 'radiant/armed 5' in out5,
        'BC.1: no threshold, but the count is never suppressed')

    # The share observable has episodes, not games, as its denominator; a seed
    # with an empty ADDED denominator is skipped, not read as 0.0.
    d6 = d1 + [rec(3, 'radiant', 'armed', added=False),
               rec(3, 'radiant', 'baseline', added=False),
               rec(3, 'dire', 'armed', added=False),
               rec(3, 'dire', 'baseline', added=False)]
    n6 = dict(n1)
    n6[(3, 'radiant')] = 1
    n6[(3, 'dire')] = 1
    est6, out6 = cap(d6, n6)
    chk('byseed-share-skips-an-empty-denominator',
        est6['ADDED:field share of ADDED'] is not None
        and est6['ADDED:field share of ADDED']['skipped'] == [3]
        and 'absent, not 0.0' in out6,
        'an absent share is not a flat share (GH #257)')

    # --- end-to-end wiring: main() must FEED by_seed, not just define it ------
    # The battery above exercises `by_seed` directly, which leaves the three
    # lines in `main()` that build its inputs unchecked -- `arm_side` on each
    # press, the `(seed, arm_side) -> games` counter, and the call itself.
    # That is the half a corpus would have exercised, and there is no corpus
    # in a routine container, so it is built here: two seeds x two arm sides,
    # one game each, one banded press per game.
    tmp = tempfile.mkdtemp(prefix='tpreach_sc_')
    try:
        os.makedirs(os.path.join(tmp, 'timelines'))
        with open(os.path.join(tmp, 'games_manifest.jsonl'), 'w') as mf:
            for seed in (11, 22):
                for sd in ('radiant', 'dire'):
                    g = 'g%d_%s' % (seed, sd)
                    mf.write(json.dumps(dict(game=g, seed=seed, side=sd)) + '\n')
                    json.dump(tl(bot, still(720, 0)),
                              open(os.path.join(tmp, 'timelines',
                                                g + '.timeline.json'), 'w'))
        buf = io.StringIO()
        argv = sys.argv
        sys.argv = ['tpreach_domain.py', tmp, '--reach-mode', 'source']
        try:
            with contextlib.redirect_stdout(buf):
                rc = main()
        finally:
            sys.argv = argv
        out = buf.getvalue()
        chk('e2e-main-runs-the-by-seed-table', rc == 0
            and 'per-seed swap-average' in out,
            'main() exit %d' % rc)
        chk('e2e-main-pairs-both-seeds',
            'seeds paired 11, 22' in out and 'UNPAIRED' not in out,
            'the (seed, arm_side) counter must see 2 seeds x 2 sides')
        chk('e2e-main-prints-the-bc4-bar',
            'BC.4 re-entry bar: seeds = 2' in out and 'NOT MET' in out,
            'a 2-seed corpus must read NOT MET, printed by the tool')
        chk('e2e-main-prints-the-retreat-count-line',
            'BC.1 retreat cell' in out,
            'BC.1 is printed even when the cell is empty')
        chk('e2e-main-prints-the-share-line-even-when-unformable',
            'ADDED:field/ADDED [share]' in out,
            'an absent share must say so; silence reads as a flat share')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print('\n%d PASS / %d FAIL' % (len(ran) - len(fails), len(fails)))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
