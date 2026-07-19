# Autonomous Operation Log

The owner has handed over autonomous operation (2026-07-19): run the soak farm,
iterate on hero/mode logic from its findings, decide independently when to
adjust, when to farm-test, and when to run win-rate validation. This file is
the running record: decisions, findings, and questions to discuss when the
owner returns.

## Operating Policy (agreed with owner)

1. **Soak farm** runs continuously (turbo, latest code both sides, varied
   drafts) producing per-game anomaly reports in S3.
2. **Fix loop**: analyze anomalies → implement fixes → luacheck + unit tests →
   commit/push to the working branch → farm keeps picking up latest code on
   its next games (repo pulled on instance periodically).
3. **Win-rate gates are release-based**: tag milestones; A/B (same-match
   team-dispatch) compares the candidate against the *previous release tag*,
   not the previous commit. Only tag a new release on a measured improvement.
4. Self-scheduling uses the harness's ScheduleWakeup (no owner approval
   needed), roughly hourly light checks with deeper analysis periodically.
   send_later/Routines are NOT used — they require manual approval per call.

## Releases

| Tag | Date | Contents | A/B result vs previous |
|---|---|---|---|
| v0.1-baseline | 2026-07-19 | main after infra + ~90 nil-bug fixes; pre hero-tuning | (baseline) |

## Decision Log

- 2026-07-19: Farm launched — 8 slots, turbo 4x, run `run_20260719_0455`,
  instance i-08b59ef7130025860, watchdog until 2026-07-21 06:55 UTC.
- 2026-07-19: Wave 1 hero fixes (Axe talent index, WK/Axe BKB, Lion/Zeus
  Aether Lens, Axe t15 talent) are on the working branch — they ride along in
  farm games; formal A/B vs v0.1-baseline deferred until a meaningful batch of
  changes accumulates.
- 2026-07-19: Hot reload (`dota_bot_reload_scripts`) verified to NOT reload
  BotLib hero files — inner loop relies on unit tests instead.

## Planned Work (not yet done)

- **Spot migration** — `tools/batch_test/aws/SPOT_MIGRATION_PLAN.md`. Switch the
  farm from on-demand ($497/mo) to a self-healing Spot ASG (~$187/mo, -62%), or
  same budget for ~2x throughput on a spot c6i.8xlarge. Owner approved writing
  the plan; implement after the current 48h on-demand run finishes. Bake stays
  on-demand.

## Open Questions for the Owner

1. send_later/Routine scheduling requires per-call approval in this
   environment — switched to ScheduleWakeup (hourly cadence, capped at 1h per
   hop). If a wakeup chain ever breaks (e.g. session interrupted), the farm
   itself keeps running unattended; re-open the session to resume monitoring.
2. Project/Workshop naming still TODO (affects bot name suffix ".OHA",
   install scripts, README branding).
3. The masked "[VScript] Script Runtime Error: error in error handling"
   (~20/game) hides the real stack — plan is to wrap OHA's error handler to
   log real tracebacks; will do as a farm-informed fix.

## Farm Findings (rolling)

- (from first complete game, pre-farm) turbo game dragged to 56 min — bots
  can't close; slow_close is the #1 macro target. Perf hotspots: GetDesire
  2-3ms on several heroes.

### Run run_20260719_0455 — first cohort (4 games, 16-slot farm)

Every one of the first 4 games flagged the same cluster:
- **slow_close (3/4, the 4th at 38min just under the 40min bar):** turbo games
  run 38-47 game-minutes vs the ~25 expected. Tower progress is *steady*, not
  stalled — bots win but close too slowly (grouping / pressing-advantage
  macro, shared mode layer). #1 macro target confirmed.
- **feeder every game:** a hero going >=8 deaths / <=2 kills. Per-hero behavior
  bug, high-value + tractable. NEXT: aggregate which heroes feed most across
  the run to rank fixes.
- **low_gpm core every game:** a core under 300 GPM in turbo = broken farming
  for that hero/position. Same aggregate-and-rank approach.
- **script_perf every game:** GetDesire/ItemUsageThink hotspots >=8ms.

Throughput: 16 slots saturate the 16 vCPUs (loadavg ~16), dragging achieved
timescale to ~2.3x (measured from wall vs game clock). This does NOT hurt
fidelity (lower timescale = more bot think-updates per game-second) — only
throughput efficiency. Added SOAK_WALL_S telemetry so effective_timescale is
recorded per game; let the loop pick the optimal slot count from ~20+ games of
data rather than tuning on 4. Radiant won all 4 (noise at n=4; watch for a real
side bias).
