#!/usr/bin/env python3
"""Condition-(a) verifier for the lane-kill pair `l1trade` / `l5combo`.

WHY A SEPARATE SCANNER (do not merge this into roam_conversion.py)
------------------------------------------------------------------
`roam_conversion.py` scans a GEOMETRY domain (<=40% enemy within 800u, ally
nearby) that was built for `roamstale`: it deliberately spans every branch that
routes through mode_team_roam's Think, because the roamstale defect lives on
that shared path.  That is exactly why it cannot answer the lane-kill pair's own
(a) -- replay-check owed §G.5 for ten cycles because the scan domain could not
be separated from the other five early-return branches.

This scanner instead transcribes the two helpers' OWN gates
(`J.ShouldInitiateLaneKill` jmz_func.lua:6828, `J.ShouldSupportComboKill`
:6758) frame by frame, including the parts that differ between them -- and that
difference is what buys the isolation:

  l1trade  : IsCore(bot)      , enemy within  800u, target depth <= 800
  l5combo  : NOT IsCore(bot)  , enemy within  900u, target depth <= 400,
             plus a HARD VETO: >=2 enemies within 700u of the bot.

The role split (core vs support) and the l5combo 2-enemy veto are both fully
observable offline, so the scanner can build bands where a branch is
analytically dead while the surrounding geometry is unchanged.  See BANDS.

WHAT IS NOT OBSERVABLE (superset boundary -- state it in every report)
---------------------------------------------------------------------
`GetEstimatedDamageToTarget` is not in the dumper stream, so neither the
LETHALITY check (our combined burst >= victim HP + 4s regen) nor the SELF-RISK
check (their burst < 75% / 60% of my HP) can be evaluated.  Every episode this
scanner yields is therefore a SUPERSET of the frames the gate really fired on.
Proxy for lethality: victim hp_pct <= 0.40 (same bar #41 used).
`WasRecentlyDamagedByAnyHero` (inside J.ShouldReleaseLaneCommit) is likewise
missing, so the release leg is invisible too.

BID ARITHMETIC (why the bands are drawn where they are)
-------------------------------------------------------
Both branches return RemapValClamped(HP, 0, 0.5, NONE, 0.92) = min(0.92,
1.84*HP) and set bLaneKillCommit, which exempts them from `CapForLanePush`
(GH #31).  What they PREEMPT, in laning phase, is capped:
  * the last-hit branch below them returns 1.5 -> the cliff pulls >0.9 to 0.72;
  * CarryFindTarget's fallback is BOT_MODE_DESIRE_HIGH = 0.75 (uncapped).
So the armed bid beats what it replaces only above ~40% own HP:
  1.84*HP > 0.75  <=>  HP > 0.4076   (beats the 0.75 fallback)
  1.84*HP > 0.72  <=>  HP > 0.3913   (beats the capped last-hit branch)
Below that the branch REPLACES A HIGHER BID WITH A LOWER ONE -- team_roam's
desire drops on exactly the frames the rule wants to fight.  That is the
`actor_hp` split reported below; it is arithmetic, not a hypothesis.

MEASURES (all paired candidate-vs-baseline inside the same mirror game)
-----------------------------------------------------------------------
  commit   -- the actor damages THAT victim within 4s (the branch's whole point)
  kill     -- the victim dies within 6s
  switch   -- the actor damages a DIFFERENT enemy hero within the 4s window
              while never touching the victim: the commit-lock (4s sticky
              target) should suppress this on the armed side and nothing else
              in the bundle stamps a 4s target lock
  creep    -- the actor's only damage in the window lands on creeps: the armed
              branch preempts the last-hit branch, so this should DROP
  no_dmg   -- no damage at all in the window

BANDS
  ACTIVE   -- gate's observable conditions all true
  VETO     -- l5combo only: >=2 enemies within 700u, the gate is provably false
              while the geometry is otherwise identical (placebo control)
  OUT      -- t in [520,900): both helpers hard `return nil` (IsInLaningPhase),
              so any candidate-vs-baseline gap here belongs to the rest of the
              bundle, not to these two ids.  This control is valid HERE (unlike
              for roamstale, test_set §I.8.4) precisely because these two
              helpers are laning-phase-only by construction.

Usage:  lanekill_commit.py <sweep_out_dir> [<sweep_out_dir> ...]
Read-only; no AWS, no billable resource.
"""
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from roam_conversion import (load_game, dist, is_dead,  # noqa: E402
                             VICTIM_HP_PROXY)

LANING_END = 480.0          # turbo hard floor of J.IsInLaningPhase()
OUT_START, OUT_END = 520.0, 900.0
VICTIM_HP = VICTIM_HP_PROXY   # PROXY, mirrors nothing -- see roam_conversion.py
ALLY_RANGE_CORE = 1000.0    # J.GetNearbyHeroes(bot, 1000) in ShouldInitiateLaneKill
# MIRROR, not a proxy: `J.GetHP( hAlly ) >= 0.4` is a real shipped clause, in
# BOTH helpers (jmz_func.lua:7389 ShouldInitiateLaneKill, :7354
# ShouldSupportComboKill -- re-anchored 2026-08-23; the previous 7085/:7050
# predated ~250 lines of insertions and pointed at unrelated lines, of which
# only 49 came from the pullzone round that noticed it).  It is registered
# against those sites in
# tests/test_detector_source_constants.py and moves if and only if the Lua does.
# It shares a NUMBER with VICTIM_HP_PROXY and nothing else -- never fuse them.
ALLY_HP_MIN = 0.40
ENEMY_RANGE_CORE = 800.0
ENEMY_RANGE_SUP = 900.0
SUP_CLOSE_RANGE = 700.0     # the 2-enemy veto ring
DEPTH_CORE = 800.0
DEPTH_SUP = 400.0
DEDUP_S = 6.0
COMMIT_S = 4.0              # the branch's own commit-lock length
CONVERT_S = 6.0
LAG_S = 1.0                 # 1Hz snapshots lag the event stream

BID_FLOOR_HIGH = 0.75 / 1.84   # 0.4076 -- above this the armed bid beats 0.75
BID_FLOOR_CAP = 0.72 / 1.84    # 0.3913 -- above this it beats the capped 0.72


def ancients(tl):
    out = {}
    for b in tl['buildings']:
        if b.get('name') == 'ancient' and b['team'] not in out:
            out[b['team']] = (b['x'], b['y'])
    return out


def depth(victim, anc, own_team):
    """+ = deeper on the ENEMY side, matching the helpers' convention
    (dist to own ancient - dist to enemy ancient)."""
    enemy_team = 3 if own_team == 2 else 2
    if own_team not in anc or enemy_team not in anc:
        return None
    ox, oy = anc[own_team]
    ex, ey = anc[enemy_team]
    return (math.hypot(victim['x'] - ox, victim['y'] - oy)
            - math.hypot(victim['x'] - ex, victim['y'] - ey))


def scan(g, drops=None):
    tl = g['tl']
    anc = ancients(tl)
    dead = g['dead']            # [bug] #78: event-based liveness
    if drops is None:
        drops = collections.Counter()
    deaths = collections.defaultdict(list)
    dmg = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] == 'DEATH' and e.get('target_hero'):
            deaths[e['target']].append(e['t'])
        elif e['type'] == 'DAMAGE' and e.get('actor_hero'):
            dmg[e['actor']].append((e['t'], bool(e.get('target_hero')), e['target'],
                                    e.get('inflictor') or ''))

    def canon(h):
        return h.replace('npc_dota_hero_', '').replace('_', '')

    pauses = g['pauses']
    last = {}
    for t in sorted(g['frames']):
        in_lane = t < LANING_END
        out_ctl = OUT_START <= t < OUT_END
        if not (in_lane or out_ctl):
            continue
        if any(not (t + COMMIT_S < a or t - LAG_S > b) for a, b in pauses):
            continue
        # [bug] #78 fix (甲)/(丙): a corpse must not be able to BE the victim,
        # nor to satisfy a load-bearing clause (nearest enemy / backing ally)
        # on someone else's behalf.  The hp_pct>0 test is kept as the cheap
        # first cut and the DEATH-event span as the authority; `drops` counts
        # what the event test removes that the proxy let through, PER ARM --
        # that count is itself the verdict (test_set.md section X.7).
        alive = []
        for s in g['frames'][t]:
            if s.get('hp_pct', 0) <= 0:
                continue
            if is_dead(dead, s['hero'], t):
                drops['corpse_leaked_by_hp_proxy'] += 1
                drops['corpse_armed' if s['team'] == g['armed_team']
                      else 'corpse_base'] += 1
                continue
            alive.append(s)
        for actor in alive:
            pos = g['pos'].get(actor['hero'], 0)
            if pos == 0:
                continue
            core = pos in (1, 2, 3)
            branch = 'l1trade' if core else 'l5combo'
            erange = ENEMY_RANGE_CORE if core else ENEMY_RANGE_SUP
            dmax = DEPTH_CORE if core else DEPTH_SUP
            enemies = [s for s in alive if s['team'] != actor['team']
                       and dist(actor, s) <= erange]
            if not enemies:
                continue
            if core:
                # "backed": an ally hero within 1000u at >=40% HP
                if not any(a is not actor and a['team'] == actor['team']
                           and a['hp_pct'] >= ALLY_HP_MIN
                           and dist(actor, a) <= ALLY_RANGE_CORE for a in alive):
                    continue
                vetoed = False
            else:
                vetoed = sum(1 for s in alive if s['team'] != actor['team']
                             and dist(actor, s) <= SUP_CLOSE_RANGE) >= 2
            for victim in enemies:
                if victim['hp_pct'] > VICTIM_HP:
                    continue
                d = depth(victim, anc, actor['team'])
                if d is None or d > dmax:
                    continue
                key = (actor['hero'], actor['idx'], victim['hero'], victim['idx'])
                if key in last and t - last[key] < DEDUP_S:
                    continue
                last[key] = t
                # #78 (丁): if the ACTOR dies inside the outcome window, "what
                # did it do in the next 4s" has no offline answer -- drop and
                # count rather than score it as a non-commit.
                if any(t < x <= t + COMMIT_S for x in deaths[actor['hero']]):
                    drops['actor_died_in_window'] += 1
                    drops['actordie_armed' if actor['team'] == g['armed_team']
                          else 'actordie_base'] += 1
                    continue
                # How much of the 4s window the victim was actually alive for.
                # A victim killed at t+0.6s leaves 0.6s of attackable window --
                # scoring that as "did not auto-attack" is the SAME artifact
                # #78 names, one layer down, and it is the layer where the
                # sign is fixed negative for a gate that works.
                vdt = min([x - t for x in deaths[victim['hero']] if x > t - LAG_S]
                          or [float('inf')])
                vic = canon(victim['hero'])
                hits = [(ht, ish, tg, inf) for ht, ish, tg, inf in dmg[actor['hero']]
                        if t - LAG_S < ht <= t + COMMIT_S]
                on_vic = any(ish and canon(tg) == vic for _, ish, tg, _ in hits)
                on_other = any(ish and canon(tg) != vic for _, ish, tg, _ in hits)
                # A hero can "damage the victim" without ever DECIDING to: Zeus'
                # static field procs on every cast and hits everything within
                # 1200u (watched _182322 t=80.5 -- Zeus stood still, SLARDAR
                # closed on HIM, and the only damage on the victim was the
                # passive while Zeus was casting at a different enemy).  An
                # auto-attack (inflictor 'dota_unknown') is a targeting
                # decision, so score it separately.
                on_vic_attack = any(ish and canon(tg) == vic and inf == 'dota_unknown'
                                    for _, ish, tg, inf in hits)
                yield {
                    't': t, 'game': g['game'], 'run': g['run'], 'seed': g['seed'],
                    'branch': branch,
                    'band': 'OUT' if out_ctl else ('VETO' if vetoed else 'ACTIVE'),
                    'actor': canon(actor['hero']), 'victim': vic,
                    'pos': pos,
                    'armed': actor['team'] == g['armed_team'],
                    'actor_hp': actor['hp_pct'], 'victim_hp': victim['hp_pct'],
                    'edist': round(dist(actor, victim)), 'depth': round(d),
                    'commit': on_vic,
                    'commit_attack': on_vic_attack,
                    'switch': on_other and not on_vic,
                    'creep': (not on_vic and not on_other and bool(hits)),
                    'no_dmg': not hits,
                    'kill': any(t - LAG_S < x <= t + CONVERT_S
                                for x in deaths[victim['hero']]),
                    'bid_wins': actor['hp_pct'] > BID_FLOOR_HIGH,
                    'vic_dt': vdt,
                    'full_window': vdt > COMMIT_S,
                }


def pct(n, d):
    return f'{100.0*n/d:5.1f}% ({n}/{d})' if d else '   n/a  '


def table(rows, label, keys=('commit', 'commit_attack', 'kill', 'switch', 'creep', 'no_dmg')):
    a = [r for r in rows if r['armed']]
    b = [r for r in rows if not r['armed']]
    print(f'\n{label}   armed n={len(a)}  baseline n={len(b)}')
    print(f'  {"metric":8} {"armed":>16} {"baseline":>16} {"delta":>8}')
    for k in keys:
        na, nb = sum(r[k] for r in a), sum(r[k] for r in b)
        da = 100.0 * na / len(a) if a else 0.0
        db = 100.0 * nb / len(b) if b else 0.0
        print(f'  {k:8} {pct(na, len(a)):>16} {pct(nb, len(b)):>16} '
              f'{da - db:+7.1f}pp')


def main():
    rows = []
    games = 0
    drops = collections.Counter()
    for d in sys.argv[1:]:
        tld = os.path.join(d, 'timelines')
        for fn in sorted(os.listdir(tld)):
            if not fn.endswith('.timeline.json'):
                continue
            stem = fn[:-len('.timeline.json')]
            aj = os.path.join(d, 'analysis', stem + '.analysis.json')
            if not os.path.exists(aj):
                continue
            g = load_game(os.path.join(tld, fn), aj)
            if g is None:
                continue                      # warmup game (no mirror: stamp)
            # Two runs of the same wave can emit an identically named
            # <timestamp>_slot1 game (charter trap: ".dem 同名跨 run 撞车").
            # Tag every row with its run or downstream joins silently merge
            # two different games.
            g['run'] = os.path.basename(os.path.normpath(d))[:24]
            g['game'] = stem
            g['seed'] = json.load(open(aj)).get('script_version', '').split(':')[-2]
            games += 1
            rows.extend(scan(g, drops))
    print(f'games={games}  episodes={len(rows)}')
    # [bug] #78 / test_set section X.7 pre-registered line: report what the
    # event-based liveness test removed, SPLIT BY ARM.  A corpse artifact that
    # is symmetric across arms cannot have produced the headline; one that
    # leans to the arm that kills more can.
    print('\n[#78] frames/episodes removed by the DEATH-event liveness test')
    print(f"  corpse snapshots the hp_pct>0 proxy let through: "
          f"{drops['corpse_leaked_by_hp_proxy']}  "
          f"(armed {drops['corpse_armed']} / baseline {drops['corpse_base']})")
    print(f"  episodes dropped, actor died inside the 4s window: "
          f"{drops['actor_died_in_window']}  "
          f"(armed {drops['actordie_armed']} / baseline {drops['actordie_base']})")
    for branch in ('l1trade', 'l5combo'):
        br = [r for r in rows if r['branch'] == branch]
        for band in ('ACTIVE', 'VETO', 'OUT'):
            sub = [r for r in br if r['band'] == band]
            if sub:
                table(sub, f'[{branch}] {band}')
        act = [r for r in br if r['band'] == 'ACTIVE']
        # #78's core objection, at the layer it actually bites: a victim killed
        # 0.6s into the window cannot be auto-attacked for the other 3.4s, so
        # "did not auto-attack" is scored against the arm that killed it.
        # Restricting to victims that survived the WHOLE window removes that
        # coupling by construction -- the surviving deficit, if any, is the
        # behaviour.  Report both halves; the split itself is diagnostic.
        table([r for r in act if r['full_window']],
              f'[{branch}] ACTIVE, victim ALIVE through the full 4s window (#78-clean)')
        table([r for r in act if not r['full_window']],
              f'[{branch}] ACTIVE, victim died inside the window (window truncated)')
        table([r for r in act if r['bid_wins']], f'[{branch}] ACTIVE, HP>0.408 (armed bid wins)')
        table([r for r in act if not r['bid_wins']], f'[{branch}] ACTIVE, HP<=0.408 (armed bid LOSES to what it preempts)')
    # per-seed paired view of the headline metric
    print('\nper-seed ACTIVE commit rate (armed - baseline), pp')
    for branch in ('l1trade', 'l5combo'):
        line = [f'  {branch:8}']
        for seed in sorted(set(r['seed'] for r in rows)):
            sub = [r for r in rows if r['branch'] == branch
                   and r['band'] == 'ACTIVE' and r['seed'] == seed]
            a = [r for r in sub if r['armed']]
            b = [r for r in sub if not r['armed']]
            if not a or not b:
                line.append(f'{seed}:   n/a')
                continue
            d = 100.0 * sum(r['commit'] for r in a) / len(a) \
                - 100.0 * sum(r['commit'] for r in b) / len(b)
            line.append(f'{seed}:{d:+6.1f}')
        print(' '.join(line))
    # Seed-paired difference-in-differences.  The ACTIVE band alone is a BUNDLE
    # read (the candidate side carries 16 armed ids); subtracting a band where
    # THIS branch is analytically dead but the rest of the bundle is unchanged
    # is the only isolation this corpus can give.  VETO exists for l5combo only
    # (the >=2-enemies-within-700 hard veto); OUT (t 520-900, both helpers
    # `return nil`) exists for both.  The spread of the control band's own
    # armed-minus-baseline delta across seeds IS the empirical zero channel --
    # quote it next to every DiD, per the capmono lesson (GH #72).
    print('\nseed-paired DiD on commit rate (pp).  ctl = the same statistic in a '
          'band where the branch is dead.')
    for branch in ('l1trade', 'l5combo'):
        for ctl in ('VETO', 'OUT'):
            per_seed = []
            for seed in sorted(set(r['seed'] for r in rows)):
                vals = {}
                for band in ('ACTIVE', ctl):
                    sub = [r for r in rows if r['branch'] == branch
                           and r['band'] == band and r['seed'] == seed]
                    a = [r for r in sub if r['armed']]
                    b = [r for r in sub if not r['armed']]
                    if not a or not b:
                        vals = None
                        break
                    vals[band] = (100.0 * sum(r['commit'] for r in a) / len(a)
                                  - 100.0 * sum(r['commit'] for r in b) / len(b))
                if vals:
                    per_seed.append((seed, vals['ACTIVE'], vals[ctl]))
            if not per_seed:
                continue
            dids = [x[1] - x[2] for x in per_seed]
            ctls = [x[2] for x in per_seed]
            n = len(dids)
            mean = sum(dids) / n
            sd = (sum((d - mean) ** 2 for d in dids) / (n - 1)) ** 0.5 if n > 1 else float('nan')
            cmean = sum(ctls) / n
            csd = (sum((c - cmean) ** 2 for c in ctls) / (n - 1)) ** 0.5 if n > 1 else float('nan')
            print(f'  {branch:8} ACTIVE-{ctl:5} n_seed={n} DiD mean {mean:+6.1f}pp '
                  f'SD {sd:5.1f} SE {sd / n ** 0.5:5.1f} | per-seed '
                  + ' '.join(f'{s}:{d - c:+.0f}' for s, d, c in per_seed)
                  + f' | ZERO CHANNEL ({ctl} delta alone): mean {cmean:+.1f} SD {csd:.1f}'
                  f' -> {n}-seed MDE +-{2 * csd / n ** 0.5:.0f}pp')

    with open('/tmp/lanekill_rows.jsonl', 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')
    print('\nrows -> /tmp/lanekill_rows.jsonl')


if __name__ == '__main__':
    main()
