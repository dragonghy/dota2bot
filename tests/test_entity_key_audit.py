#!/usr/bin/env python3
"""Regression guard for the GH #176 exposure audit (replay-check 2026-08-25).

Two things are pinned here.

1. `entity_key_audit.selfcheck()` still passes.  That selfcheck drives the real
   `leak_times` / `strip_leaks` / `keying_report` / `clean_timeline` functions
   -- not copies of them -- so this test fails if any of them drifts.

2. The CLEANED side of `clean_timeline` is what a detector would actually see:
   one snapshot stream per hero name, the real (pre-horn) one, with post-death
   leak samples gone.  This is asserted on the cleaned timeline only, never on
   the contaminated one: the point is that cleaning works, not that any given
   detector is still reading dirty input.  When a detector is fixed to import
   `entities.py`, this test keeps passing.

Plain python, no pytest (matches tests/test_detect_overchase.py).

Usage:  python3 tests/test_entity_key_audit.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEHAV = os.path.join(ROOT, "tools", "batch_test", "behavioral")
sys.path.insert(0, BEHAV)

import detect                       # noqa: E402
import entities                     # noqa: E402
import entity_key_audit as eka      # noqa: E402

failures = []


def check(cond, msg):
    print("  [%s] %s" % ("ok" if cond else "FAIL", msg))
    if not cond:
        failures.append(msg)


HERO = "npc_dota_hero_lina"


def snap(idx, t, x, y, hp):
    return dict(hero=HERO, idx=idx, t=t, x=x, y=y, hp_pct=hp, team=3, level=6,
                player_id=6, abilities=[], items=[])


def main():
    print("selfcheck of tools/batch_test/behavioral/entity_key_audit.py")
    check(eka.selfcheck(), "entity_key_audit selfcheck passes")

    # real hero: sampled before the horn, walks, dies at t=20, one leaked
    # positive-hp frame, then corpse frames.
    # illusion: born at t=10, frozen far away, dead for its whole life -- the
    # shape measured in every W11 game (replay-check 2026-08-25T21:56Z).
    snaps = ([snap(11, t, 100.0 * t, 0.0, 1.0) for t in (-5.0, 0.0, 10.0, 20.0)]
             + [snap(11, 21.0, 2000.0, 0.0, 0.05)]
             + [snap(11, t, 2000.0, 0.0, 0.0) for t in (22.0, 23.0)]
             + [snap(77, t, -6000.0, -6000.0, 0.0)
                for t in (10.0, 20.0, 21.0, 22.0, 23.0)])
    tl = dict(game=dict(teams={HERO: 3}), snapshots=snaps,
              events=[dict(type='DEATH', t=20.4, target=HERO,
                           target_hero=True),
                      dict(type='TICK', t=1e6)],
              creeps=[], buildings=[])

    clean, removed = eka.clean_timeline(tl)
    idxs = {s['idx'] for s in clean['snapshots']}
    check(idxs == {11}, "cleaned timeline keeps only the pre-horn entity (%s)"
          % sorted(idxs))
    check(removed == 6, "cleaned timeline dropped 5 illusion + 1 leak samples "
          "(got %d)" % removed)
    check(all(not (s['t'] == 21.0 and s['hp_pct'] > 0)
              for s in clean['snapshots']),
          "the post-death leak frame is gone from the cleaned timeline")
    check(any(s['t'] == 20.0 and s['hp_pct'] > 0 for s in clean['snapshots']),
          "the last live frame before the death survives cleaning")

    # what a name-keying reader gets from the cleaned input: one track, the
    # hero's own.  `detect.Timeline` is the wide-sweep instrument every stream
    # reads, so it is the one pinned here.
    d_clean = detect.Timeline(clean)
    track = d_clean.snaps[HERO]
    check(len({s['idx'] for s in track}) == 1,
          "detect.Timeline sees a single entity per name on cleaned input")
    check(all(s['x'] > -6000 for s in track),
          "no frozen illusion coordinate reaches the cleaned track")

    # and the shared module agrees with the cleaner about which stream is real
    fr, _ = entities.frames_by_hero(clean)
    check(list(fr) == ['lina'] and fr['lina'][0]['idx'] == 11,
          "entities.frames_by_hero picks the same entity the cleaner kept")

    if failures:
        print("\n%d FAILURE(S)" % len(failures))
        for f in failures:
            print("  - %s" % f)
        return 1
    print("\nall checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
