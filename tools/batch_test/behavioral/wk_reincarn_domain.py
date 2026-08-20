#!/usr/bin/env python3
"""wk_reincarn_domain.py -- pre-flight sizing for the `wkreincarnmp` gate.

`wkreincarnmp` (hero stream, 2026-08-18; `J.IsWkReincarnationArmed` in
`bots/FunLib/jmz_func.lua`) swaps a hardcoded 160-mana threshold for
`abilityR:GetManaCost()` when deciding whether Wraith King's Reincarnation is
"armed".  Its only consumer is `bots/mode_retreat_generic.lua:196-202`:

    if bTeamFight and botName == "npc_dota_hero_skeleton_king"
        and bot:GetLevel() >= 6
        and J.IsWkReincarnationArmed(bot)
    then return BOT_MODE_DESIRE_NONE end        -- "stand and fight"

So the gate can only change a decision on a frame where the two thresholds
DISAGREE.  Per the Dota 2 datafeed (hero_id=42, pulled 2026-08-21):

    skeleton_king_reincarnation  mana_costs [220, 110, 0]
                                 cooldowns  [180, 150, 120]
    note_loc: "Wraith King won't revive if he doesn't have enough mana."

Divergence bands, by Reincarnation level:

    lvl 1 (cost 220): mana in [160, 220)  shipped=ARMED (wrong), gated=not
                      -> the defect: WK stands in a losing fight believing it
                         has a free life, and the ult does not fire.
    lvl 2 (cost 110): mana in [110, 160)  shipped=not, gated=ARMED
    lvl 3 (cost   0): mana in [  0, 160)  shipped=not, gated=ARMED
                      -> the opposite direction: the gate makes WK stand and
                         fight MORE often.  Worth separating, because the two
                         directions have different cost profiles.

Sections measured off behav-dump timelines:

  A. divergence band -- WK frames with Reincarnation trained, cooldown <= 1.0s
                        and hero level >= 6 whose mana sits in the band above.
                        Reported split by Reincarnation level / direction.
                        This is the ceiling: without these frames the armed and
                        shipped trees are byte-identical end-to-end (the
                        `axeblink` trap).
  B. consumer domain -- A intersected with a proxy for `J.IsInTeamFight(bot,
                        1200)`, the outer clause of the only consumer.  Also
                        reports how often the SHIPPED rule fires at all
                        (fight proxy + level >= 6 + shipped predicate true),
                        so the divergence count has a denominator.
  D. mana profile    -- the distribution of WK's mana over every frame where
                        Reincarnation is trained and ready.  This is what makes
                        an empty section A structural rather than undersampled:
                        if the 1st percentile sits well above the ult cost, no
                        amount of extra corpus will populate the band.
  C. outcome side    -- WK deaths, split by whether Reincarnation actually
                        fired (an `ABILITY_TRIGGER` event whose inflictor is
                        `skeleton_king_reincarnation`; note that a DEATH event
                        is emitted either way, and that
                        `modifier_skeleton_king_reincarnation_scepter_active`
                        is NOT the trigger -- it also appears with the ability
                        unlearned), and by the mana WK carried just before
                        dying.
                        The failure the gate claims to prevent is a death in
                        the lvl-1 band with the ult ready and NOT firing.

Usage:
  wk_reincarn_domain.py <timeline.json> [...] [--json out.json] [--verbose]

Boundaries (quote them with the number):
  * NO MODE DATA: the dumper records no bot modes, so `J.IsInTeamFight` (>= 2
    nearby allies in BOT_MODE_ATTACK within the radius) cannot be reproduced.
    Section B uses a PROXY: >= 2 allied heroes alive within 1200 of WK
    (WK counts, matching `J.GetNearbyHeroes(bot, r, false, ...)` which includes
    the bot itself) AND >= 1 live enemy hero within 1200.  Allies standing next
    to WK in RETREAT/FARM mode inflate this, so section B is an UPPER bound.
  * NO VISION (issue #27): enemy positions here are ground truth, not what WK
    could see.  Same direction -- upper bound.
  * `GetManaCost()` is read off the datafeed, not the frame: make_fixture.py
    extracts no ability specs (the same anchor class the gate's own comment and
    `iterations/state.json: wkreincarnmp_20260818` already record).  The
    datafeed values are quoted above and cross-checked against the observed
    mana drop across real Reincarnation triggers (see section C output).
  * snapshot sampling is whatever the dump used (0.5s recommended); a mana
    band crossed inside one interval is invisible here.
  * post-game freeze (issue #43): samples past the last real event are dropped.
  * `.dem` files exist for slot 1 only (issue #75), so per-wave n is games/16.

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.
"""
import argparse
import collections
import json
import math
import sys

WK = 'npc_dota_hero_skeleton_king'
REINCARN = 'skeleton_king_reincarnation'
TRIGGER_EVENT = 'ABILITY_TRIGGER'   # inflictor == REINCARN when the ult fires

# Dota 2 datafeed, hero_id=42, pulled 2026-08-21.
REINCARN_COST = {1: 220, 2: 110, 3: 0}
REINCARN_CD = {1: 180, 2: 150, 3: 120}

SHIPPED_THRESHOLD = 160       # the hardcoded number the gate replaces
FIGHT_RADIUS = 1200           # J.IsInTeamFight(bot, 1200) at the consumer
READY_CD = 1.0                # abilityR:GetCooldownTimeRemaining() > 1.0 -> false
MIN_HERO_LEVEL = 6            # bot:GetLevel() >= 6 at the consumer


def load(path):
    d = json.load(open(path))
    tmax = max(e['t'] for e in d['events'])         # issue #43
    d['snapshots'] = [s for s in d['snapshots'] if s['t'] <= tmax]
    return d


def dist(a, b):
    return math.hypot(a['x'] - b['x'], a['y'] - b['y'])


def ability(snap, name):
    for a in snap['abilities']:
        if a['name'] == name:
            return a
    return None


def band(level, mana):
    """Which side of the disagreement this frame is on.

    Returns None when shipped and gated agree, otherwise a short label.
    """
    cost = REINCARN_COST[min(level, 3)]
    shipped = mana >= SHIPPED_THRESHOLD
    gated = mana >= cost
    if shipped == gated:
        return None
    return 'shipped_overclaims' if shipped else 'gated_extends'


def analyse(path):
    d = load(path)
    wk = sorted([s for s in d['snapshots'] if s['hero'] == WK], key=lambda s: s['t'])
    if not wk:
        return None
    team = wk[0]['team']

    by_t = collections.defaultdict(list)
    for s in d['snapshots']:
        by_t[round(s['t'], 1)].append(s)

    out = {
        'game': path.split('/')[-1].replace('.timeline.json', ''),
        'wk_level_max': max(s['level'] for s in wk),
        'reincarn_level_max': 0,
        'frames_ready': 0,
        'band_frames': collections.Counter(),
        'band_frames_fight': collections.Counter(),
        'band_episodes': [],
        'min_mana_while_ready': None,
        'mana_while_ready': [],
        'shipped_rule_frames': 0,
        'deaths': [],
        'triggers': [],
    }

    # --- reincarnation triggers, for the cost cross-check and section C ---
    trigger_ts = sorted(e['t'] for e in d['events']
                        if e['type'] == TRIGGER_EVENT
                        and e.get('actor') == WK
                        and e.get('inflictor') == REINCARN)
    deaths = sorted(e['t'] for e in d['events']
                    if e['type'] == 'DEATH' and e.get('target') == WK)

    def mana_before(t):
        prev = [s for s in wk if s['t'] <= t]
        return prev[-1] if prev else None

    for t in trigger_ts:
        s = mana_before(t)
        after = [x for x in wk if x['t'] > t + 3.0]
        out['triggers'].append({
            't': t,
            'mana_before': s['mp'] if s else None,
            'reincarn_level': (ability(s, REINCARN) or {}).get('level') if s else None,
            'mana_after_3s': after[0]['mp'] if after else None,
        })

    # --- per-frame scan ---
    cur_episode = None
    for s in wk:
        # DEAD FRAMES ARE NOT DECISIONS.  The dumper keeps emitting snapshots
        # for a dead hero with its state FROZEN at the instant of death, so a
        # naive scan counts one death with an awkward mana value as dozens of
        # "divergence frames".  Measured: game 20260820_181711_slot1 reported
        # 34 band frames, 33 of which were the corpse of the t=344.7 death
        # holding 187 mana until respawn.
        if s['hp'] <= 0:
            if cur_episode:
                out['band_episodes'].append(cur_episode)
                cur_episode = None
            continue
        r = ability(s, REINCARN)
        if r is None or r['level'] < 1:
            continue
        out['reincarn_level_max'] = max(out['reincarn_level_max'], r['level'])
        if r['cd'] > READY_CD or s['level'] < MIN_HERO_LEVEL:
            if cur_episode:
                out['band_episodes'].append(cur_episode)
                cur_episode = None
            continue
        out['frames_ready'] += 1
        out['mana_while_ready'].append(s['mp'])
        if out['min_mana_while_ready'] is None or s['mp'] < out['min_mana_while_ready']:
            out['min_mana_while_ready'] = s['mp']

        peers_all = by_t.get(round(s['t'], 1), [])
        allies_all = [p for p in peers_all
                      if p['team'] == team and p['hp'] > 0 and dist(p, s) <= FIGHT_RADIUS]
        enemies_all = [p for p in peers_all
                       if p['team'] != team and p['hp'] > 0 and dist(p, s) <= FIGHT_RADIUS]
        if (len(allies_all) >= 2 and len(enemies_all) >= 1
                and s['mp'] >= SHIPPED_THRESHOLD):
            out['shipped_rule_frames'] += 1

        lab = band(r['level'], s['mp'])
        if lab is None:
            if cur_episode:
                out['band_episodes'].append(cur_episode)
                cur_episode = None
            continue
        out['band_frames'][lab] += 1

        peers = by_t.get(round(s['t'], 1), [])
        allies = [p for p in peers
                  if p['team'] == team and p['hp'] > 0 and dist(p, s) <= FIGHT_RADIUS]
        enemies = [p for p in peers
                   if p['team'] != team and p['hp'] > 0 and dist(p, s) <= FIGHT_RADIUS]
        in_fight = len(allies) >= 2 and len(enemies) >= 1
        if in_fight:
            out['band_frames_fight'][lab] += 1

        if cur_episode and cur_episode['label'] == lab and s['t'] - cur_episode['t_end'] <= 1.0:
            cur_episode['t_end'] = s['t']
            cur_episode['frames'] += 1
            cur_episode['fight_frames'] += 1 if in_fight else 0
            cur_episode['mana_min'] = min(cur_episode['mana_min'], s['mp'])
            cur_episode['mana_max'] = max(cur_episode['mana_max'], s['mp'])
        else:
            if cur_episode:
                out['band_episodes'].append(cur_episode)
            cur_episode = {
                'label': lab, 't_start': s['t'], 't_end': s['t'], 'frames': 1,
                'fight_frames': 1 if in_fight else 0,
                'reincarn_level': r['level'], 'hero_level': s['level'],
                'mana_min': s['mp'], 'mana_max': s['mp'],
                'hp_pct_at_start': s['hp_pct'],
            }
    if cur_episode:
        out['band_episodes'].append(cur_episode)

    # --- section C: deaths ---
    for t in deaths:
        s = mana_before(t)
        if s is None:
            continue
        r = ability(s, REINCARN)
        fired = any(abs(x - t) <= 1.5 for x in trigger_ts)
        peers = by_t.get(round(s['t'], 1), [])
        enemies = [p for p in peers
                   if p['team'] != team and p['hp'] > 0 and dist(p, s) <= FIGHT_RADIUS]
        allies = [p for p in peers
                  if p['team'] == team and p['hp'] > 0 and dist(p, s) <= FIGHT_RADIUS]
        lab = None
        ready = False
        if r and r['level'] >= 1:
            ready = r['cd'] <= READY_CD
            lab = band(r['level'], s['mp'])
        out['deaths'].append({
            't': t, 'mana': s['mp'], 'max_mp': s['max_mp'],
            'hero_level': s['level'],
            'reincarn_level': r['level'] if r else 0,
            'reincarn_cd': r['cd'] if r else None,
            'ready': ready, 'fired': fired, 'band': lab,
            'allies_1200': len(allies), 'enemies_1200': len(enemies),
        })
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('timelines', nargs='+')
    ap.add_argument('--json', help='write the full per-game result here')
    ap.add_argument('--verbose', action='store_true',
                    help='print every divergence episode')
    args = ap.parse_args()

    results = []
    for p in args.timelines:
        r = analyse(p)
        if r is None:
            print('== %-28s no Wraith King in this game' % p.split('/')[-1][:28])
            continue
        results.append(r)
        print('== %-24s hero lvl max %2d, reincarn lvl max %d, ready frames %4d, '
              'min mana while ready %s'
              % (r['game'], r['wk_level_max'], r['reincarn_level_max'],
                 r['frames_ready'], r['min_mana_while_ready']))
        print('   A: divergence frames  shipped_overclaims %3d | gated_extends %3d'
              % (r['band_frames']['shipped_overclaims'], r['band_frames']['gated_extends']))
        print('   B: with fight proxy   shipped_overclaims %3d | gated_extends %3d'
              % (r['band_frames_fight']['shipped_overclaims'],
                 r['band_frames_fight']['gated_extends']))
        eps = [e for e in r['band_episodes'] if e['fight_frames'] > 0]
        print('   B: episodes in fight  %d (of %d divergence episodes); the '
              'SHIPPED rule fires on %d frames'
              % (len(eps), len(r['band_episodes']), r['shipped_rule_frames']))
        if args.verbose:
            for e in r['band_episodes']:
                print('      %-18s t=%.1f-%.1f  %2d frames (%d in fight)  '
                      'mana %d-%d  reincarn lvl %d  hero lvl %d  hp %.2f'
                      % (e['label'], e['t_start'], e['t_end'], e['frames'],
                         e['fight_frames'], e['mana_min'], e['mana_max'],
                         e['reincarn_level'], e['hero_level'], e['hp_pct_at_start']))
        fired = [d for d in r['deaths'] if d['fired']]
        in_band = [d for d in r['deaths'] if d['band'] and d['ready']]
        print('   C: %d deaths, %d reincarnations fired, %d deaths inside the '
              'divergence band with the ult off cooldown'
              % (len(r['deaths']), len(fired), len(in_band)))
        for d in in_band:
            print('      t=%.1f mana %d/%d reincarn lvl %d (cost %d) band %s '
                  'allies %d enemies %d'
                  % (d['t'], d['mana'], d['max_mp'], d['reincarn_level'],
                     REINCARN_COST[min(d['reincarn_level'], 3)], d['band'],
                     d['allies_1200'], d['enemies_1200']))
        for tr in r['triggers']:
            print('      TRIGGER t=%.1f mana before %s -> after %s (reincarn lvl %s)'
                  % (tr['t'], tr['mana_before'], tr['mana_after_3s'], tr['reincarn_level']))

    if results:
        tot = collections.Counter()
        totf = collections.Counter()
        for r in results:
            tot.update(r['band_frames'])
            totf.update(r['band_frames_fight'])
        deaths = sum(len(r['deaths']) for r in results)
        fired = sum(len([d for d in r['deaths'] if d['fired']]) for r in results)
        in_band = sum(len([d for d in r['deaths'] if d['band'] and d['ready']])
                      for r in results)
        eps = sum(len([e for e in r['band_episodes'] if e['fight_frames'] > 0])
                  for r in results)
        print('== TOTAL (%d games with Wraith King)' % len(results))
        print('   A: %d ready frames, %d shipped_overclaims, %d gated_extends'
              % (sum(r['frames_ready'] for r in results),
                 tot['shipped_overclaims'], tot['gated_extends']))
        print('   B: %d / %d divergence frames also pass the fight proxy; '
              '%d episodes (%.2f/game)'
              % (totf['shipped_overclaims'] + totf['gated_extends'],
                 tot['shipped_overclaims'] + tot['gated_extends'],
                 eps, eps / float(len(results))))
        print('   C: %d WK deaths, %d reincarnations fired, %d deaths in band'
              % (deaths, fired, in_band))
        mana = sorted(m for r in results for m in r['mana_while_ready'])
        if mana:
            def pc(p):
                return mana[min(len(mana) - 1, int(p * len(mana) / 100))]
            print('   D: mana while ready  n=%d  min %d  p1 %d  p5 %d  p25 %d  '
                  'median %d   (lvl-1 ult cost %d, shipped threshold %d)'
                  % (len(mana), mana[0], pc(1), pc(5), pc(25), pc(50),
                     REINCARN_COST[1], SHIPPED_THRESHOLD))
            print('   D: shipped rule fires on %d frames total; %d of them '
                  'would flip if armed'
                  % (sum(r['shipped_rule_frames'] for r in results),
                     totf['shipped_overclaims']))

    if args.json:
        json.dump(results, open(args.json, 'w'), indent=1)
    return 0


if __name__ == '__main__':
    sys.exit(main())
