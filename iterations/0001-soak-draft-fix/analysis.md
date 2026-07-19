# Iteration 0001 — Analysis

First firing of the scheduled iteration job. Watermark was empty, so all
available games were ingested: **18 games** from
`soak/run_20260719_0455` (launched 05:25–05:45 UTC, 2026-07-19), all
appended to `iterations/games_ledger.jsonl`. All 18 rows carry
`script_version: "unknown"` — the running slot loops predate the
version-stamping commit (fb0d418, 06:01 UTC); see decision.md.

## Baseline aggregate (18 games)

| Signal | Value |
|---|---|
| Winner | **Radiant 18/18 (100%)** |
| Duration | 38.3–67.5 min, avg **51.0 min** (turbo; ~25 expected) |
| slow_close | 17/18 games |
| feeder anomalies | 31 across 18 games (all Dire heroes) |
| low_gpm anomalies | 17 (all Dire heroes) |
| script_perf | 18/18 games (GetDesire hotspots, max ~7 ms) |
| masked VScript errors | ~20/game ("error in error handling") |

## Root-cause finding: the draft is rigged, not the heroes

Per-game lineups (see `data/baseline_aggregates.json`) show:

- **Radiant fielded the identical 5 heroes in all 18 games:**
  sniper, viper, death_prophet, ogre_magi, phantom_assassin
  (a stacked late-game/push lineup; sniper avg 836 GPM, viper 750).
- **Dire drew varied lineups from a fixed complementary 15-hero half** of
  the 30-hero soak pool (lich in 15/18, medusa 10/18, …). No pool hero
  ever switched sides.

So the "Radiant 18/18 bias", every feeder (lich 55K/207D across 15
games), and every low_gpm flag are all downstream of one drafting bug in
`custom_loader.ApplySoakDraft`:

1. The partition seed used `math.floor(RealTime()/300)` assuming
   wall-clock time. `RealTime()` is **elapsed time since process start**
   (docs/BOT_API_REFERENCE.md), ~seconds at script load → bucket = 0 in
   every game → the pool partition never rotated.
2. Each team's 5-hero sample used engine `RandomInt()`, which at
   file-load time **repeats the same sequence every launch** in the
   first-loaded (Radiant) scope → Radiant's sample froze on the same 5
   heroes. (Dire's scope loads later, after the shared RNG stream has
   diverged by a variable amount, which is why Dire still varied.)

## Why this target

Every other signal in the ranking (feeders, low_gpm, slow_close ranking
per hero) is confounded by the rigged matchup — a varied Dire team losing
to a fixed stacked Radiant tells us nothing about hero logic. Fixing the
draft is the highest-value change: it unblocks all future signal quality.
Slow-close (avg 51 min in turbo even for the stomping team) and the
masked VScript errors are real, draft-independent problems and go to the
open-issues backlog.
