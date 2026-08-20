#!/usr/bin/env python3
"""Lane-kill opportunity scanner + action-object (creep-vs-hero) diff.

Rebuilds, from dumper timelines, the two frame-level measurements the director
pre-registered for the `roamstale` bisect (test_set.md section G.3):

  1. in-domain kill conversion -- the replay-check #41 metric: during the
     laning phase, when a <=40% HP enemy hero stands within 800u of a bot that
     has an ally nearby, does that enemy die within 6s?
  2. the action-object split -- inside the same episodes, does the bot's own
     damage in the next 4s land on the ENEMY HERO or on a CREEP?  The
     `roamstale` defect (GH #39/#41) is that Think() attacks LAST frame's
     last-hit creep whenever an early collapse branch wins the auction, so the
     stale-handle signature is "episode open, bot damages creeps only".

Plus the out-of-domain control window (t 520-900s) where both lane-kill
helpers hard `return nil`, so any candidate-vs-baseline gap there is NOT
attributable to these branches.

Usage:
    roam_conversion.py <sweep_out_dir> [<sweep_out_dir> ...]

Each sweep_out_dir is a directory produced by sweep_run.sh (it must contain
timelines/ and analysis/).  Read-only; no AWS, no billable resource.
"""
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "soak"))
import seed_draft  # noqa: E402  -- the only correct source of a hero's position

LANING_END = 480.0        # turbo hard floor of J.IsInLaningPhase()
OUT_START, OUT_END = 520.0, 900.0
VICTIM_HP = 0.40
VICTIM_RANGE = 800.0
ALLY_RANGE = 1200.0
DEDUP_S = 6.0
CONVERT_S = 6.0
ACTION_S = 4.0
# Snapshots are 1Hz and LAG the event stream: a victim can already be dead in
# the DEATH events while the next snapshot still shows it at 4% HP (real case:
# 20260819_182941_slot1, PA dies t=465.1, snapshot t=465.4 says hp_pct 0.04).
# Both the kill window and the action window therefore reach LAG_S back, or a
# kill that the episode's own frame provoked is scored as a non-conversion.
LAG_S = 1.0


def dist(a, b):
    return math.hypot(a['x'] - b['x'], a['y'] - b['y'])


def paused_spans(tl, frames):
    """Same definition as detect.py's _paused_spans: an event gap >=3s during
    which every hero's snapshot position is frozen.  Window detectors MUST skip
    these -- an armed-side 24s 'stall' in 20260819_183042_slot1 (earthshaker
    next to a 14% slardar) turned out to be the frozen post-game segment, with
    every entity's x/y and hp identical for 24 straight frames."""
    per_hero = collections.defaultdict(list)
    for t, snaps in frames.items():
        for s in snaps:
            per_hero[s['hero']].append((t, s['x'], s['y']))
    spans, ts = [], [e['t'] for e in tl['events']]
    for a, b in zip(ts, ts[1:]):
        if b - a < 3.0:
            continue
        frozen, sampled = True, False
        for pts in per_hero.values():
            xs = {(x, y) for (t, x, y) in pts if a < t < b}
            if len(xs) >= 2:
                frozen = False
                break
            if xs:
                sampled = True
        if frozen and sampled:
            spans.append((a, b))
    return spans


def load_game(tl_path, aj_path):
    tl = json.load(open(tl_path))
    aj = json.load(open(aj_path))
    sv = aj.get('script_version', '')
    if not sv.startswith('mirror:'):
        return None
    armed_side = sv.rsplit(':', 1)[-1]           # radiant | dire
    armed_team = 2 if armed_side == 'radiant' else 3
    # Position comes from the SEED's draft.  The old `team_slot % 5 + 1` here was
    # wrong: `X.ShufflePickOrder` permutes pick slots every game with the engine's
    # unseeded RandomInt while the (hero, role, lane) triple travels together, so
    # the slot carries per-game entropy and the hero keeps its drafted role.  On
    # 291 mirror games the slot label agreed with the drafted one on 47.3% of rows
    # and explained eta^2 = 0.174 of last-hit variance against 0.482 (GH #57).
    # A game we cannot attribute is dropped, not guessed.
    pos = seed_draft.positions_for_game(aj)
    if pos is None:
        return None

    # Illusions are emitted as separate entities under the SAME class name
    # (a Chaos Knight Phantasm shows up as six npc_dota_hero_chaos_knight rows
    # in one frame).  Counting them multiplies episodes and fakes geometry, so
    # lock each hero to its real entity: the idx present for the whole game.
    # (Charter tool-trap: "lock idx before tracking a single unit".)
    seen = collections.Counter((s['hero'], s['idx']) for s in tl['snapshots'])
    real = {}
    for (h, i), n in seen.items():
        if h not in real or n > real[h][1]:
            real[h] = (i, n)
    real_idx = {h: v[0] for h, v in real.items()}

    # The dumper keeps emitting snapshots for ~25s AFTER the game ends (every
    # one of the 13 games in the 1808xx wave has a 24-25s frozen tail, 4303
    # rows total).  detect.py's _paused_spans cannot see it -- that definition
    # needs an event PAIR bracketing the freeze, and the tail has no trailing
    # event -- so window detectors read frozen post-game state as behavior.
    # Cut everything past the last event.
    t_end = max(e['t'] for e in tl['events'])

    frames = collections.defaultdict(list)
    n_illusion = 0
    for s in tl['snapshots']:
        if real_idx.get(s['hero']) != s['idx']:
            n_illusion += 1
            continue
        if s['t'] > t_end:
            continue
        frames[round(s['t'], 1)].append(s)
    return {
        'tl': tl, 'frames': frames, 'pos': pos, 'n_illusion': n_illusion,
        'armed_team': armed_team, 'armed_side': armed_side,
        'pauses': paused_spans(tl, frames),
    }


def scan(g, t_lo, t_hi):
    """Yield opportunity episodes in [t_lo, t_hi)."""
    frames, pos = g['frames'], g['pos']
    deaths = collections.defaultdict(list)
    dmg = collections.defaultdict(list)
    for e in g['tl']['events']:
        if e['type'] == 'DEATH' and e.get('target_hero'):
            deaths[e['target']].append(e['t'])
        elif e['type'] == 'DAMAGE' and e.get('actor_hero'):
            dmg[e['actor']].append((e['t'], bool(e.get('target_hero')), e['target']))

    pauses = g['pauses']
    last = {}
    for t in sorted(frames):
        if not (t_lo <= t < t_hi):
            continue
        if any(not (t + ACTION_S < a or t - LAG_S > b) for a, b in pauses):
            continue
        snaps = frames[t]
        alive = [s for s in snaps if s.get('hp_pct', 0) > 0]   # drop corpse frames
        for actor in alive:
            for victim in alive:
                if victim['team'] == actor['team']:
                    continue
                if victim['hp_pct'] > VICTIM_HP:
                    continue
                if dist(actor, victim) > VICTIM_RANGE:
                    continue
                if not any(a is not actor and a['team'] == actor['team']
                           and dist(actor, a) <= ALLY_RANGE for a in alive):
                    continue
                key = (actor['hero'], actor['idx'], victim['hero'], victim['idx'])
                if key in last and t - last[key] < DEDUP_S:
                    continue
                last[key] = t
                killed = any(t - LAG_S < d <= t + CONVERT_S for d in deaths[victim['hero']])
                hits = [(ht, ish) for ht, ish, _ in dmg[actor['hero']]
                        if t - LAG_S < ht <= t + ACTION_S]
                yield {
                    't': t,
                    'actor': actor['hero'], 'victim': victim['hero'],
                    'actor_team': actor['team'],
                    'armed': actor['team'] == g['armed_team'],
                    'pos': pos.get(actor['hero'], 0),
                    'actor_hp': actor['hp_pct'], 'victim_hp': victim['hp_pct'],
                    'edist': round(dist(actor, victim)),
                    'killed': killed,
                    'hit_hero': any(ish for _, ish in hits),
                    'hit_creep': any(not ish for _, ish in hits),
                    'no_dmg': not hits,
                }


def pct(n, d):
    return f'{100.0*n/d:5.1f}% ({n}/{d})' if d else '   n/a'


def main():
    dirs = sys.argv[1:]
    if not dirs:
        print(__doc__)
        return 1
    buckets = {'in': collections.defaultdict(list), 'out': collections.defaultdict(list)}
    games = 0
    for d in dirs:
        for tl in sorted(glob.glob(os.path.join(d, 'timelines', '*.timeline.json'))):
            name = os.path.basename(tl).replace('.timeline.json', '')
            aj = os.path.join(d, 'analysis', name + '.analysis.json')
            if not os.path.exists(aj):
                continue
            g = load_game(tl, aj)
            if g is None:
                continue
            games += 1
            for win, (lo, hi) in (('in', (0.0, LANING_END)),
                                  ('out', (OUT_START, OUT_END))):
                for ep in scan(g, lo, hi):
                    ep['game'] = name
                    buckets[win]['armed' if ep['armed'] else 'base'].append(ep)

    print(f'games scanned: {games}\n')
    for win, label in (('in', f'IN-DOMAIN  (laning, t<{LANING_END:.0f}s)'),
                       ('out', f'OUT-DOMAIN (t {OUT_START:.0f}-{OUT_END:.0f}s, helpers return nil)')):
        print(f'== {label} ==')
        print(f'{"":18} {"armed":>18} {"baseline":>18}')
        a, b = buckets[win]['armed'], buckets[win]['base']
        rows = [
            ('episodes', len(a), len(b)),
            ('killed<=6s', sum(x['killed'] for x in a), sum(x['killed'] for x in b)),
            ('hit the hero<=4s', sum(x['hit_hero'] for x in a), sum(x['hit_hero'] for x in b)),
            ('CREEP-ONLY<=4s', sum(x['hit_creep'] and not x['hit_hero'] for x in a),
                               sum(x['hit_creep'] and not x['hit_hero'] for x in b)),
            ('no damage<=4s', sum(x['no_dmg'] for x in a), sum(x['no_dmg'] for x in b)),
        ]
        na, nb = len(a), len(b)
        for lab, va, vb in rows:
            if lab == 'episodes':
                print(f'{lab:18} {va:>18} {vb:>18}')
            else:
                print(f'{lab:18} {pct(va, na):>18} {pct(vb, nb):>18}')
        print()
    # dump episodes for frame-level follow-up
    with open('/tmp/roam_episodes.jsonl', 'w') as fh:
        for win in buckets:
            for side in buckets[win]:
                for ep in buckets[win][side]:
                    ep['window'] = win
                    fh.write(json.dumps(ep) + '\n')
    print('episodes -> /tmp/roam_episodes.jsonl')
    return 0


if __name__ == '__main__':
    sys.exit(main())
