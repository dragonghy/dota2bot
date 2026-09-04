#!/usr/bin/env python3
"""Trigger-level execution check ((a)-evidence) for the `campbind` candidate.

WHAT THE LEVER IS.  `mode_roam_generic.lua:~400` used to poke, on arrival at a
planned camp-pull, `tNeut[1]` -- the neutral NEAREST THE BOT out of
`bot:GetNearbyNeutralCreeps(1400)` -- with no relation to the camp
`J.ShouldPullNeutralCamp` had actually planned.  Armed, the poke goes through
`J.GetCampPullPokeTarget(tNeut, bot.roamCampPull)` (jmz_func.lua:9027), which
returns the first visible neutral within 1200 u of the PLANNED camp, or nil,
in which case NO order is issued that frame.

WHY THIS TOOL EXISTS AND NOT AN AGGREGATE DIFF.  The charter's attribution rule
(replay-check.md step 4a, test_set.md BW.3) forbids charging one aggregate
armed-baseline difference to one id when siblings share the code path.  Here
FOUR armed ids live on the same camp-pull branch in W46 -- `pullcamp` (the
selector that creates bot.roamCampPull at all), `pullcad`, `pullthink` (the
wind-up hold in the very `elseif` under the poke) and `campbind` -- so any
episode-level or economy-level difference is their JOINT effect.  `campbind`'s
condition (a) is therefore bought per TRIGGER, on the one thing only it can do.

THE ONE-DIRECTIONAL PROOF this tool looks for.  Shipped code can poke ONLY the
nearest neutral.  So an armed poke whose aggro lands on a camp that is NOT the
nearest one is something the shipped branch cannot produce -- it is positive
evidence the binding fired.  The baseline leg of the same games is the control
and must show none.  The converse is NOT symmetric and is not claimed: an armed
poke that does land on the nearest camp is consistent both with "the binding
fired and the planned camp happened to be nearest" and with "the binding was
inert", so those frames are counted as UNDECIDED, never as evidence.

DOMAIN, and every clause's observability, stated because they do not cancel:
  observable  the poke itself      DAMAGE event, actor_hero, target name
                                   `npc_dota_neutral_*` (NOT dmg_creep, which
                                   lumps in lane creeps)
              pos in {4,5}         seed_draft.positions_for_game, never
                                   team_slot%5+1 (GH #57/#116)
              the camps in reach   team-4 creep positions at the creep sample
                                   <= t, clustered; this reads the LIVE camps
                                   at that instant, so it needs no centroid
                                   table and no camp-team proxy
              ambiguity            >= 2 distinct live camps within POKE_R of
                                   the bot: the only frames where "nearest"
                                   and "planned" can disagree, i.e. the only
                                   frames the lever can bite
  NOT observable, so the domain is a SUPERSET on these -- a poke counted here
  need not have come from the camp-pull branch at all:
              bot.roamCampPull ~= nil     the plan itself is bot-side state
              which camp was planned      likewise
              the 3 s throttle / mode     mode_roam_generic state
  Consequence, stated as a limit and not worked around: a support hitting a
  camp while jungling on the way home is in this census.

WHY THE WINDOW MATTERS -- measured, not argued (2026-09-04, first run of this
tool on W46/b77771, 26 games).  The WIDE census reported 5 armed vs 2 baseline
non-nearest aggros and, read alone, that looks like the one-directional proof
firing.  It is not: shipped code CANNOT poke a non-nearest camp, so those two
baseline rows are the tool's own false-positive rate made visible, and the
timestamps say what they are -- t=1317.7 and t=1310.9, with four of the five
armed rows at t=1191..1481.  The camp-pull branch cannot run after
pullcamp_domain.T_HI=360; every one of those is late-game jungling charged to a
gate that was not on the frame.  Same shape as the `zusult` lesson in the
replay-check charter (量具把「门管不着的施法」记在门头上).  Hence `in_window` /
`at_mark` / `hp_pct` are carried per row and printed as three nested censuses:
the WIDE one is context, the narrowed ones are the reading, and the baseline
column of each is the control that says whether the armed column means
anything.

AGGRO ATTRIBUTION.  `creeps[]` rows carry no identity (t, team, x, y only), so
"which neutral was hit" is not readable from the damage event.  What IS
readable is which camp MOVED: an aggroed camp follows the puller.  For each
live camp within reach at the poke, the tool tracks that cluster's centroid
over the next AGGRO_S seconds (matched forward by nearest centroid) and calls
a camp AGGROED when its centroid displaces >= AGGRO_MIN u.  A poke instant is
attributed only when EXACTLY ONE camp in reach aggroed; two movers or none is
reported as `unattributed` and enters no conclusion.

Usage:
  python3 campbind_poke.py <sweep_dir> [<sweep_dir> ...] [--selfcheck]
Read-only, offline, no AWS.
"""
import argparse
import json
import math
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pullcamp_domain as PD  # noqa: E402  (Game, dist, load_sweep, RADIANT)

CAND_ID = 'campbind'

POKE_R = 1400.0        # bot:GetNearbyNeutralCreeps(1400) at the call site
LEASH = 1200.0         # PULL_CAMP_NEUTRAL_RANGE in jmz_func.lua
CAMP_LINK = 900.0      # same cluster-link distance pullcamp_domain uses
POKE_GAP = 2.5         # one Action_AttackUnit sprays many DAMAGE rows; the
                       # cadence itself is one poke per 3.0 s, so a 2.5 s gap
                       # splits pokes without splitting a single swing
AGGRO_S = 8.0          # how long to watch the camps after the poke
AGGRO_MIN = 250.0      # centroid displacement that counts as "this camp moved"
CREEP_STALE = PD.CREEP_STALE


def clusters_near(creeps, x, y, r):
    """Live camps (clusters of team-4 creeps) with a member within r of (x,y)."""
    pts = [(c['x'], c['y']) for c in creeps]
    cl = []                      # list of [sum_x, sum_y, n, members]
    for px, py in pts:
        for c in cl:
            if PD.dist(px, py, c[0] / c[2], c[1] / c[2]) < CAMP_LINK:
                c[0] += px; c[1] += py; c[2] += 1; c[3].append((px, py))
                break
        else:
            cl.append([px, py, 1, [(px, py)]])
    out = []
    for c in cl:
        cx, cy = c[0] / c[2], c[1] / c[2]
        near = min(PD.dist(px, py, x, y) for px, py in c[3])
        if near <= r:
            out.append({'cx': cx, 'cy': cy, 'n': c[2], 'near': near})
    out.sort(key=lambda d: d['near'])
    return out


def moved(g, camps, t0):
    """Displacement of EACH camp's centroid over (t0, t0+AGGRO_S], jointly.

    Creeps have no identity, so a camp is re-found forward in time by chaining
    its centroid at 1 Hz, which is what a dragged camp looks like.  The
    assignment is EXCLUSIVE -- every neutral goes to its single nearest tracked
    centroid -- and that is not a detail:

    FRAME EVIDENCE (b77771 `20260904_124617_slot2`, spirit_breaker, t=194.4).
    The first cut of this function asked `dist(creep, centroid) <= CAMP_LINK`
    per camp independently.  The two camps in reach there sit (-4193,4792) and
    (-4845,3880), i.e. 1121 u apart -- LESS than 2*CAMP_LINK -- so the same six
    creeps satisfied both tests and the frame printed `C0 d_bot=163 n=6` beside
    `C1 d_bot=163 n=6`, one camp's creeps counted as the other's.  A shared
    membership makes both camps read as moving together, which lands in
    `unattributed`, i.e. the overlap does not fabricate a finding -- it
    SUPPRESSES one, and silently.  Exclusive nearest-centroid assignment is the
    fix; a shrunk radius would not be, because 1121 u apart is a real map fact.
    """
    tracks = [(c['cx'], c['cy']) for c in camps]
    for ct in g.creep_t:
        if ct <= t0 or ct > t0 + AGGRO_S:
            continue
        buckets = [[] for _ in tracks]
        for c in g.neutrals.get(ct, []):
            best, bd = None, CAMP_LINK
            for i, (tx, ty) in enumerate(tracks):
                d = PD.dist(c['x'], c['y'], tx, ty)
                if d < bd:
                    best, bd = i, d
            if best is not None:
                buckets[best].append(c)
        for i, b in enumerate(buckets):
            if b:
                tracks[i] = (sum(c['x'] for c in b) / len(b),
                             sum(c['y'] for c in b) / len(b))
    return [PD.dist(c['cx'], c['cy'], *tr) for c, tr in zip(camps, tracks)]


def poke_instants(g, hero):
    """Poke times: hero DAMAGE onto an `npc_dota_neutral_*` target, degrouped."""
    c2h = {PD.canon(h): h for h in g.teams}
    ts = []
    for e in g.raw_events:
        if e.get('type') != 'DAMAGE' or not e.get('actor_hero'):
            continue
        if e.get('target_hero'):
            continue
        if not str(e.get('target', '')).startswith('npc_dota_neutral_'):
            continue
        if c2h.get(PD.canon(e.get('actor'))) != hero:
            continue
        ts.append((e['t'], e['target'], e.get('inflictor')))
    ts.sort()
    out = []
    for t, tgt, infl in ts:
        if out and t - out[-1]['t_last'] <= POKE_GAP:
            out[-1]['t_last'] = t
            out[-1]['targets'].add(tgt)
            out[-1]['inflictors'].add(infl)
        else:
            out.append({'t': t, 't_last': t, 'targets': {tgt},
                        'inflictors': {infl}})
    # A poke is `Action_AttackUnit` -- a RIGHT CLICK, which the combat log
    # carries as inflictor `dota_unknown`.  Ability damage onto a neutral is
    # not a poke, and two frames say why this had to become a column rather
    # than stay an assumption (both b77771/d7082b, 2026-09-04):
    #   * `20260904_124739_slot1` ogre_magi t=271.0-279.5 -- twenty-eight rows,
    #     every one `ogre_magi_ignite`, a DoT ticking on THREE families across
    #     BOTH camps in reach (ghost, fel_beast, wildkin) while the hero walks
    #     between them.  Counting that as a poke charges one DoT to the poke
    #     target of a branch that never ran.
    #   * `20260904_124617_slot2` spirit_breaker t=194.5 --
    #     `spirit_breaker_greater_bash`, a passive proc.  A proc does imply an
    #     attack, but the attack's own row is what dates the poke.
    for o in out:
        o['physical'] = 'dota_unknown' in o['inflictors']
    return out


def scan_game(g, name, seed, sweep=''):
    rows = []
    for hero, fr in g.frames.items():
        team = g.teams.get(hero)
        pos = g.pos.get(hero)
        if not team or not pos or pos < 4:
            continue
        for p in poke_instants(g, hero):
            t = p['t']
            ct = g.creep_sample(t)
            if ct is None:
                continue
            # hero position at the frame nearest the poke
            snap = None
            for st in sorted(fr):
                if st <= t:
                    snap = fr[st]
                else:
                    break
            if snap is None or t - snap['t'] > CREEP_STALE:
                continue
            camps = clusters_near(g.neutrals.get(ct, []),
                                  snap['x'], snap['y'], POKE_R)
            if not camps:
                continue
            dmoved = moved(g, camps, t)
            hits = [i for i, d in enumerate(dmoved) if d >= AGGRO_MIN]
            if len(hits) == 1:
                attrib = 'nearest' if hits[0] == 0 else 'non_nearest'
            else:
                attrib = 'unattributed'
            sec = t % 60.0
            rows.append({
                'sweep': sweep, 'game': name, 'seed': seed, 'hero': hero,
                'pos': pos, 'leg': g.leg(hero), 't': round(t, 1),
                # The camp-pull branch can only run inside the laning window
                # (pullcamp_domain.T_LO/T_HI) and the plan is only formed at
                # the travel-lead marks.  Recorded per row rather than filtered
                # away, so the wide census stays readable and the narrowing is
                # visible as a column -- see WHY THE WINDOW MATTERS in the
                # module docstring.
                'in_window': PD.T_LO <= t <= PD.T_HI,
                'at_mark': (5 <= sec <= 20) or (35 <= sec <= 50),
                'hp_pct': snap['hp_pct'],
                'physical': p['physical'],
                'inflictors': sorted(x for x in p['inflictors'] if x),
                'n_camps': len(camps),
                'ambiguous': len(camps) >= 2,
                'd_nearest': round(camps[0]['near'], 1),
                'd_second': round(camps[1]['near'], 1) if len(camps) > 1 else None,
                'attrib': attrib,
                # The whole point of the selector campbind binds the poke to:
                # `J.ShouldPullNeutralCamp` rejects a camp that is not our
                # team's.  `camp_team` is pullcamp_domain's ancient-proximity
                # proxy for the engine's camp.team -- a proxy, so a row where
                # the NEAREST camp is enemy-side is a candidate defect frame to
                # look at by hand, never a verdict on its own.
                'nearest_enemy_side': (
                    PD.camp_team(camps[0]['cx'], camps[0]['cy'], g.ancient)
                    not in (None, team)),
                'camps_xy': [(round(c['cx']), round(c['cy']),
                              round(c['near'])) for c in camps],
                'moved': [round(d, 1) for d in dmoved],
                'targets': sorted(p['targets']),
                'leash_gap': (round(camps[1]['near'] - LEASH, 1)
                              if len(camps) > 1 else None),
            })
    return rows


def selfcheck(games):
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-42s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    g = games[0][0]
    # [1] the corpus really carries neutral camps at the first spawn
    n60 = 0
    for ct in g.creep_t:
        if 60.0 <= ct <= 66.0:
            n60 = max(n60, len(g.neutrals.get(ct, [])))
    chk('neutrals present at first spawn', n60 >= 8, 'max=%d' % n60)
    # [2] clustering must find several disjoint camps map-wide, not one blob
    ct = next((c for c in g.creep_t if c >= 60.0), None)
    blobs = clusters_near(g.neutrals.get(ct, []), 0, 0, 1e9) if ct else []
    chk('camps cluster disjointly (>=6 map-wide)', len(blobs) >= 6,
        'n=%d' % len(blobs))
    # [3] a stationary camp must NOT read as aggroed -- the false-positive
    #     control for the whole attribution.  Take the camp farthest from every
    #     hero at t=70 and assert it does not move.
    still = None
    if ct:
        for c in blobs:
            far = min((PD.dist(c['cx'], c['cy'], s['x'], s['y'])
                       for s in g.by_t.get(min(g.by_t, key=lambda x: abs(x - 70)),
                                           [])), default=0)
            if still is None or far > still[1]:
                still = (c, far)
    dmv = moved(g, [still[0]], ct)[0] if still else -1
    chk('undisturbed camp reads as NOT moved', 0 <= dmv < AGGRO_MIN,
        'displacement=%.0f u (threshold %.0f)' % (dmv, AGGRO_MIN))
    # [4] both legs are actually present in the corpus
    legs = {g_.leg(h) for g_, _, _, _ in games for h in g_.frames}
    chk('both legs present', legs == {'armed', 'baseline'}, str(sorted(legs)))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='+')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--out', default='/tmp/campbind_rows.jsonl')
    a = ap.parse_args()

    games, cands = [], set()
    for d in a.sweeps:
        for m in PD.load_sweep(d):
            cands.add(m['cand'])
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            an = os.path.join(d, 'analysis', m['game'] + '.analysis.json')
            if not os.path.exists(tl):
                print('[warn] missing timeline %s' % tl, file=sys.stderr)
                continue
            games.append((PD.Game(tl, an, m['side']), m['game'], m['seed'], d))
    print('corpus: %d games from %d sweep dir(s)' % (len(games), len(a.sweeps)))
    if len(cands) != 1:
        sys.exit('[fatal] mixed cand strings in this corpus: %s' % sorted(cands))
    cand = cands.pop()
    if CAND_ID not in cand.split(','):
        sys.exit('[fatal] `%s` is NOT in this wave\'s cand string' % CAND_ID)
    siblings = [s for s in ('pullcamp', 'pullcad', 'pullthink')
                if s in cand.split(',')]
    print('cand string carries %s; SIBLINGS on the same branch: %s'
          % (CAND_ID, ','.join(siblings) or 'none'))

    if a.selfcheck:
        print('--- selfcheck ---')
        if not selfcheck(games):
            sys.exit(2)

    rows = []
    for g, name, seed, d in games:
        rows.extend(scan_game(g, name, seed, sweep=d))
    with open(a.out, 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')

    def tally(rs):
        amb = [r for r in rs if r['ambiguous']]
        return (len(rs), len(amb),
                sum(1 for r in amb if r['attrib'] == 'non_nearest'),
                sum(1 for r in amb if r['attrib'] == 'nearest'),
                sum(1 for r in amb if r['attrib'] == 'unattributed'))

    def census(title, sel):
        print('\n=== %s ===' % title)
        print('%-9s %6s %6s %12s %9s %13s'
              % ('leg', 'pokes', 'ambig', 'non_nearest', 'nearest',
                 'unattributed'))
        for leg in ('armed', 'baseline'):
            n, amb, nn, nr, un = tally([r for r in rows
                                        if r['leg'] == leg and sel(r)])
            print('%-9s %6d %6d %12d %9d %13d' % (leg, n, amb, nn, nr, un))

    census('WIDE poke census -- every neutral poke, camp-pull or not '
           '(rows -> %s)' % a.out, lambda r: True)
    census('IN-WINDOW (%g <= t <= %g): the only times the camp-pull branch '
           'can run' % (PD.T_LO, PD.T_HI), lambda r: r['in_window'])
    census('IN-WINDOW + AT-MARK + hp>=%.2f: closest observable approximation '
           'of the branch' % PD.HP_MIN,
           lambda r: r['in_window'] and r['at_mark'] and r['hp_pct'] >= PD.HP_MIN)
    census('IN-WINDOW + PHYSICAL (right-click only): ability damage onto a '
           'neutral is not a poke',
           lambda r: r['in_window'] and r['physical'])

    # Iron rule 4(i-a): both strata's READINGS registered, per seed, always.
    print('\n=== per seed x leg (rule 4(i-a): both strata registered) ===')
    print('%-7s %-9s %6s %6s %12s' % ('seed', 'leg', 'pokes', 'ambig',
                                      'non_nearest'))
    for seed in sorted({r['seed'] for r in rows}):
        for leg in ('armed', 'baseline'):
            n, amb, nn, _, _ = tally([r for r in rows
                                      if r['seed'] == seed and r['leg'] == leg])
            print('%-7s %-9s %6d %6d %12d' % (seed, leg, n, amb, nn))

    print('\n=== IN-WINDOW ambiguous PHYSICAL pokes, one line each '
          '(the deep-dive shortlist) ===')
    inwin = [r for r in rows if r['in_window'] and r['ambiguous']
             and r['physical']]
    for r in sorted(inwin, key=lambda r: (r['leg'], r['game'], r['t'])):
        print('  %-9s %-22s t=%-6.1f %-30s pos%d d1=%-6.1f d2=%-6.1f '
              'attrib=%-13s nearest_enemy_side=%-5s camps=%s'
              % (r['leg'], r['game'], r['t'], r['hero'], r['pos'],
                 r['d_nearest'], r['d_second'], r['attrib'],
                 r['nearest_enemy_side'], r['camps_xy']))
    n_es = sum(1 for r in inwin if r['nearest_enemy_side'])
    print('  in-window ambiguous pokes whose NEAREST camp is enemy-side '
          '(the selector would reject it): %d/%d' % (n_es, len(inwin)))

    nn_rows = [r for r in rows if r['ambiguous'] and r['attrib'] == 'non_nearest']
    if nn_rows:
        # The BASELINE column of this list is the tool's own false-positive
        # rate, not a finding: shipped code cannot poke a non-nearest camp, so
        # every baseline row here is a poke that did not come from the
        # camp-pull branch (the documented superset) or an aggro
        # mis-attribution.  Read the armed column ONLY against it.
        print('\n=== non-nearest aggro (armed = candidate evidence, '
              'baseline = this tool\'s own false-positive control) ===')
        for r in sorted(nn_rows, key=lambda r: (r['leg'], r['game'], r['t'])):
            print('  %-9s %-22s t=%-7.1f win=%-5s mark=%-5s %-28s '
                  'd1=%-7.1f d2=%-7.1f moved=%s %s'
                  % (r['leg'], r['game'], r['t'], r['in_window'], r['at_mark'],
                     r['hero'], r['d_nearest'], r['d_second'], r['moved'],
                     ','.join(r['targets'])))
    else:
        print('\nNo non-nearest aggro on EITHER leg: the lever has no decided '
              'surface in this corpus (NOT a certified SILENT -- see DOMAIN).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
