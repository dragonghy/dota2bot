# Dota 2 Bot Scripts — Focused Hero Pool

Custom Lua bot scripts for Dota 2, built on a snapshot of [OpenHyperAI (OHA)](https://github.com/forest0xia/dota2bot-OpenHyperAI) and developed independently from that point on.

**Mission:** instead of being "okay at 127 heroes", make a small pool of 10-15 heroes play *clearly* better than the default bots — measurably, via batch A/B win-rate testing — and ship the result to the Steam Workshop as a one-click-subscribe bot script. (The project has no final name yet; Workshop naming is an open TODO.)

---

## What This Project Is

- **A polished, focused bot script.** The full OHA hero coverage (127 heroes, Patch 7.41/7.41a) is inherited and kept working, but deep polish effort goes into a small set of focus heroes.
- **First-batch focus heroes:** Axe, Zeus, Wraith King (`skeleton_king`), Lion, Crystal Maiden.
- **Candidate pool for later expansion:** Luna, Sniper, Death Prophet, Tidehunter, Dragon Knight, Witch Doctor, Lich, Warlock.
- **Data-driven iteration.** Every hero-logic change must pass static analysis, unit tests, and batch A/B win-rate validation before it merges. Gut feeling doesn't ship; win rates do.
- **Independent since the fork.** This project started from an OHA snapshot at patch 7.41/7.41a and evolves on its own; merging from upstream is not planned. Future Dota patches are handled by our own runbook ([docs/PATCH_UPDATE_GUIDE.md](docs/PATCH_UPDATE_GUIDE.md)).

The canonical statement of goals, hero pool rationale, testing methodology, and roadmap lives in **[docs/PROJECT.md](docs/PROJECT.md)**.

---

## Relationship to OpenHyperAI

This repo began as a fork of [forest0xia/dota2bot-OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI), the most feature-rich community bot script for Dota 2. All of the shared machinery — laning, farming, pushing, item purchasing, FretBots difficulty mode, game-mode support — is OHA's work and that of the bot-script lineages before it (see [Credits](#credits)). We are grateful for it; without that foundation a project like this would take years, not weeks.

The fork point is a permanent departure: we do not track or merge upstream. What we add on top is focus-hero polish plus a development/verification infrastructure (linting, unit tests, CI, headless batch A/B testing) that the upstream project does not have.

---

## Repository Map

```
bots/            The deliverable: pure Lua bot scripts (this is all that ships to the Workshop)
  BotLib/          Per-hero logic (hero_<internal_name>.lua — names dictated by the Dota bot API)
  FunLib/          Core shared libraries (items, skills, roles, positioning, chat)
  FretBots/        Enhanced-difficulty mode (dynamic bonuses, neutral items, chatbot)
  Customize/       User-editable settings (picks, bans, names, difficulty)
game/            Valve default setup + permanent-customization location
docs/            Documentation (project statement, architecture, patch runbook, Bot API reference)

-- Dev-only, never ships to the Workshop: --
tests/           Unit + smoke tests under a mock Bot API (lua5.1)
tools/batch_test/  Headless batch match runner, same-match A/B dispatch, AWS on-demand runbook
typescript/      TS sources for the TS-generated Lua files (inherited OHA toolchain)
.github/         CI (luacheck + unit tests on every push)
```

Note: the layout and file naming under `bots/` are dictated by the Dota 2 bot scripting API (the game loads `bots/hero_selection.lua`, `bots/BotLib/hero_<name>.lua`, etc. by path). Do not rename or move Lua files there.

---

## Verification Workflow

Run before every push (CI enforces the first two):

```bash
luacheck bots game --formatter plain   # static analysis; must be 0 warnings
lua5.1 tests/run_tests.lua             # unit tests under mock Bot API
```

Hero-logic changes additionally require batch A/B validation with `tools/batch_test/` (win rate / GPM / XPM deltas over dozens of headless matches; see [tools/batch_test/README.md](tools/batch_test/README.md) and [docs/PROJECT.md](docs/PROJECT.md) for the full test-tier methodology).

The Dota bot VM is **Lua 5.1**: no `goto`, no `table.unpack` (use `unpack`).

---

## Playing Against the Bots Locally

The script is not on the Workshop yet. To run it from a local checkout:

1. Link or copy `bots/` into your Dota 2 scripts folder:
   `<Steam>/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots`
   (The helper scripts in [bots/Install-to-vscript/](bots/Install-to-vscript/) automate the symlink; they are inherited from OHA and reference the upstream Workshop ID, but the symlink mechanics apply to any checkout.)
2. Create a **Custom Lobby** and select **Local Host** as the server location.
3. Start the game — bots auto-pick and play. Correctly loaded bots have names ending in ".OHA" (inherited naming; will change when we brand the project).

### In-Game Commands (inherited from OHA)

| Command | Description |
|---|---|
| `!pos X` | Swap your role with a bot (e.g., `!pos 2` for mid) |
| `!Xpos Y` | Reassign bot positions (e.g., `!3pos 5` = 3rd bot plays pos 5) |
| `!pick HERO` | Pick a hero (`!pick sniper`, or `/all !pick sniper` for enemy) |
| `!ban HERO` | Ban a hero from being picked |
| `!sp XX` | Set bot language (`en`, `zh`, `ru`, `ja`) |

Lobby slot order = position assignment: pos 1 + 5 safe lane, pos 2 mid, pos 3 + 4 offlane.

### Customization

| What | Where |
|---|---|
| General settings (picks, bans, names, roles) | [bots/Customize/general.lua](bots/Customize/general.lua) |
| Per-hero settings (items, skills) | [bots/Customize/hero/viper.lua](bots/Customize/hero/viper.lua) |
| FretBots difficulty tuning | [bots/FretBots/SettingsDefault.lua](bots/FretBots/SettingsDefault.lua) |

Permanent customization (survives updates): copy the `Customize` folder to `<Steam>/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/game/Customize`.

---

## Documentation

| Document | Description |
|---|---|
| [docs/PROJECT.md](docs/PROJECT.md) | Canonical project statement: goals, hero pool, testing methodology, roadmap |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | The inherited OHA codebase architecture we build on — file map, naming conventions, all systems |
| [docs/PATCH_UPDATE_GUIDE.md](docs/PATCH_UPDATE_GUIDE.md) | Our runbook for adapting the scripts to new Dota 2 patches |
| [docs/BOT_API_REFERENCE.md](docs/BOT_API_REFERENCE.md) | Comprehensive Valve bot scripting API reference with examples |
| [CLAUDE.md](CLAUDE.md) | AI coding assistant guide — project focus, common tasks, rules, workflows |

### Internal Name References

Dota 2 bot scripts use internal code names for heroes, items, and abilities — different from in-game display names. Always verify against authoritative sources:

| Resource | What It Contains |
|---|---|
| [Liquipedia Cheats Page](https://liquipedia.net/dota2/Cheats) | Authoritative `item_*` internal names, including neutral items |
| [d2vpkr npc_abilities.txt](https://raw.githubusercontent.com/dotabuff/d2vpk/master/dota_pak01/scripts/npc/npc_abilities.txt) | All ability internal names and KV data |
| [Dota 2 Patch Data API](https://www.dota2.com/datafeed/patchnoteslist?language=english) | Official patch notes, machine-readable |
| [Modifier Names (Valve Wiki)](https://developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools/Scripting/Built-In_Modifier_Names) | `modifier_*` names for buff/debuff detection |

### Useful External Resources

| Resource | Description |
|---|---|
| [Valve Bot Scripting Intro](https://developer.valvesoftware.com/wiki/Dota_Bot_Scripting) | Official Valve documentation |
| [Lua Bot APIs (moddota)](https://docs.moddota.com/lua_bots/) | Community API docs |
| [Dota2 AI Development Tutorial](https://www.adamqqq.com/ai/dota2-ai-devlopment-tutorial.html) | Comprehensive guide by adamqqq |
| [Enums & APIs (moddota)](https://moddota.com/api/#!/vscripts/dotaunitorder_t) | Enum reference |

---

## Credits

This project stands on the shoulders of the community bot-script lineage. The foundation is:

- **[Open Hyper AI (OHA)](https://github.com/forest0xia/dota2bot-OpenHyperAI)** by forest0xia and contributors — the codebase this project forked from ([upstream Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3246316298))

OHA itself builds on Valve's default bots plus contributions from many talented authors:

- New Beginner AI ([dota2jmz@163.com](mailto:dota2jmz@163.com))
- Tinkering About ([ryndrb](https://github.com/ryndrb/dota2bot))
- Ranked Matchmaking AI ([adamqqq](https://github.com/adamqqqplay/dota2ai))
- fretbots ([fretmute](https://github.com/fretmute/fretbots))
- BOT Experiment (Furiospuppy)
- ExtremePush ([insraq](https://github.com/insraq/dota2bots))
- And all other contributors who made bot games better

Licensed under the [MIT License](LICENSE), same as upstream.
