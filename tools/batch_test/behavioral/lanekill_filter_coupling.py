#!/usr/bin/env python3
"""Is `lanekill_commit.py`'s ACTIVE domain selected on its own OUTCOME?

WHY THIS EXISTS (replay-check 2026-08-21T16:xxZ; follows GH #86 / GH #90)
  The 12:39Z round showed `liondrainstop`'s registered reading filtered its
  domain on a variable (channel span >= 2.0s) that is DOWNSTREAM of the
  outcome: Lion dying ends the channel, so "long enough to be cut" is a proxy
  for "that one did not go wrong" (50.0% vs 15.0% death, Fisher p=0.0040).
  The 14:36Z round ran the same audit on `capmono`'s clean domain and found a
  second, different failure (a load-bearing threshold quoted from no source).

  `state.json` registers a third such reading: `l1trade`'s ACTIVE band, where
  GH #77's headline (-17.5pp `commit_attack`, armed minus baseline) lives.
  Its load-bearing selection clause is

        victim hp_pct <= 0.40                     (lanekill_commit.py:VICTIM_HP)

  and unlike the geometry clauses (800/900/700/400, verified verbatim against
  J.ShouldInitiateLaneKill / J.ShouldSupportComboKill at 14:36Z) this one is
  NOT in the source at all.  The gate's lethality clause is

        nBurst >= hTarget:GetHealth() + hTarget:GetHealthRegen()*4.0
                                                  (jmz_func.lua:6932)

  -- an ABSOLUTE-health comparison against our castable burst.  `hp_pct <= 0.40`
  is a fraction stand-in adopted from GH #41 because `GetEstimatedDamageToTarget`
  is not in the dumper stream.  That much is declared honestly in
  lanekill_commit.py's docstring.  What has never been measured is whether the
  stand-in is COMMON-CAUSED WITH THE OUTCOME it is used to compare.

WHAT IT MEASURES (four checks; they fail independently)

  (1) BAND vs OUTCOME -- the liondrainstop test.
      Sweep the victim-HP clause over bands while holding every other ACTIVE
      clause (role, enemy range, backing ally, depth, dedup, pause/corpse/
      actor-death hygiene) fixed, and report the outcome rates per band.
      Two readings matter and they are different questions:
        * pooled rate vs band  -> is the selection variable outcome-coupled?
        * armed-minus-baseline delta vs band -> does the headline gap live
          only inside the retained band (domain is doing work), or equally
          outside it (the gap is a global targeting difference and the
          domain's specificity claim is empty)?

  (2) REVERSE CAUSATION -- how the victim GOT to <=40%.
      A hero is at low HP because someone shot it.  If the ACTOR is the one who
      shot it, then `commit` (actor damages that victim in [t-1, t+4]) is
      partly pre-determined at the moment the frame enters the domain: the very
      damage that satisfied the selection clause is inside, or one tick outside,
      the scored window.  Measure the share of episodes whose actor already
      damaged that victim STRICTLY BEFORE the scored window, per arm, per band;
      then re-read the headline on the fresh (no prior self-damage) half.

  (3) SUPPLY -- the denominator is an outcome too.
      Episodes per game per arm.  A side that commits more drives more victims
      below 40%, so it manufactures its own domain frames.  Unequal supply means
      the two arms' rates are computed over differently-composed populations.

  (4) THE PROXY vs THE CLAUSE IT STANDS IN FOR.
      Snapshots carry ABSOLUTE `hp` as well as `hp_pct`.  The gate compares
      absolute health to burst, so report how far the fraction cut and an
      absolute cut disagree -- i.e. how much of the retained band is out of
      reach of any plausible laning burst, and how much of the excluded band is
      inside it.  This does not fix the missing burst term; it bounds how much
      of the domain the fraction cut mis-selects on the gate's own axis.

FIDELITY
  --selfcheck asserts that this scan, restricted to (0, 0.40], reproduces
  lanekill_commit.scan's own ACTIVE rows FIELD BY FIELD.  If that fails the
  domain here has drifted from the registered one and nothing below compares.

SAMPLING
  Every number is a 1.0s-interval reading (the dumper default; sweep_run.sh
  passes no -interval).  Frame/episode-level rates are sampling sensitive --
  see the 10:51Z round -- so do not compare across rounds without checking both
  sides' `-interval`.

USAGE
  lanekill_filter_coupling.py <sweep_out_dir> [...] [--selfcheck] [--branch l1trade]
Read-only; no AWS, no billable resource.
"""
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from roam_conversion import load_game, dist, is_dead  # noqa: E402
import lanekill_commit as LK  # noqa: E402

# Bands over the victim's HP fraction.  (0, 0.40] is the registered ACTIVE
# clause; everything above it is what the clause throws away.
BANDS = [(0.0, 0.10), (0.10, 0.20), (0.20, 0.30), (0.30, 0.40),
         (0.40, 0.55), (0.55, 0.75), (0.75, 1.01)]
RETAINED = (0.0, 0.40)
PRE_S = 6.0        # look-back for "the actor was already on this victim"


def canon(h):
    return h.replace('npc_dota_hero_', '').replace('_', '')


def scan_band(g, lo, hi, drops=None):
    """lanekill_commit.scan with the victim-HP clause parameterised.

    Every other clause, and the order they are applied in, is copied verbatim
    from lanekill_commit.scan.  ONE subtlety, and the fidelity check caught me
    getting it wrong on the first pass: the registered scan runs a SINGLE dedup
    clock over the whole (0,0.40] victim stream, and stamps that clock BEFORE
    dropping the actor-died-in-window episodes.  Deduping per band and merging
    afterwards is not the same function -- a 76.4s episode suppressed inside its
    own band re-appears at 77.4s once the bands are merged (observed:
    crystalmaiden->sven, 20260820_163252_slot1).  So this generator does NOT
    dedup; it emits every qualifying (frame, actor, victim) with the clock
    inputs attached, and `dedup_stream` below applies the registered clock over
    the union in time order.
    """
    tl = g['tl']
    anc = LK.ancients(tl)
    dead = g['dead']
    if drops is None:
        drops = collections.Counter()
    deaths = collections.defaultdict(list)
    dmg = collections.defaultdict(list)
    incoming = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] == 'DEATH' and e.get('target_hero'):
            deaths[e['target']].append(e['t'])
        elif e['type'] == 'DAMAGE' and e.get('actor_hero'):
            dmg[e['actor']].append((e['t'], bool(e.get('target_hero')), e['target'],
                                    e.get('inflictor') or ''))
            if e.get('target_hero'):
                incoming[canon(e['target'])].append((e['t'], canon(e['actor'])))

    pauses = g['pauses']
    last = {}
    for t in sorted(g['frames']):
        in_lane = t < LK.LANING_END
        out_ctl = LK.OUT_START <= t < LK.OUT_END
        if not (in_lane or out_ctl):
            continue
        if any(not (t + LK.COMMIT_S < a or t - LK.LAG_S > b) for a, b in pauses):
            continue
        alive = []
        for s in g['frames'][t]:
            if s.get('hp_pct', 0) <= 0:
                continue
            if is_dead(dead, s['hero'], t):
                drops['corpse_leaked_by_hp_proxy'] += 1
                continue
            alive.append(s)
        for actor in alive:
            pos = g['pos'].get(actor['hero'], 0)
            if pos == 0:
                continue
            core = pos in (1, 2, 3)
            branch = 'l1trade' if core else 'l5combo'
            erange = LK.ENEMY_RANGE_CORE if core else LK.ENEMY_RANGE_SUP
            dmax = LK.DEPTH_CORE if core else LK.DEPTH_SUP
            enemies = [s for s in alive if s['team'] != actor['team']
                       and dist(actor, s) <= erange]
            if not enemies:
                continue
            if core:
                if not any(a is not actor and a['team'] == actor['team']
                           and a['hp_pct'] >= LK.ALLY_HP_MIN
                           and dist(actor, a) <= LK.ALLY_RANGE_CORE for a in alive):
                    continue
                vetoed = False
            else:
                vetoed = sum(1 for s in alive if s['team'] != actor['team']
                             and dist(actor, s) <= LK.SUP_CLOSE_RANGE) >= 2
            for victim in enemies:
                if not (lo < victim['hp_pct'] <= hi):
                    continue
                d = LK.depth(victim, anc, actor['team'])
                if d is None or d > dmax:
                    continue
                actor_died = any(t < x <= t + LK.COMMIT_S
                                 for x in deaths[actor['hero']])
                vdt = min([x - t for x in deaths[victim['hero']] if x > t - LK.LAG_S]
                          or [float('inf')])
                vic = canon(victim['hero'])
                act = canon(actor['hero'])
                hits = [(ht, ish, tg, inf) for ht, ish, tg, inf in dmg[actor['hero']]
                        if t - LK.LAG_S < ht <= t + LK.COMMIT_S]
                on_vic = any(ish and canon(tg) == vic for _, ish, tg, _ in hits)
                on_other = any(ish and canon(tg) != vic for _, ish, tg, _ in hits)
                on_vic_attack = any(ish and canon(tg) == vic and inf == 'dota_unknown'
                                    for _, ish, tg, inf in hits)
                # (2) how the victim got here: damage landed on it STRICTLY
                # before the scored window opens at t-LAG_S.
                pre = [(ht, a) for ht, a in incoming[vic]
                       if t - PRE_S <= ht <= t - LK.LAG_S]
                yield {
                    't': t, 'game': g['game'], 'run': g['run'], 'seed': g['seed'],
                    'branch': branch,
                    'band': 'OUT' if out_ctl else ('VETO' if vetoed else 'ACTIVE'),
                    'actor': act, 'victim': vic,
                    'pos': pos,
                    'armed': actor['team'] == g['armed_team'],
                    'actor_hp': actor['hp_pct'], 'victim_hp': victim['hp_pct'],
                    'edist': round(dist(actor, victim)), 'depth': round(d),
                    'commit': on_vic,
                    'commit_attack': on_vic_attack,
                    'switch': on_other and not on_vic,
                    'creep': (not on_vic and not on_other and bool(hits)),
                    'no_dmg': not hits,
                    'kill': any(t - LK.LAG_S < x <= t + LK.CONVERT_S
                                for x in deaths[victim['hero']]),
                    'bid_wins': actor['hp_pct'] > LK.BID_FLOOR_HIGH,
                    'vic_dt': vdt,
                    'full_window': vdt > LK.COMMIT_S,
                    # -- fields this tool adds on top of the registered row --
                    '_key': (actor['hero'], actor['idx'],
                             victim['hero'], victim['idx']),
                    '_actor_died': actor_died,
                    'victim_hp_abs': victim.get('hp', 0),
                    'hp_band': next(f'{a:.2f}-{b:.2f}' for a, b in BANDS
                                    if a < victim['hp_pct'] <= b),
                    'prior_self': any(a == act for _, a in pre),
                    'prior_any': bool(pre),
                }


def load_all(dirs):
    games = []
    for d in dirs:
        tld = os.path.join(d, 'timelines')
        if not os.path.isdir(tld):
            continue
        for fn in sorted(os.listdir(tld)):
            if not fn.endswith('.timeline.json'):
                continue
            stem = fn[:-len('.timeline.json')]
            aj = os.path.join(d, 'analysis', stem + '.analysis.json')
            if not os.path.exists(aj):
                continue
            g = load_game(os.path.join(tld, fn), aj)
            if g is None:
                continue
            g['run'] = os.path.basename(os.path.normpath(d))[:24]
            g['game'] = stem
            g['seed'] = json.load(open(aj)).get('script_version', '').split(':')[-2]
            games.append(g)
    return games


def selfcheck(games):
    """Restricted to (0, 0.40] this scan must reproduce lanekill_commit.scan."""
    mine, theirs = [], []
    for g in games:
        mine.extend(scan_game(g, 0.0, RETAINED[1]))
        theirs.extend(LK.scan(g))
    keys = ('t', 'game', 'branch', 'band', 'actor', 'victim', 'armed',
            'commit', 'commit_attack', 'switch', 'creep', 'no_dmg', 'kill',
            'victim_hp', 'edist', 'depth', 'full_window')

    def sig(rs):
        return sorted(tuple(r[k] for k in keys) for r in rs)
    a, b = sig(mine), sig(theirs)
    print(f'[selfcheck] this scan (0,0.40]: {len(a)} rows | '
          f'lanekill_commit.scan: {len(b)} rows')
    if a != b:
        diff = [x for x in a if x not in b][:3] + [x for x in b if x not in a][:3]
        print('[selfcheck] FAIL -- domain drift.  first differing rows:')
        for x in diff:
            print('   ', x)
        sys.exit(2)
    print('[selfcheck] PASS -- field-by-field identical to the registered domain')


def dedup_stream(rows, drops=None):
    """The registered dedup clock, applied over one game's whole victim stream.

    Order of operations copied from lanekill_commit.scan: stamp the clock, THEN
    drop the actor-died-in-window episodes (so a dropped episode still shadows
    the next 6s, exactly as in the registered scan).
    """
    last, out = {}, []
    for r in sorted(rows, key=lambda r: r['t']):
        key = r['_key']
        if key in last and r['t'] - last[key] < LK.DEDUP_S:
            continue
        last[key] = r['t']
        if r['_actor_died']:
            if drops is not None:
                drops['actor_died_in_window'] += 1
                drops['actordie_armed' if r['armed'] else 'actordie_base'] += 1
            continue
        out.append(r)
    return out


def scan_game(g, lo=0.0, hi=1.01, drops=None):
    """One game -> deduped episode rows over the victim-HP range (lo, hi]."""
    return dedup_stream(list(scan_band(g, lo, hi)), drops)


def rate(rows, k):
    return 100.0 * sum(r[k] for r in rows) / len(rows) if rows else float('nan')


def fisher_2x2(a, b, c, d):
    """Two-sided Fisher exact p for [[a,b],[c,d]] (small tables only)."""
    def lf(n):
        return math.lgamma(n + 1)
    n = a + b + c + d
    base = lf(a + b) + lf(c + d) + lf(a + c) + lf(b + d) - lf(n)

    def p(x):
        y = a + b - x
        z = a + c - x
        w = d - (a - x)
        if min(x, y, z, w) < 0:
            return 0.0
        return math.exp(base - lf(x) - lf(y) - lf(z) - lf(w))
    obs = p(a)
    lo = max(0, a - d)
    hi = min(a + b, a + c)
    return min(1.0, sum(p(x) for x in range(lo, hi + 1) if p(x) <= obs * 1.0000001))


def main():
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    do_self = '--selfcheck' in sys.argv
    branch = 'l1trade'
    for x in sys.argv[1:]:
        if x.startswith('--branch'):
            branch = x.split('=')[-1]
    games = load_all(args)
    print(f'games={len(games)}  branch={branch}  '
          f'(1.0s dumper interval -- sweep_run.sh passes no -interval)')
    if do_self:
        selfcheck(games)

    # Two scans, and they are NOT interchangeable -- this is finding (0).
    #   reg  : the REGISTERED domain, victim clause (0,0.40].  Every arm
    #          comparison below runs on this, because it is the object GH #77
    #          quotes and the only one --selfcheck certifies.
    #   wide : no victim-HP clause at all, used ONLY for the pooled
    #          "is the selection variable outcome-coupled" question.
    # They disagree by more than the clause: DEDUP_S is a single 6s clock per
    # (actor,victim) stamped BEFORE the outcome is scored, so a high-HP episode
    # admitted by the wider clause SHADOWS a low-HP episode 1-5s later that the
    # registered scan keeps.  Widening the clause therefore does not merely add
    # episodes, it DELETES registered ones.  Quantified in (0) below.
    reg, wide = [], []
    drops = collections.Counter()
    for g in games:
        reg.extend(scan_game(g, 0.0, RETAINED[1], drops))
        wide.extend(scan_game(g, 0.0, 1.01))
    reg = [r for r in reg if r['branch'] == branch]
    wide = [r for r in wide if r['branch'] == branch]
    ng = len(set((r['run'], r['game']) for r in reg))

    print(f'\n(0) THE CLAUSE AND THE DEDUP CLOCK ARE NOT SEPARABLE')
    ra = [r for r in reg if r['band'] == 'ACTIVE']
    wa = [r for r in wide if r['band'] == 'ACTIVE' and r['victim_hp'] <= RETAINED[1]]
    print(f'  registered ACTIVE, clause (0,0.40]                : {len(ra)} episodes')
    print(f'  same low-HP episodes when the clause is opened up : {len(wa)} '
          f'({100.0*(len(ra)-len(wa))/max(len(ra),1):.0f}% of them are '
          f'shadowed out by higher-HP episodes sharing the 6s dedup clock)')
    print('  => a "what if the threshold were T" sweep must re-run the clock '
          'per T; see (1b).')

    # threshold sweep, each T with its OWN dedup clock (the real counterfactual)
    print('\n(1b) THRESHOLD COUNTERFACTUAL -- clause set to (0,T], clock re-run')
    print(f'  {"T":>5} {"armed n":>8} {"base n":>7} {"supply":>7} '
          f'{"armed ca":>9} {"base ca":>8} {"delta":>8} '
          f'{"armed/game":>11} {"base/game":>10}')
    for T in (0.40, 0.55, 0.75, 1.01):
        sub = []
        for g in games:
            sub.extend(r for r in scan_game(g, 0.0, T)
                       if r['branch'] == branch and r['band'] == 'ACTIVE')
        a = [r for r in sub if r['armed']]
        b = [r for r in sub if not r['armed']]
        if not a or not b:
            continue
        na = sum(r['commit_attack'] for r in a)
        nb = sum(r['commit_attack'] for r in b)
        print(f'  {T:5.2f} {len(a):8} {len(b):7} {len(a)/len(b):7.2f} '
              f'{rate(a, "commit_attack"):8.1f}% {rate(b, "commit_attack"):7.1f}% '
              f'{rate(a, "commit_attack") - rate(b, "commit_attack"):+7.1f}pp '
              f'{na/ng:11.2f} {nb/ng:10.2f}')

    rows = wide
    act = [r for r in rows if r['band'] == 'ACTIVE']

    # ---- (1) band vs outcome -------------------------------------------
    print('\n(1) BAND vs OUTCOME -- WIDE scan (no victim clause), one clock.\n'
          '    Answers only: is the selection variable outcome-coupled?\n'
          '    The armed-minus-baseline columns here are NOT the registered\n'
          '    reading -- see (1b) for that.')
    print(f'  {"victim hp":11} {"n":>5} {"in domain":>9} '
          f'{"commit_att":>10} {"commit":>8} {"kill":>8} {"no_dmg":>8} '
          f'{"armed n":>8} {"base n":>7} {"d(cmt_att)":>11} {"d(commit)":>10}')
    for lo, hi in BANDS:
        lab = f'{lo:.2f}-{hi:.2f}'
        sub = [r for r in act if r['hp_band'] == lab]
        if not sub:
            continue
        a = [r for r in sub if r['armed']]
        b = [r for r in sub if not r['armed']]
        inside = 'RETAINED' if hi <= RETAINED[1] + 1e-9 else 'dropped'
        da = rate(a, 'commit_attack') - rate(b, 'commit_attack')
        dc = rate(a, 'commit') - rate(b, 'commit')
        print(f'  {lab:11} {len(sub):5} {inside:>9} '
              f'{rate(sub, "commit_attack"):9.1f}% {rate(sub, "commit"):7.1f}% '
              f'{rate(sub, "kill"):7.1f}% {rate(sub, "no_dmg"):7.1f}% '
              f'{len(a):8} {len(b):7} {da:+10.1f} {dc:+9.1f}')
    # Pooled coupling contrast: both halves come from the WIDE scan, so the
    # comparison is internally consistent.
    ret_w = [r for r in act if r['victim_hp'] <= RETAINED[1]]
    drp = [r for r in act if r['victim_hp'] > RETAINED[1]]
    # Every ARM comparison from here down uses the REGISTERED domain instead.
    ret = ra
    for k in ('commit_attack', 'commit', 'kill'):
        a1 = sum(r[k] for r in ret_w)
        b1 = len(ret_w) - a1
        c1 = sum(r[k] for r in drp)
        d1 = len(drp) - c1
        print(f'  retained vs dropped, {k:13}: '
              f'{100.0*a1/len(ret_w):5.1f}% ({a1}/{len(ret_w)}) vs '
              f'{100.0*c1/len(drp):5.1f}% ({c1}/{len(drp)})  '
              f'Fisher p={fisher_2x2(a1, b1, c1, d1):.2g}')

    # ---- (1c) the OUT control ------------------------------------------
    # t in [520,900): both helpers hard `return nil` (IsInLaningPhase), so the
    # branch is analytically dead while the rest of the 15-id bundle is
    # unchanged.  If the band-vs-delta pattern and the supply asymmetry below
    # reproduce HERE, they are bundle-wide facts about the corpus, not facts
    # about the lane-kill branch -- and the ACTIVE-band reading inherits them.
    out_rows = [r for r in rows if r['band'] == 'OUT']
    print('\n(1c) SAME SWEEP IN THE OUT CONTROL BAND (branch provably dead)')
    print(f'  {"victim hp":11} {"n":>5} {"armed n":>8} {"base n":>7} '
          f'{"d(cmt_att)":>11} {"d(commit)":>10}')
    for lo, hi in BANDS:
        lab = f'{lo:.2f}-{hi:.2f}'
        sub = [r for r in out_rows if r['hp_band'] == lab]
        a = [r for r in sub if r['armed']]
        b = [r for r in sub if not r['armed']]
        if not a or not b:
            continue
        print(f'  {lab:11} {len(sub):5} {len(a):8} {len(b):7} '
              f'{rate(a, "commit_attack") - rate(b, "commit_attack"):+10.1f} '
              f'{rate(a, "commit") - rate(b, "commit"):+9.1f}')

    # ---- (2) reverse causation -----------------------------------------
    print(f'\n(2) REVERSE CAUSATION -- actor already damaged this victim in '
          f'[t-{PRE_S:.0f}, t-{LK.LAG_S:.0f}]')
    for lab, sub in (('REGISTERED (0,0.40]', ret), ('wide, dropped (>0.40)', drp)):
        a = [r for r in sub if r['armed']]
        b = [r for r in sub if not r['armed']]
        print(f'  {lab:21} prior_self armed {rate(a, "prior_self"):5.1f}% '
              f'baseline {rate(b, "prior_self"):5.1f}%  | '
              f'prior_any armed {rate(a, "prior_any"):5.1f}% '
              f'baseline {rate(b, "prior_any"):5.1f}%')
    print('\n  headline (commit_attack, armed-baseline) split by prior_self, '
          'RETAINED band only')
    for flag in (True, False):
        sub = [r for r in ret if r['prior_self'] is flag]
        a = [r for r in sub if r['armed']]
        b = [r for r in sub if not r['armed']]
        if not a or not b:
            continue
        print(f'   prior_self={str(flag):5} n={len(sub):4} '
              f'armed {rate(a, "commit_attack"):5.1f}% ({len(a)}) '
              f'baseline {rate(b, "commit_attack"):5.1f}% ({len(b)}) '
              f'delta {rate(a, "commit_attack") - rate(b, "commit_attack"):+6.1f}pp')

    # ---- (3) supply ------------------------------------------------------
    print('\n(3) SUPPLY -- ACTIVE episodes per game, per arm '
          '(the denominator is an outcome too)')
    for band, tag in (('ACTIVE', ''), ('OUT', '  <- control')):
        for lab, src in ((f'REGISTERED (0,0.40]', reg),):
            sub = [r for r in src if r['band'] == band]
            a = [r for r in sub if r['armed']]
            b = [r for r in sub if not r['armed']]
            if not sub:
                continue
            print(f'  [{band:6}] {lab:19} armed {len(a)/ng:5.2f}/game  '
                  f'baseline {len(b)/ng:5.2f}/game  '
                  f'ratio {len(a)/max(len(b),1):4.2f}{tag}')

    # composition-standardised headline: reweight both arms to the POOLED
    # prior_self mix, so the gap is read at equal "already-engaged" share.
    w = {True: sum(1 for r in ret if r['prior_self']) / len(ret)}
    w[False] = 1.0 - w[True]
    std = {}
    for armed in (True, False):
        std[armed] = sum(
            w[f] * rate([r for r in ret if r['armed'] is armed
                         and r['prior_self'] is f], 'commit_attack')
            for f in (True, False))
    a = [r for r in ret if r['armed']]
    b = [r for r in ret if not r['armed']]
    crude = rate(a, 'commit_attack') - rate(b, 'commit_attack')
    print(f'\n  headline commit_attack delta, RETAINED band: '
          f'crude {crude:+.1f}pp -> prior_self-standardised '
          f'{std[True] - std[False]:+.1f}pp '
          f'(armed n={len(a)}, baseline n={len(b)})')

    # ---- (4) proxy vs the clause it stands in for -------------------------
    print('\n(4) PROXY vs CLAUSE -- gate compares ABSOLUTE hp to burst '
          '(jmz_func.lua:6932); the domain cuts on a FRACTION')
    for lab, sub in (('RETAINED (0,0.40]', ret), ('dropped (>0.40)', drp)):
        v = sorted(r['victim_hp_abs'] for r in sub)
        if not v:
            continue
        q = lambda p: v[min(len(v) - 1, int(p * len(v)))]  # noqa: E731
        print(f'  {lab:19} abs hp  min {v[0]:5} p25 {q(.25):5} '
              f'median {q(.5):5} p75 {q(.75):5} max {v[-1]:5}')
    if ret and drp:
        rv = sorted(r['victim_hp_abs'] for r in ret)  # registered domain
        dv = sorted(r['victim_hp_abs'] for r in drp)
        # How well could ANY absolute threshold reproduce the fraction cut?
        # If the best one misclassifies almost nothing, the fraction proxy is
        # not distorting the gate's own axis on this corpus.
        cand = sorted(set(rv) | set(dv))
        best = min(((sum(1 for x in rv if x > T) + sum(1 for x in dv if x <= T)), T)
                   for T in cand)
        err, T = best
        print(f'  best single ABSOLUTE-hp threshold reproducing the 0.40 '
              f'fraction cut: hp<={T}  -> misclassifies {err}/{len(rv)+len(dv)} '
              f'= {100.0*err/(len(rv)+len(dv)):.1f}% of episodes')
        print(f'  raw range overlap [{dv[0]},{rv[-1]}]: '
              f'{sum(1 for x in rv if x >= dv[0])}/{len(rv)} retained above the '
              f'dropped minimum, {sum(1 for x in dv if x <= rv[-1])}/{len(dv)} '
              f'dropped below the retained maximum')

    # ---- (5) supply-invariant restatement --------------------------------
    # A RATE whose denominator differs by 40% between arms is not a behaviour
    # comparison.  Counts PER GAME are immune to that: they answer "how often
    # did this actually happen", which is what a promote decision needs.
    print('\n(5) SUPPLY-INVARIANT -- events per game (immune to the denominator)')
    seeds = sorted(set(r['seed'] for r in reg))
    for band, lab in (('ACTIVE', 'REGISTERED ACTIVE (0,0.40]'),
                      ('OUT', 'REGISTERED OUT control')):
        sub = [r for r in reg if r['band'] == band]
        if not sub:
            continue
        print(f'  [{lab}]')
        for k in ('commit_attack', 'commit', 'kill'):
            na = sum(r[k] for r in sub if r['armed'])
            nb = sum(r[k] for r in sub if not r['armed'])
            # seed-paired difference of per-game counts
            per = []
            for s in seeds:
                ss = [r for r in sub if r['seed'] == s]
                gs = len(set((r['run'], r['game']) for r in ss))
                if not gs:
                    continue
                per.append((sum(r[k] for r in ss if r['armed'])
                            - sum(r[k] for r in ss if not r['armed'])) / gs)
            m = sum(per) / len(per) if per else float('nan')
            sd = ((sum((x - m) ** 2 for x in per) / (len(per) - 1)) ** 0.5
                  if len(per) > 1 else float('nan'))
            se = sd / len(per) ** 0.5 if per else float('nan')
            print(f'    {k:14} armed {na/ng:5.2f}/game  baseline {nb/ng:5.2f}/game '
                  f'  delta {na/ng - nb/ng:+5.2f}/game | seed-paired '
                  f'{m:+5.2f} SE {se:4.2f} (n_seed={len(per)}) '
                  f'|t| {abs(m/se) if se else float("nan"):4.2f}')

    out = '/tmp/lanekill_filter_rows.jsonl'
    with open(out, 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')
    print(f'\nrows -> {out}')


if __name__ == '__main__':
    main()
