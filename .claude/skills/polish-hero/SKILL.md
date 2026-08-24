---
name: polish-hero
description: Improve a focus-hero bot script (Axe, Zeus/zuus, Wraith King/skeleton_king, Lion, Crystal Maiden) — ability logic, item builds, or talents. Use when editing BotLib/hero_*.lua for those heroes or when the user asks to polish a hero.
---

# Polish a focus hero

Primary workflow for Axe, Zeus (`zuus`), Wraith King (`skeleton_king`), Lion,
Crystal Maiden. Candidate-pool heroes (Luna, Sniper, …) use the same shape
but are not the polish target unless the owner said so.

## Steps

1. Read `bots/BotLib/hero_<internal_name>.lua` and, if the file layout is
   unfamiliar, `docs/ARCHITECTURE.md` sections 3–5.
2. Change **one** lever per commit when it is behavior, not a comment:
   - Ability logic: `SkillsComplement()` priority, then the matching
     `ConsiderX()` (desire + target). See "Skill / Ability System" in
     ARCHITECTURE.md.
   - Items: `sRoleItemsBuyList['pos_N']`. Names are `item_<internal>`.
     Check `FunLib/aba_item.lua`. Use `GetItemComponents()` for recipes;
     do not hardcode component arrays.
   - Talents: `tTalentTreeList` (`0` = left, `10` = right at t10/t15/t20/t25).
     A build-row index is **not** the hero level — levels 10/15/20 are spent
     on talents (`J.Skill.GetSkillList`). Pin claims with
     `tests/skill_level_map.lua`.
3. Prefer `sAbilityList[N]` over hardcoded ability names when the file
   already binds that way.
4. Behavior changes are **gated** — follow the `gated-fix` skill. Pure
   comment / talent-table / buy-list fixes that are meant to be live still
   need a fixture or a structural census (see existing `test_*_payoff.lua`
   files) and must not silently rewrite shared outfits used by other heroes.
5. Verify: `luacheck bots game --formatter plain` then the targeted lua
   tests. Do not launch a per-hero AWS batch; queue it.

## Don't

- Don't force cores to last-hit more (measured regressions `c3` / `corefarm`).
- Don't retune against normal-mode timings; Turbo wins.
- Don't edit `bots/` file names or paths.
