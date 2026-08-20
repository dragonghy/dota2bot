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
						['t20'] = {0, 10},
						['t15'] = {0, 10},
						['t10'] = {10, 0},
}

local tAllAbilityBuildList = {
						{1,3,1,2,1,6,1,2,2,2,6,3,3,3,6},--pos2
						{2,1,2,3,2,6,2,1,1,1,6,3,3,3,6},--pos4,5
}

local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == 'pos_2' then nAbilityBuildList = tAllAbilityBuildList[1] end
if sRole == 'pos_4' then nAbilityBuildList = tAllAbilityBuildList[2] end
if sRole == 'pos_5' then nAbilityBuildList = tAllAbilityBuildList[2] end

local nTalentBuildList = J.Skill.GetTalentBuild(tTalentTreeList)
if sRole == 'pos_2' then nTalentBuildList = J.Skill.GetTalentBuild(tTalentTreeList) end
if sRole == 'pos_4' then nTalentBuildList = J.Skill.GetTalentBuild(tTalentTreeList) end
if sRole == 'pos_5' then nTalentBuildList = J.Skill.GetTalentBuild(tTalentTreeList) end

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_2'] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",

	"item_bottle",
	"item_magic_wand",
	"item_arcane_boots",
	"item_phylactery",
	"item_aghanims_shard",
	"item_kaya_and_sange",--
	"item_travel_boots",
	"item_black_king_bar",--
	"item_ultimate_scepter",
	"item_angels_demise",--
	"item_octarine_core",--
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",--
	"item_travel_boots_2",--
}

sRoleItemsBuyList['pos_3'] = {
	"item_mage_outfit",
	"item_soul_ring",
	"item_glimmer_cape",--
	"item_aghanims_shard",
	"item_kaya_and_sange",--
	"item_shivas_guard",--
	"item_cyclone",
	"item_ultimate_scepter",
	"item_sheepstick",--
	"item_wind_waker",--
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_octarine_core",--
}

sRoleItemsBuyList['pos_1'] = {
	"item_tango",
	"item_double_branches",

	"item_magic_wand",
	"item_arcane_boots",
	"item_phylactery",
	"item_aghanims_shard",
	"item_kaya_and_sange",--
	"item_travel_boots",
	"item_black_king_bar",--
	"item_ultimate_scepter",
	"item_angels_demise",--
	"item_octarine_core",--
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",--
	"item_travel_boots_2",--
}

sRoleItemsBuyList['pos_4'] = {
	"item_priest_outfit",
	"item_mekansm",
	"item_aether_lens",
	"item_glimmer_cape",--
	"item_aghanims_shard",
	"item_guardian_greaves",--
	"item_spirit_vessel",--
--	"item_wraith_pact",
	"item_ultimate_scepter",
	"item_shivas_guard",--
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",--
}

sRoleItemsBuyList['pos_5'] = {
    "item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_aether_lens",
	"item_glimmer_cape",--
	"item_pipe",--
	"item_boots_of_bearing",--
    "item_ultimate_scepter",
	"item_cyclone",
--	"item_wraith_pact",
	"item_shivas_guard",
	"item_sheepstick",--
	'item_wind_waker',
	"item_moon_shard",
	"item_ultimate_scepter_2",
}

X['sBuyList'] = sRoleItemsBuyList[sRole]

X['sSellList'] = {

	"item_black_king_bar",
	"item_quelling_blade",

}

if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_mage' }, {} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )

X['bDeafaultAbility'] = false
X['bDeafaultItem'] = true

function X.MinionThink(hMinionUnit)

	if Minion.IsValidUnit( hMinionUnit )
		and hMinionUnit:GetUnitName() ~= 'npc_dota_zeus_cloud'
	then
		Minion.IllusionThink( hMinionUnit )
	end

end

local abilityQ = bot:GetAbilityByName( sAbilityList[1] )
local abilityW = bot:GetAbilityByName( sAbilityList[2] )
local abilityE = bot:GetAbilityByName( sAbilityList[3] )
local abilityD = bot:GetAbilityByName( sAbilityList[4] )
local abilityAS = bot:GetAbilityByName( sAbilityList[5] )
local abilityR = bot:GetAbilityByName( sAbilityList[6] )

local talent5 = bot:GetAbilityByName( sTalentList[5] )
local talent7 = bot:GetAbilityByName( sTalentList[7] )
local talent8 = bot:GetAbilityByName( sTalentList[8] )

local castQDesire, castQTarget
local castWDesire, castWTarget
local castW2Desire, castWLocation, castW2Target
local castDDesire, castDLocation
local castRDesire
local castEDesire, castETarget


local nKeepMana, nMP, nHP, nLV, hEnemyHeroList
local aetherRange = 0
local talentDamage = 0


local abilityASBonus = 0

-- [zusult] A healthy enemy is worth less than a ready global execute.
--
-- Thundergod's Wrath is a ~130s cooldown, map-wide finisher: it is the ONLY
-- tool Zeus owns that reaches a target he cannot walk to. Watched
-- 20260819_142047_slot1: Zeus dinged 6 at t=213.5 holding 55 mana, then spent
-- 94 on Arc Lightning (t=225.5) and 49 on Heavenly Jump (t=241.5), both into a
-- dragon_knight sitting at 971/1072 HP who regenerated all of it back inside
-- 20s. At t=278.5 an enemy lich dropped to 149 HP and then 11 HP, 7678 away --
-- a free kill for a global nuke -- and Zeus stood there with 190 mana against
-- the ult's 246 cost. `abilityR:IsFullyCastable()` was false, so ConsiderR bailed
-- on its first line. The lich died to somebody else 4.5s later; Zeus's first ult
-- of the game came at t=296.2, once regen alone had carried him back over the
-- cost.
--
-- So the reserve is only worth defending against CHIP: this refuses the spend
-- when the ult is armed-but-unaffordable and the target is still healthy. A kill
-- window (target under nUltSaveHealthFloor) and self-preservation while
-- retreating both outrank the reserve and are let through untouched.
--
-- GH #47 (first execution audit of this gate, on the batch's own replays): the
-- gate was wired to ConsiderQ and ConsiderW only. Q never leaked; W leaked three
-- times, because W is the one ability handle with a SECOND consumer -- ConsiderW2
-- -- and the held bid simply fell through to it and spent the identical mana on
-- the identical target. All three consumption points now share this one gate and
-- this one candidate id.
--
-- [zusultx] GH #59 -- the SECOND audit of this gate, on the 04:11Z evidence
-- wave, found the W leak closed (0 domain casts, down from 3) and then found
-- that the gate is structurally blind on the only frame that can change the
-- outcome. The clause below reads the mana Zeus holds BEFORE the spend, so its
-- effective domain is exactly "the reserve is ALREADY gone": at mana >= nCost
-- -- the one moment there is still something left to protect -- it stands
-- aside, and at mana < nCost -- after the reserve has been spent -- it starts
-- holding. It was never guarding the ultimate; it was guarding the regen that
-- follows losing it.
--
-- Measured, 20260820_042607_slot1 (Zeus armed, seed 872 radiant):
--   t=462.3  item_arcane_boots (+175) carries him 104 -> 256 mana. The ult is
--            level 1, cooldown 0, and now AFFORDABLE: castable this instant.
--   t=462.5  <-- THE FRAME. lion stands 499.7 away at 1.00 HP. The gate is
--            asked and answers "nothing is being denied" -- clause 7.
--   t=462.9  Lightning Bolt (ground, the W2 path) into that full-HP lion,
--            ~130 mana gone. The reserve is spent 0.4s after it arrived.
--   463.5..491.5  the gate dutifully holds 57 straight frames of chip -- the
--            reserve it is protecting no longer exists.
--   t=492.2  Zeus dies holding 116 mana with Thundergod's Wrath still level 1
--            and still cooldown 0: ready and unaffordable, 29.7s after the one
--            spend that could have been refused.
--
-- So the fix is to ask the question at the instant it is actually about: not
-- "can he pay for the ult right now" but "can he STILL pay for it after this
-- spend". The gate takes the bid's own ability handle and subtracts its cost.
-- This is deliberately a SEPARATE candidate id: it strictly widens an
-- already-armed gate's domain (post-spend affordability implies pre-spend
-- affordability, never the reverse), and widening the reach of a rule that has
-- not yet cleared condition (b) is the `lanefix` failure mode. Arming `zusult`
-- alone keeps the shipped narrow domain; arming `zusultx` runs the widened one,
-- so the increment is one subtraction between two waves and never the sum of
-- two rules. Neither id is inert on its own -- there is no arm-and-nothing-
-- happens combination here.
--
-- The widening is bounded and small: post-spend only differs from pre-spend
-- while mana sits in [nCost, nCost + spend), a ~130-wide band for a Bolt.
X.nUltSaveHealthFloor = 0.6

function X.zuus_ShouldSaveManaForUlt( hBot, hTarget, hSpell )

	if not J.IsModeTurbo() then return false end
	local bPostSpend = J.IsSoakCandidate( 'zusultx' )
	if not bPostSpend and not J.IsSoakCandidate( 'zusult' ) then return false end

	if hBot == nil or abilityR == nil then return false end
	if not abilityR:IsTrained() then return false end
	if abilityR:GetCooldownTimeRemaining() > 0 then return false end

	local nCost = abilityR:GetManaCost()
	if nCost == nil or nCost <= 0 then return false end

	-- What this bid is about to cost. Only `zusultx` subtracts it; with only
	-- `zusult` armed nSpend stays 0 and the clause below is byte-equivalent to
	-- the shipped one.
	local nSpend = 0
	if bPostSpend and hSpell ~= nil
	then
		local nSpellCost = hSpell:GetManaCost()
		if type( nSpellCost ) == 'number' and nSpellCost > 0 then nSpend = nSpellCost end
	end

	-- Still affordable AFTER this spend: nothing is being denied. (GH #59: with
	-- nSpend = 0 this is the shipped "already affordable" test, which asked the
	-- question one spend too early.)
	if hBot:GetMana() - nSpend >= nCost then return false end

	-- Fleeing beats hoarding.
	if J.IsRetreating( hBot ) then return false end

	-- Creeps/other units keep the shipped rules -- farm is not this gate's business.
	if not J.IsValidHero( hTarget ) then return false end

	-- A kill in hand is worth more than a snipe later.
	if J.GetHP( hTarget ) < X.nUltSaveHealthFloor then return false end

	return true

end


function X.SkillsComplement()


	if J.CanNotUseAbility( bot ) or bot:IsInvisible() then return end

	nKeepMana = 400
	aetherRange = 0
	talentDamage = 0
	abilityASBonus = 0
	nLV = bot:GetLevel()
	nMP = bot:GetMana()/bot:GetMaxMana()
	nHP = bot:GetHealth()/bot:GetMaxHealth()
	nManaPercentage = bot:GetMana()/bot:GetMaxMana()
	nHealthPercentage = bot:GetHealth()/bot:GetMaxHealth()
	hEnemyHeroList = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )

	local aether = J.IsItemAvailable( "item_aether_lens" )
	if aether ~= nil then aetherRange = 250 end
	if abilityAS:IsTrained() then abilityASBonus = 0.09 end
	if talent8:IsTrained() then talentDamage = talentDamage + talent8:GetSpecialValueInt( "value" ) end

	castRDesire = X.ConsiderR()
	if ( castRDesire > 0 )
	then

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbility( abilityR )
		return

	end

	castWDesire, castWTarget = X.ConsiderW()
	-- GH #59: the bid's own handle rides along, so `zusultx` can price the spend.
	if ( castWDesire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castWTarget, abilityW ) )
	then
		castWDesire = 0
	end
	if ( castWDesire > 0 )
	then

		J.SetQueuePtToINT( bot, true )
		
		
		if talent7:IsTrained() 
		then
			bot:ActionQueue_UseAbilityOnLocation( abilityW, castWTarget:GetLocation() )
		else
			bot:ActionQueue_UseAbilityOnEntity( abilityW, castWTarget )
		end
		
		return
	end

	castW2Desire, castWLocation, castW2Target = X.ConsiderW2()
	-- GH #47: W is the one handle with two consumers. Holding ConsiderW's bid
	-- alone just let the very same mana leave through ConsiderW2 at the very
	-- same target on the very next line -- measured, not predicted (3 domain
	-- casts on the armed side, 0 leaked Q casts). ConsiderW2 only reports a
	-- target for its poke branches, so kill windows and channel interrupts
	-- reach the gate as nil and are never held.
	if ( castW2Desire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castW2Target, abilityW ) )
	then
		castW2Desire = 0
	end
	if ( castW2Desire > 0 )
	then

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbilityOnLocation( abilityW, castWLocation )
		return
	end

	castQDesire, castQTarget = X.ConsiderQ()
	if ( castQDesire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castQTarget, abilityQ ) )
	then
		castQDesire = 0
	end
	if ( castQDesire > 0 )
	then

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbilityOnEntity( abilityQ, castQTarget )
		return
	end

	castDDesire, castDLocation = X.ConsiderD()
	if ( castDDesire > 0 )
	then

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbilityOnLocation( abilityD, castDLocation )
		return
	end
	
	castEDesire = X.ConsiderE()
	if ( castEDesire > 0 )
	then
	
		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbility( abilityE )
		return

	end

end

function X.ConsiderQ()

	if not abilityQ:IsFullyCastable() then	return BOT_ACTION_DESIRE_NONE, nil	end
	-- [lanefix] Conserve mana in lane: skip harass Arc Lightning when low on mana
	-- and no kill is on the table (the helper exempts a killable enemy in range).
	if J.ShouldConserveManaInLane( bot ) then return BOT_ACTION_DESIRE_NONE, nil end

	local nCastRange = abilityQ:GetCastRange()
	local nCastPoint = abilityQ:GetCastPoint()
	local manaCost = abilityQ:GetManaCost()
	local nRadius = abilityQ:GetSpecialValueInt( "radius" )
	local nDamage = abilityQ:GetSpecialValueInt( "arc_damage" )
	local nEnemyHeroesInSkillRange = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )

	for _, npcEnemy in pairs( nEnemyHeroesInSkillRange )
	do
		if J.IsValidHero( npcEnemy )
			and J.CanCastOnNonMagicImmune( npcEnemy )
			and J.CanCastOnTargetAdvanced( npcEnemy )
			and J.GetHP( npcEnemy ) <= 0.2
		then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy
		end
	end


	--对线期的使用
	if bot:GetActiveMode() == BOT_MODE_LANING
	then
		local hLaneCreepList = bot:GetNearbyLaneCreeps( nCastRange + 50, true )
		for _, creep in pairs( hLaneCreepList )
		do
			if J.IsValid( creep )
				and not creep:HasModifier( "modifier_fountain_glyph" )
				and J.IsEnemyTargetUnit( creep, 1400 )
				and J.WillKillTarget( creep, nDamage, DAMAGE_TYPE_MAGICAL, nCastPoint )
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end

	end


	if J.IsRetreating( bot ) and bot:WasRecentlyDamagedByAnyHero( 2.0 )
	then
		local target = J.GetVulnerableWeakestUnit( bot, true, true, nCastRange )
		if target ~= nil
			and J.CanCastOnTargetAdvanced( target )
			and bot:IsFacingLocation( target:GetLocation(), 45 )
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end

	if J.IsInTeamFight( bot, 1300 )
	then
		local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0 )
		if ( locationAoE.count >= 2 ) then
			local target = J.GetVulnerableUnitNearLoc( bot, true, true, nCastRange, nRadius, locationAoE.targetloc )
			if target ~= nil and J.CanCastOnTargetAdvanced( target ) then
				return BOT_ACTION_DESIRE_HIGH, target
			end
		end
	end

	if ( J.IsPushing( bot ) or J.IsDefending( bot ) ) and J.IsAllowedToSpam( bot, manaCost )
	then
		local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0 )
		if ( locationAoE.count >= 3 ) then
			local target = J.GetVulnerableUnitNearLoc( bot, false, true, nCastRange, nRadius, locationAoE.targetloc )
			if target ~= nil then
				return BOT_ACTION_DESIRE_HIGH, target
			end
		end
	end

	if J.IsGoingOnSomeone( bot )
	then
		local target = J.GetProperTarget( bot )
		if J.IsValidHero( target )
			and J.CanCastOnNonMagicImmune( target )
			and J.CanCastOnTargetAdvanced( target )
			and J.IsInRange( target, bot, nCastRange )
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end

	--Farming: use Arc Lightning on neutral/lane creeps
	if J.IsFarming( bot ) and J.GetManaAfter( manaCost ) > 0.3
	then
		local nNeutralCreeps = bot:GetNearbyNeutralCreeps( nCastRange )
		if #nNeutralCreeps >= 2
			or ( #nNeutralCreeps >= 1 and J.IsValid( nNeutralCreeps[1] ) and nNeutralCreeps[1]:IsAncientCreep() )
		then
			return BOT_ACTION_DESIRE_HIGH, nNeutralCreeps[1]
		end
		local nLaneCreeps = bot:GetNearbyLaneCreeps( nCastRange, true )
		if #nLaneCreeps >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, nLaneCreeps[1]
		end
	end

	--Roshan: use Arc Lightning on Roshan
	if J.IsDoingRoshan( bot )
	then
		local botTarget = J.GetProperTarget( bot )
		if J.IsRoshan( botTarget )
			and J.IsInRange( bot, botTarget, nCastRange )
			and J.GetManaAfter( manaCost ) > 0.3
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderW()

	if not abilityW:IsFullyCastable() then return BOT_ACTION_DESIRE_NONE, nil end
	-- [lanefix] Conserve mana in lane: skip harass Lightning Bolt when low on mana
	-- and no kill is available (helper exempts a killable enemy in range).
	if J.ShouldConserveManaInLane( bot ) then return BOT_ACTION_DESIRE_NONE, nil end

	local nCastRange = abilityW:GetCastRange()
	local nCastPoint = abilityW:GetCastPoint()
	local manaCost = abilityW:GetManaCost()
	local nDamage = abilityW:GetAbilityDamage() * ( 1 + bot:GetSpellAmp() )

	if J.IsRetreating( bot ) and bot:WasRecentlyDamagedByAnyHero( 2.0 )
	then
		local target = J.GetVulnerableWeakestUnit( bot, true, true, nCastRange )
		if target ~= nil and J.CanCastOnTargetAdvanced( target ) then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end

	if J.IsGoingOnSomeone( bot )
	then
		local target = J.GetProperTarget( bot )
		if J.IsValidHero( target )
			and J.CanCastOnNonMagicImmune( target )
			and J.CanCastOnTargetAdvanced( target )
			and J.IsInRange( target, bot, nCastRange )
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end

	local targetRanged = X.GetRanged( bot, nCastRange )
	if targetRanged ~= nil
		and targetRanged:GetHealth() < targetRanged:GetActualIncomingDamage( nDamage + targetRanged:GetHealth() * abilityASBonus , DAMAGE_TYPE_MAGICAL )
	then
		return BOT_ACTION_DESIRE_HIGH, targetRanged
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

-- Returns desire, cast location and -- third, added for GH #47 -- the enemy hero
-- the location was aimed at, but ONLY for the poke branches at the bottom. The
-- kill-AoE, channel-interrupt and retreat branches deliberately report no target
-- so that X.zuus_ShouldSaveManaForUlt (which is inert on a nil target) can never
-- stand between Zeus and a kill, an interrupt, or his own escape.
function X.ConsiderW2()

	if not abilityW:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nCastRange = abilityW:GetCastRange()
	local nCastPoint = abilityW:GetCastPoint()
	local manaCost = abilityW:GetManaCost()
	local nDamage = abilityW:GetAbilityDamage()
	local nRadius = 325

	local nAllies = J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE )

	local nEnemyHeroesInSkillRange = J.GetNearbyHeroes(bot, nCastRange + nRadius, true, BOT_MODE_NONE )
	local nWeakestEnemyHeroInSkillRange = J.GetVulnerableWeakestUnit( bot, true, true, nCastRange + nRadius )
	local nCanKillHeroLocationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius , 0.3, nDamage )

	if nCanKillHeroLocationAoE.count >= 1
	then
		if J.IsValid( nWeakestEnemyHeroInSkillRange )
		then
			local nTargetLocation = J.GetCastLocation( bot, nWeakestEnemyHeroInSkillRange, nCastRange, nRadius )
			if nTargetLocation ~= nil
			then
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation
			end
		end
	end

	for _, npcEnemy in pairs( nEnemyHeroesInSkillRange )
	do
		if J.IsValid( npcEnemy )
			and npcEnemy:IsChanneling()
			and not npcEnemy:IsMagicImmune()
		then
			local nTargetLocation = J.GetCastLocation( bot, npcEnemy, nCastRange, nRadius )
			if nTargetLocation ~= nil
			then
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation
			end
		end
	end

	if bot:GetActiveMode() == BOT_MODE_RETREAT
		and ( bot:WasRecentlyDamagedByAnyHero( 2.0 ) or #nAllies >= 3 )
	then
		local nCanHurtHeroLocationAoENearby = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange -200, nRadius -20, 0.8, 0 )
		if nCanHurtHeroLocationAoENearby.count >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, nCanHurtHeroLocationAoENearby.targetloc
		end
	end


	if bot:GetActiveMode() ~= BOT_MODE_RETREAT
	then
		local npcEnemy = J.GetProperTarget( bot )
		if J.IsValidHero( npcEnemy )
			and J.CanCastOnNonMagicImmune( npcEnemy )
			and GetUnitToUnitDistance( npcEnemy, bot ) <= nRadius + nCastRange
		then

			if nManaPercentage > 0.65
				or bot:GetMana() > nKeepMana * 2
			then
				local nTargetLocation = J.GetCastLocation( bot, npcEnemy, nCastRange, nRadius )
				if nTargetLocation ~= nil
				then
					return BOT_ACTION_DESIRE_HIGH, nTargetLocation, npcEnemy
				end
			end

			if npcEnemy:GetHealth()/npcEnemy:GetMaxHealth() < 0.45 or #nAllies >= 3
			then
				local nTargetLocation = J.GetCastLocation( bot, npcEnemy, nCastRange, nRadius )
				if nTargetLocation ~= nil
				then
					return BOT_ACTION_DESIRE_HIGH, nTargetLocation, npcEnemy
				end
			end

		end

		local npcEnemy = nWeakestEnemyHeroInSkillRange
		if J.IsValid( npcEnemy ) and DotaTime() > 0
			and ( npcEnemy:GetHealth()/npcEnemy:GetMaxHealth() < 0.4 or bot:GetMana() > nKeepMana * 2.3 or #nAllies >= 3 )
			and GetUnitToUnitDistance( npcEnemy, bot ) <= nRadius + nCastRange
		then
			local nTargetLocation = J.GetCastLocation( bot, npcEnemy, nCastRange, nRadius )
			if nTargetLocation ~= nil
			then
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, npcEnemy
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderD()

	if not bot:HasScepter()
		or not abilityD:IsFullyCastable()
		or bot:IsInvisible()
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local numPlayer =  GetTeamPlayers( GetTeam() )
	for i = 1, #numPlayer
	do
		local member =  GetTeamMember( i )
		if J.IsValid( member )
			and J.IsGoingOnSomeone( member )
		then
			local target = J.GetProperTarget( member )
			if J.IsValidHero( target )
				and J.IsInRange( member, target, 1200 )
				and J.CanCastOnNonMagicImmune( target )
			then
				return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation( 1.0 )
			end
		end
	end

	--撤退时
	if J.IsRetreating( bot )
	then
		local tableNearbyEnemyHeroes = J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE )
		for _, npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( J.IsValid( npcEnemy ) and bot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) and J.CanCastOnNonMagicImmune( npcEnemy ) )
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderR()

	if not abilityR:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end

	local nCastRange = 1600
	local nCastPoint = abilityR:GetCastPoint()
	local manaCost = abilityR:GetManaCost()
	local nDamage = abilityR:GetSpecialValueInt( 'damage' )
	
	if talent5:IsTrained() then nDamage = nDamage + talent5:GetSpecialValueInt('value') end
	
	local nDamageType = DAMAGE_TYPE_MAGICAL


	if J.IsRetreating( bot ) and bot:WasRecentlyDamagedByAnyHero( 2.0 )
	then
		if bot:GetRespawnTime() > abilityR:GetCooldown()
			and nHealthPercentage <= 0.28
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	-- [ultcash / freehunt#1] The retreat branch above misses the dying bot that
	-- never entered retreat mode (watched 230952 t=9:27: zuus walked forward
	-- into Slardar and died 1.8s later with this ult ready and four enemies at
	-- half HP). If death is imminent regardless of mode, the global nuke is
	-- pure value -- cash it out. Gated (turbo + 'ultcash') inside the helper.
	if J.IsDyingUnderAttack( bot )
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	if J.IsInTeamFight( bot, 1400 )
	then
		local tableNearbyEnemyHeroes = J.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE )
		local nInvUnit = J.GetInvUnitCount( false, tableNearbyEnemyHeroes )
		if nInvUnit >= 5 then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end

	-- modifier_warlock_fatal_bonds
	local lowHPCount = 0
	local fatalCount = 0
	local fatalBonus = false
	local gEnemies = GetUnitList( UNIT_LIST_ENEMY_HEROES )
	for _, e in pairs ( gEnemies )
	do
		if e ~= nil
			and J.CanCastOnNonMagicImmune( e )
		then
			local nEstDamage = nDamage + e:GetHealth() * abilityASBonus
			if J.WillMagicKillTarget( bot, e, nEstDamage, nCastPoint )
				and not J.IsOtherAllyCanKillTarget( bot, e )
			then
				lowHPCount = lowHPCount + 1
			end

			if e:HasModifier( "modifier_warlock_fatal_bonds" )
			then
				fatalCount = fatalCount + 1
				if e:GetHealth() <= e:GetActualIncomingDamage( nEstDamage * 2.28, nDamageType )
				then
					fatalBonus = true
				end
			end
		end
	end
	if lowHPCount >= 1
		or ( fatalCount >= 3 and fatalBonus == true )
	then
		return BOT_ACTION_DESIRE_MODERATE
	end

	return BOT_ACTION_DESIRE_NONE
end

function X.GetRanged( bot, nRadius )
	local mode = bot:GetActiveMode()
	local enemys = J.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE )
	local allies = J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE )

	if mode == BOT_MODE_TEAM_ROAM
		or mode == BOT_MODE_ATTACK
		or mode == BOT_MODE_DEFEND_ALLY
		or mode == BOT_MODE_RETREAT
		or #enemys >= 1
		or #allies >= 3
		or nManaPercentage <= 0.15
		or bot:WasRecentlyDamagedByAnyHero( 2.0 )
	then
		return nil
	end

	if mode == BOT_MODE_LANING or nManaPercentage >= 0.56
	then
		local nTowers = bot:GetNearbyTowers( 1600, false )
		if nTowers[1] ~= nil
		then
			local nTowerTarget = nTowers[1]:GetAttackTarget()
			if J.IsValid( nTowerTarget )
				and not nTowerTarget:HasModifier( 'modifier_fountain_glyph' )
				and J.IsKeyWordUnit( "ranged", nTowerTarget )
				and GetUnitToUnitDistance( nTowerTarget, bot ) <= 1400
				and not J.IsAllysTarget( nTowerTarget )
			then
				return nTowerTarget
			end
		end

		if nManaPercentage > 0.4 and bot:GetMana() > 400
		then
			local nLaneCreeps = bot:GetNearbyLaneCreeps( 990, true )
			for _, creep in pairs( nLaneCreeps )
			do
				if J.IsValid( creep )
					and J.IsKeyWordUnit( "ranged", creep )
					and not creep:HasModifier( 'modifier_fountain_glyph' )
					and not J.IsAllysTarget( creep )
					and creep:GetHealth() < bot:GetAttackDamage()
				then
					return creep
				end
			end
		end
	end

	return nil

end


function X.ConsiderE()

	if not abilityE:IsFullyCastable() 
		or bot:IsRooted()
	then
		return BOT_ACTION_DESIRE_NONE
	end

	local nJumpDistance = 450
	local nSkillLV = abilityE:GetLevel()
	local nCastRange = 600 + nSkillLV * 100
	local nCastPoint = abilityE:GetCastPoint()
	local nManaCost = abilityE:GetManaCost()

	local tableNearbyEnemyHeroes = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )
	

	if J.IsRetreating( bot )
	then
		if J.IsRunning( bot )
		then
			local targetHero = tableNearbyEnemyHeroes[1]
			if J.IsValidHero( targetHero )
				and J.CanCastOnNonMagicImmune( targetHero )
				and not bot:IsFacingLocation( targetHero:GetLocation(), 120 )
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	
	

	if J.IsGoingOnSomeone( bot )
	then
		local targetHero = J.GetProperTarget( bot )
		if J.IsValidHero( targetHero )
			and J.IsInRange( bot, targetHero, nCastRange )
			and J.CanCastOnNonMagicImmune( targetHero )
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	
	return BOT_ACTION_DESIRE_NONE

end


return X