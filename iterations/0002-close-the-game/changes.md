# Iteration 0002 — Changes

## Code (three commits on `main`)

- `dc?` `sniper: fix Shrapnel charge check` — hero_sniper.lua
- `IsModeTurbo: use GetGameMode()` — jmz_func.lua + tests/test_mode_detect.lua
- `push desire: unblock sieging/closing` — aba_push.lua **and**
  typescript/bots/FunLib/aba_push.ts (TS source updated per the
  TS-generated-file rule; toolchain not present in-repo, files kept in sync
  by hand).

Head after this iteration: `bd62ec0`.

## Verification

- `luacheck bots game` — 0 warnings.
- `lua5.1 tests/run_tests.lua` — 11 tests, 0 failures (2 new).

## Deploy

- Farm `git pull` via SSM at ~07:0x UTC 2026-07-19; farm checkout at
  `bd62ec0`, farm-local tag `iter-0002` (remote tag pushes still blocked by
  the session git proxy — see iter-0001 changes.md). Slot loops NOT
  restarted (they already stamp versions; new games pick up new code
  automatically). Games with `script_version` starting `iter-0002` are the
  post-fix cohort.

## Process changes (owner-directed, this session)

- `schedule_job.md`: removed the one-focused-change-per-iteration cap
  (owner's explicit instruction mid-session); deep log forensics declared
  part of every firing's analysis. Commits stay separated by concern.

## Ledger

- +8 pre-fix games ingested (26 total). Watermark advanced to
  `20260719_060831_slot14.analysis.json`.
