# Zeus (`zuus`) — Bot Logic Review & Improvement Backlog

**File reviewed:** `bots/BotLib/hero_zuus.lua` (745 lines)
**Ability handles (read from file + `spell_list.lua`):**
`abilityQ = zuus_arc_lightning`, `abilityW = zuus_lightning_bolt`, `abilityE = zuus_heavenly_jump`,
`abilityD = zuus_cloud` (Nimbus, scepter), `abilityAS = zuus_lightning_hands` (Static Field passive),
`abilityR = zuus_thundergods_wrath`.

## Overall assessment

The kit wiring is correct and the ult is appropriately *conservative* — it will not blow on a full-HP team, which is the most common bad-bot failure. The biggest gaps are (1) the ult's damage estimate wrongly credits Static Field to global/off-screen targets and never fires as a team-fight AoE finisher, (2) Lightning Bolt has no stand-alone kill-secure / weakest-target logic and no reveal-invis use, and (3) the item build omits Aether Lens even though the code already implements Aether cast-range handling (dead code), and lists BKB in *both* the buy list and the sell list. None of these are nil-handle crashes; they are threshold/targeting/build logic that should move win rate.

Priorities: **P0** = clear bug / big impact, **P1** = solid improvement, **P2** = polish. Items marked *(verify in-game)* need a runtime or Liquipedia check per project rules.

---

## P0 / P1 — Ult (Thundergod's Wrath)

### 1. Static Field damage is credited to *global* ult targets (over-estimates lethality)
- **Location:** `X.ConsiderR()`, lines 605–635 (specifically line 614: `local nEstDamage = nDamage + e:GetHealth() * abilityASBonus`).
- **Current behavior:** For every enemy hero in `GetUnitList(UNIT_LIST_ENEMY_HEROES)` (whole map), it adds `e:GetHealth() * abilityASBonus` (Static Field, `abilityASBonus = 0.09`) on top of the raw ult damage before the kill check `J.WillMagicKillTarget(...)`.
- **Problem:** Static Field only damages enemies within its radius (~1200) of Zeus at cast time. Thundergod's Wrath is *global*, so the enemies you most want to snipe (fleeing/far away) get **no** Static Field damage. Crediting 9%-of-HP bonus to those targets over-estimates damage → the bot casts the ult expecting a kill it cannot actually land → wasted global cooldown. This is the classic "why did Zeus ult and not kill anyone" failure.
- **Proposed change:** Only add the Static Field term for enemies actually inside Static Field range of the bot, e.g. `local bInStatic = GetUnitToUnitDistance(bot, e) <= 1200; local nEstDamage = nDamage + (bInStatic and e:GetHealth() * abilityASBonus or 0)`. (Confirm the real Static Field radius/scaling from the ability's special values rather than the hardcoded 1200/0.09.)
- **Priority:** P1
- **Validate:** Count ult casts that produce ≥1 kill vs. ult casts that kill nobody (A/B log). Expect the wasted-ult rate to drop; ult kills/game to hold or rise.

### 2. Ult never fires as a team-fight AoE finisher (too passive in fights)
- **Location:** `X.ConsiderR()`, lines 595–635. The only non-kill triggers are `nInvUnit >= 5` (line 599) and the Warlock fatal-bonds combo (lines 621–632); otherwise it needs `lowHPCount >= 1` (a guaranteed single kill, line 631).
- **Current behavior:** If three enemies are at ~40–50% in a committed fight but none is individually killable by the raw ult, `lowHPCount` stays 0 and the ult is held.
- **Problem:** A strong Zeus ults committed team fights for the massive multi-target burst + true-sight reveal even without a pre-guaranteed kill; the AoE damage frequently *creates* the kills (allies finish). Current logic leaves the signature swing button unused in exactly the spots it wins fights.
- **Proposed change:** Add a branch: if `J.IsInTeamFight(bot, 1400)` and (allies committed, e.g. `#J.GetNearbyHeroes(bot,1400,false,BOT_MODE_ATTACK) >= 2`) and there are `>= 2` non-magic-immune enemy heroes below ~45% HP visible → return `BOT_ACTION_DESIRE_MODERATE`. Keep it gated on *visible* enemies and on allies actually fighting so it does not fire into a lost/empty fight.
- **Priority:** P1
- **Validate:** Team-fight win rate and ult casts-per-fight in multi-hero engagements; hero-damage/game should rise without a spike in "ult, then Zeus dies with nothing to show."

### 3. Kill check trusts last-known HP of off-screen enemies
- **Location:** `X.ConsiderR()`, lines 608–630 (`GetUnitList(UNIT_LIST_ENEMY_HEROES)` + `J.WillMagicKillTarget` on `e:GetHealth()`).
- **Current behavior:** Iterates all enemy heroes map-wide; for unseen enemies `GetHealth()` returns the last observed value.
- **Problem:** Two-sided: the ult can fire on a target that was low when last seen but has since healed at fountain (waste), or skip a target now lower than last seen. The "snipe a known-low fleeing enemy" case is *desired* and should stay, but a fountain-healed stale value is pure waste.
- **Proposed change:** For the kill-secure count, require the target to be either currently visible (`e:CanBeSeen()`) or recently seen/damaged (e.g. `bot:WasRecentlyDamagedByHero` is not applicable here — instead track "seen within N seconds"), and skip enemies sitting in/near their fountain. At minimum guard against `e:HasModifier('modifier_fountain_...')`-style safe states. *(verify in-game which HP the API reports for unseen heroes.)*
- **Priority:** P1 *(verify)*
- **Validate:** Log ult casts where the named target survives at >60% HP after cast (indicates stale-HP waste); expect near zero after the guard.

### 4. `nCastRange = 1600` is dead in the ult; no Refresher/second-ult logic
- **Location:** `X.ConsiderR()`, line 576 (`nCastRange = 1600` never used); no Refresher handling anywhere.
- **Current behavior:** Cosmetic dead local; ult treated as global (correct). No awareness of Refresher Orb / Refresher Shard for a double Thundergod's.
- **Problem:** Minor. Refresher is off Zeus's default build (not in `sRoleItemsBuyList`), so double-ult logic is low value today.
- **Proposed change:** Drop the dead local. Only add Refresher logic if a Refresher build is introduced (hold second ult for the second wave of kills). 
- **Priority:** P2

---

## P1 — Lightning Bolt (W) target selection

### 5. No stand-alone kill-secure / weakest-target branch for W
- **Location:** `X.ConsiderW()`, lines 389–425. Kill logic only exists implicitly via `J.IsGoingOnSomeone` → `J.GetProperTarget` (lines 406–416) and the ranged-creep branch (lines 418–423).
- **Current behavior:** When "going on someone," W is cast on `GetProperTarget(bot)` — the bot's *current attack target* — with no HP/kill comparison. There is no top-level "an enemy in range is killable by W → cast" branch (Q has one at lines 283–292 for HP ≤ 0.2; W, the bigger nuke, has none).
- **Problem:** W is Zeus's premier single-target finisher and can secure kills well above 20% HP. Casting it on whatever the bot happens to be attacking (which may be a full-HP tank) instead of the lowest-HP / actually-killable enemy in range wastes the nuke and misses kills the bot could lock in.
- **Proposed change:** Before the `IsGoingOnSomeone` branch, iterate enemy heroes in cast range and, if `J.WillMagicKillTarget(bot, e, nDamage + (inStatic and e:GetHealth()*abilityASBonus or 0), nCastPoint)` for the lowest-HP such target, cast W on it (`BOT_ACTION_DESIRE_HIGH`). Then, in the offense branch, prefer `J.GetVulnerableWeakestUnit(bot,true,true,nCastRange)` over `GetProperTarget` when it is killable/lower.
- **Priority:** P1
- **Validate:** W-casts-that-secure-a-kill per game; kills stolen-by-death-timer / "W hit full-HP hero then Zeus had no follow-up" should drop.

### 6. W never used to reveal invisible / just-blinked enemies (true sight wasted)
- **Location:** `X.ConsiderW()` (389–425) and `X.ConsiderW2()` (428–526). `ConsiderW2` only ground-casts for AoE-kill (446–456), channel interrupts (458–470), retreat AoE (472–480) and proper-target (483–523).
- **Current behavior:** No logic to ground-cast W at the last-known location of a hero that just went invisible / blinked away, despite W granting true sight + a mini-stun there.
- **Problem:** Losing tempo vs. invis heroes (Riki, Clinkz, Weaver, blink escapes) is a known bot weakness; Zeus is one of the few heroes with a cheap reveal. Not exploiting it forfeits kills and safety.
- **Proposed change:** Add a low/moderate-desire branch in `ConsiderW2`: if an enemy hero was visible within the last ~1–2s, is now `not CanBeSeen()`/invisible, and its last location is in range, ground-cast W there. Gate on mana so it is not spammed. *(verify value in-game — API access to "last seen location" may be limited; may need to cache positions each frame.)*
- **Priority:** P2 *(verify)*
- **Validate:** Kills/assists on invis-heavy enemy lineups; deaths to un-revealed gankers.

---

## P1 — Item build (`sRoleItemsBuyList`)

### 7. Aether Lens missing from mid/carry builds — and the code already handles it (dead code)
- **Location:** Item lists lines 35–91 (`pos_2`, `pos_1`); Aether handling at lines 196–197 (`local aether = J.IsItemAvailable("item_aether_lens"); if aether ~= nil then aetherRange = 250 end`).
- **Current behavior:** `aetherRange` is computed and intended to extend cast ranges, but **no build ever buys `item_aether_lens`**, so `aetherRange` is permanently 0 and the handling is dead. (Compare `hero_lion.lua` `pos_2`, which does buy `item_aether_lens`.)
- **Problem:** Aether Lens is near-core on Zeus: +250 cast range dramatically improves Bolt/Arc/Nimbus safety and the ult-adjacent poke range, plus mana. Omitting it is a clear build weakness *and* leaves implemented logic unused.
- **Proposed change:** Insert `item_aether_lens` into `pos_2` and `pos_1` early-mid (e.g. after `arcane_boots`/before the Kaya line). Confirm `ConsiderW`/`ConsiderQ` add `aetherRange` to their `nCastRange` (currently `ConsiderW`/`ConsiderQ` do **not** add `aetherRange` — Lion's consider functions do). Wire `aetherRange` into the W/Q/Nimbus cast-range calcs so the item's benefit is actually modeled.
- **Priority:** P1
- **Validate:** GPM/XPM and kill participation on mid Zeus with vs. without Aether; effective cast range in logged casts.

### 8. BKB is in the buy list *and* the sell list (self-contradiction)
- **Location:** Buy: `pos_2` line 47, `pos_1` line 83 (`item_black_king_bar`). Sell: `X['sSellList']` lines 127–132 (`"item_black_king_bar"`).
- **Current behavior:** The build purchases BKB, while `sSellList` (auto-sold when inventory is full, per `item_purchase_generic.lua`) lists BKB for sale.
- **Problem:** Risks auto-selling a just-purchased BKB when the 6-slot inventory fills, or churn. Looks like a copy-paste from a support file where BKB was never bought (`hero_lion.lua` has the same `sSellList` but does not buy BKB in most slots).
- **Proposed change:** Remove `item_black_king_bar` from Zeus's `sSellList` (Zeus's own build wants to keep it). Leave `quelling_blade`.
- **Priority:** P1 *(verify sSellList semantics against `item_purchase_generic.lua`)*
- **Validate:** Confirm BKB is retained through late game in test matches (inventory audit).

### 9. `moon_shard` on a spell-caster mid is low value
- **Location:** `pos_2` line 51, `pos_1` line 87, and other slots.
- **Current behavior:** Late build includes `item_moon_shard` (attack speed).
- **Problem:** Zeus scales with spell damage/cast; attack speed is marginal except for a pure right-click late game. A slot better spent on Bloodstone/Refresher/Shiva's/Wind Waker.
- **Proposed change:** Replace `moon_shard` with a spell item (e.g. `item_bloodstone` for mana/spell-lifesteal, or `item_wind_waker`/`item_shivas_guard`), or move it to the very tail as a filler.
- **Priority:** P2
- **Validate:** Late-game hero-damage share and survivability.

### 10. Consider a Bloodstone / mana-sustain core; treads+null tempo option
- **Location:** `pos_2` / `pos_1` (35–91).
- **Current behavior:** Core is `arcane_boots → phylactery → kaya_and_sange → travel_boots → bkb → scepter`. No Bloodstone; boots go Arcane→Travel.
- **Problem:** Modern Zeus mid frequently runs Bloodstone (mana + spell lifesteal + HP survivability) and, in tempo builds, Power Treads + Null Talisman(s) early (see `hero_lion.lua` `pos_2`). The current line is serviceable but omits Zeus's best sustain item.
- **Proposed change:** Offer a Bloodstone path and/or early `item_null_talisman`; keep Travel Boots for global split. This is a playstyle change — validate rather than assume.
- **Priority:** P2
- **Validate:** A/B win rate Bloodstone-line vs. current Kaya-and-Sange line.

---

## P2 — Arc Lightning (Q), Heavenly Jump (E), Nimbus (D)

### 11. Q snipe uses a fixed `HP <= 0.2` instead of a real kill check
- **Location:** `X.ConsiderQ()`, lines 283–292 (`J.GetHP(npcEnemy) <= 0.2`).
- **Current behavior:** Fires Q on any enemy hero at ≤20% HP; ignores magic resist / regen / actual Arc damage.
- **Problem:** Sometimes Q kills targets above 20% (low-MR squishies) and sometimes not at 20% (high-MR/regen). A percentage gate mis-fires both ways.
- **Proposed change:** Use `J.WillMagicKillTarget(bot, npcEnemy, nDamage, nCastPoint)` (as the ult and Lion's Q do) for the snipe decision; keep a cheap-mana guard so Arc harass stays available.
- **Priority:** P2
- **Validate:** Q last-hit-kills on heroes; mis-fires (Q cast, hero lives >30%) should drop.

### 12. No dedicated lane-harass Q on the enemy hero
- **Location:** `X.ConsiderQ()` laning branch, lines 296–310 (only last-hits lane creeps).
- **Current behavior:** In lane, Q is used for creep last-hits and (via `IsGoingOnSomeone`) aggression, but not for value harass when the Arc chain would hit both a creep and the enemy hero.
- **Problem:** Zeus's lane pressure comes from chip harass; leaving it out cedes lane control vs. a human-tuned bot.
- **Proposed change:** Add a laning branch: if an enemy hero is within Arc chain range of a nearby creep and mana allows (`J.IsAllowedToSpam`/`GetManaAfter`), cast Q for the harass. Keep it mana-gated so it does not leave Zeus manaless for a kill.
- **Priority:** P2
- **Validate:** Lane XPM/GPM diff and enemy-hero HP pressure in laning phase.

### 13. Heavenly Jump engage does not verify jump direction
- **Location:** `X.ConsiderE()`, lines 728–737 (engage branch) — cast as no-target `ActionQueue_UseAbility(abilityE)` in `SkillsComplement` (line 265).
- **Current behavior:** On `IsGoingOnSomeone` with a target in range it jumps; the retreat branch checks `not bot:IsFacingLocation(targetHero, 120)`, but the engage branch has no facing check.
- **Problem:** Heavenly Jump moves Zeus in his facing/move direction; if he is not facing the target when the desire triggers, he can jump the wrong way. Usually fine while chasing (he faces the target), but risky when the action queue orders the jump before re-facing.
- **Proposed change:** Gate the engage jump on `bot:IsFacingLocation(target:GetLocation(), 45)` (or issue a face/move-toward before the jump). *(verify in-game how the jump resolves direction from the queued action.)*
- **Priority:** P2 *(verify)*
- **Validate:** Watch replays for "jumped away from the fight" incidents.

### 14. Nimbus placement is basic
- **Location:** `X.ConsiderD()`, lines 528–568 (ally-target extrapolated location, or self-location on retreat).
- **Current behavior:** Places Nimbus on an ally's gank target's extrapolated position, or on Zeus's own location when retreating.
- **Problem:** Fine baseline. Nimbus is strongest on stationary/channeling targets and on chokes; the extrapolated-location cast can miss mobile targets.
- **Proposed change:** Prefer placing on a channeling/disabled enemy or a low-mobility target; otherwise keep current behavior. Low value relative to the ult/W fixes.
- **Priority:** P2

---

## P2 — Talents & code hygiene

### 15. `talentDamage` (talent8) is computed but never used
- **Location:** Declared line 174, reset line 187, set line 199 (`if talent8:IsTrained() then talentDamage = talentDamage + talent8:GetSpecialValueInt("value") end`). No other reference in the file.
- **Current behavior:** Dead variable — talent8's bonus is never added to any Q/W/R kill calculation. (Also, `talent8 = sTalentList[8] = t25-right`, which the default talent build does **not** train, so it is doubly moot today.)
- **Problem:** Latent bug: if the talent build ever picks t25-right, kill estimates would silently ignore its damage. Signals the damage-talent wiring was left half-done.
- **Proposed change:** Either remove `talentDamage` entirely, or actually add it into the relevant damage figure (mirror how `talent5` is folded into `nDamage` in `ConsiderR`, lines 579–581). Decide based on what t25-right actually does. *(verify talent effect on Liquipedia.)*
- **Priority:** P2

### 16. Verify each talent tier picks the stronger side — especially t25-left flipping W to a ground cast
- **Location:** `tTalentTreeList` lines 11–16; consumed via `J.Skill.GetTalentBuild` (`aba_skill.lua` 135–150). Resolved picks: t10-right, t15-left, t20-left (`talent5`, ult-damage), t25-left (`talent7`).
- **Current behavior:** `talent7 = sTalentList[7] = t25-left` is trained by the default build, and `ConsiderW` (line 219) / `SkillsComplement` (lines 219–224) switch Lightning Bolt to a **location** cast whenever `talent7:IsTrained()`.
- **Problem:** If t25-left is genuinely the talent that gives Lightning Bolt an area/secondary effect, ground-casting is correct. If it is something unrelated (e.g. a flat stat talent), then location-casting W degrades targeting (no unit lock, easier to miss a moving hero). The mapping is subtle and the `{0,10}` convention in the file vs. the `GetTalentBuild` formula is easy to misread.
- **Proposed change:** Confirm on Liquipedia/d2vpkr what t20-left (`talent5`) and t25-left (`talent7`) actually are; ensure (a) `talent5` really is the Thundergod's Wrath damage talent it is treated as, and (b) `talent7` really warrants ground-casting W. Correct the tier picks if the stronger talent is on the other side.
- **Priority:** P1 *(verify — talent effects)*
- **Validate:** Kill/damage output with the confirmed talent line.

### 17. `nManaPercentage` / `nHealthPercentage` leak as globals
- **Location:** `X.SkillsComplement()`, lines 192–193 (assigned without `local`; `nMP`/`nHP` on 190–191 are the proper locals). Used in `ConsiderW2` (491, 501, 514) and `ConsiderR` (589).
- **Current behavior:** Works, but the two values are global (only whitelisted-away in luacheck).
- **Problem:** Hygiene only; risk of cross-file collision is low but real in a shared VM.
- **Proposed change:** Make them `local` (they duplicate `nMP`/`nHP` anyway — consider collapsing to one pair).
- **Priority:** P2

---

## Quick reference — priority summary

| # | Area | Title | Priority |
|---|------|-------|----------|
| 1 | Ult | Static Field wrongly credited to global targets | P1 |
| 2 | Ult | No team-fight AoE finisher branch | P1 |
| 3 | Ult | Trusts stale HP of off-screen enemies | P1 *(verify)* |
| 5 | W | No stand-alone kill-secure / weakest-target | P1 |
| 7 | Items | Aether Lens missing (dead cast-range code) | P1 |
| 8 | Items | BKB in buy list AND sell list | P1 *(verify)* |
| 16 | Talents | Verify t25-left justifies ground-casting W | P1 *(verify)* |
| 6 | W | No reveal-invis ground cast | P2 *(verify)* |
| 9/10 | Items | Moon Shard weak; add Bloodstone line | P2 |
| 11/12 | Q | Real kill check; add lane harass | P2 |
| 13 | E | Jump direction not verified on engage | P2 *(verify)* |
| 14 | Nimbus | Placement polish | P2 |
| 15/17 | Code | `talentDamage` dead; global leaks | P2 |
| 4 | Ult | Dead `nCastRange`; Refresher n/a | P2 |
