----------------------------------------------------------------------------------------------------
--- The Creation Come From: BOT EXPERIMENT Credit:FURIOUSPUPPY
--- BOT EXPERIMENT Author: Arizona Fauzie 2018.11.21
--- Link:http://steamcommunity.com/sharedfiles/filedetails/?id=837040016
--- Refactor: 决明子 Email: dota2jmz@163.com 微博@Dota2_决明子
--- Link:http://steamcommunity.com/sharedfiles/filedetails/?id=1573671599
--- Link:http://steamcommunity.com/sharedfiles/filedetails/?id=1627071163
----------------------------------------------------------------------------------------------------
local X = {}
local bot = GetBot()

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Minion = dofile( GetScriptDirectory()..'/FunLib/aba_minion' )
local sTalentList = J.Skill.GetTalentList( bot )
local sAbilityList = J.Skill.GetAbilityList( bot )
local sRole = J.Item.GetRoleItemsBuyList( bot )

local tTalentTreeList = {
							['t25'] = {0, 10},
							['t20'] = {10, 0},
							['t15'] = {10, 0},
							['t10'] = {10, 0},
}


-- ABILITY INDEX MAP -- re-anchored 2026-08-22 against the live Dota 2 datafeed
-- (https://www.dota2.com/datafeed/herodata?language=english&hero_id=42), because
-- the map that used to sit here named an ability the game no longer has.
--
-- These numbers index sAbilityList, which J.Skill.GetAbilityList builds by walking
-- the ability slots and SKIPPING innates; the ultimate is forced to index 6.  For
-- Wraith King that yields:
--
--   1 = skeleton_king_hellfire_blast  Wraithfire Blast -- the only lockdown.
--                                     525 cast range, 95/110/125/140 mana,
--                                     14/12/10/8s cd, 80/100/120/140 impact
--                                     damage plus a 2s dot worth 20/40/60/80 PER
--                                     SECOND (the feed's heading on
--                                     blast_dot_damage is "DAMAGE PER SECOND", so
--                                     the dot totals 40/80/120/160 and the whole
--                                     cast is worth 120/180/240/300), -20% move
--                                     slow for those 2s, 1.0/1.2/1.4/1.6s stun.
--   2 = skeleton_king_bone_guard      Bone Guard -- an ACTIVE, no-target skeleton
--                                     release: 70/80/90/100 mana, flat 42s cd,
--                                     2/4/6/8 max charges, 34/39/43/49 skeleton
--                                     damage, skeletons last 40s and carry +25
--                                     bonus damage to heroes.  It is NOT
--                                     lifesteal.
--   3 = skeleton_king_mortal_strike   Mortal Strike -- passive crit / skeletons.
--   6 = skeleton_king_reincarnation   220/110/0 mana, 180/150/120s cd.
--
-- The lifesteal costs no skill point.  CORRECTED 2026-08-23 -- the sentence that
-- used to stand here ("skeleton_king_vampiric_spirit is flagged INNATE by the
-- datafeed, so GetAbilityList drops it") was wrong in both halves, and the same
-- shape of sentence is load-bearing in four other focus files:
--   * THE NAME.  The engine does not use the feed's name.  Every WK frame in
--     tests/fixtures/ that dumps an ability array carries
--     skeleton_king_INNATE_vampiric_spirit -- 31 of 31 -- and the feed's
--     skeleton_king_vampiric_spirit appears on 0.  Lion is identical
--     (lion_innate_to_hell_and_back 22/22 vs the feed's lion_to_hell_and_back 0).
--     A name read off the datafeed is not a name you may match an engine ability
--     against; the feed is still authoritative for VALUES.
--   * THE MECHANISM.  J.Skill.GetAbilityList reads no innate flag -- the bot API
--     has none.  It drops an ability only when NOT_LEARNABLE **and**
--     ability:IsHidden() are both true, and nothing offline here can evaluate
--     IsHidden.  The word "innate" in that function lives in a commented-out
--     warning ("e.g. innate like"), which is where the story came from.
-- What survives: WK's build rows spend no point on it either way, because they
-- only ever name indices 1,2,3,6 -- and this file binds by hardcoded name, not by
-- index at all, so an innate landing at index 4 could not reach it.  Zeus and
-- Crystal Maiden DO bind index 4/5; see tests/test_focus_innate_index_anchor.lua.
-- Two other names that are not in the game's ability set any more:
-- skeleton_king_vampiric_aura (what this block said before 2026-08-22) and
-- skeleton_king_spectral_blade (see abilityW).
local tAllAbilityBuildList = {
							{2,1,2,3,2,6,2,3,3,3,6,1,1,1,6},--pos1,3
}

-- [GH #17] Kill-participation laning build (gated). WK is a focus hero but bottom
-- of the pool on kills (0.6/game): the default build above leaves Wraithfire Blast
-- (index 1, the only lockdown) at a SINGLE point until level 13, so WK has no
-- reliable stun through the entire laning + early-gank window. This build instead
-- takes the 2nd stun point at level 5 (much longer lockdown when kills actually
-- happen) and still maxes Mortal Strike (index 3) by level 8 for farm/fight damage.
-- Gated turbo + soak-candidate 'wkbuild' so it stays inert until an A/B win
-- promotes it.
--
-- NOTE (2026-08-22, re-anchor): the rationale recorded here when the gate was
-- written said the remaining points were kept in "Vampiric Aura (W) for lane
-- sustain".  That was wrong on the facts: index 2 is Bone Guard, an active
-- skeleton release, and the lifesteal is innate and free.  So what this build
-- actually trades away is Bone Guard uptime, not sustain -- both build rows spend
-- 4 points there, this one just spends them later (1/9/11/13 vs 1/3/5/7, HERO
-- LEVELS and not row indices: levels 10 and 15 go on talents, GH #134).
--
-- CONDITION (c), RE-ARGUED 2026-08-22 on that corrected basis (GH #17 / #104).
-- A Bone Guard point buys two things: max_skeleton_charges 2/4/6/8 and skeleton
-- damage 34/39/43/49.  The cap is the load-bearing half, and under THIS file's own
-- release rule a higher cap is a COST, not a benefit.  X.ConsiderW fires on
--
--     branch 1   nStack / maxStack >= 0.6   ->  1.2 / 2.4 / 3.6 / 4.8 charges
--     branch 2   nStack == maxStack         ->    2 /   4 /   6 /   8 charges
--
-- and the only term that can bypass either test is `talent6:IsTrained()`, which
-- section 2 of tests/test_wk_fact_anchor.lua shows is a level-20 test and which
-- the GH #84 census read on 0 of 210 turbo hero-slots.  (That bypass is NOT a
-- defect, checked 2026-08-23: the talent at that slot is "+5 Bone Guard
-- Skeletons Spawned" over a base min_skeleton_spawn of 0, so with it trained a
-- release from an empty bank still fields five skeletons and "release regardless
-- of the bank" is the right rule.  tests/test_wk_bone_guard_talent_bypass.lua
-- section 1.)  So in turbo every early
-- point in Bone Guard raises, monotonically and on both branches, the bank WK has
-- to accumulate before he will release any skeletons at all.  The default row has
-- all four points down by level 7: from level 7 on it asks an 8-charge bank of the
-- hero the batch reads at 15 last hits and 0.6 kills a game.  This row leaves him
-- at cap 2 for the whole laning phase, which is a bank he can actually reach, and
-- spends the freed points on the only lockdown he has -- 2nd Wraithfire Blast
-- point at level 5 instead of 13 (stun 1.0 -> 1.2s, cooldown 14 -> 12s) -- and on
-- maxing Mortal Strike at 8 instead of 11.  (Every level in this paragraph is a
-- HERO level read out of J.Skill.GetSkillList, not a build-row index; the two
-- differ from level 10 on, GH #134.  tests/test_focus_level_claims.lua pins them.)
--
-- Two bounds this argument does NOT clear, recorded so nobody quotes it as more:
--   * it fixes the SIGN, not the size.  How large a bank WK actually holds between
--     releases is a corpus question and it cannot be asked offline -- the dumper
--     does not record modifier stack counts (same gap family as GH #27).
--   * a higher cap also raises the PAYLOAD per release (8 skeletons at 49 damage
--     against 2 at 34).  The claim here is only that the frequency loss is
--     automatic under the shipped rule while the payload gain is conditional on a
--     charge supply nobody has measured.
-- tests/test_wk_bone_guard_thresholds.lua drives the sign half on shipped code.
local tKillBuildList = {
							{2,1,3,3,1,6,3,3,2,2,6,2,1,1,6},--pos1,3, earlier 2nd stun
}

local nAbilityBuildList
if J.IsModeTurbo() and J.IsSoakCandidate( 'wkbuild' ) then
	nAbilityBuildList = J.Skill.GetRandomBuild( tKillBuildList )
else
	nAbilityBuildList = J.Skill.GetRandomBuild( tAllAbilityBuildList )
end

local nTalentBuildList = J.Skill.GetTalentBuild( tTalentTreeList )

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_1'] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_gauntlets",
	"item_quelling_blade",

	"item_magic_wand",
	"item_phase_boots",
	"item_armlet",
	"item_radiance",--
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",--
	"item_assault",--
	"item_ultimate_scepter",
	"item_overwhelming_blink",--
	"item_ultimate_scepter_2",
	"item_abyssal_blade",--
	"item_travel_boots",
	"item_moon_shard",
	"item_refresher",--
	"item_travel_boots_2",--
}

sRoleItemsBuyList['pos_3'] = {
	"item_tango",
	"item_quelling_blade",
	"item_gauntlets",
	"item_magic_stick",
	-- GH #136: this line used to be a SINGLE "item_branches" and Magic Wand
	-- takes TWO.  The purchase layer cannot recover the missing one: when the
	-- target becomes item_magic_wand, Item.GetBasicItems drops every component
	-- already owned, _buildRequiredCounts then counts requirements off that
	-- ALREADY-FILTERED list (so branches: required 1, owned 1) and _stillNeeds
	-- pops it as satisfied.  The recipe -- the one component not yet owned --
	-- is the only thing bought, which is exactly the 40/40 end-game inventory
	-- observed in run_001140: magic_stick + ONE branch + recipe_magic_wand and
	-- no wand, ever, in any game.  Median unspent gold 4007 against 366-487
	-- for the other nine heroes in the same mirrored games.
	"item_double_branches",

	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_radiance",--
	"item_blink",
	"item_black_king_bar",--
	"item_ultimate_scepter",
	"item_assault",--
	"item_aghanims_shard",
	"item_overwhelming_blink",--
	"item_refresher",--
	"item_ultimate_scepter_2",
	"item_nullifier",--
	"item_travel_boots_2",--
	"item_moon_shard",
}

sRoleItemsBuyList['pos_2'] = sRoleItemsBuyList['pos_3']

sRoleItemsBuyList['pos_4'] = sRoleItemsBuyList['pos_3']

sRoleItemsBuyList['pos_5'] = sRoleItemsBuyList['pos_3']

X['sBuyList'] = sRoleItemsBuyList[sRole]

X['sSellList'] = {

	"item_black_king_bar",
	"item_quelling_blade",

}

if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_tank' }, {"item_heavens_halberd", 'item_quelling_blade'} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )


X['bDeafaultAbility'] = true
X['bDeafaultItem'] = false

function X.MinionThink(hMinionUnit)

	if Minion.IsValidUnit( hMinionUnit )
		and hMinionUnit:GetUnitName() ~= "npc_dota_wraith_king_skeleton_warrior"
	then
		Minion.IllusionThink( hMinionUnit )
	end

end

--[[

npc_dota_hero_skeleton_king -- re-anchored 2026-08-22 from the live datafeed
(hero_id 42).  The block that used to sit here still named the 7.2x ability and
talent set; every line below was read off the feed, not carried forward.

abilities, in the order the feed lists them (the feed gives no "AbilityN" slot
numbers, so the old block's numbering is dropped rather than guessed at):

  skeleton_king_hellfire_blast
  skeleton_king_bone_guard
  skeleton_king_mortal_strike
  skeleton_king_vampiric_spirit     -- ability_is_innate: true, not learnable
                                    -- NB the ENGINE spells this
                                    -- skeleton_king_innate_vampiric_spirit
                                    -- (31/31 frames); the feed's spelling is on 0
  skeleton_king_reincarnation       -- the ultimate

talents, in the feed's order, ASSUMED to be ability-slot order -- which is the
order J.Skill.GetTalentList returns.  Two things corroborate it: the old block's
Ability17 was ..._unique_wraith_king_4 and that is still the last name here, and
index [6] below is the Bone Guard talent, which is exactly the handle X.ConsiderW
reads as `talent6`.  J.Skill.GetTalentBuild drives indices 1,2 from t10 / 3,4 from
t15 / 5,6 from t20 / 7,8 from t25, so an index alone tells you the tier, and THAT
part needs no assumption at all (tests/test_wk_fact_anchor.lua reads it out of
aba_skill.lua rather than asserting it):

  [1] special_bonus_unique_wraith_king_2          +% Vampiric Spirit lifesteal
  [2] special_bonus_unique_wraith_king_facet_1    +s Wraithfire Blast slow dur.
  [3] special_bonus_unique_wraith_king_11         +s Wraithfire Blast stun dur.
  [4] special_bonus_hp_300                        +300 health
  [5] special_bonus_attack_speed_50               +50 attack speed
  [6] special_bonus_unique_wraith_king_facet_3    + Bone Guard skeletons spawned
  [7] special_bonus_unique_wraith_king_10         -s Mortal Strike cooldown
  [8] special_bonus_unique_wraith_king_4          Reincarnation casts Wraithfire

tTalentTreeList above therefore resolves to [2] at t10, [4] at t15, [6] at t20 and
[7] at t25 ({10,0} takes the even/right index, {0,10} the odd/left one -- see
aba_skill.lua:135).  Only the t10 and t15 picks can ever be taken in turbo: the
level census behind GH #84 read level >= 20 on 0 of 210 hero-slots, high-water 19.

modifier_skeleton_king_bone_guard                 -- stack count = charges held
modifier_skeleton_king_hellfire_blast
modifier_skeleton_king_mortal_strike
modifier_skeleton_king_mortal_strike_summon
modifier_skeleton_king_mortal_strike_summon_thinker
modifier_skeleton_king_reincarnation
modifier_skeleton_king_reincarnate_slow
modifier_skeleton_king_reincarnation_scepter
modifier_skeleton_king_reincarnation_scepter_active

--]]

local abilityQ = bot:GetAbilityByName('skeleton_king_hellfire_blast')
-- Was seeded with 'skeleton_king_spectral_blade', a name that exists nowhere in
-- the game's ability set nor anywhere else in this repo, so it resolved to nil on
-- every load and the whole W path rode on the SkillsComplement fallback below.
-- Seeding it with the real name leaves that fallback in place and is a no-op for
-- every read of abilityW (the fallback re-fetches the same handle).
local abilityW = bot:GetAbilityByName('skeleton_king_bone_guard')
local abilityR = bot:GetAbilityByName('skeleton_king_reincarnation')
-- talent6 is sTalentList[6] = the t20 slot (aba_skill.lua:140).  Both places it is
-- read below are OR-bypasses, so in turbo -- where level 20 does not happen -- they
-- contribute nothing and the sibling stack test is the whole condition.  What they
-- mean when they DO become live: index 6 is "+5 Bone Guard Skeletons Spawned", a
-- flat floor, so the bypass buys "release even on an empty bank" and that is
-- coherent, not a bug.  One residual is registered rather than settled -- if the
-- engine only carries modifier_skeleton_king_bone_guard while charges >= 1, the
-- guard at the top of X.ConsiderW re-imposes the very ammunition test the bypass
-- lifts.  tests/test_wk_bone_guard_talent_bypass.lua sections 1 and 5.
local talent6 = bot:GetAbilityByName( sTalentList[6] )

local castQDesire, castQTarget
local castWDesire

local nMP, nHP, nLV, hEnemyHeroList

function X.SkillsComplement()


	if J.CanNotUseAbility( bot ) or bot:IsInvisible() then return end
    if not abilityW or abilityW:IsHidden() then abilityW = bot:GetAbilityByName('skeleton_king_bone_guard') end

	-- (a `nKeepMana = 160` used to be assigned here; nothing in this file, or any
	-- other, ever read it -- same dead reserve as the one cleared out of
	-- hero_lion.lua under GH #73.  WK's real mana reserve is X.ShouldSaveMana.)
	nLV = bot:GetLevel()
	nMP = bot:GetMana()/bot:GetMaxMana()
	nHP = bot:GetHealth()/bot:GetMaxHealth()
	hEnemyHeroList = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )


	castQDesire, castQTarget = X.ConsiderQ()
	if ( castQDesire > 0 )
	then

		J.SetQueuePtToINT( bot, false )

		bot:ActionQueue_UseAbilityOnEntity( abilityQ, castQTarget )
		return
	end

	castWDesire = X.ConsiderW()
	if ( castWDesire > 0 )
	then

		J.SetQueuePtToINT( bot, false )

		bot:ActionQueue_UseAbility( abilityW )
		return

	end

end

--- Absolute mana the Roshan branch of X.ConsiderQ demands before it will spend
--- Wraithfire Blast on Roshan.  Takes the blast's own cost so the two legs are
--- priced off the same number the branch is about to pay.
---
--- SHIPPED (no gate): a flat 600, and it is the wrong KIND of number.  The spell
--- it gates costs 95/110/125/140 (npc_dota_hero_skeleton_king.txt,
--- skeleton_king_hellfire_blast/AbilityManaCost, read 2026-08-26), so the floor is
--- 4.3x the price of one cast at rank 4.  Worse, it is absolute while the pool it
--- is drawn against is not: at every pre-scepter milestone in the shipped buy
--- lists the crossing pool is exactly 603 (tests/test_wk_roshan_mana_ceiling.lua
--- computes those milestones off the lists rather than typing them in), so 600 is
--- 99.5% OF THE POOL -- one blast drops him under it for the rest of the fight.
---
--- WIDENED (soak candidate 'wkrosh', turbo-only): the floor becomes "pay for the
--- blast and still hold the reincarnation mana".  That is not a number picked to
--- be smaller; it is THIS FILE'S OWN reserve rule.  X.ShouldSaveMana already
--- refuses any cast that would leave bot:GetMana() below abilityR:GetManaCost(),
--- and it is consulted on the first line of X.ConsiderQ -- but only while
--- Reincarnation is within 3.0s of ready.  A Roshan fight is precisely where that
--- window should be permanent, so the Roshan branch applies the same reserve
--- unconditionally instead of a constant that predates it.  Both sides scale with
--- rank: Reincarnation costs 220/110/0 (same file, AbilityValues/AbilityManaCost,
--- read 2026-08-26 -- rank 3 is FREE, which is why the armed floor collapses to
--- the blast's own price at level 16+), so the armed floor is 315/330 at R rank 1,
--- 235/250 at rank 2 and 95..140 at rank 3, against 600 either way today.
---
--- ONE-DIRECTIONAL BY CONSTRUCTION, not by today's arithmetic: the relative floor
--- is returned only when it is strictly BELOW the shipped one, so no future KV
--- edit can make the armed leg demand MORE mana than the shipped leg.  The lever's
--- whole claim is "this floor is too high"; a leg that could raise it would be
--- testing something nobody argued for.
---
--- WHY IT IS SAFE TO LOOSEN, AND WHAT IT COSTS (condition (c), argued not assumed)
---   * Nothing else in this file casts on Roshan.  The farming branch above
---     excludes him by name (not J.IsRoshan(targetCreep)) and every other branch
---     in X.ConsiderQ iterates hero lists, so this branch is the only Roshan path
---     -- it is not DOWNSTREAM-DOMINATED and it is not a duplicate of a sibling.
---   * Mana held during a Roshan fight has no competing spender: the bot is
---     standing in the pit hitting Roshan, and the one thing the mana IS needed
---     for -- coming back after a gank lands on the pit -- is exactly what the
---     reserve half of the new floor keeps.
---   * The cost is real and one-sided: a blast spent on Roshan is a blast not
---     available for the fight that starts 8-14s later (its cooldown), and the
---     shipped 600 buys that insurance by never firing.  This lever trades that
---     insurance for the damage; it does not claim the trade is free.
---   * Below level 6 abilityR is unlearned and what GetManaCost answers then is
---     an engine question this desk cannot settle.  It does not matter here in
---     practice (X.ShouldSaveMana is itself nLV >= 6, and a level-5 Wraith King in
---     BOT_MODE_ROSHAN is not a real frame), but a reader sizing this must not
---     assume the rank-1 220 is what arrives.
function X.GetRoshanManaFloor( nAbilityManaCost )

	local nShipped = 600

	if J.IsModeTurbo() and J.IsSoakCandidate( 'wkrosh' )
	then
		local nReserve = 0
		if abilityR ~= nil then nReserve = abilityR:GetManaCost() end
		local nRelative = nAbilityManaCost + nReserve
		if nRelative < nShipped then return nRelative end
	end

	return nShipped

end

function X.ConsiderQ()

	if not abilityQ:IsFullyCastable()
		or X.ShouldSaveMana( abilityQ )
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local nCastRange = abilityQ:GetCastRange()
	local nCastPoint = abilityQ:GetCastPoint()
	local nManaCost = abilityQ:GetManaCost()
	local nSkillLV = abilityQ:GetLevel()
	-- 100/140/180/220.  Re-anchored 2026-08-22 (SECOND pass -- the first pass got
	-- this wrong and the correction matters to the lever below).  blast_dot_damage
	-- is 20/40/60/80 but the datafeed heading on that field is "DAMAGE PER SECOND"
	-- and blast_dot_duration is 2, so the dot is worth 40/80/120/160, not
	-- 20/40/60/80.  That leaves nDamage as NEITHER honest number: the impact alone
	-- is 80/100/120/140 and the impact-plus-whole-dot is 120/180/240/300, and
	-- 100/140/180/220 sits between them.
	--
	-- It feeds a kill check below at nDamage * 1.68 = 168/235/302/370 CLAIMED
	-- magical damage.  At rank 4 that is 2.64x what lands on cast (140) and still
	-- 1.23x what the target loses if it stands in the dot to the very end (300).
	-- Registered as a lever, NOT changed here: narrowing it is a behaviour change
	-- and needs its own gate and its own real frame.  Whoever takes it has to pick
	-- the honest number first, and that is not free either -- the cast also brings
	-- a 1.0-1.6s stun and a -20% slow, which is exactly what decides whether the
	-- target is still standing in the dot when it expires.
	local nDamage = 40 * ( nSkillLV - 1 ) + 100
	local nDamageType = DAMAGE_TYPE_MAGICAL

	local allyList =  J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE )

	local nEnemysHerosInView = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )

	if #nEnemysHerosInView == 1
		and J.IsValidHero( nEnemysHerosInView[1] )
		and J.IsInRange( nEnemysHerosInView[1], bot, nCastRange + 350 )
		and nEnemysHerosInView[1]:IsFacingLocation( bot:GetLocation(), 30 )
		and nEnemysHerosInView[1]:GetAttackRange() > nCastRange
		and nEnemysHerosInView[1]:GetAttackRange() < 1250
	then
		nCastRange = nCastRange + 260
	end

	local nEnemysHerosInRange = J.GetNearbyHeroes(bot, nCastRange + 43, true, BOT_MODE_NONE )
	local nEnemysHerosInBonus = J.GetNearbyHeroes(bot, nCastRange + 330, true, BOT_MODE_NONE )

	--打断和击杀
	for _, npcEnemy in pairs( nEnemysHerosInBonus )
	do
		if J.IsValid( npcEnemy )
			and J.CanCastOnNonMagicImmune( npcEnemy )
			and J.CanCastOnTargetAdvanced( npcEnemy )
		then
			if npcEnemy:IsChanneling()
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end

			if GetUnitToUnitDistance( bot, npcEnemy ) <= nCastRange + 80
				and J.CanKillTarget( npcEnemy, nDamage * 1.68, nDamageType )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end

		end
	end

	--团战中对战力最高的敌人使用
	if J.IsInTeamFight( bot, 1200 )
	then
		local npcMostDangerousEnemy = nil
		local nMostDangerousDamage = 0

		for _, npcEnemy in pairs( nEnemysHerosInRange )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not J.IsDisabled( npcEnemy )
				and not npcEnemy:IsDisarmed()
			then
				local npcEnemyDamage = npcEnemy:GetEstimatedDamageToTarget( false, bot, 3.0, DAMAGE_TYPE_PHYSICAL )
				if ( npcEnemyDamage > nMostDangerousDamage )
				then
					nMostDangerousDamage = npcEnemyDamage
					npcMostDangerousEnemy = npcEnemy
				end
			end
		end

		if ( npcMostDangerousEnemy ~= nil )
		then
			return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy
		end
	end

	--对线期间对敌方英雄使用
	if bot:GetActiveMode() == BOT_MODE_LANING or nLV <= 5
	then
		for _, npcEnemy in pairs( nEnemysHerosInBonus )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not J.IsDisabled( npcEnemy )
				and J.GetAttackEnemysAllyCreepCount( npcEnemy, 1400 ) >= 4
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end


	--打架时先手
	if J.IsGoingOnSomeone( bot )
	then
		local npcTarget = J.GetProperTarget( bot )
		if J.IsValidHero( npcTarget )
			and J.CanCastOnNonMagicImmune( npcTarget )
			and J.CanCastOnTargetAdvanced( npcTarget )
			and J.IsInRange( npcTarget, bot, nCastRange + 80 )
			and not J.IsDisabled( npcTarget )
			and not npcTarget:IsDisarmed()
		then
			if nSkillLV >= 3 or nMP > 0.68 or J.GetHP( npcTarget ) < 0.38 or nHP < 0.25
			then
				return BOT_ACTION_DESIRE_HIGH, npcTarget
			end
		end
	end

	--撤退时保护自己
	if J.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( nEnemysHerosInRange )
		do
			if J.IsValid( npcEnemy )
				and ( bot:WasRecentlyDamagedByHero( npcEnemy, 5.0 )
						or nMP > 0.8
						or GetUnitToUnitDistance( bot, npcEnemy ) <= 400 )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not J.IsDisabled( npcEnemy )
				and not npcEnemy:IsDisarmed()
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end

	if J.IsFarming( bot )
		and nSkillLV >= 3
		and ( bot:GetAttackDamage() < 200 or nMP > 0.88 )
		and nMP > 0.71 and #hEnemyHeroList == 0
	then
		local nCreeps = bot:GetNearbyNeutralCreeps( nCastRange + 100 )

		local targetCreep = J.GetMostHpUnit( nCreeps )

		if J.IsValid( targetCreep )
			and bot:IsFacingLocation( targetCreep:GetLocation(), 46 )
			and ( #nCreeps >= 2 or GetUnitToUnitDistance( targetCreep, bot ) <= 400 )
			and not J.IsRoshan( targetCreep )
			and not J.IsOtherAllysTarget( targetCreep )
			and targetCreep:GetMagicResist() < 0.3
			and not J.CanKillTarget( targetCreep, bot:GetAttackDamage() * 1.68, DAMAGE_TYPE_PHYSICAL )
			and not J.CanKillTarget( targetCreep, nDamage, nDamageType )
		then
			return BOT_ACTION_DESIRE_HIGH, targetCreep
		end
	end

	--打肉的时候输出
	-- LEVER C, RE-MEASURED 2026-08-23 (hero stream).  The note that stood here
	-- said this branch was "unreachable in turbo whatever Roshan is doing".  THAT
	-- CONCLUSION IS WITHDRAWN; it rested on two errors, and both are corrected
	-- here rather than quietly deleted, because the old numbers have been quoted.
	--
	--   * ITEMS.  It claimed "no item ahead of item_ultimate_scepter in either buy
	--     list above grants intelligence".  Three do.  Iron Branch is +1 to all
	--     attributes EACH; MAGIC WAND -- entry 6 of pos_3 and entry 6 of pos_1, the
	--     first assembled item either list buys -- is +3 to ALL attributes; BRACER,
	--     entry 7 of pos_3, is +2 intelligence.  Scepter is +10 all attributes AND
	--     a flat +175 mana, which the old note also did not count.  (Values from
	--     odota dotaconstants 10.8.0, read 2026-08-23.)
	--   * ARITHMETIC.  Intelligence is FLOORED before it pays out at 12 mana a
	--     point: pool = 75 + 12*floor(16 + 1.4*(level-1) + item_int).  The floor is
	--     not cosmetic -- it is what makes the model reproduce 33 of the 34 real
	--     Wraith King frames in tests/fixtures exactly, the 34th being a known bad
	--     row named in tests/test_wk_roshan_mana_ceiling.lua.  Unfloored, the old
	--     note overstated the pool by up to 7 (502 vs 495 at level 15, 569 vs 567
	--     at 19, 586 vs 579 at 20).
	--
	-- First level whose FULL pool reaches 600, by what is in the bag:
	--     bare hero                        21     (the number the old note gave)
	--     magic wand (it eats the branches)19
	--     wand + bracer                    18     <- both shipped pos_3 entries
	--     + aghanim's scepter              every level from 1 (pool 622 at level 1)
	--
	-- GH #84's turbo level census reads level >= 20 on 0 of 210 hero-slots with a
	-- HIGH-WATER OF 19, so the shipped build reaches its crossing level in the tail
	-- of that distribution instead of never.  The branch is not arithmetically
	-- dead.  What IS wrong with it is narrower and survives the correction: at
	-- every pre-scepter milestone the crossing pool is exactly 603, so the 600
	-- floor demands 99.5% OF THE POOL, and one Wraithfire Blast (95/110/125/140)
	-- drops him under it for the rest of the Roshan fight.  An absolute floor 4.3x
	-- the cost of the spell it gates is the defect; the level was never the point.
	--
	-- WRITTEN 2026-08-26, GATED (`wkrosh`, turbo-only, unarmed) -- the shape the
	-- 2026-08-23 round registered for it ("absolute 600 -> a relative floor that
	-- still leaves the reincarnation mana behind").  The floor now comes out of
	-- X.GetRoshanManaFloor below; read the argument there.  What has NOT changed
	-- is the domain: GetActiveMode is bot-VM state, not entity state, so it is in
	-- no .dem (13th world assertion, tests/test_activemode_world_assertion.lua) and
	-- this comparison is constant FALSE on every archived frame -- a fact about the
	-- harness, not a frequency.  Sizing still needs the positional proxy asked for
	-- as queue hero-10; do NOT read a fixture-driven zero here as an empty domain.
	if bot:GetActiveMode() == BOT_MODE_ROSHAN
		and bot:GetMana() >= X.GetRoshanManaFloor( nManaCost )
	then
		local npcTarget = bot:GetAttackTarget()
		if J.IsRoshan( npcTarget )
			and not J.IsDisabled( npcTarget )
			and not npcTarget:IsDisarmed()
			and J.IsInRange( npcTarget, bot, nCastRange )
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget
		end
	end

	--受到伤害时保护自己
	if bot:WasRecentlyDamagedByAnyHero( 3.0 )
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and not bot:IsInvisible()
		and #nEnemysHerosInRange >= 1
		and nLV >= 6
	then
		for _, npcEnemy in pairs( nEnemysHerosInRange )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not J.IsDisabled( npcEnemy )
				and not npcEnemy:IsDisarmed()
				and bot:IsFacingLocation( npcEnemy:GetLocation(), 45 )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end

	--通用消耗敌人或受到伤害时保护自己
	-- PRE-FLIGHT DONE, CANDIDATE NOT WRITTEN (hero stream, 2026-08-22, queue.json
	-- hero-1).  The proposal was `wkqaim`: this branch takes nEnemysHerosInRange[1]
	-- and that list is distance-sorted, so it casts on the NEAREST enemy while the
	-- branches above it each express a preference (killability, biggest threat).
	-- Give it one too -- prefer the lowest-health enemy in the ring.  Two reasons it
	-- was not written; tests/test_wk_q_aim_preflight.lua machine-checks both.
	--
	--   SUPPLY.  This is the last of TEN firing points in this function bidding
	--   for one 14-second ability.  tAllAbilityBuildList leaves Wraithfire Blast
	--   at rank 1 -- 14s cd -- from hero level 2 to 12 (the 2nd point lands at 13,
	--   corrected 2026-08-24 per GH #134; the old note said "to 11" by counting
	--   row indices as levels), which is where GH #84's
	--   turbo level census actually lives (0 of 210 hero-slots reached 20;
	--   high-water 19).  Measured
	--   over the fixture library: every frame carrying a living WK with two or more
	--   living enemies inside 568u has the Blast unlearned or on cooldown.  The
	--   branch is not reached on a single one.
	--
	--   SIBLING, UPSTREAM.  The recently-damaged branch just above takes the
	--   nearest entry of the same list, and it fires on exactly the frames this fix
	--   was for -- the ones where WK is being hit.  Aiming here alone changes no
	--   fight.  Same shape as liondrain/liondrainstop (GH #97), except the sibling
	--   is upstream and unarmed, so it takes those frames unconditionally.
	--
	-- If `wkqaim` is ever revived it has to cover the recently-damaged branch too,
	-- and the deciding read is still the corpus scan hero-1 asked for (153 games
	-- with .dem from the 2026-08-22 wave) -- a fixture-library zero shows EMPTY,
	-- never RARE.
	if ( #nEnemysHerosInView > 0 or bot:WasRecentlyDamagedByAnyHero( 3.0 ) )
		and ( bot:GetActiveMode() ~= BOT_MODE_RETREAT or #allyList >= 2 )
		and #nEnemysHerosInRange >= 1
		and nLV >= 7
	then
		for _, npcEnemy in pairs( nEnemysHerosInRange )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not J.IsDisabled( npcEnemy )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end

	

	return 0

end

-- NOT VALIDATABLE ON A FIXTURE (measured 2026-08-23).  The first guard below asks
-- for modifier_skeleton_king_bone_guard, and that modifier is on 0 of the 34
-- Wraith King frames in tests/fixtures -- including the 17 that carry a modifier
-- list at all, 17 of which carry a sibling modifier_skeleton_king_* .  So this
-- function returns 0 on 34 of 34 real frames whatever else is true of them, and a
-- "domain = 0" reading taken from the corpus about Bone Guard measures the tool,
-- not the game (the axeblink trap).  The name is right: this is the repo's only
-- caster of the ability, and four corpus frames catch it mid-cooldown against its
-- flat 42s, so the engine answered HasModifier true in those games; the gap is
-- that make_fixture.py rebuilds modifiers from combat-log ADD/REMOVE pairs and
-- there are none for this one.  Size a Bone Guard change with a batch request,
-- never with a fixture scan.  tests/test_wk_bone_guard_talent_bypass.lua.
function X.ConsiderW()
	if not abilityW:IsFullyCastable()
		or not bot:HasModifier( "modifier_skeleton_king_bone_guard" )
		or X.ShouldSaveMana( abilityW )
		or abilityW:GetName() ~= "skeleton_king_bone_guard"
	then return 0 end

	local nStack = 0
	local modIdx = bot:GetModifierByName( "modifier_skeleton_king_bone_guard" )
	if modIdx > -1 then
		nStack = bot:GetModifierStackCount( modIdx )
	end
	local maxStack = abilityW:GetSpecialValueInt( "max_skeleton_charges" )

	local nEnemysHerosInView = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )
	local npcTarget = J.GetProperTarget( bot )

	--辅助进攻
	if J.IsValidHero( npcTarget )
		and #nEnemysHerosInView == 1
		and J.IsInRange( npcTarget, bot, 650 )
		and ( nStack / maxStack >= 0.6 or talent6:IsTrained() )
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	--buff叠满了靠近兵线的时候
	if ( nStack == maxStack or talent6:IsTrained() )
		and nLV >= 4
		and ( X.IsNearLaneFront( bot ) or J.IsFarming( bot ) )
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	return 0
end

function X.IsNearLaneFront( bot )
	local testDist = 600
	local laneList = {LANE_TOP, LANE_MID, LANE_BOT}
	for _, lane in pairs( laneList )
	do
		local tFLoc = GetLaneFrontLocation( GetTeam(), lane, 0 )
		if GetUnitToLocationDistance( bot, tFLoc ) <= testDist
		then
			return true
		end
	end
	return false
end

function X.ShouldSaveMana( nAbility )

	-- (a commented-out `if talent5:IsTrained() then return false end` used to open
	-- this function.  talent5 is sTalentList[5] = the other t20 slot, today
	-- special_bonus_attack_speed_50 -- nothing to do with mana, and unreachable in
	-- turbo regardless.  The handle it needed is gone with it.)
	if nLV >= 6
	and nAbility ~= nil
	and abilityR ~= nil
	and abilityR:GetCooldownTimeRemaining() <= 3.0
	and ( bot:GetMana() - nAbility:GetManaCost() < abilityR:GetManaCost() )
	then
		return true
	end

	return false
end


return X
-- dota2jmz@163.com QQ:2462331592..
