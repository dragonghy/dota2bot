# Dota 2 Bot Scripts - Claude Code Guide

## What This Project Is

This repo is an **independent Dota 2 bot script project** focused on a small hero pool. It started from a snapshot of the community project [OpenHyperAI (OHA)](https://github.com/forest0xia/dota2bot-OpenHyperAI) at Patch 7.41/7.41a (127 heroes supported) and evolves on its own — upstream merges are not planned. The goal: make 10-15 focus heroes play clearly better than default bots, verified by batch A/B win-rate testing, and eventually publish to the Steam Workshop. The project has no final name yet.

**Current focus heroes (deep polish targets):** Axe, Zeus, Wraith King (`skeleton_king`), Lion, Crystal Maiden.
**Candidate pool for later:** Luna, Sniper, Death Prophet, Tidehunter, Dragon Knight, Witch Doctor, Lich, Warlock.

**The iteration loop for hero polish is data-driven:** change hero logic → `luacheck` clean → unit tests pass → batch A/B run (`tools/batch_test/`) shows a win-rate/GPM/XPM improvement → merge. No hero-logic change ships on intuition alone.

**What ships vs what doesn't:** only `bots/` (pure Lua) is the Workshop deliverable. `tests/`, `tools/`, `typescript/`, `.github/` are dev-only.

**Layout is load-bearing:** the Dota bot API loads scripts by fixed path and name (`bots/hero_selection.lua`, `bots/BotLib/hero_<internal_name>.lua`, mode scripts, etc.). Never rename, move, or delete Lua files under `bots/` or `game/`.

See **[docs/PROJECT.md](docs/PROJECT.md)** for the full project statement, testing tiers, and roadmap.

## Key Documentation

- **[docs/PROJECT.md](docs/PROJECT.md)** -- Canonical goals, hero pool rationale, testing methodology (T0-T3), roadmap
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** -- The inherited OHA codebase architecture: file map, naming conventions, all systems explained
- **[docs/PATCH_UPDATE_GUIDE.md](docs/PATCH_UPDATE_GUIDE.md)** -- Our runbook for adapting to new Dota 2 patches
- **[docs/BOT_API_REFERENCE.md](docs/BOT_API_REFERENCE.md)** -- Valve bot scripting API reference

**Read the relevant docs FIRST before making changes.** They contain everything needed to make targeted updates without scanning the entire repo.

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
any new agent that needs AWS must bootstrap first:

```bash
tools/batch_test/aws/bootstrap_creds.sh   # writes ~/.aws/credentials + the awsx wrapper
```

This reads `DOTA2BOT_AWS_KEY_ID` / `DOTA2BOT_AWS_SECRET` from the cloud
environment (the owner sets these once in the environment config) and verifies
the identity is the restricted `dota2bot-agent` IAM user.

If you want AWS ready automatically at session start, point the environment's
setup script at the absolute path
`bash /home/user/dota2bot/tools/batch_test/aws/session_setup.sh` — it is
cwd-independent, no-ops when the creds env vars are absent, and always exits 0
so it can never block a session. Do NOT put a bare relative path like
`./tools/batch_test/aws/bootstrap_creds.sh` in the setup script: the setup
hook's working directory isn't guaranteed to be the repo root, and a non-zero
exit (e.g. creds not set) will fail session startup. After bootstrapping,
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
