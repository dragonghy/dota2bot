#!/usr/bin/env python3
"""capmono ARM-INTERNAL HP-gradient re-read (test_set.md 2026-08-20T21:00Z, SS V.2).

WHY THIS EXISTS
  `capmono` (mode_team_roam_generic.lua:128) replaces the shipped cliff
  (`desire>0.9 -> 0.72`) with a real ceiling (`desire>0.72 -> 0.72`).  Its
  ACTIVE SET is therefore exactly `raw desire in (0.72, 0.9]`; everywhere else
  the two trees are byte-for-byte identical.  The director asked for a
  zero-spend arm-internal re-read that splits the already-paid 32-game corpus
  at the HP where the capped branches cross raw=0.9, hoping the high half is an
  arm-internal PLACEBO immune to the +-15pp cross-seed noise that sank the
  aggregate DiD (GH #72).

  IT IS NOT A PLACEBO.  See BAND MAP.  This tool reports the split anyway (it
  is what was pre-registered) but adds the bands the code actually implies.

BAND MAP (bots/mode_team_roam_generic.lua, verified 2026-08-20T22:5xZ)
  Bid formulas of the branches that reach CapForLanePush (L148):
    L235 helpCoreTargeted  Remap(HP,0,0.5,NONE,0.98)  = 1.96*HP
    L258 punish-dive       Remap(HP,0,0.5,NONE,0.98)  = 1.96*HP
    L272 punish-overchase  Remap(HP,0,0.5,NONE,0.98)  = 1.96*HP
    L245 helpAlly          Remap(HP,0,0.6,NONE,0.98)  = 1.633*HP
    L297/L312 l1trade/l5combo                          EXEMPT (bLaneKillCommit, GH #31)
    L370/L382 towerCreep   Remap(HP,0,0.4,NONE,0.9)   = 0.90 FLAT for HP>=0.4
    L780 CarryFindTarget   ... BOT_MODE_DESIRE_HIGH    = 0.75 FLAT for HP>=0.4
    L333 warlock upheaval  VERYHIGH+0.1               = 0.85 FLAT
  => within the 14:37Z clean domain HP in [0.42,0.50]:
    P  [ .. ,0.3673)  1.96 family raw<=0.72 AND helpAlly raw<=0.60 -> both OFF
    L  [0.3673,0.4409) 1.96 family ACTIVE, helpAlly OFF (raw<=0.72)
    M  [0.4409,0.4592] BOTH families ACTIVE
    H  (0.4592,0.50]  1.96 family OFF (raw>0.9, shipped caps it too),
                      helpAlly ACTIVE  <-- the "placebo" band is another
                                          branch's active set, not a placebo
  The 14:37Z clean domain floors HP at 0.42, so without --wide band L is only
  its top slice [0.42,0.4409) and band P is empty; --wide opens the code-implied
  full bands.  Both readings are printed with their true edges.
  and the three FLAT branches (0.90 / 0.85 / 0.75) are capmono-ACTIVE in every
  band including P, because the shipped cliff never fires on them (0.90 is not
  > 0.90).  The dumper cannot see which branch bid, so no band is clean.

WHAT TO CONCLUDE
  Per SS V.2 point 4 the asymmetry is pre-registered: a gradient in the
  predicted direction supports (a); an absent gradient is WEAK evidence and
  cannot exonerate.  Measured 2026-08-20 on the 16:09Z/18:08Z bisect
  (32 mirror games, 4 seeds, tree 11a8de33):
    armA gradient (L+M internal diff) - (H internal diff) = -4.6pp
    armB gradient, capmono OFF in BOTH bands (NULL CHANNEL) = +10.5pp
    per-seed armA gradient  +17.3 +3.5 -4.0 -10.9  mean +1.50  SD 12.1
    per-seed armB gradient   -7.1 -17.4 +37.8 -0.4 mean +3.22  SD 24.1
  => the gradient statistic's own noise floor (SD 24pp/seed, MDE ~ +-24pp at
  4 seeds) is WIDER than the aggregate channel it was meant to replace
  (GH #72: SD 15pp/seed, MDE ~ +-21pp).  It is a difference of two noisy
  differences: being arm-internal removes the seed effect but roughly doubles
  the sampling variance, and the second effect wins.
  DO NOT read a gradient of |x| < 24pp at 4 seeds as evidence either way.

THE DECISIVE SPLIT IS NOT HP -- IT IS ENEMY DISTANCE (added 2026-08-20T23:xxZ)
  Clamping raw to 0.72 changes a DECISION only if some other mode bids inside
  (0.72, raw].  capmono's own comment names that competitor: "loses to the
  promoted lanesurv retreat, 0.75".  `J.ShouldRetreatLaneBurst`
  (jmz_func.lua:4848) returns false unless a visible enemy is within 1100u.
  => within the clean domain (nearest enemy 850-1500u by construction):
       edist in [850,1100)  competitor CAN bid  -> capmono is decision-relevant
       edist in [1100,1500] competitor CANNOT bid -> the clamp provably changes
                                                    nothing observable
  and the second slice is 46% of the corpus.  Measured:
       decision-RELEVANT   armA -6.2pp   armB -2.1pp   -> DiD -4.1pp
       decision-IRRELEVANT armA -13.2pp  armB +13.2pp  -> DiD -26.4pp
  i.e. the whole of armA's -10.4pp active-band reading lives in the cell where
  capmono cannot have caused it.  This is a better placebo than the HP split
  because it is ORTHOGONAL to the gate's arithmetic.
  Caveats (superset, do not overclaim): the dumper sees enemies through fog
  (GH #27), so edist<1100 is a superset of "lanesurv sees one"; lanesurv also
  needs nIncoming>0 and no peel-capable ally; and other modes can in principle
  bid in the gap.

EFFECTIVE n (the reason for the noise)
  Frame counts overstate independence ~3x: per (arm,seed,side,band) cell the
  20-30 clean frames come from only 2-14 distinct (game,hero) episodes, and a
  single sticky 12-frame episode can move a cell 20pp.  The run always prints
  the f/e (frames/episodes) table; read it before quoting any cell.

USAGE
  capmono_gradient.py <root> [--wide]
     root/{armA,armB}_<run>/<game>.timeline.json  (+ .analysis.json alongside)
     --wide  drop the clean domain's HP floor from 0.42 to 0.30, opening band
             P (both HP-dependent families provably off -- the closest thing to
             the placebo SS V.2 wanted) and the rest of band L.  Same single
             pass; the narrow default is the one comparable with 14:37Z/18:36Z.
"""
import collections
import json
import math
import os
import statistics as st
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import capmono_refusal as CR
from roam_conversion import load_game

# Bid-formula crossings; see BAND MAP.  Do not "round" these -- they are exact.
B_HI = 0.9 / 1.96        # 0.45918  1.96-family raw crosses 0.9
B_LO = 0.72 / 1.633      # 0.44090  helpAlly raw crosses 0.72
P_HI = 0.72 / 1.96       # 0.36735  1.96-family raw crosses 0.72


def band(hp):
    if hp < P_HI:
        return 'P'
    if hp < B_LO:
        return 'L'
    if hp <= B_HI:
        return 'M'
    return 'H'


def frac(eps):
    n = len(eps)
    r = sum(e['retreat'] for e in eps)
    return r, n, (100.0 * r / n if n else float('nan'))


def collect(root, hp_lo, hp_hi):
    CR.HP_LO, CR.HP_HI = hp_lo, hp_hi
    out = []
    for arm in ('armA', 'armB'):
        for d in sorted(_glob(root, arm)):
            for tl in sorted(_glob_tl(d)):
                name = os.path.basename(tl).replace('.timeline.json', '')
                aj = tl.replace('.timeline.json', '.analysis.json')
                g = load_game(tl, aj)
                if g is None:
                    continue
                seed = json.load(open(aj))['script_version'].split(':s')[1].split(':')[0]
                for e in CR.scan_game(g, os.path.basename(d) + '/' + name):
                    e['arm'] = arm
                    e['seed'] = seed
                    e['band'] = band(e['hp'])
                    out.append(e)
    return out


def _glob(root, arm):
    import glob
    return glob.glob(os.path.join(root, arm + '_*'))


def _glob_tl(d):
    import glob
    return glob.glob(os.path.join(d, '*.timeline.json'))


def cell(eps, arm, seed, armed, bands):
    return [e for e in eps if e['arm'] == arm and e['armed'] == armed
            and e['band'] in bands and (seed is None or e['seed'] == seed)]


def report(eps, seeds, bands_act, bands_ref, label_act, label_ref):
    print(f"\n=== {label_act}  vs  {label_ref} ===")
    grads = {}
    for arm in ('armA', 'armB'):
        a = frac(cell(eps, arm, None, True, bands_act))
        b = frac(cell(eps, arm, None, False, bands_act))
        a2 = frac(cell(eps, arm, None, True, bands_ref))
        b2 = frac(cell(eps, arm, None, False, bands_ref))
        d1, d2 = a[2] - b[2], a2[2] - b2[2]
        print(f"  {arm}: {label_act} armed {a[0]}/{a[1]}={a[2]:5.1f}% base {b[0]}/{b[1]}={b[2]:5.1f}% -> {d1:+6.1f}pp")
        print(f"        {label_ref} armed {a2[0]}/{a2[1]}={a2[2]:5.1f}% base {b2[0]}/{b2[1]}={b2[2]:5.1f}% -> {d2:+6.1f}pp")
        print(f"        gradient = {d1 - d2:+6.1f}pp")
        per = []
        for s in seeds:
            x = frac(cell(eps, arm, s, True, bands_act))[2] - frac(cell(eps, arm, s, False, bands_act))[2]
            y = frac(cell(eps, arm, s, True, bands_ref))[2] - frac(cell(eps, arm, s, False, bands_ref))[2]
            per.append(x - y if not (math.isnan(x) or math.isnan(y)) else float('nan'))
        ok = [v for v in per if not math.isnan(v)]
        print("        per-seed " + " ".join(f"{v:+.1f}" for v in per)
              + (f"  mean {st.mean(ok):+.2f} SD {st.stdev(ok):.2f} SE {st.stdev(ok) / math.sqrt(len(ok)):.2f}"
                 if len(ok) > 1 else ""))
        grads[arm] = ok
    if len(grads['armA']) > 1 and len(grads['armB']) > 1:
        sdB = st.stdev(grads['armB'])
        print(f"  >>> NULL-CHANNEL (armB, capmono OFF in both bands) SD {sdB:.1f}pp/seed"
              f"  => MDE ~ +-{2 * sdB / math.sqrt(len(grads['armB'])):.0f}pp at {len(grads['armB'])} seeds")


def decision_relevance(eps, seeds):
    """Split the capmono-ACTIVE HP band by whether lanesurv (0.75) can bid at all.

    See THE DECISIVE SPLIT above: with no competitor inside (0.72, raw], the
    clamp is a provable no-op on the decision even though the arithmetic fires.
    """
    print("\n=== DECISION-RELEVANCE split (HP in active band; edist ring) ===")
    for lab, lo, hi in (('RELEVANT  edist[850,1100)', 0.0, 1100.0),
                        ('IRRELEVANT edist[1100,1500]', 1100.0, 1e9)):
        for arm in ('armA', 'armB'):
            def cut(armed):
                return [e for e in eps if e['arm'] == arm and e['armed'] == armed
                        and e['band'] in ('L', 'M') and lo <= e['edist'] < hi]
            a, b = frac(cut(True)), frac(cut(False))
            per = []
            for s in seeds:
                x = frac([e for e in cut(True) if e['seed'] == s])[2]
                y = frac([e for e in cut(False) if e['seed'] == s])[2]
                per.append(x - y)
            ok = [v for v in per if not math.isnan(v)]
            sd = f" SD {st.stdev(ok):.1f}" if len(ok) > 1 else ""
            print(f"  {lab:28} {arm}: armed {a[0]}/{a[1]}={a[2]:5.1f}%  base {b[0]}/{b[1]}={b[2]:5.1f}%"
                  f"  diff {a[2] - b[2]:+6.1f}pp   per-seed "
                  + " ".join(f"{v:+.0f}" for v in per) + sd)


def episodes(eps):
    print("\n=== effective n: distinct (game,hero) episodes per cell ===")
    for arm in ('armA', 'armB'):
        for s in sorted({e['seed'] for e in eps}):
            row = []
            for armed in (True, False):
                for bnd in ('L', 'M', 'H'):
                    c = cell(eps, arm, s, armed, (bnd,))
                    row.append(f"{'A' if armed else 'B'}{bnd}:{len(c)}f/{len({(e['game'], e['hero']) for e in c})}e")
            print(f"  {arm} s{s}: " + "  ".join(row))


def main():
    root = sys.argv[1]
    wide = '--wide' in sys.argv
    eps = collect(root, 0.30 if wide else 0.42, 0.50)
    seeds = sorted({e['seed'] for e in eps})
    print(f"games/frames scanned: {len({e['game'] for e in eps})} games, {len(eps)} clean frames"
          f"  (HP window {'0.30-0.50' if wide else '0.42-0.50'})")
    counts = collections.Counter(e['band'] for e in eps)
    print("  band counts: " + "  ".join(f"{k}={counts[k]}" for k in ('P', 'L', 'M', 'H')))
    # the pre-registered split (SS V.2): active [0.42,0.4592] vs "placebo" (0.4592,0.50]
    lo = '.30' if wide else '.42'
    report(eps, seeds, ('L', 'M'), ('H',), f'ACTIVE[{lo},.4592]', 'HIGH(.4592,.50]')
    # the split the code implies for the 1.96 family alone (helpAlly still off)
    report(eps, seeds, ('L',), ('H',), f'L-only[{lo},.4409)', 'HIGH(.4592,.50]')
    if wide:
        report(eps, seeds, ('L', 'M'), ('P',), 'ACTIVE[.3673,.4592]', 'P-band[.30,.3673)')
    decision_relevance(eps, seeds)
    episodes(eps)


if __name__ == '__main__':
    main()
