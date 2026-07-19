# Iteration 0008+ — Ten-Minute Economy Lab (overnight, owner asleep)

**Owner directive (2026-07-19 ~08:45 UTC):** this session drives optimization
directly, all night. Games locked to **10 game-minutes**; objective:
**maximize the economic lead at the cap**. Validation = mirror games
(candidate script on one side, reference on the other, same match — the
`make_ab_build.py` team-dispatch tree). Baseline chain: B0 = iter-0008
(= main at b087e4e); accepted candidates merge to main and become the next
baseline. No scheduled jobs — this session self-schedules (wave monitors +
wakeup heartbeat).

## Protocol per candidate

1. Branch `cand-XX` from main with ONE coherent change; gates must pass;
   push to origin (farm fetches refs from origin).
2. Farm: `ab_deploy.sh <baseline_ref> <cand-XX>` (+`swap` for side-flipped
   waves), `farm_start.sh 12`, one wave = 12 mirror games ≈ 6-8 wall-min.
3. Metric per game: `team_gold[cand side] - team_gold[ref side]` from the
   analysis JSON. Wave verdict: mean margin and #positive games,
   side-bias-corrected (see W1).
4. Accept if mean margin ≥ +1000 gold AND ≥7/12 games positive after bias
   correction → merge into main, tag `base-XX`, becomes reference.
   Reject otherwise; log either way in the Progress Log below.

## Calibration waves

- **W0** `run_20260719_0848` (running): plain mode, both sides main —
  validates the 10-min referee (expect durations ~10-11.5 min,
  winner_by=economy_10min_cap).
- **W1**: mirror main-vs-main — measures side bias + noise floor of the
  margin metric (dispatcher live but sides identical).
- **W2**: mirror `8c36da4` (pre-draft-fix, frozen radiant lineup) as OLD on
  the RADIANT side (swap mode): frozen sniper/viper/DP/ogre/PA lineup
  appearing only on radiant proves per-team dispatch actually loads two
  different trees.

## Candidate queue (10-min turbo economy)

- **C1 farm-free**: remove the post-5-min farm-desire cap (0.45) — tests
  whether the push-first doctrine HURTS the first 10 minutes (lane/jungle
  gold vs tower bounties).
- **C2 push-heavy**: opposite direction — if C1 loses, strengthen early
  tower-taking (tower bounties + map control).
- **C3 runes**: bounty (0:00, 3:00, 6:00, 9:00) + water rune pickup — direct
  gold/regen value.
- **C4 lane sanity**: match drafted heroes to lanes by role map (cores
  actually in farming positions).
- **C5 fewer deaths**: earlier laning retreat thresholds (deaths are the
  biggest single econ swing pre-10).
- **C6 starting/turbo item builds**: first-buy optimization.

## Progress log (append per wave)

(waves logged below as they complete)
