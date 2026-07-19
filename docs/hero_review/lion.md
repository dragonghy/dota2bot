# Lion (`hero_lion.lua`) — Improvement Backlog

**File reviewed:** `bots/BotLib/hero_lion.lua` (1056 lines), at 7.41a snapshot.
**Kit (verified against the file header + d2vpkr):** Q `lion_impale` (Earth Spike, line stun), W `lion_voodoo` (Hex), E `lion_mana_drain` (channel), R `lion_finger_of_death` (single-target nuke, +25 dmg/kill scaling, Aghs = +100 dmg & 325 splash).

## Overall assessment

The file is a competent, defensive nuker script: Finger only fires when it actually secures a kill (it correctly holds vs full-HP tanks), `WillMagicKillTarget` properly models magic resist / spell-amp / regen, and Q→W spacing plus `IsDisabled` guards give real chain-CC behavior. The **base damage/scepter math is correct** (600/725/850 = `475+125*LV`; scepter `575+125*LV` = +100), so the core kill estimate is trustworthy. The weaknesses are in *value*, not survival: every ability fires at the *first/nearest* valid enemy rather than the *highest-value killable* one, disable targeting ignores magic casters, the support item builds skip Aether Lens (which the code itself relies on) and BKB, and the hardcoded talent build/indices look stale vs the current talent set and need re-verification. None of these are crashes — they are decision-quality gaps that a strong player exploits.

---

## P0 — highest impact

### 1. Finger of Death fires at the FIRST killable enemy, not the highest-value one
- **Location:** `X.ConsiderR`, kill loop, lines 843–854.
- **Current behavior:** `for _, npcEnemy in pairs( nInBonusEnemyList ) do ... if J.WillMagicKillTarget(...) then return BOT_ACTION_DESIRE_HIGH, npcEnemy end end` — returns the **first** enemy in list order for which Finger is lethal.
- **Problem:** When both a low-value support and the enemy carry/mid are simultaneously killable, Lion may burn its 110/70/30s ultimate on the support because it appears earlier in `nInBonusEnemyList`. The single signature Lion decision — "Finger the right hero" — is left to list ordering.
- **Proposed change:** Collect *all* enemies satisfying `CanCastAbilityROnTarget` + `WillMagicKillTarget`, then pick the max by value (e.g. `npcEnemy:GetNetWorth()`, or an existing role/threat weight, tie-break on lowest HP%). Finger the highest-value killable target.
- **Priority:** P0
- **How to validate:** A/B a scenario with two killable enemies (fed carry + support) in range; measure share of Fingers landing on the higher-net-worth hero, and enemy-carry death count / GPM denied. Expect higher-value kills without a drop in total kills.

### 2. Support builds (pos_4/pos_5) never buy Aether Lens, yet the code depends on it
- **Location:** `sRoleItemsBuyList['pos_4']` (lines 36–52) and `['pos_5']` (54–70); consumed at lines 214–215 (`aether = J.IsItemAvailable("item_aether_lens"); aetherRange = 250`).
- **Current behavior:** Only the off-role core builds (`pos_2`, line 106) list `item_aether_lens`. The pos_4 and pos_5 lists — Lion's actual roles — never buy it, so `aetherRange` stays 0 for the whole game.
- **Problem:** Aether Lens is a core Lion item (+250 cast range on Hex/Spike/Finger/Drain, +mana). The script is written to exploit the extra range but never acquires it, so Lion perpetually casts at minimum range and eats more risk to land the combo.
- **Proposed change:** Insert `item_aether_lens` into `pos_4` and `pos_5` early-mid (around the Blink/Glimmer slot). Consider it before Scepter for pos_5.
- **Priority:** P0 (cheap, high-confidence, and the logic already rewards it)
- **How to validate:** A/B win-rate + average combo cast distance / deaths-during-cast. Expect fewer deaths initiating and more landed combos.

---

## P1 — strong improvements

### 3. Hex ignores magic-damage casters when picking the teamfight target
- **Location:** `X.ConsiderW`, teamfight "most dangerous" block, lines 576–605.
- **Current behavior:** `local npcEnemyDamage = npcEnemy:GetEstimatedDamageToTarget( false, bot, 3.0, DAMAGE_TYPE_PHYSICAL )` — ranks enemies purely by estimated **physical** right-click damage.
- **Problem:** A fed Lina / Zeus / Lion / SF-caster returns ~0 physical estimate and is never considered the "most dangerous," so Hex (Lion's premier single-target lockdown) skips the enemy nuker who most needs shutting down. Channelers are handled separately (interrupt block, 531–558), but instant-cast burst mages are not.
- **Proposed change:** Rank by combined threat: `GetEstimatedDamageToTarget(...PHYSICAL)` plus a magic/burst proxy (e.g. enemy has offensive mana + is a known nuker, or `GetOffensivePower()`, or a role/threat weight from the roles map). At minimum, treat high-INT cores with mana as high-priority Hex targets.
- **Priority:** P1
- **How to validate:** A/B vs a nuker-heavy enemy lineup; measure whether Hex lands on the primary magic threat and resulting teamfight win rate.

### 4. Chain-disable spacing is a fixed 0.8s and can overlap Spike's stun with Hex
- **Location:** `X.ConsiderW` gate at lines 517–519 (`lastCastQTime > DotaTime() - 0.8 then return 0`); `lastCastQTime` set at 252 in `SkillsComplement`.
- **Current behavior:** After Earth Spike, Hex on the *same* target is blocked for only 0.8s (and other branches also check `not J.IsDisabled`).
- **Problem:** Earth Spike stun is ~1.3–2.4s. An 0.8s gate can allow Hex to land while the stun is still running, wasting up to ~1s+ of total lockdown. The `IsDisabled` guard partly saves this by redirecting Hex to a *different* enemy, but the fixed timer is a blunt instrument and can also needlessly delay a legitimate Hex on a *second* target.
- **Proposed change:** Replace the fixed 0.8s with duration-aware chaining: if the intended Hex target is still stunned/disabled, either skip (spread CC to another threat — good) or delay Hex until the disable has < ~0.3s remaining (`J.GetModifierTime` on the stun) so lockdown chains instead of overlapping. Don't block Hex on target B just because target A was Spiked.
- **Priority:** P1
- **How to validate:** In-game: total lockdown seconds applied per combo on a single target; A/B kill-secure rate on a lone ganked hero.

### 5. Default level-10 talent and stale talent index mapping — VERIFY
- **Location:** `tTalentTreeList` lines 19–24; talent refs `talent4/5/8` lines 181–183, used at 216 (commented), 1006 (`GetAbilityRDamageBonus`), and throughout `ConsiderW` for the AoE-Hex branches (534, 539, 550, 566, 599, 621, 645, 670, 688).
- **Current behavior:** `t10 = {0, 10}` selects the **right** level-10 talent. Per the in-file comment block (lines 158–165) the tier-10 pair is `cast_range_100` / `attack_damage_90`, so `{0,10}` takes **+90 attack damage** over **+100 cast range**. Code also references `talent4` (`sTalentList[4]`, commented-out cast-range add — index looks wrong, that slot is `gold_income_25` per the header), `talent5` for Finger damage-per-kill, and `talent8` to switch Hex to a ground/AoE cast.
- **Problem:** (a) For a pos-4/5 chain-disabler, **+100 cast range is almost always the stronger level-10 pick** than +90 attack damage. (b) More importantly, d2vpkr's current Lion talent set does **not** match the file's header comment (the header lists `special_bonus_unique_lion/2/3/4`, `hp_500`, `gold_income_25`; the live tree uses a different `unique_lion_*` numbering and different tiers). That means the hardcoded side selections **and** the positional `talent5`/`talent8` references may point at the wrong talents on the current patch — e.g. the entire AoE-Hex code path (`talent8:IsTrained()` → `ActionQueue_UseAbilityOnLocation`) may be gated on a talent the default build never takes, or one that no longer converts Hex to ground-target.
- **Proposed change:** Re-derive the talent list from d2vpkr `npc_dota_hero_lion` for the target patch; fix `tTalentTreeList` to prefer cast range at 10 and utility/lockdown talents (Hex radius/cooldown, Finger dmg-per-kill) at higher tiers; and confirm `talent5`/`talent8` resolve to the intended abilities (or switch to name-based `GetAbilityByName`). Mark the AoE-Hex branch live only if the taken talent actually makes Hex ground-targetable.
- **Priority:** P1 (correctness + value; **requires d2vpkr/in-game verification** before editing)
- **How to validate:** Print `sTalentList` in-game to confirm indices; A/B cast-range vs attack-damage at 10 for win rate and combo reliability.

### 6. Cross-ability target selection is nearest/first, not value-focused
- **Location:** `ConsiderQ` "常规" block 474–490 and "攻击" 366–383; `ConsiderR` weakest-by-raw-HP 856–882; general reliance on `botTarget = J.GetProperTarget(bot)` (210).
- **Current behavior:** Q's generic block fires on the first in-range castable enemy; R's teamfight block chooses purely by lowest absolute `GetHealth()`; most branches key off `botTarget`, i.e. whatever the bot is already attacking.
- **Problem:** For a chain-disabler the combo should focus the enemy's *key* hero, not the nearest creepwave-adjacent target or the lowest-HP illusion/support. Lowest absolute HP also biases toward supports and misjudges effective HP (armor/magic resist).
- **Proposed change:** Introduce a shared "priority enemy" selector (highest net worth / role-threat among castable in-range enemies, effective-HP aware) and prefer it in Q/W/R attack branches, falling back to `botTarget` only when no priority target is in range.
- **Priority:** P1
- **How to validate:** A/B enemy-core death share and average gold denied to enemy pos-1/2.

---

## P2 — refinements & latent issues

### 7. `MayKillTarget` ignores its parameter and uses the global `botTarget`
- **Location:** `X.MayKillTarget(nTarget)`, lines 1038–1053.
- **Current behavior:** Signature takes `nTarget`, but the body computes `bot:GetEstimatedDamageToTarget( true, botTarget, 9.0, ... )` and `J.CanKillTarget( botTarget, ... )` — it evaluates the **global** `botTarget`, not the passed argument.
- **Problem:** Latent bug. Today both call sites (787, 805) happen to pass `botTarget`, so it's harmless, but any future caller passing a different unit gets wrong results. Also the "can I just right-click this down?" gate uses 9s of PHYSICAL auto-attack damage, a weak proxy for a support Lion and one that ignores Finger.
- **Proposed change:** Use the `nTarget` parameter consistently; reconsider the 9.0s physical horizon.
- **Priority:** P2

### 8. Mana Drain only stops channeling when in RETREAT mode
- **Location:** `X.ConsiderStopDrain` (276–286) + `IsAbilityEChanneling` (289–314); called first in `SkillsComplement` (197–201).
- **Current behavior:** Breaks the channel only if `J.IsRetreating(bot)`.
- **Problem:** If Lion is draining (not in retreat mode) and gets burst/jumped, it keeps channeling and dies mid-cast. A strong player cancels drain the instant a threat commits.
- **Proposed change:** Also cancel when low HP + recently damaged by a hero, or when a disable/heavy nuke is incoming (e.g. `bot:WasRecentlyDamagedByAnyHero(1.0)` and `nHP` below a threshold, or an enemy blink/jump detected).
- **Priority:** P2
- **How to validate:** In-game: deaths while channeling Mana Drain before/after.

### 9. Finger can be "wasted" securing a low-value near-dead target an ally would finish
- **Location:** `ConsiderR` kill loop 843–854 (and desperation `nHP < 0.2` at 932).
- **Current behavior:** Fires whenever Finger is lethal to any valid target, regardless of that target's value or whether allied burst/auto-attacks already secure it.
- **Problem:** Burning a 110/70/30s ultimate to last-hit a low-HP support that an ally attack would kill anyway is a tempo loss. (The Aeon Disk case is also unmodeled — `WillMagicKillTarget` doesn't predict an Aeon proc, so Finger can be spent only to pop the disk without killing.)
- **Proposed change:** Skip Finger on low-value targets when an ally can secure the kill this second (reuse a "kill secured by allies" check), and hold if the target has an active/available Aeon Disk that Finger alone won't punch through. Keep firing when Finger is the only lethal source or the target is high value.
- **Priority:** P2
- **How to validate:** Fingers-per-kill efficiency (kills secured per Finger cast) and average value of Fingered targets.

### 10. Early E branches (illusion-kill / refill) run before the "other ability castable" guard
- **Location:** `X.ConsiderE`: mana-refill 722–739 and illusion-kill 742–770 sit **above** the guard `if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0` (773); E is evaluated first in `SkillsComplement` (219–228).
- **Current behavior:** The illusion-kill branch can return HIGH and pre-empt R/Q/W via `Action_ClearActions(false)`.
- **Problem:** Vs illusion heroes (PL, Naga, TB), Lion may channel-drain a suspicious illusion instead of Hexing/Fingering the real hero in a fight. Situational but can throw a fight.
- **Proposed change:** Gate the illusion-kill drain behind "not in an active teamfight / no higher-value cast available," or move it below the `IsOtherAbilityFullyCastable` guard.
- **Priority:** P2

### 11. Support builds carry no BKB / limited survivability for the squishiest combo hero
- **Location:** `pos_4` (36–52), `pos_5` (54–70). BKB appears only in the core `pos_2`/`pos_3` lists (107).
- **Current behavior:** Support Lion buys Glimmer/Force/Greaves/Pipe but never a situational BKB.
- **Problem:** Lion must survive to channel a full combo; vs heavy disable/burst lineups a late BKB dramatically raises combo reliability. Its absence from the support lists removes that option entirely.
- **Proposed change:** Add `item_black_king_bar` as a late/situational entry in `pos_4` and `pos_5` (after core utility). Consider `item_aghanims_shard` for `pos_5` too (multi-target Mana Drain sustain).
- **Priority:** P2
- **How to validate:** A/B vs a disable/burst-heavy enemy comp; combos-completed and win rate.

---

## Items confirmed correct (no action)

- **Finger base + scepter damage math** (`ConsiderR` 830–835): `475+125*LV` and scepter `575+125*LV` (+100) match d2vpkr. `GetAbilityRDamageBonus` reads `damage_per_kill` and the per-kill talent dynamically. Good.
- **Linken's / Lotus / Aeon-active / spell-block handling** on Finger via `CanCastAbilityROnTarget` → `J.CanCastOnTargetAdvanced` (1006–1047). Finger won't be fed into an active Linken/Lotus. (Aeon *proc* prediction is the only gap — see item 9.)
- **`WillMagicKillTarget`** (jmz_func 1110–1155) correctly applies magic resist (`GetActualIncomingDamage`), spell amp, health regen over delay, and special cases (Medusa shield, Refraction, Bristleback, Ghost Ship). Kill estimates are trustworthy.
- **Aegis / Tempest Double** excluded from Finger targets (1017–1028). Good.
