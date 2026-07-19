# Iteration 0007 — 30-minute lock (owner-directed infrastructure change)

## Rule change

Games are locked to ~30 game-minutes; the ECONOMIC leader at the cap wins.
The optimization objective for all future iterations: **maximize the
economic lead at 30 minutes** (schedule_job.md §0.1). Pushing and farming
are both legitimate; closing speed is no longer chased for its own sake.

## Why infrastructure (not bot behavior)

Owner rejected the behavioral forfeit (bots throwing the game). Probing the
dedicated server showed NO scripting/query surface: no `script` command, no
force-win console command except `dota_dev forcewin` (discovered + verified:
instant end, normal signout), bot print() never reaches any log, chat is not
logged, condump unavailable headless, and Lua error payloads are masked
("error in error handling" — this also closes the old vscript_errors mystery:
the engine's error handler is broken in this environment, so NO error text
is ever visible; unmasking via logs is impossible).

## Mechanism (commit a388b56)

- soak_loop launches servers with `-usercon +rcon_password`.
- referee.py polls each slot: reads Building-destruction timestamps (exact
  game time) from the slot's stdout log, measures achieved timescale live,
  extrapolates the clock, and past 30:00 fires `dota_dev forcewin` (which
  team the engine credits is irrelevant).
- analyze_log.py overrides winner = economic leader (Σ GPM × duration per
  team) for games ≥29.5 min (`winner_by: economy_30min_cap`) and records
  `team_gold` + `econ_winner` on EVERY game — the primary metric for the
  scheduled iteration agents.
- Verified end-to-end: forcewin live-tested on a farm test server;
  referee's below-cap/past-cap paths unit-tested against real logs;
  analyze_log econ-winner tested on a real 67-min game log.

## Cohort scoring (from run_20260719_0741, pre-lock)

- iter-0005 (push-first desires): 12 games, avg 48.6 min (40.8–59.9), 7R/4D.
- iter-0006 (+tower-aggro fix): 15 games, avg 52.2 min (38.9–66.5), 8R/7D —
  sieges start earlier (T2s from 16.8 min observed) but games see-saw; no
  net duration gain. Winner balance stays ~50/50 (draft fix holding).
- Conclusion: chasing close-speed via desires hit diminishing returns;
  the 30-min lock renders it moot. Next agents optimize econ lead instead.

## For the next scheduled agent

- New run prefix `soak/run_20260719_0841`, farm tag iter-0007 (12 slots).
- Score: durations should cluster 30–32 min; check `winner_by` and
  `referee_*.log`/`refstate_*.json` on the farm if any game runs long.
- Primary metric now: `team_gold` margin at cap; per-hero GPM/KDA under
  the push-first doctrine — tune the push/farm mix by econ lead, per hero.
- Watch iter-0006's deny-aggro change for tower-dive deaths via econ data.
