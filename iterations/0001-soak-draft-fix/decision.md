# Iteration 0001 — Decision

## Hypothesis

The 100% Radiant win rate and the entire feeder/low_gpm anomaly surface
are artifacts of `ApplySoakDraft` freezing Radiant's lineup (seed always
0 + deterministic load-time `RandomInt`). If the draft rotates properly
per game, Radiant win rate should regress toward ~50% and per-hero
anomaly stats become attributable to hero logic instead of matchup rig.

## Fix

Rework the drafter's seeding (`bots/FunLib/custom_loader.lua`):

- Seed from `RealTime()`'s **sub-second load-timing jitter** (the only
  reliable per-launch entropy at file-load time), with `RandomInt` mixed
  in as a secondary source only.
- All draws go through a local Park–Miller LCG (`s*16807 % 2^31-1`,
  double-safe in Lua 5.1 — the old `s*1103515245` overflowed the 2^53
  float mantissa and degraded).
- The first team scope stashes the seed in `_G`; a same-VM second scope
  reproduces the identical draft (zero cross-team duplicates). Isolated
  scopes fall back to independent seeds, where a rare duplicate pick
  degrades to OHA's random-available fallback (noise, not breakage).

Also restart the farm slot loops after deploy (they had been running
code from 05:25, predating both wall-time capture and
`SOAK_SCRIPT_VERSION` stamping — every ledger row so far says
`script_version: unknown`, violating the §8 provenance requirement).
Restart gives a clean post-fix cohort in a fresh run prefix.

## Expected metric movement (for iteration 0002 to score)

- **Radiant win rate: 100% → 40–60%** over the next ~15+ games.
- **Radiant lineup diversity: 1 distinct 5-set in 18 games → no lineup
  repeated more than ~2×**; pool heroes appear on both sides.
- `script_version` populated (`iter-0001`) on all new ledger rows.
- Secondary watch: whether lich/venomancer/dragon_knight feeder rates
  persist once matchups are fair — only then are they real hero-logic
  targets.
