# Crystal Maiden — Bot Logic Review & Improvement Backlog

File reviewed: `bots/BotLib/hero_crystal_maiden.lua` (1034 lines).
Reviewed against sibling support idioms (`hero_lion.lua`) and helper semantics in `FunLib/jmz_func.lua`.
Review only — **no code was modified.**

## Overall assessment

CM's spell-casting `Consider` functions are competent for lane harass and creep clear, and the file does one thing well that most bots miss: `ConsiderCombo()` (lines 237-278) actively protects an in-progress Freezing Field channel with Shadow Amulet / Glimmer / Invis. But the **core CM decision — whether to channel Freezing Field at all — is unsafe**: the teamfight trigger (lines 882-889) fires on a raw nearby-enemy count with *no* check for ally presence, protection (BKB/Glimmer/blink), or a won fight, so the fragile pos-5 will channel and get bursted. Compounding this, the pos-5 item build ships **no Blink, no BKB, no Force Staff, and no Aghanim's Scepter**, which both removes CM's standard ult-positioning/protection combo and leaves the `ConsiderCrystalClone()` logic (scepter-only) effectively dead. Frostbite target selection is solid for self-peel and kill-secure but never peels for an allied core. Fixing the ult-safety gate and the build are the two highest-leverage changes.

Ability handles (verified against the in-file `npc_dota_hero_crystal_maiden` block, lines 111-136, and `spell_list.lua`):
`crystal_maiden_crystal_nova` (Q, `sAbilityList[1]`), `crystal_maiden_frostbite` (W, `[2]`), `crystal_maiden_brilliance_aura` (passive, `[3]`), `crystal_maiden_crystal_clone` (scepter-granted, `[4]`), `crystal_maiden_freezing_field` (R, `[6]`).

---

## P0

### 1. Freezing Field is channeled with no safety / protection / won-fight gate
- **Location:** `X.ConsiderR()`, lines 854-924 — specifically the primary trigger at 882-889.
- **Current behavior:**
  ```lua
  if bot:GetActiveMode() ~= BOT_MODE_RETREAT
      or ( ... RETREAT and bot:GetActiveModeDesire() <= 0.85 ) then
      if ( #nEnemysHeroesInRange >= 3 or aoeCanHurtCount >= 2 ) then
          return BOT_ACTION_DESIRE_HIGH
      end
  end
  ```
  The only inputs are enemy count within `AOERadius*0.88` (line 863) and a partial "will they stay in it" count (`aoeCanHurtCount`, 872-881, enemies that are disabled or slower than the radius margin).
- **Problem:** This is the signature CM decision and it ignores everything a strong player weighs before committing a 5-6s channel that roots CM in place:
  - **No ally presence check** — CM will channel solo against 2-3 enemies (mode is ATTACK/PUSH/GANK, not RETREAT), i.e. exactly the facecheck-into-death scenario.
  - **No self-protection check** — does not require BKB active, Glimmer, Wind Waker, blink distance, or being behind allies. A single stun/silence/burst cancels it instantly.
  - **No "won fight" signal** — doesn't check that enemies are already locked down by the team or low HP; `aoeCanHurtCount >= 2` counts merely-slowed enemies who can walk out.
  - A bot that ults badly is worse than one that never ults; this trigger will lose CM for free in even fights.
- **Proposed change:** Gate the teamfight channel on a conjunction of safety signals, e.g. require **at least one** of: BKB active (`bot:HasModifier('modifier_black_king_bar_immune')`), Glimmer/Wind Waker just used or available to self-cast this frame, or `#allies_in_1200 >= #enemies_in_range`; **and** require enemies to be committed (≥2 already disabled, or a teammate in ATTACK mode within 1200 via `J.IsInTeamFight`). Raise the count threshold to `#nEnemysHeroesInRange >= 3 AND aoeCanHurtCount >= 2` (both, not either) when unprotected. Keep the existing `ConsiderCombo` channel-protection as the second line of defense.
- **Priority:** P0
- **How to validate:** A/B metric — CM **deaths while channeling** / channel-interrupt rate (parse "Freezing Field" cast vs death within its duration), average Freezing Field damage per cast, and teamfight win rate. Target: fewer channel-deaths and higher damage-per-cast without a drop in cast frequency in genuinely won fights.

---

## P1

### 2. No BKB / Blink initiation tied to the ult; combo only reacts defensively
- **Location:** `X.SkillsComplement()` (157-218) ordering; `X.ConsiderCombo()` (237-278); `X.ConsiderR()` (854-924).
- **Current behavior:** `ConsiderCombo` only runs **while already channeling** (`bot:IsChanneling()`, line 239) and only uses Shadow Amulet, Glimmer, Invis Sword, Silver Edge — never BKB, never a Blink to center the ult. There is no logic that blinks into position or pops BKB *before/at* the moment of casting Freezing Field.
- **Problem:** Standard pos-5 CM play is Blink → Freezing Field → BKB (or BKB → channel) so the AoE lands centered on the enemy team and survives disables. Without it the bot channels from wherever it happens to stand and dies to the first interrupt. This is the execution half of item #1's decision half.
- **Proposed change:** Add a pre-ult combo: when `ConsiderR` would return HIGH and a Blink is available and enemies are clustered ~1000-1200 away, blink to a location centering the cluster first; then on the channel frame, self-cast BKB if owned and enemies have interrupts. Sequence BKB into `ConsiderCombo` (add an `item_black_king_bar` branch) as the highest-priority channel protector, ahead of Glimmer.
- **Priority:** P1
- **How to validate:** In-game (T3): confirm CM blinks in and BKBs before/at ult in a scripted 5v5; A/B: enemies-hit-per-Freezing-Field and channel-completion rate.

### 3. pos-5 item build is missing CM's signature items (Blink, BKB, Force, Aghs)
- **Location:** `sRoleItemsBuyList['pos_5']`, lines 43-58 (and `pos_4`, 28-41).
- **Current behavior:** pos_5 = `blood_grenade, mage_outfit, ancient_janggo, glimmer_cape, boots_of_bearing, pipe, shivas_guard, cyclone, sheepstick, aghanims_shard, wind_waker, moon_shard, ultimate_scepter_2`.
- **Problem:**
  - **No `item_blink`** — CM's primary ult-positioning and escape item is absent (Lion's list has it).
  - **No `item_black_king_bar`** — the item that makes Freezing Field actually channel through a fight is absent.
  - **No `item_force_staff`** — the standard support self-peel/repositioning item for a fragile hero is absent (this is also the main file-level survivability lever, see #6).
  - **No real `item_ultimate_scepter`** — only `item_ultimate_scepter_2`, which per `aba_item.lua:1225` is the "blessing" that only resolves when the hero *already* `HasScepter()`. CM's Aghs (grants `crystal_maiden_crystal_clone`) is a strong, standard pickup and its absence makes the entire `ConsiderCrystalClone` path dead (see #7).
  - The list is also over-stuffed with overlapping disables (cyclone + wind_waker + sheepstick) while lacking the fight-defining Blink/BKB.
- **Proposed change:** Rework pos_5 toward: `mage_outfit → arcane/tranquil boots → glimmer_cape → force_staff → aghanims_shard → blink → black_king_bar → ultimate_scepter → sheepstick/shivas` as greedy late game. Mirror the fix into pos_4. Verify all item internal names against `FunLib/aba_item.lua`.
- **Priority:** P1
- **How to validate:** A/B GPM/XPM neutral, but survivability up: CM deaths/game down, assists/teamfight participation up. Confirm purchase order in a T1 smoke match.

### 4. Frostbite never peels for an allied core; teamfight target is "most damage to CM" only
- **Location:** `X.ConsiderW()` teamfight branch, lines 646-675; self-protect branch 678-693.
- **Current behavior:** Teamfight target is chosen by `npcEnemy:GetEstimatedDamageToTarget( false, bot, 3.0, DAMAGE_TYPE_PHYSICAL )` (line 661) — highest physical damage **to the bot (CM)**. The only other peel is "protect self" (678-693), also self-referential and additionally gated on `bot:IsFacingLocation(npcEnemy, 45)` (line 688).
- **Problem:** A pos-5 CM's most valuable Frostbite is often rooting an enemy diving the allied carry, not the one hitting CM. The current logic never evaluates threat to allies, so it will let a low-HP core die while rooting whoever happens to threaten CM. The `IsFacingLocation` restriction on the self-peel is also an odd, brittle constraint (Frostbite is targeted; facing shouldn't matter).
- **Proposed change:** Add a branch: if a low-HP allied hero (`J.GetHP(ally) < ~0.5`) is being attacked by an enemy within Frostbite range, root that attacker (peel-for-carry), prioritized just below kill-secure and TP-interrupt. Keep the existing self-peel but drop the `IsFacingLocation` gate.
- **Priority:** P1
- **How to validate:** In-game: set up a dive on a scripted allied carry and confirm CM roots the diver. A/B: allied-core deaths in fights where CM is present, CM assist count.

---

## P2

### 5. `ConsiderArcaneAura` is dead code — it "casts" a passive
- **Location:** `X.ConsiderArcaneAura()` (220-235); called first in `SkillsComplement` (173-180).
- **Current behavior:** Returns HIGH and does `bot:ActionQueue_UseAbility(ArcaneAura)`, guarded by `J.CanCastAbility(ArcaneAura)`.
- **Problem:** `crystal_maiden_brilliance_aura` is a **passive** aura. `J.CanCastAbility` returns false for any ability where `IsPassive()` is true (`jmz_func.lua:864`), so this branch can never fire — it's dead. It also sits as the *first* check in `SkillsComplement`, so it's the most-run no-op and it misleads future readers into thinking CM has an active aura.
- **Proposed change:** Remove `ConsiderArcaneAura` and its call, or replace with the real early-game desire (Arcane Aura has no active). Free the top-of-function slot for a meaningful check.
- **Priority:** P2
- **How to validate:** luacheck clean + smoke load; no behavior change expected (confirms it was inert).

### 6. `ConsiderCrystalClone` is effectively dead for the support build
- **Location:** `X.ConsiderCrystalClone()` (926-977); dependency on `sAbilityList[4]` = `crystal_maiden_crystal_clone`, scepter-granted.
- **Current behavior:** Guards on `CrystalClone:IsTrained()` (927). The clone ability only exists if CM owns Aghanim's Scepter.
- **Problem:** The pos_5/pos_4 builds never buy `item_ultimate_scepter` (see #3), so `IsTrained()` is almost always false and this whole function never runs for a support CM. The logic itself is reasonable (outnumber-check to send a clone toward fountain), so this is a build/logic mismatch, not a logic-quality problem.
- **Proposed change:** Reconcile with #3 — if Aghs is added to the build, this activates and should be validated; if CM is intended to stay scepter-less as pos-5, note the function is intentionally latent. Recommend adding Aghs (standard) and keeping the logic.
- **Priority:** P2
- **How to validate:** With Aghs in build, confirm in-game the clone is cast on outnumbered engagements/retreats.

### 7. Talent picks look off for a spellcaster support — verify on Liquipedia before changing
- **Location:** `tTalentTreeList`, lines 11-16. Talent slot names in the in-file comment (119-126).
- **Current behavior / mapping (`{left, right}`, 10 = take):**
  - t10 `{0,10}` → `special_bonus_cast_range_100` (over `special_bonus_hp_250`)
  - t15 `{0,10}` → `special_bonus_gold_income_25` (over `special_bonus_unique_crystal_maiden_4`)
  - t20 `{10,0}` → `special_bonus_attack_speed_250` (over `special_bonus_unique_crystal_maiden_3`)
  - t25 `{0,10}` → `special_bonus_unique_crystal_maiden_2` (over `..._1`)
- **Problem:** t20 taking **+250 attack speed** — an auto-attack stat — over a unique CM talent is suspect for a hero who fights with spells and rarely right-clicks in fights. t15 taking **gold income** over the unique talent trades fight impact for economy on a hero that wants impact. t10 cast range vs +250 HP is a real trade-off (survivability vs safer casts) worth A/B-ing.
- **Proposed change:** Do **not** guess the unique-talent effects — verify `special_bonus_unique_crystal_maiden_1..4` and `_3` on Liquipedia/d2vpkr, then very likely flip t20 to the unique and reconsider t15. Treat t10 as an A/B question.
- **Priority:** P2 (needs verification before implementation)
- **How to validate:** After verifying effects, A/B the flipped talent build for teamfight impact (damage, disables landed) vs current.

### 8. Freezing Field "death channel" while retreating
- **Location:** `X.ConsiderR()`, lines 907-920.
- **Current behavior:** While retreating with `nHP > 0.38`, if Q and W are both on cooldown and an enemy is within 500, returns HIGH to channel.
- **Problem:** Channeling roots CM in place — casting Freezing Field *while trying to retreat* usually gets her killed rather than saving her, unless it's a genuine last-stand. The `nHP > 0.38 * #enemiesFurther` scaling (916) is opaque and can trigger at healthy HP against multiple chasers.
- **Proposed change:** Restrict this branch to true last-stand (very low HP, no escape available, chasers guaranteed to catch), or remove it in favor of Wind Waker/Force/Glimmer escapes. At minimum require `not bot:HasModifier('modifier_...tp')` and no escape item available.
- **Priority:** P2
- **How to validate:** A/B: CM survival rate during retreats; count retreat-ults that result in death vs escape.

### 9. Latent nil-index risk in Crystal Nova creep-count guard
- **Location:** `X.ConsiderQ()`, lines 314-319.
- **Current behavior:**
  ```lua
  if nCanHurtCreepsLocationAoE == nil
      or nCanHurtCreepsLocationAoE.targetloc == nil
      or J.GetInLocLaneCreepCount(...) <= 2 then
      nCanHurtCreepsLocationAoE.count = 0
  end
  ```
- **Problem:** If `nCanHurtCreepsLocationAoE` were ever `nil`, the guard's own body (`nCanHurtCreepsLocationAoE.count = 0`) would index nil and error. In practice `bot:FindAoELocation` returns a table so this likely never fires, hence latent, not active.
- **Proposed change:** Move the `.count = 0` write into a form that doesn't dereference when nil (e.g. only zero it in the non-nil sub-cases, or early-return). Low urgency.
- **Priority:** P2
- **How to validate:** Smoke test unaffected; defensive-only.

### 10. Crystal Nova solo-cast thresholds during "going on someone" are convoluted
- **Location:** `X.ConsiderR()` going-on branch (892-905) and `X.ConsiderQ()` attack branches.
- **Current behavior:** The R solo-kill branch requires `#nAllies <= 2`, `npcTarget:GetHealth() > 400`, and a 1.5×-offensive-power kill check simultaneously (898-901).
- **Problem:** The `GetHealth() > 400` floor means CM won't ult to finish a sub-400-HP target (where the channel would actually secure a kill), and `#allies <= 2` arbitrarily forbids the solo-ult in the exact grouped scenario where it's safest. The thresholds encode intent poorly.
- **Proposed change:** Re-derive from the kill math: allow the finishing ult when `J.WillMagicKillTarget` (or the incoming-damage check) confirms lethality and CM is safe (ties into #1), independent of the ally count and the 400-HP floor.
- **Priority:** P2
- **How to validate:** A/B: solo-kill conversion rate with ult; ensure no increase in wasted channels.

---

## Notes on positioning / survivability (focus area 4)

Most movement is owned by the `mode_*_generic.lua` scripts; the hero file's realistic levers are (a) not committing the ult into death (items #1, #2, #8), and (b) owning reactive self-peel/escape items. Today the escape toolkit in code is Glimmer/Wind Waker/Cyclone via defensive branches, but **Force Staff is not even purchased** (#3), which is the single biggest file-level survivability gap for a fragile pos-5. Prioritize the ult-safety gate and the build fix; they cover the bulk of CM's "dies for nothing" failure mode.

## Items to verify in-game (T1/T3) before implementing
- Exact effects of `special_bonus_unique_crystal_maiden_1..4` and `_3` (talent rework #7).
- Whether adding Aghs meaningfully activates `ConsiderCrystalClone` for a support (#6).
- That the P0 safety gate still lets CM ult in genuinely won fights (avoid over-tightening into "never ults").
