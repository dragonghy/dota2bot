---
name: add-hero
description: Add a new Dota 2 hero bot file and the three required registry entries. Use when the user asks to support a new hero or copy a BotLib template.
---

# Add a new hero

1. Copy a similar existing hero from `bots/BotLib/` as the template. The
   filename **must** be `hero_<internal_name>.lua` (Valve load path).
2. Register the hero in all three places:
   - `bots/FretBots/HeroNames.lua`
   - `bots/FunLib/aba_hero_roles_map.lua`
   - `bots/FunLib/spell_list.lua`
3. Follow the "New Heroes" section in `docs/PATCH_UPDATE_GUIDE.md` and the
   hero-file skeleton in `docs/ARCHITECTURE.md` §3 (talents, ability build
   indices, `sRoleItemsBuyList` pos_1–5, `SkillsComplement`, `ConsiderX`).
4. Do not rename, move, or delete other Lua files under `bots/` or `game/`.
5. Smoke: `lua5.1 tests/run_tests.lua` includes `tests/test_smoke_load.lua`,
   which must load the new file under Lua 5.1.
6. Deep polish is **not** implied. Focus-pool membership is an owner
   decision. Default: keep the inherited OHA-quality file loading cleanly.

Item names are `item_<internal>`. Ability slots should use `sAbilityList[N]`
when possible. If you change behavior relative to the template, gate it
(`gated-fix` skill) rather than shipping it live.
