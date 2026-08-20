#!/usr/bin/env python3
"""item_build_diff.py -- armed-vs-baseline differ for ITEM BUILD gates.

Answers the condition-(a) question for any soak candidate that reorders or
rewrites a hero's `sRoleItemsBuyList` (today: `axebuyblink`):

  1. did the hero ever HOLD the target item, and at what game-clock second?
  2. what did the reorder cost -- how long did the hero go with NO item
     progression at all, because the promoted item has no components and has
     to be saved for as a lump sum?

Both are read straight off `behav-dump`'s 1 Hz `snapshots[].items`, cross-keyed
to the mirror stamp in the matching `*.analysis.json` so each game is labelled
ARMED / BASE / WARM without any hand-maintained mapping table.

Usage
-----
    python3 item_build_diff.py --root <dir> --hero axe --item blink_dagger

`--root` holds one subdirectory per run, each with the run's `*.json`
timelines (from `behav-dump <dem>`) and the matching `*.analysis.json`.

Boundaries (do NOT let a caller forget these)
---------------------------------------------
* The dump carries the INVENTORY + backpack only. An item bought but sitting
  in the stash (courier dead / not sent) reads as "never held". Rule it out
  per game the way 20260820 did: net_worth minus the summed value of the held
  items never crosses the target item's cost.
* `net_worth` is items + unspent gold, so a purchase is net-worth-neutral;
  the idle-gold estimate below is arithmetic on a small price table and is
  approximate by construction -- quote it as "~", never as a measurement.
* 1 Hz sampling: acquisition times are +-1s.
* Frames where the hero is dead come back with an EMPTY item list; they are
  skipped, otherwise every respawn reads as "re-acquired everything".
* Post-game freeze (issue #43): samples past the last real event are dropped.
* Consumables are excluded from "progression" -- `fieldregen` buys flasks on
  the armed side (measured 2.17/game vs 1.17), which would otherwise show up
  as the armed side buying MORE.

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.
"""

import argparse
import collections
import glob
import json
import os
import statistics

CONSUMABLE = {
    'tango', 'tango_single', 'flask', 'clarity', 'ward_observer', 'ward_sentry',
    'tpscroll', 'smoke_of_deceit', 'enchanted_mango', 'faerie_fire', 'dust',
    'bottle', 'cheese', 'aegis',
}

# Rough shop prices, only used for the "~idle gold" hint. Extend as needed.
PRICE = {
    'blink_dagger': 2250, 'power_treads': 1400, 'boots_of_speed': 500,
    'bracer': 505, 'quelling_blade': 130, 'magic_wand': 450, 'magic_stick': 200,
    'belt_of_strength': 450, 'gauntlets': 90, 'circlet': 155,
    'ironwood_branch': 50, 'vitality_booster': 1100, 'vanguard': 1900,
    'helm_of_iron_will': 950, 'crimson_guard': 3600, 'broadsword': 1000,
    'splint_mail': 800, 'blade_mail': 2200, 'flask': 110, 'tango': 90,
    'tango_single': 30, 'clarity': 50,
}


def load_games(root):
    for run in sorted(os.listdir(root)):
        rdir = os.path.join(root, run)
        if not os.path.isdir(rdir):
            continue
        for tlf in sorted(glob.glob(os.path.join(rdir, '*.json'))):
            if tlf.endswith('.analysis.json'):
                continue
            base = os.path.basename(tlf)[:-5]
            ajf = os.path.join(rdir, base + '.analysis.json')
            if not os.path.exists(ajf):
                continue
            yield run, base, json.load(open(tlf)), json.load(open(ajf))


def analyse(tl, aj, hero, item):
    sv = aj.get('script_version', '')
    warm = not sv.startswith('mirror:')
    seed = side = '-'
    if not warm:
        _, _cand, seed, side = sv.split(':', 3)

    # issue #43: every game ends with a ~24s frozen post-game tail.
    tmax = max(e['t'] for e in tl['events']) if tl['events'] else float('inf')

    snaps = sorted((s for s in tl['snapshots']
                    if s['hero'].replace('npc_dota_hero_', '') == hero),
                   key=lambda s: s['t'])
    if not snaps:
        return None
    team = snaps[0]['team']
    armed = (not warm) and ((side == 'radiant' and team == 2)
                            or (side == 'dire' and team == 3))

    ever, acq, t_item = set(), [], None
    last_held, last_nw = [], None
    for s in snaps:
        if s['t'] > tmax:
            break
        held = [i for i in (s.get('items') or []) if i]
        if not held:                      # dead / not yet spawned
            continue
        last_held, last_nw = held, s.get('net_worth')
        for i in held:
            if i not in ever:
                ever.add(i)
                acq.append((round(s['t'], 1), i, s.get('net_worth')))
        if t_item is None and item in held:
            t_item = round(s['t'], 1)

    prog = [(t, i, nw) for t, i, nw in acq if i not in CONSUMABLE and t > -30]
    marks = [0.0] + [t for t, _i, _nw in prog if 0 <= t <= tmax] + [tmax]
    gap, gstart, gend = max((marks[k + 1] - marks[k], marks[k], marks[k + 1])
                            for k in range(len(marks) - 1))

    idle = None
    if last_nw is not None:
        idle = last_nw - sum(PRICE.get(i, 0) for i in last_held)

    casts = [e for e in tl['events']
             if e.get('type') == 'ITEM'
             and str(e.get('inflictor', '')).replace('item_', '') in (item, item.replace('_dagger', ''))
             and str(e.get('actor', '')).replace('npc_dota_hero_', '') == hero]

    return dict(warm=warm, armed=armed, seed=seed, side=side,
                dur=round(tmax, 1), t_item=t_item, n_prog=len(prog),
                gap=round(gap, 1), gap_span=(round(gstart, 1), round(gend, 1)),
                idle_gold_end=idle, casts=len(casts), prog=prog)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', required=True)
    ap.add_argument('--hero', required=True)
    ap.add_argument('--item', required=True)
    ap.add_argument('--seq', action='store_true', help='print the buy sequence per game')
    a = ap.parse_args()

    groups = collections.defaultdict(list)
    print(f"{'tag':6}{'run':8}{'game':16}{'seed':6}{'dur':>7}{'t_item':>8}"
          f"{'maxgap':>8}{'span':>16}{'prog':>5}{'casts':>6}{'~idle_g':>8}")
    for run, base, tl, aj in load_games(a.root):
        r = analyse(tl, aj, a.hero, a.item)
        if r is None:
            print(f"{'--':6}{run:8}{base:16}  no {a.hero} in this game")
            continue
        tag = 'WARM' if r['warm'] else ('ARMED' if r['armed'] else 'BASE')
        groups[tag].append(r)
        span = f"[{r['gap_span'][0]}-{r['gap_span'][1]}]"
        print(f"{tag:6}{run:8}{base:16}{r['seed']:6}{r['dur']:7}"
              f"{str(r['t_item']):>8}{r['gap']:8}{span:>16}{r['n_prog']:5}"
              f"{r['casts']:6}{str(r['idle_gold_end']):>8}")
        if a.seq:
            for t, i, nw in r['prog']:
                print(f'        {t:>7} nw={nw:<6} {i}')

    print()
    for tag in ('ARMED', 'BASE', 'WARM'):
        g = groups.get(tag)
        if not g:
            continue
        print(f"{tag}: n={len(g)}  held {a.item} {sum(1 for r in g if r['t_item'])}/{len(g)}"
              f"  mean t_item={_mean([r['t_item'] for r in g if r['t_item']])}"
              f"  mean maxgap={_mean([r['gap'] for r in g])}"
              f"  mean prog buys={_mean([r['n_prog'] for r in g])}"
              f"  casts={sum(r['casts'] for r in g)}")


def _mean(v):
    return round(statistics.mean(v), 1) if v else None


if __name__ == '__main__':
    main()
