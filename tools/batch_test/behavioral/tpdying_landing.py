#!/usr/bin/env python3
"""Landing-commitment tracer for the `tpcommit` floor and its `tpdying` release.

Written for replay-check's condition-(a) verification of `tpdying` (GH #35,
test_set.md section A'), 2026-08-20.  Read-only: consumes the dumper timeline +
analysis.json that sweep_run.sh already produces.  Launches nothing, costs
nothing.

WHAT IS BEING MEASURED
----------------------
`J.GetTpCommitDefendDesire` (jmz_func.lua) bids a 0.85 DEFEND floor for the lane
a TP answered, for the 12s after the cast.  Every defend TP stamps it -- the
rescue branch, the midtp tower-fight branch and the SHIPPED defend TP all write
bot.tpRespondLoc / tpRespondUntil (ability_item_usage_generic.lua:5106/5128/5310)
-- so the pinned population is "defend TPs", not just the gated rescues that
tp_attribution.py isolates for GH #37.

The floor has three releases, in source order:
  1. HP < 40%  or  J.ShouldRetreatLaneBurst   (shipped inside `tpcommit`)
  2. `tpdying`: J.IsIncomingBurstLethal(bot, 3.0)
  3. `tpdead` : the stamped rescue ally is a corpse

Release 1's anticipatory half is structurally dead here: ShouldRetreatLaneBurst
returns false outside the laning phase (its own third line), and this floor is
overwhelmingly reached after it -- which is the entire argument for `tpdying`.
So the id's own domain is: POST-LANING, HP >= 40%, burst already lethal.

OFFLINE BOUNDARY (do not paper over this)
-----------------------------------------
GetEstimatedDamageToTarget is not in the replay, so IsIncomingBurstLethal cannot
be evaluated exactly -- the same gap that bounds tp_attribution.py and
cmrguard_counterfactual.py.  Two substitutes are used, both stated as what they
are:

  * THREAT (superset of the gate's domain): >= 1 living enemy hero within 1100u,
    the same radius J.GetNearbyHeroes uses inside the predicate.  Every real
    trigger is inside this set; most of this set is not a real trigger.
  * REALIZED-LETHAL (ground truth, strict subset of "the gate should have
    fired"): the pinned hero is dead within 3.0s of the frame.  Whatever the
    engine estimated, the burst on the board was in fact >= its health.  A frame
    that is realized-lethal and still pinned is the pathology `tpdying` was
    written against, observed rather than modelled.

The pin itself is not in the replay either; what IS observable is its intended
consequence -- staying put at the answered spot.  "Pinned" here means displaced
< 500u from the landing point, the same shape the wave12 dossier charged
("static <500u for 5s+ under fire, literal zero output").

Baseline games have no `tpcommit` at all, so their landers are never pinned;
the cand-vs-base split therefore measures tpcommit+tpdying jointly.  Condition
(a) for `tpdying` alone has to come from the candidate-side frame listing.

Usage:
  tpdying_landing.py <sweep_out_dir> [<sweep_out_dir> ...] [--json out.jsonl]
                     [--post-laning 480] [--radius 1100] [--pin-radius 500]
where <sweep_out_dir> is a sweep_run.sh output directory (timelines/ +
analysis/ + games_manifest.jsonl).
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from roam_conversion import load_game, dist  # noqa: E402

RAD, DIRE = 2, 3
FOUNTAIN = {RAD: (-7200.0, -6666.0), DIRE: (7000.0, 6500.0)}

# A TP that lands next to my own fountain is a trip home, not an answer to
# anything; the floor's stamp sites are all destination-side.
HOME_TP_RADIUS = 2500.0
# The engine hands out the scroll's 3s channel; landings show up as a >1500u
# jump between two 1Hz snapshots.
JUMP = 1500.0
COMMIT = 12.0          # DotaTime() + 12.0 at every stamp site
LETHAL_HORIZON = 3.0   # J.IsIncomingBurstLethal(bot, 3.0) as the floor calls it


def in_pause(t, pauses):
    return any(a < t < b for a, b in pauses)


def scan_game(g, game, seed, post_laning, radius, pin_radius):
    tl = g['tl']
    frames = g['frames']
    pauses = g['pauses']
    teams = tl['game']['teams']
    armed_team = g['armed_team']
    times = sorted(frames)

    deaths = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] == 'DEATH':
            deaths[e['target']].append(e['t'])

    by_hero = collections.defaultdict(dict)
    for t in times:
        for s in frames[t]:
            by_hero[s['hero']][t] = s

    def at(hero, t, tol=1.2):
        arr = by_hero.get(hero)
        if not arr:
            return None
        best, bt = None, None
        for ft in times:
            if ft > t + 0.01:
                break
            if ft in arr:
                best, bt = arr[ft], ft
        if best is not None and t - bt <= tol:
            return best
        for ft in times:
            if abs(ft - t) <= tol and ft in arr:
                return arr[ft]
        return None

    def died_between(h, lo, hi):
        return any(lo <= x <= hi for x in deaths[h])

    out = []
    for e in tl['events']:
        if e['type'] != 'ITEM' or e.get('inflictor') != 'item_tpscroll':
            continue
        h = e['actor']
        team = teams.get(h)
        if team is None:
            continue
        t0 = e['t']
        if in_pause(t0, pauses):
            continue
        cs = at(h, t0)
        if cs is None or cs.get('hp_pct', 0) <= 0:
            continue

        land = None
        for ft in times:
            if ft <= t0 + 2.0 or ft > t0 + 7.5:
                continue
            s = by_hero[h].get(ft)
            if s is None or s.get('hp_pct', 0) <= 0:
                continue
            if dist(s, cs) > JUMP:
                land = s
                break
        if land is None:
            continue  # channel eaten, or the scroll went somewhere <1500u away

        fx, fy = FOUNTAIN[team]
        d_home = math.hypot(land['x'] - fx, land['y'] - fy)
        if d_home < HOME_TP_RADIUS:
            continue  # trip home; no stamp site writes this

        t_land = land['t']
        t_until = t0 + COMMIT
        anchor = land

        # --- walk the commitment window frame by frame -------------------
        win = []
        for ft in times:
            if ft < t_land or ft > t_until or in_pause(ft, pauses):
                continue
            s = by_hero[h].get(ft)
            if s is None or s.get('hp_pct', 0) <= 0:
                continue
            foes = [o for o in frames[ft]
                    if teams.get(o['hero']) not in (None, team)
                    and o.get('hp_pct', 0) > 0
                    and dist(o, s) <= radius]
            win.append(dict(
                t=ft,
                hp=round(s['hp_pct'], 3),
                d_anchor=round(dist(s, anchor)),
                n_foe=len(foes),
                nearest_foe=round(min((dist(o, s) for o in foes), default=-1)),
                # realized ground truth: the burst on the board WAS lethal
                lethal=died_between(h, ft, ft + LETHAL_HORIZON),
            ))

        # longest consecutive run of pinned-and-threatened frames
        best_run, run, run_start = 0.0, [], None
        for f in win:
            if f['n_foe'] >= 1 and f['d_anchor'] < pin_radius:
                if run_start is None:
                    run_start = f['t']
                run.append(f)
                best_run = max(best_run, f['t'] - run_start)
            else:
                run, run_start = [], None

        # the id's own domain: post-laning, HP >= 40% (clause 1 silent),
        # threatened, still parked at the answered spot.
        dom = [f for f in win
               if f['t'] > post_laning and f['hp'] >= 0.40
               and f['n_foe'] >= 1 and f['d_anchor'] < pin_radius]
        # of those, the ones where the engine's estimate must have been lethal
        dom_lethal = [f for f in dom if f['lethal']]

        out.append(dict(
            game=game, seed=seed, hero=h,
            side='cand' if team == armed_team else 'base',
            t_cast=round(t0, 1), t_land=round(t_land, 1),
            hp_land=round(land['hp_pct'], 3),
            post_laning=t_land > post_laning,
            n_win_frames=len(win),
            pinned_threat_run=round(best_run, 1),
            died_10s=died_between(h, t_land, t_land + 10.0),
            # 15s, not 10s: the 12s commitment plus a step out of it. The
            # sharpest case in the 10:11Z wave (103644 necrolyte) died at
            # land+12.1s -- a 10s window scores that landing as a survivor and
            # hides the very episode the id exists for.
            died_15s=died_between(h, t_land, t_land + 15.0),
            died_window=died_between(h, t_land, t_until),
            dom_frames=len(dom),
            dom_lethal=len(dom_lethal),
            first_dom_lethal_t=(round(dom_lethal[0]['t'], 1) if dom_lethal else None),
            win=win,
        ))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dirs', nargs='+')
    ap.add_argument('--json')
    ap.add_argument('--post-laning', type=float, default=480.0,
                    help='turbo laning floor; ShouldRetreatLaneBurst is dead past it')
    ap.add_argument('--radius', type=float, default=1100.0)
    ap.add_argument('--pin-radius', type=float, default=500.0)
    a = ap.parse_args()

    eps, games = [], 0
    for d in a.dirs:
        for mf in glob.glob(os.path.join(d, 'games_manifest.jsonl')):
            for line in open(mf):
                m = json.loads(line)
                name = m['game']
                tlp = os.path.join(d, 'timelines', name + '.timeline.json')
                ajp = os.path.join(d, 'analysis', name + '.analysis.json')
                if not (os.path.exists(tlp) and os.path.exists(ajp)):
                    continue
                g = load_game(tlp, ajp)
                if g is None:
                    continue
                games += 1
                eps += scan_game(g, name, m.get('seed'), a.post_laning,
                                 a.radius, a.pin_radius)

    if a.json:
        with open(a.json, 'w') as fh:
            for e in eps:
                fh.write(json.dumps(e) + '\n')

    def agg(rows):
        n = len(rows)
        if n == 0:
            return dict(n=0)
        return dict(
            n=n,
            died_10s='%d (%.1f%%)' % (sum(r['died_10s'] for r in rows),
                                      100.0 * sum(r['died_10s'] for r in rows) / n),
            died_15s='%d (%.1f%%)' % (sum(r['died_15s'] for r in rows),
                                      100.0 * sum(r['died_15s'] for r in rows) / n),
            died_window='%d (%.1f%%)' % (sum(r['died_window'] for r in rows),
                                         100.0 * sum(r['died_window'] for r in rows) / n),
            pinned5s='%d (%.1f%%)' % (sum(r['pinned_threat_run'] >= 5.0 for r in rows),
                                      100.0 * sum(r['pinned_threat_run'] >= 5.0 for r in rows) / n),
            dom_frames=sum(r['dom_frames'] for r in rows),
            dom_lethal=sum(r['dom_lethal'] for r in rows),
        )

    print('games=%d  defend-TP landings=%d' % (games, len(eps)))
    for label, sel in (('ALL', lambda r: True),
                       ('post-laning only', lambda r: r['post_laning'])):
        print('\n== %s' % label)
        for side in ('cand', 'base'):
            rows = [r for r in eps if r['side'] == side and sel(r)]
            print('  %-5s %s' % (side, json.dumps(agg(rows))))


if __name__ == '__main__':
    main()
