#!/usr/bin/env python3
"""`death_spans()` must anchor its fountain-jump test on the CORPSE, and the
switch must be inert for every consumer of the spans it exports.

Plain python, no pytest (matches tests/test_canon_hero_join.py).

Background (`[bug]` GH #247, replay-check 2026-08-27).  The shared constructor
`roam_conversion.death_spans()` decided "was this respawn a fountain teleport?"
by measuring the >1500u jump from the LAST LIVE SAMPLE -- the last snapshot at
or before the DEATH event.  At 1Hz that frame can predate the fall by a full
sample, and a hero running at 300+ u/s covers 300u in one sample against a
1500u threshold, so the sign flips.  Frame-verified on
`c1d1cf/20260827_063128_slot8` skeleton_king L19: a 4.2s in-place Reincarnation
sits 1386u from the corpse and 1705u from the running frame, so the old anchor
read it as a level-19 fountain respawn.  In `bbfloor_domain.py`, which exports
that flag, it was the ONLY buyback candidate on the whole W16 corpus.

TWO PROPERTIES ARE PINNED HERE, and the second is the one that made the
backfill affordable.

  1. THE ANCHOR IS THE CORPSE.  Asserted on a case where the choice actually
     reaches the exported value, so reverting the anchor turns this file red
     rather than leaving it green on a flag nobody reads.

  2. THE SWITCH MOVES NO HISTORICAL SPAN.  `death_spans()` exports only
     `(t_death, t_respawn)`; `jumped` never leaves the loop, and the loop
     breaks on `jumped or s['t'] - td >= 1.5`.  So the anchor can reach `tr`
     ONLY through a frame in the open window `(td, td + 1.5)` that already
     carries `hp_pct > 0.5` -- and no real revival lands there (fountain floor
     6.2s measured at level 1 per GH #246, aegis ~5s, Reincarnation ~3s), while
     the hp leak the 1.5s guard exists for is a stale COPY of the last live
     sample, i.e. the same position under either anchor.  That is why the
     corpus-wide before/after rescan #247 asked for is not owed by the
     consumers of the spans, and remains owed by anyone exporting `jumped` or
     `span`.  Prose cannot carry that claim, so it is a DIFFERENTIAL against a
     frozen copy of the pre-fix anchor: every disagreement must exhibit such a
     frame, checked over the bearing geometry and a deterministic sweep of
     synthesized ones.

The frozen copy below is history, not a second implementation to maintain: it
is the `before` side of the differential and must never be updated in step.

Usage:  python3 tests/test_death_span_corpse_anchor.py
"""
import collections
import math
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "batch_test", "behavioral"))
import roam_conversion as RC  # noqa: E402

HERO = "npc_dota_hero_skeleton_king"
failures = []


def check(cond, msg):
    if cond:
        print("  ok   %s" % msg)
    else:
        failures.append(msg)
        print("  FAIL %s" % msg)


# --------------------------------------------------------------- frozen past

def old_anchor_spans(tl, real_idx):
    """VERBATIM pre-#247 `death_spans()` body.  Frozen: do NOT keep in step."""
    per = collections.defaultdict(list)
    for s in tl['snapshots']:
        if real_idx.get(s['hero']) == s['idx']:
            per[RC.canon_hero(s['hero'])].append(s)
    for h in per:
        per[h].sort(key=lambda s: s['t'])

    spans = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] != 'DEATH' or not e.get('target_hero'):
            continue
        h, td = RC.canon_hero(e['target']), e['t']
        if spans[h] and spans[h][-1][1] > td:
            continue
        snaps = per.get(h) or []
        loc = next(((s['x'], s['y']) for s in reversed(snaps) if s['t'] <= td), None)
        tr = float('inf')
        for s in snaps:
            if s['t'] <= td or s['hp_pct'] <= 0.5:
                continue
            jumped = loc is None or math.hypot(s['x'] - loc[0], s['y'] - loc[1]) > 1500.0
            if jumped or s['t'] - td >= 1.5:
                tr = s['t']
                break
        spans[h].append((td, tr))
    return spans


# ------------------------------------------------------------------- helpers

def timeline(frames, deaths, hero=HERO):
    """frames: [(t, x, y, hp_pct)]; deaths: [t]."""
    snaps = [{"hero": hero, "idx": 1, "t": round(t, 1),
              "x": float(x), "y": float(y), "hp_pct": float(hp)}
             for (t, x, y, hp) in frames]
    ev = [{"type": "DEATH", "t": t, "target": hero, "target_hero": True}
          for t in deaths]
    return {"snapshots": snaps, "events": ev}, {hero: 1}


def only_span(spans):
    got = spans[RC.canon_hero(HERO)]
    return got[0] if got else None


def witness_frames(tl, td):
    """The frames that let the anchor reach `tr` at all -- see property 2."""
    return [s for s in tl['snapshots']
            if td < s['t'] < td + 1.5 and s['hp_pct'] > 0.5]


# ----------------------------------------------- 1. the bearing frame itself

# c1d1cf/20260827_063128_slot8, seed 895, skeleton_king L19, team 3.
# Sampled at the real cadence around the death; the corpse frame is the one the
# anchor now selects.
BEARING = [
    (1079.5, -5680.0, 730.0, 0.310),
    (1080.5, -5397.2, 765.3, 0.143),   # last live sample -- RUNNING
    (1081.5, -5074.9, 796.3, 0.000),   # the corpse
    (1082.5, -5074.9, 796.3, 0.000),
    (1083.5, -5074.9, 796.3, 0.000),
    (1084.5, -5074.9, 796.3, 0.000),
    (1085.5, -3744.0, 1184.0, 1.000),  # Reincarnation, in place, 4.2s later
    (1086.5, -3700.0, 1200.0, 1.000),
]
TD = 1081.3

print("bearing frame: the geometry the issue reported")
d_corpse = math.hypot(-3744.0 - (-5074.9), 1184.0 - 796.3)
d_running = math.hypot(-3744.0 - (-5397.2), 1184.0 - 765.3)
check(round(d_corpse) == 1386, "revival is %du from the corpse (<1500)" % round(d_corpse))
check(round(d_running) == 1705, "revival is %du from the running frame (>1500)"
      % round(d_running))
check(d_corpse < 1500.0 < d_running,
      "the 1500u threshold sits BETWEEN the two anchors -- the sign is the anchor")

tl, real_idx = timeline(BEARING, [TD])
check(only_span(RC.death_spans(tl, real_idx)) == (TD, 1085.5),
      "shipped: span closes at the Reincarnation frame")
check(only_span(old_anchor_spans(tl, real_idx)) == (TD, 1085.5),
      "frozen pre-fix anchor closes it there TOO -- the flag flipped, the "
      "exported span did not (this is property 2 on the bearing case)")
check(witness_frames(tl, TD) == [],
      "and there is no >0.5 hp frame inside (td, td+1.5) to carry a difference")

# ------------------------------------- 2. the anchor IS observable, when it is

# The constructed witness: a frame 0.1s after the death carrying hp above 0.5,
# placed 1600u from the running sample and 1300u from the corpse, so the 1500u
# line falls between the two anchors exactly as it does on the bearing frame.
# This is the ONLY shape in which the anchor can move the exported span, and it
# exists to make the choice observable -- see the docstring for why no real
# revival can occupy it.
WITNESS = [
    (99.0, 0.0, 0.0, 0.60),
    (100.0, 700.0, 0.0, 0.30),      # last live sample -- running east
    (100.5, 2300.0, 0.0, 0.90),     # 1600u from the running frame, 1300u from
    (101.0, 1000.0, 0.0, 0.00),     # ...the corpse, which lies here
    (103.0, 5000.0, 0.0, 1.00),     # the real fountain respawn
]
print()
print("constructed witness: where the anchor reaches the exported span")
wt, wi = timeline(WITNESS, [100.4])
new_span = only_span(RC.death_spans(wt, wi))
old_span = only_span(old_anchor_spans(wt, wi))
check(new_span == (100.4, 103.0),
      "shipped anchors on the corpse: 1300u is no jump, the span runs to 103.0")
check(old_span == (100.4, 100.5),
      "frozen anchor measures 1600u from the running sample, past its own "
      "1500u line, and closes the span 2.5s early")
check(new_span != old_span,
      "the two anchors DISAGREE here -- reverting the fix turns this red")
check(len(witness_frames(wt, 100.4)) == 1,
      "and the disagreement carries the predicted witness frame")

# ------------------------------------------- 3. degenerate / fallback shapes

print()
print("fallback shapes")
no_corpse = [(10.0, 0.0, 0.0, 0.90), (11.0, 0.0, 0.0, 0.80)]
nt, ni = timeline(no_corpse, [10.5])
check(only_span(RC.death_spans(nt, ni)) == only_span(old_anchor_spans(nt, ni)),
      "no corpse frame at all (truncated span): falls back to the old anchor")
check(only_span(RC.death_spans(nt, ni))[1] == float('inf'),
      "...and the span stays open, as before")

empty, ei = timeline([], [10.0])
check(only_span(RC.death_spans(empty, ei)) == (10.0, float('inf')),
      "no snapshots at all: no crash, span open")

late = [(10.0, 0.0, 0.0, 1.00), (11.0, 0.0, 0.0, 0.00),
        (40.0, 6000.0, 6000.0, 1.00)]
lt, li = timeline(late, [10.5])
check(only_span(RC.death_spans(lt, li)) == (10.5, 40.0),
      "ordinary fountain respawn is unchanged")

# ----------------------------------------- 4. the differential, over a sweep

print()
print("differential sweep: every disagreement must carry a witness frame")
rng = random.Random(247)
disagreements = 0
agreements = 0
for _ in range(4000):
    td = round(rng.uniform(50.0, 60.0), 1)
    x0, y0 = rng.uniform(-6000, 6000), rng.uniform(-6000, 6000)
    # a run direction and speed in the engine's real range
    ang, spd = rng.uniform(0, 6.283), rng.uniform(0.0, 420.0)
    frames = []
    t = td - 3.0
    while t < td + 12.0:
        dt = t - (td - 3.0)
        if t <= td:
            hp = rng.uniform(0.05, 1.0)
            px, py = x0 + math.cos(ang) * spd * dt, y0 + math.sin(ang) * spd * dt
        elif t < td + 1.4:
            # the contested window: sometimes a corpse, sometimes a leaked
            # live sample, sometimes a teleport-looking artefact
            roll = rng.random()
            if roll < 0.55:
                hp = 0.0
                px, py = x0 + math.cos(ang) * spd * (td - (td - 3.0)), \
                    y0 + math.sin(ang) * spd * (td - (td - 3.0))
            elif roll < 0.8:
                hp = rng.uniform(0.51, 1.0)
                px, py = x0 + rng.uniform(-2500, 2500), y0 + rng.uniform(-2500, 2500)
            else:
                hp = rng.uniform(0.0, 0.5)
                px, py = x0 + rng.uniform(-400, 400), y0 + rng.uniform(-400, 400)
        elif t < td + 6.0:
            hp = 0.0
            px, py = x0 + rng.uniform(-50, 50), y0 + rng.uniform(-50, 50)
        else:
            hp = 1.0
            px, py = (rng.choice([x0 + rng.uniform(-1400, 1400), rng.uniform(-6000, 6000)]),
                      rng.choice([y0 + rng.uniform(-1400, 1400), rng.uniform(-6000, 6000)]))
        frames.append((round(t, 1), px, py, hp))
        t += 0.5
    tl, ri = timeline(frames, [td])
    new = only_span(RC.death_spans(tl, ri))
    old = only_span(old_anchor_spans(tl, ri))
    if new == old:
        agreements += 1
        continue
    disagreements += 1
    if not witness_frames(tl, td):
        check(False, "disagreement with NO >0.5hp frame in (td, td+1.5): "
                     "old=%r new=%r" % (old, new))
        break

check(agreements + disagreements == 4000, "swept 4000 synthesized deaths")
check(disagreements > 0,
      "the sweep actually produced disagreements (%d) -- a sweep that never "
      "disagrees proves nothing" % disagreements)
check(not [f for f in failures if f.startswith("disagreement")],
      "every one of the %d disagreements carried a witness frame in "
      "(td, td+1.5)" % disagreements)

print()
if failures:
    print("FAILED %d" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")
