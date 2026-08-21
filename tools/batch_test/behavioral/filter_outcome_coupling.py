#!/usr/bin/env python3
"""Is a detector's SELECTION clause common-caused with its OUTCOME variable?

WHY THIS EXISTS (replay-check 2026-08-21T12:39Z, GH #86)
  `liondrainstop`'s registered reading filtered domain channels to span>=2.0s
  before comparing arms.  Measured on 196 games, that filter threw away the
  dangerous half: span<2.0s channels died 12/24 = 50.0%, span>=2.0s 6/40 =
  15.0% (Fisher p=0.0040) -- because Lion dying ENDS the channel, so "long
  enough to be cut" is a proxy for "that one did not go wrong".  The filter
  variable was downstream of the outcome.

  state.json carries other "filter first, then compare arms" readings that have
  never had that check run on them.  This tool runs it for the biggest one:
  `capmono`'s clean domain, whose load-bearing clause is
  NEAREST ENEMY IN [850,1500].

WHAT IT MEASURES (two independent couplings; they can fail separately)

  (1) BAND vs OUTCOME -- the liondrainstop test.
      Sweep the nearest-enemy clause over bands while holding every other
      clean-domain clause (HP in [0.42,0.50], ally-in-need within 1200u, t<=600,
      corpse/TP-channel/pause hygiene) fixed, and report the actor's own
      death-within-12s rate per band.  If the EXCLUDED near band is far more
      lethal than the INCLUDED band, the domain measures the safe half of the
      decision the gate exists to change.

  (1b) THE CLAUSE vs THE CODE IT CITES.
      capmono_refusal.py's domain note says ">850u guarantees `lanesurv`'s burst
      retreat does not fire on its own, so a retreat here is attributable to
      team-roam being capped".  `J.ShouldRetreatLaneBurst` (jmz_func.lua:4892)
      scans `J.GetNearbyHeroes(bot, 1100, ...)` and returns false only when that
      set is EMPTY -- so the threshold that buys the guarantee is 1100, not 850.
      The literal `850` does not occur anywhere in jmz_func.lua.  This tool
      reports the domain split at 1100 so the un-attributable share is visible.

  (2) RESIDENCE vs OUTCOME -- the frame-level-rate test.
      The registered DiD is a FRAME-level rate, so every frame an actor spends
      inside the band is one vote.  How long an actor stays inside a band that
      is defined by his distance to the enemy is itself an outcome: closing the
      distance (commit) exits the band downward, backing off (retreat) can hold
      it or exit upward.  Group clean frames into episodes (same actor, gap <=
      GAP_S) and compare frames-per-episode by first-frame outcome, per cell.
      Unequal residence means the frame rate and the episode rate are different
      estimands -- and if the inequality differs per cell it moves the DiD.

FIDELITY
  --selfcheck asserts this scan reproduces capmono_refusal.py's own cell counts
  (193/219/178/203 clean frames on the 1609xx/1807xx 40-game corpus at the
  default 1.0s dumper interval).  If that assertion fails, the domain here has
  drifted from the registered one and nothing below is comparable.

SAMPLING
  Every number here is a 1.0s-interval reading (the dumper default;
  `sweep_run.sh` passes no -interval).  Frame-level rates are sampling
  sensitive -- see the 10:51Z round -- so do not compare them across rounds
  without checking both sides' interval.

USAGE
  filter_outcome_coupling.py <root> [--selfcheck]
      root/{armA,armB}_<run>/<game>.timeline.json (+ .analysis.json)
"""
import collections, glob, json, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from roam_conversion import load_game, dist, is_dead, canon_hero
from capmono_refusal import (own_ancients, tp_channel_spans,
                             HP_LO, HP_HI, ALLY_R, LEGACY_ENE_LO, ENE_HI,
                             T_MAX, LAG, FWD_LO, FWD_HI, FWD_TGT,
                             LANESURV_REACH)

GAP_S = 2.0            # episode continuity at the 1.0s dumper interval

# This tool exists to AUDIT the pre-#90 registered domain against the rule it
# claimed to exclude, so it deliberately keeps the wrong 850 floor: that is the
# object under test, and --selfcheck's bit-for-bit cell counts (193/219/178/203)
# only mean something against it.  capmono_refusal.py itself has since moved its
# live floor to the derived 1100 (director ruling 2026-08-21T15:0xZ, GH #90).
ENE_LO = LEGACY_ENE_LO
LANESURV_R = LANESURV_REACH   # read out of J.ShouldRetreatLaneBurst, not copied
                              # -- copying it here would repeat GH #90 verbatim
DEATH_W = 12.0         # outcome window, same as the liondrainstop census
BANDS = [(0.0, 400.0), (400.0, 850.0), (850.0, 1500.0), (1500.0, 2500.0)]


def death_times(dead, hero):
    return [a for a, _ in dead.get(canon_hero(hero), ())]


def scan_game(g, name):
    """Yield one record per (frame, actor) passing every clean-domain clause
    EXCEPT the nearest-enemy band, which is recorded instead of filtered."""
    tl, frames = g['tl'], g['frames']
    anc = own_ancients(tl)
    dead, chan = g['dead'], tp_channel_spans(tl)
    dmg_taken = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] == 'DAMAGE' and e.get('target_hero'):
            dmg_taken[e['target']].append(e['t'])
    pauses = g['pauses']
    ts = sorted(frames)
    pos_by_hero = collections.defaultdict(dict)
    for t in ts:
        for s in frames[t]:
            pos_by_hero[s['hero']][t] = s

    out = []
    for t in ts:
        if not (0.0 <= t <= T_MAX):
            continue
        if any(not (t + FWD_HI < a or t - LAG > b) for a, b in pauses):
            continue
        snaps = frames[t]
        alive = [s for s in snaps
                 if s.get('hp_pct', 0) > 0.01 and not is_dead(dead, s['hero'], t)]
        for actor in alive:
            hp = actor['hp_pct']
            if not (HP_LO <= hp <= HP_HI):
                continue
            enemies = [s for s in alive if s['team'] != actor['team']]
            if not enemies:
                continue
            ne = min(enemies, key=lambda s: dist(actor, s))
            ed = dist(actor, ne)
            if ed > BANDS[-1][1]:
                continue
            allies = [s for s in alive if s['team'] == actor['team'] and s is not actor
                      and dist(actor, s) <= ALLY_R]
            hit_ally = None
            for a in allies:
                if a['hp_pct'] <= 0.55 or any(t - 1.5 <= dt <= t + 1.0
                                              for dt in dmg_taken[a['hero']]):
                    hit_ally = a
                    break
            if hit_ally is None:
                continue
            fwd = None
            for tt in ts:
                if t + FWD_LO <= tt <= t + FWD_HI:
                    s2 = pos_by_hero[actor['hero']].get(tt)
                    if s2 and (fwd is None
                               or abs(tt - (t + FWD_TGT)) < abs(fwd[0] - (t + FWD_TGT))):
                        fwd = (tt, s2)
            if fwd is None:
                continue
            if any(a <= t < b for a, b in chan.get(actor['hero'], ())):
                continue

            s2 = fwd[1]
            dx, dy = s2['x'] - actor['x'], s2['y'] - actor['y']
            oa = anc.get(actor['team'])
            uax, uay = oa[0] - actor['x'], oa[1] - actor['y']
            la = math.hypot(uax, uay) or 1.0
            uex, uey = ne['x'] - actor['x'], ne['y'] - actor['y']
            le = math.hypot(uex, uey) or 1.0
            proj_ret = (dx * uax + dy * uay) / la
            proj_com = (dx * uex + dy * uey) / le
            dts = [td for td in death_times(dead, actor['hero']) if t < td <= t + DEATH_W]
            out.append({
                'game': name, 'run': g['run'], 'arm': g['arm'], 'seed': g['seed'],
                't': round(t, 1), 'hero': actor['hero'], 'idx': actor['idx'],
                'armed': actor['team'] == g['armed_team'],
                'hp': round(hp, 3), 'edist': round(ed, 1), 'enemy': ne['hero'],
                'ally': hit_ally['hero'], 'ally_hp': round(hit_ally['hp_pct'], 3),
                'retreat': proj_ret > proj_com,
                'proj_ret': round(proj_ret), 'proj_com': round(proj_com),
                'died12': bool(dts), 'tdeath': round(dts[0], 1) if dts else None,
                'x': actor['x'], 'y': actor['y'],
            })
    return out


def in_band(r, lo, hi):
    return lo <= r['edist'] <= hi if lo == ENE_LO else lo <= r['edist'] < hi


def pct(k, n):
    return (100.0 * k / n) if n else float('nan')


def fisher_2x2(a, b, c, d):
    """Two-sided Fisher exact p for [[a,b],[c,d]] (small tables only)."""
    from math import comb
    n = a + b + c + d
    r1, r2, c1 = a + b, c + d, a + c

    def p(x):
        return comb(r1, x) * comb(r2, c1 - x) / comb(n, c1)
    p0 = p(a)
    tot = 0.0
    for x in range(max(0, c1 - r2), min(r1, c1) + 1):
        px = p(x)
        if px <= p0 * (1 + 1e-9):
            tot += px
    return min(1.0, tot)


def episodes(recs, lo, hi):
    """Group band-passing frames into per-actor contiguous episodes."""
    by = collections.defaultdict(list)
    for r in recs:
        if in_band(r, lo, hi):
            by[(r['game'], r['hero'], r['idx'])].append(r)
    eps = []
    for k, rs in by.items():
        rs.sort(key=lambda r: r['t'])
        cur = [rs[0]]
        for r in rs[1:]:
            if r['t'] - cur[-1]['t'] <= GAP_S:
                cur.append(r)
            else:
                eps.append(cur)
                cur = [r]
        eps.append(cur)
    return eps


def main():
    root = sys.argv[1]
    selfcheck = '--selfcheck' in sys.argv
    recs = []
    for arm in ('armA', 'armB'):
        for d in sorted(glob.glob(os.path.join(root, arm + '_*'))):
            for tlp in sorted(glob.glob(os.path.join(d, '*.timeline.json'))):
                ajp = tlp.replace('.timeline.json', '.analysis.json')
                g = load_game(tlp, ajp)
                if g is None:
                    continue
                g['arm'] = arm
                g['run'] = os.path.basename(d)
                g['seed'] = json.load(open(ajp))['script_version'].split(':s')[1].split(':')[0]
                recs += scan_game(g, os.path.basename(d) + '/' +
                                  os.path.basename(tlp).replace('.timeline.json', ''))
    with open('/tmp/coupling_recs.jsonl', 'w') as fh:
        for r in recs:
            fh.write(json.dumps(r) + '\n')

    cells = [('armA', True), ('armA', False), ('armB', True), ('armB', False)]

    if selfcheck:
        print("=== FIDELITY: registered clean-domain cell counts ===")
        want = {('armA', True): 193, ('armA', False): 219,
                ('armB', True): 178, ('armB', False): 203}
        ok = True
        for c in cells:
            n = sum(1 for r in recs if r['arm'] == c[0] and r['armed'] == c[1]
                    and in_band(r, ENE_LO, ENE_HI))
            flag = 'OK' if n == want[c] else 'MISMATCH'
            ok &= (n == want[c])
            print(f"  {c[0]} {'armed' if c[1] else 'base ':5}: {n} (want {want[c]}) {flag}")
        print(f"  => {'domain reproduces capmono_refusal.py' if ok else 'DOMAIN DRIFT -- stop'}")
        print()

    print("=== (1) BAND vs OUTCOME  [the liondrainstop test] ===")
    print("     all clean-domain clauses held fixed; only the nearest-enemy clause swept")
    print(f"     outcome = the ACTOR's own death within {DEATH_W:.0f}s")
    print("  band            frames  retreat%   died<=12s        (in domain?)")
    band_tot = {}
    for lo, hi in BANDS:
        sel = [r for r in recs if in_band(r, lo, hi)]
        d = sum(r['died12'] for r in sel)
        band_tot[(lo, hi)] = (d, len(sel))
        tag = '<-- THE DOMAIN' if (lo, hi) == (ENE_LO, ENE_HI) else 'excluded'
        print(f"  [{lo:6.0f},{hi:6.0f})  {len(sel):5}   {pct(sum(r['retreat'] for r in sel), len(sel)):5.1f}%   "
              f"{d:3}/{len(sel):<4} = {pct(d, len(sel)):5.1f}%   {tag}")
    inb = band_tot[(ENE_LO, ENE_HI)]
    near = tuple(sum(x) for x in zip(band_tot[(0.0, 400.0)], band_tot[(400.0, 850.0)]))
    print(f"\n  EXCLUDED-NEAR [0,850) {near[0]}/{near[1]} = {pct(*near):.1f}% "
          f"vs DOMAIN [850,1500] {inb[0]}/{inb[1]} = {pct(*inb):.1f}%")
    print(f"  Fisher p = {fisher_2x2(near[0], near[1]-near[0], inb[0], inb[1]-inb[0]):.4g}")

    print("\n  per cell (does the exclusion bite the two arms equally?):")
    for c in cells:
        row = []
        for lo, hi in BANDS:
            sel = [r for r in recs if r['arm'] == c[0] and r['armed'] == c[1]
                   and in_band(r, lo, hi)]
            row.append(f"{sum(r['died12'] for r in sel):2}/{len(sel):<3}={pct(sum(r['died12'] for r in sel), len(sel)):5.1f}%")
        print(f"    {c[0]} {'armed' if c[1] else 'base ':5}: " + "  ".join(row))

    print("\n=== (1b) THE 850 CLAUSE vs THE 1100 IT CITES ===")
    print("     lanesurv scans 1100u, so [850,1100) frames are NOT attributable")
    print("     to capmono alone -- the domain's own stated identification fails there.")
    splits = [('registered [850,1500]', ENE_LO, ENE_HI),
              ('lanesurv OVERLAP [850,1100)', ENE_LO, LANESURV_R - 1e-6),
              ('attributable [1100,1500]', LANESURV_R, ENE_HI)]
    for lab, lo, hi in splits:
        rates = {}
        for c in cells:
            sel = [r for r in recs if r['arm'] == c[0] and r['armed'] == c[1]
                   and lo <= r['edist'] <= hi]
            rates[c] = (pct(sum(r['retreat'] for r in sel), len(sel)), len(sel))
        dA = rates[('armA', True)][0] - rates[('armA', False)][0]
        dB = rates[('armB', True)][0] - rates[('armB', False)][0]
        n = sum(v[1] for v in rates.values())
        print(f"  {lab:28} n={n:4}  armA {dA:+6.1f}pp  armB {dB:+6.1f}pp  DiD {dA-dB:+6.1f}pp")
    ov = sum(1 for r in recs if ENE_LO <= r['edist'] < LANESURV_R)
    tot = sum(1 for r in recs if in_band(r, ENE_LO, ENE_HI))
    print(f"  => {ov}/{tot} = {pct(ov, tot):.1f}% of the registered domain is un-attributable")

    print("\n=== (2) RESIDENCE vs OUTCOME  [the frame-level-rate test] ===")
    print("     episodes = contiguous clean-domain frames for one actor (gap<=%.1fs)" % GAP_S)
    print("  cell          eps   frames  frames/ep  by first-frame outcome     frame%   ep%")
    for c in cells:
        sel = [r for r in recs if r['arm'] == c[0] and r['armed'] == c[1]]
        eps = episodes(sel, ENE_LO, ENE_HI)
        nf = sum(len(e) for e in eps)
        ret = [e for e in eps if e[0]['retreat']]
        com = [e for e in eps if not e[0]['retreat']]
        lr = sum(len(e) for e in ret) / len(ret) if ret else float('nan')
        lc = sum(len(e) for e in com) / len(com) if com else float('nan')
        fr = pct(sum(r['retreat'] for r in sel if in_band(r, ENE_LO, ENE_HI)), nf)
        er = pct(len(ret), len(eps))
        print(f"    {c[0]} {'armed' if c[1] else 'base ':5}: {len(eps):4}  {nf:5}   "
              f"{nf/len(eps) if eps else float('nan'):5.2f}    "
              f"retreat {lr:4.2f} / commit {lc:4.2f}   {fr:5.1f}%  {er:5.1f}%")

    def cellrate(arm, armed, level):
        sel = [r for r in recs if r['arm'] == arm and r['armed'] == armed]
        if level == 'frame':
            f = [r for r in sel if in_band(r, ENE_LO, ENE_HI)]
            return pct(sum(r['retreat'] for r in f), len(f))
        eps = episodes(sel, ENE_LO, ENE_HI)
        return pct(sum(1 for e in eps if e[0]['retreat']), len(eps))

    print("\n  the two estimands side by side:")
    for level in ('frame', 'episode'):
        dA = cellrate('armA', True, level) - cellrate('armA', False, level)
        dB = cellrate('armB', True, level) - cellrate('armB', False, level)
        print(f"    {level:8}: armA {dA:+6.1f}pp   armB {dB:+6.1f}pp   DiD {dA-dB:+6.1f}pp")

    print("\n=== exit direction (why an episode left the domain) ===")
    exits = collections.Counter()
    byrec = collections.defaultdict(dict)
    for r in recs:
        byrec[(r['game'], r['hero'], r['idx'])][round(r['t'], 1)] = r
    for c in cells:
        sel = [r for r in recs if r['arm'] == c[0] and r['armed'] == c[1]]
        for e in episodes(sel, ENE_LO, ENE_HI):
            last = e[-1]
            nxt = byrec[(last['game'], last['hero'], last['idx'])].get(round(last['t'] + 1.0, 1))
            if nxt is None:
                k = 'left-domain-or-gone'
            elif nxt['edist'] < ENE_LO:
                k = 'CLOSED (<850u)'
            elif nxt['edist'] > ENE_HI:
                k = 'BACKED OFF (>1500u)'
            else:
                k = 'other-clause'
            exits[(c[0], 'armed' if c[1] else 'base', k, e[0]['retreat'])] += 1
    for k in sorted(exits):
        print(f"  {k[0]} {k[1]:5} {k[2]:22} first-frame={'retreat' if k[3] else 'commit ':7}: {exits[k]}")


if __name__ == '__main__':
    main()
