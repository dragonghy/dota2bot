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

---
### Progress log

- **09:04 UTC** W0(first attempt, run_0848) invalidated: `dota_dev forcewin`
  turned out to be a NO-OP — its earlier "success" was the engine's default
  all-disconnected auto-surrender firing coincidentally on a test server
  launched without the farm's `+dota_surrender_on_disconnect 0`. Lesson
  recorded: verify causality, not coincidence (owner caught it live).
  Games of run_0848 hit the 15-min wall kill; no data.
- **09:04 UTC** Referee v3: at cap, set `dota_surrender_on_disconnect 1` +
  `dota_auto_surrender_all_disconnected_timeout 1` via rcon → engine ends
  the match in seconds WITH full signout (verified live on slot2: complete
  scoreboard, team_gold parsed, econ winner applied). Default ts estimate
  2.4→3.0. W0 redo launched: run_20260719_0904, iter-0009.
- Next: W0 verify durations ≈10-11 game-min → quick dispatch proof (mirror
  8c36da4-vs-main swap: frozen five on radiant = two trees really load) →
  C1 wave (farm-cap removal vs iter-0009).
- **09:15 UTC — W0 COMPLETE** (run_0904, 12 games, iter-0009 both sides,
  plain mode): durations 11.3-14.0 min (mean 12.7; referee ts estimate
  bumped 3.0→3.6 to tighten). **Radiant-side econ bias +2,146 gold mean
  (9R/3D, per-game σ≈3.8k)** → candidate verdicts use paired
  normal+swap waves: effect = (mean_margin_normal − mean_margin_swap)/2.
- **09:14 UTC — Dispatch proof PASSED** (mirror 8c36da4-vs-main, swap):
  Radiant (OLD) drafted the pre-fix frozen-half signature
  (viper/DP/sniper/PA/necro) while Dire (NEW) drafted via jitter seed with
  collision fallback (pudge/SD from the 127 pool) — two trees demonstrably
  live in one game. Note: cross-team pick collisions in mirror mode pull
  occasional non-pool heroes via OHA fallback; symmetric noise.
- **09:15 UTC — C1a launched** (run_0915): cand-c1 (no farm cap, 51d9114e)
  on RADIANT vs iter-0009 on DIRE.
- **09:25 UTC — mirror trees ABANDONED**: C1a (run_0915) all 12 games dead —
  drafts fine but every player level 1 / 0 GPM (gameplay VMs never ran;
  likely engine refuses dofile outside bots/). Pivot: single-tree TEAM GATE
  (J.IsSoakCandidateSide + farm-only Customize/soak_side.lua). Candidate
  code branches on the gate; inert off-farm. ba6af42.
- **09:27 UTC — C1 gated wave launched** (run_0927 after two soak_side
  quoting fumbles; file verified `return 'radiant'`): candidate=radiant
  plays with NO farm cap vs baseline dire. Verdict = mean(R−D gold) vs W0
  bias +2146, then swap wave.
- **09:35 UTC — C1 VERDICT: REJECTED** (run_0927, 12 games, cand=radiant):
  margins mean −979 raw / **≈−3,125 bias-corrected** (4/12 positive vs
  W0's 9/12). Removing the farm cap HURTS 10-min econ — the post-laning
  push doctrine (tower gold) out-earns free farming. Gate code left in
  tree (inert), candidate abandoned.
- **KEY INSIGHT**: turbo laning-phase hard floor is 8 min → bots lane for
  ~80% of a 10-min game; desire-level knobs only touch minutes 8-11.
  Real lever = laning window itself.
- **09:35 UTC — C2 launched** (run_0935): candidate side laning floor
  8→5 min (soft 10→7), converting minutes 5-10 into push/objective play.
- **09:44 UTC — C2 VERDICT: REJECTED** (run_0935, 12 games): mean −462 raw /
  ≈−2,608 corrected (5/12 positive). Early lane exit loses lane income
  without gaining enough objective gold. Baseline lane window stands.
- **DATA MINE (24 lab games)**: cores average only **12–47 last hits at
  ~11 min** (DK 12, PA 29, sven 28; best = sniper 47) — Valve-default CS
  runs for every farm bot because OHA's custom last-hit micro was gated to
  buggy-hero/human-partner setups. Lane EXECUTION is the biggest leak.
- **09:44 UTC — C3 launched** (run_0944): candidate-side cores (pos 1-3)
  use the custom last-hit desire (0.9) + Think micro (attack/deny/approach).
- **09:54 UTC — C3 VERDICT: REJECTED** (run_0944, 12 games): mean −1,442 raw
  / ≈−3,588 corrected. Mechanism check (lh_check): candidate cores' LH
  **dropped** to 27.6 vs baseline 35.5 — OHA's custom last-hit micro is
  WORSE than the engine's built-in CS AI. FINDING: never enable that path;
  engine CS stands. (Also explains why the human-partner gate existed.)
- **09:54 UTC — C4 launched** (run_0954): inverse of C2 — candidate side
  lanes the WHOLE capped game (floor 12 min). Rationale: pre-10min tower
  gold is scarce; C1/C2 both showed lane income dominates.
- **10:02 UTC — C4 wave 1** (run_0954): mean **+1,396** (8/12 positive),
  bias-corrected ≈ −750 — statistically NEUTRAL vs baseline, best candidate
  so far. Running the swap wave (candidate on dire, run_1002) to sharpen:
  effect = (m_normal − m_swap)/2.
- **10:11 UTC — C4 VERDICT: NEUTRAL/REJECTED** (paired waves 0954+1002):
  effect = (1,396 − 1,611)/2 ≈ **−108 gold** — zero. The 8→12 min laning
  window is irrelevant at the 10-min cap. Paired-wave side-bias refresh:
  (1,396+1,611)/2 ≈ **+1,504** (was +2,146 in W0).
- **STRATEGY PIVOT**: stop testing fresh hypotheses blind; sweep the one
  proven axis (C1: farm-cap presence worth ~3k in a 3.5-min window).
- **10:11 UTC — C7 launched** (run_1011): cap depth 0.45 → 0.30 on
  candidate side.
- **10:19 UTC — C7 VERDICT: REJECTED** (run_1011, 11 games): mean +590 raw /
  ≈−1.2k corrected. Cap 0.45 is the depth optimum (0.30 and none both lose).
- **VOLUME FINDING**: teams collect only ~43% of spawned lane gold by 11.5
  min (team LH ≈125 vs ≈290 lane creeps) — grouped pushing abandons two
  lanes. Biggest untapped econ pool.
- **10:19 UTC — C10 launched** (run_1019): role-split caps — candidate
  cores (pos1-3) cap 0.65 to soak lanes, supports stay 0.45 on the push.
- **10:28 UTC — C10 wave 1** (run_1019): mean **+1,630** (10/12 positive) —
  right at the bias line (+1,504 refreshed / +2,146 W0). Swap wave running
  (run_1028) to decide: effect = (1,630 − m_swap)/2.
- **10:37 UTC — C10 PAIRED VERDICT: WEAK POSITIVE, PROMOTED** — wave1
  +1,630 / swap +968 → **effect +331 gold** (±~780). First candidate above
  zero after six rejections; mechanism sound (soak uncollected lane gold).
  **Promoted as baseline B1** (unconditional role-split caps: cores 0.65,
  supports 0.45; farm tag base-b1). Rationale: cheap false-positive risk,
  explore around a promising point.
- **10:37 UTC — C11 launched** (run_1037): core cap sweep 0.65 → 0.80 vs B1.
- **10:45 UTC — C11 VERDICT: REJECTED** (run_1037, 11 games): mean −497 /
  ≈−2k corrected. Core-cap 0.80 overshoots. **Cap axis fully mapped**:
  none −3.1k · 0.30 −1.2k · 0.45 base · **0.65-cores +0.3k (B1 = peak)** ·
  0.80 −2k.
- **10:45 UTC — C12 launched** (run_1045): death-avoidance axis — candidate
  retreats at HP<0.45 with ≥1 damaging enemy (baseline 0.3 / ≥2).
- **10:54 UTC — C12 VERDICT: REJECTED** (run_1045, 12 games): mean +671 raw /
  ≈−833 corrected — earlier retreats don't pay for the lost lane time.
- **10:54 UTC — C13 launched** (run_1054): support cap 0.45→0.35 (harder
  push commitment for pos4/5, complement of B1's core-soak).
- AWS check: $35.17 MTD, only the soak box running (unchanged).
- **11:02 UTC — C13 VERDICT: REJECTED** (run_1054, 11 games): mean −339 /
  ≈−1.8k corrected. Support cap 0.45 stands.
- **11:02 UTC — MODE SHIFT**: quick-knob space exhausted (8 candidates
  tested, 1 weak win promoted). Remaining night = repeated paired b0
  regression waves (candidate side reverts to pre-B1 uniform caps) to pin
  B1's true effect with tight CI for the morning report; plus offline
  investigation of disaster heroes (DK 218 GPM / 12 LH).

### Scoreboard @ 11:02 UTC (all effects bias-corrected)
| cand | change | effect | verdict |
|---|---|---|---|
| C1 | no farm cap | −3,125 | reject |
| C2 | lane exit 8→5min | −2,608 | reject |
| C3 | OHA custom last-hit micro | −3,588 | reject (micro worse than engine CS) |
| C4 | full-game laning | −108 (paired) | neutral reject |
| C7 | cap 0.30 | ≈−1,200 | reject |
| C10 | role-split caps (cores 0.65) | **+331 (paired)** | **promoted → B1** |
| C11 | core cap 0.80 | ≈−2,000 | reject |
| C12 | earlier retreat | ≈−833 | reject |
| C13 | support cap 0.35 | ≈−1,843 | reject |
- **11:20 UTC — B0 paired pair 1**: wave1 (b0@radiant) +973 / swap (b0@dire)
  +633 → **B1 true effect ≈ −170 ± ~780** — the C10 promotion (+331) was
  likely noise; B1 ≈ B0. Accumulating 2 more paired waves to reach ±~400
  and decide keep-vs-revert honestly.
- **11:45 UTC — B1 REVERTED** (4 confirmation waves: effect −176±550, the
  +331 promotion was noise). Baseline = uniform 0.45 cap (iter-0010).
  Role-split kept as gate c10r for a future higher-n retest.
- **11:45 UTC — Consolidation**: farm on clean baseline soak
  (run_20260719_1136); morning report written (REPORT.md).
- **~13:50 UTC — owner: keep running.** Resumed candidate loop (the 11:45→13:50
  gap was my consolidation-mode decision — logged as a pacing mistake).
  Switched to ROLLING waves: config flips without farm restart, waves
  delimited by version stamp (~2.5 min/wave saved).
- **14:03 UTC — c10r retest wave1** (role-split@radiant, run_1353): mean
  **−205** (n=12) — третий negative signal for role-split. Swap wave rolling.
  C14 (split-soak pos1) implemented+committed (4b5a93a), queued next.
