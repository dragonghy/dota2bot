#!/usr/bin/env python3
"""`illureal` condition (a): do the illusions the gate ADMITS ever take the
decoy order?

WHAT THE LEVER IS
-----------------
`bots/FunLib/minion_lib/illusions.lua:92-99`.  Shipped, `IsIllusionUnit` is the
hand-written field `hMinionUnit.isIllusion`, and exactly two hero files in the
repo ever set it (`hero_naga_siren.lua:91`, `hero_phantom_lancer.lua:92`).
Armed (turbo only), the same function also asks the ENGINE:

    return hMinionUnit.isIllusion == true or hMinionUnit:IsIllusion()

So `illureal` is a pure WIDENING of one predicate, and the widened set is
exactly: *every controlled illusion whose owner is not Naga Siren or Phantom
Lancer* -- Manta Style copies, Conjure Image, Phantasm, Haunt, illusion runes.
The only thing that predicate guards is one call, three lines below:

    if IsIllusionUnit(u) then
        if X.ConfuseEnemyWithIllusions(bot, u) > 0 then return end
    end

and that body is itself guarded by a three-way conjunction (`illusions.lua:146`):

    J.GetHP(bot) < 0.4  and  J.IsRetreating(bot)  and  not J.WeAreStronger(bot, 1200)

whose effect, when all three hold, is one order: the illusion walks 800 u along
`bot:GetFacing() + 180` from ITS OWN position.

WHAT THIS TOOL MEASURES -- AND THE THREE THINGS IT CANNOT
---------------------------------------------------------
Frame table (`behav-dump`) carries t / hero / idx / player_id / x / y / hp_pct.
It does NOT carry facing, bot mode, or team-power.  Hence:

  1. `J.IsRetreating(bot)`      -- NOT observable.  No proxy is used here; a
     retreat proxy built out of "walks toward own fountain" would silently
     redefine the domain, and the domain is the whole question.
  2. `J.WeAreStronger(bot,1200)` -- NOT observable.  Visible enemy/ally counts
     within 1200 u are PRINTED next to each frame as context, never subtracted
     from anything and never used to include or exclude a frame.
  3. `bot:GetFacing()`          -- NOT observable, so the decoy's DIRECTION
     cannot be checked.  What is observable is its unmistakable magnitude: an
     800 u order issued to a unit that is otherwise attacking or idling.

=> The frame set this tool reports is an UPPER BOUND on the domain
   (`owner alive and hp_pct < 0.40` AND `an admitted copy alive`), never the
   domain itself.  A count on an upper bound can refute "it fired a lot"; it
   can never by itself prove SILENT.  Say INDETERMINATE when that is what the
   corpus supports -- INDETERMINATE is a verdict, not a failure.

THE MEASUREMENT, ON EACH UPPER-BOUND FRAME
------------------------------------------
For a copy alive at t and still alive at t+`WINDOW`:

  moved  |p(t+W) - p(t)| >= `MOVE_U`     -- this unit took SOME move order
  still  otherwise                        -- it is attacking, or has no order

`sep` (the change in copy-to-owner distance over the same window) is reported
beside it because the decoy order points away from a retreating owner, so a
firing branch should show `moved` AND `sep > 0`.  Neither is a signature by
itself: an illusion sent to lane-farm also moves.

⭐ CORPSE FREEZE (measured, not assumed; `--selfcheck` asserts it).  The dumper
keeps emitting an entity after it dies, frozen at its last position with
hp_pct = 0.  So `hp_pct > 0` is the aliveness test, and a `still` reading on a
frame whose copy is about to die is NOT evidence of a missing order -- it is a
unit in its death animation.  `--frames` prints `ttl` (time to that copy's
death) so a reader can see which frames sit in that tail.

⭐⭐ ENTITY INDEX REUSE, measured 2026-09-18 and NOT previously written down
anywhere in this tree.  The freeze is not forever: an idx is RECYCLED, and a
later illusion of the same owner is networked into it.  Witness, verbatim from
`20260912_095226_slot1`, luna idx 286: alive 856.5-874.5 at ~0.33 hp, dead and
frozen at (2007, 2136) through 898.5, then at 899.5 the SAME idx is at
(2142, 1700) with hp 0.96 and moves for another 17 s before dying again.
=> an idx is NOT a unit over a whole game; it is a unit only within one
contiguous alive run.  This tool therefore splits every copy into alive RUNS
and never lets a window cross a run boundary.  Three of the 166 copies in the
12-game corpus were recycled; a tool that keyed a whole-game trajectory on idx
would have spliced two different illusions into one.

⭐ IDENTITY (GH #176, same lock as `illumove_pairs.py`).  A hero NAME is not an
entity key: an illusion carries the same `hero` string and `player_id` and
differs only in `idx`.  The owner is the idx with the EARLIEST first
appearance -- heroes exist before the horn, illusions never do.

铁律 4 (i-a): both strata (armed-on-radiant, armed-on-dire) are printed for
every count.  (i-e): the two legs of one game are two disjoint hero sets, so
per-seed leg deltas are a paired structure; this tool prints the pair and does
NOT pool games of different seeds into one ratio.

Usage:
    illureal_domain.py <sweep_dir> [<sweep_dir> ...]
    illureal_domain.py <sweep_dir> [...] --frames [--limit N]
    illureal_domain.py --selfcheck <sweep_dir> [...]
"""
import argparse
import json
import math
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creeppull_domain import DIRE, RADIANT, load_sweep  # noqa: E402

HP_CUT = 0.40        # illusions.lua:146, J.GetHP(bot) < 0.4
WINDOW = 2.0         # seconds of lookahead for "did this unit move at all"
MOVE_U = 250.0       # displacement that means an order was taken (see docstring)
CONTEXT_R = 1200.0   # illusions.lua:146 passes 1200 to J.WeAreStronger -- context only
# Shipped code already routes these two heroes' illusions into the branch
# (they are the only files that set `isIllusion`), so they are NOT widened.
FIELD_SETTERS = ('npc_dota_hero_naga_siren', 'npc_dota_hero_phantom_lancer')


def load(path):
    with open(path) as fh:
        return json.load(fh)


def group_units(tl):
    """(hero, player_id) -> idx -> {t: snapshot}, t rounded to 0.1s."""
    by = defaultdict(lambda: defaultdict(dict))
    for s in tl['snapshots']:
        by[(s['hero'], s['player_id'])][s['idx']][round(s['t'], 1)] = s
    return by


def frames_by_t(tl):
    by = defaultdict(list)
    for s in tl['snapshots']:
        by[round(s['t'], 1)].append(s)
    return by


def alive_runs(frames):
    """Maximal contiguous runs of hp_pct > 0, as [(t_first, t_death), ...].

    One run = one occupant of that entity index (see ENTITY INDEX REUSE in the
    docstring).  `t_death` is the first dead frame after the run, or just past
    the last frame when the run reaches the end of the recording.
    """
    ts = sorted(frames)
    runs, start = [], None
    for t in ts:
        if frames[t]['hp_pct'] > 0:
            if start is None:
                start = t
        elif start is not None:
            runs.append((start, t))
            start = None
    if start is not None:
        runs.append((start, ts[-1] + 0.001))
    return runs


def _run_rows(hero, pid, idx, frames, own, allf, owner_idx, t0, tdeath):
    """Upper-bound rows for ONE alive run of one copy (one occupant)."""
    rows = []
    for t in sorted(frames):
        if not (t0 <= t < tdeath):
            continue
        o = own.get(t)
        if o is None or not (0 < o['hp_pct'] < HP_CUT):
            continue
        c = frames[t]
        tn = round(t + WINDOW, 1)
        cn, on = frames.get(tn), own.get(tn)
        if cn is None or cn['hp_pct'] <= 0 or tn >= tdeath:
            verdict, disp, sep = 'no_window', None, None
        else:
            disp = math.dist((c['x'], c['y']), (cn['x'], cn['y']))
            d_now = math.dist((c['x'], c['y']), (o['x'], o['y']))
            d_next = (math.dist((cn['x'], cn['y']), (on['x'], on['y']))
                      if on is not None and on['hp_pct'] > 0 else None)
            sep = None if d_next is None else d_next - d_now
            verdict = 'moved' if disp >= MOVE_U else 'still'
        enemies = allies = 0
        for s in allf.get(t, []):
            if s['hp_pct'] <= 0 or s['idx'] == owner_idx:
                continue
            if math.dist((s['x'], s['y']), (o['x'], o['y'])) > CONTEXT_R:
                continue
            if s['team'] == o['team']:
                allies += 1
            else:
                enemies += 1
        rows.append({'hero': hero, 'pid': pid, 'idx': idx, 'team': c['team'],
                     't': t, 'ttl': round(tdeath - t, 1),
                     'owner_hp': o['hp_pct'],
                     'copy_d': math.dist((c['x'], c['y']), (o['x'], o['y'])),
                     'disp': disp, 'sep': sep, 'verdict': verdict,
                     'enemies_1200': enemies, 'allies_1200': allies})
    return rows


def scan_game(tl):
    """Every upper-bound frame of every ADMITTED copy in one game."""
    by = group_units(tl)
    allf = frames_by_t(tl)
    rows = []
    carriers = Counter()
    for (hero, pid), idxs in by.items():
        if len(idxs) < 2:
            continue
        owner = min(idxs, key=lambda i: min(idxs[i]))
        if hero in FIELD_SETTERS:
            carriers['field_setter_copies'] += len(idxs) - 1
            continue                      # shipped already admits these
        own = idxs[owner]
        for i, frames in idxs.items():
            if i == owner:
                continue
            runs = alive_runs(frames)
            if not runs:
                continue
            # one run = one occupant of this index (ENTITY INDEX REUSE);
            # a window never crosses a run boundary
            carriers['admitted_copies'] += len(runs)
            carriers['recycled_idx'] += len(runs) - 1
            for t0, tdeath in runs:
                rows += _run_rows(hero, pid, i, frames, own, allf, owner,
                                  t0, tdeath)
    return rows, carriers


def scan(dirs):
    out = []
    for d in dirs:
        for row in load_sweep(d):
            p = os.path.join(d, 'timelines', row['game'] + '.timeline.json')
            if not os.path.exists(p):
                continue
            tl = load(p)
            rows, carriers = scan_game(tl)
            armed = RADIANT if row['side'] == 'radiant' else DIRE
            for r in rows:
                r['leg'] = 'armed' if r['team'] == armed else 'baseline'
            out.append({'game': row['game'], 'seed': row['seed'],
                        'side': row['side'], 'rows': rows,
                        'carriers': dict(carriers)})
            del tl
    if not out:
        sys.exit('[fatal] no timelines under %s' % dirs)
    return out


def report(res, frames=False, limit=40):
    print('constants read from the Lua: hp cut %.2f, context radius %.0f u'
          % (HP_CUT, CONTEXT_R))
    print('instrument: window %.1f s, move threshold %.0f u' % (WINDOW, MOVE_U))
    print('games: %d' % len(res))
    print('⚠ every count below is an UPPER BOUND: IsRetreating and '
          'WeAreStronger are not in the frame table (see docstring).')
    adm = sum(g['carriers'].get('admitted_copies', 0) for g in res)
    fld = sum(g['carriers'].get('field_setter_copies', 0) for g in res)
    print('copies seen: %d admitted by illureal, %d already admitted shipped '
          '(naga/phantom_lancer)' % (adm, fld))
    per_leg = defaultdict(Counter)
    per_stratum = defaultdict(lambda: defaultdict(Counter))
    per_seed = defaultdict(lambda: defaultdict(Counter))
    for g in res:
        for r in g['rows']:
            per_leg[r['leg']][r['verdict']] += 1
            per_leg[r['leg']]['frames'] += 1
            per_stratum[g['side']][r['leg']][r['verdict']] += 1
            per_stratum[g['side']][r['leg']]['frames'] += 1
            per_seed[g['seed']][r['leg']][r['verdict']] += 1
            per_seed[g['seed']][r['leg']]['frames'] += 1
    print('\nupper-bound frames by leg')
    for leg in ('armed', 'baseline'):
        c = per_leg[leg]
        print('  %-9s frames %3d  moved %3d  still %3d  no_window %3d'
              % (leg, c['frames'], c['moved'], c['still'], c['no_window']))
    print('\nboth strata (铁律 4 (i-a) -- registered whatever they say)')
    for side in sorted(per_stratum):
        for leg in ('armed', 'baseline'):
            c = per_stratum[side][leg]
            print('  armed-on-%-8s %-9s frames %3d  moved %3d  still %3d  no_window %3d'
                  % (side, leg, c['frames'], c['moved'], c['still'], c['no_window']))
    print('\nper seed')
    for seed in sorted(per_seed):
        a, b = per_seed[seed]['armed'], per_seed[seed]['baseline']
        print('  s%-7s armed frames %3d (moved %2d) | baseline frames %3d (moved %2d)'
              % (seed, a['frames'], a['moved'], b['frames'], b['moved']))
    if frames:
        print('\nframe table (first %d per leg; ttl = seconds until that copy dies)'
              % limit)
        shown = Counter()
        for g in res:
            for r in sorted(g['rows'], key=lambda r: r['t']):
                if shown[r['leg']] >= limit:
                    continue
                shown[r['leg']] += 1
                print('  %-30s %-8s t=%7.1f %-22s idx%-5d ttl=%5.1f '
                      'owner_hp=%.2f d=%6.0f disp=%s sep=%s %-9s E%d/A%d'
                      % (g['game'], r['leg'], r['t'],
                         r['hero'].replace('npc_dota_hero_', ''), r['idx'],
                         r['ttl'], r['owner_hp'], r['copy_d'],
                         '   --' if r['disp'] is None else '%5.0f' % r['disp'],
                         '   --' if r['sep'] is None else '%+5.0f' % r['sep'],
                         r['verdict'], r['enemies_1200'], r['allies_1200']))


def selfcheck(res, dirs):
    """Priors that must hold on real data -- each one failed something real."""
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-44s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    # 1. The identity lock: in every game the owner idx of a group that has
    #    copies must appear BEFORE the horn, and no copy may.
    # 2. The corpse freeze, in the only form that is actually true: a dead
    #    copy stays frozen until its idx is RECYCLED, and a recycle is visible
    #    as a fresh alive run on the same idx.  A position change while dead
    #    with no later alive run would mean the freeze itself is unreliable,
    #    and every `still` reading in this tool would be suspect.
    pre_owner = post_copy = bad = 0
    corpses = recycled = unexplained = 0
    for d in dirs:
        for row in load_sweep(d):
            p = os.path.join(d, 'timelines', row['game'] + '.timeline.json')
            if not os.path.exists(p):
                continue
            tl = load(p)
            for (hero, pid), idxs in group_units(tl).items():
                if len(idxs) < 2:
                    continue
                owner = min(idxs, key=lambda i: min(idxs[i]))
                if min(idxs[owner]) < 0:
                    pre_owner += 1
                else:
                    bad += 1
                for i, frames in idxs.items():
                    if i == owner:
                        continue
                    if min(frames) > 0:
                        post_copy += 1
                    else:
                        bad += 1
                    runs = alive_runs(frames)
                    recycled += max(0, len(runs) - 1)
                    ts = sorted(frames)
                    # walk the dead stretches: inside one stretch the position
                    # must not move; a move is only legal across a recycle.
                    prev_t = None
                    for t in ts:
                        if frames[t]['hp_pct'] > 0:
                            prev_t = None
                            continue
                        if prev_t is None:
                            prev_t = t
                            corpses += 1
                            continue
                        if math.dist((frames[prev_t]['x'], frames[prev_t]['y']),
                                     (frames[t]['x'], frames[t]['y'])) > 1:
                            unexplained += 1
                        prev_t = t
            del tl
    chk('owner appears before the horn', bad == 0 and pre_owner > 0,
        'owners=%d copies=%d violations=%d' % (pre_owner, post_copy, bad))
    chk('a corpse never moves inside one dead stretch',
        corpses > 0 and unexplained == 0,
        'dead stretches=%d moves=%d recycled idx runs=%d'
        % (corpses, unexplained, recycled))
    # 2b. The run split must not LOSE a live frame.  This is the assertion
    #     that actually pins the recycle handling: a one-span `alive_runs`
    #     (the shape this tool had before 2026-09-18) passes every other check
    #     here and silently drops the second occupant of a recycled idx.
    live_total = live_in_runs = 0
    for d in dirs:
        for row in load_sweep(d):
            p = os.path.join(d, 'timelines', row['game'] + '.timeline.json')
            if not os.path.exists(p):
                continue
            tl = load(p)
            for (hero, pid), idxs in group_units(tl).items():
                if len(idxs) < 2:
                    continue
                owner = min(idxs, key=lambda i: min(idxs[i]))
                for i, frames in idxs.items():
                    if i == owner:
                        continue
                    live = [t for t in frames if frames[t]['hp_pct'] > 0]
                    live_total += len(live)
                    runs = alive_runs(frames)
                    live_in_runs += sum(1 for t in live
                                        if any(a <= t < b for a, b in runs))
            del tl
    chk('every live copy frame lies inside some run',
        live_total > 0 and live_in_runs == live_total,
        'live=%d covered=%d' % (live_total, live_in_runs))
    # 3. Every reported frame really is inside the hp cut and really has a
    #    live copy -- the domain definition, asserted rather than trusted.
    rows = [r for g in res for r in g['rows']]
    chk('every row has owner hp in (0, cut)',
        all(0 < r['owner_hp'] < HP_CUT for r in rows), 'rows=%d' % len(rows))
    chk('no row is a naga/phantom_lancer copy',
        all(r['hero'] not in FIELD_SETTERS for r in rows))
    # 4. Both legs are populated by the manifest, not by chance: every game
    #    must declare a side, and both sides must appear in the corpus.
    sides = {g['side'] for g in res}
    chk('both strata present in corpus', sides == {'radiant', 'dire'},
        'sides=%s' % sorted(sides))
    # 5. A `no_window` row must be one whose copy dies inside the window --
    #    otherwise the lookahead is dropping frames it could have read.
    bad_nw = [r for r in rows if r['verdict'] == 'no_window' and r['ttl'] > WINDOW + 1.0]
    chk('no_window only where the copy dies inside the window',
        not bad_nw, 'offenders=%d' % len(bad_nw))
    # 6. The instrument must be able to SEE a move: at least one copy somewhere
    #    in the corpus moves >= MOVE_U in WINDOW while alive (positive control
    #    for the threshold itself -- a threshold nothing ever clears measures
    #    nothing).
    seen = 0
    for d in dirs:
        for row in load_sweep(d):
            p = os.path.join(d, 'timelines', row['game'] + '.timeline.json')
            if not os.path.exists(p) or seen:
                continue
            tl = load(p)
            for (hero, pid), idxs in group_units(tl).items():
                if len(idxs) < 2 or seen:
                    continue
                owner = min(idxs, key=lambda i: min(idxs[i]))
                for i, frames in idxs.items():
                    if i == owner:
                        continue
                    ts = sorted(t for t in frames if frames[t]['hp_pct'] > 0)
                    for t in ts:
                        tn = round(t + WINDOW, 1)
                        if tn in frames and frames[tn]['hp_pct'] > 0:
                            if math.dist((frames[t]['x'], frames[t]['y']),
                                         (frames[tn]['x'], frames[tn]['y'])) >= MOVE_U:
                                seen += 1
                                break
                    if seen:
                        break
            del tl
    chk('threshold is clearable by a real copy', seen > 0, 'witness=%d' % seen)
    print('\n%s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dirs', nargs='+')
    ap.add_argument('--frames', action='store_true')
    ap.add_argument('--limit', type=int, default=40)
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--out')
    a = ap.parse_args()
    res = scan(a.dirs)
    if a.selfcheck:
        sys.exit(0 if selfcheck(res, a.dirs) else 1)
    report(res, frames=a.frames, limit=a.limit)
    if a.out:
        with open(a.out, 'w') as fh:
            json.dump(res, fh, indent=1)
        print('\nwrote %s' % a.out)


if __name__ == '__main__':
    main()
