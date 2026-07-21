# Transfer Notes — read this first if you're taking over

A single handoff map: **the tools, what's shipped vs still dark, what's open,
and the learnings that cost real batch runs.** For loop mechanics see
`docs/TURBO_QUALITY_RUNBOOK.md`; for the mandated stage-by-stage loop see
CLAUDE.md → "Iteration Workflow (REQUIRED)"; for project goals see
`docs/PROJECT.md`. This file is the status board + orientation.

_Refreshed 2026-07-21 (iteration 18). Target: **Turbo** early/mid-game quality
for the 5 focus heroes — Axe, Zeus, Wraith King (`skeleton_king`), Lion,
Crystal Maiden. Iter 18: full lane-control cluster (#8) + #6/#9/#17/#20 landed
as gated fixes; backlog of fixable items cleared — remaining work is A/B
validation (owner-deferred)._

---

## 1. The loop, in one paragraph

**Observe replays frame-by-frame → find one concrete bad decision → write a
gated fix → luacheck + unit tests + smoke → LOCAL replay-fixture validation
(cheap, mandatory) → accumulate ~10 → ONE batch A/B as the final gate → merge
only on measured improvement.** Fixes land **gated** (a soak-candidate id;
inert in real games) and are promoted one lever at a time. The batch simulator
is the **rare final exam, never the per-change validator** — the owner corrected
this sharply once; do not regress on it.

## 2. Tool inventory (all present on the branch)

| Tool | Path | What it does |
|---|---|---|
| **ReplayScope** | `tools/batch_test/replayscope/` (`build.py`, `template.html`) | Replay timeline → self-contained scrubbable web page: square minimap + hero portraits, global/radiant/dire **vision toggle**, per-tick state table (level, view-scoped net worth, items 6+3 slots, CS/deny, KDA, ability/CC cooldowns). The primary "watch the replay" surface. |
| **Local replay-fixture validator** | `tools/batch_test/replayscope/make_fixture.py` + `tests/mock/replay_fixture.lua` + `tests/fixtures/f_*.lua` | Freeze one decision instant from a behav-dump timeline (all 10 heroes' real pos/HP/mana/level/team/items/tp_cd/abilities + ground truth: per-enemy damage dealt to the subject in the next 5s, `died_after`). Rebuilds it under the mock Bot API and runs the **real** `jmz_func` helpers (zero J.* stubs) and full hero `SkillsComplement` via `load_hero`. **This is the cheap layer that catches "did the fix fire on the real frame".** 10 fixtures exist (Luna chase, Sky rescue, Oracle screen/wander, QOP salve, Sven idle, Zeus mana/Lina, WK lane/revive). |
| **Behavioral pipeline** | `tools/batch_test/behavioral/` (`dumper/main.go`, `detect.py`) | Go/manta replay dumper → Python **detectors** counting named bad behaviors (`overextend_alone`, `sandwiched_walk`, missed-CS-at-tower `d9`, …). Detector deltas = the Class-B metric. Build on a spot via `setup_instance.sh`. |
| **Mirrored-draft A/B** | `tools/batch_test/soak/mirror_multi.sh` (spot `aws/spot_run.sh --validate`) | Same 10 heroes both sides, swap the candidate per wave → cancels draft variance + side bias. The Class-A final gate. |
| **Soak farm (spot)** | `tools/batch_test/aws/spot_run.sh` | Self-terminating spot; true Turbo + per-position draft + slot-1 recording → own S3 run prefix. No standing farm; launch on demand. |
| **Gating** | `bots/Customize/soak_side.lua` (gitignored) | `J.IsSoakCandidate('<id>')`; `J.IsLaneFixActive()`/`J.IsLaneFixOn(sub)` wrap the `lanefix` bundle. A fix is a no-op unless Turbo + its id is armed. |

## 3. Status board

### Shipped & LIVE in Turbo (default-on, gated only on `IsModeTurbo`)
- **#2 TP-home suppression** — first data-driven behavioral fix (+51 GPM / −0.32 deaths).
- **#7 punish enemy tower-dive** — `J.ShouldPunishDive`.
- **#6 don't solo-overextend / regroup** — `J.ShouldRegroupNotSolo`.
- **#17 avoid death-zone** — `J.ShouldAvoidDeathZone`.
- **don't blind-dive 2+ enemies** — `J.ShouldSuppressDive` (critical-HP clause: a bot below ~35% HP no longer counts as a full fighter for parity).
- **#19 Vengeful Spirit solo-forward suppression** — promoted, Turbo-only, Class-B.
- **#14 support/carry last-hit division** partial via `suplh` (verify gating before claiming default-on).

### On the branch but GATED (inert; not live)
- **`lanefix` bundle** (from the 071423/071859/etc. replay review; each fix has its own `lf_*` id): `lf_chase` (`ShouldNotChaseWhenLow`), `lf_mana` (`ShouldConserveManaInLane`), `lf_salve` (lane regen use), `lf_rescue` (`GetRescueTpTarget` — counter-gank TP to save a caught ally), `lf_revive` (`ShouldFleeAfterRevive`), `lf_recover` (`ShouldLaneRecoverFarm`), `lf_support` (support stays with/screens carry), `lf_threat` (`NoteProvenKillerOnDeath`/`ShouldRespectProvenKiller`), `lf_undertower` (parked). **All fixture-validated locally; REJECTED as a bundle at the final gate (see §4). Not live.**
- **`depthnum`** (#18) — depth-discounted numbers in `SafeToCommitFight`.
- **`nodive2`** (#4) — sharpened dive trigger. **`nopush`** (#12) — no accidental wave-shove. **`wlok`** (#9) — Warlock laning build.
- **Lane-control cluster (iter 17–18, all gated, unit-tested, inert):**
  `creeppull` (#10 `J.ShouldCreepPullLane` — disadvantaged core draws enemy-creep
  aggro), `bodyblock` (#11 `J.ShouldBodyBlockHarass` — advantaged core harasses on
  a winnable trade), `pullcamp` (#13 `J.ShouldPullNeutralCamp` — support pulls a
  friendly camp), `midtp` (#15 `J.ShouldTpSupportTowerFight` — mid 6-level TP to a
  tower fight), `aegisgroup` (#6 `J.ShouldGroupWithAegis` — no solo-dive with
  aegis), `skysilence` (#9 Skywrath — no lone value-less silence), `tpsafe2`
  (#9 Slardar — no interruptible TP), `overchase` (#20 `J.ShouldPunishOverchase` —
  turn and punish an enemy over-chasing our low ally), `wkbuild` (#17 WK
  earlier-2nd-stun skill build for kill participation).
  **All await A/B; promote one lever at a time.**

### Rejected by A/B (recorded negatives — do NOT retry)
- **`c3`** active last-hit micro **−37 GPM** (0/4); **`corefarm`** cap raise **−17 GPM** (0/4). → forcing cores to farm more is the wrong lever in Turbo (#16).

## 4. The lanefix rejection (the most important recent result)

The `lanefix` bundle — 8+ individually locally-correct, fixture-clean guards —
was **REJECTED by the mirrored final gate twice: gpm −74.5, then −88.7 (0/4
comps).** Nothing shipped (all gated). Diagnosis via a behavioral diff on the
batch's own replays: **primary culprit `lf_recover`** (cores 19% off-lane vs
10%, CS@8 −48%), **secondary `lf_support`** (clumping −23%); the retreat guards
were **exonerated** (overextend −75%, oscillation only +6%). `lf_recover` and
`lf_support` were then narrowed at the fixture level, `lf_undertower` parked for
a solo A/B. **Next final gate** (owner-gated, ~$1): the re-narrowed bundle
without undertower — run only after the owner has seen the reject analysis.
**Takeaway → the crux learning below.**

## 5. "Have we done X?" — the owner's behaviors question (honest answer)

| Behavior (owner's words) | Status | Where |
|---|---|---|
| **拉野 / 控兵线** (creep-pull, lane-equilibrium control) | **DONE (gated, awaiting A/B)** | Full lane-control cluster #8 implemented: `creeppull` (#10 勾线 disadvantaged), `bodyblock` (#11 body-block advantaged), `pullcamp` (#13 pull camps), plus `nopush` (#12) and `suplh` (#14). All gated + unit-tested; none promoted yet. |
| **支援其他路** (rotate to help other lanes) | **Partial / NOT general** | `GetRescueTpTarget` (`lf_rescue`, gated) counter-gank TP to save a caught ally; `midtp` (#15 `J.ShouldTpSupportTowerFight`, gated) TPs mid to a friendly-tower fight. Still **no general lane-rotation / gank-other-lane** desire. |
| **惩罚对面深入走位 / 冲塔** (punish enemy overextension / dive) | **DONE & live** | `J.ShouldPunishDive` (#7), backed by `ShouldRegroupNotSolo` (#6) / `ShouldSuppressDive` / `depthnum` (#18, gated) keeping *our* side from over-committing. |
| **惩罚对面追击** (punish an enemy who over-chases us) | **DONE (gated, awaiting A/B)** | `overchase` (#20 `J.ShouldPunishOverchase`) turns nearby allies to collapse on an enemy solo-chasing our low ally deep into our half (gated on `SafeToCommitFight`). Distinct from `J.ShouldNotChaseWhenLow` (us not over-chasing — the inverse). Diagnostic detector `d20_enemy_overchase_unpunished` added. |

## 6. Learnings that cost real runs
1. **Locally-correct ≠ emergently-good (the crux).** Fixture-clean guards → net
   −88.7 GPM as a bundle. Local validation answers "is the decision correct";
   only the batch answers "is the aggregate good." Ship gated, one lever, and
   diagnose rejects by behavioral-diffing the batch's own replays.
2. **Turbo econ is kill/push/passive-driven, not last-hit-driven** — c3/corefarm
   both worse. Low CS is a symptom.
3. **Econ A/B is noise-limited** (SD ≈ 600 GPM/game); use mirrored-draft +
   behavioral detectors.
4. **Radiant side bias ≈ +1.5k gold** — swap-and-average.
5. **No bot-side debugging** — `print()` dropped, error handler broken.
6. **Harness (bash) changes need a soak-loop restart; Lua changes don't.**
7. **In-memory wakeup chains die on session suspend** — background `sleep`
   heartbeat, re-armed each wake; the farm runs on regardless.

## 7. Operational state
- **Branch: `main` only (owner directive 2026-07-21).** Commit and push all
  changes directly to `main` — no dev/feature branches. On/off control for any
  behavior change is a **gate** (`J.IsSoakCandidate('<id>')` + `J.IsModeTurbo()`),
  not a branch. (History note: work through iter 17 lived on
  `claude/affectionate-dirac-qumja6`, now fast-forwarded into `main`.)
- **No standing farm.** All-spot; approval tier **$100** cumulative. Always
  launch via `spot_run.sh` (self-terminating spot); run `check_costs.sh` +
  terminate leftovers after every batch (last known: no leaked instances).
- **Verify before every push:** `luacheck bots game --formatter plain` (0
  warnings) + `lua5.1 tests/run_tests.lua`.
- **Watch state drift:** trust git history + this file + GitHub issues over any
  single stale note; `iterations/state.json` is the running record (iter 17).
