#!/usr/bin/env python3
"""Target-legality re-read of `died_with_ult_ready` (d22) findings.

WHY THIS FILE EXISTS (replay-check 2026-09-02)
-----------------------------------------------
`detect.py:d22_died_with_ult_ready` fires when a hero dies while holding an
ultimate that is `level > 0 and cd == 0 and mp >= cost`.  Those three
conditions are about the CASTER.  None of them asks the question the
detector's own name implies -- was there anything to cast it AT?

The 2026-09-02T09:51Z round found the gap by hand on a 24-episode fragment:
6 `axe_culling_blade` episodes, 6/6 with no enemy below the execute
threshold, 3/6 with no enemy inside cast range at all.  A hand count on a
fragment is the #263 shape (a read that is not in the tree is a read the
next round redoes, and redoes differently), so this is that read, in the
tree, runnable on a whole wave.

WHAT IT COMPUTES
----------------
For every d22 finding in a sweep's `all_findings.jsonl`, at the LAST LIVE
FRAME STRICTLY BEFORE the death event (never the death frame itself, and
never an interpolated blend of a live and a dead sample -- see LIMITS 3):

  * `nearest_enemy`  -- distance to the closest LIVING enemy hero
  * `in_range`       -- living enemies inside this ult's RANGE FLOOR
  * `executable`     -- for execute-style ults only: living enemies inside
                        range AND below the kill threshold at that frame

and classifies the episode:

  LEGAL       -- at least one target the ult could actually be cast on
  NO_TARGET   -- nothing inside the range floor
  NO_EXECUTE  -- something inside range, but nothing the execute can kill
                 (execute-style ults only)

Output is a per-ult table plus the ab/ba stratified rate, because a rate is
a reading and 铁律 4(i-a) applies to readings.

THE FLOORS ARE DELIBERATELY GENEROUS
------------------------------------
`RANGE_FLOOR` is an UPPER bound on each ult's true cast range, and
`EXECUTE_HP` an UPPER bound on its true threshold.  Both errors point the
same way: they make a target look legal when it may not be.  So every count
this tool reports is a STRICT UNDER-COUNT of illegitimacy -- if it says an
episode had no target, the real game had no target either.  Globals get
`inf` and can never be NO_TARGET.  That asymmetry is the point: this tool
is allowed to miss a bad episode, never to invent one.

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. **The floors are this tool's operational definitions, not dumper
   fields.**  The dump carries no cast range and no execute threshold; the
   numbers below are read off the game and rounded UP.  No gate reads them.
   Same requirement as GH #405 acceptance (b).
2. **This is not a per-id effect size.**  d22 is a general behaviour
   detector; a wave arms a whole bundle.  A NO_TARGET rate says the
   DETECTOR is over-counting, not that any gate did anything.
3. **Alive/dead is decided by bracketing samples**, via
   `entities.alive_interp` -- interpolating hp across a death boundary
   manufactures a live-looking corpse at a position the hero never occupied
   (replay-check 2026-08-25, GH #176).  Illusions are dropped by
   `entities.frames_by_hero` for the same reason.
4. **1 Hz sampling.**  A hero closing at 400+ u/s moves ~420 u between
   samples, so `nearest_enemy` carries that much slack.  The range floors
   are far enough above the true ranges to absorb it in the safe direction.
"""

import argparse
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402

INF = float('inf')

# Upper bounds on true cast range (u).  Rounded UP on purpose -- see the
# module docstring: over-estimating range can only ever turn a NO_TARGET
# into a LEGAL, never the reverse.
RANGE_FLOOR = {
    # global / self / no-target -- can never lack a target
    'zuus_thundergods_wrath': INF,
    'silencer_global_silence': INF,
    'luna_eclipse': INF,
    'death_prophet_exorcism': INF,
    'centaur_stampede': INF,
    'sven_gods_strength': INF,
    'dragon_knight_elder_dragon_form': INF,
    'chaos_knight_phantasm': INF,
    'storm_spirit_ball_lightning': INF,
    'warlock_upheaval': INF,
    'oracle_false_promise': INF,          # ally-target: enemies irrelevant
    # self-centred AoE -- radius floor
    'nevermore_requiem': 1000,
    'venomancer_poison_nova': 1000,
    'tidehunter_ravage': 1400,
    'crystal_maiden_freezing_field': 1200,
    # ground / unit target -- cast range floor
    'lion_finger_of_death': 900,
    'viper_viper_strike': 1000,
    'slardar_amplify_damage': 900,
    'witch_doctor_death_ward': 800,
    'skywrath_mage_mystic_flare': 1000,
    'obsidian_destroyer_sanity_eclipse': 900,
    'queenofpain_sonic_wave': 900,
    'jakiro_macropyre': 900,
    'lich_chain_frost': 900,
    'shadow_shaman_mass_serpent_ward': 1000,
    'warlock_rain_of_chaos': 1200,
    # execute -- short range, and a threshold on top (see EXECUTE_HP)
    'axe_culling_blade': 400,
}

# Upper bounds on the execute threshold, by ability level.  Culling Blade is
# the only execute in `_CASHABLE_ULTS`.  Rounded UP for the same reason.
EXECUTE_HP = {
    'axe_culling_blade': {1: 300, 2: 400, 3: 500},
}


def _dist(a, b):
    return math.hypot(a['x'] - b['x'], a['y'] - b['y'])


def _ability_level(snap, name):
    for a in (snap.get('abilities') or []):
        if a['name'] == name:
            return a['level']
    return 0


def _abs_hp(frames, t):
    """Absolute HP around `t`, taken as the MINIMUM of the bracketing samples.

    `entities.interp` deliberately carries only `hp_pct`, not `hp` -- so the
    execute threshold, which is an absolute number, cannot come from it.  It
    comes from the raw samples instead.

    The minimum, not the interpolation, and that direction is the whole
    point: a LOWER enemy HP makes the execute look castable, i.e. turns a
    NO_EXECUTE into a LEGAL.  Like every other floor in this file the error
    can only ever under-count illegitimacy.

    (This branch is why `--selfcheck` exists.  The first corpus it ran on --
    W38, 449 episodes -- contained no Axe at all, so an `os_['hp']` that
    would have raised KeyError on contact sat unexecuted and looked fine.)
    """
    if not frames or t < frames[0]['t'] or t > frames[-1]['t']:
        return None
    lo, hi = 0, len(frames) - 1
    while lo < hi - 1:
        mid = (lo + hi) // 2
        if frames[mid]['t'] <= t:
            lo = mid
        else:
            hi = mid
    return min(frames[lo]['hp'], frames[hi]['hp'])


def _last_live_before(frames, t, my_deaths):
    """Last sample strictly before `t` on which the unit is alive.

    NOT the death frame and NOT an interpolation across it.  The charter's
    2026-08-20 note (#66 §0) is the same shape one detector down: evaluating
    a predicate on the frame AFTER the instant reads a world the decision
    never saw.
    """
    best = None
    for s in frames:
        if s['t'] >= t:
            break
        if s['hp_pct'] > 0:
            best = s
    if best is None:
        return None
    if entities.alive_interp(frames, best['t'], my_deaths) is None:
        return None
    return best


def classify(ctx, hero_key, t_death, ult):
    """-> (verdict, nearest_enemy, n_in_range, n_executable) or None."""
    frames, team, deaths = ctx
    me = frames.get(hero_key)
    if not me:
        return None
    my_team = team.get(hero_key)
    if my_team is None:
        return None
    snap = _last_live_before(me, t_death, deaths.get(hero_key))
    if snap is None:
        return None

    floor = RANGE_FLOOR.get(ult)
    if floor is None:
        return None
    thresh_tab = EXECUTE_HP.get(ult)
    thresh = None
    if thresh_tab:
        lvl = _ability_level(snap, ult)
        thresh = thresh_tab.get(lvl, max(thresh_tab.values()))

    nearest, n_in, n_exec = INF, 0, 0
    for other, ofr in frames.items():
        if other == hero_key or team.get(other) == my_team:
            continue
        os_ = entities.alive_interp(ofr, snap['t'], deaths.get(other))
        if os_ is None:
            continue
        d = _dist(snap, os_)
        nearest = min(nearest, d)
        if d <= floor:
            n_in += 1
            if thresh is not None:
                hp = _abs_hp(ofr, snap['t'])
                if hp is not None and hp < thresh:
                    n_exec += 1

    if n_in == 0:
        verdict = 'NO_TARGET'
    elif thresh is not None and n_exec == 0:
        verdict = 'NO_EXECUTE'
    else:
        verdict = 'LEGAL'
    return verdict, nearest, n_in, n_exec


def load_findings(sweep_dir):
    path = os.path.join(sweep_dir, 'all_findings.jsonl')
    out = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            f = json.loads(line)
            if f.get('detector') == 'died_with_ult_ready':
                out.append(f)
    return out


def timeline_path(sweep_dir, game):
    hits = glob.glob(os.path.join(sweep_dir, 'timelines', game + '*'))
    return hits[0] if hits else None


def _synth(enemy_x, enemy_hp, ult, my_lvl=3):
    """One-hero-per-side synthetic dump, hero dies at t=100."""
    def stream(idx, name, team, x, hp, ab):
        return [dict(t=t, hero=name, idx=idx, team=team, x=x, y=0,
                     hp=hp, hp_pct=1.0 if hp > 0 else 0.0, mp=999,
                     max_mp=999, mp_pct=1.0, level=6, items=[],
                     abilities=ab, tp_cd=0, tp_cdlen=60, net_worth=0)
                for t in (-10.0, 95.0, 99.0)]
    mine = stream(1, 'npc_dota_hero_axe', 2, 0, 600,
                  [dict(name=ult, level=my_lvl, cd=0, cd_len=100)])
    foe = stream(2, 'npc_dota_hero_lion', 3, enemy_x, enemy_hp, [])
    return {'snapshots': mine + foe,
            'events': [dict(t=100.0, type='DEATH', actor='npc_dota_hero_lion',
                            target='npc_dota_hero_axe', inflictor='x',
                            actor_hero=True, target_hero=True)],
            'game': {'teams': {}}}


def selfcheck():
    """Reverse assertions: prove each verdict can actually be reached.

    Without this, a verdict that no corpus happens to trigger is
    indistinguishable from one the code cannot produce -- which is exactly
    what happened to the execute branch on its first corpus.
    """
    cases = [
        # (name, enemy_x, enemy_hp, ult, expected)
        ('in range, executable',      200, 100, 'axe_culling_blade', 'LEGAL'),
        ('in range, too healthy',     200, 900, 'axe_culling_blade',
         'NO_EXECUTE'),
        ('out of range',             5000, 100, 'axe_culling_blade',
         'NO_TARGET'),
        ('non-execute, in range',     800, 900, 'lion_finger_of_death',
         'LEGAL'),
        ('non-execute, out of range',5000, 900, 'lion_finger_of_death',
         'NO_TARGET'),
        ('global ult, enemy far',    5000, 900, 'zuus_thundergods_wrath',
         'LEGAL'),
    ]
    bad = 0
    for name, ex, ehp, ult, want in cases:
        raw = _synth(ex, ehp, ult)
        fr, tm = entities.frames_by_hero(raw)
        ctx = (fr, tm, entities.death_times(raw))
        got = classify(ctx, 'axe', 100.0, ult)
        verdict = got[0] if got else 'UNRESOLVED'
        ok = verdict == want
        bad += not ok
        print(f'  {"ok  " if ok else "FAIL"} {name:28s} '
              f'-> {verdict} (want {want})')
    print(f'{len(cases)-bad}/{len(cases)} selfcheck cases pass')
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweep_dirs', nargs='*')
    ap.add_argument('--verbose', action='store_true',
                    help='one line per episode')
    ap.add_argument('--selfcheck', action='store_true',
                    help='reverse assertions on synthetic dumps')
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()
    if not args.sweep_dirs:
        ap.error('give at least one sweep dir, or --selfcheck')

    rows = []
    tl_cache = {}
    for sd in args.sweep_dirs:
        for f in load_findings(sd):
            game = f.get('game') or f.get('replay') or ''
            tp = timeline_path(sd, game)
            if not tp:
                rows.append(dict(f, verdict='NO_TIMELINE'))
                continue
            if tp not in tl_cache:
                with open(tp) as fh:
                    # entities.* read the RAW dump dict (`timeline['snapshots']`,
                    # `timeline['events']`), not detect.Timeline.
                    raw = json.load(fh)
                fr, tm = entities.frames_by_hero(raw)
                tl_cache[tp] = (fr, tm, entities.death_times(raw))
            tl = tl_cache[tp]
            f = dict(f, leg='ab' if f.get('side') == 'radiant' else 'ba')
            got = classify(tl, entities.canon(f['hero']), f['t'], f['ult'])
            if got is None:
                rows.append(dict(f, verdict='UNRESOLVED'))
                continue
            v, near, n_in, n_ex = got
            rows.append(dict(f, verdict=v, nearest=round(near, 1),
                             n_in_range=n_in, n_exec=n_ex))

    if not rows:
        print('no died_with_ult_ready findings in the given sweeps')
        return 0

    by_ult = {}
    for r in rows:
        by_ult.setdefault(r['ult'], []).append(r)

    print(f'D22 TARGET LEGALITY  episodes={len(rows)}  '
          f'sweeps={len(args.sweep_dirs)}')
    print()
    print(f'{"ult":40s} {"n":>4s} {"LEGAL":>6s} {"NO_TGT":>7s} '
          f'{"NO_EXEC":>8s} {"other":>6s}')
    print('-' * 78)
    tot = {}
    for ult in sorted(by_ult, key=lambda u: -len(by_ult[u])):
        rs = by_ult[ult]
        c = {v: sum(1 for r in rs if r['verdict'] == v)
             for v in ('LEGAL', 'NO_TARGET', 'NO_EXECUTE')}
        other = len(rs) - sum(c.values())
        for k, v in c.items():
            tot[k] = tot.get(k, 0) + v
        tot['other'] = tot.get('other', 0) + other
        print(f'{ult:40s} {len(rs):4d} {c["LEGAL"]:6d} {c["NO_TARGET"]:7d} '
              f'{c["NO_EXECUTE"]:8d} {other:6d}')
    print('-' * 78)
    print(f'{"TOTAL":40s} {len(rows):4d} {tot.get("LEGAL",0):6d} '
          f'{tot.get("NO_TARGET",0):7d} {tot.get("NO_EXECUTE",0):8d} '
          f'{tot.get("other",0):6d}')

    bad = tot.get('NO_TARGET', 0) + tot.get('NO_EXECUTE', 0)
    resolved = len(rows) - tot.get('other', 0)
    if resolved:
        print(f'\nillegitimate = {bad}/{resolved} = '
              f'{100.0*bad/resolved:.1f}% of RESOLVED episodes '
              f'(strict under-count -- floors are upper bounds)')

    # 4(i-a): both strata's readings, unconditionally.
    for leg in ('ab', 'ba'):
        rs = [r for r in rows if r.get('leg') == leg]
        if not rs:
            continue
        b = sum(1 for r in rs
                if r['verdict'] in ('NO_TARGET', 'NO_EXECUTE'))
        res = sum(1 for r in rs
                  if r['verdict'] in ('LEGAL', 'NO_TARGET', 'NO_EXECUTE'))
        pct = f'{100.0*b/res:.1f}%' if res else 'n/a'
        print(f'  leg {leg}: {b}/{res} = {pct}')

    if args.verbose:
        print()
        for r in sorted(rows, key=lambda r: (r['ult'], r['t'])):
            print(f'  {r["verdict"]:11s} {r.get("game","?"):34s} '
                  f'{r["hero"]:22s} t={r["t"]:7.1f} {r["ult"]:34s} '
                  f'near={r.get("nearest","?")} in={r.get("n_in_range","?")} '
                  f'exec={r.get("n_exec","?")}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
