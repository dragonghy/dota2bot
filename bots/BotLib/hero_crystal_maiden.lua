local X = {}
local bDebugMode = ( 1 == 10 )
local bot = GetBot()

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Minion = dofile( GetScriptDirectory()..'/FunLib/aba_minion' )
local sTalentList = J.Skill.GetTalentList( bot )
local sAbilityList = J.Skill.GetAbilityList( bot )
local sRole = J.Item.GetRoleItemsBuyList( bot )

local tTalentTreeList = {
						['t25'] = {0, 10},
						['t20'] = {10, 0},
						['t15'] = {0, 10},
						['t10'] = {0, 10},
}

local tAllAbilityBuildList = {
							 {1,2,3,2,2,6,2,1,1,1,6,3,3,3,6},
}

local nAbilityBuildList = J.Skill.GetRandomBuild( tAllAbilityBuildList )

local nTalentBuildList = J.Skill.GetTalentBuild( tTalentTreeList )

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_4'] = {
	"item_priest_outfit",
	"item_urn_of_shadows", -- Alternative: item_essence_distiller (if not going spirit_vessel)
	"item_mekansm",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_spirit_vessel",
--	"item_wraith_pact",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_5'] = {
	"item_blood_grenade",

	'item_mage_outfit',
	'item_ancient_janggo',
	'item_glimmer_cape',
	'item_boots_of_bearing',
	'item_pipe',
	"item_shivas_guard",
	'item_cyclone',
	'item_sheepstick',
	"item_aghanims_shard",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_3'] = {
	"item_mage_outfit",
	"item_shadow_amulet",
	"item_veil_of_discord",
	"item_cyclone",
	"item_shivas_guard",
	"item_glimmer_cape",
	"item_sheepstick",
	"item_orchid",
	"item_bloodthorn",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_1'] = sRoleItemsBuyList['pos_3']

sRoleItemsBuyList['pos_2'] = sRoleItemsBuyList['pos_3']

-- [TURBO BUILD, gated 'cmboots'] pos_5 opens on item_mage_outfit (tranquil
-- boots) and terminates on item_boots_of_bearing, whose recipe CONSUMES a pair
-- of tranquil boots -- a coherent utility-support line, but one that leaves the
-- highest mana costs among supports (Nova 175 / Frostbite 155 / Freezing Field
-- 600 at max rank) with no mana item at all.  Measured on this repo's corpus
-- (tests/test_cm_pos5_boots.lua): 12 of 45 ready ability slots on tranquil-
-- carrying CM frames cannot pay their own mana cost, against 0 of 14 on the
-- arcane-carrying (pos_4) frames at the same mean hero level.  The case does
-- NOT rest on arcane's flat +125 mana (that is smaller than the +144 talent
-- this desk declined at t10); it rests on Replenish, which the shipped tree
-- already fires, and which the corpus cannot see at all (GH #100) -- argued,
-- not measured.
--
-- Bearing has to go with the tranquils: with arcane in the opener its recipe
-- would buy a SECOND pair of boots (movement speed does not stack) and strand
-- 1500 gold.  No corpus unit owns one, but that zero is OUT-OF-WINDOW, not
-- empty -- the corpus ends at 11:30 and Bearing is a 4225g fifth item.
-- 2026-08-27: "the corpus ends at 11:30" was true of the corpus, never of turbo.
-- Owner priority P3 (GH #108) lifted the batch game cap from 10 to 25 minutes,
-- and the first frame taken past it (GH #235) is at 23:02 with this Crystal
-- Maiden at level 22 and holding boots_of_bearing.  The OUT-OF-WINDOW reading is
-- confirmed rather than overturned -- Bearing does get bought, just later than
-- anything the old corpus could see -- but the zero is now BUYABLE evidence, so
-- it should be re-measured rather than argued the next time this is opened.
--
-- WHY THIS IS GATED AND NO LONGER SHIPPED (GH #144, director 2026-08-23):
-- 9fa4898 landed it UNGATED.  The mirrored A/B reports a difference of
-- differences, and an ungated change is present on BOTH arms of BOTH waves, so
-- it cancels term-for-term -- condition (b) can never be bought for it, in
-- either direction, however many waves run.  Component-count repairs (GH #136,
-- GH #139) stay gate-free because they restore an intended-but-unreachable
-- state; a choice of WHAT to buy is a design decision and ships dark first.
--
-- The candidate list is derived FROM the shipped one rather than duplicated,
-- so the two cannot drift apart, and gate-off is byte-identical.
local function ArcaneBootsBuild( tList )
	if tList == nil then return tList end
	local tOut = {}
	for _, sItem in ipairs( tList ) do
		if sItem == 'item_mage_outfit' then
			tOut[#tOut+1] = 'item_mage_arcane_outfit'
		elseif sItem ~= 'item_boots_of_bearing' then
			tOut[#tOut+1] = sItem
		end
	end
	return tOut
end

if J.IsModeTurbo() and J.IsSoakCandidate( 'cmboots' ) then
	sRoleItemsBuyList['pos_5'] = ArcaneBootsBuild( sRoleItemsBuyList['pos_5'] )
end

X['sBuyList'] = sRoleItemsBuyList[sRole]

X['sSellList'] = {
	'item_cyclone',
	'item_magic_wand',

	"item_shivas_guard",
	'item_magic_wand',
}


if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_mage' }, {} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )

X['bDeafaultAbility'] = true
X['bDeafaultItem'] = true

function X.MinionThink(hMinionUnit)

	if Minion.IsValidUnit( hMinionUnit )
	then
		Minion.IllusionThink( hMinionUnit )
	end

end

--[[

npc_dota_hero_crystal_maiden

"Ability1"		"crystal_maiden_crystal_nova"
"Ability2"		"crystal_maiden_frostbite"
"Ability3"		"crystal_maiden_brilliance_aura"
"Ability4"		"generic_hidden"
"Ability5"		"generic_hidden"
"Ability6"		"crystal_maiden_freezing_field"
"Ability10"		"special_bonus_hp_250"
"Ability11"		"special_bonus_cast_range_100"
"Ability12"		"special_bonus_unique_crystal_maiden_4"
"Ability13"		"special_bonus_gold_income_25"
"Ability14"		"special_bonus_attack_speed_250"
"Ability15"		"special_bonus_unique_crystal_maiden_3"
"Ability16"		"special_bonus_unique_crystal_maiden_1"
"Ability17"		"special_bonus_unique_crystal_maiden_2"

modifier_crystal_maiden_crystal_nova
modifier_crystal_maiden_frostbite
modifier_crystal_maiden_brilliance_aura
modifier_crystal_maiden_brilliance_aura_effect
modifier_crystal_maiden_freezing_field
modifier_crystal_maiden_freezing_field_slow
modifier_crystal_maiden_freezing_field_tracker

--]]

local amuletTime = 0
local aetherRange = 0

local abilityQ = bot:GetAbilityByName( sAbilityList[1] )
local abilityW = bot:GetAbilityByName( sAbilityList[2] )
local abilityR = bot:GetAbilityByName( sAbilityList[6] )
local CrystalClone = bot:GetAbilityByName( sAbilityList[4] )
local talent2 = bot:GetAbilityByName( sTalentList[2] )
local ArcaneAura = bot:GetAbilityByName("crystal_maiden_brilliance_aura")

local castQDesire, castQLoc = 0
local castWDesire, castWTarget = 0
local castRDesire = 0
local CrystalCloneDesire, CrystalCloneLocation
local ArcaneAuraDesire
local botTarget

local nKeepMana, nMP, nHP, nLV

function X.SkillsComplement()

	X.ConsiderCombo()

	if J.CanNotUseAbility( bot ) or bot:IsInvisible() then return end

	botTarget = bot:GetAttackTarget()
	nKeepMana = 220
	aetherRange = 0
	nMP = bot:GetMana()/bot:GetMaxMana()
	nHP = bot:GetHealth()/bot:GetMaxHealth()
	nLV = bot:GetLevel()
	local aether = J.IsItemAvailable( 'item_aether_lens' )
	if aether ~= nil then aetherRange = 250 end
--	if talent2:IsTrained() then aetherRange = aetherRange + talent2:GetSpecialValueInt( 'value' ) end

	ArcaneAuraDesire = X.ConsiderArcaneAura()
	if ( ArcaneAuraDesire > 0 )
	then
		J.SetQueuePtToINT( bot, false )

		bot:ActionQueue_UseAbility( ArcaneAura )
		return
	end

	CrystalCloneDesire, CrystalCloneLocation = X.ConsiderCrystalClone()
	if CrystalCloneDesire > 0
	then
		J.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation( X.GetBoundAbility( CrystalClone, 'crystal_maiden_crystal_clone' ), CrystalCloneLocation)
		return
	end

	castQDesire, castQLoc = X.ConsiderQ()
	if ( castQDesire > 0 )
	then
		J.SetQueuePtToINT( bot, false )

		bot:ActionQueue_UseAbilityOnLocation( abilityQ, castQLoc )
		return
	end


	castWDesire, castWTarget = X.ConsiderW()
	if ( castWDesire > 0 )
	then
		J.SetQueuePtToINT( bot, false )

		bot:ActionQueue_UseAbilityOnEntity( abilityW, castWTarget )
		return
	end

	castRDesire = X.ConsiderR()
	if ( castRDesire > 0 )
	then
		J.SetQueuePtToINT( bot, false )

		bot:ActionQueue_UseAbility( abilityR )
		return
	end

end

--- Can the engine actually ACCEPT a cast order for Arcane Aura?
---
--- WHY THIS IS A QUESTION AT ALL (GH #177, axis `CASTSHAPE`).  Every other axis
--- this desk opened asked what a number was worth.  This one asks whether the
--- order the file writes is one the engine can take.  `bot:Action*_UseAbility`,
--- `...OnEntity` and `...OnLocation` are three different orders and an
--- ability's `AbilityBehavior` flags decide which of them it accepts --
--- `DOTA_ABILITY_BEHAVIOR_PASSIVE` accepts none of them, ever.
---
--- `crystal_maiden_brilliance_aura` is declared
--- `"AbilityBehavior" "DOTA_ABILITY_BEHAVIOR_PASSIVE"` in the game's own hero
--- KV -- that one flag and nothing else.  So the `ActionQueue_UseAbility(
--- ArcaneAura )` at the top of X.SkillsComplement is an order the engine cannot
--- execute.  Census over all 128 shipped heroes: 11 such sites in 10 files, and
--- this is the ONLY one in the focus five (tools/agent/cast_shape_census.py,
--- frozen in tests/mock/ability_behavior.lua).
---
--- WHAT IT COSTS TODAY IS ZERO, AND THAT IS EXACTLY THE PROBLEM.  The branch is
--- dead upstream of the order: `J.CanCastAbility` rejects on `ability:IsPassive()`
--- before anything else.  So the whole reasoning rests on ONE engine predicate
--- that cannot be read from here (AGENTS.md: no bot-side debugging; the mock
--- answers false for every `Is*` it does not know, so offline agreement is not
--- evidence).  And the cost of that predicate being false is not one wasted
--- cast: this branch runs FIRST in X.SkillsComplement and `return`s, so a
--- non-zero desire eats Crystal Nova, Frostbite, Crystal Clone AND Freezing
--- Field for that tick, every tick CM is going on someone within 500 units.
--- A silent dependency with that blast radius is worth converting into a fact.
---
--- NARROWING (soak candidate 'cmaurapassive', turbo-only).  The shipped read
--- runs FIRST and `return false` is the only thing the armed path can add, so
--- gate-off equivalence is STRUCTURAL, not measured -- the same shape as
--- `lionhexaoe` (GH #166) and the dual of GH #154's widening.  Direction is
--- single: armed can only ever refuse a cast the shipped code allowed.
function X.IsArcaneAuraCastable()

	if not J.CanCastAbility( ArcaneAura ) then return false end

	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmaurapassive' )
	and X.HasPassiveBehavior( ArcaneAura )
	then
		return false
	end

	return true

end

--- Does this ability carry DOTA_ABILITY_BEHAVIOR_PASSIVE in its behavior mask?
---
--- A behavior of 0, or a constant this VM does not define, means "we could not
--- read it" -- answer false and let the shipped predicate stand.  Inventing a
--- default here would be the mistake GH #162 wrote down: a silent zero is not
--- a value, and a guard built on one is a guard built on nothing.
function X.HasPassiveBehavior( hAbility )

	if hAbility == nil then return false end

	local nFlag = DOTA_ABILITY_BEHAVIOR_PASSIVE
	if type( nFlag ) ~= 'number' or nFlag <= 0 then return false end

	local nBehavior = hAbility:GetBehavior()
	if type( nBehavior ) ~= 'number' or nBehavior <= 0 then return false end

	return bit.band( nBehavior, nFlag ) == nFlag

end

function X.ConsiderArcaneAura()
	--进攻
	if J.IsGoingOnSomeone( bot )
	and X.IsArcaneAuraCastable()
	then
		local npcTarget = J.GetProperTarget( bot )
		if J.IsValidHero( npcTarget )
			and J.CanCastOnNonMagicImmune( npcTarget )
			and J.CanCastOnTargetAdvanced( npcTarget )
			and J.IsInRange( npcTarget, bot, 500 )
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end

function X.ConsiderCombo()
	if bot:IsAlive()
		and bot:IsChanneling()
		and not bot:IsInvisible()
	then
		local nEnemyTowers = bot:GetNearbyTowers( 880, true )

		if nEnemyTowers[1] ~= nil then return end

		local amulet = J.IsItemAvailable( 'item_shadow_amulet' )
		if amulet~=nil and amulet:IsFullyCastable() and amuletTime < DotaTime()- 10
		then
			amuletTime = DotaTime()
			bot:Action_UseAbilityOnEntity( amulet, bot )
			return
		end

		if not bot:HasModifier( 'modifier_teleporting' )
		then
			local glimer = J.IsItemAvailable( 'item_glimmer_cape' )
			if glimer ~= nil and glimer:IsFullyCastable()
			then
				bot:Action_UseAbilityOnEntity( glimer, bot )
				return
			end

			local invissword = J.IsItemAvailable( 'item_invis_sword' )
			if invissword ~= nil and invissword:IsFullyCastable()
			then
				bot:Action_UseAbility( invissword )
				return
			end

			local silveredge = J.IsItemAvailable( 'item_silver_edge' )
			if silveredge ~= nil and silveredge:IsFullyCastable()
			then
				bot:Action_UseAbility( silveredge )
				return
			end
		end
	end
end

-- [GH #12] 'nopush' laning wave-shove guard. During the laning phase an AOE
-- damage nuke aimed at (or splashing onto) the enemy creep wave shoves the
-- lane, costing the bot lane control and last-hits. Returns true to suppress
-- such a cast when it is a *pure wave-clear* -- >= 2 enemy lane creeps caught
-- in the AOE and NO enemy hero inside it -- and the bot is not in an explicit
-- push / defend / teamfight state. Harassing an actual enemy hero (a hero
-- inside the AOE) always passes through. Gated: turbo + soak-candidate
-- 'nopush', so shipped behavior is unchanged (inert off the candidate side).
-- Extend to other AOE laning nukes by wrapping their Consider fn the same way
-- (see hero_jakiro.lua Dual Breath for the second beachhead).
function X._nopush_ShouldSuppressWaveShove( hBot, vLocation, nRadius )
	if hBot == nil or vLocation == nil or vLocation == 0 then return false end
	if type( nRadius ) ~= 'number' or nRadius <= 0 then return false end
	if not J.IsModeTurbo() or not J.IsSoakCandidate( 'nopush' ) then return false end
	if not J.IsInLaningPhase() then return false end
	-- Intended shove: pushing / defending a tower / in a teamfight -> allow.
	if J.IsPushing( hBot ) or J.IsDefending( hBot ) or J.IsInTeamFight( hBot, 1600 )
	then
		return false
	end
	-- An enemy hero inside the AOE means this is harass, not a wave-clear.
	local tEnemyHeroes = J.GetNearbyHeroes( hBot, 1600, true, BOT_MODE_NONE )
	if tEnemyHeroes ~= nil
	then
		for _, e in pairs( tEnemyHeroes )
		do
			if J.IsValid( e ) and GetUnitToLocationDistance( e, vLocation ) <= nRadius
			then
				return false
			end
		end
	end
	-- Pure wave-clear: >= 2 of the enemy lane creeps sit in the AOE.
	return J.GetInLocLaneCreepCount( hBot, 1600, nRadius, vLocation ) >= 2
end

function X.ConsiderQ()
	-- [lanefix] Conserve mana in lane when no kill is on the table.
	if J.ShouldConserveManaInLane( bot ) then return BOT_ACTION_DESIRE_NONE, 0 end
	local nDesire, vLoc = X.ConsiderQImpl()
	if nDesire ~= nil
		and nDesire ~= BOT_ACTION_DESIRE_NONE
		and abilityQ ~= nil
		and X._nopush_ShouldSuppressWaveShove( bot, vLoc, abilityQ:GetSpecialValueInt( 'radius' ) )
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	return nDesire, vLoc
end

function X.ConsiderQImpl()


	if not abilityQ:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local nRadius = abilityQ:GetSpecialValueInt( 'radius' )
	local nCastRange = abilityQ:GetCastRange() + aetherRange + 32
	local nCastPoint = abilityQ:GetCastPoint()
	local nManaCost = abilityQ:GetManaCost()
	local nDamage = abilityQ:GetSpecialValueInt( 'nova_damage' )
	local nSkillLV = abilityQ:GetLevel()

	local nAllys =  J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE )

	local nEnemysHeroesInRange = J.GetNearbyHeroes(bot, nCastRange + nRadius, true, BOT_MODE_NONE )
	local nEnemysHeroesInBonus = J.GetNearbyHeroes(bot, nCastRange + nRadius + 150, true, BOT_MODE_NONE )
	local nEnemysHeroesInView = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )
	local nWeakestEnemyHeroInRange, nWeakestEnemyHeroHealth1 = X.cm_GetWeakestUnit( nEnemysHeroesInRange )
	local nWeakestEnemyHeroInBonus, nWeakestEnemyHeroHealth2 = X.cm_GetWeakestUnit( nEnemysHeroesInBonus )

	local nEnemysLaneCreeps1 = bot:GetNearbyLaneCreeps( nCastRange + nRadius, true )
	local nEnemysLaneCreeps2 = bot:GetNearbyLaneCreeps( nCastRange + nRadius + 200, true )
	local nEnemysWeakestLaneCreeps1, nEnemysWeakestLaneCreepsHealth1 = X.cm_GetWeakestUnit( nEnemysLaneCreeps1 )
	local nEnemysWeakestLaneCreeps2, nEnemysWeakestLaneCreepsHealth2 = X.cm_GetWeakestUnit( nEnemysLaneCreeps2 )

	local nTowers = bot:GetNearbyTowers( 1000, true )

	local nCanKillHeroLocationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius , 0.8, nDamage )
	local nCanHurtHeroLocationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius , 0.8, 0 )
	local nCanKillCreepsLocationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange + nRadius, nRadius, 0.5, nDamage )
	local nCanHurtCreepsLocationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange + nRadius, nRadius, 0.5, 0 )

	if nCanHurtCreepsLocationAoE == nil
		or nCanHurtCreepsLocationAoE.targetloc == nil
		or J.GetInLocLaneCreepCount( bot, 1600, nRadius, nCanHurtCreepsLocationAoE.targetloc ) <= 2
	then
		nCanHurtCreepsLocationAoE.count = 0
	end

	--击杀敌人
	if nCanKillHeroLocationAoE.count ~= nil
		and nCanKillHeroLocationAoE.count >= 1
	then
		if J.IsValid( nWeakestEnemyHeroInBonus )
		then
			local nTargetLocation = J.GetCastLocation( bot, nWeakestEnemyHeroInBonus, nCastRange, nRadius )
			if nTargetLocation ~= nil
			then
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation
			end
		end
	end

	--对线期对两名以上敌人使用
	if bot:GetActiveMode() == BOT_MODE_LANING
		and #nTowers <= 0
		and nHP >= 0.4
	then
		if nCanHurtHeroLocationAoE.count >= 2
			and GetUnitToLocationDistance( bot, nCanHurtHeroLocationAoE.targetloc ) <= nCastRange + 50
		then
			return BOT_ACTION_DESIRE_HIGH, nCanHurtHeroLocationAoE.targetloc
		end
	end

	--撤退时保护自己
	if bot:GetActiveMode() == BOT_MODE_RETREAT
		and bot:WasRecentlyDamagedByAnyHero( 2.0 )
	then
		local nCanHurtHeroLocationAoENearby = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange - 300, nRadius, 0.8, 0 )
		if nCanHurtHeroLocationAoENearby.count >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, nCanHurtHeroLocationAoENearby.targetloc
		end
	end

	--进攻时的逻辑
	if J.IsGoingOnSomeone( bot )
	then

		--进攻时对两名以上敌人使用
		if J.IsValid( nWeakestEnemyHeroInBonus )
			and nCanHurtHeroLocationAoE.count >= 2
			and GetUnitToLocationDistance( bot, nCanHurtHeroLocationAoE.targetloc ) <= nCastRange
		then
			return BOT_ACTION_DESIRE_HIGH, nCanHurtHeroLocationAoE.targetloc
		end

		--对进攻目标使用
		local npcEnemy = J.GetProperTarget( bot )
		if J.IsValidHero( npcEnemy )
			and J.CanCastOnNonMagicImmune( npcEnemy )
		then

			--蓝很多随意用
			if nMP > 0.75
				or bot:GetMana() > nKeepMana * 2
			then
				local nTargetLocation = J.GetCastLocation( bot, npcEnemy, nCastRange, nRadius )
				if nTargetLocation ~= nil
				then
					return BOT_ACTION_DESIRE_HIGH, nTargetLocation
				end
			end

			--进攻目标血很少
			if ( npcEnemy:GetHealth()/npcEnemy:GetMaxHealth() < 0.4 )
				and GetUnitToUnitDistance( npcEnemy, bot ) <= nRadius + nCastRange
			then
				local nTargetLocation = J.GetCastLocation( bot, npcEnemy, nCastRange, nRadius )
				if nTargetLocation ~= nil
				then
					return BOT_ACTION_DESIRE_HIGH, nTargetLocation
				end
			end

		end

		--对最虚弱的敌人使用
		npcEnemy = nWeakestEnemyHeroInRange
		if npcEnemy ~= nil and npcEnemy:IsAlive()
			and ( npcEnemy:GetHealth()/npcEnemy:GetMaxHealth() < 0.4 )
			and GetUnitToUnitDistance( npcEnemy, bot ) <= nRadius + nCastRange
		then
			local nTargetLocation = J.GetCastLocation( bot, npcEnemy, nCastRange, nRadius )
			if nTargetLocation ~= nil
			then
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation
			end
		end

		--无敌人时清理兵线
		if 	J.IsValid( nEnemysWeakestLaneCreeps2 )
			and nCanHurtCreepsLocationAoE.count >= 5
			and #nEnemysHeroesInBonus <= 0
			and bot:GetActiveMode() ~= BOT_MODE_ATTACK
			and nSkillLV >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, nCanHurtCreepsLocationAoE.targetloc
		end

		--无敌人时收钱
		if nCanKillCreepsLocationAoE.count >= 3
			and ( J.IsValid( nEnemysWeakestLaneCreeps1 ) or nLV >= 25 )
			and #nEnemysHeroesInBonus <= 0
			and bot:GetActiveMode() ~= BOT_MODE_ATTACK
			and nSkillLV >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, nCanKillCreepsLocationAoE.targetloc
		end
	end

	--非撤退的逻辑
	if bot:GetActiveMode() ~= BOT_MODE_RETREAT
	then
		if J.IsValid( nWeakestEnemyHeroInBonus )
		then

			if nCanHurtHeroLocationAoE.count >= 3
				and GetUnitToLocationDistance( bot, nCanHurtHeroLocationAoE.targetloc ) <= nCastRange
			then
				return BOT_ACTION_DESIRE_VERYHIGH, nCanHurtHeroLocationAoE.targetloc
			end

			if nCanHurtHeroLocationAoE.count >= 2
				and GetUnitToLocationDistance( bot, nCanHurtHeroLocationAoE.targetloc ) <= nCastRange
				and bot:GetMana() > nKeepMana
			then
				return BOT_ACTION_DESIRE_HIGH, nCanHurtHeroLocationAoE.targetloc
			end

			if J.IsValid( nWeakestEnemyHeroInBonus )
			then
				if nMP > 0.8
					or bot:GetMana() > nKeepMana * 2
				then
					local nTargetLocation = J.GetCastLocation( bot, nWeakestEnemyHeroInBonus, nCastRange, nRadius )
					if nTargetLocation ~= nil
					then
						return BOT_ACTION_DESIRE_HIGH, nTargetLocation
					end
				end

				if ( nWeakestEnemyHeroInBonus:GetHealth()/nWeakestEnemyHeroInBonus:GetMaxHealth() < 0.4 )
					and GetUnitToUnitDistance( nWeakestEnemyHeroInBonus, bot ) <= nRadius + nCastRange
				then
					local nTargetLocation = J.GetCastLocation( bot, nWeakestEnemyHeroInBonus, nCastRange, nRadius )
					if nTargetLocation ~= nil
					then
						return BOT_ACTION_DESIRE_HIGH, nTargetLocation
					end
				end
			end
		end
	end


	--打钱
	if J.IsFarming( bot )
		and nSkillLV >= 3
	then

		if nCanKillCreepsLocationAoE.count >= 2
			and J.IsValid( nEnemysWeakestLaneCreeps1 )
		then
			return BOT_ACTION_DESIRE_HIGH, nCanKillCreepsLocationAoE.targetloc
		end

		if nCanHurtCreepsLocationAoE.count >= 4
			and J.IsValid( nEnemysWeakestLaneCreeps1 )
		then
			return BOT_ACTION_DESIRE_HIGH, nCanHurtCreepsLocationAoE.targetloc
		end

	end

	--推进和防守
	if #nAllys <= 2 and nSkillLV >= 3
		and ( J.IsPushing( bot ) or J.IsDefending( bot ) )
	then

		if nCanHurtCreepsLocationAoE.count >= 4
			and  J.IsValid( nEnemysWeakestLaneCreeps1 )
		then
			return BOT_ACTION_DESIRE_HIGH, nCanHurtCreepsLocationAoE.targetloc
		end

		if nCanKillCreepsLocationAoE.count >= 2
			and J.IsValid( nEnemysWeakestLaneCreeps1 )
		then
			return BOT_ACTION_DESIRE_HIGH, nCanKillCreepsLocationAoE.targetloc
		end
	end


	if bot:GetActiveMode() == BOT_MODE_ROSHAN
		and bot:GetMana() >= 400
	then
		if J.IsRoshan( botTarget )
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end

	--特殊用法之辅助二技能收大野
	local nNeutarlCreeps = bot:GetNearbyNeutralCreeps( nCastRange + nRadius )
	if J.IsValid( nNeutarlCreeps[1] )
	then
		for _, creep in pairs( nNeutarlCreeps )
		do
			if J.IsValid( creep )
				and creep:HasModifier( 'modifier_crystal_maiden_frostbite' )
				and creep:GetHealth()/creep:GetMaxHealth() > 0.3
				and ( creep:GetUnitName() == 'npc_dota_neutral_dark_troll_warlord'
					or creep:GetUnitName() == 'npc_dota_neutral_satyr_hellcaller'
					or creep:GetUnitName() == 'npc_dota_neutral_polar_furbolg_ursa_warrior' )
			then
				local nTargetLocation = J.GetCastLocation( bot, creep, nCastRange, nRadius )
				if nTargetLocation ~= nil
				then
					return BOT_ACTION_DESIRE_HIGH, nTargetLocation
				end
			end
		end
	end

	--通用的用法
	if #nEnemysHeroesInView == 0
		and not J.IsGoingOnSomeone( bot )
		and nSkillLV > 2
	then

		if nCanKillCreepsLocationAoE.count >= 2
			and ( nEnemysWeakestLaneCreeps2 ~= nil or nLV == 25 )
		then
			return BOT_ACTION_DESIRE_HIGH, nCanKillCreepsLocationAoE.targetloc
		end

		if nCanHurtCreepsLocationAoE.count >= 4
			and nEnemysWeakestLaneCreeps2 ~= nil
		then
			return BOT_ACTION_DESIRE_HIGH, nCanHurtCreepsLocationAoE.targetloc
		end

	end

	if J.IsDoingRoshan(bot)
	then
		if J.IsRoshan(botTarget)
        and J.IsInRange(bot, botTarget, nCastRange)
        and J.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end

	if J.IsDoingTormentor(bot)
	then
		if J.IsTormentor( botTarget )
        and J.IsInRange(bot, botTarget, nCastRange)
        and J.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0

end

function X.ConsiderW()

	if not abilityW:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end

	local nCastRange = abilityW:GetCastRange() + 30 + aetherRange
	local nCastPoint = abilityW:GetCastPoint()
	local nManaCost = abilityW:GetManaCost()
	local nSkillLV = abilityW:GetLevel()
	local nDamage = ( 100 + nSkillLV * 50 )

	local nAllies =  J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE )

	local nEnemysHeroesInView = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )
	if #nEnemysHeroesInView <= 1 and nCastRange < bot:GetAttackRange() then nCastRange = bot:GetAttackRange() + 60 end
	local nEnemysHeroesInRange = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )
	local nEnemysHeroesInBonus = J.GetNearbyHeroes(bot, nCastRange + 200, true, BOT_MODE_NONE )

	local nWeakestEnemyHeroInRange, nWeakestEnemyHeroHealth1 = X.cm_GetWeakestUnit( nEnemysHeroesInRange )
	local nWeakestEnemyHeroInBonus, nWeakestEnemyHeroHealth2 = X.cm_GetWeakestUnit( nEnemysHeroesInBonus )

	local nEnemysCreeps1 = bot:GetNearbyCreeps( nCastRange + 100, true )
	local nEnemysCreeps2 = bot:GetNearbyCreeps( 1400, true )

	local nEnemysStrongestCreeps1, nEnemysStrongestCreepsHealth1 = X.cm_GetStrongestUnit( nEnemysCreeps1 )
	local nEnemysStrongestCreeps2, nEnemysStrongestCreepsHealth2 = X.cm_GetStrongestUnit( nEnemysCreeps2 )

	local nTowers = bot:GetNearbyTowers( 900, true )

	--击杀敌人
	if J.IsValid( nWeakestEnemyHeroInRange )
		and J.CanCastOnTargetAdvanced( nWeakestEnemyHeroInRange )
	then
		if J.WillMagicKillTarget( bot, nWeakestEnemyHeroInRange, nDamage, nCastPoint )
		then
			return BOT_ACTION_DESIRE_HIGH, nWeakestEnemyHeroInRange
		end
	end

	--打断TP
	for _, npcEnemy in pairs( nEnemysHeroesInBonus )
	do
		if J.IsValid( npcEnemy )
			and npcEnemy:IsChanneling()
			and npcEnemy:HasModifier( 'modifier_teleporting' )
			and J.CanCastOnNonMagicImmune( npcEnemy )
			and J.CanCastOnTargetAdvanced( npcEnemy )
		then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy
		end
	end

	--团战中对最强的敌人使用
	if J.IsInTeamFight( bot, 1200 )
		and  DotaTime() > 6 * 60
	then
		local npcMostDangerousEnemy = nil
		local nMostDangerousDamage = 0

		local tableNearbyEnemyHeroes = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )
		for _, npcEnemy in pairs( tableNearbyEnemyHeroes )
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

	--保护自己
	if bot:WasRecentlyDamagedByAnyHero( 3.0 )
		and #nEnemysHeroesInRange >= 1
	then
		for _, npcEnemy in pairs( nEnemysHeroesInRange )
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

	--对线期消耗
	if bot:GetActiveMode() == BOT_MODE_LANING and #nTowers == 0
	then
		if( nMP > 0.5 or bot:GetMana()> nKeepMana )
		then
			if J.IsValid( nWeakestEnemyHeroInRange )
				and not J.IsDisabled( nWeakestEnemyHeroInRange )
			then
				return BOT_ACTION_DESIRE_HIGH, nWeakestEnemyHeroInRange
			end
		end

		if( nMP > 0.78 or bot:GetMana()> nKeepMana )
		then
			if J.IsValid( nWeakestEnemyHeroInBonus )
				and nHP > 0.6
				and #nTowers == 0
				and #nEnemysCreeps2 + #nEnemysHeroesInBonus <= 5
				and not J.IsDisabled( nWeakestEnemyHeroInBonus )
				and nWeakestEnemyHeroInBonus:GetCurrentMovementSpeed() < bot:GetCurrentMovementSpeed()
			then
				return BOT_ACTION_DESIRE_HIGH, nWeakestEnemyHeroInBonus
			end
		end


		if J.IsValid( nEnemysHeroesInView[1] )
		then
			if J.GetAllyUnitCountAroundEnemyTarget( bot, nEnemysHeroesInView[1], 350 ) >= 5
				and not J.IsDisabled( nEnemysHeroesInView[1] )
				and not nEnemysHeroesInView[1]:IsMagicImmune()
				and nHP > 0.7
				and bot:GetMana()> nKeepMana
				and #nEnemysCreeps2 + #nEnemysHeroesInBonus <= 3
				and #nTowers == 0
			then
				return BOT_ACTION_DESIRE_HIGH, nEnemysHeroesInView[1]
			end
		end

		if J.IsValid( nWeakestEnemyHeroInRange )
		then
			if nWeakestEnemyHeroInRange:GetHealth()/nWeakestEnemyHeroInRange:GetMaxHealth() < 0.5
			then
				return BOT_ACTION_DESIRE_HIGH, nWeakestEnemyHeroInRange
			end
		end
	end

	--特殊用法之冰冻敌方英雄的随从
	if nEnemysHeroesInRange[1] == nil
		and nEnemysCreeps1[1] ~= nil
	then
		for _, EnemyplayerCreep in pairs( nEnemysCreeps1 )
		do
			if J.IsValid( EnemyplayerCreep )
				and EnemyplayerCreep:GetTeam() == GetOpposingTeam()
				and EnemyplayerCreep:GetHealth() > 460
				and not EnemyplayerCreep:IsMagicImmune()
				and not EnemyplayerCreep:IsInvulnerable()
				and EnemyplayerCreep:IsDominated()
			then
				return BOT_ACTION_DESIRE_HIGH, EnemyplayerCreep
			end
		end
	end

	--无英雄目标时冰冻小兵打钱
	if bot:GetActiveMode() ~= BOT_MODE_LANING
		and  bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and  bot:GetActiveMode() ~= BOT_MODE_ATTACK
		and  #nEnemysHeroesInView == 0
		and  #nAllies < 3
		and  nLV >= 5
	then

		--先远
		if J.IsValid( nEnemysStrongestCreeps2 )
			and ( DotaTime() > 10 * 60
				or ( nEnemysStrongestCreeps2:GetUnitName() ~= 'npc_dota_creep_badguys_melee'
					and nEnemysStrongestCreeps2:GetUnitName() ~= 'npc_dota_creep_badguys_ranged'
					and nEnemysStrongestCreeps2:GetUnitName() ~= 'npc_dota_creep_goodguys_melee'
					and nEnemysStrongestCreeps2:GetUnitName() ~= 'npc_dota_creep_goodguys_ranged' ) )
		then
			if ( nEnemysStrongestCreepsHealth2 > 460 or ( nEnemysStrongestCreepsHealth1 > 390 and nMP > 0.45 ) )
				and nEnemysStrongestCreepsHealth2 <= 1200
			then
				return BOT_ACTION_DESIRE_LOW, nEnemysStrongestCreeps2
			end
		end

		--再近
		if J.IsValid( nEnemysStrongestCreeps1 )
			and ( DotaTime() > 10 * 60
				or ( nEnemysStrongestCreeps1:GetUnitName() ~= 'npc_dota_creep_badguys_melee'
					and nEnemysStrongestCreeps1:GetUnitName() ~= 'npc_dota_creep_badguys_ranged'
					and nEnemysStrongestCreeps1:GetUnitName() ~= 'npc_dota_creep_goodguys_melee'
					and nEnemysStrongestCreeps1:GetUnitName() ~= 'npc_dota_creep_goodguys_ranged' ) )
		then
			if ( nEnemysStrongestCreepsHealth1 > 410 or ( nEnemysStrongestCreepsHealth1 > 360 and nMP > 0.45 ) )
				and nEnemysStrongestCreepsHealth1 <= 1200
			then
				return BOT_ACTION_DESIRE_LOW, nEnemysStrongestCreeps1
			end
		end

	end

	--进攻
	if J.IsGoingOnSomeone( bot )
	then
		local npcTarget = J.GetProperTarget( bot )
		if J.IsValidHero( npcTarget )
			and J.CanCastOnNonMagicImmune( npcTarget )
			and J.CanCastOnTargetAdvanced( npcTarget )
			and J.IsInRange( npcTarget, bot, nCastRange + 50 )
			and not J.IsDisabled( npcTarget )
			and not npcTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, npcTarget
		end
	end


	--撤退
	if J.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( nEnemysHeroesInRange )
		do
			if J.IsValid( npcEnemy )
				and bot:WasRecentlyDamagedByHero( npcEnemy, 5.0 )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not J.IsDisabled( npcEnemy )
				and J.IsInRange( npcEnemy, bot, nCastRange - 80 )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end


	if bot:GetActiveMode() == BOT_MODE_ROSHAN
		and bot:GetMana() >= 400
	then
		if J.IsRoshan( botTarget )
			and not J.IsDisabled( botTarget )
			and not botTarget:IsDisarmed()
			and J.IsInRange( botTarget, bot, nCastRange )
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end


	return BOT_ACTION_DESIRE_NONE, 0

end

-- [hero.md backlog #2] Self-preservation gate for Freezing Field: ConsiderR
-- had no check on CM's own safety before committing to the 10s self-rooting
-- channel. Real frame 20260819_003005_slot1 t=373.4 (6:13, replay-analyst
-- dig): CM opened R while Jakiro -- ice_path off cooldown, a curated hard-CC
-- ability -- was closing to ~1139 units with no ally CC covering him; he
-- stunned her 0.6s into the channel (cutting it to 6% of its max duration)
-- and she died 5.9s later, most of the ultimate's value lost. Withhold when
-- an enemy hero within 1600 (this file's standard nearby-hero scan range)
-- has a ready hard-CC ability -- she isn't covered against being chain-CC'd
-- out of the channel. Gated turbo + 'cmrguard'; default path (candidate not
-- armed) is unchanged.
--
-- [NARROWED, GH #34] The first cut asked J.HasReadyHardCc -- the boolean
-- wrapper -- and so was RANGE-BLIND: any enemy inside the 1600 scan holding a
-- ready CC vetoed the ultimate, no matter whether he could deliver it. That is
-- the same defect ccburst already paid a bisect to narrow (jmz_func.lua), and
-- the counterfactual replay of 14 mirror games (5 vetoes reconstructed on real
-- frames) caught it: at 20260819_004858_slot1 t=423.4 a HALF-HP Centaur 1326
-- units away and WALKING AWAY (1326 -> 3077 over the next 10s, hoof_stomp
-- never cast) vetoed a Freezing Field that in reality cost CM nothing -- she
-- lived another 44.1s. J.GetReadyHardCc deliberately returns the HANDLE so the
-- caller can range-check; use it, with the same closing buffer form ccburst
-- settled on (no-target self-radius CCs report cast range 0 -> the holder must
-- be right on top of her, which is correct for hoof_stomp).
--
-- The buffer is WIDER than ccburst's 250 because the consumer is different:
-- ccburst sizes a 3s lane-trade window ("can he land it before I step away"),
-- while Freezing Field roots CM for a 10s channel -- a threat only has to close
-- the gap ONCE during it. 400 units is ~1.3s of hero movement at ~300 ms, an
-- order of magnitude short of the channel, so the gate stays narrow. The two
-- real frames pinned in tests/test_replay_260819_cm_r_range.lua bound it to
-- [139, 1011): >=139 so the Jakiro ice_path frame that motivated the gate is
-- still caught, <1011 so the Centaur false positive is released.
X.nRGuardCloseBuffer = 400

-- [GH #63, re-measured 2026-08-22] The `+ buffer` above is an argument about
-- CLOSING: a threat only has to cover the gap once during a 10s channel, so
-- give it 400 units of walking room. That argument is sound for a self-radius
-- CC (hoof_stomp, berserkers_call, slithereen_crush all report cast range 0 --
-- the holder must physically arrive), and empty for a ranged one: a Witch
-- Doctor holding paralyzing_cask does not have to close anything, so on him the
-- buffer is not modelling approach, it is handing out 400 free units of veto
-- radius on top of a ring that already reaches. `cmrcap` (gated turbo, and only
-- ever meaningful when `cmrguard` is armed too -- it narrows THAT branch) caps
-- the GetCastRange() term so the buffer keeps its closing meaning everywhere.
--
-- 200 is measured, not chosen for roundness. Re-running GH #63's cap sweep on
-- its own 8-game corpus (10948 CM-alive frames, 0.5s dump) against the
-- RE-ANCHORED cast ranges -- the table that sweep ran on was wrong in 16 of 23
-- entries, cask included (900 -> 600) -- gives, per cap: episode precision
-- 48% (no cap) / 50% (500) / 52% (300) / 57% (250) / 62% (200) / 60% (0), and
-- lockout 213.0s / 181.0 / 104.5 / 91.0 / 65.5 / 50.0. Only 200 clears all
-- three clauses GH #63 section 6 pre-registered (precision >= 60%, lockout <=
-- 35% of the status quo, true positives down <= 20%); 250 -- the value that
-- issue recommends -- misses two of them once the anchors are right.
--
-- The two frames pinned in tests/test_replay_260820_cm_cask_cap.lua bound it to
-- [146, 483): both are the SAME ability at different distances, so the bound is
-- a pure statement about range. >= 146 so the 546u cask that really did stun
-- her out of the channel (GH #63 section 3, she died 0.2s later) is still
-- caught; < 483 so the 883u cask that never came is released (she lived 101.9s).
-- Recall against the landing set -- hard CCs that really landed on her, ground
-- truth from the event stream and therefore immune to how the veto runs are
-- segmented -- goes 94% -> 86% at this cap, and falls off a cliff (73%) only if
-- the range term is dropped entirely.
X.nRGuardRangeCap = 200

-- [hero.md backlog #13] The gate above asks only about THEM: who, right now,
-- holds a ready hard CC and stands close enough to deliver it. It never asks
-- anything about CM herself -- not her health, not whether she is already being
-- shot at, not whether she is standing in a stun at this very instant. GH #66
-- section 2 frame A is what that costs: at 20260820_103216_slot1 t=473.5 she was
-- at 292/1110 (26%), carrying a modifier_stunned with 0.2s left from a hit 1.1s
-- earlier, with 919 points of hero damage landed on her in the preceding 6s and
-- two enemies inside 300 units. Every input the gate reads was about them, all
-- of it passed, and she opened a ten-second self-rooting channel: stunned again
-- at 474.4, dead at 474.5 (the fixture's own ground truth, died_after = 1.0).
--
-- The clause is deliberately a CONJUNCTION of two facts about her, because
-- either alone is ordinary. Low health alone is CM's normal state as a support
-- and vetoing on it would silence the ultimate for most of the game; being shot
-- at alone is what a teamfight looks like, and a teamfight is exactly when
-- Freezing Field is worth channelling. It is the pair -- below the health floor
-- AND currently under hero fire -- that says the channel will not survive long
-- enough to pay: the ability deals its damage in pulses over up to 10s, so a CM
-- who dies in the first second converts a full ultimate into roughly one pulse.
-- Standard play is the same: Freezing Field is opened from a protected position
-- (or behind a Glimmer/BKB), never as a low-health hero's escape from a fight
-- she is already losing -- at 38% under fire the correct spell is Frostbite or
-- a walk, both of which this file already bids for.
--
-- The floor is 0.38 because that is the number ConsiderR ALREADY uses one branch
-- below (`J.IsRetreating( bot ) and nHP > 0.38`): the file has long agreed that
-- below 38% CM is too fragile to commit to the channel, and simply never applied
-- that judgement outside the retreat branch. Reusing the constant makes the two
-- consistent instead of introducing a second opinion. The two pinned frames
-- bracket it far from either edge -- 26.3% must be caught, 51.5% must be
-- released -- so any floor in (0.264, 0.514] reproduces both verdicts.
--
-- The 2.0s fire window matches the one this file already uses in ConsiderQ.
--
-- Deliberately NOT written (one lever at a time): an exemption for the
-- desperation teamfight (low health, many allies alive around her, ultimate wins
-- the fight anyway). It would need its own frame evidence, and its absence is
-- the conservative direction -- a false veto costs one ultimate, a false release
-- cost her the game's life in frame A.
--
-- Gated turbo + 'cmrself', and gated SEPARATELY from 'cmrguard' above: arming
-- either id alone changes behaviour on its own, so neither one's batch reading
-- is a measurement of the other (the `axeblink` trap, where a candidate's only
-- consumer was unreachable unless a second id was armed too). Arming 'cmrguard'
-- alone remains byte-for-byte what it was before this clause existed.
--
-- PRE-FLIGHT CORPUS CHECK 2026-08-21T10:xxZ -- DO NOT SPEND AN ARM ON THIS ID.
-- 17 turbo games (replays/20260820_10*, CM in 17/17; the wave GH #66 frame A
-- itself came from), tool `tools/batch_test/behavioral/cm_r_selfstate_domain.py`.
-- Verdict is neither of the two previous shapes: the domain is NOT empty (this
-- is not the `axeblink` trap) and it is NOT reachable either --
--
--     armed != shipped on 1 FRAME / 1 EPISODE / 1 of 17 games (0.06/game),
--
-- versus 0.76 episodes/game for `odaoe`, the first candidate this stream
-- cleared. And the cause is NOT that the gate rarely triggers: the predicate
-- alone (below the floor, under hero fire, ult castable, out of base) holds on
-- 31 frames = 13 EPISODES in 9 of 17 games. It is the branch BELOW that never
-- co-occurs with it. On exactly those 31 frames the enemy count inside
-- nRadius is {0: 16, 1: 7, 2: 8} -- it never reaches the 3 that branch 1's
-- first clause wants -- and `aoeCanHurtCount >= 2` holds once. The two
-- predicates are ANTI-CORRELATED rather than nested: a CM below 38% and taking
-- hero damage is a support being chased, not one standing in a three-man
-- teamfight, and the teamfight branch is the only health-blind path that ever
-- fires (branch 3 already carries this file's own `nHP > 0.38`).
--
-- The one domain frame is 20260820_103216_slot1 t=473.5 -- GH #66 frame A, the
-- frame that motivated the clause, already pinned in
-- tests/fixtures/f_260820_103216_cm_es_aftershock.lua. So the case is real and
-- correctly diagnosed; it is simply a once-per-17-games case. Outcome side
-- agrees: of 17 real Freezing Field casts across the 17 games exactly 1 is
-- inside the gate's domain, and CM died 0.2s into that channel.
--
-- The reading is robust where it can be checked and fragile where it cannot:
-- swapping the audited `is_dead()` liveness for the GH #78 `hp > 0` proxy adds
-- 4 predicate frames and 0 domain frames, but the single domain frame rests on
-- `aoeCanHurtCount`, whose ring is `nRadius * 0.82 - GetCurrentMovementSpeed()`
-- and movespeed is not in the .dem: at ms >= 330 the domain is 0.
--
-- CONSEQUENCE: leave armed-and-parked. A batch arm spent here cannot produce a
-- condition (b) reading -- 0.06 episodes/game is below the noise of every
-- detector we have -- so the id should not be scheduled against `odaoe` and the
-- other waiting ids. Re-measure if any of these change: branch 1's
-- `#nEnemysHeroesInRange >= 3` is lowered, the `aoeCanHurtCount` ring is
-- widened, or a grouping change makes CM fight alongside her team while low.
X.nRSelfHpFloor = 0.38
X.nRSelfFireWindow = 2.0

function X.cm_IsRSafeToOpen( hBot )
	if not J.IsModeTurbo() then return true end

	if J.IsSoakCandidate( 'cmrguard' )
	then
		local tEnemies = J.GetNearbyHeroes( hBot, 1600, true, BOT_MODE_NONE )
		for _, e in pairs( tEnemies or {} )
		do
			if J.IsValid( e )
			then
				local hCc = J.GetReadyHardCc( e )
				if hCc ~= nil
				then
					local nCcRange = hCc:GetCastRange() or 0
					if J.IsSoakCandidate( 'cmrcap' )
					then
						nCcRange = math.min( nCcRange, X.nRGuardRangeCap )
					end

					if GetUnitToUnitDistance( hBot, e ) <= nCcRange + X.nRGuardCloseBuffer
					then
						return false
					end
				end
			end
		end
	end

	if J.IsSoakCandidate( 'cmrself' )
	and J.GetHP( hBot ) < X.nRSelfHpFloor
	and hBot:WasRecentlyDamagedByAnyHero( X.nRSelfFireWindow )
	then
		return false
	end

	return true
end

function X.ConsiderR()

	if not abilityR:IsFullyCastable()
		or bot:DistanceFromFountain() < 300
		or not X.cm_IsRSafeToOpen( bot )
	then
		return BOT_ACTION_DESIRE_NONE
	end


	local nRadius = abilityR:GetAOERadius() * 0.88

	local nAllies =  J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE )

	local nEnemysHeroesInRange = J.GetNearbyHeroes(bot, nRadius, true, BOT_MODE_NONE )
	local nWeakestEnemyHeroInRange, nWeakestEnemyHeroHealth1 = X.cm_GetWeakestUnit( nEnemysHeroesInRange )


	local aoeCanHurtCount = 0
	for _, enemy in pairs ( nEnemysHeroesInRange )
	do
		if J.IsValid( enemy )
			and J.CanCastOnNonMagicImmune( enemy )
			and ( J.IsDisabled( enemy )
				  or J.IsInRange( bot, enemy, nRadius * 0.82 - enemy:GetCurrentMovementSpeed() ) )
		then
			aoeCanHurtCount = aoeCanHurtCount + 1
		end
	end
	if bot:GetActiveMode() ~= BOT_MODE_RETREAT
		or ( bot:GetActiveMode() == BOT_MODE_RETREAT and bot:GetActiveModeDesire() <= 0.85 )
	then
		if ( #nEnemysHeroesInRange >= 3 or aoeCanHurtCount >= 2 )
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end


	if J.IsGoingOnSomeone( bot )
	then
		local npcTarget = J.GetProperTarget( bot )
		if J.IsValidHero( npcTarget )
			and J.CanCastOnNonMagicImmune( npcTarget )
			and ( J.IsDisabled( npcTarget ) or J.IsInRange( bot, npcTarget, 280 ) )
			and npcTarget:GetHealth() <= npcTarget:GetActualIncomingDamage( bot:GetOffensivePower() * 1.5, DAMAGE_TYPE_MAGICAL )
			and GetUnitToUnitDistance( npcTarget, bot ) <= nRadius
			and npcTarget:GetHealth() > 400
			and #nAllies <= 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	if J.IsRetreating( bot ) and nHP > 0.38
	then
		local nEnemysHeroesNearby = J.GetNearbyHeroes(bot, 500, true, BOT_MODE_NONE )
		local nEnemysHeroesFurther = J.GetNearbyHeroes(bot, 1300, true, BOT_MODE_NONE )
		local npcTarget = nEnemysHeroesNearby[1]
		if J.IsValidHero( npcTarget )
			and J.CanCastOnNonMagicImmune( npcTarget )
			and not abilityQ:IsFullyCastable()
			and not abilityW:IsFullyCastable()
			and nHP > 0.38 * #nEnemysHeroesFurther
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	return BOT_ACTION_DESIRE_NONE

end

--- [cmclone] GH #206 -- `GRANTSLOT`, the Crystal Maiden half of GH #203.
---
--- `sAbilityList` is NOT this hero's slot array.  It is the array
--- `J.Skill.GetAbilityList` COMPACTS out of slots 0..10 with `table.insert`
--- (bots/FunLib/aba_skill.lua); the only fixed index is 6, written directly for
--- the ultimate.  So index N means "the Nth ability the walk ACCEPTED", and any
--- ability the walk accepts ahead of the one you meant shifts it by one.
---
--- Crystal Maiden's slot order (datafeed hero_id=5, read 2026-08-26):
---
---     slot 0  crystal_maiden_crystal_nova
---     slot 1  crystal_maiden_frostbite
---     slot 2  crystal_maiden_brilliance_aura
---     slot 3  crystal_maiden_crystal_clone    ability_is_granted_by_shard
---     slot 4  crystal_maiden_glacial_guard    ability_is_innate
---     slot 5  crystal_maiden_freezing_field   ultimate -> index 6
---
--- The walk drops an ability only when NOT_LEARNABLE **and** IsHidden() are both
--- true.  Enumerating the drop decision over the two optional abilities gives
--- four worlds, and index 4 is Crystal Clone in only two of them: it is the
--- INNATE in one and the empty-slot placeholder `generic_hidden` in one
--- (tests/test_cm_ability_index_binding.lua).
---
--- ⭐ AND THE CORPUS PICKS THE WORLD, because IsHidden() turned out to be
--- readable offline after all -- in one direction.  The behavioural dumper
--- (tools/batch_test/behavioral/dumper/main.go, isRealAbility) walks the same
--- `m_vecAbilities` and drops every entry with `m_bHidden` set.  So an ability
--- PRESENT in a fixture frame's array was not hidden on that frame.  Wraith
--- King's and Lion's innates are present on 31/31 and 23/23 frames; Crystal
--- Maiden's ability array is exactly four entries on 51/51 frames, with the
--- innate and the shard grant on ZERO -- against a live denominator, since
--- zuus_lightning_hands (a shard grant) does appear on one Zeus frame.
--- ⇒ both of her optional abilities are hidden, both are dropped, and index 4
--- falls to the fourth world.  What lands there is NOT nil: the walk name-checks
--- `generic_hidden` (a file-local string, aba_skill.lua:5) BEFORE it applies the
--- drop rule, so an empty engine slot is kept whatever its flags say -- and with
--- three abilities in front of the fixed index 6, `#{1,2,3,[6]}` answers 3 on
--- this VM and the first placeholder lands squarely on index 4.  So the shipped
--- `CrystalClone` is a handle to `generic_hidden`: `IsTrained()` is false, the
--- branch answers NONE forever, and nothing raises.  Silent, not loud.
---
--- The same corpus CONFIRMS the slot order rather than assuming it (the
--- assumption GH #203 had to declare): the ultimate reaches the fixed index 6
--- only from `slot >= 4`, she has just three always-visible abilities, and her
--- ultimate is on cooldown on 10 of those 51 frames -- so it WAS cast, so index
--- 6 was written, so at least one optional ability really does sit ahead of it.
---
--- And the binding is frozen: `sAbilityList` is computed once at file scope,
--- before any shard exists.  Turbo hands out a free Aghanim's Shard at 15:00,
--- which GH #108's cap=25 finally puts inside the scored window -- and this
--- handle would still be the one resolved at t=0.  Crystal Clone is unreachable
--- for the whole game, in every game, and that is index arithmetic rather than a
--- decision anyone made.
---
--- ⚠️ The nil check below is UNGATED (the split GH #188 / #192 / #203 settled:
--- forced repairs ship, policy ships gated) -- and it is INSURANCE, not the
--- repair of an observed nil.  Say it that way when citing this.  `#` over a
--- table with a hole is UNSPECIFIED in Lua 5.1: this VM answers 3 for
--- `#{1,2,3,[6]}` and hands index 4 the placeholder, but a VM answering 6 would
--- append past the hole and leave index 4 nil.  Both answers are legal and the
--- game VM's is not readable from here.  In that second world the shipped
--- `CrystalClone:IsTrained()` raises inside X.SkillsComplement, the engine's
--- error handler is broken (AGENTS.md), and since this branch sits ABOVE
--- ConsiderQ/W/R the whole spell dispatch dies silently.  The corpus says that
--- is not what ships today -- her ultimate is on cooldown on 10 of 51 frames,
--- and the only Freezing Field cast site in the repo is below this branch.
---
--- Binding by name is this repo's majority pattern, not an invention: GH #203
--- counted 40 file-scope sites under bots/BotLib that already fetch a shard or
--- scepter ability by literal name.  That count is CARRIED FORWARD from #203
--- rather than re-measured here.
function X.GetBoundAbility( hShipped, sName )

	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmclone' )
	then
		local hNamed = bot:GetAbilityByName( sName )
		if hNamed ~= nil then return hNamed end
	end

	return hShipped

end

function X.ConsiderCrystalClone()
	local hClone = X.GetBoundAbility( CrystalClone, 'crystal_maiden_crystal_clone' )

	if hClone == nil
	or not hClone:IsTrained()
	or not hClone:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE
	end

	local nRadius = 450
	local botTarget = J.GetProperTarget(bot)

	if J.IsGoingOnSomeone(bot)
	then
		if J.IsValidTarget(botTarget)
		and J.IsInRange(bot, botTarget, nRadius)
		and J.CanCastOnNonMagicImmune(botTarget)
		and not J.IsSuspiciousIllusion(botTarget)
		and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
		then
			local nInRangeAlly = J.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local nInRangeEnemy = J.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)

			if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
			and #nInRangeAlly >= #nInRangeEnemy
			then
				return BOT_ACTION_DESIRE_HIGH, J.Site.GetXUnitsTowardsLocation(bot, J.GetTeamFountain(), nRadius)
			end
		end
	end

    if J.IsRetreating(bot)
    then
        local nInRangeEnemy = J.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)

        if nInRangeEnemy ~= nil and #nInRangeEnemy >= 1
        and J.IsValidHero(nInRangeEnemy[1])
        and J.IsInRange(bot, nInRangeEnemy[1], nRadius)
        and not J.IsSuspiciousIllusion(nInRangeEnemy[1])
        then
            local nInRangeAlly = J.GetNearbyHeroes(nInRangeEnemy[1], 1200, true, BOT_MODE_NONE)
            local nTargetInRangeAlly = J.GetNearbyHeroes(nInRangeEnemy[1], 1200, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
            and (#nTargetInRangeAlly > #nInRangeAlly
                or bot:WasRecentlyDamagedByAnyHero(1))
            then
		        return BOT_ACTION_DESIRE_HIGH, J.Site.GetXUnitsTowardsLocation(bot, J.GetTeamFountain(), nRadius)
            end
        end
    end

	return BOT_ACTION_DESIRE_NONE
end

function X.cm_GetWeakestUnit( nEnemyUnits )

	local nWeakestUnit = nil
	local nWeakestUnitLowestHealth = 10000
	for _, unit in pairs( nEnemyUnits )
	do
		if 	J.CanCastOnNonMagicImmune( unit )
		then
			if unit:GetHealth() < nWeakestUnitLowestHealth
			then
				nWeakestUnitLowestHealth = unit:GetHealth()
				nWeakestUnit = unit
			end
		end
	end

	return nWeakestUnit, nWeakestUnitLowestHealth
end

function X.cm_GetStrongestUnit( nEnemyUnits )

	local nStrongestUnit = nil
	local nStrongestUnitHealth = GetBot():GetAttackDamage()

	for _, unit in pairs( nEnemyUnits )
	do
		if 	unit ~= nil and unit:IsAlive()
			and not unit:HasModifier( 'modifier_fountain_glyph' )
			and not unit:IsMagicImmune()
			and not unit:IsInvulnerable()
			and unit:GetHealth() <= 1100
			and not unit:IsAncientCreep()
			and unit:GetMagicResist() < 1.05 - unit:GetHealth()/1100
			and not J.IsOtherAllysTarget( unit )
			and string.find( unit:GetUnitName(), 'siege' ) == nil
			and ( nLV < 25 or unit:GetTeam() == TEAM_NEUTRAL )
		then
			if string.find( unit:GetUnitName(), 'ranged' ) ~= nil
				and unit:GetHealth() > GetBot():GetAttackDamage() * 2
			then
				return unit, 500
			end

			if unit:GetHealth() > nStrongestUnitHealth
			then
				nStrongestUnitHealth = unit:GetHealth()
				nStrongestUnit = unit
			end
		end
	end

	return nStrongestUnit, nStrongestUnitHealth
end

return X
-- dota2jmz@163.com QQ:2462331592..
