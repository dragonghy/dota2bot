# Turbo Bot-Quality Optimization Runbook

**Purpose.** This is the canonical, hand-off-ready playbook for improving the
bots' **turbo early-game behavior quality**. Any agent (or human) can pick up
the loop from here. It documents the infrastructure, the iteration loop, how to
find bugs, how to fix + A/B-validate + ship them, how to delegate to
sub-agents, and the hard-won gotchas. Read this first, every time.

> Optimization target = **TURBO mode** (`dota_force_gamemode 23`), early game.
> Quality is judged by *behavior* (do bots make good decisions?), measured via
> replay behavioral detectors + economy/deaths A/B — NOT by blind parameter search.

---

## 0. Current state (2026-07-20)

- **ALL-SPOT model (no standing farm).** The old on-demand "golden farm" was
  terminated (owner: use spot instances from now on). Launch farms on demand with
  `tools/batch_test/aws/spot_run.sh --count N` (self-terminating spot from AMI
  `ami-0a990a26d89c66547`); each boots true turbo + per-position draft + slot-1
  recording and ships to its own S3 run prefix. **Fresh spots are FASTER than the
  old golden farm was** — golden's run had thousands of backlog files that made
  the S3 collect loop crawl; a fresh spot run has none. Approval tier is **$100**
  cumulative (raised from $50); still terminate spots after each batch.
- **Behavioral pipeline is NOT on spots by default.** `/opt/behav` lived only on
  the (now gone) golden box. It's fully reproducible: run
  `tools/batch_test/behavioral/setup_instance.sh` over SSM on a spot when you need
  replay analysis (builds the Go/manta dumper from `dumper/main.go`). Validation
  A/B does NOT need it — it reads GPM/XPM/deaths/last_hits straight from
  `analysis.json`.
- **S3** bucket `dota2bot-batch-results-4924`: `soak/<run_id>/` = per-game `*.analysis.json` + `*.log.gz` (+ `*.dem` for slot 1); `replays/` = slot-1 `.dem` replays; `behavioral/` = detector rollups.
- **Bug queue = GitHub issues** (`dragonghy/dota2bot`, issues #2–#9, labels P0–P4). One coherent fixable unit per issue. Close with the A/B numbers when shipped.
- **Behavioral pipeline**: `tools/batch_test/behavioral/` (built on the farm at `/opt/behav`, a Go/manta replay dumper + Python detectors).
- **Shipped fixes so far**: turbo mode enabled; per-position draft; replay recording; **#2 TP-home suppression** (first data-driven behavioral fix, +51 GPM / −0.32 deaths).

---

## 1. VALIDATION POLICY — two classes of change, two yardsticks (owner, 2026-07-20)

Econ A/B can only resolve BIG effects (~30+ GPM at 20 games/comp). Micro-behavior
fixes worth ±5 GPM are invisible to it — that does NOT make them wrong. So:

**Class A — macro/balance changes** (farm-vs-fight desire, team strategy, big
numeric retunes — anything that could plausibly hurt globally): still require
multi-seed mirrored A/B (`mirror_multi.sh`, positive mean over ≥4 comps). This is
the regression gate that correctly killed c3 (−37 GPM) and corefarm (−17 GPM).

**Class B — micro-behavior fixes** (locally-correct reactions with a clear goal
and no plausible downside; e.g. "when an ally is attacked nearby, either attack
or flee — never stand idle"): do NOT gate on econ A/B. Ship when:
  1. verify gates pass (luacheck + unit tests + smoke);
  2. **behavioral evidence**: the target bad-behavior detector count drops
     clearly (e.g. idle_while_ally_dies 11→1/game) with no new bad behavior; and
  3. the goal is defensible from pro/meta play.
Quantity of small correct behaviors compounds into quality; each stays
turbo-only and individually revertible.

Replays are for FINDING problems (the owner's judgment → detectors → metric
library), not for gating every fix. Keep a spot soak farm producing replays.

## 1b. The iteration loop (SCAN → PICK → FIX → VALIDATE → PROMOTE)

### SCAN — find bugs
Two complementary sources; use both:
1. **Watch replays** (like the owner does — irreplaceable for NEW ideas). Presign a slot-1 replay and open it in Dota:
   ```bash
   awsx s3 ls s3://dota2bot-batch-results-4924/replays/            # newest slot1.dem
   awsx s3 presign s3://dota2bot-batch-results-4924/replays/<TAG>.dem --expires-in 604800
   ```
   In Dota: put `.dem` in `.../game/dota/replays/`, console `playdemo replays/<name>` (no `.dem`), `demoui` for scrub/speed.
2. **Run the behavioral detectors** across recorded replays for an objective, ranked bug leaderboard:
   ```bash
   awsx ssm send-command ... 'bash /opt/dota2bot/tools/batch_test/behavioral/batch_s3.sh'
   ```
   Detectors implemented: `sandwiched_walk` (walk into 2+ enemies), `idle_while_ally_dies`, `tp_home_wasteful`, `tp_under_threat`. Add new detectors for new bug classes (they encode the owner's replay observations as automated checks — this is the leverage: one human observation → scans every game).

**As the orchestrator, keep watching replays and filing new GitHub issues.** Themes worth studying: (1) laning strength, (2) hero coordination, (3) teamfight quality, (4) per-hero script correctness (e.g. Warlock skill build/understanding). Break big issues (like #8 laning craft) into smaller ones as replays reveal specifics.

### PICK
Take the highest (frequency × owner-priority × tractability) open issue. P0/P1 first.

### FIX — implement a gated change
Every fix is **turbo-gated + soak-candidate-gated** so it only affects the candidate team of an A/B and NEVER ships untested. Template = the shipped `J.ShouldStayAndRegen` (commit `bdb6c01`, `bots/FunLib/jmz_func.lua`):
```lua
function J.ShouldXxx( bot )
    if not J.IsSoakCandidate( '<id>' ) then return false end   -- candidate-only during A/B
    if not J.IsModeTurbo() then return false end               -- turbo-only always
    ... conservative conditions ...
end
```
- `J.IsSoakCandidate('<id>')` reads the farm-only `bots/Customize/soak_side.lua` `{ side='radiant'|'dire', cand='<id>' }`; false everywhere off-farm → inert in shipped Workshop code.
- `J.IsModeTurbo()` uses `GetGameMode()==GAMEMODE_TURBO`.
- Wire the helper into the relevant desire/consider function. Keep it CONSERVATIVE — only fire in the exact bad case; let normal behavior fall through.
- **TS-generated Lua** (`aba_push`, `aba_defend`, etc.): edit the `.ts` under `typescript/bots/` too, keep in sync.

**Verify (hard gates, never skip):**
```bash
luacheck bots game --formatter plain   # 0 warnings
lua5.1 tests/run_tests.lua             # 0 failures
lua5.1 tests/run_tests.lua smoke       # every hero file loads under mock API
```

Commit to a branch referencing the issue; push.

### VALIDATE — mirrored-draft A/B (the standard gate)

**Use `tools/batch_test/soak/mirror_ab.sh`.** The random-draft wave+swap below
is noise-limited (draft variance ±600 GPM/game swamps a behavior fix — see the
gotcha in §3). The mirror harness pins the draft seed so BOTH waves run the
IDENTICAL 10-hero draft, swapping only which side carries the fix; averaging the
paired diff cancels side bias AND draft, giving a clean `fix_effect`:
```bash
INST=i-08b59ef7130025860 RUN=run_20260719_1601 \
  tools/batch_test/soak/mirror_ab.sh <cand-id> <seed> 12
# prints ABdiff/BAdiff + fix_effect for GPM/XPM/deaths, and a
# `distinct drafts=1` sanity line (must be 1). Confirm a win across 2-3 seeds
# before promoting (one seed = one comp; may not generalize).
```
Parallelize across fixes with spot farms (§2/§4): golden farm runs one candidate,
each spot (`spot_run.sh --count N`) runs another; drive each with its own
`INST=<id> RUN=<run_id>`. **Lesson (iterations/0010): conservative *suppression*
fixes (e.g. #4 "don't dive into 2+ enemies": +20 GPM / −0.39 deaths) win;
*active re-engagement* fixes (#5 join-or-flee, #3 walk-then-TP) tested worse —
they carry their own farm/positioning cost. Prefer suppression.**

### VALIDATE (legacy random-draft) — A/B on the farm
Deploy the candidate (rolling; no restart — the gate + code are read per game):
```bash
# on the farm, via awsx ssm:
cd /opt/dota2bot && sudo -u ubuntu git pull -q origin main
echo "return { side = 'radiant', cand = '<id>' }" | sudo -u ubuntu tee bots/Customize/soak_side.lua
echo "gate:<id>:cand=radiant" > /opt/soak/ab_version   # version stamp for filtering games
```
Wait ~12–15 min for a 12-game wave (breakdown: ~5 min for in-flight non-candidate games to clear, then 12 parallel candidate games at ~5–6 wall-min each; monitor polls S3). Then **flip to swap** (`cand='dire'`) and collect a second wave.

**Metrics** (from each game's `analysis.json`, split by team):
- Economy A/B (all 12 slots, fast): per-hero **XPM / GPM / deaths**, candidate side vs baseline side.
- **Bias correction is mandatory**: radiant has a ~+1.5k gold side bias. Paired verdict = `(wave1_diff + swap_diff)/2` cancels it (wave1 cand=radiant, swap cand=dire).
- Behavioral (slot-1 replays): detector count for the fix's bug class, candidate-side heroes vs baseline-side (map hero→team via `analysis.json`).

Accept if the fix's target metric improves (bug count down / deaths down / farm up) **AND** economy is not hurt, bias-corrected, over ~24 games (wave + swap).

### PROMOTE — ship it
Remove the `IsSoakCandidate` gate (keep `IsModeTurbo`), so it applies to all turbo games; normal mode stays unchanged. Verify gates again, commit to `main`, push, `git pull` on the farm, clear `soak_side.lua`/`ab_version`. **Close the GitHub issue with the A/B numbers.**

---

## 2. Sub-agent delegation (parallel fixes)

- Spawn **worktree-isolated** sub-agents (`isolation: "worktree"`) — one per issue — to do CODE ONLY: implement the gated fix, pass the 3 verify gates, commit to their branch, push, report the SHA + gate id. They must NOT touch AWS/the farm or deploy.
- **The orchestrator owns validation + the farm + all AWS/spot lifecycle** (avoids soak_side collisions and spot leaks). Validate each returned branch via the A/B loop above; promote winners; merge.
- To parallelize *validation*, the orchestrator may launch a few **spot** instances (see §4) it controls, running different candidates concurrently, each with a self-terminate watchdog, torn down after. Never let a sub-agent manage spot teardown.

---

## 3. Hard-won gotchas (do not relearn these)

- **Turbo requires `+dota_bot_practice_start 1`** (NOT `+dota_start_ai_game 1`) with turbo cvars (`dota_bot_practice_gamemode 23`, `dota_force_gamemode 23`, `dota_lobby_browser_selected_gamemode 23`, `dota_bot_practice_difficulty 3`) set BEFORE `+map dota`, plus `-fill_with_bots`. Verify: levels ~10-12 @10min (turbo) vs ~6-7 (normal); team GPM sum ~25k vs ~20k.
- **Game-end / 30-or-10-min cap**: bot scripts can't end a game. The referee (`tools/batch_test/soak/referee.py`) extrapolates game time from `Building:` destruction timestamps and at the cap sets `dota_surrender_on_disconnect 1` + `dota_auto_surrender_all_disconnected_timeout 1` via rcon → the all-bot game ends in seconds with a full signout. (`dota_dev forcewin` is a NO-OP here — don't trust it.)
- **Bot `print()` never reaches the dedicated-server console**, and the engine's error handler is broken (`error in error handling` masks all Lua error text). You cannot debug via bot-side logging. Use the replay (behavioral pipeline) or in-game observation.
- **Replay attribution**: only slot 1 records; purge stale `.dem` before each slot-1 launch (done) or the "newest .dem" upload mislabels a leftover game (this caused a phantom `arc_warden`/"Gordon" hero).
- **Radiant side bias** ~+1.5k gold — always A/B with a swap wave and average.
- **The econ/deaths A/B is NOISE-LIMITED (critical).** The soak draft gives each
  side *different random heroes every game*, so radiant-vs-dire econ is confounded
  by draft; the swap only cancels the ~+1.5k *side* bias, not draft variance.
  Measured per-game candidate−baseline team-GPM diffs span **−1380…+973** (SD ≈
  600 GPM); over 12 games the SE on the mean is ~170 GPM, so a ~40 GPM fix effect
  is invisible. See `iterations/0010`. **Implications:** (a) for behavior fixes,
  use the **behavioral detectors** as the primary metric (dense, direct), not
  end-of-game econ; (b) to make econ usable, build a **mirrored-draft** harness
  (same 10 heroes both sides, swap the fix) so draft cancels. Don't declare an
  econ win/loss from a single 12-game wave+swap — it's within noise.
- **Wave timing** ~12-15 min for 12 games (see §1 VALIDATE). Spot-parallel to halve wall time.
- **Per-position draft**: `tools/batch_test/soak/hero_pool.txt` = `name,positions,tier` (positions like `1/3`); `gen_soak_pool.py` emits `{name, pos={...}}`; `custom_loader.ApplySoakDraft` assigns each drafted hero to a position it can play. Regenerate the pool on the farm after editing hero_pool.txt.

---

## 4. AWS / farm ops

```bash
bash tools/batch_test/aws/session_setup.sh      # once per session; then use `awsx` (never raw aws)
# launch N self-terminating spot farms (each = its own S3 run prefix):
bash tools/batch_test/aws/spot_run.sh --count N --ref main --slots 12 --hours 2
# wait for a spot to be SSM-reachable + farm-producing, then drive it over SSM
# (scratchpad has spot_wait.sh / spot_multi_driver.sh helpers from the last run):
INST=<spot-id> RUN=<spot-run-id> tools/batch_test/soak/mirror_multi.sh <cand> "<seeds>" 12
awsx ec2 terminate-instances --region us-west-2 --instance-ids <spot-ids>   # ALWAYS after a batch
bash tools/batch_test/aws/check_costs.sh        # spend + running instances (want EMPTY between batches)
```
**Spend policy**: owner approval at each **$100** cumulative tier. After any spot
work, run `check_costs.sh` and terminate leftovers (spots also self-terminate via
2h watchdog + shutdown-behavior=terminate, but terminate explicitly too). A
c6i.4xlarge is ~$0.68/hr on-demand, ~$0.26/hr spot. Recompute a run's verdict
straight from S3 if the live aggregator hiccups (bulk `aws s3 cp --recursive
--include '*.analysis.json'`, group by the `mirror:<cand>:s<seed>:<side>` stamp).

---

## 5. What "good" looks like (quality goals from owner replay review)

Laning: winning laners zone/orb-walk; losing laners creep-pull (勾线) to reset; supports deny+harass (don't steal carry CS); no unintentional spell-pushing; pull camps to control equilibrium. Fights: commit only on lethal-or-numbers, never dive 2+ enemies blind; never idle while an ally dies; rotate mid to defend. Macro (turbo, cheap TP): punish tower-dives/overextension with TP collapses; after aegis group and press, don't scatter-farm or solo-dive. Per hero: correct skill build + ability sequencing (e.g. Skywrath silence→burst, Warlock lane sustain not self-channel into creeps). Turbo: heal in lane via bought regen, almost never TP home for state.

Each of these is (or becomes) a GitHub issue + a behavioral detector + an A/B-validated fix.
