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
--                                     damage + 20/40/60/80 over a 2s dot,
--                                     1.0/1.2/1.4/1.6s stun.
--   2 = skeleton_king_bone_guard      Bone Guard -- an ACTIVE, no-target skeleton
--                                     release: 70/80/90/100 mana, flat 42s cd,
--                                     2/4/6/8 max charges.  It is NOT lifesteal.
--   3 = skeleton_king_mortal_strike   Mortal Strike -- passive crit / skeletons.
--   6 = skeleton_king_reincarnation   220/110/0 mana, 180/150/120s cd.
--
-- skeleton_king_vampiric_spirit (the lifesteal) is flagged INNATE by the datafeed,
-- so GetAbilityList drops it and it costs no skill point at all.  The name that
-- used to be written here, skeleton_king_vampiric_aura, is not in the game's
-- ability set any more; neither is skeleton_king_spectral_blade (see abilityW).
local tAllAbilityBuildList = {
							{2,1,2,3,2,6,2,3,3,3,6,1,1,1,6},--pos1,3
}

-- [GH #17] Kill-participation laning build (gated). WK is a focus hero but bottom
-- of the pool on kills (0.6/game): the default build above leaves Wraithfire Blast
-- (index 1, the only lockdown) at a SINGLE point until level 12, so WK has no
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
-- 4 points there, this one just spends them later (1/9/10/12 vs 1/3/5/7).
-- The gate's condition (c) has to be re-argued on that basis before it is armed.
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
	"item_branches",

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
-- contribute nothing and the sibling stack test is the whole condition.
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
	-- 100/140/180/220.  Anchored 2026-08-22: that is Wraithfire Blast's impact
	-- damage (80/100/120/140) PLUS the whole 2s damage-over-time (20/40/60/80), so
	-- it is what the target loses if it stands in the dot to the end -- not what
	-- lands on cast.  It feeds a kill check below at nDamage * 1.68, i.e. up to 370
	-- claimed magical damage against 140 of impact.  Registered as a lever, NOT
	-- changed here: narrowing it is a behaviour change and needs its own gate and
	-- its own real frame.
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
	-- 600 is an ABSOLUTE mana figure on a hero that cannot hold it in turbo.  The
	-- datafeed gives WK 267 max mana at level 1 on 16 int, i.e. the standard 75
	-- base + 12/point, and 1.4 int per level: the pool is 435 at level 11, 502 at
	-- 15, 569 at 19 and still 586 at 20.  It first crosses 600 at level 21, and
	-- this branch wants CURRENT mana, so it wants a near-full level-21 pool -- while
	-- the GH #84 level census read level >= 20 on 0 of 210 hero-slots, high-water
	-- 19.  No item ahead of item_ultimate_scepter in either buy list above grants
	-- intelligence.  So this branch is unreachable in turbo whatever Roshan is
	-- doing.  Registered as a lever, NOT changed here: a fractional floor is a
	-- behaviour change, and its domain (WK in BOT_MODE_ROSHAN at all) has to be
	-- measured first -- it may well be empty, which is the axeblink trap again.
	if bot:GetActiveMode() == BOT_MODE_ROSHAN
		and bot:GetMana() >= 600
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
