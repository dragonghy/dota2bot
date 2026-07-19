# Iteration 0001 — Changes

## Code

- `bots/FunLib/custom_loader.lua` — reworked `ApplySoakDraft` seeding:
  per-launch jitter seed, double-safe Park–Miller LCG for all draws,
  `_G` seed stash for same-VM scope agreement. (Ships-safe: without the
  farm-only `Customize/soak_pool.lua` the function is still a silent
  no-op; shipped behavior unchanged.)
- `tests/test_soak_draft.lua` — new; 4 tests locking the fix: valid
  disjoint 5v5 from the pool, rotation across launches despite
  deterministic load-time `RandomInt`, same-VM second scope reproduces
  the draft, silent no-op without a pool file.

## Verification

- `luacheck bots game` — 0 warnings.
- `lua5.1 tests/run_tests.lua` — 9 tests, 0 failures.

## Ship & deploy

- Commit: **e18bd457ccd37eeecdd15616db50a44a5580478d** on `main`.
- Tag: `iter-0001`. **Note:** this environment's git proxy rejects tag
  pushes to origin (`remote end hung up`; GitHub shows no tags), so the
  tag exists locally and **on the farm checkout** (created via SSM),
  which is what `git describe` version-stamping reads. Deploy metadata is
  also recorded in `state.json.deploys` so no step depends on the remote
  tag.
- Farm deploy: `git pull` via SSM on `i-08b59ef7130025860`
  (dota2bot-soak) at ~06:30 UTC 2026-07-19; farm checkout at `e18bd45`,
  `git describe` → `iter-0001`.
- **Farm slot loops restarted** (`farm_start.sh 16`) into new run prefix
  `soak/run_20260719_0630`. Reason (per §4 "record why"): the running
  loops dated from 05:25 and predate wall-time capture (56234b3) and
  version stamping (fb0d418) — without a restart every future ledger row
  would still carry `script_version: unknown`, breaking §8 provenance
  and iteration 0002's before/after scoring. 16 in-flight games were
  sacrificed; the farm self-replenishes.

## Process/manual edits

- `schedule_job.md` §Step 8 amended: documents the tag-push limitation
  and the farm-local tagging + `state.json.deploys` fallback. Reason:
  the next firing must not stall retrying an impossible push, and Step 2
  needs a reliable deploy timestamp source.
