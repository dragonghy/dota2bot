#!/usr/bin/env python3
"""Frame-by-frame reconstruction of one decision instant from a dumper timeline.

    frame_replay.py <timeline.json> --actor <hero> --t <sec> [--victim <hero>]
                    [--pre 3] [--post 9]

Prints, one line per 1Hz snapshot: the actor's HP/MP/position, the victim's
HP/position, their separation, and EVERY event the actor authored in that
second (DAMAGE with its target, ABILITY, ITEM), plus how many enemy creeps sit
within 400u of the actor -- the stale-handle defect's tell is "actor damages a
creep while a low-HP hero stands in range".

Entity identity is by (hero class name, idx): the dumper emits one snapshot row
per entity and illusions share their owner's class name, so tracking a hero
without pinning idx interleaves several trajectories into one fake track.
"""
import argparse, json, math, collections

def canon(n):
    return (n or '').replace('npc_dota_hero_', '').replace('_', '')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('timeline'); ap.add_argument('--actor', required=True)
    ap.add_argument('--t', type=float, required=True); ap.add_argument('--victim')
    ap.add_argument('--pre', type=float, default=3.0); ap.add_argument('--post', type=float, default=9.0)
    a = ap.parse_args()
    tl = json.load(open(a.timeline))
    lo, hi = a.t - a.pre, a.t + a.post

    # pin idx: the entity of that class closest in time to t with the most rows
    cand = collections.Counter(s['idx'] for s in tl['snapshots']
                               if canon(s['hero']) == canon(a.actor) and lo - 5 <= s['t'] <= hi + 5)
    if not cand:
        print('no snapshots for actor'); return 1
    aidx = cand.most_common(1)[0][0]
    vidx = None
    if a.victim:
        vc = collections.Counter(s['idx'] for s in tl['snapshots']
                                 if canon(s['hero']) == canon(a.victim) and lo - 5 <= s['t'] <= hi + 5)
        vidx = vc.most_common(1)[0][0] if vc else None
    if len(cand) > 1:
        print(f'# NOTE: {len(cand)} entities share class {canon(a.actor)} (illusions?); pinned idx={aidx}')

    snaps = collections.defaultdict(dict)
    for s in tl['snapshots']:
        if lo <= s['t'] <= hi and s['idx'] in (aidx, vidx):
            snaps[round(s['t'], 1)]['a' if s['idx'] == aidx else 'v'] = s
    creeps = collections.defaultdict(list)
    for c in tl['creeps']:
        if lo <= c['t'] <= hi:
            creeps[round(c['t'], 1)].append(c)
    ev = collections.defaultdict(list)
    for e in tl['events']:
        if lo <= e['t'] <= hi and canon(e.get('actor')) == canon(a.actor):
            ev[math.floor(e['t'])].append(e)

    print(f"{'t':>7} {'actorHP':>8} {'mp':>5} {'actor xy':>16} {'vicHP':>6} {'victim xy':>16} {'dist':>6} {'cr<400':>6}  events")
    for t in sorted(snaps):
        s = snaps[t].get('a'); v = snaps[t].get('v')
        if not s: continue
        d = f"{math.hypot(s['x']-v['x'], s['y']-v['y']):.0f}" if v else '-'
        ncr = sum(1 for c in creeps.get(t, []) if c['team'] != s['team']
                  and math.hypot(c['x']-s['x'], c['y']-s['y']) < 400)
        acts = []
        for e in ev.get(math.floor(t), []):
            tgt = canon(e.get('target')) or (e.get('target') or '?')
            if e['type'] == 'DAMAGE':
                acts.append(f"DMG {e.get('value')}->{tgt or 'creep/unit'}")
            elif e['type'] in ('ABILITY', 'ITEM'):
                acts.append(f"{e['type']} {e.get('inflictor') or e.get('value')}")
        print(f"{t:7.1f} {s['hp_pct']:8.2f} {s.get('mp_pct',0):5.2f} "
              f"{s['x']:7.0f},{s['y']:8.0f} {(v['hp_pct'] if v else 0):6.2f} "
              f"{(v['x'] if v else 0):7.0f},{(v['y'] if v else 0):8.0f} {d:>6} {ncr:>6}  "
              + '; '.join(acts))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
