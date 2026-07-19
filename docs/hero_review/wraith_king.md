# Wraith King (`skeleton_king`) — Bot Logic Improvement Backlog

**File reviewed:** `bots/BotLib/hero_skeleton_king.lua` (full)
**Cross-referenced:** `bots/mode_retreat_generic.lua`, `bots/FunLib/override_generic/mode_attack_generic.lua`, `bots/mode_roam_generic.lua`, `bots/FunLib/aba_skill.lua`, `bots/FunLib/spell_list.lua`, sibling carries `hero_sven.lua` / `hero_juggernaut.lua`.

## Overall assessment

The WK hero file is a compact, working Q/W caster with a solid Wraithfire Blast (`skeleton_king_hellfire_blast`) targeting stack (interrupt/kill/teamfight/lane-harass/retreat branches) and mana reservation for Reincarnation. But it under-delivers on WK's two signature strengths: (1) **Reincarnation-aware aggression is only half-built** — a single teamfight-only retreat-suppression exists in `mode_retreat_generic.lua`, with no proactive "dive because R is up" and, more importantly, **no extra caution when R is on cooldown** (the biggest WK decision); and (2) **the skeleton army (Bone Guard / Vampiric Spirit) is never released in multi-hero teamfights** because `ConsiderW` gates the offensive summon on exactly one enemy in view. Item build is a reasonable Armlet→Radiance aggression shell but is **missing BKB entirely** and pushes Aghanim's Scepter absurdly late. Several ability handles/comments are stale (harmless today thanks to a runtime fallback, but fragile).

Note: current W ability confirmed as `skeleton_king_bone_guard` via `spell_list.lua` (lines 741–746). Talent/Aghs/Shard exact effects were NOT verified against Liquipedia in this review and are flagged for verification where load-bearing.

---

## P0 — Reincarnation-aware aggression (asymmetric risk-taking)

### P0-1. No added caution when Reincarnation is on cooldown; proactive aggression not tied to R
- **Location:** Behavior lives outside the hero file. Existing R logic: `mode_retreat_generic.lua` `X.GetDesire` lines **172–179**. Hero file `hero_skeleton_king.lua` has **no** `ConsiderR` and never reads `abilityR:GetCooldownTimeRemaining()` for aggression (only `X.ShouldSaveMana`, lines **468–482**, reads it for mana).
- **Current behavior:** The only R-aware aggression is retreat suppression *in a teamfight only*:
  ```lua
  if bTeamFight and botName == "npc_dota_hero_skeleton_king" and bot:GetLevel() >= 6 then
      local abilityR = bot:GetAbilityByName("skeleton_king_reincarnation")
      if abilityR:GetCooldownTimeRemaining() <= 1.0 and bot:GetMana() >= 160 then
          return BOT_MODE_DESIRE_NONE   -- don't retreat, I have a second life
      end
  end
  ```
- **Problem:** This is only *half* of the signature WK decision, and only in `J.IsInTeamFight` (2+ allies in attack mode within 1200). Two gaps: (a) **when Reincarnation is DOWN, the bot plays with the same boldness as when it is up** — there is no added retreat desire / dive-avoidance, so it will over-commit and die a real death with no comeback (the single worst WK mistake). (b) Solo/gank/split-push duels (`BOT_MODE_ROAM/GANK`, 1v1 lane fights) never get the "I have R, keep fighting" benefit because `bTeamFight` is false. A strong WK is defined by exactly this asymmetry: greedy when R is up, conservative when it is down.
- **Proposed change:** Introduce an R-state signal and use it on both sides.
  - **Caution when R down:** in `mode_retreat_generic.lua`, when `botName == skeleton_king`, `bot:GetLevel() >= 6`, and R is on real cooldown (e.g. `GetCooldownTimeRemaining() > 20` or not castable AND `GetMana() < R:GetManaCost()`), *raise* retreat desire modestly (e.g. `RemapValClamped(botHP, 0.75, 0.4, MODERATE, HIGH)` when enemies ≥ allies) so it disengages earlier.
  - **Aggression when R up:** extend the ready-check beyond `bTeamFight` to also cover `J.IsGoingOnSomeone(bot)` 1v1 situations, and consider a small attack-desire bump in `mode_attack_generic` when R is ready and HP is healthy. Factor an `X.IsReincarnationReady()` helper (castable AND mana ≥ cost AND cd ≤ ~1s) into `hero_skeleton_king.lua` and reuse it in the mode files rather than duplicating the inline check.
  - Also gate `ConsiderQ`'s dive-initiation branch (see P2-2) on R readiness for low-HP dives.
- **Priority:** P0
- **How to validate:** A/B (old vs new) on WK pos-1: expect **deaths-while-R-on-cooldown to drop** and **net kill participation to rise** without a GPM/XPM regression. In-game: bait a 1v1 with R down — new bot should back off; with R up — new bot should commit. Watch that it does NOT suicide into 3+ heroes just because R is up (cap the boldness with an enemy-count/HP guard).

---

## P1

### P1-1. Skeleton army (Bone Guard) is never deployed in real teamfights
- **Location:** `X.ConsiderW`, lines **417–452** (offensive branch **435–441**).
- **Current behavior:**
  ```lua
  if J.IsValidHero( npcTarget )
      and #nEnemysHerosInView == 1          -- only ONE enemy visible
      and J.IsInRange( npcTarget, bot, 650 )
      and ( nStack / maxStack >= 0.6 or talent6:IsTrained() )
  then return BOT_ACTION_DESIRE_HIGH end
  ```
  The only other trigger (lines 444–449) releases skeletons when `nStack == maxStack` *and* near lane front / farming.
- **Problem:** WK's stored skeleton charges are his biggest burst of army DPS and are meant to be unloaded at the **start of a multi-hero fight**. The `#nEnemysHerosInView == 1` condition means that in any fight with 2+ visible enemies — i.e. every teamfight — the offensive summon is skipped, and charges only get spent while farming or pushing a lane. So WK enters teamfights *without* his skeletons. This directly wastes the mechanic the Aghs/skeleton build is built around.
- **Proposed change:** Replace the `== 1` restriction with `>= 1` (or drop it) for the engage branch, and add an explicit teamfight release: if `J.IsInTeamFight(bot, 1200)` and `nStack >= 1` (or `>= maxStack * 0.5`) and an attackable enemy hero is within ~700, return HIGH. Keep the mana/charge guards. Optionally prefer dumping charges when `J.IsGoingOnSomeone(bot)` regardless of enemy count.
- **Priority:** P1
- **How to validate:** A/B: expect higher WK hero-damage and teamfight win rate. In-game: force a 5v5 — new bot should summon its skeletons as the fight opens, not sit on charges.

### P1-2. Black King Bar missing from the carry build; sell-list even lists BKB
- **Location:** `sRoleItemsBuyList['pos_1']` lines **37–59**; `sRoleItemsBuyList['pos_3']` lines **61–82**; `X['sSellList']` lines **92–97**.
- **Current behavior:** pos_1 core sequence is `phase_boots → armlet → radiance → blink → aghanims_shard → assault → ultimate_scepter → overwhelming_blink → …`. **No `item_black_king_bar` anywhere** in pos_1 or pos_3. Meanwhile the sell list is:
  ```lua
  X['sSellList'] = { "item_black_king_bar", "item_quelling_blade" }
  ```
- **Problem:** WK is a melee, blink-in, right-click carry whose whole value proposition is *staying on the target*. Against any lineup with reliable disable/silence he needs BKB to connect and to protect the Reincarnation channel. Omitting it entirely is a clear downgrade versus a strong player (and arguably versus default bots, which do buy BKB situationally). Listing BKB in `sSellList` is also backwards — if BKB ever entered the inventory (e.g. via override/customize), the purchase system could auto-sell it when the bag is full.
- **Proposed change:** Insert `item_black_king_bar` into pos_1 and pos_3 after the first big timing item (e.g. after Armlet/Radiance, around the Blink slot), and remove `item_black_king_bar` from `sSellList`. Consider making BKB conditional/earlier vs heavy-magic lineups if the framework supports situational buys.
- **Priority:** P1
- **How to validate:** A/B vs a disable-heavy enemy draft: expect fewer "died while stunlocked" deaths and higher fight participation. Confirm BKB is actually purchased and toggled in fights (toggle logic lives in `ability_item_usage_generic.lua`).

### P1-3. Aghanim's Scepter is scheduled far too late for a skeleton build
- **Location:** `sRoleItemsBuyList['pos_1']` lines **37–59** (`item_ultimate_scepter` at index **13**, line 51; `item_aghanims_shard` at index **11**, line 49).
- **Current behavior:** Order is `… radiance(9) → blink(10) → shard(11) → assault(12) → ultimate_scepter(13) → overwhelming_blink(14) …`. Scepter comes after Assault and after Overwhelming Blink is queued.
- **Problem:** WK's Scepter upgrades Reincarnation (the `modifier_skeleton_king_reincarnation_scepter_active` referenced across the mode files indicates the scepter turns reincarnation into an offensive skeleton/aura form). For a build whose identity is the skeleton army + a stronger second life, buying Scepter 13th (behind Assault + Overwhelming Blink) means the bot spends most of the game without its defining upgrade. **[Verify exact 7.4x Scepter effect on Liquipedia before finalizing ordering.]**
- **Proposed change:** Move `item_ultimate_scepter` up to roughly the 4th–5th finished-item slot (around/after Blink) and push `item_overwhelming_blink` / second Scepter later. Keep Shard where it is or slightly earlier.
- **Priority:** P1
- **How to validate:** A/B on timing: expect earlier power spike and better mid-game fight win rate. Sanity-check total gold pacing so the reorder doesn't delay the first major DPS item (Radiance/Assault) too much.

---

## P2

### P2-1. Stale/misleading ability handle and header comment (works only via runtime fallback)
- **Location:** Handle at line **152**; fallback at line **168**; header comment block lines **119–149**.
- **Current behavior:**
  ```lua
  local abilityW = bot:GetAbilityByName('skeleton_king_spectral_blade')   -- line 152
  ...
  if not abilityW or abilityW:IsHidden() then abilityW = bot:GetAbilityByName('skeleton_king_bone_guard') end  -- line 168
  ```
  The header comment still lists `Ability2 = skeleton_king_vampiric_aura` and pre-rework modifiers.
- **Problem:** `skeleton_king_spectral_blade` is not a WK ability (Spectral Blade is Phantom Assassin's). Today it resolves to nil and the line-168 fallback fixes W to `skeleton_king_bone_guard`, so behavior is correct — but the initial handle is dead/misleading, the fallback runs every `SkillsComplement` tick, and the stale comment will mislead the next patch update. This is fragile: if a future ability named `skeleton_king_spectral_blade` ever existed as hidden, the guard could misbind.
- **Proposed change:** Replace line 152 with the real handle (prefer the resilient pattern `bot:GetAbilityByName('skeleton_king_bone_guard') or (sAbilityList[2] and bot:GetAbilityByName(sAbilityList[2]))`), drop the now-redundant reassignment on line 168, and refresh the header comment block to the current kit (`skeleton_king_bone_guard`, current modifiers `modifier_skeleton_king_bone_guard`, `modifier_skeleton_king_reincarnation*`).
- **Priority:** P2 (cleanup / patch-resilience; not a live bug)
- **How to validate:** `luacheck` clean + smoke test load; in-game confirm W still casts (unchanged behavior). No metric change expected.

### P2-2. Wraithfire Blast kill/dive checks use an approximate damage constant
- **Location:** `X.ConsiderQ`, `nDamage` line **212**; kill check line **245**; dive branch lines **300–315**.
- **Current behavior:** `nDamage = 40 * (nSkillLV - 1) + 100`; kill secure uses `J.CanKillTarget(npcEnemy, nDamage * 1.68, DAMAGE_TYPE_MAGICAL)` (line 245), i.e. a hard-coded 1.68× fudge to approximate the impact + DoT total.
- **Problem:** The `40*(lv-1)+100` and `1.68` constants are not read from the ability's special values, so if Valve retunes Wraithfire Blast the kill-secure math silently drifts (over- or under-estimating). Overestimation → Q "secures" a kill that doesn't land and the enemy escapes; underestimation → misses free kills. **[Verify current Wraithfire Blast impact + DoT numbers on Liquipedia/d2vpkr.]**
- **Proposed change:** Pull impact/DoT/duration from `abilityQ:GetSpecialValueInt(...)` (as `hero_juggernaut.lua` does with `GetSpecialValueInt('dam')`) and compute total = impact + dotPerSec * duration, rather than magic constants. Keep a small safety margin instead of a blanket 1.68×.
- **Priority:** P2
- **How to validate:** In-game last-hit/secure scenarios at each Q level; confirm the bot only commits Q-for-kill when the target actually dies. A/B: watch kill-secure success rate.

### P2-3. Talent selections unverified for the aggressive-carry gameplan
- **Location:** `tTalentTreeList` lines **19–24**; resolved via `aba_skill.GetTalentBuild` (lines 135–150) against the comment map (lines 129–136).
- **Current behavior:** The encoding resolves to: **L10** `special_bonus_attack_speed_20` (right), **L15** `special_bonus_unique_wraith_king_6` (right), **L20** `special_bonus_unique_wraith_king_8` (right), **L25** `special_bonus_unique_wraith_king_2` (left). (Recall: in `GetTalentBuild`, a `0` in the pair selects the left/first talent, non-zero selects the right/second.)
- **Problem:** L10 attack speed is a sensible carry pick, but the L15/L20/L25 `unique_wraith_king_*` choices are opaque and were **not** verified against current tooltips. Whether these beat the alternative talents (e.g. skeleton-charge, crit, or reincarnation-cooldown talents) for a farm-then-fight pos-1 is unknown and is a cheap win-rate lever. **[Verify all four WK talent pairs on Liquipedia.]**
- **Proposed change:** After verifying tooltips, prefer talents that compound the skeleton/right-click/second-life plan (e.g. skeleton count/charges or Reincarnation cooldown if available at 20/25) over flat generic stats, and A/B the two talent lines.
- **Priority:** P2
- **How to validate:** A/B two talent configs across a batch; pick the higher win rate / net worth at 30 min.

### P2-4. Level-1 / max order and minor dead code
- **Location:** `tAllAbilityBuildList` line **28** (`{2,1,2,3,2,6,2,3,3,3,6,1,1,1,6}`); `nKeepMana` set at line **170** but never read; `ConsiderW` banking threshold lines **438/444**.
- **Current behavior:** Build takes W (Vampiric Spirit/Bone Guard) at level 1, maxes W first, then E (Mortal Strike), then Q last; `nKeepMana = 160` is assigned each tick but never used (unlike `hero_sven.lua`, which reads it); `ConsiderW` only releases charges at ≥60%/full.
- **Problem:** These are minor. W-at-1 and W-first is a defensible sustain/farm build for pos-1 WK, but level-1 Q (a stun) is a common alternative for securing early aggression/rune fights — worth an A/B. `nKeepMana` is harmless dead code. The 60% banking threshold interacts with P1-1 (charges sitting unused).
- **Proposed change:** Optionally A/B a Q-at-1 variant; remove the unused `nKeepMana` (or wire it into `ShouldSaveMana` like the Sven idiom); revisit the W release threshold together with P1-1.
- **Priority:** P2
- **How to validate:** Batch A/B on the skill order; `luacheck`/smoke test after any cleanup.

---

## Quick reference — key line ranges in `hero_skeleton_king.lua`
- Talents: 19–24 · Ability build: 27–29 · Item builds: 37–88 · Sell list: 92–97
- Ability handles: 151–156 (note stale W handle at 152) · `SkillsComplement`: 164–198
- `ConsiderQ`: 200–415 · `ConsiderW`: 417–452 · `IsNearLaneFront`: 454–466 · `ShouldSaveMana`: 468–482
- External R-aware retreat suppression: `mode_retreat_generic.lua` 172–179
