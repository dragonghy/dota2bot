local X = {}
local bDebugMode = ( 1 == 10 )
local bot = GetBot()

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Minion = dofile( GetScriptDirectory()..'/FunLib/aba_minion' )
local sTalentList = J.Skill.GetTalentList( bot )
local sAbilityList = J.Skill.GetAbilityList( bot )
local sRole = J.Item.GetRoleItemsBuyList( bot )

-- [hero] TALENTPRICE -- Crystal Maiden's t20 and t25, priced for the first time
-- 2026-08-27 (baton 2 of GH #238 section 6; lion -> axe -> zuus -> here).  Both
-- rows were OpenHyperAI snapshot defaults, pinned but never argued.  BOTH MOVE,
-- and they move for two different reasons -- one is reachability, one is a
-- stale reading this file already carries today.  Talent rows are not gated, so
-- these are live in every turbo game that reaches 20 / 25 (GH #235: heroes read
-- 22-27 once owner priority P3 lifted the 10-minute cap; CM herself reads 22 on
-- that frame).
--
-- t20 {10,0} -> {0,10}: sTalentList[5]
--   `special_bonus_unique_crystal_maiden_glacial_guard_mana_multiplier`
--   (+20 on Glacial Guard's mana-to-barrier percentage) INSTEAD OF [6]
--   `special_bonus_unique_crystal_maiden_3` (+50 Freezing Field damage).
--
--   Priced on PAYOFF REACHABILITY -- the same ruler that decided t10 and t15.
--   [6] is denominated in CHANNEL-SECONDS HELD: it pays +50 per Freezing Field
--   explosion and stops paying the instant the channel breaks.  This file's own
--   pinned frames are what that costs.  20260819_003005_slot1 t=373.4: she was
--   stunned 0.6s into a 10s channel -- 6% of its maximum -- and died 5.9s later
--   (X.nRGuardCloseBuffer's block below).  20260820_103216_slot1 t=473.5: she
--   opened at 26% health while carrying a stun, and was dead 1.0s later
--   (X.nRSelfHpFloor's block).  The three candidates that would guard the
--   opening -- 'cmrguard', 'cmrcap', 'cmrself' -- are all still SOAK CANDIDATES,
--   so the SHIPPED default opens Freezing Field in exactly those situations.
--   Buying more damage per explosion is buying a multiplier on a quantity this
--   desk has never once measured as large.
--
--   [5] is denominated in MANA SPENT ON ABILITIES: "a portion of the mana
--   Crystal Maiden spends on her abilities is converted into a physical
--   barrier" (Valve's own tooltip, abilities_english.txt, read 2026-08-27),
--   barrier_duration 8, mana_multiplier 30 with hero_levelup +2 -- about 70% at
--   level 20, which the talent takes to 90%, i.e. +20 barrier per 100 mana
--   spent, ~+29% more barrier than the row buys today.  There is no cast to
--   land, no channel to hold, no aim: she pays it on every Nova and every
--   Frostbite, wave-clear casts included.  And it pays out ON the very action
--   [6] is betting on -- Freezing Field costs 600 mana at rank 3, so opening the
--   channel is itself worth +120 barrier at the moment she is rooted and focused.
--
--   AFFORDABLE FOR THE SAME REASON AXE'S t20 WAS: the flip is inert to the
--   decision layer, so it can only move combat power.  Nothing in this file
--   reads `crystal_maiden_freezing_field/damage` (X.ConsiderR sizes itself off
--   GetOffensivePower), and nothing holds a handle on the innate at all -- it is
--   hidden on 53 of 53 corpus frames and dropped from sAbilityList before this
--   file ever sees it (GH #206).  Neither direction can create a stale read.
--
--   External corroboration, weakest ground and listed last: Valve's own default
--   bot build for this hero takes [5] at 20 (npc_heroes.txt, "Bot"/"Build",
--   entry "20").  It disagrees with us at t10, which is why it is not the
--   argument.
--
--   HONEST BOUNDS.  (i) The channel evidence is n=2, both from the 10-minute
--   capped corpus and both below level 20, so it bounds the SHAPE of [6]'s
--   payoff (channels get cut), not its rate at 20+.  (ii) The barrier is
--   PHYSICAL only -- it does nothing against the magical burst that also kills
--   her.  (iii) Whether `hero_levelup +2` counts from level 0 or 1 moves the
--   ~70% by 2 points; the ratio the decision rests on does not move.  (iv) All
--   four entries in this hero's "Facets" block read Deprecated -- which is WHY
--   Glacial Guard is a plain `"Innate" "1"` ability today.  If a patch
--   re-attaches it to a facet, this row becomes facet-conditional and must be
--   re-priced (the family skeleton_king's two rows are already in).
--
-- t25 {0,10} -> {10,0}: sTalentList[8]
--   `special_bonus_unique_crystal_maiden_2` (+300 Crystal Nova damage) INSTEAD
--   OF [7] `special_bonus_unique_crystal_maiden_1` (+1.0s Frostbite duration).
--
--   This one is a DECISION-LAYER ruling, not a magnitude call, and the row
--   shipped today is the wrong half of it.  X.ConsiderW reconstructs Frostbite's
--   damage by hand: `nDamage = ( 100 + nSkillLV * 50 )`, which is exactly
--   damage_per_second 100 x duration 1.5/2/2.5/3 = 150/200/250/300 -- correct at
--   all four ranks, and correct only while no talent touches the duration.  [7]
--   takes rank 4 to 4.0s, i.e. 400 real damage against a kill-check that still
--   says 300: a live 25% UNDERESTIMATE from level 25 on, in the "thinks it
--   cannot kill" direction, in every turbo game that gets there.  Taking [8]
--   REMOVES that band rather than creating one -- the twin of Axe's t25, where
--   the same shape argued for keeping the row where it was.
--
--   [8] lands on `crystal_maiden_crystal_nova/nova_damage`, and X.ConsiderQImpl
--   reads that key LIVE (`abilityQ:GetSpecialValueInt('nova_damage')`) before
--   handing it to bot:FindAoELocation for both the hero-kill and the creep-kill
--   search.  The engine folds a trained talent into the base read (GH #228), so
--   the bot hits for 560 instead of 260 AND KNOWS IT: the kill branch fires at
--   the enlarged threshold with no code change anywhere.
--
--   WHAT IS GIVEN UP, written down rather than left as a surprise: one extra
--   second of a single-target root, which is real teamfight value the engine
--   would have applied for free and this file does not measure.  The trade is
--   taken because +115% on the nuke the decision layer already reads beats +33%
--   on a duration it cannot see, not because the root is worthless.
--
-- Both rows, the arithmetic behind them, and the conditions that reopen them:
-- tests/test_cm_t20t25_payoff.lua; the ladder record: tests/test_focus_talent_anchor.lua.
local tTalentTreeList = {
						['t25'] = {10, 0},
						['t20'] = {0, 10},
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
-- would buy a SECOND pair of boots and strand 1500 gold.  That is not a rules-
-- of-Dota claim, it is a fact about THIS repo's purchase code, and it is the
-- one leg this removal now stands on: item_purchase_generic.lua's _stillNeeds
-- refuses a second pair of basic boots when the hero already has boots, EXCEPT
-- when the current build target is in its tBootsUpgrades whitelist -- and
-- item_boots_of_bearing is in that whitelist, while item_arcane_boots is in
-- Item['tEarlyBoots'].  Keeping the terminus on the arcane line would switch
-- that guard off on purpose.
--
-- 2026-08-28 (GH #279): the OTHER leg is gone, and the terminus is PRICED.
-- This used to add "no corpus unit owns one, and that zero is OUT-OF-WINDOW,
-- not empty -- the corpus ends at 11:30 and Bearing is a 4225g fifth item".
-- Two fixtures landed with THIS Crystal Maiden holding boots_of_bearing, and
-- the item's own modifier dates the purchase to t=773.5s = 12:53 at level 14,
-- net worth 7746, with the tranquils and the drum both consumed out of the
-- inventory.  So the out-of-window reading was right but only just: the
-- terminus sat 83 seconds past the old corpus edge, not a game away.  It is
-- reachable, it is measured, and the deletion pays a real price for it --
-- including one the file had never stated: the candidate keeps
-- item_ancient_janggo and deletes its only upgrade, so it ends on a drum whose
-- charges do not replenish where the shipped line ends on Bearing's, which do.
-- What keeps the deletion cheap is that the aura's observed reach is thin --
-- 1 ally-frame out of 8.  All of it is asserted in tests/test_cm_pos5_boots.lua
-- section 3, ceilings included, so a corpus that makes the terminus look
-- valuable turns that file red instead of leaving this comment stale.
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
	-- Soak candidate 'aetherlens' (turbo-only), resolved inside
	-- J.GetAetherLensRangeBonus -- the shipped 250 is 25 more than the item's own
	-- KV grants (cast_range_bonus 225).  Gate off, this returns the 250 it is
	-- handed, so the two consumers below (X.ConsiderQ :610, X.ConsiderW :941) are
	-- byte-for-byte the shipped ones.  Argument, ground truth and scope: the block
	-- above the helper in bots/FunLib/jmz_func.lua.
	if aether ~= nil then aetherRange = J.GetAetherLensRangeBonus( aether, 250 ) end
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

--- How far from the bot may the CREEP AoE search place its centre?
---
--- THE ASYMMETRY THIS EXISTS TO CLOSE (axis `REACH`).  X.ConsiderQImpl runs four
--- bot:FindAoELocation searches.  Its 4th argument is `nMaxDistanceFromBase`, so
--- the returned `.targetloc` is guaranteed to sit within that distance of
--- bot:GetLocation() and nowhere tighter.  The two HERO searches pass
--- `nCastRange`; the two CREEP searches pass `nCastRange + nRadius`.
---
--- Then look at what each result is allowed to become a cast location:
---
---   * hero, 5 return sites -- 4 of them re-check
---     `GetUnitToLocationDistance( bot, ... ) <= nCastRange` (+50 at one), and
---     the 5th runs its own search at `nCastRange - 300`, i.e. contained by
---     construction.  5/5 in range.
---   * creep, 8 return sites -- not one checks anything.  0/8.
---
--- So the creep branches can hand X.SkillsComplement a point up to `nRadius`
--- past the cast range and it goes straight into
--- `bot:ActionQueue_UseAbilityOnLocation( abilityQ, castQLoc )`.  At rank 4 with
--- no Aether Lens that is 425 of 732 units -- the overshoot is 58% of the whole
--- cast range, not a rounding edge.
---
--- WHAT THE OVERSHOOT COSTS IS **NOT** CLAIMED HERE, and that is deliberate.
--- The engine either refuses the order or walks her into range first, and which
--- one it does is not readable from the bot VM (AGENTS.md: `print()` never
--- reaches the console and the error handler is broken).  Refusal means this
--- branch wins the desire contest and does nothing, every tick, while a wave is
--- out there; a walk means a position-5 support strolls up to 425 units into a
--- creep wave to farm.  Neither is a thing the hero branches in this same
--- function are willing to do, and that -- not a guess about which -- is the
--- argument.  The domain reading is requested in `queue.json:hero-25`.
---
--- NARROWING (soak candidate 'cmqreach', turbo-only).  The armed path only
--- shrinks a search radius, so the point it yields is in range BY CONSTRUCTION,
--- exactly the way the 5th hero site already is -- no new predicate, no new
--- guard to get wrong.  Direction is single and it is honest about the cost: a
--- smaller search can also see fewer creeps, so the `count >= 2/3/4/5`
--- thresholds get harder and the armed side casts Nova on waves STRICTLY no
--- more often.  It never moves a cast that was already legal.
function X.cm_GetCreepAoESearchRange( nCastRange, nRadius )
	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmqreach' )
	then
		return nCastRange
	end
	return nCastRange + nRadius
end


--- Soak candidate `cmqpoke` (turbo-only, INERT until armed) -- the release test
--- X.ConsiderQImpl's catch-all Crystal Nova path never had.  Written 2026-09-10
--- under OWNER_PRIORITIES P4.4 (i).
---
--- THE DEFECT, and it is a RELEASE-CONDITION one, not a reach one.  The
--- `--非撤退的逻辑` block is the function's LAST hero path and its widest: its
--- only mode term is a NEGATED one (`~= BOT_MODE_RETREAT`, true in every mode
--- but one), so it is what fires whenever the specific paths above it do not.
--- Inside it, two neighbouring branches ask for the same cast on the same
--- subject -- `nWeakestEnemyHeroInBonus`, resolved through the same
--- J.GetCastLocation -- and differ in ONE term:
---
---     :80x   nMP > 0.8 or bot:GetMana() > nKeepMana * 2        <- what she HAS
---     :81x   nWeakestEnemyHeroInBonus health ratio < 0.4       <- what it BUYS
---
--- So the upper branch is the lower one with its quality test replaced by a
--- WALLET test.  It is the same shape as `cmrcrowd` (GH #649) one function down
--- -- the one release path in the file that never asks what the cast is for --
--- except that here the unqualified path does not merely short-circuit the
--- qualified one, it sits six lines ABOVE it and therefore always wins.
---
--- AND THE WALLET TEST LOOSENS AS THE GAME RUNS.  `nKeepMana` is 220, so the
--- absolute disjunct is a flat 440 while the pool is not.  Arithmetic, not a
--- reading: the two terms cross at a 550 pool, and past it the effective
--- reserve falls to 40% of the bar at a 1100 pool and 20% at 2200.  The reading
--- that goes with it, over the 28 corpus instants where Nova is fully castable
--- (tests/test_cm_nova_surplus_poke.lua section 5): 18 satisfy the shipped
--- disjunction, 6 on the absolute term ALONE, and ZERO on the ratio term alone.
--- On this corpus `nMP > 0.8` never once decides the question by itself; the
--- rule that actually runs is "mana > 440", i.e. two Novas' worth.
---
--- WHY IT IS A GATE, and the direction is a property of the CODE, not of the
--- data.  The shipped disjunction is evaluated FIRST and a false answer is
--- returned unchanged, so the armed leg can only ever turn a shipped TRUE into
--- FALSE -- it deletes casts and can never add one.  Gate off, this helper IS
--- the shipped expression, byte for byte.
---
--- WHAT IT COSTS, stated so it can be argued with.  Crystal Nova's cooldown is
--- 11/10/9/8s and in Turbo a wasted one comes back quickly, so the loss per
--- declined poke is small; the case for declining is that the cast is her only
--- AoE slow and her mana is the binding constraint on the Frostbite follow-up.
--- The armed test is not a new idea -- it is the sibling branch's own 0.4, so
--- armed this path collapses onto the qualified one instead of inventing a
--- threshold this file does not already use.
---
--- ⭐ THE DOMAIN IS NOT EMPTY, AND THAT IS RARE HERE.  GH #658 measured that the
--- whole fixture corpus drives exactly FOUR shipped skill decisions across the
--- five focus heroes, and Crystal Maiden's single one is THIS branch:
--- tests/fixtures/f_260820_182906_lion_drain_survived.lua -- CM level 11,
--- 543/831 mana (65%, so it is the 440 disjunct that fires, not the 0.8 one),
--- one ally inside 1200, three enemies at 625.2u / 749.5u / 885.1u at 0.62 /
--- 0.94 / 0.97 health, no kill on the table.  Armed, that cast is declined.
--- It is the first Crystal Maiden lever in this repo whose armed leg changes a
--- decision the corpus actually reaches; see tests/test_cm_nova_surplus_poke.lua.
---
--- ⛔ THIS HELPER NAMES EXACTLY ONE ID.  Never conjoin it with `cmqreach` or
--- `cmrcrowd`: a gate naming a sibling freezes FALSE the day the sibling is
--- promoted (the `pullcad` trap) and check_armed_wiring.py still calls it WIRED.
--- ⛔ THE SHIPPED DISJUNCTION STAYS AT THE CALL SITE, passed in as
--- `bShippedSurplus` rather than rebuilt here from (pct, mana, keep).  It has to:
--- tests/_cm_t10_payoff_sweep.lua reads this file's mana gates out of the SOURCE
--- TEXT (`nMP <op> <n>` / `GetMana() <op> nKeepMana * <n>`), so moving the
--- expression behind renamed parameters deletes a gate from that sweep's model
--- while every assertion about THIS lever stays green -- the census reads 7
--- where it read 8 and nothing says which one left.  Caught on the first run of
--- tests/test_cm_t10_payoff.lua; same family as GH #650 (a census whose subject
--- moved out from under it).
function X.cm_ShouldSpendSurplusNova( hTarget, bShippedSurplus )

	if not bShippedSurplus then return false end

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmqpoke' ) ) then return true end

	if not J.IsValid( hTarget ) then return false end

	local nMaxHealth = hTarget:GetMaxHealth()
	if type( nMaxHealth ) ~= 'number' or nMaxHealth <= 0 then return true end

	return hTarget:GetHealth() / nMaxHealth < 0.4

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
	-- Gated ('cmqreach'): shipped answers nCastRange + nRadius, which is what
	-- puts an out-of-cast-range point into the eight unguarded creep return
	-- sites below.  See X.cm_GetCreepAoESearchRange.
	local nCreepSearch = X.cm_GetCreepAoESearchRange( nCastRange, nRadius )
	local nCanKillCreepsLocationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCreepSearch, nRadius, 0.5, nDamage )
	local nCanHurtCreepsLocationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCreepSearch, nRadius, 0.5, 0 )

	-- GH #346.  The `== nil` clause used to route execution INTO `.count = 0`,
	-- i.e. into indexing the very value it had just found nil -- the one line
	-- the guard exists to protect.  (`or` short-circuits, so the nil never
	-- reached J.GetInLocLaneCreepCount; the then-body was the whole defect.)
	-- The nil leg now substitutes the zero-count stand-in that the other two
	-- clauses produce by assignment, which is also what the four downstream
	-- `.count >= N` reads need.
	--
	-- EQUIVALENCE, which is why this is not gated: on every frame where the old
	-- code completed, the new code leaves identical state.  The substitution is
	-- reachable only when FindAoELocation returns nil, and on that frame the old
	-- code raised.  The differential is exactly the crashing frame.
	--
	-- NOT a nil-safety claim for CM: 350 of this repo's 353 FindAoELocation
	-- sites index the result unguarded, three of them in this same function.
	-- See tests/test_nil_guard_then_body.lua for that bound as a pin.
	if nCanHurtCreepsLocationAoE == nil then
		nCanHurtCreepsLocationAoE = { count = 0 }
	elseif nCanHurtCreepsLocationAoE.targetloc == nil
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
				-- [cmqpoke] was `nMP > 0.8 or bot:GetMana() > nKeepMana * 2`.
				-- Gate off the helper IS that expression.  See
				-- X.cm_ShouldSpendSurplusNova for the fact (this is the sibling
				-- branch six lines below with its quality test swapped for a
				-- wallet test), the direction guarantee, and the real frame.
				if X.cm_ShouldSpendSurplusNova( nWeakestEnemyHeroInBonus,
						nMP > 0.8 or bot:GetMana() > nKeepMana * 2 )
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


--- How much health a creep may have and still be worth freezing to farm it.
---
--- WHAT THE SHIPPED NUMBER IS.  `X.ConsiderW`'s "无英雄目标时冰冻小兵打钱" block
--- admits a creep whose health is `<= 1200`, twice, as a bare literal.  That is
--- not an arbitrary number: Frostbite's own KV says
---     damage_per_second 100  x  creep_multiplier 4  x  duration 1.5/2/2.5/3
---     =  600 / 800 / 1000 / 1200
--- so `1200` is EXACTLY the rank-4 figure.  The literal is the right quantity
--- frozen at the top of its own ladder -- the same shape as Zeus's static field
--- constant and Axe's `150 + 100*lv`, and the reason this is filed as a
--- rank-independence defect and not as "the number is wrong".
---
--- WHAT THAT COSTS.  At ranks 1-3 the block admits creeps this hero cannot kill
--- by 600 / 400 / 200 health, and admits them at the TOP of the window it
--- searches (`X.cm_GetStrongestUnit` returns the STRONGEST creep, so the
--- over-admitted band is precisely the band the picker prefers).  The spend is
--- 125-155 mana off a hero whose mana is this desk's standing scarcity (GH #126)
--- plus a 6-9s cooldown on her only single-target disable, for a creep that
--- walks out of the root alive.  The shipped row `{1,2,3,2,2,6,2,1,1,1,6,3,3,3,6}`
--- spends W at hero levels 2/4/5/7 (no talent sits below level 10, so those
--- indices ARE the levels), i.e. the band bites from level 2 to level 6 -- the
--- laning half of a turbo game, exactly where her mana is tightest, and the same
--- window `nLV >= 5` already lets this block open in.
---
--- DIRECTION IS BY CONSTRUCTION, and it is a NARROWING: `dps*mult*duration` is
--- `<= 1200` at every rank this file can reach, with equality at rank 4, so the
--- armed cap admits a strict SUBSET of the creeps the shipped cap admits.  It
--- can only remove a cast, never add one.  The one way it could widen is the
--- t25 half `special_bonus_unique_crystal_maiden_1` (+1.0s duration -> a real
--- 1600), and this file's own `tTalentTreeList['t25'] = {10, 0}` takes the OTHER
--- half, so that row is structurally untrained; the ratchet in
--- tests/test_cm_frostbite_creep_cap.lua fails if it ever moves.  (Were it
--- trained, the widened cap would be the CORRECT one -- the engine folds a
--- trained talent into the base read, GH #228 -- which is the second reason to
--- read the KV live instead of hardcoding a fifth constant.)
---
--- SHAPE (the GH #162 house rule, as in hero_lion.lua X.GetImpaleKillDamage).
--- The shipped expression is this function's LAST statement and the armed branch
--- is the only detour, so gate-off equivalence is structural; and an armed read
--- answering `<= 0` falls through to the shipped literal rather than inventing a
--- cap of 0, which would silently close the whole block instead of narrowing it.
---
--- Soak candidate 'cmcreepcap', turbo-only.  Domain, the driven ranks and the
--- corpus limit: tests/test_cm_frostbite_creep_cap.lua.
function X.cm_GetFrostbiteCreepCap( hAbility )

	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmcreepcap' )
	then
		local nKvCreepDamage = hAbility:GetSpecialValueInt( 'damage_per_second' )
							 * hAbility:GetSpecialValueInt( 'creep_multiplier' )
							 * hAbility:GetSpecialValueFloat( 'duration' )
		if nKvCreepDamage > 0
		then
			return nKvCreepDamage
		end
	end

	return 1200

end


--- Whether the FAR creep branch's mana-backed relaxed floor is met.  Soak
--- candidate `cmfarcreep`, turbo-only, INERT until armed.  Written 2026-09-07
--- under OWNER_PRIORITIES P4.4 (bots/ 主体配额).
---
--- THE DEFECT -- A FLOOR APPLIED TO A QUANTITY THAT IS NOT THE TARGET'S.
--- X.ConsiderW's "无英雄目标时冰冻小兵打钱" block has two halves, and each half
--- picks its own creep out of its own list:
---
---     nEnemysCreeps1 = bot:GetNearbyCreeps( nCastRange + 100, true )   -- NEAR
---     nEnemysCreeps2 = bot:GetNearbyCreeps( 1400, true )               -- WIDE
---     ...Creeps1/...Health1 = X.cm_GetStrongestUnit( nEnemysCreeps1 )
---     ...Creeps2/...Health2 = X.cm_GetStrongestUnit( nEnemysCreeps2 )
---
--- The "再近" half reads Health1 in all three of its terms and casts on Creeps1.
--- The "先远" half casts on Creeps2 and reads Health2 in its 460 floor and in its
--- `<= nCreepCap` cap -- but its relaxed floor reads **Health1**:
---
---     if ( ...Health2 > 460 or ( ...Health1 > 390 and nMP > 0.45 ) )
---         and ...Health2 <= nCreepCap
---     then  return BOT_ACTION_DESIRE_LOW, ...Creeps2
---
--- That is the ONLY term in either half that tests one creep to authorise a cast
--- on a different one.  Same family as `cmrangedhp` (a number that is not the
--- unit's health) and `cmcreepcap` (a cap that is not this rank's), arriving
--- through the third side of the same comparison: here both numbers are honest
--- healths and the wrong one is read.
---
--- WHY IT MATTERS MOST IN EXACTLY THE STATE THE BRANCH EXISTS FOR.  When there
--- is no qualifying creep in the NEAR list at all, Health1 is not 0 and it is not
--- the far creep's health -- X.cm_GetStrongestUnit initialises its running
--- maximum to `GetBot():GetAttackDamage()` and returns it untouched, so Health1
--- falls back to Crystal Maiden's attack damage.  Her ranged base is 39-45 and
--- neither buy list carries a damage item, so that fallback is a hero-stat
--- argument away from 390 at every level this block can open at (`nLV >= 5`), not
--- a coincidence of one frame.  ⇒ whenever the far creep is the ONLY candidate --
--- which is the whole point of the "先远" half running first -- the relaxed floor
--- is false and the branch can fire only above 460.  The mana term it is paired
--- with (`nMP > 0.45`) never gets to buy anything there.
---
--- ⚠️ THAT PARAGRAPH IS ARITHMETIC, NOT A FRAME READING, AND THE TWO MUST NOT BE
--- MERGED.  `GetAttackDamage` answers 0 on every fixture frame -- a .dem slice
--- carries neither attack damage nor attack speed (tests/mock/bot_api.lua) -- so
--- the corpus cannot report her real attack damage and this file does not pretend
--- it can.  What section 4 of the test pins is the FALLBACK'S IDENTITY (the
--- initialiser is the attack-damage read, not 0 and not Health2), which is the
--- half that decides the shape.
---
--- WHY IT IS A GATE.  It strictly WIDENS the branch's only relaxed floor, i.e. it
--- ADDS casts, and this stream ships an action-adding change dark until a wave has
--- sized its domain.
---
--- DIRECTION IS BY CONSTRUCTION, NOT BY MONOTONICITY.  The shipped test is
--- evaluated FIRST and returns true on its own; the armed path is only ever
--- reached after it answered false.  So the accepted set is a strict SUPERSET of
--- the shipped one for any pair of inputs whatsoever -- no argument about
--- `Health1 <= Health2` is load-bearing, and none is made.  (It happens to hold
--- while `cmrangedhp` is unarmed, because Creeps1 is a subset of Creeps2; with
--- that lever armed the ranged early-exit reports list-order-dependent healths and
--- it need not.  Writing the widening as an OR on top of the shipped term makes
--- this lever's direction independent of that one -- the `pullcad` lesson applied
--- to arithmetic rather than to gate ids.)
---
--- WHAT IS DELIBERATELY LEFT ALONE.  One term moves.  The 460 floor, the
--- `<= nCreepCap` cap, the creep-name curfew, the `DotaTime() > 10*60` clause, the
--- near half's 410/360 pair and the target itself are untouched -- arming cannot
--- change WHICH creep is frozen, only whether the far half fires at all.
---
--- WHAT IS NOT KNOWN.  The domain is UNSIZED and this corpus structurally cannot
--- size it: no fixture carries a creep UNIT (creeps appear only as combat-log
--- rows, with no health and no handle) and bot:GetNearbyCreeps answers an empty
--- table on every frame -- both pinned as one-way tripwires in
--- tests/test_cm_far_creep_floor.lua section 5, the same blocker `cmrangedhp` and
--- `cmcreepcap` both record.  Size it on a wave: iterations/queue.json `hero-42`.
--- Do NOT promote this on the (c) argument alone.
function X.cm_IsFarCreepFloorMet( nNearHealth, nFarHealth, nFloor )

	if nNearHealth > nFloor then return true end

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmfarcreep' ) ) then return false end

	return nFarHealth > nFloor

end


--- [cmlaneband] gated (turbo + soak candidate): may X.ConsiderW's lane-harass
--- firing point commit Frostbite to a hero it cannot reach?  INERT until armed.
--- Written 2026-09-08 (hero stream) under OWNER_PRIORITIES P4.4 (i).
---
--- WHAT IS WRONG.  X.ConsiderW builds TWO hero rings off one cast range --
--- `nEnemysHeroesInRange` (nCastRange) and `nEnemysHeroesInBonus`
--- (nCastRange + 200) -- and then bids from eight firing points.  Six of the
--- eight bound the target to roughly the cast range:
---
---     kill-confirm       nEnemysHeroesInRange
---     teamfight          J.GetNearbyHeroes( bot, nCastRange, ... )
---     protect-self       nEnemysHeroesInRange
---     lane last term     nEnemysHeroesInRange
---     进攻               J.IsInRange( npcTarget, bot, nCastRange + 50 )
---     撤退               J.IsInRange( npcEnemy,  bot, nCastRange - 80 )
---     roshan             J.IsInRange( botTarget, bot, nCastRange )
---
--- Exactly TWO read nEnemysHeroesInBonus with no distance term at all: the TP
--- interrupt, and the 对线期消耗 lane-harass branch this helper guards.
---
--- THIS HELPER IS ABOUT THE SECOND ONE, AND DELIBERATELY NOT ABOUT THE FIRST.
--- An interrupt is worth walking for -- it costs the enemy a whole teleport,
--- and the same argument was made and left standing for Wraith King's Q
--- (GH #621, tests/test_wk_q_lane_reach.lua section 0).  The lane-harass
--- branch's payoff is a HARASS on a target the branch itself has already
--- described as slower than CM, and the KILL case is the first firing point in
--- the function, which does bound distance.  So the loosest reach in the
--- function sits under the smallest payoff.
---
--- WHAT IT COSTS.  X.SkillsComplement hands the engine
--- `ActionQueue_UseAbilityOnEntity( abilityW, castWTarget )`, and on an
--- out-of-range target that order is a MOVE order first: CM walks the gap, in
--- lane, at 125-155 mana a cast.  The dispatch `return`s the moment W is
--- queued, so X.ConsiderR (Freezing Field) is not consulted for as long as the
--- desire holds.  Same family as `lionrreach` (GH #617) and `wkqlane`
--- (GH #621) on a third hero.
---
--- THE SLACK IS THE FUNCTION'S OWN, NOT A NEW NUMBER.  `+50` is what the 进攻
--- firing point -- the other place in this function that COMMITS to one chosen
--- hero -- already allows.  Armed, the lane-harass branch may commit exactly
--- where the offence branch would commit, and nowhere further.
---
--- ⚠️ `nCastRange` IS A PARAMETER, not a constant re-typed here.  The caller's
--- value already carries `+ 30`, `aetherRange`, and the lone-enemy attack-range
--- extension above it, so the gate composes with all three instead of freezing
--- one of today's values (the `pullcad` lesson applied to arithmetic).
---
--- DIRECTION IS SINGLE.  Gate off the answer is an unconditional `true`, so the
--- armed set is a strict subset of the shipped one: arming can only ever REFUSE
--- a cast, never add one.  A negative reading may not be read as "CM cast more".
--- It also cannot RELOCATE a refused cast inside this function: every firing
--- point below reads a ring that is tighter (nCastRange, +50, -80) or demands a
--- different target class, so a refused band hero is refused outright.
---
--- ⚠️ WHAT THIS ROUND DID NOT BUY.  That the branch AS A WHOLE fires on an
--- archive frame is NOT a reading this round holds -- two of its conjuncts are
--- undrivable offline, and both reasons are about the harness, not the game:
--- `bot:GetActiveMode()` is bot-VM state that is in no .dem, and the fixture
--- loader hands EVERY unit `GetCurrentMovementSpeed = 300`, so the branch's own
--- `target speed < bot speed` term is `300 < 300` on every frame in the corpus.
--- tests/test_cm_w_lane_band.lua section 6 states both as the limits they are.
--- Size the domain on a wave: iterations/queue.json `hero-47`.
function X.cm_IsLaneHarassTargetInReach( hBot, hTarget, nCastRange )

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmlaneband' ) ) then return true end

	return J.IsInRange( hTarget, hBot, nCastRange + 50 )

end


--- The heading cone X.ConsiderW's SELF-DEFENCE branch reads before it is allowed
--- to Frostbite the hero who is hitting Crystal Maiden.  Kept as a named number
--- so the gate below and tests/test_cm_w_selfdefense_facing.lua read the same 45
--- the shipped tree read, from one place.
X.nWSelfDefenseFacingCone = 45


--- SOAK CANDIDATE 'cmwface' (turbo-only).  Not armed; gate OFF is the shipped
--- predicate, byte for byte -- the same call on the same handle with the same
--- cone.
---
--- THE DEFECT, in one line of shipped source (X.ConsiderW, the 保护自己 branch):
---
---     and bot:IsFacingLocation( npcEnemy:GetLocation(), 45 )
---
--- X.ConsiderW has FIVE branches that commit Frostbite -- 击杀 (kill), 打断TP
--- (interrupt a teleport), 团战 (team fight, most dangerous), 保护自己 (self
--- defence) and 对线期消耗 (lane harass).  Exactly ONE of them asks where Crystal
--- Maiden happens to be looking, and it is the defensive one: the branch whose
--- trigger is `bot:WasRecentlyDamagedByAnyHero( 3.0 )`, i.e. the branch that only
--- opens while a hero is beating on her.
---
--- THE FACT.  Frostbite is UNIT-TARGETED (crystal_maiden_frostbite,
--- DOTA_ABILITY_BEHAVIOR_UNIT_TARGET).  The engine turns the caster through the
--- cast point for a unit-targeted order; heading is not a precondition of the
--- cast, and no other Frostbite branch in this file treats it as one.  So the
--- cone forbids nothing the engine forbids -- it only suppresses a legal cast.
---
--- WHY THAT LANDS ON THE DEFENSIVE BRANCH HARDEST.  Its premise and its guard
--- point in opposite directions.  A support who is being focused is walking away
--- from whoever is focusing her, and a hero's heading follows her movement order,
--- so "a hero damaged me in the last 3 seconds" is exactly the state in which she
--- is LEAST likely to be looking at him.  The one branch that exists to answer
--- being attacked is gated on not having turned to run.
---
--- WHAT DELIBERATELY DOES NOT CHANGE.  One conjunct, one branch.  Every other
--- guard on the loop stays (validity, non-magic-immune, CanCastOnTargetAdvanced,
--- not already disabled, not disarmed), the branch's own two-part premise stays,
--- the cone stays live on the shipped leg, and the four sibling branches are not
--- touched.  The lever can only ADD a cast, never remove one
--- (tests/test_cm_w_selfdefense_facing.lua section 4.2 asserts that direction
--- over the whole CM corpus).
---
--- ⚠️ WHAT THIS ROUND DID NOT BUY -- READ BEFORE QUOTING THE PIN.  `IsFacingLocation`
--- is NOT answerable from the corpus: make_fixture.py dumps x/y and no heading,
--- so the loader installs no spec for it and the mock's generic Is* default
--- answers FALSE at all 317 call sites under bots/.  Therefore the pin frame's
--- NONE -> HIGH flip is produced by the mock's default, NOT by a recorded
--- heading, and this note does NOT claim that the shipped tree failed to cast in
--- that game.  What the pin DOES buy is that on a real frame every OTHER conjunct
--- of the branch holds at once -- two enemy heroes who had just dealt her damage,
--- both inside Frostbite's real 600 cast range, neither disabled nor disarmed,
--- the spell off cooldown and affordable, and she died 1.0s later.  How often the
--- cone actually blocks is a FREQUENCY and needs a wave: iterations/queue.json
--- `hero-53`.
---
--- ⚠️ THE SIBLINGS ARE NOT IN THIS LEVER.  The identical cone sits in
--- hero_skeleton_king.lua (X.ConsiderQ's 受到伤害时保护自己 branch) and in
--- hero_zuus.lua.  They are the same upstream idiom and probably the same defect,
--- but they are NOT gated here: one lever at a time, and the Wraith King branch's
--- corpus domain is EMPTY anyway (measured -- no WK fixture carries level >= 6,
--- Hellfire Blast ready, hero damage inside 3s and an enemy in cast range at
--- once), so it could not be pinned this round even if it rode along.
function X.cm_IsSelfDefenseFacingOk( hBot, hTarget )

	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmwface' ) then return true end

	return hBot:IsFacingLocation( hTarget:GetLocation(), X.nWSelfDefenseFacingCone )

end


--- The lookback X.ConsiderW's SELF-DEFENCE branch already uses to decide that it
--- is under attack at all (`bot:WasRecentlyDamagedByAnyHero( 3.0 )`).  Named so
--- the branch's TRIGGER and the per-candidate question below cannot drift apart:
--- the whole point of 'cmwhit' is that they are the SAME window asked once
--- existentially and once per candidate.
X.nWSelfDefenseDamageWindow = 3.0


--- Every per-candidate guard X.ConsiderW's SELF-DEFENCE branch puts on a
--- Frostbite target, in the shipped order and with the shipped short-circuit.
--- No soak gate of its own -- it is the shipped chain, moved so that both legs
--- of X.cm_FindSelfDefenseTarget are demonstrably about the same predicate
--- rather than about two copies of it.
---
--- ⚠️ Its last conjunct is X.cm_IsSelfDefenseFacingOk, which carries 'cmwface'.
--- That is a CALL, not a conjunction of two soak ids (the `pullcad` trap is a
--- gate whose own condition names a SECOND id, which freezes FALSE the day
--- either is promoted -- see the statement of it in bots/FunLib/jmz_func.lua;
--- ⚠️ it is not restated with quoted id literals HERE because
--- tests/test_gate_claim_consistency.lua reads a quoted id in this file as a
--- WIRED id, and a made-up one enrols this file in a register that means
--- something else entirely).  'cmwhit' and 'cmwface' are
--- orthogonal and independently armable: 'cmwface' decides how many candidates
--- clear the chain, 'cmwhit' decides which of the ones that clear it is taken.
function X.cm_IsSelfDefenseCastable( hBot, hEnemy )

	return J.IsValid( hEnemy )
		and J.CanCastOnNonMagicImmune( hEnemy )
		and J.CanCastOnTargetAdvanced( hEnemy )
		and not J.IsDisabled( hEnemy )
		and not hEnemy:IsDisarmed()
		and X.cm_IsSelfDefenseFacingOk( hBot, hEnemy )

end


--- SOAK CANDIDATE 'cmwhit' (turbo-only).  Not armed.  STANDALONE: this function
--- holds exactly one J.IsSoakCandidate call and it names only 'cmwhit'.
---
--- THE DEFECT, in the shipped source of X.ConsiderW's 保护自己 branch:
---
---     if bot:WasRecentlyDamagedByAnyHero( 3.0 )          <- the TRIGGER
---         and #nEnemysHeroesInRange >= 1
---     then
---         for _, npcEnemy in pairs( nEnemysHeroesInRange ) do
---             if <the chain above> then return HIGH, npcEnemy end   <- the TARGET
---
--- The branch OPENS on an existential fact about damage -- "some hero has been
--- hitting me" -- and then hands the target question to the ordering of a list
--- whose sort key is DISTANCE.  `J.GetNearbyHeroes` filters the engine's
--- `GetNearbyHeroes`, which docs/BOT_API_REFERENCE.md makes sorted-by-distance
--- for the whole family, and it never reorders; so the loop returns the NEAREST
--- hero who can legally be frozen.  Whether that hero is the one doing the
--- damage is never asked.
---
--- ⭐ WHY SORTING THE LIST IS NOT THE FIX (the GH #731 shape, not GH #724's).
--- The list is ordered CORRECTLY.  The predicate the branch is about is
--- AUTHORSHIP OF THE DAMAGE, and the sort key is distance; they are different
--- questions, and the shipped term answers the first with the second's handle.
--- Frostbite is a single-target root that also disarms for its duration, so the
--- defensive value it buys is entirely "the source of the incoming damage stops
--- being able to apply it".  Spent on a bystander who happens to stand 21 units
--- closer, it stops nothing: the hero actually beating on her keeps attacking,
--- and the cooldown that could have answered him is gone.
---
--- ⭐ THE BINDING ALREADY EXISTS IN THIS TREE, AND THIS IS THE SITE THAT LEFT IT
--- UNBOUND.  `bot:WasRecentlyDamagedByHero( npcEnemy, t )` is the per-candidate
--- form of the very call this branch's trigger makes, and it is the live idiom
--- here: 19 call sites under bots/, including this file's own X.ConsiderQ
--- (:1566), hero_skeleton_king.lua (:1118), hero_lion.lua (:786, :1085) and
--- hero_zuus.lua (:1399).  So this is not a new judgement -- it is the tree's
--- own per-candidate predicate, applied at the one self-defence firing point in
--- the focus five that opens on the ANY form and then never narrows to it.
---
--- DIRECTION: NEITHER A WIDENING NOR A NARROWING.  Pass 1 requires the shipped
--- chain AND authorship; pass 2 IS the shipped scan.  So the armed leg returns
--- non-nil on exactly the frames the shipped leg does -- the branch fires the
--- same number of times, on the same frames, with the same desire -- and the
--- only thing that can differ is WHICH qualifying enemy is handed back.  That
--- is asserted over the corpus rather than argued
--- (tests/test_cm_w_selfdefense_damager.lua §4).
---
--- THE READING (one real frame, real positions, real recorded damage).
--- tests/fixtures/f_260820_102645_cm_es_reach.lua -- Crystal Maiden with two
--- enemies inside Frostbite's cast ring:
---
---     earthshaker   536.0u   did NOT damage her in the last 3s
---     bristleback   556.9u   DID damage her in the last 3s
---
--- 20.9 units of distance decide the shipped target, and they decide it against
--- the only hero in the ring who was actually hitting her.  The damage history
--- is the .dem's own `recent_damage` rows, not a stub
--- (tests/mock/replay_fixture.lua:550).
---
--- ⛔ WHAT THIS DOES NOT CLAIM, AND THE FIRST ONE IS THE IMPORTANT ONE.
--- (1) THE PIN IS A READING AT THE FINDER, NOT A RECORDED FAILURE TO CAST.
--- Frostbite is 1.5s into its cooldown on that frame, so X.ConsiderW returns
--- NONE at its first line and the 保护自己 branch is never evaluated there.
--- The flip is measured on the ring the branch WOULD have built.  The corpus
--- does supply frames where the whole branch is reachable (>= 3 of them) -- it
--- simply supplies no single frame that is reachable AND flips.  Both halves
--- are asserted, in that direction (tests §3.3 / §3.4).
--- (2) That the added root lands a kill or saves the life -- it claims only
--- that the disable is spent on the damage source.
--- (3) A FREQUENCY.  Over the whole 70-instant CM corpus, 13 instants have her
--- recently damaged and exactly ONE of them has a ring where the nearest legal
--- target is not a damager; how often that holds in a real Turbo game is a wave
--- question, filed as iterations/queue.json hero-60.
--- (4) That the siblings are covered: the same ANY-trigger-then-nearest-target
--- shape sits in hero_skeleton_king.lua X.ConsiderQ (Hellfire Blast) and
--- hero_zuus.lua X.ConsiderW (Lightning Bolt).  One lever at a time, and their
--- corpus flip count is 0 today (tests §1.1 counts it).  ⚠️ Axe is NOT in this
--- family however much the trigger looks alike -- Berserker's Call is a
--- no-target taunt, so there is no per-target choice for authorship to move.
function X.cm_FindSelfDefenseTarget( hBot, tEnemies )

	if tEnemies == nil then return nil end

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmwhit' ) )
	then
		for _, hEnemy in ipairs( tEnemies )
		do
			if X.cm_IsSelfDefenseCastable( hBot, hEnemy ) then return hEnemy end
		end
		return nil
	end

	for _, hEnemy in ipairs( tEnemies )
	do
		if X.cm_IsSelfDefenseCastable( hBot, hEnemy )
			and hBot:WasRecentlyDamagedByHero( hEnemy, X.nWSelfDefenseDamageWindow )
		then
			return hEnemy
		end
	end

	for _, hEnemy in ipairs( tEnemies )
	do
		if X.cm_IsSelfDefenseCastable( hBot, hEnemy ) then return hEnemy end
	end

	return nil

end


--- The shipped wall clock on X.ConsiderW's teamfight firing point, and the
--- turbo value that halves it.  Named so the two legs of X.cm_IsTeamfightClockOpen
--- read as one question asked at two thresholds, and so the test can mirror the
--- numbers off the source instead of re-typing them (the stale-mirror family:
--- tests/test_cast_ring_mirror_discipline.lua).
X.nWTeamfightClockShipped = 6 * 60
X.nWTeamfightClockTurbo   = 3 * 60


--- The wall-clock curfew on X.ConsiderW's TEAMFIGHT firing point, and the
--- turbo-only narrowing of it.  Soak candidate `cmtfclock` (turbo-only, INERT
--- until armed).  STANDALONE: this function holds exactly one J.IsSoakCandidate
--- call and it names only its own id.
---
--- ⭐ THE DEFECT IS NOT "6 MINUTES IS TOO LONG".  It is that the curfew is
--- INVERTED WITH RESPECT TO THE EVIDENCE.  X.ConsiderW bids from eight
--- HERO-target firing points (the census is in X.cm_IsLaneHarassTargetInReach's
--- header).  Exactly ONE of them carries a wall clock, and it is the one whose
--- own precondition is the strongest evidence a cast is warranted:
---
---     teamfight      J.IsInTeamFight( bot, 1200 )   + DotaTime() > 6 * 60
---     kill-confirm   a weakest enemy in the ring     (no clock)
---     protect-self   she is being hit right now      (no clock)
---     TP interrupt   an enemy is teleporting         (no clock)
---     进攻 / 撤退 / roshan / 对线期消耗                (no clock)
---
--- ⚠️ "HERO-target" is load-bearing and was written after the test caught this
--- paragraph's first draft.  The function does read DotaTime() twice more, on
--- the two CREEP branches (先远 / 再近) -- but each of those is a DISJUNCT,
--- `DotaTime() > 10 * 60 or <this creep is not a basic lane creep>`, so time
--- RELAXES a target-class rule there rather than gating a cast.  Opposite
--- shape, different target class, not in this lever
--- (tests/test_cm_w_teamfight_clock.lua §5.1 pins both counts).
---
--- So a lane HARASS -- the smallest payoff in the function, and the one
--- `cmlaneband` had to put a reach term on -- may fire at 0:30, while a real
--- five-hero fight with Frostbite off cooldown and a legal target in range is
--- refused until 6:00.  Whatever the clock was a proxy FOR ("laning is over,
--- fights are real"), `J.IsInTeamFight( bot, 1200 )` is the direct measurement
--- of it, and it is already the first conjunct.  The proxy overrides the
--- measurement, and only here.
---
--- ⛔ AND IT IS NOT A MANA POLICY, checked rather than assumed.  X.ConsiderW's
--- only entry guard is `abilityW:IsFullyCastable()`; the function has no mana
--- reserve of any kind at any of its eight firing points (unlike X.ConsiderQ,
--- which carries J.ShouldConserveManaInLane, and unlike the Roshan branches
--- elsewhere in this file, which carry J.GetManaAfter).  So the clock cannot be
--- read as "do not spend her small early pool" -- if it were, it would be on the
--- function, not on one branch of it.
---
--- WHY TURBO IS WHERE THIS BITES.  6 minutes is a NORMAL-MODE constant.  This
--- project's optimization target is Turbo (docs/PROJECT.md), where games run
--- ~20 minutes against ~35-40 -- so the curfew costs roughly 30% of the game,
--- and it costs the FIRST 30%, which in Turbo is not a farming phase at all:
--- doubled XP/gold and halved respawns mean five-hero fights genuinely happen
--- before 6:00, which is the mode's defining property.  Frostbite's value is
--- also highest exactly there -- a 1.5-3s root that also disarms, thrown at
--- hero levels where nobody owns a BKB or a dispel and HP pools are small.
---
--- ARMED: 3 * 60, which is the shipped number halved.  The 2x is not invented
--- here -- it is this repo's own stated Turbo pace ratio (~20 min vs ~35-40).
--- Halving rather than REMOVING is deliberate and is the narrow change: whether
--- the branch should carry a clock AT ALL is a second question, and conjoining
--- the two would make one wave reading unattributable to either.
---
--- ⚠️ DIRECTION: THIS IS A WIDENING, and it is the first thing a reader must
--- know.  Every t past 6:00 is also past 3:00, so the armed predicate is a
--- strict SUPERSET of the shipped one: arming can only ADD teamfight casts, in
--- the window (3:00, 6:00], and can never remove or move one.  Asserted over
--- the whole corpus rather than argued (tests/test_cm_w_teamfight_clock.lua §4).
--- A negative wave reading is therefore attributable to "those early-fight
--- Frostbites were not worth casting" and NEVER to a cast this lever refused.
--- It also cannot relocate a cast: the branch sits ABOVE 保护自己 / 进攻 /
--- 撤退 / roshan, so a frame the clock refuses falls through to them today and
--- an armed frame simply stops earlier with a target those branches could not
--- have chosen the same way (they pick by distance or by damage authorship;
--- this one picks by GetEstimatedDamageToTarget).
---
--- THE READING (one real frame, real clock, real roster, nothing moved).
--- tests/fixtures/f_260820_162821_lion_drain_lethal.lua at t=307.4 (5:07) --
--- Crystal Maiden loaded as the subject unit.  J.IsInTeamFight( bot, 1200 ) is
--- TRUE on the real frame with no injection, Frostbite's real ring (630 = real
--- GetCastRange + 30 + the aether term) holds one enemy hero, and that hero
--- clears the branch's whole per-candidate chain.  Shipped refuses on the clock
--- alone; armed enters.  307.4 is 52.6s inside the window this lever opens.
---
--- ⛔ TWO DOMAINS, REGISTERED SEPARATELY because they are different numbers and
--- a reader who conflates them has performed an execution verification out of
--- thin air:
---   * GATE-LAYER domain = 1 corpus frame (the pin above): the clock is the
---     only thing refusing.
---   * END-TO-END domain = 0 corpus frames: on that same frame Frostbite is on
---     cooldown, so X.ConsiderW returns NONE at its first line and the branch is
---     never evaluated there.  The flip is measured on the clock the branch
---     WOULD have read.  Same shape as `cmwhit`, and both halves are asserted
---     in that direction (tests §3.3 / §3.4).
---
--- ⚠️ NOT A FREQUENCY.  Over the whole 70-instant CM corpus: 5 instants have a
--- teamfight running, 15 sit in (3:00, 6:00], and exactly 1 is both.  How often
--- a real Turbo game puts a fight in that window is a wave question, filed as
--- iterations/queue.json hero-61.
function X.cm_IsTeamfightClockOpen()

	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmtfclock' )
	then
		return DotaTime() > X.nWTeamfightClockTurbo
	end

	return DotaTime() > X.nWTeamfightClockShipped

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
	local nCreepCap = X.cm_GetFrostbiteCreepCap( abilityW )

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
	-- [cmtfclock] gate off the second conjunct is `DotaTime() > 6 * 60`, byte
	-- for byte.  See X.cm_IsTeamfightClockOpen just above X.ConsiderW.
	if J.IsInTeamFight( bot, 1200 )
		and X.cm_IsTeamfightClockOpen()
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
	if bot:WasRecentlyDamagedByAnyHero( X.nWSelfDefenseDamageWindow )
		and #nEnemysHeroesInRange >= 1
	then
		-- [cmwhit] gate off this is the shipped scan: the first member of
		-- nEnemysHeroesInRange clearing the shipped chain (validity,
		-- non-magic-immune, CanCastOnTargetAdvanced, not disabled, not
		-- disarmed, and the [cmwface] heading cone), i.e. the NEAREST legal
		-- target.  Armed, a member who actually damaged her inside the same
		-- window this branch's own trigger reads is preferred, and the shipped
		-- scan is the fallback -- so the branch fires on exactly the same
		-- frames either way.  Read X.cm_FindSelfDefenseTarget's header for the
		-- quantifier, the direction, and the one real frame that separates the
		-- two legs.  ⚠️ the loop is `ipairs` where the shipped source wrote
		-- `pairs`; nEnemysHeroesInRange is built by table.insert with no holes,
		-- so the two visit the same members in the same order, and
		-- tests/test_cm_w_selfdefense_damager.lua §2 asserts that over the
		-- corpus rather than asserting it here in prose.
		local npcEnemy = X.cm_FindSelfDefenseTarget( bot, nEnemysHeroesInRange )
		if npcEnemy ~= nil
		then
			return BOT_ACTION_DESIRE_HIGH, npcEnemy
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
				and X.cm_IsLaneHarassTargetInReach( bot, nWeakestEnemyHeroInBonus, nCastRange )
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
			-- [cmfarcreep] gate off the middle term is `...Health1 > 390`, byte for
			-- byte; the floor stays a literal HERE so it reads beside its siblings
			-- (460 above, the cap below, 410/360 in the near half).  See
			-- X.cm_IsFarCreepFloorMet: the far half is the only place in this block
			-- where a floor is applied to a creep other than the one being cast on.
			if ( nEnemysStrongestCreepsHealth2 > 460
					or ( X.cm_IsFarCreepFloorMet( nEnemysStrongestCreepsHealth1, nEnemysStrongestCreepsHealth2, 390 )
							and nMP > 0.45 ) )
				and nEnemysStrongestCreepsHealth2 <= nCreepCap
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
				and nEnemysStrongestCreepsHealth1 <= nCreepCap
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
--
-- ADDENDUM 2026-09-01 (hero, tests/test_cm_ult_reach_meter_domain.lua). Two
-- things about this id that the pre-flight above could not see, neither of them
-- a change to its parked status:
--
--   * A SECOND domain frame exists, from a game outside the pre-flight's
--     corpus: 20260820_043039 t=515.5, pinned as
--     tests/fixtures/f_260820_043039_cm_cask_close.lua (CM at 30.0% health, 0
--     allies within 1200, dead 0.2s later). It fires branch 1 on
--     `#nEnemysHeroesInRange >= 3`, which reads NO movespeed -- so the
--     "at ms >= 330 the domain is 0" fragility above no longer covers the whole
--     domain. Over the whole fixture archive (48 live-CM instants) those two
--     frames are the ONLY ones where the ultimate's fire branches are reachable
--     at all, and arming this id withholds the channel on both.
--   * CLOSED FORM: this veto can only ever change a branch-1 or branch-2 bid.
--     It fires strictly BELOW X.nRSelfHpFloor while branch 3 requires strictly
--     ABOVE the same constant, so the two are disjoint -- and branches 1 and 2
--     both multiply through `abilityR:GetAOERadius()`. If the engine answers 0
--     for that getter on Freezing Field (its KV declares `radius` but no
--     AbilityAOERadius key, and no offline reading of the engine exists here),
--     this id is a no-op by construction; if it answers the radius, its domain
--     is exactly the fire set. The fixture world's own GetAOERadius answers 0
--     today, which is why no test could reach these frames before.
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

--- The escape term X.ConsiderR's HEAD-COUNT disjunct never had -- soak candidate
--- `cmrcrowd` (turbo-only, INERT until armed).
---
--- THE DEFECT.  Branch 1 of X.ConsiderR opens the channel on
---     `#nEnemysHeroesInRange >= 3 or aoeCanHurtCount >= 2`
--- and the two disjuncts are not two readings of one idea.  The right-hand one
--- is a QUALITY test the function computes six lines above itself: an enemy is
--- counted only if he is disabled, or standing close enough that
--- `nRadius * 0.82 - GetCurrentMovementSpeed()` still reaches him -- i.e. only if
--- he cannot simply leave.  The left-hand one is a bare HEAD COUNT of the same
--- list with the quality test dropped.  So the one path in this function that
--- opens on a crowd is the one path that never asks whether the crowd can be hit,
--- and it SHORT-CIRCUITS the test: `or` evaluates left first, so three mobile
--- enemies at 735u release the channel while two of them standing still would
--- have had to earn it.  This is the shape the file already rejects everywhere
--- else, arriving through the one door that does not check.
---
--- WHAT IT COSTS, on the real frame this was written from.
--- `tests/fixtures/f_260820_043039_cm_cask_close.lua` (20260820_043039_slot1,
--- t=515.5, 8:35) -- CM at 267/890 hp (0.30), THREE visible enemies inside the
--- 734.8u field (witch_doctor 546u, slardar 571u, shadow_shaman 609u), ZERO
--- allied heroes inside 1200u.  Every one of the three is outside
--- `734.8 * 0.82 - 300 = 302.5` and none is disabled, so `aoeCanHurtCount == 0`
--- and the head count is the SOLE reason for the bid.  Shipped X.ConsiderR
--- answers 0.75 there.  The fixture's ground truth is `died_after = 0.2`: she was
--- dead two tenths of a second later, so the 10s channel this bid asks for is one
--- she did not have.  Zero injection beyond the AoE-radius anchor named under
--- LIMITS.
---
--- CONDITION (c), argued rather than assumed.  crystal_maiden_freezing_field is
--- `AbilityChannelTime 10` with `AbilityCooldown 100/95/90` (KV, mirrored in
--- tests/mock/special_value_shapes.lua): casting it converts CM into a
--- stationary, silence-able target for ten seconds, and its damage is paid out in
--- 0.1s explosion ticks over that whole window rather than on impact.  Standard
--- practice with a channelled AoE is therefore to open it on enemies that are
--- COMMITTED -- held by a disable, or too deep to walk out -- and this file
--- already writes that down; the head-count path is the exception, not the rule.
--- Three enemies who can walk cover the 735u radius in ~1.5s at 300 movespeed, so
--- what the bid buys on such a frame is a couple of ticks against a 90-100s
--- cooldown, in Turbo, where the whole game is ~20 minutes.
---
--- ARMED (`cmrcrowd`, turbo only): the head-count disjunct additionally requires
--- `aoeCanHurtCount >= 1` -- ONE enemy who cannot leave, not two.  The
--- `aoeCanHurtCount >= 2` disjunct is untouched, so a genuinely pinned pair still
--- releases the channel with no ally in sight.
---
--- DIRECTION BY CONSTRUCTION, not by today's data (the `cullthresh` lesson).  The
--- armed predicate is the shipped one AND an extra conjunct on one disjunct, so
--- the armed release set is a strict SUBSET of the shipped one for every
--- (head count, hurt count) pair.  Arming this id can only REMOVE releases; it
--- can never add one.  A negative wave read is attributable to "the withheld
--- channels were worth opening" and never to a cast this lever invented.
--- tests/test_cm_r_crowd_release.lua §3 sweeps the whole (count, hurt) grid
--- rather than asserting a single cell, which is the shape of test that caught
--- `cullthresh`'s first, wrong guard.
---
--- ⚠️ LIMITS, four, none rhetorical:
---   1. `GetAOERadius()` is not one of the seven getters the fixture loader
---      specs, so it answers 0 offline and every reading above rides the 835
---      Liquipedia ANCHOR that tests/test_replay_260819_cm_r_range.lua
---      established and GH #502 ruled must not be sourced from the KV's 810.
---      Anchor moves ⇒ these numbers move.
---   2. `GetCurrentMovementSpeed()` is not in the dump; the mock answers a flat
---      300.  On the frame above the answer survives that -- the quality test
---      admits nobody for any movespeed above 56.5, and hero movespeed is never
---      that low -- but a frame whose nearest enemy sits between
---      `nRadius*0.82 - ms` and `nRadius*0.82` is decided by the mock, not by the
---      game.  Say so before quoting a corpus-wide hurt count.
---   3. 1 domain frame is not a frequency.  Of the 10 Crystal-Maiden-subject
---      fixtures exactly one carries three enemies inside the field; how often
---      the shape occurs per game needs a wave (iterations/queue.json hero-52).
---   4. This lever does NOT touch branch 1's missing ALLY term -- `nAllies` is
---      computed at the top of X.ConsiderR and read only by branch 2.  Whether a
---      solo CM should ever open on a crowd is a separate question with a
---      separate id; one lever at a time.
X.nRCrowdHurtFloor = 1

function X.cm_IsFieldCrowdReleaseOk( nAoeCanHurtCount )

	if J.IsModeTurbo() and J.IsSoakCandidate( 'cmrcrowd' )
	then
		return nAoeCanHurtCount >= X.nRCrowdHurtFloor
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
		-- [cmrcrowd] the escape term the head-count disjunct never had.  See
		-- X.cm_IsFieldCrowdReleaseOk above; gate off it is `true`, byte for byte.
		if ( ( #nEnemysHeroesInRange >= 3 and X.cm_IsFieldCrowdReleaseOk( aoeCanHurtCount ) )
			 or aoeCanHurtCount >= 2 )
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
--- King's and Lion's innates are present on 33/33 and 23/23 frames; Crystal
--- Maiden's ability array is exactly four entries on 53/53 frames, with the
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
--- ultimate is on cooldown on 10 of those 53 frames -- so it WAS cast, so index
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
--- is not what ships today -- her ultimate is on cooldown on 10 of 53 frames,
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

--- The health `X.cm_GetStrongestUnit` REPORTS for the ranged creep it early-
--- returns.  Soak candidate `cmrangedhp`, turbo-only.
---
--- WHAT THE SHIPPED NUMBER IS.  Every other exit of the two pickers in this file
--- hands back the unit's own health (`nWeakestUnitLowestHealth`,
--- `nStrongestUnitHealth`), and X.ConsiderW consumes the second return value as
--- a health, twice:
---
---     if ( nEnemysStrongestCreepsHealth2 > 460 or ( ...Health1 > 390 and ... ) )
---         and nEnemysStrongestCreepsHealth2 <= nCreepCap
---     if ( nEnemysStrongestCreepsHealth1 > 410 or ( ...Health1 > 360 and ... ) )
---         and nEnemysStrongestCreepsHealth1 <= nCreepCap
---
--- The ranged-creep exit alone hands back the literal `500`.  So on that exit
--- the caller's four floors and its cap are all applied to a number that is not
--- the creep's health and does not move with it.
---
--- IT IS THE SAME LITERAL DEFECT `cmcreepcap` (GH #541) FIXED, ARRIVING THROUGH
--- THE OTHER SIDE OF THE COMPARISON, AND `cmcreepcap` CANNOT REACH IT: that
--- lever repaired the CAP, and on this exit the quantity being capped is a
--- constant, so a correct cap is compared against a fabricated health.
---
--- WHAT 500 COSTS, IN BOTH DIRECTIONS AT ONCE -- this is not one error:
---   * IT LIES HIGH on a damaged creep.  The exit's own admission test is
---     `GetHealth() > GetBot():GetAttackDamage() * 2`, so a ranged creep is
---     admitted from `2*ad` upward; every one of them is then reported as 500,
---     which clears all four floors (500 > 460, 410, 390, 360).  The window in
---     which the report is a lie in this direction is `(2*ad, 460]`, non-empty
---     for every attack damage below 230 -- section 2 reads `ad` off the real
---     frames rather than assuming it.  Cost: 125-155 mana and a 6-9s cooldown
---     on her only single-target disable, spent on a creep two auto-attacks
---     would have taken, at the exact hero levels this desk has on record as
---     her tightest mana window (GH #126).
---   * IT LIES LOW on a healthy one.  500 <= nCreepCap holds at EVERY rank
---     (600/800/1000/1200), so the kill test the cap exists to run is never run
---     on this exit.  The window is `(nCreepCap, 1100]` -- 1100 being this
---     function's own health bar three lines below -- non-empty at Frostbite
---     ranks 1-3 and empty at rank 4.  Cost: the creep walks out of the root.
---
--- ARMED: report the creep's own health, which is what every other exit of
--- both pickers reports and what the caller's five terms are written against.
---
--- DIRECTION IS BY CONSTRUCTION AND IT IS A NARROWING.  The unit returned does
--- not change -- only the number does -- and all five consuming terms are
--- monotone in it (`> floor` four times, `<= cap` once) with 500 satisfying
--- every one of them.  So any other value can only turn a true into a false:
--- arming can REMOVE a freeze and can never add one, and it can never change
--- WHICH creep is frozen.  A negative wave read may be blamed on "she should
--- have frozen that creep after all"; it may never be blamed on this lever
--- having invented a cast or moved a target.
---
--- SHAPE (the GH #162 house rule): the shipped literal is this function's last
--- statement and the armed branch is the only detour, so gate-off equivalence
--- is structural; and a health reading `<= 0` falls through to the shipped
--- literal rather than reporting 0, which would not narrow the block on this
--- exit -- it would CLOSE it, since 0 fails every floor.
---
--- ⚠️ COVERAGE, stated before anyone quotes this as fixture-validated, AND THE
--- TWO SENTENCES MUST NOT BE MERGED.  The changed term cannot be driven with a
--- real creep: no fixture under tests/fixtures/ carries a creep UNIT (creeps
--- appear only as combat-log `recent_damage` rows, which have no health and no
--- handle), and bot:GetNearbyCreeps answers an empty table on every frame --
--- both pinned as one-way tripwires in tests/test_cm_ranged_creep_health.lua
--- section 5.  What IS read off real frames is the WIDTH OF BOTH WINDOWS above:
--- `2*ad` from the real Crystal Maiden on each frame and `nCreepCap` from the
--- real Frostbite handle on each frame (section 2).  The creep's health is the
--- one variable the corpus cannot supply, and this file does not pretend
--- otherwise.  Sizing is iterations/queue.json hero-36, never this scan.
---
--- REGISTERED, NOT TAKEN (a second, independent property of the same exit):
--- the `return` also ENDS the search, so the picker hands back the first
--- qualifying ranged creep in list order rather than the strongest, which
--- contradicts its own name.  That is a TARGET-IDENTITY change and this lever
--- deliberately does not make it -- keeping the target fixed is exactly what
--- makes the direction argument above hold by construction.
function X.cm_GetRangedCreepReportedHealth( hUnit )

	local nShipped = 500

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrangedhp' ) ) then return nShipped end

	if hUnit == nil then return nShipped end

	local nHealth = hUnit:GetHealth()

	if nHealth == nil or nHealth <= 0 then return nShipped end

	return nHealth

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
				-- [cmrangedhp] gate off this is the literal `500`, byte for byte.
				return unit, X.cm_GetRangedCreepReportedHealth( unit )
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
