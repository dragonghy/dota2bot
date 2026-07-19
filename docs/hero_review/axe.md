# Axe (`hero_axe.lua`) — Improvement Backlog

File reviewed: `bots/BotLib/hero_axe.lua` (589 lines). Sibling calibration: `hero_tidehunter.lua`, `hero_sven.lua`.
Ability handles read from the file (lines 108–133): Q `axe_berserkers_call`, W `axe_battle_hunger`, E (passive) `axe_counter_helix`, R `axe_culling_blade`.
Blink Dagger / Blade Mail active use is NOT in this file — it comes from the generic `ability_item_usage_generic.lua` (`item_blink` @1447, `item_blade_mail` @1411).

## Overall assessment

Axe's logic is **functional but shallow and carries at least one concrete bug**. The three casting `Consider*` functions cover the obvious cases (interrupt-on-channel, execute-below-threshold, laning harass, jungle/Rosh) and the execute HP check itself is mechanically sound. But the hero plays "reactively nearest-target" rather than like a strong initiator: Berserker's Call has **no situational gating** (it will Call into a lost, outnumbered fight), initiation relies entirely on the generic Blink logic with no Blink+Call coordination, and the level-25 Culling threshold bonus is **read from the wrong talent** so the bot under-estimates its own execute range late game and leaves kills on the table. The main-role (pos_3) item build is also missing BKB and makes a weak level-15 talent pick. None of these are catastrophic, but fixing them should measurably improve Axe's teamfight kill conversion and survivability.

---

## P0 — Culling Blade threshold reads the wrong talent (missed executes)

- **Location**: `X.ConsiderR()` lines 517–518; talent binding line 140 (`talent5 = bot:GetAbilityByName( sTalentList[5] )`).
- **Current behavior**:
  ```lua
  local nKillDamage = 150 + 100 * nSkillLV
  if talent5:IsTrained() then nKillDamage = nKillDamage + talent5:GetSpecialValueInt( 'value' ) end
  ```
  `sTalentList` is built in slot order (`aba_skill.lua GetTalentList`, slots 10→17), so `sTalentList[5]` = Ability14 = **`special_bonus_hp_regen_20`** (the level-20 LEFT talent), per this file's own header (lines 116–123). The actual "+Culling Blade kill threshold" talent is **`special_bonus_unique_axe`** = Ability17 = `sTalentList[8]` (level-25 RIGHT), which is exactly the talent the build DOES pick (`t25 = {0,10}`, line 20).
- **Problem**: Two compounding errors. (1) `talent5` points at the HP-regen talent, which the build never trains (`t20 = {0,10}` picks the RIGHT talent), so `IsTrained()` is false and the bonus is never added. (2) Even if it were trained, `GetSpecialValueInt('value')` would add the HP-regen number (~20), not the ~150 threshold. Net effect: at level 25 the real hero has a much higher kill threshold than the code believes, so Axe **holds Culling on targets it could actually execute** — the single biggest source of wasted Axe potential.
- **Proposed change**: Bind the threshold talent correctly, e.g. `local talentCull = sAbilityList and bot:GetAbilityByName( sTalentList[8] )` (verify `[8]` = `special_bonus_unique_axe` on the live hero) and use it in `ConsiderR`. Better still, read the base threshold straight from the ability instead of the hardcoded `150 + 100*nSkillLV`: `abilityR:GetSpecialValueInt('kill_threshold')` (verify the special-value key name against d2vpkr). The talent's own bonus then flows through the ability value automatically.
- **Priority**: P0 (unambiguous bug on the hero's signature skill).
- **How to validate**: A/B at level 25+ — count Culling Blade casts that result in a kill vs. enemies who walked away in `[threshold, threshold+150]` HP. Expect more successful executes and higher kill participation in the fixed build; watch hero_damage / kills, not just winrate.

---

## P1 — Berserker's Call has no situational gating (calls into lost fights)

- **Location**: `X.ConsiderQ()` initiation branch, lines 243–254 (invoked first-in-priority after R in `SkillsComplement`, lines 181–190).
- **Current behavior**:
  ```lua
  if J.IsGoingOnSomeone( bot ) then
      if J.IsValidHero( botTarget )
          and J.IsInRange( botTarget, bot, nRadius - 90 )
          and J.CanCastOnNonMagicImmune( botTarget )
          and not J.IsDisabled( botTarget )
      then ... return BOT_ACTION_DESIRE_HIGH end
  end
  ```
  It Calls as soon as *any* proper target is inside the radius.
- **Problem**: No check on enemy-vs-ally count, own HP, or fight strength. Axe will taunt into 3–5 heroes with no allies committed and no BKB active, forcing every nearby enemy to focus him and dying before Culling comes online. Compare `hero_sven.lua ConsiderR` (gates on `J.GetHP(botTarget) > 0.25 or #enemies >= 2`) and its Blink usage which checks `J.WeAreStronger` + ally count. Axe is precisely the hero where "don't initiate a lost fight" matters most.
- **Proposed change**: Add a strength gate to the initiation branch: require allies committed (`#hAllyList >= #hEnemyList` within ~1200, or `J.WeAreStronger(bot, 1200)`) OR self is safe (BKB active / HP high / has Blademail ready). Optionally scale desire up with the number of enemy heroes that would be caught in the radius (Call value grows with bodies for Counter Helix + Blade Mail reflect), and keep a HIGH-desire override for the interrupt-channel case (lines 230–239, already good) regardless of the gate.
- **Priority**: P1.
- **How to validate**: A/B on deaths-immediately-after-Call and Call-with-0-allies frequency; expect fewer throw-away initiations and better trade ratio in teamfights.

---

## P1 — pos_3 (main-role) item build has no Black King Bar

- **Location**: `sRoleItemsBuyList['pos_3']`, lines 52–68.
- **Current behavior**: `item_tank_outfit`, `item_crimson_guard`, `item_blade_mail`, `item_blink`, `item_aghanims_shard`, `item_heavens_halberd`, `item_travel_boots`, `item_assault`, `item_ultimate_scepter_2`, `item_moon_shard`, `item_heart`, `item_overwhelming_blink`. **No `item_black_king_bar`.** (pos_1 has it at line 41; the offlane build does not.)
- **Problem**: Axe's whole plan is Blink → Call in the middle of the enemy team. Without BKB he gets chain-disabled and bursted before Culling / Blade Mail pay off. BKB is a standard situational Axe item and its absence from the *primary* role build is a real gap. Heaven's Halberd + Blade Mail + Crimson are all good, but none substitute for spell-immunity vs a disable-heavy enemy lineup.
- **Proposed change**: Insert `item_black_king_bar` into the pos_3 list (roughly after Blink / before or alongside Halberd). Ideally make it conditional on enemy magic/disable threat, but even an unconditional add matches how the pos_1 list already treats it.
- **Priority**: P1.
- **How to validate**: A/B vs disable-heavy enemy comps; track Axe's average time-alive-in-fight and successful Call-to-Culling sequences.

---

## P1 — Level-15 talent picks Mana Regen over Attack Speed

- **Location**: `tTalentTreeList`, line 22: `['t15'] = {10, 0}` → picks the LEFT talent = `special_bonus_mp_regen_2` (Ability12) over the RIGHT `special_bonus_attack_speed_35` (Ability13).
- **Current behavior**: +2 mana regen chosen instead of +35 attack speed.
- **Problem**: +35 attack speed is far stronger for Axe — more attacks = more Counter Helix procs, more Blade Mail-reflected damage taken/dealt, faster Rosh/tower, better DPS. +2 mp regen is nearly irrelevant on a hero with a 400 keep-mana floor and cheap spells. This looks like an unconsidered default.
- **Proposed change**: Set `['t15'] = {0, 10}` (attack speed). Verify the L/R mapping holds on the live hero (header lines 118–119 confirm Ability12=mp_regen, Ability13=attack_speed).
- **Priority**: P1.
- **How to validate**: A/B GPM/XPM and hero_damage; expect higher sustained fight damage and faster objective/Rosh timings.

---

## P2 — Culling Blade base threshold is hardcoded, not read from the ability

- **Location**: `X.ConsiderR()` line 517, `local nKillDamage = 150 + 100 * nSkillLV`.
- **Current behavior**: Hardcoded formula (yields 250/350/450 for levels 1/2/3, which matches current values).
- **Problem**: Violates the project convention that number-only changes should be handled by the game API (CLAUDE.md / ARCHITECTURE.md). A future rebalance of the threshold silently desyncs the bot's execute logic. Also does not reflect any scepter/shard modification if one exists.
- **Proposed change**: Read the value from the ability: `abilityR:GetSpecialValueInt('kill_threshold')` (confirm the exact special-value key via d2vpkr `npc_heroes.txt`). Fold this into the P0 fix.
- **Priority**: P2.
- **How to validate**: Static — no behavior change at current numbers; protects against future patch drift. Smoke test + one in-game cull check.

---

## P2 — Culling Blade magic-immunity guard flagged "V BUG" (needs confirmation, likely fine)

- **Location**: `X.ConsiderR()` line 535: `and not npcEnemy:IsMagicImmune() --V BUG`.
- **Current behavior**: Refuses to Cull spell-immune targets.
- **Problem**: The `--V BUG` comment implies someone suspected this is wrong. Culling Blade does **not** pierce spell immunity, so refusing to target a BKB'd enemy is correct — the guard should stay. The misleading comment invites a future "fix" that would make the bot waste Culling on immune targets (cast fails, long cooldown, no refresh).
- **Proposed change**: Leave the guard; delete or correct the `--V BUG` comment. Confirm in-game that Culling cannot target a spell-immune hero in the current patch.
- **Priority**: P2 (documentation/verification, not a behavior change).
- **How to validate**: In-game — attempt to Cull a BKB'd low-HP hero; confirm the cast is invalid.

---

## P2 — No defensive / peel use of Berserker's Call

- **Location**: `X.ConsiderQ()` — branches exist for interrupt, initiation, lane push, Rosh, Tormentor, jungle; there is **no** retreat/peel branch (contrast `hero_tidehunter.lua ConsiderW`/`ConsiderQ` and `hero_sven.lua ConsiderQ`, which both handle `J.IsRetreating`).
- **Current behavior**: Call is only ever offensive.
- **Problem**: A taunt is a strong peel/escape tool — forcing 1–2 chasers to stop and attack Axe (who has armor from the Call + Counter Helix + Blade Mail) can save Axe or a fleeing ally. The bot never uses it this way.
- **Proposed change**: Add a retreat branch: if `J.IsRetreating(bot)` (or an ally nearby is retreating and being chased) and ≥1 enemy hero within radius who `WasRecentlyDamagedByHero`/is chasing, Call at MODERATE–HIGH desire, gated on HP so it isn't a suicide taunt.
- **Priority**: P2.
- **How to validate**: A/B on Axe/escorted-ally survival when outnumbered and fleeing.

---

## P2 — Battle Hunger "kill" prediction is over-optimistic

- **Location**: `X.ConsiderW()` lines 342–343, 353–364.
- **Current behavior**:
  ```lua
  local nDamage = abilityW:GetSpecialValueInt('damage_per_second') * nDuration
  ... J.WillMagicKillTarget( bot, npcEnemy, nDamage, nDuration ) ... return HIGH  -- "W-击杀"
  ```
  Treats the full-duration DoT total as burst for a kill check.
- **Problem**: Battle Hunger is a slow damage-over-time that the enemy can outrun, out-regen, or cancel early (killing a unit removes it). Predicting a kill from full-duration damage and firing at HIGH desire over-values it and can "commit" the bot to a target that walks away. The DoT is a chase/harass/slow tool, not an execute.
- **Proposed change**: Keep the DoT for harass/slow/team-fight-weakest-target (those branches are fine), but downgrade or remove the standalone "will kill over full duration" branch, or require the target to also be slowed/rooted/low-mobility before trusting the full-duration kill. Consider using W primarily to enable Culling setup (slow the runner so Axe/allies bring them under threshold).
- **Priority**: P2.
- **How to validate**: A/B on wasted-W frequency (W cast on a hero who survives full duration and escapes) and mana efficiency.

---

## P2 — Blink+Call not coordinated; initiation depends entirely on generic Blink

- **Location**: `X.SkillsComplement()` lines 151–205 (no Blink handling here); generic `item_blink` @ `ability_item_usage_generic.lua:1447`, `J.IsGoingOnSomeone` branch @1554–1609. Axe is NOT in the `bot.shouldBlink` combo list (lines 1558–1566).
- **Current behavior**: The generic Blink lands Axe near `botTarget` (within ~150 after `RandomVector(150)`) when `WeAreStronger` and ally count is favorable; on the next think, `ConsiderQ` fires the Call. Two separate think functions, no explicit ordering guarantee.
- **Problem**: Works in practice (blink lands inside Call radius, Call follows next frame) but there is no same-frame Blink→Call queue and no Axe-specific tuning of *where* to land to maximize heroes caught. Occasionally Axe can blink and then fail to Call (e.g. target repositions out of `nRadius - 90`, or the fight-strength gate proposed above rejects it after the blink is spent).
- **Proposed change**: Optionally give Axe an explicit Blink→Call action queue (land at the enemy cluster centroid, then `ActionQueue_UseAbility(abilityQ)`), and keep the same fight-strength gate on both so the bot doesn't blink in and then decline to Call. Lower priority than the gating/talent/BKB fixes; the generic path is "good enough" today.
- **Priority**: P2.
- **How to validate**: A/B on heroes-caught-per-Call after a blink initiation and on "blinked but didn't Call" incidents.

---

## Notes / lower-confidence observations (verify in-game, no action yet)

- **`talent7` (Call radius, lines 139 & 216)**: `sTalentList[7]` = Ability16 = `special_bonus_unique_axe_2` (level-25 LEFT). This is mutually exclusive with the Culling-threshold talent the build actually picks (`t25 = {0,10}` = RIGHT), so `talent7:IsTrained()` is normally false and the radius bonus is never applied — same class of index issue as the P0 item, though lower impact. Confirm whether `special_bonus_unique_axe_2` is truly the Call-AoE talent and decide if it's worth picking over the threshold talent at 25.
- **`pos_1` build (lines 36–50)**: Axe as a hard carry (`item_sven_outfit` start) is unusual; likely rarely selected since Axe scores as an offlaner in `aba_hero_roles_map`. Not worth tuning unless data shows Axe getting picked pos_1/2.
- **`item_ultimate_scepter_2` in pos_3 (line 62) without a preceding `item_ultimate_scepter`**: represents a "consume a second scepter" buy (`aba_item.lua:1225`). Axe's Aghanim's Scepter is niche; verify it's actually worth a slot on the offlane build vs. e.g. a defensive/utility item.
- **`t10 = {0,10}` (line 23) picks +20 movement speed over +8 strength**: defensible for a blink initiator (gap-close) but +8 str is a common durability pick; low priority, revisit only if data suggests.
- **`t20 = {0,10}` (line 21) picks `special_bonus_unique_axe_3`**: identify what this talent does before trusting it over `+20 HP regen`; likely fine.
