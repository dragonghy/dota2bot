#!/usr/bin/env python3
"""zusult_reserve_cross.py -- the frames `X.zuus_ShouldSaveManaForUlt` cannot see.

Companion to `zusult_gate.py` (which counts the casts the gate SHOULD have
suppressed inside its own domain). This one counts the casts that carry Zeus
ACROSS the reserve line -- from mana >= Thundergod's Wrath cost down to below
it -- while the ult is trained and off cooldown.

Why they matter (GH #59): the gate's clause order is

    if hBot:GetMana() >= nCost then return false end   -- clause 7
    if J.IsRetreating( hBot ) then return false end    -- clause 8
    ...
    if J.GetHP( hTarget ) < 0.6 then return false end

Clause 7 is evaluated on the mana Zeus holds BEFORE the spend, so the gate's
effective domain is exactly "the reserve is already gone". It can never stand
between Zeus and the spend that loses the reserve; it only protects the regen
that follows. A crossing onto a HEALTHY hero is therefore a leak by the gate's
own stated purpose ("the reserve is only worth defending against CHIP") that
the gate is structurally blind to.

Two properties make this measurement unusually clean for a soak candidate:

  * it does NOT depend on `J.IsRetreating` -- clause 7 precedes clause 8, so
    mana >= cost returns false no matter what mode the bot is in. The
    structural blind spot that limits GH #47's evidence does not apply here.
  * it does not depend on which ConsiderW2 branch fired: a nil target leaves
    the gate inert, a hero target hits clause 7. Both let the cast through.

Usage:
  zusult_reserve_cross.py <timeline.json>=ARMED <timeline.json>=BASE ...

Boundaries (quote them with the number):
  * 1 Hz snapshots: "mana before" is the last snapshot at or before the cast
    and "mana after" the first one past it, so any other spend or regen inside
    that <=1s window rides along. Cross-check a headline frame by hand
    (frame_replay.py / zeus-style per-second dump) before citing it -- e.g. an
    R cast in the same second shows up here as a crossing too.
  * target health uses the charter's 1 Hz rule: HEALTHY only when EVERY
    snapshot within +-1.5s of the cast is >= 0.60, so a target that the cast
    itself knocks under the kill-window floor is not counted as healthy.
  * R mana cost is the level table below, measured off real ult frames
    (level 1 = 225: mp 848->652 across a cast instant plus ~1s of regen).
  * dead frames (hp_pct <= 0) are excluded from the target-health lookup.
  * post-game freeze (issue #43): samples past the last real event are dropped.

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.
"""
import collections
import json
import math
import sys

RCOST = {1: 225, 2: 375, 3: 525}
HEALTHY = 0.60
SPELLS = ('zuus_arc_lightning', 'zuus_lightning_bolt')
Z = 'npc_dota_hero_zuus'


def load(path):
    d = json.load(open(path))
    tmax = max(e['t'] for e in d['events'])          # issue #43
    d['snapshots'] = [s for s in d['snapshots'] if s['t'] <= tmax]
    return d


def analyse(path):
    d = load(path)
    snaps = collections.defaultdict(list)
    for s in d['snapshots']:
        snaps[s['hero']].append(s)
    for k in snaps:
        snaps[k].sort(key=lambda s: s['t'])
    zs = snaps.get(Z)
    if not zs:
        return None
    evs = sorted(d['events'], key=lambda e: e['t'])
    rows = []
    for e in evs:
        if e['type'] != 'ABILITY' or e.get('actor') != Z:
            continue
        inf = e.get('inflictor')
        if inf not in SPELLS:
            continue
        before = [s for s in zs if s['t'] <= e['t']]
        after = [s for s in zs if s['t'] > e['t']]
        if not before or not after:
            continue
        pre, post = before[-1], after[0]
        ab = {a['name']: a for a in pre['abilities']}
        r = ab.get('zuus_thundergods_wrath', {'level': 0, 'cd': 0})
        if r['level'] < 1 or r['cd'] > 0:
            continue
        cost = RCOST.get(r['level'], 225)
        if not (pre['mp'] >= cost and post['mp'] < cost):
            continue                                   # not a crossing
        raw = str(e.get('target', ''))
        ground = not raw.startswith('npc_dota_hero_')
        tgt = None if ground else raw
        if tgt is None:                                # resolve a ground cast
            hits = [x for x in evs
                    if abs(x['t'] - e['t']) <= 0.25 and x['type'] == 'DAMAGE'
                    and x.get('inflictor') == inf and x.get('target_hero')]
            tgt = hits[0]['target'] if hits else None
        if tgt is None:
            continue
        near = [x for x in snaps.get(tgt, [])
                if abs(x['t'] - e['t']) <= 1.5 and x['hp_pct'] > 0]
        if not near:
            continue
        hp = min(x['hp_pct'] for x in near)
        same = [x for x in snaps.get(tgt, []) if abs(x['t'] - pre['t']) < 0.6]
        dist = int(math.hypot(same[0]['x'] - pre['x'], same[0]['y'] - pre['y'])) if same else None
        rows.append(dict(t=e['t'], spell=inf, ground=ground, tgt=tgt, hp=hp,
                         dist=dist, mp_pre=pre['mp'], mp_post=post['mp'], cost=cost))
    return rows


def main(argv):
    tot = collections.Counter()
    for arg in argv:
        path, tag = arg.split('=')
        rows = analyse(path)
        print(f"\n### {tag} {path.split('/')[-1]}")
        if rows is None:
            print("  no zuus in this game")
            continue
        for c in rows:
            flag = 'HEALTHY' if c['hp'] >= HEALTHY else 'killwindow(exempt)'
            print(f"  t={c['t']:7.1f} {c['spell'].replace('zuus_',''):15s} "
                  f"{'GROUND' if c['ground'] else 'TARGET':6s} -> "
                  f"{c['tgt'].replace('npc_dota_hero_',''):15s} "
                  f"tgt_hp_min={c['hp']:.2f} d={c['dist']} "
                  f"mp {c['mp_pre']:.0f}->{c['mp_post']:.0f} (Rcost {c['cost']}) {flag}")
            tot[tag + '_all'] += 1
            if c['hp'] >= HEALTHY:
                tot[tag + '_healthy'] += 1
        tot[tag + '_games'] += 1
        print(f"  crossings: {len(rows)} total, "
              f"{sum(1 for c in rows if c['hp'] >= HEALTHY)} onto a healthy hero")

    print("\n=== totals ===")
    for tag in sorted({k.rsplit('_', 1)[0] for k in tot}):
        g = tot[tag + '_games']
        print(f"{tag:6s} games={g} crossings={tot[tag + '_all']} "
              f"onto_healthy={tot[tag + '_healthy']}"
              + (f"  ({tot[tag + '_healthy'] / g:.2f}/game)" if g else ""))


if __name__ == '__main__':
    main(sys.argv[1:])
