# Isolated Scenario Testing — Feasibility & Design

Status: **design + prototype** (2026-07-20). Prototype driver:
`tools/batch_test/scenario/run_scenario.py`; first scenario spec:
`tools/batch_test/scenario/scenarios/ally_attacked_react.json`.
Nothing here has run against a live dedicated server yet — every claim below
is labeled **VERIFIED** (proven on our farm in a previous iteration),
**LIKELY** (same mechanism class as something verified), or **UNTESTED**
(needs the live-probe checklist in section 8).

## 1. Problem

Full ~11-minute Turbo games are a blunt instrument for micro-behaviors.
"When my ally is attacked, do I react within 3 seconds?" is a discrete,
local decision; measuring it through whole-game GPM/win-rate needs hundreds
of games to rise above draft variance (see `iterations/0010`, ±600 GPM/game
draft noise). The owner wants *scenario tests*: set up a small, controlled
situation (e.g. a 2v2 at mid, level 6), force the interaction, and assert
the behavior directly from events.

## 2. Feasibility verdict

**A pure rcon-driven scenario setup — "spawn heroes at a position, set
levels, grant items, teleport, force a fight, all via console commands" —
is NOT feasible on our headless dedicated server.** Every setup cheat in
the game is anchored to a *human player context* that rcon does not have:

- `dota_create_unit <name> [enemy|neutral]` (chat `-createhero`) spawns the
  unit **"where the user's mouse cursor is pointing"**
  ([Liquipedia: Cheats](https://liquipedia.net/dota2/Cheats)). Over rcon
  there is no client, no cursor, and no spawn-position argument.
- The `dota_dev` family (`hero_level`, `hero_maxlevel`, `hero_teleport`,
  `player_givegold`, `hero_refresh`) acts on **the issuing player's hero**
  ([Liquipedia: Cheats](https://liquipedia.net/dota2/Cheats),
  [Dota 2 Wiki: Cheats](https://dota2.fandom.com/wiki/Cheats)). rcon issues
  as "Console", which owns no hero. **VERIFIED consistent with our own
  probing:** `dota_dev forcewin` was proven a no-op on this dedicated build
  (`iterations/0008-ten-min-lab/REPORT.md` — its one apparent success was a
  misconfigured test server's auto-surrender firing coincidentally).
- Chat cheats (`-lvlup`, `-gold`, `-item`, `-createhero`) are parsed from a
  *player's* chat. rcon `say` speaks as Console with no player ID —
  **UNTESTED, expected no-op.**
- **VERIFIED:** this dedicated build exposes **no `script` command and no
  query/scripting surface at all** over rcon; bot `print()` never reaches
  any log; Lua error payloads are masked
  (`iterations/0007-30min-lock/decision.md`).

**However, a practical scenario harness IS feasible** as a hybrid of three
mechanisms we already trust, none of which requires the infeasible spawn
path:

| Channel | Mechanism | Status |
|---|---|---|
| **rcon cvar flips** | referee.py already sets `dota_surrender_on_disconnect` + `dota_auto_surrender_all_disconnected_timeout` live and the engine obeys within seconds | **VERIFIED** |
| **Lua config files** (`bots/Customize/*.lua`, gitignored, farm-only) | bots `dofile()` these at load; `soak_pool.lua`/`soak_side.lua` already steer the whole draft and A/B gating this way | **VERIFIED** |
| **Replay observation** | `+tv_autorecord` `.dem` → `behavioral/dumper` timeline (per-tick positions/HP + full combat log) → pure-function detectors | **VERIFIED** (behavioral pipeline; reference game reproduced the owner's hand-found bugs) |

So instead of *spawning* a 2v2 at mid, we **compose** one: pin the exact
10-hero draft through the Customize channel, let Turbo + `host_timescale`
reach level 6 in ~1–2 wall-minutes, shape the map with server cvars
(creep spawns off, all-vision), optionally steer positioning with a
dev-only Lua scenario hook, and assert behavior from the replay timeline.
The "force a fight" step is the one real gap — section 5.3.

## 3. Command research (what works from rcon, what doesn't)

Legend: anchor = what the command needs to resolve its target.

| Command | Anchor | rcon-viable? | Source |
|---|---|---|---|
| `dota_surrender_on_disconnect`, `dota_auto_surrender_all_disconnected_timeout` | server cvar | **VERIFIED yes** (our game-end mechanism) | `soak/referee.py` |
| `host_timescale N` | server cvar | **VERIFIED yes** (set at launch; live flip LIKELY) | `soak/soak_loop.sh` |
| `dota_creeps_no_spawning 1` | server cvar | **LIKELY** (plain cvar, same class as above) — UNTESTED live | [Dota 2 Wiki: Cheats](https://dota2.fandom.com/wiki/Cheats), [PCGamesN](https://www.pcgamesn.com/dota-2/console-commands-cheats) |
| `dota_all_vision 1` | server cvar | **LIKELY** — UNTESTED live | [Dota 2 Wiki: Cheats](https://dota2.fandom.com/wiki/Cheats) |
| `dota_bot_give_level N` (chat `-levelbots`) | **all bots** (no player needed) | **UNTESTED — most promising setup command.** Levels every bot; cannot target one hero | [Liquipedia: Cheats](https://liquipedia.net/dota2/Cheats) |
| `dota_bot_give_item <item>` (chat `-givebots`) | bots; exact recipient semantics unclear headless | **UNTESTED** | [Liquipedia: Cheats](https://liquipedia.net/dota2/Cheats) |
| `dota_create_unit <name> [enemy]` | issuing client's **mouse cursor** | **No** (no cursor headless) | [Liquipedia: Cheats](https://liquipedia.net/dota2/Cheats) |
| `dota_dev hero_level/hero_teleport/player_givegold/hero_refresh` | **issuing player's hero** | **No** (no player; `dota_dev forcewin` VERIFIED no-op here) | [Liquipedia: Cheats](https://liquipedia.net/dota2/Cheats); `iterations/0008` |
| `dota_dev forcegamestart` (chat `-startgame`) | game rules | Unneeded — `+dota_bot_practice_start 1` at launch already starts the game | [Liquipedia: Cheats](https://liquipedia.net/dota2/Cheats) |
| `say -lvlup 5` etc. (chat cheats via rcon) | chat **player** context | **UNTESTED, expected no** (Console is not a player) | [Dota 2 Wiki: Cheats](https://dota2.fandom.com/wiki/Cheats) |
| `ent_teleport` / `ent_setpos` | ent picker / issuing player's view | **No** | engine `ent_*` semantics |

Note on `sv_cheats`: cheat commands require `sv_cheats 1`
([PCGamesN](https://www.pcgamesn.com/dota-2/console-commands-cheats)); our
farm already launches with `+sv_cheats 1` (`soak_loop.sh`).

## 4. Architecture

```
 scenario spec (JSON)                         farm instance
 scenarios/ally_attacked_react.json           ┌───────────────────────────────┐
        │                                     │ dedicated server (headless)   │
        ▼                                     │  -usercon +rcon  +sv_cheats   │
 run_scenario.py ── gen Customize files ────▶ │  bots/Customize/ (draft pin)  │
        │           (draft pin, seed,         │  +tv_autorecord → .dem        │
        │            optional Lua hook cfg)   └──────┬────────────────────────┘
        ├── rcon: wait for horn (console log)        │
        ├── rcon: setup cvars (creeps off, vision…)  │
        ├── wait observe-window (wall clock ÷ ts)    │
        ├── rcon: surrender flip (VERIFIED end)      │
        ▼                                            ▼
 console log + rcon transcript              replay .dem
        │                                            │
        │                     behavioral/run_replay.sh (behav-dump)
        │                                            ▼
        └────────────▶ run_scenario.py evaluate --timeline timeline.json
                                │
                                ▼
                   per-incident PASS/FAIL + summary (assertions from the spec)
```

Three phases, three trust levels:

1. **Setup** — `run_scenario.py gen-customize` writes the Customize draft
   pin the spec calls for (the **VERIFIED** `Customize.Radiant_Heros` /
   `Dire_Heros` path consumed by `hero_selection.lua:270-297`; a fixed
   draft also removes the ±600 GPM draft-variance problem entirely), then
   the soak launcher (or a thin variant) starts the server. After the
   horn, the driver applies the spec's rcon cvar sequence.
2. **Observe** — the game simply runs for the spec's observation window
   (game-minutes ÷ assumed timescale = wall seconds). Slot-1-style
   `+tv_autorecord` captures the `.dem`.
3. **Assert** — the existing behavioral dumper turns the `.dem` into
   `timeline.json`; `run_scenario.py evaluate` runs the spec's assertion
   blocks against it and emits per-incident findings and a pass rate.

### 4.1 Scenario spec schema (v0)

```jsonc
{
  "name": "ally_attacked_react",
  "description": "...",
  "draft": {                      // optional; pins both teams pos1..pos5
    "radiant": ["axe", "zuus", "lion", "crystal_maiden", "skeleton_king"],
    "dire":    ["luna", "sniper", "tidehunter", "witch_doctor", "lich"]
  },
  "launch": {                     // documented expectations for the launcher
    "timescale": 4, "game_mode": 23, "record_replay": true
  },
  "phases": [                     // rcon command sequence, gated on game state
    { "when": "in_progress",      // wait for the horn line in the console log
      "commands": ["dota_creeps_no_spawning 1", "dota_all_vision 1"],
      "untested": true,           // marks commands pending the live probe
      "enabled": false }
  ],
  "observe": { "game_minutes": 8, "assumed_timescale": 3.6 },
  "end": { "method": "surrender_flip" },   // the only VERIFIED end mechanism
  "assertions": [ /* see 4.2 */ ]
}
```

### 4.2 Assertion language (v0)

Assertions are pure functions over the behavioral timeline
(`{snapshots, events}`, see `tools/batch_test/behavioral/README.md`), in
the exact style of `detect.py`'s detectors. v0 implements one parametric
assertion type, enough for the first scenario:

- **`ally_react`** — for every *incident* (an allied hero taking hero
  damage from an enemy hero), each living ally within `notice_radius`
  must, within `react_window_s` seconds, either
  (a) act against the attacker's team (ABILITY cast or hero DAMAGE dealt), or
  (b) move `retreat_min_units` or more from its position at incident time.
  Emits per-(incident, ally) PASS/FAIL and an aggregate react rate;
  `min_react_rate` decides the scenario's exit code.

New assertion types get added the way detectors do: one small pure
function, registered in `ASSERTION_TYPES` in `run_scenario.py`.

## 5. What we can and cannot control (honest limits)

### 5.1 Controllable today (no code changes)
- **Exact 10-hero draft** — VERIFIED Customize channel.
- **Game mode / timescale / difficulty** — VERIFIED launch cvars.
- **Game end at a chosen time** — VERIFIED surrender flip.
- **Item builds** — hero files own `sRoleItemsBuyList`; a farm-only
  Customize override can pin a build (gold still accrues naturally).
- **Full observation** — VERIFIED replay pipeline (positions, HP, casts,
  damage, modifiers, deaths, with game-clock timestamps).

### 5.2 Likely controllable (cvar class, needs live probe)
- Creep spawns off (`dota_creeps_no_spawning 1`) — turns mid into an
  empty arena once the initial waves die out.
- All-vision (`dota_all_vision 1`) — removes fog as a confound so bots
  always *see* the incident (isolates decision logic from vision logic;
  run scenarios both ways).
- Mass bot leveling (`dota_bot_give_level N`) — jump straight to the
  level-6 scenario without waiting; all 10 heroes level together, which
  is acceptable for symmetric scenarios.

### 5.3 Not controllable via console — Lua hook territory
- **Spawn/teleport heroes to a position**: impossible headless (cursor/
  player anchored). Workaround: a dev-only **scenario hook** in the bot
  scripts, following the exact `soak_side.lua` precedent
  (`FunLib/jmz_func.lua:4565` — a gitignored `Customize/scenario.lua`
  file is `dofile`d under `pcall`; absent file = inert, so nothing ships
  active to the Workshop). The hook's contract:
  - *Setup phase* (game-time window from the spec): listed heroes
    override their mode desire to walk to a waypoint and hold near it.
    The Bot API fully supports this (movement orders are what bots do).
  - *Release* (at trigger time): the hook goes inert and **normal logic
    resumes** — this is the moment under test. The hook must never
    script the behavior being asserted, only the approach.
  - Not implemented yet (phase 3; this design deliberately ships no Lua).
- **Per-hero levels/gold/items granted instantly**: no console path; the
  practical substitute is natural Turbo accrual plus `dota_bot_give_level`
  (all-bots) once probed.
- **Forcing the fight itself**: bots decide to fight from their own
  desire functions — which is precisely what we want to *measure*, not
  force. Scenario design therefore engineers *proximity and stakes*
  (e.g. two heroes steered to push into two defenders), then measures the
  reaction.

### 5.4 Observation limits (inherited, VERIFIED)
- Bot `print()` is invisible and Lua errors are masked on the dedicated
  server — the replay is the *only* behavior channel; assertions must be
  expressible in positions + combat-log events.
- Wall-clock/game-clock mapping is estimated (referee-style anchor on the
  horn + Building lines); phase timing is accurate to ± one poll interval.
- The `.dem` needs the manta build-tag patch (`behavioral/setup_instance.sh`).

### 5.5 v1 insight: organic incidents already give scenario power
For reaction-class behaviors, a **pinned-draft ordinary game is already a
scenario**: an 8-game-minute Turbo 5v5 contains dozens of "ally attacked"
incidents, and the assertion evaluator scores *all* of them. That works
today with zero untested commands (draft pin + surrender end + replay are
all VERIFIED), making it the right v1. Arena-style setups (creeps off,
forced level, positioning hook) then narrow the distribution in v2/v3.

## 6. Prototype: `tools/batch_test/scenario/run_scenario.py`

Modes (see `--help`):

- `run` — connect to rcon (retry loop with timeouts), tail the console
  log for the horn, apply each enabled phase's commands (each command's
  rcon response is captured), wait the observation window, apply the end
  method (surrender flip), and write an artifacts dir: rcon transcript
  (JSONL) and `scenario_result.json` with phase timings. Defensive: every
  rcon interaction has a timeout, a bounded retry count, and a clear
  error string; a dead server or refused auth aborts with exit 2, never
  hangs.
- `gen-customize` — emit the Customize draft-pin Lua file from the spec,
  with instructions for placing it on the farm instance.
- `evaluate` — run the spec's assertions against a behavioral
  `timeline.json`; exit 0 iff all assertions meet their thresholds. This
  mode is fully testable offline and covered by a synthetic-timeline
  self-test (`self-test` mode; run in CI-less environments by hand).

Untested-against-live-server parts are marked in-code with `UNTESTED:`
comments and mirrored in section 8.

## 7. First scenario: `ally_attacked_react`

`scenarios/ally_attacked_react.json` encodes the owner's example: *when my
ally is attacked, do I react?* v1 configuration (all-VERIFIED mechanisms):
pinned focus-hero draft, ordinary Turbo game, 8 game-minute window,
surrender end, then `ally_react` assertion over every organic incident —
allies within 1200u must fight back or reposition ≥300u within 3s;
scenario passes at ≥60% react rate (threshold intentionally loose until we
have a baseline; ratchet after the first runs). The spec also carries a
v2 arena phase (creeps off + all-vision) marked `"untested": true` and
`"enabled": false`.

## 8. Live-probe checklist (first spot-instance session)

Run once over rcon on a scratch game, record results back into this doc:

1. `dota_creeps_no_spawning 1` — do lane creeps stop spawning? (console
   log wave lines / replay creep entities)
2. `dota_all_vision 1` — do bots act on full vision? (indirect: reaction
   distances in the replay)
3. `dota_bot_give_level 5` — do all bots jump levels? (replay levels)
4. `dota_bot_give_item item_tango` — does anything happen headless?
5. `say -lvlup 5` — expected no-op; confirm.
6. Live `host_timescale` flip mid-game — does the achieved timescale
   change? (referee's Building-line slope)
7. Then flip each result to VERIFIED/DEAD in the section-3 table.

## 9. Roadmap

1. **v1 (runnable now; probe optional)**: pinned-draft organic-incident
   scenarios; `ally_attacked_react` baseline; wire `evaluate` output into
   the ledger like `analysis_*.json`.
2. **v2**: arena shaping — creeps off, all-vision, `dota_bot_give_level`;
   add 2-3 more assertion types (tp_discipline, dive_punish — port from
   `detect.py`).
3. **v3**: Lua scenario hook (`Customize/scenario.lua`, soak_side
   pattern) for positioning/hold-then-release setups; A/B two code
   versions on identical scenario seeds, comparing react rates instead of
   GPM.

## Sources

- [Liquipedia — Dota 2 Cheats](https://liquipedia.net/dota2/Cheats) —
  chat/console equivalences, cursor-anchored spawning, `dota_dev` player
  anchoring, `dota_bot_give_level`/`dota_bot_give_item`.
- [Dota 2 Wiki (Fandom) — Cheats](https://dota2.fandom.com/wiki/Cheats) —
  cheat scope (bot matches/lobbies only), chat-cheat player context.
- [PCGamesN — Dota 2 console commands and cheats](https://www.pcgamesn.com/dota-2/console-commands-cheats)
  — `sv_cheats` requirement, `dota_creeps_no_spawning`, `dota_all_vision`.
- In-repo verified ground truth: `iterations/0007-30min-lock/decision.md`
  (no scripting surface, masked errors, print invisibility),
  `iterations/0008-ten-min-lab/REPORT.md` (`dota_dev forcewin` no-op,
  surrender-flip end mechanism), `tools/batch_test/behavioral/README.md`
  (replay pipeline).
