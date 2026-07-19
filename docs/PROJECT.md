# Project Statement

This document is the canonical description of what this project is, what it is trying to achieve, and how progress is measured. If any other doc appears to disagree with this one, this one wins.

---

## 1. Goal

Build a polished Dota 2 bot script that is **clearly stronger than the default bots for a small, curated hero pool (10-15 heroes)**, and publish it to the Steam Workshop for one-click subscribe.

**The target game mode is Turbo** (`dota_force_gamemode 23`) — the mode the owner actually plays. All batch A/B validation runs in Turbo, and tuning decisions favor Turbo's pace: faster gold/XP (item timings arrive much earlier), weaker towers, ~20-minute games, and a stronger payoff for grouped pushing. Normal mode keeps working (it shares the same logic), but when a tuning trade-off differs between modes, Turbo wins.

Breadth is explicitly not the goal. The inherited codebase supports 127 heroes and we keep that coverage working, but polish effort concentrates on the focus pool where we can make bots that lane, fight, and close out games noticeably better — and prove it with data.

The project does not have a final name yet; Workshop title/branding is an open TODO.

## 2. Origin and Independence

The codebase started as a fork of [OpenHyperAI (OHA)](https://github.com/forest0xia/dota2bot-OpenHyperAI) at Patch 7.41/7.41a. OHA provides the entire foundation: laning, farming, pushing, item purchasing, role assignment, FretBots difficulty mode, game-mode support, and 127 hero files.

**The fork point is a permanent departure.** This project evolves independently; merging from upstream is not planned. Future Dota patches are handled by our own process (see [PATCH_UPDATE_GUIDE.md](PATCH_UPDATE_GUIDE.md)). Attribution to OHA and the earlier bot-script lineages is kept prominently (see the README credits and the MIT [LICENSE](../LICENSE)); in-file credit headers in Lua sources stay untouched.

## 3. Hero Pool

### First batch (deep polish targets)

| Hero | Internal name | Why |
|---|---|---|
| Axe | `axe` | Simple, decisive initiator kit; call/blink timing and Culling Blade thresholds are highly scriptable |
| Zeus | `zuus` | Spell-driven mid; strength comes from precise nuke timing and mana management, not micro |
| Wraith King | `skeleton_king` | Forgiving carry with a deterministic kit; good baseline pos-1 to measure farm/fight logic |
| Lion | `lion` | Chain-disable support; value comes from target selection and disable sequencing |
| Crystal Maiden | `crystal_maiden` | Classic pos-5; positioning, aura value, and channel timing are where scripts beat defaults |

The common thread: kits whose in-game strength depends on discrete, well-timed decisions (targeting, thresholds, sequencing) rather than fine micro or reaction-speed tricks — exactly what a script can do reliably better than the default bots. The batch also spans positions 1-5 so a full focus-pool team is testable.

### Candidate pool (later expansion)

Luna, Sniper, Death Prophet, Tidehunter, Dragon Knight, Witch Doctor, Lich, Warlock.

## 4. Testing Methodology

Every hero-logic change must climb this ladder before merging:

| Tier | What | Where | Gate |
|---|---|---|---|
| **T0 — CI** | `luacheck bots game` (0 warnings) + `lua5.1 tests/run_tests.lua` (unit + data-consistency + smoke-load under a mock Bot API) | `.github/workflows/ci.yml`, runs on every push | Hard gate: must pass |
| **T1 — Smoke** | Scripts load and play a real (or headless) match without errors; hot-reload via `dota_bot_reload_scripts` for quick iteration | Local machine with Dota 2 | Must complete a match |
| **T2 — Batch A/B** | Headless batch runs comparing old vs new build. Preferred form: **same-match team dispatch** — `tools/batch_test/make_ab_build.py` builds a combined script where Radiant runs build A and Dire runs build B in the *same match*, eliminating cross-run matchup noise. Metrics: win rate, GPM, XPM, KDA, match length | `tools/batch_test/` (local Linux box or AWS) | Measured improvement (or at minimum no regression) for the touched heroes |
| **T3 — Human play** | Play against the bots in a custom lobby; sanity-check that "stronger" also means "plays sensibly" | Local | Qualitative sign-off |

T0 is enforced by CI. T2 is the merge criterion for hero polish; T1/T3 are judgment checkpoints.

### AWS on-demand batch infra (summary)

There is no always-on test server. `tools/batch_test/aws/` keeps only a baked AMI (Dota 2 + SteamCMD preinstalled, ~$2-3/month snapshot storage) and an S3 bucket for results. A single command launches a Spot instance (c6i.4xlarge class), runs the batch, uploads results to S3, and self-destroys — with a cloud-init watchdog as a second kill switch. A 100-game batch costs on the order of $1.50. See [../tools/batch_test/aws/README.md](../tools/batch_test/aws/README.md) for the runbook.

## 5. What Ships vs What Is Dev-Only

| Path | Ships to Workshop? | Notes |
|---|---|---|
| `bots/` | **Yes** — the entire deliverable, pure Lua | Layout and `hero_<name>.lua` naming are dictated by the Dota bot API; never rename/move/delete Lua files here |
| `game/` | Installed locally by users for permanent customization | Same no-rename rule |
| `tests/`, `tools/`, `typescript/`, `.github/`, docs | **No** — development-side only | |

## 6. Patch Policy

We adapt to new Dota patches ourselves using [PATCH_UPDATE_GUIDE.md](PATCH_UPDATE_GUIDE.md): categorize changes (structural / number-only / talent swaps), apply structural fixes, and re-validate. Focus heroes get first priority after any patch — their builds and ability logic are re-verified and re-run through T2 before anything else.

## 7. Status and Roadmap

**Done:**
- Fork established at 7.41/7.41a; all 127 inherited heroes loading cleanly
- Verification infra: `.luacheckrc`, `tests/` (mock Bot API, smoke + data tests), CI workflow
- Batch test scaffolding: headless runner, log parser, reporting, same-match A/B build tool, AWS on-demand runbook

**Next:**
1. First real batch run to calibrate `tools/batch_test/parse_log.py` log patterns (win/loss and metric lines) — currently pending
2. Establish a baseline: focus-pool win rate vs current build, with stable seeds/settings
3. Hero polish iterations on the first batch (Axe, Zeus, Wraith King, Lion, Crystal Maiden), each gated by T2
4. Expand into the candidate pool once the first batch is convincingly strong
5. Workshop packaging: name/branding decision, description, screenshots, publish flow
