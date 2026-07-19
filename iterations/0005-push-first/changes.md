# Iteration 0005 — Changes

## Code (commit `472bf93` on `main`)

- `bots/FunLib/aba_push.lua` + `typescript/bots/FunLib/aba_push.ts` —
  base push desire 1.0, caps 0.92/0.95, overtime bonus +0.35.
- `bots/mode_farm_generic.lua` — post-early-game farm cap 0.45 (pure
  Lua file, no TS source).
- `bots/FunLib/jmz_func.lua` — soak overtime forfeit 40 → 35 game-min.
- `tests/test_soak_overtime.lua` — boundary times updated to 34/36 min.

## Verification

- `luacheck bots game` — 0 warnings.
- `lua5.1 tests/run_tests.lua` — 13 tests, 0 failures.

## Deploy

- Farm pulled `472bf93`, farm-local tag `iter-0005`, then **fully
  restarted with 12 slots** (owner: lower parallelism → less CPU
  contention → faster wall-clock per game). New run prefix
  `soak/run_20260719_0741`. In-flight iter-0004/0005-boundary games
  sacrificed (their 11 finished games were ingested first).

## Ledger

- +11 iter-0004 games (`soak/run_20260719_0716`), 52 rows total.

## Process notes

- Mid-implementation the owner escalated the directive twice (more
  aggressive than my staged tuning); the shipped numbers reflect the
  final instruction: farming minimized, pushing dominant, rebalance
  later via winrate.
