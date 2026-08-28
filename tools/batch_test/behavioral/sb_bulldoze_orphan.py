#!/usr/bin/env python3
"""The behavioural signature of a nil charge target (hero_spirit_breaker.lua:309).

X.SkillsComplement:114-126 is the only place Charge is dispatched:

    ChargeOfDarknessDesire, ChargeOfDarknessTarget = X.ConsiderChargeOfDarkness()
    if ChargeOfDarknessDesire > 0
    then
        if ChargeOfDarkness:GetLevel() >= 3 and Bulldoze:IsTrained()
        and Bulldoze:IsFullyCastable()
        then
            bot:Action_UseAbility(Bulldoze)          -- (1) PRELUDE
        end
        bot:Action_UseAbilityOnEntity(ChargeOfDarkness, ChargeOfDarknessTarget)
        return                                       -- (2) suppresses the rest
    end

So a Bulldoze cast fired as the PRELUDE is always immediately followed by a
charge attempt.  If the attempt carries a nil target it produces no charge
event -- leaving an ORPHAN Bulldoze: Bulldoze cast, charge off cooldown and
level >= 3, and no charge in the window that follows.

WHAT THIS IS AND IS NOT.  Bulldoze is also cast on its own account by
X.ConsiderBulldoze() further down the same function, so an orphan is not by
itself proof of a nil target -- it is the observable NECESSARY consequence.
The reading that matters is the CONTRAST: paired Bulldozes are charges that
found a target, orphans are charge decisions that produced no charge.  Both
legs of that contrast come from the same hero in the same games, so map and
draft are controlled by construction.

Charge cooldown is read at the last snapshot at or before the Bulldoze, i.e.
BEFORE the cast -- never off a cooldown rising edge (charter tool trap: the
rising edge is the frame AFTER the cast).

########################################################################
# LIMITS -- READ BEFORE QUOTING THIS SCRIPT.  MEASURED NON-DISCRIMINATING.
#
# replay-check 2026-08-28T18:5xZ ran this on W22 seed 975 (6 games) and got
# 5 ORPHAN vs 1 PAIRED.  That reading was DISCARDED, not reported as
# evidence, and GH #283 does not rest on it.  Reason: X.ConsiderBulldoze()
# casts Bulldoze on its own account further down the same function, and
# nothing in the frame table says which caller a given cast came from.  A
# plain ConsiderBulldoze cast is indistinguishable from a nil-target prelude
# here, so a high orphan rate is the EXPECTED reading either way.
#
# This file is kept so the dead end is not re-walked, not because the number
# means something.  To make it discriminating you would need a caller-side
# observable this dumper does not emit.
########################################################################
"""
import json, glob, os, sys, collections

SB = 'npc_dota_hero_spirit_breaker'
CHARGE = 'spirit_breaker_charge_of_darkness'
BULL = 'spirit_breaker_bulldoze'
WINDOW = 2.0


def real_stream(d, name):
    by = collections.defaultdict(list)
    for s in d['snapshots']:
        if s['hero'] == name:
            by[s['idx']].append(s)
    for k, fr in by.items():
        fr.sort(key=lambda s: s['t'])
        if fr[0]['t'] < 0:
            return fr
    return None


def before(fr, t):
    p = None
    for s in fr:
        if s['t'] > t:
            break
        p = s
    return p


def abil(s, name):
    for a in s['abilities']:
        if a['name'] == name:
            return a
    return None


def main(paths):
    tot = collections.Counter()
    rows = []
    for p in sorted(paths):
        d = json.load(open(p))
        g = os.path.basename(p).split('.')[0]
        fr = real_stream(d, SB)
        if fr is None:
            continue
        ev = [e for e in d['events'] if e['type'] == 'ABILITY'
              and (e.get('actor') or '') == SB]
        bulls = [e['t'] for e in ev if e.get('inflictor') == BULL]
        chgs = sorted(e['t'] for e in ev if e.get('inflictor') == CHARGE)
        for bt in bulls:
            s = before(fr, bt)
            if s is None:
                continue
            c = abil(s, CHARGE)
            if c is None or c['level'] < 3 or c['cd'] > 0:
                tot['not-a-prelude-candidate'] += 1
                continue
            paired = any(bt <= ct <= bt + WINDOW for ct in chgs)
            if paired:
                tot['PAIRED (charge followed)'] += 1
            else:
                tot['ORPHAN (no charge followed)'] += 1
                rows.append((g[9:], bt, c['level'], c['cd'],
                             s['x'], s['y'], s['hp_pct']))
    n = tot['PAIRED (charge followed)'] + tot['ORPHAN (no charge followed)']
    print('== spirit_breaker Bulldoze casts with charge castable (level>=3, cd==0) ==')
    for k in ('PAIRED (charge followed)', 'ORPHAN (no charge followed)'):
        print('   %-28s %3d  (%s)' % (k, tot[k],
              ('%.1f%%' % (100.0 * tot[k] / n)) if n else 'n/a'))
    print('   %-28s %3d  (charge not level>=3 or on cooldown -- not a prelude)'
          % ('excluded', tot['not-a-prelude-candidate']))
    print()
    for r in rows[:20]:
        print('   ORPHAN %s t=%.1f  charge lvl=%d cd=%.1f  SB=(%.0f,%.0f) hp=%.2f'
              % r)


if __name__ == '__main__':
    main(sys.argv[1:] or glob.glob('timelines/*.json'))
