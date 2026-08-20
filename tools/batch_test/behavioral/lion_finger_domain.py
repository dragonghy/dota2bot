#!/usr/bin/env python3
"""lion_finger_domain.py -- pre-flight sizing for the two GH #73 Lion levers.

GH #73 named two structural gaps in `bots/BotLib/hero_lion.lua` that could
explain the charter's "Finger of Death 0/1/2/0/0 casts per game" observation:

  * Fact 1 -- Lion has no ult-mana reserve (`nKeepMana` was write-only), so
    Impale/Hex can spend the mana Finger needs.  Proposed lever `lionult`,
    mirroring `X.zuus_ShouldSaveManaForUlt`.
  * Fact 2 -- `X.ConsiderR`'s kill and teamfight-weakest branches iterate
    `nInBonusEnemyList` (cast range + 400) with no per-branch range check, so a
    killable enemy at 1000-1300u can win the bid over nothing at all.

Before either lever is armed, the team's pre-flight rule (director 2026-08-20
21:15Z) requires showing the lever's domain is non-empty in real Turbo games.
This script measures all three domains off behav-dump timelines:

  A. reserve domain     -- frames with Finger trained + off cooldown where mana
                           is BELOW the ult cost (shipped `zusult` shape), and
                           the widened post-spend band [cost, cost + spend)
                           (the `zusultx` shape, GH #59).  This is where
                           `lionult` would have anything to say.
  B. kill windows       -- frames with Finger trained + off cooldown + affordable
                           where an enemy hero is at or under the kill
                           threshold, split by <= cast range (the casts the bot
                           can actually make) vs (cast range, cast range + 400]
                           (Fact 2's domain: bid returns a target it cannot
                           reach).  Reported against the real cast count.
  C. death hoard        -- Lion deaths within `--death-window` seconds of a frame
                           holding a ready + affordable Finger with an enemy
                           hero inside cast range.  This is the domain of the
                           `nSkillLV >= 2` clauses in the retreat branch and the
                           `nHP < 0.2` fight fallback, which in Turbo are
                           structurally dead (see boundaries).

Usage:
  lion_finger_domain.py <timeline.json> [<timeline.json> ...] [--json out.json]

Anchors (Dota 2 datafeed hero_id=26, verified 2026-08-20):
  lion_finger_of_death  damage [600, 725, 850]  mana [200, 400, 600]
                        cooldown [110, 70, 30]  cast range 900
  (`hero_lion.lua` computes the same damage as 475 + 125 * level, +100 with
  Aghanim's, so the table below and the Lua agree by construction.)

Boundaries (quote them with the number):
  * NO VISION (issue #27): the dumper does not emit per-hero visibility, so an
    enemy counted here may be invisible to Lion, in which case
    `J.GetNearbyHeroes` would not have returned it at all.  Every count in
    section B/C is therefore an UPPER bound on the real domain.
  * kill threshold uses base 25% magic resistance only -- no items, no
    `GetActualIncomingDamage`, no spell amp, no health regen subtraction.  The
    Lua predicate `J.WillMagicKillTarget` is strictly more conservative once the
    target carries any magic resistance item, so section B is again an upper
    bound.
  * snapshot sampling is whatever the dump used (0.5s recommended); a kill
    window shorter than one sample interval is invisible here.
  * `nSkillLV >= 2` is unreachable in Turbo in this corpus: hero level tops out
    at 9-11, and the second Finger point needs hero level 12.  Section C exists
    because of that, and reports the hero level range it observed.
  * post-game freeze (issue #43): samples past the last real event are dropped.

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.
"""
import argparse
import collections
import json
import math
import sys

LION = 'npc_dota_hero_lion'
FINGER = 'lion_finger_of_death'
IMPALE = 'lion_impale'
HEX = 'lion_voodoo'

FINGER_COST = {1: 200, 2: 400, 3: 600}
FINGER_DAMAGE = {1: 600, 2: 725, 3: 850}
IMPALE_COST = {1: 90, 2: 110, 3: 130, 4: 150}
HEX_COST = {1: 110, 2: 140, 3: 170, 4: 200}
CAST_RANGE = 900          # no Aether Lens; the Lua caps the sum at 1200
BONUS_RANGE = 400         # `nInBonusEnemyList` reach beyond cast range
BASE_MAGIC_RESIST = 0.25


def load(path):
    d = json.load(open(path))
    tmax = max(e['t'] for e in d['events'])        # issue #43
    d['snapshots'] = [s for s in d['snapshots'] if s['t'] <= tmax]
    return d


def dist(a, b):
    return math.hypot(a['x'] - b['x'], a['y'] - b['y'])


def spend_options(abils):
    """Mana a competing bid could take out of the pool this frame."""
    out = []
    q = abils.get(IMPALE)
    if q and q['level'] >= 1 and q['cd'] == 0:
        out.append(('impale', IMPALE_COST[min(q['level'], 4)]))
    w = abils.get(HEX)
    if w and w['level'] >= 1 and w['cd'] == 0:
        out.append(('hex', HEX_COST[min(w['level'], 4)]))
    return out


def analyse(path, death_window):
    d = load(path)
    lion = sorted([s for s in d['snapshots'] if s['hero'] == LION], key=lambda s: s['t'])
    if not lion:
        return None
    team = lion[0]['team']
    by_t = collections.defaultdict(list)
    for s in d['snapshots']:
        by_t[round(s['t'], 1)].append(s)

    casts = [e for e in d['events']
             if e['type'] == 'ABILITY' and e.get('actor') == LION
             and e.get('inflictor') == FINGER]
    deaths = [e for e in d['events'] if e['type'] == 'DEATH' and e.get('target') == LION]

    res = {
        'timeline': path,
        'lion_frames': len(lion),
        'hero_level_max': max(s['level'] for s in lion),
        'finger_level_max': 0,
        'finger_casts': [{'t': round(e['t'], 1), 'target': e.get('target', '')} for e in casts],
        'lion_deaths': len(deaths),
        'ready_frames': 0,
        'A_below_cost_frames': 0,          # shipped `zusult` shape domain
        'A_postspend_band_frames': 0,      # widened `zusultx` shape domain
        'A_min_mana_while_ready': None,
        'B_kill_window_in_range': 0,
        'B_kill_window_far_only': 0,
        'B_kill_window_both': 0,
        'B_far_only_episodes': [],
        'C_deaths_holding_finger': [],
    }

    far_run = None
    for s in lion:
        abils = {a['name']: a for a in s['abilities']}
        f = abils.get(FINGER)
        if not f or f['level'] < 1:
            continue
        res['finger_level_max'] = max(res['finger_level_max'], f['level'])
        if f['cd'] > 0:
            continue
        cost = FINGER_COST[min(f['level'], 3)]
        mana = s['mp']
        if res['A_min_mana_while_ready'] is None or mana < res['A_min_mana_while_ready']:
            res['A_min_mana_while_ready'] = mana
        if mana < cost:
            res['A_below_cost_frames'] += 1
            continue
        spends = spend_options(abils)
        if spends and mana - max(sp for _, sp in spends) < cost:
            res['A_postspend_band_frames'] += 1
        res['ready_frames'] += 1

        threshold = FINGER_DAMAGE[min(f['level'], 3)] * (1.0 - BASE_MAGIC_RESIST)
        near, far = [], []
        for o in by_t[round(s['t'], 1)]:
            if o['hero'] == LION or o['team'] == team or o['hp'] <= 0:
                continue
            if o['hp'] > threshold:
                continue
            dd = dist(o, s)
            if dd <= CAST_RANGE:
                near.append((round(dd), o['hero'][14:], o['hp']))
            elif dd <= CAST_RANGE + BONUS_RANGE:
                far.append((round(dd), o['hero'][14:], o['hp']))
        if near:
            res['B_kill_window_in_range'] += 1
        if far:
            res['B_kill_window_far_only'] += 1
        if near and far:
            res['B_kill_window_both'] += 1
        if far and not near:
            if far_run is not None and s['t'] - far_run['t_end'] <= 2.0:
                far_run['t_end'] = round(s['t'], 1)
                far_run['frames'] += 1
            else:
                if far_run:
                    res['B_far_only_episodes'].append(far_run)
                far_run = {'t_start': round(s['t'], 1), 't_end': round(s['t'], 1),
                           'frames': 1, 'sample': sorted(far)[0]}
        elif far_run is not None:
            res['B_far_only_episodes'].append(far_run)
            far_run = None
    if far_run:
        res['B_far_only_episodes'].append(far_run)

    for dev in deaths:
        held = []
        for s in lion:
            if not (dev['t'] - death_window <= s['t'] <= dev['t']):
                continue
            abils = {a['name']: a for a in s['abilities']}
            f = abils.get(FINGER)
            if not f or f['level'] < 1 or f['cd'] > 0:
                continue
            if s['mp'] < FINGER_COST[min(f['level'], 3)]:
                continue
            near = []
            for o in by_t[round(s['t'], 1)]:
                if o['hero'] == LION or o['team'] == team or o['hp'] <= 0:
                    continue
                dd = dist(o, s)
                if dd <= CAST_RANGE:
                    near.append((round(dd), o['hero'][14:], o['hp']))
            if near:
                held.append({'t': round(s['t'], 1), 'hp': s['hp'], 'hp_pct': round(s['hp_pct'], 2),
                             'mp': s['mp'], 'enemies_in_range': sorted(near)})
        if held:
            res['C_deaths_holding_finger'].append({
                'death_t': round(dev['t'], 1),
                'killer': dev.get('actor', '')[14:],
                'frames': held,
            })
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('timelines', nargs='+')
    ap.add_argument('--death-window', type=float, default=3.0,
                    help='seconds before a Lion death to look for a held Finger')
    ap.add_argument('--json', help='write the full per-game result here')
    args = ap.parse_args()

    out = []
    for path in args.timelines:
        r = analyse(path, args.death_window)
        if r is None:
            print('%s: no Lion in this game' % path)
            continue
        out.append(r)
        print('== %s' % path)
        print('   hero level max %d, finger level max %d, finger casts %d %s'
              % (r['hero_level_max'], r['finger_level_max'], len(r['finger_casts']),
                 [c['t'] for c in r['finger_casts']]))
        print('   A reserve: ready+affordable frames %d | below-cost frames %d | post-spend band frames %d | min mana while ready %s'
              % (r['ready_frames'], r['A_below_cost_frames'], r['A_postspend_band_frames'],
                 r['A_min_mana_while_ready']))
        print('   B windows: killable <= %du: %d frames | only in (%d, %d]: %d frames | both: %d'
              % (CAST_RANGE, r['B_kill_window_in_range'], CAST_RANGE,
                 CAST_RANGE + BONUS_RANGE, r['B_kill_window_far_only'], r['B_kill_window_both']))
        for ep in r['B_far_only_episodes']:
            print('      far-only episode t=%.1f-%.1f (%d frames) nearest %s'
                  % (ep['t_start'], ep['t_end'], ep['frames'], ep['sample']))
        print('   C deaths: %d total, %d holding a ready+affordable Finger with an enemy in range'
              % (r['lion_deaths'], len(r['C_deaths_holding_finger'])))
        for ep in r['C_deaths_holding_finger']:
            f0 = ep['frames'][0]
            print('      death t=%.1f killer=%s | first held frame t=%.1f hp=%d(%.2f) mp=%d in-range %s'
                  % (ep['death_t'], ep['killer'], f0['t'], f0['hp'], f0['hp_pct'], f0['mp'],
                     f0['enemies_in_range']))

    if out:
        tot = collections.Counter()
        for r in out:
            tot['games'] += 1
            tot['ready'] += r['ready_frames']
            tot['below'] += r['A_below_cost_frames']
            tot['band'] += r['A_postspend_band_frames']
            tot['near'] += r['B_kill_window_in_range']
            tot['far'] += r['B_kill_window_far_only']
            tot['casts'] += len(r['finger_casts'])
            tot['deaths'] += r['lion_deaths']
            tot['deaths_holding'] += len(r['C_deaths_holding_finger'])
        print('== TOTAL over %d games' % tot['games'])
        print('   A: %d ready+affordable frames, %d below cost, %d in the post-spend band'
              % (tot['ready'], tot['below'], tot['band']))
        print('   B: %d in-range kill-window frames vs %d actual casts; %d far-only frames'
              % (tot['near'], tot['casts'], tot['far']))
        print('   C: %d Lion deaths, %d holding a ready+affordable Finger with an enemy in range'
              % (tot['deaths'], tot['deaths_holding']))

    if args.json:
        json.dump(out, open(args.json, 'w'), indent=1)
        print('wrote %s' % args.json)
    return 0


if __name__ == '__main__':
    sys.exit(main())
