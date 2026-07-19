# Iteration 0003 — Changes

## Code (commit `81c2eec` on `main`)

- `bots/FunLib/jmz_func.lua` — `J.IsSoakFarm()` (cached probe of the
  farm-only pool file) and `J.IsSoakOvertime()` (DotaTime > 40 min).
- `bots/FunLib/aba_defend.lua` + `typescript/bots/FunLib/aba_defend.ts` —
  defend desire None during overtime.
- `bots/FunLib/aba_push.lua` + `typescript/bots/FunLib/aba_push.ts` —
  push desire 0.95 during overtime.
- `typescript/bots/FunLib/jmz_func.d.ts` — declarations for the two new
  functions.
- `tools/batch_test/soak/soak_loop.sh` — wall backstop 45 → 35 min
  (takes effect at the next farm restart).
- `tests/test_soak_overtime.lua` — new; incl. ship-safety test.

## Verification

- `luacheck bots game` — 0 warnings.
- `lua5.1 tests/run_tests.lua` — 13 tests, 0 failures (2 new).

## Deploy

- Farm: restored stale `bots/Customize/general.lua` (old draft.py
  residue — cause of the `-dirty` version stamps), pulled `81c2eec`,
  farm-local tag `iter-0003` (remote tag pushes still blocked by the
  session git proxy). No loop restart; running games finish on their
  launch-time code, new launches pick up the cap.

## Ledger

- +14 games from `soak/run_20260719_0630` (fair-draft `iter-0001-dirty`
  cohort), 40 rows total.
