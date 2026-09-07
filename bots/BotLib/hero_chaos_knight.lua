----------------------------------------------------------------------------------------------------
--- The Creation Come From: BOT EXPERIMENT Credit:FURIOUSPUPPY
--- BOT EXPERIMENT Author: Arizona Fauzie 2018.11.21
--- Link:http://steamcommunity.com/sharedfiles/filedetails/?id=837040016
--- Refactor: 决明子 Email: dota2jmz@163.com 微博@Dota2_决明子
--- Link:http://steamcommunity.com/sharedfiles/filedetails/?id=1573671599
--- Link:http://steamcommunity.com/sharedfiles/filedetails/?id=1627071163
----------------------------------------------------------------------------------------------------
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
						['t15'] = {10, 0},
						['t10'] = {0, 10},
}

local tAllAbilityBuildList = {
						{1,2,3,3,3,6,3,2,2,2,6,1,1,1,6},--pos1,3
}

local nAbilityBuildList = J.Skill.GetRandomBuild( tAllAbilityBuildList )

local nTalentBuildList = J.Skill.GetTalentBuild( tTalentTreeList )

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_1'] = {
	"item_bristleback_outfit",
	"item_armlet",
	"item_aghanims_shard",
--	"item_blade_mail",
	"item_heavens_halberd",--
	"item_manta",--
	"item_orchid",
	"item_bloodthorn",--
	"item_travel_boots",
	"item_heart",--
	"item_satanic",--
	"item_moon_shard",
	"item_travel_boots_2",--
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_2'] = sRoleItemsBuyList['pos_1']

sRoleItemsBuyList['pos_3'] = {
	"item_tank_outfit",
	"item_aghanims_shard",
	"item_crimson_guard",--
	"item_armlet",
	"item_heavens_halberd",--
	"item_assault",--
	"item_travel_boots",
	"item_manta",--
	"item_heart",--
	"item_moon_shard",
	"item_travel_boots_2",--
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_4'] = {
	'item_priest_outfit',
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",--
	"item_guardian_greaves",--
    "item_basher",
    "item_monkey_king_bar",--
	"item_assault",--
	"item_heavens_halberd",--
	"item_aghanims_shard",
    "item_abyssal_blade",--
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_5'] = {
	'item_priest_outfit',
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",--
	"item_pipe",--
    "item_basher",
    "item_monkey_king_bar",--
	"item_assault",--
	"item_heavens_halberd",--
	"item_aghanims_shard",
    "item_abyssal_blade",--
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}

X['sBuyList'] = sRoleItemsBuyList[sRole]

X['sSellList'] = {
	"item_power_treads",
	"item_quelling_blade",

	'item_travel_boots',
	'item_armlet',
}

if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_tank' }, {"item_power_treads", 'item_quelling_blade'} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )


X['bDeafaultAbility'] = true
X['bDeafaultItem'] = false

function X.MinionThink(hMinionUnit)

	if Minion.IsValidUnit( hMinionUnit )
	then
		Minion.IllusionThink( hMinionUnit )
	end

end

--[[

npc_dota_hero_chaos_knight

"Ability1"		"chaos_knight_chaos_bolt"
"Ability2"		"chaos_knight_reality_rift"
"Ability3"		"chaos_knight_chaos_strike"
"Ability4"		"generic_hidden"
"Ability5"		"generic_hidden"
"Ability6"		"chaos_knight_phantasm"
"Ability10"		"special_bonus_all_stats_5"
"Ability11"		"special_bonus_movement_speed_20"
"Ability12"		"special_bonus_strength_15"
"Ability13"		"special_bonus_cooldown_reduction_12"
"Ability14"		"special_bonus_gold_income_25"
"Ability15"		"special_bonus_unique_chaos_knight"
"Ability16"		"special_bonus_unique_chaos_knight_2"
"Ability17"		"special_bonus_unique_chaos_knight_3"

modifier_chaos_knight_reality_rift_debuff
modifier_chaos_knight_reality_rift_buff
modifier_chaos_knight_reality_rift
modifier_chaos_knight_chaos_strike
modifier_chaos_knight_chaos_strike_debuff
modifier_chaos_knight_phantasm
modifier_chaos_knight_phantasm_illusion

--]]

local abilityQ = bot:GetAbilityByName( sAbilityList[1] )
local abilityW = bot:GetAbilityByName( sAbilityList[2] )
local abilityR = bot:GetAbilityByName( sAbilityList[6] )
local talent6 = bot:GetAbilityByName( sTalentList[6] )
local abilityArmlet = nil

local castQDesire, castQTarget = 0
local castWDesire, castWTarget = 0
local castRDesire = 0
local botTarget

local nKeepMana, nMP, nHP, nLV, hEnemyHeroList


function X.SkillsComplement()

	if J.CanNotUseAbility( bot ) or bot:IsInvisible() then return end

	botTarget = J.GetProperTarget( bot )
	nKeepMana = 240
	nMP = bot:GetMana()/bot:GetMaxMana()
	nHP = bot:GetHealth()/bot:GetMaxHealth()
	nLV = bot:GetLevel()
	hEnemyHeroList = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )
	abilityArmlet = J.IsItemAvailable( "item_armlet" )

	castRDesire = X.ConsiderR()
	if ( castRDesire > 0 )
	then

		if abilityArmlet ~= nil
			and abilityArmlet:IsFullyCastable()
			and abilityArmlet:GetToggleState() == false
		then
			bot:ActionQueue_UseAbility( abilityArmlet )
		end

		bot:ActionQueue_UseAbility( abilityR )
		return
	end

	castWDesire, castWTarget = X.ConsiderW()
	if ( castWDesire > 0 )
	then

		J.SetQueuePtToINT( bot, false )

		bot:ActionQueue_UseAbilityOnEntity( abilityW, castWTarget )
		return
	end

	castQDesire, castQTarget = X.ConsiderQ()
	if ( castQDesire > 0 )
	then

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbilityOnEntity( abilityQ, castQTarget )
		return
	end



end

function X.ConsiderQ()

	if not abilityQ:IsFullyCastable() then return BOT_ACTION_DESIRE_NONE end

	local nCastRange = abilityQ:GetCastRange()
	local nCastPoint = abilityQ:GetCastPoint()
	local nSkillLV = abilityQ:GetLevel()
	local nDamage = 30 + nSkillLV * 30 + 120 * 0.38

	local nEnemysHeroesInCastRange = J.GetNearbyHeroes(bot, nCastRange + 99, true, BOT_MODE_NONE )
	local nEnemysHeroesInView = J.GetNearbyHeroes(bot, 880, true, BOT_MODE_NONE )

	--击杀
	if #nEnemysHeroesInCastRange > 0 then
		for i=1, #nEnemysHeroesInCastRange do
			if J.IsValid( nEnemysHeroesInCastRange[i] )
				and J.CanCastOnNonMagicImmune( nEnemysHeroesInCastRange[i] )
				and J.CanCastOnTargetAdvanced( nEnemysHeroesInCastRange[i] )
				and nEnemysHeroesInCastRange[i]:GetHealth() < nEnemysHeroesInCastRange[i]:GetActualIncomingDamage( nDamage, DAMAGE_TYPE_MAGICAL )
				and not ( GetUnitToUnitDistance( nEnemysHeroesInCastRange[i], bot ) <= bot:GetAttackRange() + 60 )
				and not J.IsDisabled( nEnemysHeroesInCastRange[i] )
			then
				return BOT_ACTION_DESIRE_HIGH, nEnemysHeroesInCastRange[i]
			end
		end
	end

	--打断
	if #nEnemysHeroesInView > 0 then
		for i=1, #nEnemysHeroesInView do
			if J.IsValid( nEnemysHeroesInView[i] )
				and J.CanCastOnNonMagicImmune( nEnemysHeroesInView[i] )
				and J.CanCastOnTargetAdvanced( nEnemysHeroesInView[i] )
				and nEnemysHeroesInView[i]:IsChanneling()
			then
				return BOT_ACTION_DESIRE_HIGH, nEnemysHeroesInView[i]
			end
		end
	end


	--团战
	if J.IsInTeamFight( bot, 1200 )
		and DotaTime() > 4 * 60
	then
		local npcMostDangerousEnemy = nil
		local nMostDangerousDamage = 0

		for _, npcEnemy in pairs( nEnemysHeroesInCastRange )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not J.IsDisabled( npcEnemy )
				and not npcEnemy:IsDisarmed()
			then
				local npcEnemyDamage = npcEnemy:GetEstimatedDamageToTarget( false, bot, 3.0, DAMAGE_TYPE_ALL )
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


	--常规
	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and J.CanCastOnNonMagicImmune( botTarget )
			and J.CanCastOnTargetAdvanced( botTarget )
			and J.IsInRange( botTarget, bot, nCastRange )
			and not J.IsDisabled( botTarget )
			and not botTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

	--对线期间


	if J.IsRetreating( bot )
	then
		if J.IsValid( nEnemysHeroesInCastRange[1] )
			and J.CanCastOnNonMagicImmune( nEnemysHeroesInCastRange[1] )
			and J.CanCastOnTargetAdvanced( nEnemysHeroesInCastRange[1] )
			and not J.IsDisabled( nEnemysHeroesInCastRange[1] )
			and not nEnemysHeroesInCastRange[1]:IsDisarmed()
			and GetUnitToUnitDistance( bot, nEnemysHeroesInCastRange[1] ) <= nCastRange - 60
		then
			return BOT_ACTION_DESIRE_HIGH, nEnemysHeroesInCastRange[1]
		end
	end


	if bot:GetActiveMode() == BOT_MODE_ROSHAN
		and bot:GetMana() > 400
	then
		local target =  bot:GetAttackTarget()

		if target ~= nil and target:IsAlive()
			and J.GetHP( target ) > 0.2
			and not J.IsDisabled( target )
			and not target:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_LOW, target
		end
	end

	return BOT_ACTION_DESIRE_NONE
end


function X.ConsiderW()

	if not abilityW:IsFullyCastable() or bot:IsRooted() then return BOT_ACTION_DESIRE_NONE end

	local nCastRange = abilityW:GetCastRange()
	local nCastPoint = abilityW:GetCastPoint()
	local nSkillLV = abilityW:GetLevel()
	local nDamage = 0
	local bIgnoreMagicImmune = talent6:IsTrained()

	local nEnemysHeroesInCastRange = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )


	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and J.IsInRange( botTarget, bot, nCastRange + 50 )
			and ( not J.IsInRange( bot, botTarget, 200 ) or not botTarget:HasModifier( 'modifier_chaos_knight_reality_rift' ) )
			and J.CanCastOnNonMagicImmune( botTarget )
			and J.CanCastOnTargetAdvanced( botTarget )
			and not J.IsDisabled( botTarget )
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end


	if J.IsRetreating( bot )
	then
		local enemies = J.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE )
		local creeps = bot:GetNearbyLaneCreeps( nCastRange, true )

		if enemies[1] ~= nil and creeps[1] ~= nil
		then
			for _, creep in pairs( creeps )
			do
				if enemies[1]:IsFacingLocation( bot:GetLocation(), 30 )
					and bot:IsFacingLocation( creep:GetLocation(), 30 )
					and GetUnitToUnitDistance( bot, creep ) >= 650
				then
					return BOT_ACTION_DESIRE_LOW, creep
				end
			end
		end
	end


	if hEnemyHeroList[1] == nil
		and bot:GetAttackDamage() >= 150
	then
		local nCreeps = bot:GetNearbyLaneCreeps( 1000, true )
		for i=1, #nCreeps
		do
			local creep = nCreeps[#nCreeps -i + 1]
			if J.IsValid( creep )
				and not creep:HasModifier( "modifier_fountain_glyph" )
				and J.IsKeyWordUnit( "ranged", creep )
				and GetUnitToUnitDistance( bot, creep ) >= 350
			then
				return BOT_ACTION_DESIRE_LOW, creep
			end
		end
	end

	if J.IsDoingRoshan(bot) then
		if J.IsRoshan(botTarget)
		and J.IsInRange(bot, botTarget, 800)
		and J.CanBeAttacked(botTarget)
		and J.GetHP(botTarget) > 0.5
		and J.IsAttacking(bot)
		and (J.IsEarlyGame() or J.IsMidGame())
		and J.GetManaAfter(abilityR:GetManaCost()) > 0.35
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	if J.IsDoingTormentor(bot) then
		if J.IsTormentor(botTarget)
		and J.IsInRange(bot, botTarget, 800)
		and J.CanBeAttacked(botTarget)
		and J.GetHP(botTarget) > 0.5
		and J.IsAttacking(bot)
		and (J.IsEarlyGame() or J.IsMidGame())
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	return BOT_ACTION_DESIRE_NONE

end

-- [ckpush, 20260902; evidence sentence corrected 20260903, GH #447]
-- SECONDS-PER-MINUTE, and why the shape does NOT settle the repair.
--
-- WHAT THE DEFECT WAS. The push branch of X.ConsiderR below is gated on the
-- value this resolver hands back, and outside turbo that value is still the
-- inherited `8 * 30` -- which is what the defect looked like. `* 30` is
-- the only seconds-per-minute constant in bots/ that is not 60; the one other
-- site that carries it is THE SAME expression, the rubick twin at
-- FunLib/rubick_hero/chaos_knight.lua (left registered-not-fixed on purpose --
-- its domain is empty, so condition (a) is unbuyable for it here). Inherited
-- verbatim from the upstream OHA snapshot (74727e4:485), so it has never read
-- otherwise in this repo's history. The shape says "typo": 8 * 30 = 240s is
-- 8 minutes written with the wrong constant.
--
-- ⚠ THIS COMMENT DELIBERATELY RESTATES NO COUNTS. Section 1 of
-- tests/test_ckpush_minute_unit.lua COUNTS the census over the shipped tree and
-- section 4 counts the fixture-archive readings, so both self-update into a
-- failure when the tree moves. The three counts this paragraph used to restate
-- had ALL drifted from the tree by the time GH #447 read them (`138` sites when
-- the tree held 127, `10` band frames when it held 12, `24` chaos_knight frames
-- when 27 carry one and 24 are alive). Prose that restates a measured number
-- acquires a second, unpinned copy of it; point at the pinned reading instead.
--
-- WHY THE SHAPE IS NOT THE RULING. Repairing the typo REMOVES push-Phantasm
-- from the band 240 < t < 480 -- the stretch where CK's ultimate first comes
-- online -- so it is a REAL turbo behaviour change and its sign is a batch
-- question, not a reading question. That the band is non-empty on real frames,
-- AND non-empty on frames holding a learned Phantasm, is what makes this a
-- lever rather than a registered-not-fixed entry; section 4 counts both.
--
-- ⚠ WHAT THIS COMMENT USED TO CLAIM, AND WHY IT WAS WRONG (GH #447). It said,
-- off the fixture archive, that "no frame at or below 240s carries it at all",
-- and concluded that the shipped 240 NEVER BINDS in turbo. That is a UNIVERSAL
-- drawn from about one game's worth of frames, and 82 games of W41 falsify it:
-- Phantasm is first learned 85.5s earlier than the archive's earliest, i.e.
-- BELOW the shipped 240. What survives is the weaker -- and genuinely
-- different -- claim the ruling actually needs: over those same 82 games there
-- is ZERO push-Phantasm casting at or below 240s, so the shipped 240 does not
-- bind IN EFFECT. Both readings are registered as constants in the test
-- (ARCHIVE / CORPUS_W41) with their domains named, because what failed here was
-- a DOMAIN confusion -- an archive reading worn as a corpus universal -- and
-- not an arithmetic slip.
--
-- The repair shipped as a SELECTION rather than a disjunction, so the gate-off
-- leg was the shipped VALUE; it is now the NON-TURBO leg, and the test still
-- pins that as an equality on real frames rather than as a claim here.
--
-- PROMOTED (was soak-candidate 'ckpush') 2026-09-07 -- turbo default, no gate
-- left; outside turbo the shipped 8 * 30 is untouched, byte for byte. Owner
-- rule 2, all three conditions, each with its own boundary:
--   (a) WORKING -- replay desk 2026-09-03T07:20Z on W41 (82 games of .dem read
--       frame by frame): `VERIFY id=ckpush verdict=WORKING episodes=40`, 40
--       domain frames over 15 games, so the domain is NOT empty and SILENT is
--       refused. The decisive frame is a COUNTERFACTUAL on the baseline leg --
--       20260903_040014_slot4 t=335.5, where the other three HIGH-desire paths
--       of X.ConsiderR are excluded one by one (nearest enemy 1384u > the 1200
--       cast range and > the 700 retreat radius; only 1 enemy within 1600, so
--       the team-fight conjunct is false), CK is taking tier-1 tower damage
--       with 5 allied creeps beside him, and Phantasm is cast 0.3s later. Only
--       the push branch could have opened there.
--       HONEST BOUNDARY, and it must travel with the reading: this is a
--       SUPPRESSION gate, so the armed leg has no positive observable -- what
--       was bought is "the shipped leg really does fire here", not "the armed
--       leg was seen blocking it". And the effect is SMALL: 1 attributable
--       cast in 82 games; in-band cast rate 1.292 vs 1.294 per game, dead even.
--       Report iterations/reports/replay-check/20260903T072000Z.md §4.
--   (b) NO OBVIOUS NEGATIVE -- armed on every leg of W42/W44/W45/W46/W47/W48/
--       W49/W50 (membership re-derived at ruling time from each wave record's
--       arm_md5 against the armed string in git history, not from prose).
--       Family gpm swap-averaged -19.15 / -9.60 / -6.19 / -20.26 / -5.95 /
--       +27.25 / +11.70 / +13.76 over 1,478 scored mirrored games; arithmetic
--       mean of the eight -1.06. HONEST BOUNDARY: that is a FAMILY-level
--       reading, not an id-level one -- an all-on wave cannot attribute economy
--       to one member -- and the winrate channel has been DEGENERATE since GH
--       #352, so no win/loss number exists to cite. At 1 cast per 82 games this
--       id cannot have produced any of those numbers in either direction; rule
--       2(b) asks for a coarse "no obvious negative" and this is that, and
--       nothing more.
--   (c) `8 * 30` is the only seconds-per-minute constant in bots/ that is not
--       60 (127:2 at landing, and the other 2 was this same expression in the
--       rubick twin), inherited verbatim from the upstream OHA snapshot, so
--       the author wrote "8 minutes" and got 4. Committing a ~2-minute-cooldown
--       teamfight ultimate to chipping a tier-1 tower in the window where it
--       first comes online is the standard thing not to do with it; the repair
--       restores the threshold the code's own arithmetic says it meant.
--       REGISTERED COUNTER-THEORY, not smoothed over: turbo rewards grouped
--       pushing, so an EARLIER objective commit is a defensible turbo tuning,
--       and the corpus cannot separate the two theories at this effect size --
--       no batch we can afford will ever resolve the sign of 1 cast per 82
--       games. The ruling therefore rests on (c) being an intent repair, not on
--       a measured gain. If the earlier commit time is ever wanted, it must be
--       a deliberate turbo constant with its own evidence, not an inherited
--       typo left in place because it might be accidentally right.
--       Ruling: iterations/streams/test_set.md §FQ.
-- KNOWN RESIDUAL, promoted with eyes open: the rubick twin at
-- bots/FunLib/rubick_hero/chaos_knight.lua keeps the inherited `8 * 30`. Its
-- domain is empty (corpus_hero_census.py --hero rubick: files=0, games=0), so
-- condition (a) is unbuyable for it BY CONSTRUCTION -- it stays
-- registered-not-fixed, and the census in section 1 of the test pins that the
-- remaining inline site is exactly that one.
function X.GetPushCommitTime()

	if J.IsModeTurbo()
	then
		return 8 * 60
	end

	return 8 * 30

end

function X.ConsiderR()

	if not abilityR:IsFullyCastable() or bot:DistanceFromFountain() < 500 then return BOT_ACTION_DESIRE_NONE end

	local nNearbyAllyHeroes = J.GetAlliesNearLoc( bot:GetLocation(), 1200 )
	local nNearbyEnemyHeroes = J.GetEnemyList( bot, 1600 )
	local nNearbyEnemyTowers = bot:GetNearbyTowers( 700, true )
	local nNearbyEnemyBarracks = bot:GetNearbyBarracks( 400, true )
	local nNearbyAlliedCreeps = bot:GetNearbyLaneCreeps( 1000, false )
	local nCastRange = abilityW:IsFullyCastable() and 1200 or 900

	-- if #nNearbyAllyHeroes + #nNearbyEnemyHeroes >= 3
		-- and  #hEnemyHeroList - #nNearbyAllyHeroes <= 2
		-- and  ( #nNearbyEnemyHeroes >= 2 or ( #hEnemyHeroList <= 1 and #nNearbyEnemyHeroes >= 1 ) )
	-- then
	  	-- return BOT_ACTION_DESIRE_HIGH
	-- end

	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and J.IsInRange( bot, botTarget, nCastRange )
			and J.CanCastOnMagicImmune( botTarget )
			--and #nNearbyAllyHeroes - #nNearbyEnemyHeroes <= 2
			and ( J.GetHP( botTarget ) > 0.5
				  or nHP < 0.7
				  or #nNearbyEnemyHeroes >= 2 )

		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end


	if J.IsInTeamFight( bot, 1200 )
	then
		if #nNearbyEnemyHeroes >= 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end


	-- [ckpush] threshold resolves in X.GetPushCommitTime -- see its header. That
	-- resolver is PROMOTED (turbo default 8 * 60, no gate left); non-turbo still
	-- reads the inherited 8 * 30.
	if J.IsPushing( bot )
		and DotaTime() > X.GetPushCommitTime()
	then
		if ( #nNearbyEnemyTowers >= 1 or #nNearbyEnemyBarracks >= 1 )
			and #nNearbyAlliedCreeps >= 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end


	if bot:GetActiveMode() == BOT_MODE_RETREAT
		and nHP >= 0.5
		and J.IsValidHero( nNearbyEnemyHeroes[1] )
		and GetUnitToUnitDistance( bot, nNearbyEnemyHeroes[1] ) <= 700
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	return BOT_ACTION_DESIRE_NONE
end


return X
-- dota2jmz@163.com QQ:2462331592..
