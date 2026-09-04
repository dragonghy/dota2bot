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
# First hero level at which any talent can be trained. Below it,
# `talent7:IsTrained()` in ConsiderW is necessarily false -- see consumer().
TALENT_LEVEL = 10

# Items that hand Zeus mana. The gate's FIRST clause is
# `if hBot:GetMana() >= nCost then return false end`, and it reads the mana the
# bot holds at the DECISION instant -- but the only mana this scanner can see is
# the last snapshot at or before the cast, up to 1 s earlier. One of these fired
# inside that gap moves the input of clause 7 between the sample and the
# decision, so a frame the bot saw as AFFORDABLE (gate correctly silent) is
# recorded as unaffordable, i.e. in-domain. The error therefore MANUFACTURES
# LEAKS; it never hides one.
#
# It is not a rare tail, and the reason is structural: the selector
# (`mp < R cost`) and the contaminant (a bot drinks/blinks its mana back exactly
# when it is low) are the SAME condition, so the contamination concentrates in
# the reported set. Measured on the W46 Zeus corpus (38 games, 4190 Q/W casts):
# 3.4% of all casts, but 1 of the 2 in-domain W flags -- 50% -- and that one was
# the single armed-leg flag the round was about to escalate as a `zusboltdom`
# leak (Arcane Boots, +175, at t=394.5; the bolt at t=395.1; the bot held 337
# against an R cost of 225 and was right to fire).
#
# Same family as the two traps already in the replay-check charter -- the
# cooldown RISING-EDGE cast-frame bug and the illusion name-keying bug -- and
# the same shape: a sub-frame event moves a predicate's input between the sample
# and the decision. Like the missing-ability guard below, these frames are NOT
# silently dropped into the negative bucket; they are carried as their own state
# and reported, so a stale reading can never be mistaken for a clean one.
MANA_RESTORE_ITEMS = frozenset((
    'item_arcane_boots', 'item_magic_wand', 'item_magic_stick', 'item_bottle',
    'item_enchanted_mango', 'item_soul_ring', 'item_holy_locket', 'item_clarity',
))

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
    mana_items = [e['t'] for e in evs if e['type'] == 'ITEM'
                  and e.get('actor') == 'npc_dota_hero_zuus'
                  and e.get('inflictor') in MANA_RESTORE_ITEMS]

    def stale_mana(t):
        """Did Zeus refill mana between the snapshot this row was read from and
        the cast? See MANA_RESTORE_ITEMS: if so, the `unaff` flag on this row
        was computed from mana the bot no longer held when it decided."""
        prev = [s for s in zs if s['t'] <= t]
        if not prev:
            return False
        return any(prev[-1]['t'] <= it <= t for it in mana_items)

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

    def consumer(ev, zlvl):
        """WHICH of W's two consumers issued this bolt -- the question an
        in-domain COUNT cannot answer, and the one that decides whether the
        cast is a gate miss at all.

        `bots/BotLib/hero_zuus.lua` dispatches W twice.  `ConsiderW` (:673)
        casts on the ENTITY (:687) unless `talent7:IsTrained()` (:685);
        `ConsiderW2` (:700) always casts on a LOCATION (:709).  Both call the
        same reserve gate, but ConsiderW2's channel-interrupt / retreat /
        (unless `zusboltdom` is armed) kill-AoE branches report NO target on
        purpose, and the gate is inert on a nil target -- so a bolt from those
        branches is the exemption WORKING AS WRITTEN, not a leak past the gate.

        Talents are learnable only from hero level 10, so below that
        `talent7:IsTrained()` is necessarily false and a POINT cast cannot have
        come from ConsiderW.  That makes the split exact on the frames that
        matter here; at level >= 10 a point cast is genuinely AMBIGUOUS between
        the two, and is reported as such rather than assigned.

        This does NOT narrow the domain and does not move a single existing
        reading -- `dom` is byte-identical with or without this function.  It
        adds the attribution WITHOUT which an in-domain count reads as a gate
        miss by default, which is the direction that flatters nobody: it
        manufactured the reading `zusult` armed 8.0 vs baseline 8.6 per 100
        opportunity frames on the W45 Zeus corpus (37 games), a "the gate does
        nothing" shape that dissolves once all 7 armed casts turn out to be
        ConsiderW2 point casts at hero level 7-9.
        """
        point = not str(ev.get('target', '')).startswith('npc_dota_hero_')
        if not point:
            return 'considerW'          # entity cast -- ConsiderW, gate was live
        if zlvl is not None and zlvl < TALENT_LEVEL:
            return 'considerW2'         # no talent possible -> ConsiderW excluded
        return 'ambiguous'

    # gate state timeline
    #
    # `snapshots[].abilities` is None on a large minority of frames (measured on
    # the W44 corpus: 10271 / 79735 Zeus frames = 12.9%, of which 735 are frames
    # where Zeus is ALIVE).  Reading it unguarded is what this scanner used to do
    # and it raised TypeError on the first such frame, i.e. the instrument could
    # not run at all on a current-dumper corpus.
    #
    # The guard is deliberately NOT a silent `or []`: with the ability list
    # missing, `ready` would evaluate False and the frame would be filed as
    # "ult not ready" -- indistinguishable from a real negative, and the
    # direction of that error flatters the armed leg (a suppressed-cast
    # violation on a missing-ability frame would silently leave the domain).
    # Missing frames are therefore carried as their own state (`have=False`) and
    # reported as UNKNOWN, never as in-domain and never as out-of-domain.
    gate = []
    for s in zs:
        raw = s.get('abilities')
        have = raw is not None
        ab = {a['name']: a for a in (raw or [])}
        r = ab.get('zuus_thundergods_wrath', {'level': 0, 'cd': 0})
        ready = have and r['level'] >= 1 and r['cd'] == 0
        unaff = ready and s['mp'] < RCOST.get(r['level'], 225)
        gate.append(dict(t=s['t'], ready=ready, unaff=unaff, s=s,
                         rlvl=r['level'], have=have))

    def gate_at(t):
        g = [x for x in gate if x['t'] <= t]
        return g[-1] if g else None

    def spent(t, spell):
        """Did Zeus HIMSELF pay for this spell at t?

        An `ABILITY` event naming `zuus_lightning_bolt` is NOT proof that Zeus
        cast it: Nimbus (`zuus_cloud`) strikes are logged under the same
        inflictor with Zeus as the actor, and they cost nothing and touch no
        cooldown.  Measured on the W44 corpus, 2 of the 5 armed-leg in-domain
        flags were exactly that -- one of them a `zuus_lightning_bolt` whose
        only damaged hero stood 8300 units away, i.e. an order of magnitude
        outside the bolt's own cast range.  40% of the flags were not casts.

        The discriminator is the ability's own cooldown across the instant:
        a real cast takes it from 0 to cd_len.  `pre_cd > 0` is decisive the
        other way -- the spell was already on cooldown, so this event cannot be
        a fresh cast of it.  When the cooldown is shorter than the 1 Hz
        snapshot spacing it can elapse unseen, so a mana drop is accepted as
        the fallback witness.
        """
        arr = [s for s in zs if s['t'] <= t]
        nxt = [s for s in zs if s['t'] > t]
        if not arr or not nxt: return None            # unknown, not "no"
        a, b = arr[-1], nxt[0]
        if b['t'] - a['t'] > 1.5: return None
        pa = {q['name']: q for q in (a.get('abilities') or [])}.get(spell)
        pb = {q['name']: q for q in (b.get('abilities') or [])}.get(spell)
        if pa is None or pb is None: return None
        if pa['cd'] > 0: return False                 # already on cooldown
        if pb['cd'] > 0: return True                  # 0 -> running = cast
        return (a['mp'] - b['mp']) >= 50              # cd elapsed inside the gap

    # clean opportunity frames
    opp = 0
    for g in gate:
        # Redundant today and deliberately kept: `ready` already carries
        # `have`, so a missing-ability frame cannot reach here with unaff set.
        # Mutating this line away leaves the test suite green (measured), which
        # is a statement about the line, not about the suite -- it is a
        # tripwire for the day `ready` stops depending on `have`.
        if not g['have']: continue
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
                         calm=calm(e['t'], g['s']), healthy=hh, have=g['have'],
                         stale=stale_mana(e['t']), zlvl=g['s'].get('level'),
                         consumer=(consumer(e, g['s'].get('level'))
                                   if inf == 'zuus_lightning_bolt' else 'considerQ'),
                         spent=spent(e['t'], inf)))
    flagged = [r for r in rows if r['have'] and r['unaff'] and r['healthy'] and r['calm']]
    # Order matters and is deliberate: the stale-mana split comes FIRST, because
    # a row whose `unaff` was read off pre-refill mana never belonged in the
    # domain at all -- filing it under "not a cast" instead would concede that
    # it WAS in-domain and merely unpaid.
    stale = [r for r in flagged if r['stale']]
    flagged = [r for r in flagged if not r['stale']]
    dom = [r for r in flagged if r['spent'] is not False]
    notcast = [r for r in flagged if r['spent'] is False]
    unknown = [r for r in rows if not r['have']]
    return dict(opp=opp, rows=rows, dom=dom, notcast=notcast, unknown=unknown,
                stale=stale,
                unaff_frames=sum(1 for g in gate if g['unaff']),
                noab_frames=sum(1 for g in gate if not g['have']),
                noab_alive_frames=sum(1 for g in gate
                                      if not g['have'] and g['s']['hp'] > 0))

if __name__ == '__main__':
    tot = collections.Counter()
    for a in sys.argv[1:]:
        path, armed = a.split('='); armed = armed == '1'
        r = analyze(path)
        tag = 'ARMED ' if armed else 'BASE  '
        print(f"\n=== {tag} {path.split('/')[-1]} ===")
        print(f"  R-ready&unaffordable frames {r['unaff_frames']} | clean opportunity frames {r['opp']} "
              f"| Q/W casts w/ hero target {len(r['rows'])} | IN-DOMAIN (should be suppressed) {len(r['dom'])}"
              f" | NOT-A-CAST (dropped) {len(r['notcast'])}"
              f" | STALE-MANA (dropped: refill inside the sample gap) {len(r['stale'])}"
              f" | UNKNOWN (gate frame had no ability list) {len(r['unknown'])}"
              f" | no-ability frames {r['noab_frames']} (alive {r['noab_alive_frames']})")
        for c in r['dom']:
            print(f"    t={c['t']:7.1f} {c['spell']:20s} -> {c['tgt'].replace('npc_dota_hero_',''):16s} "
                  f"tgt_hp={c['hp']:.2f} zeus_hp={c['zhp']:.2f} mp={c['mp']} Rlvl={c['rlvl']} "
                  f"paid={c['spent']} zlvl={c['zlvl']} via={c['consumer']}")
        for c in r['notcast']:
            print(f"    [dropped: not a cast] t={c['t']:7.1f} {c['spell']} -> "
                  f"{c['tgt'].replace('npc_dota_hero_','')}")
        k = 'armed' if armed else 'base'
        tot[k + '_opp'] += r['opp']; tot[k + '_dom'] += len(r['dom'])
        tot[k + '_casts'] += len(r['rows']); tot[k + '_games'] += 1
        tot[k + '_unknown'] += len(r['unknown']); tot[k + '_notcast'] += len(r['notcast'])
        tot[k + '_stale'] += len(r['stale'])
        for c in r['dom']:
            tot[k + '_via_' + c['consumer']] += 1
    print("\n=== totals ===")
    for k in ('armed', 'base'):
        o, dm, c, g = tot[k+'_opp'], tot[k+'_dom'], tot[k+'_casts'], tot[k+'_games']
        print(f"{k:6s} games={g} clean_opp_frames={o} in_domain_casts={dm} "
              f"({dm/o*100 if o else 0:.1f} per 100 opp frames) allcasts={c} "
              f"unknown_gate_frame_casts={tot[k+'_unknown']} "
              f"dropped_not_a_cast={tot[k+'_notcast']} "
              f"dropped_stale_mana={tot[k+'_stale']}")
        # The attribution split of the SAME in_domain_casts above -- not a
        # second domain. A count that is all `considerW2` is the nil-target
        # exemption working as written; only `considerW` (and, pending a frame,
        # `ambiguous`) can be a miss past a live gate.
        print(f"       in_domain via: considerW2={tot[k+'_via_considerW2']} "
              f"considerW={tot[k+'_via_considerW']} "
              f"ambiguous={tot[k+'_via_ambiguous']} "
              f"Q={tot[k+'_via_considerQ']}")
