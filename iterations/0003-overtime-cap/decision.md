# Iteration 0003 — Decision

## Change: in-game overtime forfeit (farm-only)

Past **40 game-minutes** (`J.IsSoakOvertime()`, jmz_func.lua):
- defend desire → 0 for every bot (aba_defend),
- push desire → 0.95 for every bot (aba_push),

so the side that is stronger on the map ends the match within a few game
minutes and the game still produces a real signout scoreboard — unlike
the wall-clock `kill -9`, which loses the data. The wall backstop was
lowered 45 → 35 min (applies at the next farm restart; the in-game cap
should always fire first).

**Ship safety:** active only when the farm-only, gitignored
`Customize/soak_pool.lua` exists (`J.IsSoakFarm()`); without it the
check is always false — locked by a ship-safety unit test
(`tests/test_soak_overtime.lua`). Workshop behavior unchanged.

## Expected metric movement

- Hard ceiling: no game exceeds ~42-43 game-min / ~20 wall-min.
- Slot throughput up ~40% (avg 60-min games → ≤40 + a few min).
- `winner` stays meaningful (map-stronger side finishes).

## Caveat for scoring iter-0002's closing fixes

With the cap in place, raw duration clips at ~40; measure closing by
**time-to-first-rax** and **hero building damage per minute** instead.
Owner's live observation suggests iter-0002 games may still be slow
(first ones were still in flight when this shipped) — if
post-iter-0002 cohorts still show first-rax > ~30 min, push desire is
still too low and the next lever is raising the advantage-cap further /
weakening the tower-yo-yo retreat in PushThink
(`push_think:tower_yoyo` in open_issues).
