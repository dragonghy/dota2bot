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

-- TALENT LADDER -- re-anchored 2026-08-22 against the live Dota 2 datafeed
-- (https://www.dota2.com/datafeed/herodata?language=english&hero_id=2), the same
-- way GH #104 re-anchored Wraith King.  The npc dump further down still quotes the
-- 7.2x ladder and every talent name in it (special_bonus_strength_8 /
-- ..._movement_speed_20 / ..._mp_regen_2 / ..._attack_speed_35 / ..._hp_regen_20)
-- is gone from the hero.  Today's eight, in the feed's order:
--
--   [1] ..._unique_axe_culling_blade_speed_duration  +3s Culling Blade KILL buff
--                                                    duration (6 -> 9s)
--   [2] special_bonus_unique_axe_8   +8% move speed per ACTIVE Battle Hunger
--   [3] special_bonus_unique_axe     +8 Battle Hunger dps (12/16/20/24 -> 20/24/28/32)
--   [4] special_bonus_unique_axe_7   +10 Berserker's Call armor (12/13/14/15 -> 22/23/24/25)
--   [5] special_bonus_strength_15    +15 strength
--   [6] special_bonus_unique_axe_4   +Counter Helix damage
--   [7] special_bonus_unique_axe_2   +Berserker's Call AoE
--   [8] special_bonus_unique_axe_5   +Culling Blade damage
--
-- J.Skill.GetTalentBuild drives {1,2} from t10, {3,4} from t15, {5,6} from t20 and
-- {7,8} from t25; {0,10} takes the ODD index of a pair, {10,0} the EVEN one
-- (aba_skill.lua:135 -- tests/test_focus_talent_anchor.lua reads that arithmetic
-- out of the code instead of asserting it).  Only t10 and t15 can ever be taken in
-- turbo: the level census behind GH #84 read level >= 20 on 0 of 210 hero-slots,
-- high-water 19.  Two independent checks say the feed's order is the slot order
-- here: talent7 below is used as a Berserker's Call radius bonus and [7] is the
-- Call AoE talent; talent8 is used as Culling Blade kill damage and [8] is the
-- Culling Blade damage talent.
--
-- t10 CHANGED 2026-08-22 from {0,10} ([1]) to {10,0} ([2]).  Pure talent-table
-- change, no gate (stream charter: numbers and builds ship ungated, with the
-- rationale written down).  CONDITION (c), argued from the two payout conditions:
--   * [1] pays only AFTER Culling Blade lands a HERO KILL, and then only stretches
--     a buff from 6s to 9s.  Culling is a 175-range, 70/75/80s-cd finisher, and the
--     buff lands once the fight it would have helped win is already decided.
--   * [2] pays whenever a Battle Hunger is ticking on anything, +8% each.  Battle
--     Hunger is the FIRST point this file buys (build row {2,3,1,...}), is maxed by
--     level 10, runs 12s on a 20/15/10/5s cooldown, and X.ConsiderW fires it from
--     four separate branches (kill / initiation / teamfight / lane harass).  So it
--     is up for most of most fights, and the talent pays on every one of them.
--   * Move speed is the stat this Axe is short of: our own measurement (GH #56,
--     backlog #5) is that he NEVER holds a Blink Dagger in a turbo game -- 0 of 4
--     games, and 0 frames in 4 more -- so he closes every gap on foot.
-- HONEST BOUND: [1] is a TEAM buff (+20/25/30 move speed, +10/15/20 armor, 900
-- radius) and this gives up three seconds of it.  The claim is about how OFTEN each
-- pays, not about which single payout is larger.  No replay corpus was read: what
-- is counted above is cast conditions plus this file's own build order, not casts
-- per game.  Pick-rate corroboration could not be fetched (dotabuff 403,
-- liquipedia 429, fandom 402) -- the numbers are Valve's datafeed, not a guide.
--
-- t15 EXAMINED 2026-08-23 and deliberately NOT changed, so it is not re-litigated
-- on taste.  The pair is [3] +8 Battle Hunger dps against [4] +10 Berserker's Call
-- armor, and the row keeps [3].  Same ruler as the t10 change above -- payoff
-- REACHABILITY, i.e. how much of the game each talent's payout condition is true
-- for, not which single payout is larger:
--   * By this file's own build row, at level 15 Battle Hunger is rank 4 and
--     Berserker's Call rank 3.  Battle Hunger then runs 12s on a 5s cooldown --
--     it can be live CONTINUOUSLY.  Berserker's Call runs 2.7s on a 14s cooldown:
--     an uptime ceiling of 19%.  Five times the chances to pay, before anything
--     is measured.  (CORRECTED 2026-08-23, second pass: this said "both rank 4"
--     and 25%, from counting build-row entries as hero levels.  Levels 10 and 15
--     go to TALENTS, so Call's last point lands at level 16 -- one level after the
--     choice.  The correction made the gap bigger, not smaller; the mapping now
--     comes out of J.Skill.GetSkillList itself, in tests/skill_level_map.lua.)
--   * Measured, on the 16 Axe fixture frames that carry modifier state: an enemy
--     is carrying modifier_axe_battle_hunger on 5 of them, Axe is carrying
--     modifier_axe_berserkers_call_armor on 1.  Summed over the ranks those frames
--     actually held, the ceilings were ~14 and ~1.9 -- so the Call side is at about
--     half of everything it could ever have, while the Battle Hunger side is at
--     about a third of its own.  The gap is the ceiling, not slack the bot could
--     take up by pressing Call more often.
-- THE REJECTED SIDE'S CASE, recorded because it is real: [4] is the bigger
-- RELATIVE buff (14 -> 24 armor at the rank held here, +71%, against 24 -> 32
-- dps, +33%); a taunt
-- guarantees the attacks its armor blunts actually arrive; and the innate
-- One Man Army turns 50% of Axe's armor into Strength while no ally is within
-- 700, which is exactly the state X.ConsiderQ's neutral-taunt branch puts him
-- in.  It loses on frequency, not on quality.
-- COSTS AND BOUNDS: the corpus tops out at level 14, so every frame above was read
-- one level BELOW the tier -- a proxy, not an in-domain reading; n = 1 on the Call
-- side corroborates the arithmetic and establishes nothing alone; and keeping [3]
-- keeps a decision-layer side effect, since X.ConsiderW multiplies
-- damage_per_second by the full 12s duration into the claim it hands
-- J.WillMagicKillTarget -- a claim Battle Hunger's "until the target kills a unit"
-- clause already makes optimistic.  [4] has no consumer in this file at all.
-- Pinned in tests/test_axe_t15_payoff.lua.  Pick-rate corroboration could not be
-- fetched again (dotabuff 403); condition (c) rests on the mechanism.
--
-- The t15 row's OLD comment was deleted on 2026-08-22 rather than updated: it named
-- two 7.2x talents the hero no longer has, and it was backwards even for them --
-- {0,10} takes the ODD index, which in that ladder was the mana-regen talent, i.e.
-- the row picked the talent its own comment said it rejected.  The exact wording is
-- quoted once, in tests/test_focus_talent_anchor.lua, which also guards against it
-- coming back; do not paste it here.
local tTalentTreeList = {
						['t25'] = {0, 10},
						['t20'] = {0, 10},
						['t15'] = {0, 10},
						['t10'] = {10, 0},
}

local tAllAbilityBuildList = {
	{2,3,1,3,3,6,3,2,2,2,6,1,1,1,6},--pos3
}

local nAbilityBuildList = J.Skill.GetRandomBuild( tAllAbilityBuildList )

local nTalentBuildList = J.Skill.GetTalentBuild( tTalentTreeList )

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_1'] = {
	"item_sven_outfit",
	"item_blade_mail",--
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",--
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_overwhelming_blink",--
	"item_abyssal_blade",--
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_heart",--
	"item_travel_boots_2",--
}

sRoleItemsBuyList['pos_3'] = {

	"item_tank_outfit",
	"item_crimson_guard",--
	"item_blade_mail",--
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",--
	"item_heavens_halberd",--
	"item_travel_boots",
	"item_assault",--
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_heart",--
	"item_overwhelming_blink",--
	"item_travel_boots_2",--

}

-- [TURBO BUILD, gated 'axebuyblink'] Blink Dagger is the delivery system for
-- Axe's whole kit (blink -> Berserker's Call -> Counter Helix procs -> Culling
-- Blade reset); without it a melee initiator with no gap-closer can only fight
-- what walks into him. The shipped orders bury it behind the tank stack:
-- pos_3 spends ~2.7k on the starting outfit, then Crimson Guard, then Blade
-- Mail before blink's 2250 even starts (~8.5k in), and pos_1 puts Blade Mail
-- ahead of it. That is a normal-mode order running in a game mode that ends at
-- minute 11.
--
-- Measured (4 turbo soak games, 2026-08-19, spot_20260819_121044_1_main):
-- Axe NEVER held a blink in any of them -- final net worth 4228 / 5556 / 7834
-- / 8586, all short of the shipped prefix. From his own measured gold curve,
-- blink bought straight after boots would have landed at 558s / 479s / 584s /
-- never, i.e. in 3 of 4 games with 100-240s of a decisive turbo game left.
-- Standard Axe theory agrees: blink is the first big item, Blade Mail and the
-- Crimson/Vanguard stack come after it.
--
-- The reorder is a pure permutation built FROM the shipped list, so the two
-- can never drift apart, and it is inert unless the gate is armed in turbo.
local function BlinkFirstBuild( tList )
	if tList == nil or tList[1] == 'item_blink' then return tList end
	local bHasBlink = false
	for _, sItem in ipairs( tList ) do
		if sItem == 'item_blink' then bHasBlink = true end
	end
	if not bHasBlink then return tList end

	-- index 1 is the starting-items bundle (it carries the boots), so blink
	-- goes immediately after it; every other item keeps its relative order.
	local tOut = { tList[1], 'item_blink' }
	for i = 2, #tList do
		if tList[i] ~= 'item_blink' then tOut[#tOut+1] = tList[i] end
	end
	return tOut
end

if J.IsModeTurbo() and J.IsSoakCandidate( 'axebuyblink' ) then
	sRoleItemsBuyList['pos_1'] = BlinkFirstBuild( sRoleItemsBuyList['pos_1'] )
	sRoleItemsBuyList['pos_3'] = BlinkFirstBuild( sRoleItemsBuyList['pos_3'] )
end

sRoleItemsBuyList['pos_2'] = sRoleItemsBuyList['pos_1']

sRoleItemsBuyList['pos_4'] = sRoleItemsBuyList['pos_3']

sRoleItemsBuyList['pos_5'] = sRoleItemsBuyList['pos_3']


X['sBuyList'] = sRoleItemsBuyList[sRole]

X['sSellList'] = {
	"item_travel_boots",
	"item_quelling_blade",

	"item_abyssal_blade",
	"item_magic_wand",
}


if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_tank' }, {"item_heavens_halberd", 'item_quelling_blade'} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )

X['bDeafaultAbility'] = false
X['bDeafaultItem'] = false

function X.MinionThink(hMinionUnit)

	if Minion.IsValidUnit( hMinionUnit )
	then
		Minion.IllusionThink( hMinionUnit )
	end

end

--[[

npc_dota_hero_axe

"Ability1"		"axe_berserkers_call"
"Ability2"		"axe_battle_hunger"
"Ability3"		"axe_counter_helix"
"Ability4"		"generic_hidden"
"Ability5"		"generic_hidden"
"Ability6"		"axe_culling_blade"
-- THE EIGHT LINES BELOW ARE THE 7.2x LADDER AND ARE KEPT ONLY AS THE RECORD OF
-- WHAT THIS FILE USED TO BELIEVE.  Five of the names no longer exist on the hero
-- and the three ..._unique_axe* ones moved.  Read the re-anchored ladder at the top
-- of this file (dated 2026-08-22, from the datafeed) before trusting any index.
"Ability10"		"special_bonus_strength_8"
"Ability11"		"special_bonus_movement_speed_20"
"Ability12"		"special_bonus_mp_regen_2"
"Ability13"		"special_bonus_attack_speed_35"
"Ability14"		"special_bonus_hp_regen_20"
"Ability15"		"special_bonus_unique_axe_3"
"Ability16"		"special_bonus_unique_axe_2"
"Ability17"		"special_bonus_unique_axe"

modifier_axe_berserkers_call
modifier_axe_berserkers_call_armor
modifier_axe_battle_hunger
modifier_axe_battle_hunger_self
modifier_axe_counter_helix
modifier_axe_culling_blade_boost


--]]

local abilityQ = bot:GetAbilityByName( sAbilityList[1] )
local abilityW = bot:GetAbilityByName( sAbilityList[2] )
local abilityE = bot:GetAbilityByName( sAbilityList[3] )
local abilityR = bot:GetAbilityByName( sAbilityList[6] )
local talent7 = bot:GetAbilityByName( sTalentList[7] ) -- t25 pair, odd index: today special_bonus_unique_axe_2, +Berserker's Call AoE
-- t25 pair, even index.  The name in the comment that used to sit here was
-- `special_bonus_unique_axe: +Culling Blade kill threshold`, which is stale twice
-- over: special_bonus_unique_axe is index [3] today (+8 Battle Hunger dps), and
-- index [8] is special_bonus_unique_axe_5, +Culling Blade DAMAGE.  Adding it to
-- nKillDamage below still reads correctly under the new name -- Culling has had no
-- separate kill threshold since the mechanic was folded into its pure damage -- but
-- both talent handles here are t25, so GH #84's census (level >= 20 on 0 of 210
-- hero-slots) makes them dead weight in turbo either way.
local talent8 = bot:GetAbilityByName( sTalentList[8] )

local castQDesire, castQTarget
local castWDesire, castWTarget
local castEDesire, castETarget
local castRDesire, castRTarget

local nKeepMana, nMP, nHP, nLV, hEnemyList, hAllyList, botTarget, sMotive
local aetherRange = 0


function X.SkillsComplement()

	if J.CanNotUseAbility( bot ) or bot:IsInvisible() then return end

	nKeepMana = 400
	aetherRange = 0
	nLV = bot:GetLevel()
	nMP = bot:GetMana() / bot:GetMaxMana()
	nHP = bot:GetHealth() / bot:GetMaxHealth()
	botTarget = J.GetProperTarget( bot )
	hEnemyList = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )
	hAllyList = J.GetAlliesNearLoc( bot:GetLocation(), 1600 )


	--计算天赋可能带来的通用变化
	local aether = J.IsItemAvailable( "item_aether_lens" )
	if aether ~= nil then aetherRange = 225 end
	
	castRDesire, castRTarget, sMotive = X.ConsiderR()
	if castRDesire > 0
	then
		J.SetReportMotive( bDebugMode, sMotive )

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbilityOnEntity( abilityR, castRTarget )
		return
	end
	

	castQDesire, sMotive = X.ConsiderQ()
	if castQDesire > 0
	then
		J.SetReportMotive( bDebugMode, sMotive )

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbility( abilityQ )
		return
	end

	castWDesire, castWTarget, sMotive = X.ConsiderW()
	if castWDesire > 0
	then
		J.SetReportMotive( bDebugMode, sMotive )

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbilityOnEntity( abilityW, castWTarget )
		return
	end

	

end


function X.ConsiderQ()


	if not abilityQ:IsFullyCastable() then return 0 end

	local nSkillLV = abilityQ:GetLevel()
	
	local nRadius = abilityQ:GetSpecialValueInt( 'radius' )
	if talent7:IsTrained() then nRadius = nRadius + talent7:GetSpecialValueInt( 'value' ) end
	
	local nCastRange = nRadius
	
	local nCastPoint = abilityQ:GetCastPoint()
	local nManaCost = abilityQ:GetManaCost()
	local nDamage = 0
	local nDamageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyList = J.GetAroundEnemyHeroList( nRadius - 50 )
--	local nInBonusEnemyList = J.GetAroundEnemyHeroList( nRadius + 200 )
	local hCastTarget = nil
	local sCastMotive = nil
	
	--打断敌人施法
	for _, npcEnemy in pairs( nInRangeEnemyList )
	do 
		if npcEnemy:IsChanneling()
			and not npcEnemy:IsMagicImmune()
		then
			hCastTarget = npcEnemy
			sCastMotive = 'Q-打断'..J.Chat.GetNormName( hCastTarget )
			return BOT_ACTION_DESIRE_HIGH, sCastMotive		
		end
	end
	
	
	--攻击敌人时
	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and J.IsInRange( botTarget, bot, nRadius - 90 )
			and J.CanCastOnNonMagicImmune( botTarget )			
			and not J.IsDisabled( botTarget )
		then			
			hCastTarget = botTarget
			sCastMotive = 'Q-先手'..J.Chat.GetNormName( hCastTarget )
			return BOT_ACTION_DESIRE_HIGH, sCastMotive
		end
	end
	


	--带线时嘲讽小兵攻击自己
	if ( J.IsPushing( bot ) or J.IsDefending( bot ) or J.IsFarming( bot ) )
		and J.IsAllowedToSpam( bot, nManaCost )
		and bot:GetAttackTarget() ~= nil
		and DotaTime() > 6 * 60
		and #hAllyList <= 2 
		and #hEnemyList == 0
	then
		local laneCreepList = bot:GetNearbyLaneCreeps( nRadius - 50, true )
		if #laneCreepList >= 4
			and not laneCreepList[1]:HasModifier( "modifier_fountain_glyph" )
		then
			hCastTarget = laneCreepList[1]
			sCastMotive = 'Q-带线'..(#laneCreepList)
			return BOT_ACTION_DESIRE_HIGH, sCastMotive
		end
	end

	if J.IsDoingRoshan(bot)
	then
		if  J.IsRoshan(botTarget)
        and not J.IsDisabled(botTarget)
        and not botTarget:IsDisarmed()
        and J.IsInRange(bot, botTarget, nRadius)
        and J.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

    if J.IsDoingTormentor(bot)
	then
		if  J.IsTormentor(botTarget)
        and J.IsInRange(bot, botTarget, nRadius)
        and J.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	--farming: taunt 3+ neutral creeps when healthy
	if J.IsFarming( bot )
		and #hEnemyList == 0
		and nHP > 0.5
		and J.GetManaAfter( nManaCost ) > 0.3
	then
		local nNeutralCreeps = bot:GetNearbyNeutralCreeps( nRadius - 50 )
		if #nNeutralCreeps >= 3
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	--Roshan: taunt Roshan to absorb hits
	if bot:GetActiveMode() == BOT_MODE_ROSHAN
		and J.GetManaAfter( nManaCost ) > 0.3
		and nHP > 0.3
	then
		if J.IsRoshan( botTarget )
			and not J.IsDisabled( botTarget )
			and J.IsInRange( bot, botTarget, nRadius )
			and J.IsAttacking( bot )
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end

	return BOT_ACTION_DESIRE_NONE


end


function X.ConsiderW()


	if not abilityW:IsFullyCastable() then return 0 end

	local nSkillLV = abilityW:GetLevel()
	local nCastRange = abilityW:GetCastRange() + aetherRange
	local nRadius = 600
	local nCastPoint = abilityW:GetCastPoint()
	local nManaCost = abilityW:GetManaCost()
	
	local nDuration = abilityW:GetSpecialValueInt( 'duration' )
	local nDamage = abilityW:GetSpecialValueInt( 'damage_per_second' ) * nDuration
	
	local nDamageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange )
	local nInBonusEnemyList = J.GetAroundEnemyHeroList( nCastRange + 200 )
	local hCastTarget = nil
	local sCastMotive = nil
	
	
	--击杀低血量敌人
	for _, npcEnemy in pairs( nInRangeEnemyList )
	do 
		if J.IsValid( npcEnemy )
			and J.CanCastOnNonMagicImmune( npcEnemy )
			and J.CanCastOnTargetAdvanced( npcEnemy )
			and J.WillMagicKillTarget( bot, npcEnemy, nDamage , nDuration )
			and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
		then
			hCastTarget = npcEnemy
			sCastMotive = 'W-击杀'..J.Chat.GetNormName( hCastTarget )
			return BOT_ACTION_DESIRE_HIGH, hCastTarget, sCastMotive
		end
	
	end
	
	
	--攻击敌人时
	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and J.IsInRange( botTarget, bot, nCastRange )
			and J.CanCastOnNonMagicImmune( botTarget )			
			and J.CanCastOnTargetAdvanced( botTarget )
			and not botTarget:HasModifier( 'modifier_axe_battle_hunger_self' )
		then			
			hCastTarget = botTarget
			sCastMotive = 'W-先手'..J.Chat.GetNormName( hCastTarget )
			return BOT_ACTION_DESIRE_HIGH, hCastTarget, sCastMotive
		end
	end
	
	
	--团战中对血量最低的敌人使用
	if J.IsInTeamFight( bot, 1200 )
	then
		local npcWeakestEnemy = nil
		local npcWeakestEnemyHealth = 100000

		for _, npcEnemy in pairs( nInBonusEnemyList )
		do
			if J.IsValid( npcEnemy )
				and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
			then
				local npcEnemyHealth = npcEnemy:GetHealth()
				if ( npcEnemyHealth < npcWeakestEnemyHealth )
				then
					npcWeakestEnemyHealth = npcEnemyHealth
					npcWeakestEnemy = npcEnemy
				end
			end
		end

		if npcWeakestEnemy ~= nil
		then
			hCastTarget = npcWeakestEnemy
			sCastMotive = 'W-团战'..J.Chat.GetNormName( hCastTarget )
			return BOT_ACTION_DESIRE_HIGH, hCastTarget, sCastMotive
		end
	end
	
	
	--对线期间消耗
	if J.IsLaning( bot ) and nMP > 0.5
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do 
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and npcEnemy:GetAttackTarget() == nil
				and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
			then
				hCastTarget = npcEnemy
				sCastMotive = 'W-对线消耗:'..J.Chat.GetNormName( hCastTarget )
				return BOT_ACTION_DESIRE_HIGH, hCastTarget, sCastMotive
			end
		
		end	
	end
	
	
	
	--撤退时保护自己
	if J.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
			then
				hCastTarget = npcEnemy
				sCastMotive = 'W-撤退:'..J.Chat.GetNormName( hCastTarget )
				return BOT_ACTION_DESIRE_HIGH, hCastTarget, sCastMotive
			end
		end
	end
	
	--打野时
	if J.IsFarming( bot )
		and nSkillLV >= 2
		and J.GetManaAfter( nManaCost ) > 0.3
	then
		local neutralCreepList = bot:GetNearbyNeutralCreeps( nCastRange + 100 )

		local targetCreep = J.GetMostHpUnit( neutralCreepList )

		if J.IsValid( targetCreep )
			and not J.IsRoshan( targetCreep )
			and not targetCreep:HasModifier( 'modifier_axe_battle_hunger_self' )
			and not J.CanKillTarget( targetCreep, bot:GetAttackDamage() * 2.88, DAMAGE_TYPE_PHYSICAL )
		then
			hCastTarget = targetCreep
			sCastMotive = 'W-打野'
			return BOT_ACTION_DESIRE_HIGH, hCastTarget, sCastMotive
	    end
	end


	if J.IsDoingRoshan(bot)
	then
		if  J.IsRoshan(botTarget)
        and not J.IsDisabled(botTarget)
        and J.IsInRange(bot, botTarget, nCastRange)
        and J.IsAttacking(bot)
        and not botTarget:HasModifier('modifier_axe_battle_hunger_self')
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

    if J.IsDoingTormentor(bot)
	then
		if  J.IsTormentor(botTarget)
        and not J.IsDisabled(botTarget)
        and J.IsInRange(bot, botTarget, nCastRange)
        and J.IsAttacking(bot)
        and not botTarget:HasModifier('modifier_axe_battle_hunger_self')
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end


	return BOT_ACTION_DESIRE_NONE


end


function X.ConsiderR()


	if not abilityR:IsFullyCastable() then return 0 end

	local nSkillLV = abilityR:GetLevel()
	local nCastRange = abilityR:GetCastRange()
	local nRadius = 600
	local nCastPoint = abilityR:GetCastPoint()
	local nManaCost = abilityR:GetManaCost()
	
	-- REGISTERED LEVER, NOT TAKEN THIS ROUND (hero stream, 2026-08-22).  This
	-- constant is stale: 150 + 100*lv is 250/350/450, and Culling Blade's damage on
	-- the live datafeed (hero_id 2) is 275/375/475.  So the bot under-states its own
	-- finisher by 25 pure damage at every level and declines a Culling that would in
	-- fact kill whenever the target sits in the 25-point band above the estimate.
	-- The honest fix is to read it off the ability (abilityR:GetSpecialValueInt(
	-- 'damage' )) rather than to re-hardcode today's numbers.  It is NOT done here
	-- because it ADDS a cast rather than removing one, and this stream ships an
	-- action-adding change only with a real frame and a sized domain -- neither of
	-- which this round bought.  PRE-REGISTERED DOMAIN for whoever picks it up:
	-- frames where Culling is off cooldown, the target is inside 175, and its
	-- current health falls in (150 + 100*lv, ability damage] -- count episodes, not
	-- frames.
	local nKillDamage = 150 + 100 * nSkillLV
	if talent8 ~= nil and talent8:IsTrained() then nKillDamage = nKillDamage + talent8:GetSpecialValueInt( 'value' ) end
	
	local nDamageType = DAMAGE_TYPE_PURE
	local nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange )
	local nInBonusEnemyList = J.GetAroundEnemyHeroList( nCastRange + 200 )
	local hCastTarget = nil
	local sCastMotive = nil
	
	
	--直接斩杀血量低于斩杀线的敌人
	for _, npcEnemy in pairs( nInBonusEnemyList )
	do 
		if J.IsValidHero( npcEnemy )
			and npcEnemy:CanBeSeen()
			and npcEnemy:GetHealth() + npcEnemy:GetHealthRegen() * 0.8 < nKillDamage
			and not J.IsHaveAegis( npcEnemy )
			and not npcEnemy:IsInvulnerable()
			and not npcEnemy:IsMagicImmune() --V BUG
			and not X.HasSpecialModifier( npcEnemy )
			and not X.IsKillBotAntiMage( npcEnemy )
		then
			hCastTarget = npcEnemy
			sCastMotive = 'R-击杀'..J.Chat.GetNormName( hCastTarget )
			return BOT_ACTION_DESIRE_HIGH, hCastTarget, sCastMotive			
		end
	end


	return BOT_ACTION_DESIRE_NONE


end


function X.HasSpecialModifier( npcEnemy )

	if npcEnemy:HasModifier( 'modifier_winter_wyvern_winters_curse' )
		or npcEnemy:HasModifier( 'modifier_winter_wyvern_winters_curse_aura' )
		or npcEnemy:HasModifier( 'modifier_antimage_spell_shield' )
		or npcEnemy:HasModifier( 'modifier_item_lotus_orb_active' )
		or npcEnemy:HasModifier( 'modifier_item_aeon_disk_buff' )
		or npcEnemy:HasModifier( 'modifier_item_sphere_target' )
		or npcEnemy:HasModifier( 'modifier_illusion' )
	then
		return true
	else
		return false	
	end

end


function X.IsKillBotAntiMage( npcEnemy )

	if not npcEnemy:IsBot() 
		or npcEnemy:GetUnitName() ~= 'npc_dota_hero_antimage'
		or npcEnemy:IsStunned()
		or npcEnemy:IsHexed()
		or npcEnemy:IsNightmared()
		or npcEnemy:IsChanneling()
		or J.IsTaunted( npcEnemy )
	then
		return false
	end
	
	return true

end


return X
-- dota2jmz@163.com QQ:2462331592..
