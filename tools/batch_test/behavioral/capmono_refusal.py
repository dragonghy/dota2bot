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

`[bug] #78` LIVENESS AUDIT (2026-08-21, measured on this exact 32-game corpus)
  #78 asks every detector here to re-check its `hp_pct > 0` liveness proxy.
  For THIS detector the answer differs per path, and the difference is
  structural -- do not carry the `lanekill_commit.py` conclusion across:

    (A) ACTOR selection came out CLEAN ON THIS CORPUS: 0/806 actor frames sit
        inside a death span, and 0/806 actors die inside the forward window
        [t, t+4.5].  That 0/806 is a direct measurement and still stands.

        THE BAND ARGUMENT THAT USED TO EXPLAIN IT DOES NOT.  This note read
        "the measured leak band is hp 0.005..0.29 (all <= 0.40) so it does not
        reach the actor band [0.42,0.50]".  Re-measured 2026-08-21T06:3xZ on
        the same 1609xx/1807xx corpus (940 death spans, 19207 corpse frames,
        235 leaks -- the RATE reproduces: 0.250 leak frames/death vs 0.24
        recorded, and max lag 0.30s vs 0.30 recorded), the VALUE range does
        not.  Split by whether the leaked snapshot is strictly after DEATH:

          * demonstrated leaks (lag > 0, n=135): p95 0.241, p99 0.370,
            MAX 0.386 -- not 0.29.  9 leaks (6.7%) clear 0.20, 4 clear 0.30.
          * frames at lag == 0.0 (n=100), i.e. snapshot timestamp == DEATH
            timestamp, which `is_dead()`'s `a <= t < b` counts as DEAD:
            p99 0.437, MAX 0.517.

        So under this module's own liveness convention the leak band REACHES
        INTO [0.42,0.50] on the corpus already in hand (0.437), and even under
        the strict reading the margin to 0.42 is 0.034 -- one sample's width,
        not the 0.13 the 0.29 figure implied.  The tail is not a lone outlier.

        The two >0.42 frames are BOTH Lion's Finger of Death, exactly the
        mechanism this docstring predicted below:
          20260820_183451_slot1 zuus  hp 0.437, DEATH t=540.50, Finger 459
          20260820_181738_slot1 c.maiden hp 0.517, DEATH t=276.40, Finger 334
        In both the killing cast and the DEATH share the snapshot's 0.1s tick
        and the next snapshot reads 0.000, so the sample is a real live read
        erased inside one interval -- a burst property, as predicted.

        DIRECTOR RULING 2026-08-21T05:0xZ (test_set.md section Z.1): this is a
        MEASURED disjointness, NOT immunity by construction -- the first draft
        of this note said "IMMUNE BY CONSTRUCTION, not by luck" and that is the
        section Y.2 error (a desk argument can prove EMPTY, it cannot prove
        RARE) one round later.  The leak value IS the last hp sampled before
        death, so leak > 0.42 needs only a hero going from >42% to dead inside
        one 0.5s interval -- available burst, i.e. a draft/patch property, not
        a code property.  The >=850u nearest-enemy clause makes it rarer, not
        impossible (Lion's Finger reaches 850 and Zeus's ult is global).
        WHY IT MATTERS EVEN THOUGH THE FILTER IS ALWAYS ON BELOW: the risk is
        not this run, it is a future reader citing "by construction" to skip
        the audit or drop the is_dead() call on a new corpus.  And the bias, if
        the bands ever do overlap, runs the WRONG WAY: a corpse's displacement
        is 0 -> scored COMMIT -> refusal rate down; capmono working means fewer
        in-band deaths on the armed side, so the armed refusal rate is pushed
        UP -- the design signature itself (GH #78's asymmetry, un-cancellable
        by DiD).  RE-AUDIT TRIGGER: any new corpus, or a wider sample interval
        -- BUT THE TRIGGER IS ALREADY MET, on this corpus, without either: the
        tail column asked for above came back p99 0.370 (not ~0.05) with mass
        spread up to 0.386, and 0.437/0.517 at the lag==0 boundary.  Read the
        ruling's own disjunction: "a lone 0.29 over a p99 of ~0.05 is a real
        margin; mass piled near 0.29 means 0.42 is one burst draft away" --
        this corpus is the second branch, and the burst draft is already in it.
        PRACTICAL CONSEQUENCE: keep `is_dead()`; do not restore an hp_pct
        liveness test on ANY path of this detector, and do not re-derive
        "the actor band is safe" from band geometry -- on a corpus with Lion,
        Lina, Zeus or any other one-cast nuke it is not.
    (B) The ALLY gate is where #78 DOES bite: it admits an ally at hp <= 0.55,
        and that band CONTAINS the whole leak band.  Measured 4/806 frames
        whose "ally in need" was already dead at t (leaked hp 0.133/0.059/
        0.014/0.037, each within 0.2s of its own DEATH event).  There was no
        ally to collapse to on those frames.
    (C) NEAREST-ENEMY selection: 0/806 picked a dead enemy.

  So the load-bearing rule is the band relation, not the proxy: a lethality
  proxy fails exactly where its selection band overlaps [0, 0.40].

TELEPORT CHANNELING (a SEPARATE defect found while doing the above -- and the
22:53Z "add a movelen cap" advice is INCOMPLETE, do not just apply it)
  9/806 clean-domain frames have the actor holding `modifier_teleporting`: the
  TP scroll was cast 0.5-2.2s BEFORE the sampled frame, so what the classifier
  scores as a decision at t was taken earlier, by another mode, and is
  irrevocable while channeling.  These split into two OPPOSITE-SIGN classes:
    (i)  landing inside the fwd window -> movelen ~1e4 -> forced RETREAT (7/9)
    (ii) landing after it, or the channel gets interrupted -> movelen ~0 ->
         forced COMMIT (2/9).  Existence proof: armA_160911/20260820_163429
         t=335.5 sniper, TP cast 332.5, zero displacement, channel broken at
         336.9 by a jakiro ice_path stun -- scored COMMIT while the bot was
         visibly trying to leave.
  A movelen cap catches (i) and KEEPS (ii) mislabelled.  Exclude the channel
  span instead: it is exactly observable from MODIFIER_ADD/REMOVE of
  `modifier_teleporting`, so this is a precise filter, not a heuristic.

AGGREGATE IMPACT OF BOTH CORRECTIONS (so nobody re-litigates it)
  13 of 806 frames drop (9 channel + 4 dead-ally).  Seed-paired DiD
  -7.89 -> -7.70pp; armB null-channel SD 15.0 -> 14.2pp/seed (MDE ~ +-20pp);
  DiD per-seed signs 2/4 either way.  The reading stays deep inside its own
  noise floor => the 21:00Z `capmono` NOT-PROMOTE verdict is UNCHANGED, and
  that is now measured rather than assumed.
  One honest wrinkle worth NOT over-reading: arm A's own internal diff goes
  3/4 -> 4/4 negative (-0.6 -3.5 -21.2 -0.1).  The null channel is still
  2/4 at |11-16|pp, so 4/4 on values this small is not a signal; it is quoted
  here only so the next reader is not surprised by it.

USAGE
  capmono_refusal.py <root>      # root/{armA,armB}_<run>/<game>.timeline.json
                                 # writes /tmp/clean_eps.jsonl (kept frames)
  --raw                          # disable the liveness/channel filters above
                                 # (reproduces the pre-#78 numbers bit-for-bit)
"""
import collections, glob, json, math, os, sys
sys.path.insert(0, '/home/user/dota2bot/tools/batch_test/behavioral')
from roam_conversion import load_game, dist, is_dead

RAW = False               # --raw: reproduce the pre-#78 reading bit-for-bit
DISCARD = collections.Counter()   # (arm, side, reason) -> frames dropped

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


def tp_channel_spans(tl):
    """hero -> [(t_add, t_remove)] for `modifier_teleporting`.

    A hero inside one of these spans is committed to a teleport decided BEFORE
    the sampled frame and cannot act, so the frame is not a decision frame at
    all -- see the TELEPORT CHANNELING note in the module docstring for why a
    movelen cap is not an adequate substitute for this.

    SECOND IMPLEMENTATION, ON PURPOSE-ish (director review 2026-08-21T05:0xZ):
    detect.py:_tp_channels already does this and is NOT reused only because it
    wants a tl wrapper with .events while we hold the raw dict.  The two differ
    in one place: it keeps a FIFO of unmatched ADDs per hero, this keeps a
    single slot, so an ADD/ADD/REMOVE sequence (a REMOVE dropped by the dumper)
    yields the span from the SECOND add here and from the first there.  Ours is
    the narrower span => fewer frames excluded => the correction is understated,
    never overstated, which is the safe direction for a discard filter.  If a
    third copy of this ever appears, hoist one shared implementation instead.
    """
    open_at, spans = {}, collections.defaultdict(list)
    for e in tl['events']:
        if e.get('inflictor') != 'modifier_teleporting':
            continue
        h = e.get('target')
        if e['type'] == 'MODIFIER_ADD':
            open_at[h] = e['t']
        elif e['type'] == 'MODIFIER_REMOVE' and h in open_at:
            spans[h].append((open_at.pop(h), e['t']))
    for h, t in open_at.items():          # channel still open at cut-off
        spans[h].append((t, t + 4.0))
    return spans


def scan_game(g, name):
    tl, frames = g['tl'], g['frames']
    anc = own_ancients(tl)
    dead, chan = g['dead'], tp_channel_spans(tl)
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
        # `hp_pct > 0.01` is the pre-#78 proxy; the death spans are the real
        # test.  Path (A) of the audit shows they never disagree on the ACTOR
        # (bands are disjoint) but they do on the ALLY, so apply both.
        alive = [s for s in snaps if s.get('hp_pct', 0) > 0.01
                 and (RAW or not is_dead(dead, s['hero'], t))]
        for actor in alive:
            hp = actor['hp_pct']
            if not (HP_LO <= hp <= HP_HI):
                continue
            side = 'armed' if actor['team'] == g['armed_team'] else 'base'
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
                # Audit path (B): did the pre-#78 proxy have an "ally in need"
                # here that was in fact already dead?  Count it, so the report
                # can state the false-admit rate instead of estimating it.
                if not RAW:
                    for a in snaps:
                        if (a['team'] == actor['team'] and a is not actor
                                and a.get('hp_pct', 0) > 0.01
                                and dist(actor, a) <= ALLY_R
                                and is_dead(dead, a['hero'], t)
                                and (a['hp_pct'] <= 0.55
                                     or any(t - 1.5 <= dt <= t + 1.0
                                            for dt in dmg_taken[a['hero']]))):
                            DISCARD[(name.split('/')[0][:4], side, 'dead_ally')] += 1
                            break
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
            # Checked HERE, not at actor selection: the discard count must mean
            # "clean-domain episodes dropped", and the domain is only fully
            # qualified at this point.  The emitted set is the same either way
            # (the channel test is independent of the enemy/ally gates) -- it
            # is the reported number that would otherwise be ~17x too large.
            if not RAW and any(a <= t < b for a, b in chan.get(actor['hero'], ())):
                DISCARD[(name.split('/')[0][:4], side, 'tp_channel')] += 1
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
    global RAW
    argv = [a for a in sys.argv[1:] if a != '--raw']
    RAW = '--raw' in sys.argv
    root = argv[0]
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

    print("=== #78 LIVENESS / CHANNEL DISCARDS ===" if not RAW else
          "=== RAW MODE: pre-#78 proxy, no discards ===")
    if not RAW:
        if not DISCARD:
            print("  (none)")
        for k in sorted(DISCARD):
            print(f"  {k[0]} {k[1]:5} {k[2]:10}: {DISCARD[k]} frames dropped")
    print()
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
