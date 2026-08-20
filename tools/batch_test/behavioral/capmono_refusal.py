#!/usr/bin/env python3
"""capmono clean-domain refuse-collapse rate: two-arm DiD verifier.

WHAT IT MEASURES
  `capmono` (bots/mode_team_roam_generic.lua:128) turns the team-roam lane-push
  "cliff" (desire>0.9 -> 0.72) into a real ceiling min(desire,0.72), so a ~46%-HP
  hero that would have out-bid the promoted `lanesurv` retreat (0.75) instead
  loses to it.  Observable signature: at ~46% HP with a reachable fight in front
  of him, the hero turns for his own fountain instead of collapsing in.

CLEAN DOMAIN (14:37Z spec, kept verbatim so readings stay comparable)
  per frame, corpse frames (hp_pct<=0.01) excluded:
    HP in [0.42,0.50]; alive ally within 1200u low-HP or taking damage;
    NEAREST ENEMY IN [850,1500] -- the load-bearing clause: >850u guarantees
    `lanesurv`'s burst retreat does not fire on its own, so a retreat here is
    attributable to team-roam being capped; t<=600s.
  Classify by displacement over the next ~3.5s: retreat iff the projection
  toward own ancient exceeds the projection toward the nearest enemy.

WHY DiD AND NOT A SINGLE ARM
  A single armed arm cannot isolate capmono: `teambrain` (regroup) also produces
  detachment while `ownhalf`/`overchase`/`l1trade`/`l5combo` push the other way.
  Run it over BOTH arms of a capmono bisect (arm A = capmono ON, arm B = the same
  id list minus capmono, same seeds, same tree); the 15 shared ids cancel in
    DiD = (armA armed-base) - (armB armed-base).

EMPIRICAL ZERO-POINT (measured 2026-08-20, GH #72 -- READ BEFORE JUDGING)
  In arm B capmono is OFF, so arm B's internal diff is a *null channel* and its
  scatter IS this detector's noise floor.  Measured over 4 seeds / 32 mirror
  games / 806 clean frames:
      armB per-seed internal diff: -13.2 -9.3 +18.2 +9.3   SD 15.0  SE 7.5
      armA per-seed internal diff:  -1.3 -3.5 -23.1 +1.4   SD 11.2  SE 5.6
      DiD (seed-paired) = -7.9pp  SE 9.3  |t| 0.84   per-seed signs 2/4
  => sigma ~ +-15pp/seed, MDE ~ +-21pp at 4 seeds.  Anything smaller is noise.
  The 14:37Z single-arm reading (+16.6pp, n=62/63, teambrain uncontrolled) sits
  INSIDE that scatter and must not be cited as evidence for capmono.
  This is the behavioral-channel analogue of GH #30 (economy, sigma~30 gpm).

DOMAIN VALIDITY (do not "fix" the laning skew -- it is correct)
  ~88% of clean frames land at t<=480 and 100% at t<=600.  That is not a
  sampling defect: the cap lives inside `if J.IsInLaningPhase() or
  J.IsPushing(hBot)` and turbo IsInLaningPhase has a 480s floor / 600s soft end
  (jmz_func.lua:8973-8985, with `c2` unarmed).  The genuinely uncovered slice is
  the second leg -- `J.IsPushing` frames at t>600 -- which this domain misses.

BOUNDARIES (offline-undecidable; do not overclaim)
  The clean domain is a SUPERSET of real trigger frames: raw desire in
  (0.72,0.9], lethality and self-risk gates cannot be evaluated offline (the
  dumper does not record GetEstimatedDamageToTarget).  A null/weak-negative DiD
  is equally consistent with "capmono fires too rarely to move the aggregate" --
  it is NOT evidence that capmono is harmful.
  Fog of war is the standing GH #27 gap.

INHERITED HYGIENE
  load_game() (roam_conversion) supplies the illusion idx-lock, `_paused_spans`
  filtering and the #43 frozen post-game tail truncation.  Do not reimplement.

USAGE
  capmono_refusal.py <root>      # root/{armA,armB}_<run>/<game>.timeline.json
                                 # writes /tmp/clean_eps.jsonl (all frames)
"""
import collections, glob, json, math, os, sys
sys.path.insert(0, '/home/user/dota2bot/tools/batch_test/behavioral')
from roam_conversion import load_game, dist

HP_LO, HP_HI = 0.42, 0.50
ALLY_R = 1200.0
ENE_LO, ENE_HI = 850.0, 1500.0
T_MAX = 600.0
LAG = 1.0
FWD_LO, FWD_HI, FWD_TGT = 2.5, 4.5, 3.5
MOVE_MIN = 120.0          # ignore near-stationary frames for a HOLD diagnostic
DEDUP_S = 6.0


def own_ancients(tl):
    a = {}
    for b in tl['buildings']:
        if b['name'] == 'ancient':
            a[b['team']] = (b['x'], b['y'])
        if len(a) == 2:
            break
    return a


def scan_game(g, name):
    tl, frames = g['tl'], g['frames']
    anc = own_ancients(tl)
    # ally damage-taken times (as victim hero, hit by enemy)
    dmg_taken = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] == 'DAMAGE' and e.get('target_hero'):
            dmg_taken[e['target']].append(e['t'])
    pauses = g['pauses']
    ts = sorted(frames)
    # index positions per hero for forward lookup
    pos_by_hero = collections.defaultdict(dict)
    for t in ts:
        for s in frames[t]:
            pos_by_hero[s['hero']][t] = s
    eps = []
    last = {}
    for t in ts:
        if not (0.0 <= t <= T_MAX):
            continue
        if any(not (t + FWD_HI < a or t - LAG > b) for a, b in pauses):
            continue
        snaps = frames[t]
        alive = [s for s in snaps if s.get('hp_pct', 0) > 0.01]
        for actor in alive:
            hp = actor['hp_pct']
            if not (HP_LO <= hp <= HP_HI):
                continue
            # nearest enemy
            enemies = [s for s in alive if s['team'] != actor['team']]
            if not enemies:
                continue
            ne = min(enemies, key=lambda s: dist(actor, s))
            ed = dist(actor, ne)
            if not (ENE_LO <= ed <= ENE_HI):
                continue
            # ally within 1200 taking damage / low hp
            allies = [s for s in alive if s['team'] == actor['team'] and s is not actor
                      and dist(actor, s) <= ALLY_R]
            hit_ally = None
            for a in allies:
                low = a['hp_pct'] <= 0.55
                took = any(t - 1.5 <= dt <= t + 1.0 for dt in dmg_taken[a['hero']])
                if low or took:
                    hit_ally = a
                    break
            if hit_ally is None:
                continue
            # forward displacement
            fwd = None
            for tt in ts:
                if t + FWD_LO <= tt <= t + FWD_HI:
                    s2 = pos_by_hero[actor['hero']].get(tt)
                    if s2 and (fwd is None or abs(tt - (t + FWD_TGT)) < abs(fwd[0] - (t + FWD_TGT))):
                        fwd = (tt, s2)
            if fwd is None:
                continue
            s2 = fwd[1]
            dx, dy = s2['x'] - actor['x'], s2['y'] - actor['y']
            movelen = math.hypot(dx, dy)
            oa = anc.get(actor['team'])
            uax, uay = oa[0] - actor['x'], oa[1] - actor['y']
            la = math.hypot(uax, uay) or 1.0
            uex, uey = ne['x'] - actor['x'], ne['y'] - actor['y']
            le = math.hypot(uex, uey) or 1.0
            proj_ret = (dx * uax + dy * uay) / la
            proj_com = (dx * uex + dy * uey) / le
            retreat = proj_ret > proj_com
            key = (actor['hero'], actor['idx'])
            dedup = (key in last and t - last[key] < DEDUP_S)
            last[key] = t
            eps.append({
                'game': name, 't': round(t, 1), 'hero': actor['hero'],
                'armed': actor['team'] == g['armed_team'],
                'team': actor['team'], 'hp': round(hp, 3),
                'edist': round(ed), 'enemy': ne['hero'],
                'ally': hit_ally['hero'], 'ally_hp': round(hit_ally['hp_pct'], 3),
                'movelen': round(movelen), 'proj_ret': round(proj_ret),
                'proj_com': round(proj_com), 'retreat': retreat,
                'hold': movelen < MOVE_MIN,
                'fwd_t': round(fwd[0], 1),
                'x': actor['x'], 'y': actor['y'], 'x2': s2['x'], 'y2': s2['y'],
                'dedup': dedup,
            })
    return eps


def main():
    root = sys.argv[1]
    # cell -> list of eps
    allc = []
    per_game = {}
    for arm in ('armA', 'armB'):
        for d in sorted(glob.glob(os.path.join(root, arm + '_*'))):
            for tl in sorted(glob.glob(os.path.join(d, '*.timeline.json'))):
                name = os.path.basename(tl).replace('.timeline.json', '')
                aj = tl.replace('.timeline.json', '.analysis.json')
                g = load_game(tl, aj)
                if g is None:
                    continue
                eps = scan_game(g, os.path.basename(d) + '/' + name)
                for e in eps:
                    e['arm'] = arm
                    e['run'] = os.path.basename(d)
                    e['armed_side'] = g['armed_side']
                    seed = json.load(open(aj))['script_version'].split(':s')[1].split(':')[0]
                    e['seed'] = seed
                    allc.append(e)
                per_game[os.path.basename(d) + '/' + name] = (g['armed_side'], len(eps))
    with open('/tmp/clean_eps.jsonl', 'w') as fh:
        for e in allc:
            fh.write(json.dumps(e) + '\n')

    def frac(eps):
        n = len(eps)
        r = sum(e['retreat'] for e in eps)
        return r, n, (100.0 * r / n if n else float('nan'))

    print("=== FRAME-LEVEL (all clean-domain frames) ===")
    cells = {}
    for arm in ('armA', 'armB'):
        for side in ('armed', 'base'):
            k = (arm, side)
            eps = [e for e in allc if e['arm'] == arm and (e['armed'] == (side == 'armed'))]
            cells[k] = eps
            r, n, f = frac(eps)
            print(f"  {arm} {side:5}: retreat {r}/{n} = {f:5.1f}%")
    aA = frac(cells[('armA', 'armed')]); bA = frac(cells[('armA', 'base')])
    aB = frac(cells[('armB', 'armed')]); bB = frac(cells[('armB', 'base')])
    dA = aA[2] - bA[2]; dB = aB[2] - bB[2]
    print(f"  armA internal (armed-base): {dA:+.1f}pp")
    print(f"  armB internal (armed-base): {dB:+.1f}pp")
    print(f"  DiD = (armA a-b) - (armB a-b) = {dA - dB:+.1f}pp")

    print("\n=== DEDUP episode-level (>=6s apart per actor) ===")
    for arm in ('armA', 'armB'):
        for side in ('armed', 'base'):
            eps = [e for e in allc if e['arm'] == arm and (e['armed'] == (side == 'armed')) and not e['dedup']]
            r, n, f = frac(eps)
            print(f"  {arm} {side:5}: retreat {r}/{n} = {f:5.1f}%")

    # per-seed / per-direction sign check (frame-level internal diff)
    print("\n=== per-seed armA internal diff (armed-base) ===")
    for seed in ('888', '895', '896', '906'):
        a = frac([e for e in allc if e['arm'] == 'armA' and e['seed'] == seed and e['armed']])
        b = frac([e for e in allc if e['arm'] == 'armA' and e['seed'] == seed and not e['armed']])
        print(f"  s{seed}: armed {a[0]}/{a[1]}={a[2]:5.1f}%  base {b[0]}/{b[1]}={b[2]:5.1f}%  diff {a[2]-b[2]:+.1f}pp")
    print("=== per-seed armB internal diff (armed-base) ===")
    for seed in ('888', '895', '896', '906'):
        a = frac([e for e in allc if e['arm'] == 'armB' and e['seed'] == seed and e['armed']])
        b = frac([e for e in allc if e['arm'] == 'armB' and e['seed'] == seed and not e['armed']])
        print(f"  s{seed}: armed {a[0]}/{a[1]}={a[2]:5.1f}%  base {b[0]}/{b[1]}={b[2]:5.1f}%  diff {a[2]-b[2]:+.1f}pp")
    print("\n=== per-direction armA internal diff ===")
    for sd in ('radiant', 'dire'):
        a = frac([e for e in allc if e['arm'] == 'armA' and e['armed_side'] == sd and e['armed']])
        b = frac([e for e in allc if e['arm'] == 'armA' and e['armed_side'] == sd and not e['armed']])
        print(f"  armed={sd}: armed {a[0]}/{a[1]}={a[2]:5.1f}%  base {b[0]}/{b[1]}={b[2]:5.1f}%  diff {a[2]-b[2]:+.1f}pp")
    for sd in ('radiant', 'dire'):
        a = frac([e for e in allc if e['arm'] == 'armB' and e['armed_side'] == sd and e['armed']])
        b = frac([e for e in allc if e['arm'] == 'armB' and e['armed_side'] == sd and not e['armed']])
        print(f"  armB armed={sd}: armed {a[0]}/{a[1]}={a[2]:5.1f}%  base {b[0]}/{b[1]}={b[2]:5.1f}%  diff {a[2]-b[2]:+.1f}pp")

    # decisive statistic: seed-paired DiD against arm B's null channel
    import statistics as _st
    _d = {}
    for arm in ('armA', 'armB'):
        _d[arm] = []
        for seed in ('888', '895', '896', '906'):
            a = frac([e for e in allc if e['arm'] == arm and e['seed'] == seed and e['armed']])
            b = frac([e for e in allc if e['arm'] == arm and e['seed'] == seed and not e['armed']])
            _d[arm].append(a[2] - b[2])
    if all(len(v) > 1 for v in _d.values()):
        mA, mB = _st.mean(_d['armA']), _st.mean(_d['armB'])
        sA, sB = _st.stdev(_d['armA']) / 2, _st.stdev(_d['armB']) / 2
        did = mA - mB
        se = math.sqrt(sA ** 2 + sB ** 2)
        per = [_d['armA'][i] - _d['armB'][i] for i in range(len(_d['armA']))]
        print("\n=== seed-paired DiD (decisive; armB is the NULL CHANNEL) ===")
        print(f"  armA mean {mA:+.2f}pp (SE {sA:.2f})   armB mean {mB:+.2f}pp (SE {sB:.2f})")
        print(f"  DiD {did:+.2f}pp  SE {se:.2f}  |t| {abs(did / se) if se else float('nan'):.2f}")
        print(f"  per-seed DiD {[round(x, 1) for x in per]}  "
              f"negative {sum(1 for x in per if x < 0)}/{len(per)}")
        print(f"  noise floor from armB: SD {_st.stdev(_d['armB']):.1f}pp/seed "
              f"=> MDE ~ +-{2.8 * sB:.0f}pp at 4 seeds")

    print(f"\ngames scanned: {len(per_game)}")


if __name__ == '__main__':
    main()
