#!/usr/bin/env python3
"""Did `odaoe` actually fire?  The geometric discriminator, on real frames.

WHY A DISCRIMINATOR AND NOT A COUNTER.  od_eclipse_aoe_domain.py answers the
COUNTERFACTUAL question ("on how many frames WOULD the armed branch fire"),
which is the same number on both legs because it is computed from geometry, not
from the gate.  It cannot tell a WORKING id from a SILENT one.  This script
answers the executed question instead, and it can, because the two code paths
put the circle in provably different places:

  shipped (hero_obsidian_destroyer.lua:479)  `return ..., enemyHero:GetLocation()`
      -- the 500-radius disk is ALWAYS centred on some enemy's own position,
         and that enemy is inside the 700 cast range.
  armed  (X.od_GetEclipseAoeLocation, :575)  candidate set = every hittable
      enemy's position PLUS every pairwise MIDPOINT
      -- so it can place the disk where no enemy stands.

=> a multi-hero cast whose hit set fits NO enemy-centred disk is a cast the
shipped path could not have produced.  That is a proof from the source, not a
threshold, which is what makes a small baseline leg tolerable.

READING RULES BAKED IN
  * cast instants come from the ability's own DAMAGE events, never from a
    cooldown rising edge (charter tool trap: `prev_cd==0 and cd>0` is the frame
    AFTER the cast, and at 400+ u/s one frame is +-420u).
  * positions are read at the LAST FRAME BEFORE the cast.
  * entity streams are keyed (hero, idx) and only streams sampled before the
    horn (t < 0) are kept -- illusions share the hero name and player_id and
    would otherwise forge enemy positions (GH #176).
  * SLACK absorbs up to 1.5s of movement between that frame and the damage.
  * the enemy-centred test tries EVERY LIVING ENEMY as the centre, not only the
    ones that took damage: Sanity's Eclipse deals (OD mana - target mana) * 0.4,
    so an enemy with mana >= OD's stands inside the circle and emits no DAMAGE
    event at all.  Conservative on purpose -- it can only UNDER-report.

usage:  od_eclipse_offcentre.py <label> <timeline.json ...>
first measured: replay-check 2026-08-28T09:52Z on W20 seed 947 (GH #276 round).
"""

import json, gzip, glob, os, sys, collections, math
ABIL='obsidian_destroyer_sanity_eclipse'; OD='npc_dota_hero_obsidian_destroyer'
CAST_RANGE, RADIUS, SLACK = 700.0, 500.0, 60.0   # SLACK: <=1.5s of travel between frame and damage

def load(p):
    o=gzip.open(p,'rt') if p.endswith('.gz') else open(p); return json.load(o)
def streams(d):
    by=collections.defaultdict(list)
    for s in d['snapshots']: by[(s['hero'],s['idx'])].append(s)
    out={}
    for k,fr in by.items():
        fr.sort(key=lambda s:s['t'])
        if fr[0]['t']<0: out[k]=fr
    return out
def before(fr,t):
    p=None
    for s in fr:
        if s['t']>t: break
        p=s
    return p
def dist(a,b): return math.hypot(a[0]-b[0],a[1]-b[1])

def analyse(paths,label):
    tot=collections.Counter(); rows=[]
    for path in sorted(paths):
        d=load(path); st=streams(d); g=os.path.basename(path).split('.')[0]
        odk=[k for k in st if k[0]==OD]
        if not odk: continue
        dmg=[e for e in d['events'] if e['type'] in ('DAMAGE','CRITICAL_DAMAGE')
             and ABIL in (e.get('inflictor') or '') and e.get('target_hero')]
        dmg.sort(key=lambda e:e['t'])
        cs=[]; cur=None
        for e in dmg:
            if cur is None or e['t']-cur['t0']>1.5:
                cur={'t0':e['t'],'tg':collections.Counter()}; cs.append(cur)
            cur['tg'][e['target']]+=e.get('value',0)
        for c in cs:
            if len(c['tg'])<2: continue
            odf=before(st[odk[0]],c['t0'])
            if odf is None: continue
            odp=(odf['x'],odf['y']); pts=[]; allen=[]
            for (h,idx),fr in st.items():
                s=before(fr,c['t0'])
                if s is None or s['team']==odf['team']: continue
                if s['hp_pct']>0: allen.append((s['x'],s['y']))
                if h in c['tg']: pts.append((s['x'],s['y']))
            if len(pts)<2: continue
            # CONSERVATIVE: the shipped exit returns enemyHero:GetLocation(), so
            # try EVERY living enemy as the centre -- not only the hit ones (an
            # enemy whose mana >= OD's takes 0 and emits no DAMAGE event).
            on_enemy=any(dist(p,odp)<=CAST_RANGE+SLACK and
                         all(dist(p,q)<=RADIUS+SLACK for q in pts) for p in allen)
            mids=[((p[0]+q[0])/2,(p[1]+q[1])/2) for i,p in enumerate(pts) for q in pts[i+1:]]
            off=any(dist(c2,odp)<=CAST_RANGE+SLACK and
                    all(dist(c2,q)<=RADIUS+SLACK for q in pts) for c2 in pts+mids)
            key='shipped-explainable' if on_enemy else ('OFF-CENTRE ONLY' if off else 'neither')
            tot[key]+=1
            if not on_enemy and off:
                far=max(dist(p,odp) for p in pts)
                rows.append((g,c['t0'],len(c['tg']),far,
                             ','.join(h.replace('npc_dota_hero_','') for h in c['tg'])))
    n=sum(tot.values())
    print('== %s: %d multi-hero eclipse casts' % (label,n))
    for k in ('shipped-explainable','OFF-CENTRE ONLY','neither'):
        if n: print('   %-20s %3d  (%.1f%%)' % (k,tot[k],100.0*tot[k]/n))
    for r in rows[:12]:
        print('     off-centre: %s t=%.1f n=%d farthest_hit_from_OD=%.0f  %s' % r)
    return tot

if __name__=='__main__':
    analyse(sys.argv[2:], sys.argv[1])
