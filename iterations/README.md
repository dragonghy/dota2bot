# Iterations

Running record of the scheduled iteration job (see `../schedule_job.md`). One
subfolder per iteration; one committed ledger of every game.

## Contents

- **`state.json`** — cross-iteration state: counter, ingest watermark,
  fixed-issue ledger, ranked open issues, last release tag. The scheduled job
  reads this first and updates it last, every firing.
- **`games_ledger.jsonl`** — append-only, queryable record of every soak game
  (script version, duration, per-hero GPM/KDA, tower timeline, anomalies). Query
  with `jq` or `pandas.read_json(..., lines=True)` instead of re-parsing console
  logs. Contract in `schedule_job.md` §8.
- **`NNNN-<slug>/`** — one folder per iteration:
  - `analysis.md` — the data that drove the iteration (anomaly aggregation)
  - `decision.md` — hypothesis, the fix, the metric expected to move
  - `changes.md` — files changed + rationale, commit SHA, `iter-NNNN` tag
  - `outcome.md` — written by the *next* iteration: did the metric actually
    move? (closes the loop)

## For the master (supervising) session

Read `state.json`, then the latest `NNNN-*/` folders (especially `outcome.md`),
then `git log` + the `iter-*` / `v*` tags. That's the whole story of what the
bot has learned and shipped.
