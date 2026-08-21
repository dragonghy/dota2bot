#!/usr/bin/env python3
"""Audit the `hp_pct > 0` liveness proxy's LEAK TAIL on a corpus.

WHY THIS EXISTS (GH `[bug] #78`, director ruling 2026-08-21T05:00Z section Z.1)
------------------------------------------------------------------------------
Every detector in this directory used to test liveness with `hp_pct > 0`.  #78
established that this is a PROXY: the dumper keeps emitting snapshots for a
dead hero, and the first one at/after the DEATH event can still carry the last
LIVE sample.  `roam_conversion.death_spans()` / `is_dead()` replaced the proxy
with event-based death spans, and each detector was then re-read on corpus.

`capmono_refusal.py` came back 0/806 -- clean -- and the note explaining WHY
said the leak band (recorded as hp 0.005..0.29) is disjoint from capmono's
actor band [0.42,0.50].  The director downgraded that from "immune by
construction" to "measured disjointness" and asked for the one column that
decides whether the margin is real: not the MAX of the leak values but their
TAIL -- p95/p99 and the count above 0.20.  "A lone 0.29 over a p99 of ~0.05 is
a real margin; mass piled near 0.29 means 0.42 is one burst draft away."

This script computes that column.  Answer on the 1609xx/1807xx 32-game corpus
(2026-08-21T06:3xZ): the second branch.  See "MEASURED" below.

DEFINITIONS THAT MATTER
-----------------------
A leak = a snapshot inside a death span whose hp_pct still reads > 0.  Death
spans come from `roam_conversion.death_spans()` (DEATH event -> revival),
which is the SAME liveness definition the detectors ship with, so this audits
the filter as deployed rather than a private reconstruction.

The leaks split into two populations and CONFLATING THEM IS THE ERROR that put
0.29 in the record:

  * lag > 0  -- the snapshot is strictly after the DEATH event.  These are
                DEMONSTRATED proxy failures: ground truth is unambiguous.
  * lag == 0 -- the snapshot's timestamp equals the DEATH event's timestamp.
                Within one 0.1s tick the order is NOT observable, so these are
                not demonstrated failures.  But `is_dead()`'s window is
                `a <= t < b`, so THE SHIPPED FILTER COUNTS THEM AS DEAD, and
                any band argument about the shipped filter has to include them.

Report both, separately, always.  A one-number answer to "how high does the
leak go" is a question about which convention you meant.

MEASURED (940 death spans, 19207 corpse frames, 235 leaks; 40 games, 32 mirror)
------------------------------------------------------------------------------
  proxy correct on corpse frames  98.78%   (18972/19207 read exactly 0.0)
  leak frames per death           0.250    (recorded 0.24 -- REPRODUCES)
  max lag after DEATH             0.30s    (recorded 0.30 -- REPRODUCES)

  lag > 0   n=135  p50 0.043  p95 0.241  p99 0.370  max 0.386
                   >0.20: 9 (6.7%)   >0.30: 4   >0.42: 0
  lag == 0  n=100  p50 0.064  p95 0.264  p99 0.437  max 0.517
                   >0.20: 12         >0.30: 4   >0.42: 2

So the RATE and the TIMING in the record both reproduce; the VALUE RANGE
("0.005 .. 0.29, all <= 0.40") does not.  p99 is 0.370, not ~0.05.  Under the
shipped filter's own convention the band reaches 0.517 and 0.437 sits INSIDE
[0.42,0.50]; under the strict convention the margin to 0.42 is 0.034.

Both frames above 0.42 are Lion's Finger of Death -- the exact mechanism
`capmono_refusal`'s docstring predicted ("leak > 0.42 needs only a hero going
from >42% to dead inside one 0.5s interval -- available burst, i.e. a
draft/patch property"):

  20260820_183451_slot1  zuus           hp 0.437  DEATH t=540.50  Finger v=459
  20260820_181738_slot1  crystal_maiden hp 0.517  DEATH t=276.40  Finger v=334

In both, the killing cast and the DEATH are stamped on the snapshot's own 0.1s
tick and the next snapshot reads 0.000.

WHAT THIS DOES AND DOES NOT OVERTURN
------------------------------------
Does NOT: capmono's 0/806, which was measured directly, not derived from the
band; nor `death_spans()`'s 1.5s no-jump revival guard, which needs the LAG
bound (max 0.30s, 5x margin) and that bound reproduced.

DOES: the band-disjointness ARGUMENT, and the size of the margin.  Do not
re-derive "this detector's selection band cannot contain a corpse" from leak
geometry on a corpus containing any one-cast nuke.

USAGE
-----
    python3 leak_tail.py <root>

<root> holds <root>/tl/<run>/<game>.json (dumper timelines) and
<root>/corpus/<run>/<game>.analysis.json, per-run subdirectories (charter:
`.dem` basenames collide across runs and flatten silently).
"""
import collections
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roam_conversion as RC  # noqa: E402

# Leaks above this are the ones that can reach a mid-HP selection band.
REPORT_THRESHOLDS = (0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.42)


def collect(root):
    """Yield one row per leaked frame, plus corpus counters."""
    rows = []
    n_spans = n_corpse = n_zero = n_open = 0
    n_games = n_mirror = 0

    for run in sorted(os.listdir(os.path.join(root, 'tl'))):
        for tlf in sorted(glob.glob(os.path.join(root, 'tl', run, '*.json'))):
            base = os.path.basename(tlf)[:-5]
            ajf = os.path.join(root, 'corpus', run, base + '.analysis.json')
            if not os.path.exists(ajf):
                continue
            mirror = json.load(open(ajf)).get('script_version', '').startswith('mirror:')
            tl = json.load(open(tlf))
            n_games += 1
            n_mirror += bool(mirror)

            # Illusions share the class name; lock each hero to its real entity
            # (charter tool-trap) before anything else touches the snapshots.
            seen = collections.Counter((s['hero'], s['idx']) for s in tl['snapshots'])
            real = {}
            for (h, i), n in seen.items():
                if h not in real or n > real[h][1]:
                    real[h] = (i, n)
            real_idx = {h: v[0] for h, v in real.items()}

            # #43: the dumper emits a frozen 24-25s tail past the last event.
            t_end = max(e['t'] for e in tl['events'])

            by_hero = collections.defaultdict(list)
            for s in tl['snapshots']:
                if real_idx.get(s['hero']) == s['idx'] and s['t'] <= t_end:
                    by_hero[s['hero']].append(s)
            for h in by_hero:
                by_hero[h].sort(key=lambda s: s['t'])

            for hero, spans in RC.death_spans(tl, real_idx).items():
                for (td, tr) in spans:
                    n_spans += 1
                    n_open += (tr == float('inf'))
                    for s in by_hero.get(hero, ()):
                        if not (td <= s['t'] < tr):
                            continue
                        n_corpse += 1
                        if s['hp_pct'] > 0:
                            rows.append({
                                'run': run, 'game': base, 'mirror': mirror,
                                'hero': hero, 'hp': s['hp_pct'],
                                'lag': round(s['t'] - td, 2),
                                't': s['t'], 'td': td,
                            })
                        else:
                            n_zero += 1
    return rows, dict(spans=n_spans, corpse=n_corpse, zero=n_zero,
                      open=n_open, games=n_games, mirror=n_mirror)


def tail(vals, label):
    vals = sorted(vals)
    n = len(vals)
    if not n:
        print(f'  {label}: n=0')
        return
    q = lambda p: vals[min(n - 1, int(round(p * (n - 1))))]  # noqa: E731
    print(f'  {label}: n={n:4d}  p50={q(.50):.3f} p90={q(.90):.3f} '
          f'p95={q(.95):.3f} p99={q(.99):.3f} max={vals[-1]:.3f}')
    hits = '  '.join(f'>{t:.2f}:{sum(1 for v in vals if v > t)}'
                     for t in REPORT_THRESHOLDS)
    print(f'        {hits}')


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    rows, c = collect(root)

    print('=== corpus ===')
    print(f"games {c['games']} (mirror {c['mirror']});  death spans {c['spans']} "
          f"(never-closed {c['open']})")
    print(f"corpse frames {c['corpse']};  exact-zero {c['zero']};  LEAKED {len(rows)}")
    print(f"proxy correct on corpse frames: "
          f"{100.0 * c['zero'] / max(1, c['corpse']):.2f}%")
    print(f"leak frames per death: {len(rows) / max(1, c['spans']):.3f}  "
          f"(record: 0.24)")

    for scope, keep in (('ALL games', lambda r: True),
                        ('MIRROR only', lambda r: r['mirror'])):
        sub = [r for r in rows if keep(r)]
        print(f'\n=== leak-value tail -- {scope} ===')
        tail([r['hp'] for r in sub if r['lag'] > 0.0], 'DEMONSTRATED (lag>0) ')
        tail([r['hp'] for r in sub if r['lag'] == 0.0], 'TICK-AMBIGUOUS lag==0')

    lags = sorted(r['lag'] for r in rows)
    print(f'\n=== lag after DEATH (s) ===  max={lags[-1] if lags else 0:.2f} '
          f'(record: 0.30; death_spans() 1.5s revive guard needs this bound)')
    print('  histogram:', sorted(collections.Counter(lags).items()))

    print('\n=== leaks above 0.30, with provenance (hand-verify these) ===')
    for r in sorted((r for r in rows if r['hp'] > 0.30), key=lambda r: -r['hp']):
        print(f"  hp={r['hp']:.3f} lag={r['lag']:.2f}  {r['run']}/{r['game']}  "
              f"{r['hero']}  DEATH t={r['td']}")

    out = os.path.join(root, 'leaks.json')
    json.dump(rows, open(out, 'w'))
    print(f'\n[wrote {out}]')


if __name__ == '__main__':
    main()
