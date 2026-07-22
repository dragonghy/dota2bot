# Dota 2 Bot Scripts - Claude Code Guide

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

**Read the relevant docs FIRST before making changes.** They contain everything needed to make targeted updates without scanning the entire repo.

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

## Subagent profiles (owner-directed division of labor, 2026-07-22)

Three specialist profiles live in `.claude/agents/`. **The main session DOES
NOT do these jobs itself anymore — delegate via the Agent tool** (the owner
explicitly directed this):

| Profile | Job | Hand it |
|---|---|---|
| `batch-runner` | AWS 批测全流程:launch(镜像A/B, on-demand, bundle 支持)、监控、收 verdict、抢占恢复(recover_verdict.py)、成本/泄漏检查 | "跑一轮批测 / 收批测结果 / 查实例花费" |
| `replay-analyst` | 录像诊断:逐帧还原(硬规则:先逐帧后聚合)+ 检测器/经济差分 + fixture 钉帧 | "看录像找问题 / 诊断批测行为差异" |
| `replay-artifact` | ReplayScope 网页制作 + Artifact 发布 + 时刻导览 | "把录像做成页面给 owner 看" |

Main session keeps: writing/fixing bot Lua + tests, promote/reject decisions,
owner communication, and synthesizing the specialists' reports. Each profile
embeds the operational hard-knowledge (awsx wrapper, $-tier policy, 4-seed
promote bar, depth sign convention, dumper build recipe, artifact publishing
rules) — keep the profiles updated when that knowledge changes.

## Agent session continuity (heartbeat)

- In-memory schedules (CronCreate etc.) **do not survive session suspend** —
  they silently vanish. Never promise or rely on cron-based self-wakeups.
- **Preferred: server-side wakeup** via the claude-code-remote MCP
  `send_later` tool (a Routine stored server-side) — it survives container
  restarts/suspends. It needs a one-time permission approval from the owner;
  once granted, use it as the primary wakeup and re-arm on every wake.
- Fallback: a **background sleep** via the Bash tool (`sleep <seconds>` with
  `run_in_background: true`): its exit re-invokes the agent. CAVEAT (observed
  2026-07-22): background tasks **die silently on container restart** — that
  is why send_later is preferred. If using sleep, re-arm on every wake and
  keep the interval ~1h.
- Always leave the tree committed + pushed and `iterations/state.json` current,
  so ANY wake (heartbeat or owner message) can resume from the repo alone.

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
until it's ungated. Currently gated & unpromoted: the `lanefix` bundle (chase /
mana / salve / rescue-TP / revive-flee / lane-recover / support), `depthnum`,
`nodive2`, `nopush`, `suplh`, `wlok`.

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
- **In-memory wakeup chains die on session suspend** — see "Agent session
  continuity" above; use a background `sleep` heartbeat and re-arm each wake.

## Verification (run before every push)

```bash
luacheck bots game --formatter plain   # static analysis; must be 0 warnings
lua5.1 tests/run_tests.lua             # unit tests under mock Bot API (tests/)
```

- `.luacheckrc` whitelists all legit Bot API / engine globals. A new "accessing
  undefined variable" warning means a typo or a leaked local — fix the code;
  only extend `read_globals` for a genuinely new engine API.
- The Dota bot VM is Lua 5.1: **no `goto`**, no `table.unpack` (use `unpack`).
  luacheck won't catch 5.2+ syntax, but the smoke test (`tests/test_smoke_load.lua`)
  will — it loads every hero file under `lua5.1`.
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
script runs *before Claude Code launches*, and in that phase the
`DOTA2BOT_AWS_*` variables are NOT injected — they are only present in the
Claude Code session environment (i.e. the environment your Bash tool calls
inherit). So `session_setup.sh` wired as a setup script just hits its own
no-op branch and skips AWS; it only works when *you* run it in-session. That is
why bootstrapping is an in-session step, not a startup hook.

After bootstrapping,
**always call AWS via the `awsx` wrapper**, not `aws` directly — the wrapper
strips the proxy's placeholder `AWS_*` env vars (which otherwise shadow the real
key) and points at the proxy CA bundle. Config lives in
`tools/batch_test/aws/aws.env` (bucket, AMI id, security group, etc.).

The `dota2bot-agent` user is permission-scoped to exactly what batch testing
needs (EC2 batch lifecycle, the results S3 bucket, SSM, PassRole for the runner
profile, read-only cost/budget). It cannot perform IAM admin or touch unrelated
resources. A $50/month AWS Budget with a freeze action at 100% caps its EC2
spend as a hard backstop.

## AWS Spending Policy

Batch testing runs on the owner's AWS account (see `tools/batch_test/aws/`).
Rules for any agent operating this infrastructure:

- **Every $50 of cumulative AWS spend requires the owner's explicit approval
  before launching further paid work.** Track cumulative spend across sessions;
  when a new $50 tier would be crossed, stop and ask first.
- Check current spend and running resources with `tools/batch_test/aws/check_costs.sh`
  before and after every batch run. Anything still running that shouldn't be —
  terminate it and tell the owner.
- Batch instances must always launch via `aws_run.sh` (self-terminating Spot +
  12h watchdog). Never launch a long-lived instance without an explicit
  self-destruction path.
- An AWS Budget (`dota2bot-batch`, $50/month, alerts at 50/80/100% to the
  owner's email) is the backstop, not the primary control — the primary control
  is asking the owner at each $50 tier.

## Common Tasks

### Polish a Focus Hero (primary workflow)

1. Read `bots/BotLib/hero_[name].lua` (and `docs/ARCHITECTURE.md` sections 3-5 if unfamiliar)
2. Improve ability logic (`SkillsComplement()` / `ConsiderX()` functions), item builds (`sRoleItemsBuyList`), or talents (`tTalentTreeList`)
3. Run verification (above), then a batch A/B run comparing old vs new (`tools/batch_test/README.md`)
4. Only merge on a measured improvement

### Check for New Patches

To check if there are patches we haven't updated for:
1. Fetch `https://www.dota2.com/datafeed/patchnoteslist?language=english`
2. Compare latest version against "Last updated for" in `docs/PATCH_UPDATE_GUIDE.md`
3. If newer patch exists, follow the update process below

### Patch Update

When user says "update for patch X.XX" or provides patch notes:

1. Read `docs/PATCH_UPDATE_GUIDE.md` for the step-by-step process
2. Fetch patch data: `https://www.dota2.com/datafeed/patchnotes?version=X.XX&language=english`
3. Fetch d2vpkr data (shops.txt, neutral_items.txt) for authoritative item/ability names
4. **Categorize changes**: STRUCTURAL (need code) vs NUMBER-ONLY (game API handles) vs TALENT SWAPS
5. **Always verify ability names on Liquipedia** -- patch note summaries can be wrong
6. Follow the checklist in order: items -> hero builds -> abilities -> neutrals -> actives -> map changes
7. **Always update TS sources** for any TS-generated Lua files changed (see ARCHITECTURE.md Section 13)
8. Focus heroes get priority: verify their builds/abilities first and re-run A/B validation after a major patch

### Add a New Hero

1. Copy a similar existing hero from `bots/BotLib/` as template
2. Add to `FretBots/HeroNames.lua`, `FunLib/aba_hero_roles_map.lua`, `FunLib/spell_list.lua`
3. See "New Heroes" section in `docs/PATCH_UPDATE_GUIDE.md`

### Fix a Hero's Item Build

1. Read `bots/BotLib/hero_[name].lua`
2. Edit the `sRoleItemsBuyList['pos_N']` arrays
3. Items use `item_[internal_name]` format -- check `FunLib/aba_item.lua` for valid names

### Fix a Hero's Ability Logic

1. Read `bots/BotLib/hero_[name].lua`
2. The `SkillsComplement()` function controls ability casting priority
3. Each ability has a `ConsiderX()` function returning desire + target
4. See "Skill / Ability System" in `docs/ARCHITECTURE.md`

## Important Rules

- **Never rename/move/delete Lua files** under `bots/` or `game/` -- the game loads them by fixed path/name
- **Use `GetItemComponents()` for item recipes** -- don't hardcode component arrays
- **Use `sAbilityList[N]` references** when possible -- resilient to ability renames
- **Always update BOTH neutral item files** (Buff/ AND FretBots/)
- **Verify on Liquipedia** before trusting patch note summaries about ability names
- **Test in-game** after changes -- some things can only be verified at runtime
- **Keep attribution intact** -- MIT LICENSE, credits to OHA and earlier lineages, and in-file credit headers in Lua files stay as they are
