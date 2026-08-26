# Dota 2 Bot Scripts — Agent Guide

This file is the **shared always-on project prompt**. Both Cursor and Claude Code
load it (Cursor natively; Claude Code via `CLAUDE.md` importing it). Task
playbooks live in `.claude/skills/` (both tools discover that directory).
Specialist workers live in `.claude/agents/` (both tools discover that too).

Tool-specific runtime notes are **not** in this file:

- Claude Code only: `.claude/rules/claude-code.md`
- Cursor only: `.cursor/rules/cursor-runtime.mdc`

## Who runs where (2026-08-24)

Owner-facing chat is **Cursor**. The five automation streams still run as
**Claude Code Cloud Routines** for the next stretch (about a month). Do not
move those jobs onto Cursor Automations until the owner says so.

| Seat | Host | Job |
|---|---|---|
| Integrator (talks to the owner) | **Cursor** | Schedule (turn owner intent into `OWNER_PRIORITIES` / issues / `queue.json` / charter edits), summarize from reports, watch dropped batons. Charter: `HANDOFF.md`. |
| batch-desk / replay-check / strategy / hero / director | **Claude Code Routines** | One work unit per 2h fresh session. Charters: `iterations/streams/*.md`. Prompt templates: `iterations/streams/routine_prompts.md`. |
| On-demand specialists | `.claude/agents/` | `batch-runner`, `replay-analyst`, `replay-artifact` — spawned by the integrator for a one-off (replay page, harvest, frame diagnosis). |

If you are the integrator, read `HANDOFF.md` next. If you are a named stream,
read `iterations/streams/README.md` then your own charter — do not wait for a
Claude Code main session; that seat moved.

---

## What This Project Is

This repo is an **independent Dota 2 bot script project** focused on a small hero pool. It started from a snapshot of the community project [OpenHyperAI (OHA)](https://github.com/forest0xia/dota2bot-OpenHyperAI) at Patch 7.41/7.41a (127 heroes supported) and evolves on its own — upstream merges are not planned. The goal: make 10-15 focus heroes play clearly better than default bots, verified by batch A/B win-rate testing, and eventually publish to the Steam Workshop. The project has no final name yet.

**The optimization target is TURBO mode (`dota_force_gamemode 23`), not normal mode.** All batch A/B validation runs in Turbo, and hero logic should be tuned for Turbo's pace: faster gold/XP (item timings arrive much earlier), weaker towers, shorter games (~20 min), grouped pushing pays off more. When a tuning decision differs between normal and Turbo, Turbo wins.

**Current focus heroes (deep polish targets):** Axe, Zeus, Wraith King (`skeleton_king`), Lion, Crystal Maiden.
**Candidate pool for later:** Luna, Sniper, Death Prophet, Tidehunter, Dragon Knight, Witch Doctor, Lich, Warlock.

**The iteration loop for hero polish is data-driven** — see **"Iteration Workflow"** below. Short form: watch replays frame-by-frame → find a concrete bad decision → narrow gated fix → **local replay-fixture validation (cheap, mandatory)** → accumulate ~10 validated fixes → ONE batch A/B run as the final gate → merge only on measured improvement. The simulator is the rare final exam, never the per-change validator. No hero-logic change ships on intuition alone.

**What ships vs what doesn't:** only `bots/` (pure Lua) is the Workshop deliverable. `tests/`, `tools/`, `typescript/`, `.github/` are dev-only.

**Layout is load-bearing:** the Dota bot API loads scripts by fixed path and name (`bots/hero_selection.lua`, `bots/BotLib/hero_<internal_name>.lua`, mode scripts, etc.). Never rename, move, or delete Lua files under `bots/` or `game/`.

See **[docs/PROJECT.md](docs/PROJECT.md)** for the full project statement, testing tiers, and roadmap.

## Key Documentation

- **[docs/PROJECT.md](docs/PROJECT.md)** -- Canonical goals, hero pool rationale, testing methodology (T0-T3), roadmap
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** -- The inherited OHA codebase architecture: file map, naming conventions, all systems explained
- **[docs/PATCH_UPDATE_GUIDE.md](docs/PATCH_UPDATE_GUIDE.md)** -- Our runbook for adapting to new Dota 2 patches
- **[docs/BOT_API_REFERENCE.md](docs/BOT_API_REFERENCE.md)** -- Valve bot scripting API reference
- **[docs/TURBO_QUALITY_RUNBOOK.md](docs/TURBO_QUALITY_RUNBOOK.md)** -- Iteration method, Class-A/B validation, AWS farm

**Read the relevant docs FIRST before making changes.** They contain everything needed to make targeted updates without scanning the entire repo.

Current lab state (not the docs): `iterations/OWNER_PRIORITIES.md`, `iterations/streams/test_set.md` (latest § only), `iterations/streams/README.md`, GitHub issues. `iterations/state.json` is the historical verdict archive.

## Iteration Workflow (REQUIRED — agents follow this exactly)

The owner-approved loop. Each stage has its own tool; do not skip stages and do
not promote a cheaper stage's job to a more expensive stage.

1. **Observe** — watch replays **frame by frame** like a human reviewer
   (ReplayScope: `tools/batch_test/replayscope/`, dumper in
   `tools/batch_test/behavioral/`). Aggregate stats alone are NOT observation;
   they hide the story (a hero can farm zero for 3 minutes without ever dying).
2. **Find** — a concrete bad decision at a concrete timestamp, with vision
   context (what could the bot actually see?).
3. **Fix** — a narrow, locally-correct change, gated behind a soak candidate
   (`J.IsSoakCandidate`), so shipped defaults stay unchanged until validated.
4. **Local validation (MANDATORY, cheap, frequent)** — reproduce the exact
   decision instant and assert the fixed decision:
   `tools/batch_test/replayscope/make_fixture.py <timeline> --t <sec> --hero <name>`
   → fixture in `tests/fixtures/` → load via `tests/mock/replay_fixture.lua`
   (real jmz_func helpers run on the real frame; no J.* stubs) → unit test.
   Gate-plumbing tests are NOT local validation. **Do not touch the simulator
   here.** Case study: the first low-HP-chase guard passed its gate tests but
   did not fire on the very frame that motivated it (visible 2v2 parity counted
   the dying bot as a full fighter) — the fixture caught it in seconds
   (`tests/test_replay_071423_luna_chase.lua`); a rejected simulator bundle
   could not say why.
5. **Accumulate** ~10 locally-validated fixes.
6. **Final gate (RARE)** — ONE batch A/B (`tools/batch_test/`, mirrored-draft,
   self-terminating spot). Merge only on measured improvement. Never launch a
   per-change or per-fix-isolation batch; that burns the expensive stage on the
   cheap stage's question.

Task playbooks for steps 3–4 live in `.claude/skills/gated-fix/` and
`.claude/skills/replay-fixture/`.

## Autonomous mode (owner-toggled)

When the owner says to work autonomously ("继续干不要停 / 不要等我"), that is a
**standing instruction until they revoke it**:

- **Do not stop to ask for input or approval on anything inside the approved
  loop** (observe → find → gated fix → fixture validation → commit+push).
  Finish a work item and immediately start the next one from the backlog; if
  the backlog is empty, generate more work (watch more replays frame-by-frame,
  codify watched problems into detectors, extend fixtures/coverage).
- Stopping to wait is the failure mode the owner has explicitly complained
  about. End a turn only when genuinely blocked on something outside the loop
  (AWS $-tier approval, a destructive/irreversible action, or a true design
  fork with no conservative default) — and even then, pick the conservative
  default where one exists, note the decision, and keep going.
- The owner toggles back with words to the effect of "恢复等我模式" — then
  return to confirming before each major step.
- Exception that always holds regardless of mode: the AWS spending tiers and
  the "simulator only as the rare final gate" rule.

## Subagent profiles (owner-directed division of labor)

Three specialist profiles live in `.claude/agents/`. **The main session DOES
NOT do these jobs itself anymore — delegate to those subagents** (the owner
explicitly directed this):

| Profile | Job | Hand it |
|---|---|---|
| `batch-runner` | AWS 批测全流程:launch(镜像A/B, on-demand, bundle 支持)、监控、收 verdict、被抢占时本地恢复、汇总多 seed 结果、成本与泄漏检查 | "跑一轮批测 / 收批测结果 / 查实例花费" |
| `replay-analyst` | 录像诊断:逐帧还原(硬规则:先逐帧后聚合)+ 检测器/经济差分 + fixture 钉帧 | "看录像找问题 / 诊断批测行为差异" |
| `replay-artifact` | ReplayScope 网页制作 + Artifact 发布 + 时刻导览 | "把录像做成页面给 owner 看" |

Main session keeps: writing/fixing bot Lua + tests, promote/reject decisions,
owner communication, and synthesizing the specialists' reports. Each profile
embeds the operational hard-knowledge (awsx wrapper, $-tier policy, 4-seed
promote bar, depth sign convention, dumper build recipe, artifact publishing
rules) — keep the profiles updated when that knowledge changes.

The five scheduled streams (batch-desk / replay-check / strategy / hero /
director) still run as Claude Code Routines. Their charters live in
`iterations/streams/`. The owner-facing integrator is Cursor (`HANDOFF.md`).
Do not steal stream jobs from an integrator session, and do not wait for a
Claude Code main session — that seat moved.

## Gated fixes (soak candidates) — behavior changes ship dark first

Every new behavior fix lands **gated**: it is a no-op unless (a) the game is
Turbo and (b) its soak-candidate id is armed. The gate file is
`bots/Customize/soak_side.lua` (gitignored; on the farm it returns
`{side, cand, seed}`). Helpers read it via `J.IsSoakCandidate('<id>')`;
convenience wrappers like `J.IsLaneFixActive()` / `J.IsLaneFixOn(sub)` gate a
whole bundle while each fix keeps its own `lf_*` id for isolation. This lets a
fix ride the branch (and A/B candidate waves) while staying **inert in real
games** until it passes its gate and is promoted (gate removed / made
default-on). **A gated fix on the branch is NOT live** — don't call it shipped
until it's ungated. The authoritative list of gated-and-unpromoted ids lives in
`iterations/state.json` (it changes weekly).

**Promoted turbo defaults (no gate left — these are LIVE in every Turbo game):**
`lanesurv`, `tphome`, `tpsafe`, `tpsafe2`, `pushguard`, `nodive`, `punish`,
`regroup`, `deathzone`, `vsafe`, `skyburst`, `fight`, `roamstale`, and
`creeppull`+`pullbeat` (2026-08-23, `stable-v2` — the first pair to clear all
three of the owner's rule-2 conditions; promoted as ONE atom because `pullbeat`
sits inside `creeppull`'s execution body and `creeppull` alone is the broken
configuration GH #143 measured). Read this
list off the source, not off prose: each promoted helper carries a `PROMOTED
(was soak-candidate '<id>')` note above it, and `tests/test_gate_claim_consistency.lua`
fails if any comment claims a gate that no longer exists (or never did). Note
`nodive`/`punish` are promoted while their *extensions* `nodive2`/`ownhalf`
stay gated — the helper ships, the sharpened domain does not.

## Hard-won learnings (don't relearn these — they cost real batch runs)

- **Locally-correct ≠ emergently-good (the crux).** The bots are finely
  balanced; a *bundle* of individually-defensible, fixture-validated guards had
  a strongly NEGATIVE aggregate effect — the `lanefix` bundle was fixture-clean
  yet the final-gate batch **REJECTED it twice** (gpm −74.5, then −88.7, 0/4
  comps). Local validation answers "is this decision correct"; only the batch
  answers "is the emergent aggregate good." Ship gated, one lever at a time; the
  diagnosis path is a behavioral diff on the batch's own replays (here: primary
  culprit `lf_recover`, secondary `lf_support`; the retreat guards were
  exonerated), then re-narrow at the fixture level.
- **Turbo economy is kill/push/passive-driven, not last-hit-driven.** Forcing
  cores to farm more measured WORSE (`c3` active-last-hit −37 GPM; `corefarm`
  cap-raise −17 GPM, both 0/4). Low core CS in Turbo is a *symptom*, not a lever
  — pull on winning fights / objectives / fewer pointless deaths (issue #16).
- **The econ/deaths A/B is noise-limited** (random-draft SD ≈ 600 GPM/game; a
  ~40 GPM fix is invisible over 12 games). Use **mirrored-draft** (same 10 both
  sides, swap the fix) + **behavioral detectors**, never a single-wave econ read.
- **Radiant side bias ≈ +1.5k gold** — always swap-and-average.
- **No bot-side debugging** — `print()` never reaches the server console and the
  engine error handler is broken (`error in error handling` masks all Lua error
  text). Debug via replays / in-game observation / bisection.
- **Harness (bash) changes need a soak-loop restart** (a long-lived loop caches
  the old file); **Lua hero changes do not** (each game re-reads `bots/`).
- **Promoting an id silently kills any gate that names it.** A gate written as
  `IsSoakCandidate('X') and IsSoakCandidate('Y')` — the good way to make a
  dependency code instead of prose — is frozen FALSE the day `Y` is promoted,
  because a promoted id is in no armed string. The lever then no-ops in every
  wave, `check_armed_wiring.py` still calls it WIRED (it checks that a call site
  exists, not that the predicate can be true), and the verdict reads back
  "tested, no effect" with nothing raising a hand. Before promoting anything,
  grep the id for appearances in OTHER gates' conditions and fix them in the
  same change. Caught on `pullcad` during the `creeppull`/`pullbeat` promote.
- **Batch instances clone `origin/main` at launch — verify the remote tip
  equals the tree you mean to test BEFORE launching.** Near-miss 2026-07-23: a
  4-seed all-on rerun launched while 8 fix commits existed only locally (the
  session had been "pushing" a stale side branch); the instances would have
  measured the wrong tree with a bundle id that didn't exist in their clone.
  Cost of the kill+relaunch: <$0.5. Check `git ls-remote origin main` first.

## Verification (run before every push)

```bash
bash tools/agent/luacheck_gate.sh      # static half: buys luacheck, then runs it
lua5.1 tests/run_tests.lua             # unit tests under mock Bot API (tests/)
```

- **A fresh container has neither binary, and that is not a reason to skip
  either half** (GH #205). The gate script installs what it needs first
  (`tools/agent/ensure_lua_toolchain.sh`, bounded + guarded + silent on
  failure); measured cold, end to end, **18s** — 5.5s to install, 13s to run,
  0 warnings on trunk (2026-08-26). It exits **0 clean / 2 could-not-run /
  3 warnings**, so a gate that did not run cannot be mistaken for one that
  passed. `lua5.1` is bought the same way by 开工自检.
  ⚠️ The apt package is **`lua-check`**, not `luacheck` — `apt-get install
  luacheck` answers `Unable to locate package`, and *that* is why three
  separate rounds recorded "luacheck isn't in apt" and skipped rule 6's first
  door. `.github/workflows/ci.yml` has always had the right name.
- Running `luacheck bots game --formatter plain` by hand is still fine — it is
  the same command the gate runs. What the script adds is that it cannot be
  passed by not running.
- `.luacheckrc` whitelists all legit Bot API / engine globals. A new "accessing
  undefined variable" warning means a typo or a leaked local — fix the code;
  only extend `read_globals` for a genuinely new engine API.
- The Dota bot VM is Lua 5.1: **no `goto`**, no `table.unpack` (use `unpack`).
  luacheck won't catch 5.2+ syntax, but the smoke test (`tests/test_smoke_load.lua`)
  will — it loads every hero file under `lua5.1`.
- The full suite does not finish in one process in a routine container
  (~100 min, GH #124). Markdown-only changes may skip it.
- Batch in-game A/B testing scaffolding lives in `tools/batch_test/` (requires a
  machine with Dota 2 installed; not part of CI). Hero-logic changes need an
  A/B win-rate validation pass before merging.

## AWS Access (for a new session/agent)

Batch testing runs on the owner's AWS account. Credentials do NOT persist
across sessions (each container is fresh and the repo carries no secrets), so
**any new agent that needs AWS must bootstrap in-session first.** AWS is not
ready at session start — you have to run this yourself before any `awsx` call:

```bash
bash tools/batch_test/aws/session_setup.sh   # installs AWS CLI, writes ~/.aws/credentials + the awsx wrapper, verifies identity
```

This is idempotent (safe to re-run), installs the AWS CLI if the fresh
container lacks it, then reads `DOTA2BOT_AWS_KEY_ID` / `DOTA2BOT_AWS_SECRET`
from the session environment and verifies the identity is the restricted
`dota2bot-agent` IAM user. A successful run prints
`AWS ready: arn:aws:iam::...:user/dota2bot-agent`. Do this once at the start of
any session that needs AWS; most work (hero logic, tests, docs) does not need
it, so skip it otherwise.

Do NOT expect the environment's **setup script** to do this for you. The setup
script often runs *before* session secrets are injected, hits a no-op branch,
and skips AWS. Bootstrapping is an in-session step, not a startup hook.

After bootstrapping,
**always call AWS via the `awsx` wrapper**, not `aws` directly — the wrapper
strips the proxy's placeholder `AWS_*` env vars (which otherwise shadow the real
key) and points at the proxy CA bundle. Config lives in
`tools/batch_test/aws/aws.env` (bucket, AMI id, security group, etc.).

The `dota2bot-agent` user is permission-scoped to exactly what batch testing
needs (EC2 batch lifecycle, the results S3 bucket, SSM, PassRole for the runner
profile, read-only cost/budget). It cannot perform IAM admin or touch unrelated
resources. An AWS Budget named `dota2bot-batch` is the standing backstop —
**verified 2026-08-21 via `budgets describe-budgets`: the limit is $100/month**,
with ACTUAL alerts at 50/80/100% of that limit (i.e. $50 / $80 / $100 of spend).
Whether the claimed *freeze action* at 100% still exists **cannot be verified
from this account**: `dota2bot-agent` lacks `budgets:DescribeBudgetActionsForBudget`.
Treat the freeze as unconfirmed and rely on the human-facing brake lines below.

**Only the batch-desk stream (or the `batch-runner` subagent) spends AWS money.**
A main/integrator session stays read-only on S3 unless the owner explicitly
asked for a launch.

## AWS Spending Policy

Batch testing runs on the owner's AWS account (see `tools/batch_test/aws/`).
Rules for any agent operating this infrastructure:

- **Every $50 of cumulative AWS spend requires the owner's explicit approval
  before launching further paid work.** Track cumulative spend across sessions;
  when a new $50 tier would be crossed, stop and ask first.
- Check current spend and running resources with `tools/batch_test/aws/check_costs.sh`
  before and after every batch run. Anything still running that shouldn't be —
  terminate it and tell the owner.
- Batch instances must always launch via `aws_run.sh` / `spot_run.sh`
  (self-terminating Spot + watchdog). Never launch a long-lived instance without
  an explicit self-destruction path.
- An AWS Budget (`dota2bot-batch`, **$100/month as actually configured**, alerts
  at 50/80/100% = $50/$80/$100 of spend to the owner's email) is the backstop,
  not the primary control — the primary control is asking the owner at each $50
  tier. The first owner-visible alert therefore fires at $50, *above* the batch
  desk's own $45 launch fence and *below* its $90 brake line.
- The MTD number comes from `budgets describe-budgets` (free), not from Cost
  Explorer — `ce get-cost-and-usage` is billed **$0.01 per request**, and at two
  calls per agent trigger that overhead measured $0.24/day on the real bill.
  `check_costs.sh` pays for a CE read only to confirm a near-brake reading or
  when a per-day/per-service breakdown is actually needed.

## Skills (on-demand playbooks)

Always-on rules stay in this file. Repeatable procedures live in
`.claude/skills/<name>/SKILL.md` so they load only when relevant. Use them
when the task matches:

| Skill | When |
|---|---|
| `owner-briefing` | Summarize status for the owner, or turn a decision into priorities/issues/queue |
| `gated-fix` | Land a new soak-candidate behavior change |
| `replay-fixture` | Freeze one replay instant into `tests/fixtures/` and assert the decision |
| `polish-hero` | Improve a focus hero's skills, items, or talents |
| `patch-update` | Check for / apply a new Dota 2 patch |
| `add-hero` | Add a hero file and the three required registry edits |

Do **not** copy these playbooks back into this file. If a playbook changes,
edit the skill.

## Important Rules

- **Never rename/move/delete Lua files** under `bots/` or `game/` -- the game loads them by fixed path/name
- **Use `GetItemComponents()` for item recipes** -- don't hardcode component arrays
- **Use `sAbilityList[N]` references** when possible -- resilient to ability renames
- **Always update BOTH neutral item files** (Buff/ AND FretBots/)
- **Verify on Liquipedia** before trusting patch note summaries about ability names
- **Test in-game** after changes -- some things can only be verified at runtime
- **Keep attribution intact** -- MIT LICENSE, credits to OHA and earlier lineages, and in-file credit headers in Lua files stay as they are
- **Commit messages contain no model names**
