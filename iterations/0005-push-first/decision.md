# Iteration 0005 — Decision (owner directive: push-first doctrine)

Owner: concentrate the bots' primary intent on pushing; drop farming
desire to a minimum now, rebalance later against winrate. Game tempo =
iteration speed.

## Changes (commit `472bf93`)

- `aba_push.lua` (+TS): base `nPushDesire` 0.5 → **1.0** (healthy bot
  pushes at the full cap even in even games); caps: base 0.85 → **0.92**,
  overtime floor **0.95**, overtime bonus +0.35.
- `mode_farm_generic.lua`: post-early-game farm desire hard-capped at
  **0.45** (escape/ShouldRun returns > 1.0 untouched) — farming fills
  gaps, never outcompetes structures.
- `jmz_func.lua`: soak overtime forfeit 40 → **35 game-min**, so forfeit
  races land ~40 (the owner's line-3 target).

## Deploy

Farm restarted per owner: **12 slots** (down from 16 — less CPU
contention → higher effective timescale → faster wall-clock per game),
run `soak/run_20260719_0741`, clean `iter-0005` stamps, 35-min wall
backstop active.

## Expected metric movement (score from run_20260719_0741)

- Organic closes (no forfeit) in the 25–35 min band for games with any
  advantage; forfeit races land ≤ ~42.
- Avg duration ~49 → **low-to-mid 30s**; effective timescale up with 12
  slots (wall-min per game down disproportionately).
- WATCH: winrate stability and feeder anomalies — push-first will cost
  some throws; that's the accepted trade, tune back via winrate data.
