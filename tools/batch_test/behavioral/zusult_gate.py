#!/usr/bin/env python3
"""zusult (a)-evidence scanner: did the "save mana for the ult" gate actually fire?

Gate under test -- `X.zuus_ShouldSaveManaForUlt` (bots/BotLib/hero_zuus.lua):
suppress an Arc Lightning (Q) / Lightning Bolt (W) cast when Thundergod's Wrath
is trained, off cooldown, unaffordable, and the target is a hero still above
`nUltSaveHealthFloor` (0.60) -- unless the bot is retreating.

Everything in that predicate is readable from a behav-dump timeline EXCEPT
`J.IsRetreating` (bot mode is a script-side concept and is not networked into
the .dem at all -- structural, not a dumper gap). It is proxied here by
"zeus hp >= HPFLOOR and no enemy-hero damage on zeus in the last RECENT
seconds"; in-domain casts are therefore an UPPER BOUND on real gate misses.

The discriminating output is the SPELL SPLIT of the in-domain casts, not their
count: one and the same gate call guards Q (SkillsComplement L~294) and W
(L~263), so if in-domain Q casts vanish on the armed side while in-domain W
casts survive, the leak is downstream of the gate -- i.e. `ConsiderW2`, the
ungated second caster of the same ability handle.

R mana cost: level-1 = 225 measured directly off this wave's ults (mp 603->387
and 332->99 across the cast instant, +~7 regen/s).

Usage:
  zusult_gate.py <timeline.json>=1 <timeline.json>=0 ...   # 1 = zeus side armed
"""
import json, sys, math, collections

RCOST = {1: 225, 2: 375, 3: 525}
HEALTHY = 0.60
HPFLOOR = 0.55
RECENT = 3.0

def load(p):
    d = json.load(open(p))
    tmax = max(e['t'] for e in d['events'])
    d['snapshots'] = [s for s in d['snapshots'] if s['t'] <= tmax]
    return d

def analyze(path):
    d = load(path)
    team = d['game']['teams']['npc_dota_hero_zuus']
    snaps = collections.defaultdict(list)
    for s in d['snapshots']: snaps[s['hero']].append(s)
    for k in snaps: snaps[k].sort(key=lambda s: s['t'])
    zs = snaps['npc_dota_hero_zuus']
    evs = sorted(d['events'], key=lambda e: e['t'])
    hurt = [e['t'] for e in evs if e['type'] == 'DAMAGE' and e.get('target') == 'npc_dota_hero_zuus'
            and e.get('actor_hero')]

    def snap_at(hero, t, side='prev'):
        arr = snaps.get(hero, [])
        prev = [s for s in arr if s['t'] <= t]
        nxt = [s for s in arr if s['t'] > t]
        return (prev[-1] if prev else None), (nxt[0] if nxt else None)

    def healthy(hero, t):
        a, b = snap_at(hero, t)
        vals = [s['hp_pct'] for s in (a, b) if s and abs(s['t'] - t) <= 1.5]
        return bool(vals) and min(vals) >= HEALTHY, (min(vals) if vals else None)

    def calm(t, zs_snap):
        return zs_snap['hp_pct'] >= HPFLOOR and not any(t - RECENT <= h <= t for h in hurt)

    # gate state timeline
    gate = []
    for s in zs:
        ab = {a['name']: a for a in s['abilities']}
        r = ab.get('zuus_thundergods_wrath', {'level': 0, 'cd': 0})
        ready = r['level'] >= 1 and r['cd'] == 0
        unaff = ready and s['mp'] < RCOST.get(r['level'], 225)
        gate.append(dict(t=s['t'], ready=ready, unaff=unaff, s=s, rlvl=r['level']))

    def gate_at(t):
        g = [x for x in gate if x['t'] <= t]
        return g[-1] if g else None

    # clean opportunity frames
    opp = 0
    for g in gate:
        if not g['unaff'] or g['s']['hp_pct'] <= 0: continue
        if not calm(g['t'], g['s']): continue
        me = g['s']
        near = []
        for h, arr in snaps.items():
            if h == 'npc_dota_hero_zuus': continue
            cand = [x for x in arr if abs(x['t'] - g['t']) < 0.6]
            for o in cand:
                if o['team'] == team or o['hp_pct'] < HEALTHY: continue
                if math.hypot(o['x'] - me['x'], o['y'] - me['y']) <= 900: near.append(h)
        if near: opp += 1

    # casts
    rows = []
    for e in evs:
        if e['type'] != 'ABILITY' or e.get('actor') != 'npc_dota_hero_zuus': continue
        inf = e.get('inflictor')
        if inf not in ('zuus_arc_lightning', 'zuus_lightning_bolt'): continue
        tgt = e.get('target') if str(e.get('target', '')).startswith('npc_dota_hero_') else None
        if not tgt:
            hits = [x for x in evs if abs(x['t'] - e['t']) <= 0.2 and x['type'] == 'DAMAGE'
                    and x.get('inflictor') == inf and x.get('target_hero')]
            tgt = hits[0]['target'] if hits else None
        g = gate_at(e['t'])
        if not g or not tgt: continue
        hh, hv = healthy(tgt, e['t'])
        rows.append(dict(t=e['t'], spell=inf, tgt=tgt, hp=hv, unaff=g['unaff'],
                         mp=g['s']['mp'], rlvl=g['rlvl'], zhp=g['s']['hp_pct'],
                         calm=calm(e['t'], g['s']), healthy=hh))
    dom = [r for r in rows if r['unaff'] and r['healthy'] and r['calm']]
    return dict(opp=opp, rows=rows, dom=dom,
                unaff_frames=sum(1 for g in gate if g['unaff']))

if __name__ == '__main__':
    tot = collections.Counter()
    for a in sys.argv[1:]:
        path, armed = a.split('='); armed = armed == '1'
        r = analyze(path)
        tag = 'ARMED ' if armed else 'BASE  '
        print(f"\n=== {tag} {path.split('/')[-1]} ===")
        print(f"  R-ready&unaffordable frames {r['unaff_frames']} | clean opportunity frames {r['opp']} "
              f"| Q/W casts w/ hero target {len(r['rows'])} | IN-DOMAIN (should be suppressed) {len(r['dom'])}")
        for c in r['dom']:
            print(f"    t={c['t']:7.1f} {c['spell']:20s} -> {c['tgt'].replace('npc_dota_hero_',''):16s} "
                  f"tgt_hp={c['hp']:.2f} zeus_hp={c['zhp']:.2f} mp={c['mp']} Rlvl={c['rlvl']}")
        k = 'armed' if armed else 'base'
        tot[k + '_opp'] += r['opp']; tot[k + '_dom'] += len(r['dom'])
        tot[k + '_casts'] += len(r['rows']); tot[k + '_games'] += 1
    print("\n=== totals ===")
    for k in ('armed', 'base'):
        o, dm, c, g = tot[k+'_opp'], tot[k+'_dom'], tot[k+'_casts'], tot[k+'_games']
        print(f"{k:6s} games={g} clean_opp_frames={o} in_domain_casts={dm} "
              f"({dm/o*100 if o else 0:.1f} per 100 opp frames) allcasts={c}")
