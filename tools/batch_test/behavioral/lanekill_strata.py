#!/usr/bin/env python3
"""Iron-rule-4 (i-a)/(i-e) strata reading for the lane-kill pair.

WHY THIS EXISTS (replay-check 2026-09-17, owed row `lanekill_condition_a_detector`)
-----------------------------------------------------------------------------
`lanekill_commit.py` answers the (a) question -- did `l1trade` / `l5combo`
actually drive a lane commit in a WAVE REPLAY -- but it splits its rows only by
`armed` and by `seed`.  The owed row's acceptance sentence additionally demands
the two STRATA readings (iron rule 4 (i-a)): the armed leg sat on the radiant
team in some runs and on the dire team in others, and a reading that pools the
two hides the roster term.

This script is a thin reader over `lanekill_commit.scan()` -- it re-uses that
scanner verbatim (same domain, same constants, same #78 hygiene) and only adds:

  * `arm_side`   -- which PHYSICAL team carried the armed leg in that game,
                    read from the `mirror:...:<seed>:<side>` stamp;
  * both strata deltas, registered per (i-a) whether or not they agree;
  * the paired arm estimator from `strata.py` (per-seed swap-average first,
    THEN the arithmetic mean across seeds -- (i-d)), formed on SHARES because
    the observable here is a share of episodes, not a per-game count.

⛔ It does NOT re-derive the domain, and it must never grow one: if the domain
is wrong it is wrong in `lanekill_commit.py`, and two copies of a domain is the
failure mode §BW.3 is about.

⚠️ The superset boundary of `lanekill_commit.py` is inherited unchanged:
`GetEstimatedDamageToTarget` is not in the dumper stream, so the LETHALITY and
SELF-RISK conjuncts cannot be evaluated offline and every episode here is a
SUPERSET of the frames the gate really fired on.  Quote that in any report.

Usage:  lanekill_strata.py <sweep_out_dir> [<sweep_out_dir> ...]
Read-only; no AWS, no billable resource.
"""
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lanekill_commit import scan                      # noqa: E402
from roam_conversion import load_game                 # noqa: E402
import strata                                         # noqa: E402

BANDS = ('ACTIVE', 'VETO', 'OUT')
MEASURES = ('commit', 'commit_attack', 'kill', 'switch', 'creep', 'no_dmg')


def collect(dirs):
    """-> (records, ngames_by_seed, games, drops)

    `records` are one dict per episode carrying the keys `strata.py` wants
    (`seed`, `arm_side`, `leg`) plus the measures.
    """
    records = []
    ngames = collections.Counter()
    games = 0
    drops = collections.Counter()
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
                continue                       # warmup: no `mirror:` stamp
            sv = json.load(open(aj)).get('script_version', '')
            arm_side = sv.rsplit(':', 1)[-1]
            seed = sv.split(':')[-2]
            g['run'] = os.path.basename(os.path.normpath(d))[:24]
            g['game'] = stem
            g['seed'] = seed
            games += 1
            ngames[(seed, arm_side)] += 1
            for r in scan(g, drops):
                r['arm_side'] = arm_side
                r['leg'] = 'armed' if r['armed'] else 'baseline'
                records.append(r)
    return records, ngames, games, drops


def share(rows, key):
    return (sum(1 for r in rows if r[key]) / float(len(rows))) if rows else None


def stratum_rows(records, branch, band, side, leg):
    return [r for r in records if r['branch'] == branch and r['band'] == band
            and r['arm_side'] == side and r['leg'] == leg]


def report(records, ngames, games, drops):
    print(f'games={games}  episodes={len(records)}')
    print('games by (seed, arm_side): '
          + ', '.join(f'{s}/{sd}={n}' for (s, sd), n in sorted(ngames.items())))
    paired, seeds, unpaired = strata.pairing(records, ngames)
    print(f'pairing: paired={paired}  seeds={seeds}  unpaired={unpaired}')
    print('[#78] corpse snapshots let through by hp_pct>0: '
          f"{drops['corpse_leaked_by_hp_proxy']} "
          f"(armed {drops['corpse_armed']} / baseline {drops['corpse_base']}); "
          'episodes dropped, actor died in window: '
          f"{drops['actor_died_in_window']} "
          f"(armed {drops['actordie_armed']} / baseline {drops['actordie_base']})")

    for branch in ('l1trade', 'l5combo'):
        for band in BANDS:
            any_rows = [r for r in records
                        if r['branch'] == branch and r['band'] == band]
            if not any_rows:
                continue
            print(f'\n=== [{branch}] {band}')
            # (i-a): BOTH strata readings are registered, always.
            for side in ('radiant', 'dire'):
                a = stratum_rows(records, branch, band, side, 'armed')
                b = stratum_rows(records, branch, band, side, 'baseline')
                head = f'  arm_side={side:7} n_armed={len(a):4} n_base={len(b):4}'
                cells = []
                for k in MEASURES:
                    sa, sb = share(a, k), share(b, k)
                    if sa is None or sb is None:
                        cells.append(f'{k}=n/a')
                    else:
                        cells.append(f'{k}={sa:.3f}/{sb:.3f} d={sa-sb:+.3f}')
                print(head + '  ' + '  '.join(cells))
            # (i-e)(甲)+(i-d): the estimator is the per-seed swap-average of
            # the two strata deltas, then the arithmetic mean across seeds.
            # ⭐ Computed for the CONTROL bands too, not just ACTIVE: a control
            # band is only a control if it is read with the same estimator.
            # `VETO` is the band where the l5combo gate is provably false and
            # `OUT` the band where both helpers hard `return nil`, so an arm of
            # the same size there is the reading that kills an ACTIVE arm.
            # A per-GAME count, not a share: how often the branch's own
            # geometry occurred at all.  A gate that drives collapses should
            # MAKE this geometry, so the count is the one observable that is
            # about the decision rather than about what followed it.  (i-d)
            # divides by games, which is why it uses `per_seed_arm`.
            cnt = strata.per_seed_arm(
                records, ngames,
                pred=lambda r, b=branch, bd=band: (r['branch'] == b
                                                   and r['band'] == bd))
            if cnt is None:
                print('  arm[episodes/game] = n/a (corpus not paired)')
            else:
                per = ', '.join(f"{p['seed']}:{p['arm']:+.3f}"
                                for p in cnt['per_seed'])
                sp = ('n/a' if cnt['spread'] is None else f"{cnt['spread']:.3f}")
                print(f"  arm[episodes/game] = {cnt['arm']:+.4f}  "
                      f"n_seeds={cnt['n_seeds']}  spread={sp}  "
                      f"seeds_better={cnt['seeds_better']}  per_seed[{per}]")
            for k in MEASURES:
                res = strata.per_seed_share_arm(
                    records, ngames,
                    pred_num=lambda r, k=k: bool(r[k]),
                    pred_den=lambda r, b=branch, bd=band: (r['branch'] == b
                                                           and r['band'] == bd))
                if res is None:
                    print(f'  arm[{k}] = n/a (corpus not paired, or an empty '
                          f'denominator in one stratum) -- stays in (i-b)')
                    continue
                per = ', '.join(f"{p['seed']}:{p['arm']:+.3f}"
                                for p in res['per_seed'])
                sp = ('n/a' if res['spread'] is None else f"{res['spread']:.3f}")
                print(f"  arm[{k}] = {res['arm']:+.4f}  n_seeds={res['n_seeds']}"
                      f"  spread={sp}  seeds_better={res['seeds_better']}"
                      f"  per_seed[{per}]"
                      + (f"  skipped={res['skipped']}" if res.get('skipped') else ''))


def main():
    dirs = [a for a in sys.argv[1:] if not a.startswith('-')]
    if not dirs:
        print(__doc__)
        return 2
    records, ngames, games, drops = collect(dirs)
    report(records, ngames, games, drops)
    return 0


if __name__ == '__main__':
    sys.exit(main())
