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
-- out of the code instead of asserting it).  All four tiers are taken in turbo.
-- This used to read "only t10 and t15 can ever be taken in turbo", argued from
-- the level census behind GH #84: level >= 20 on 0 of 210 hero-slots, high-water
-- 19.  CORRECTED 2026-08-27: that zero was a property of the batch HARNESS, not
-- of turbo -- every game self-terminated at a 10-minute economy cap, so no
-- hero-slot could reach 20.  Owner priority P3 (GH #108) raised the cap to 25
-- minutes, and the first frame taken past it reads ten heroes at level 22-27 in
-- a 24.9-minute naturally-ended game (GH #235).  Real turbo games average ~20
-- minutes, so it was never a property of the shipped product either.  t20 and
-- t25 WERE live rows whose picks had never been argued in this repo -- upstream
-- defaults, pinned but unpriced by tests/test_focus_talent_anchor.lua on
-- 2026-08-27, whose section 6 shows where the queue asks for them.  They are
-- PRICED 2026-08-27 in the block directly above tTalentTreeList: t20 changed,
-- t25 kept and now argued.
-- Two independent checks say the feed's order is the slot order
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
--     Hunger is the FIRST point this file buys (build row {2,3,1,...}), is
--     rank 4 from level 11 (the row's 10th entry -- level 10 goes on a talent, so
--     it is rank 3 at the moment this pick is made; GH #134.  The talent's payout
--     does not scale with the rank, so the verdict is unaffected),
--     runs 12s on a 20/15/10/5s cooldown, and X.ConsiderW fires it from
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
--
-- t20 CHANGED 2026-08-27, [5] -> [6].  t25 PRICED 2026-08-27 and NOT changed.
-- This is baton 2 of the three this desk handed forward at 02:15Z (GH #238
-- section 6): price the ten t20/t25 picks of the focus five, one hero per round.
-- Until now both rows were OpenHyperAI snapshot defaults that nobody here had read.
--
-- t20 -- [5] special_bonus_strength_15 (+15 strength) against [6]
-- special_bonus_unique_axe_4 (axe_counter_helix / damage +40, on a base of
-- 100 120 140 160).  The row now takes [6].
-- On reachability alone [5] wins outright, and this change does not pretend otherwise.
-- That matters, because REACHABILITY is the ruler the t10 and t15 blocks above used,
-- and here it is silent: [5] is a stat block with no payout condition at all.  What
-- decides this pair is what each payout is DENOMINATED in, and whether this Axe can
-- spend that currency:
--   * [5] pays in attack damage (Strength is Axe's primary attribute) and in health.
--     This build is already long on both.  Nothing in this file has a right-click
--     decision layer -- every Consider* here is Q/W/E/R -- and neither role list buys
--     attack speed or a damage item, so +15 attack damage compounds with nothing; at
--     a 1.7 base attack time it is under 9 dps.  The health half lands on the hero
--     whose pos_3 list opens item_tank_outfit -> item_crimson_guard ->
--     item_blade_mail, i.e. on the single axis this build already spends its first
--     ~8.5k on (the blink note below sizes that prefix).
--   * [6] pays in PURE damage, the one currency neither this build nor the enemy's
--     supplies.  Armor does not touch it, and t20 unlocks in the last third of a
--     turbo game -- exactly when the mode's fast timings have handed enemy cores the
--     armor that [5]'s physical half runs into.  At the rank Axe holds here it is
--     160 -> 200, +25% on his principal damage source, and it is the only damage he
--     has that multiplies by the number of enemies present -- the state X.ConsiderQ
--     manufactures on purpose, taunting everything inside Call's radius into Counter
--     Helix's 275.
-- The t20 flip is inert to the decision layer: this file has no talent5 or talent6 handle.
-- That is why a magnitude call is affordable at t20 and is NOT affordable at t25 --
-- the flip can only move combat power, and cannot create a stale read either way.
-- COSTS AND BOUNDS: no in-domain frame exists.  Not one Axe frame anywhere in this
-- repo is at the tier: the 105 fixtures hold ten Axe frames, levels 1-11, and the one
-- late frame the corpus has gained (GH #235, 23:02, ten heroes at 22-27) has no Axe in
-- it.  On those ten frames one has an enemy inside Counter Helix's 275
-- (tools/agent/fixture_proximity_census.py axe 275 315 400).  That reading does NOT
-- support this change -- it is recorded rather than dropped, and it is nine or more
-- levels out of domain on a sample frozen for other heroes' decisions, so it is not
-- evidence against it either.  +15 strength converts to health at the game's
-- global rate (22 per point at time of writing), a world constant NOT verified against
-- KV here; nothing above depends on its exact value.  Pick-rate corroboration was not
-- fetched again -- the numbers are Valve's own KV via tools/agent/talent_slot_census.py,
-- not a guide.
--
-- t25 -- [7] special_bonus_unique_axe_2 (axe_berserkers_call / radius +85) against
-- [8] special_bonus_unique_axe_5 (axe_culling_blade / damage +150).  The row KEEPS
-- [7], and here the decision layer decides it, not a judgement about size:
--   * [7] is delivered to this bot for free.  The engine folds the +85 into the
--     `radius` X.ConsiderQ already reads, and that value becomes nCastRange, which the
--     same function then uses to find its targets.  So Axe both catches more (315 ->
--     400 is +61% area) and KNOWS he catches more, with no code change at all.  One
--     frame in the corpus happens to show the annulus doing exactly that
--     (f_175703_sven_tp47: one enemy inside 315, two inside 400).  n = 1, at level 1,
--     and it is corroboration of the mechanism, not a measurement of how often it pays.
--   * [8] would be bought and then not used.  The Culling kill-check further down is
--     a hardcoded literal, 150 + 100 * lv, so no fold reaches it, and the talent term
--     beside it reads 0 (GH #228: hero-unique talents own no KV block).  Real Culling
--     damage with [8] is 425/525/625 against a threshold still reading 250/350/450.
-- Taking [8] would multiply this file's existing Culling blind band by seven.
-- Today that band is (450, 475] at rank 3 -- 25 wide, the stale-constant defect the
-- `hero-2` lever is registered for.  With [8] it becomes (450, 625], 175 wide, and
-- every point of the extra 150 is a kill Axe can make and declines to try.
-- So t25 is not a free choice until `hero-2` lands: whoever repairs the kill-check by
-- reading abilityR:GetSpecialValueInt('damage') collects the fold, and may re-price
-- this pair on its merits afterwards.  Filed forward, not silently absorbed.
local tTalentTreeList = {
						['t25'] = {0, 10},
						['t20'] = {10, 0},
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
-- separate kill threshold since the mechanic was folded into its pure damage.
--
-- The sentence that used to close this block -- "both talent handles here are t25,
-- so GH #84's census (level >= 20 on 0 of 210 hero-slots) makes them dead weight in
-- turbo either way" -- is RETIRED 2026-08-27.  That zero was the 10-minute batch
-- cap, not turbo (GH #235; see the header).  What replaces it is not one fact but
-- two, and they point opposite ways, which is why the retired sentence was worth
-- more than a comment edit:
--
--   * talent7 is LIVE from level 25.  This file's t25 row is {0,10} = index [7],
--     so the handle above is the one this Axe actually trains, and the
--     `nRadius + talent7:GetSpecialValueInt('value')` line below now really runs.
--     It adds 0, and GH #228 says that is CORRECT -- the engine has already folded
--     the +85 into the base `radius` the site reads, so a handle that answered
--     would double-count.  The ruling has not changed; what changed is that it
--     used to be protected by the branch being unreachable as well, and now the
--     fold argument is the only thing holding it up.
--   * talent8 is STRUCTURALLY UNTRAINED.  A hero takes one talent per tier and
--     this file takes [7], so `talent8:IsTrained()` is false for the whole game
--     and the nKillDamage term it guards is dead code -- not merely a zero read.
--     Whoever takes the registered `hero-2` lever inherits both halves: the base
--     is hardcoded AND the talent term can never fire.  Flipping the t25 row to
--     {10,0} would make it fire; do not do that as a side effect of fixing
--     `hero-2`, because it is a talent-pick change and owes its own rationale.
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


--- Soak candidate `axecallbkb` (turbo-only, INERT until armed) -- the sibling of
--- `axecull` on the OTHER ability in this file that pierces spell immunity.
--- Written 2026-09-05 under OWNER_PRIORITIES P4.4.
---
--- THE FACT, from two independent sources that agree.  axe_berserkers_call is
--- `bkbpierce: "Yes"`, behavior `No Target`, radius 315, cooldown 18/16/14/12,
--- mana 90/100/110/120 (odota/dotaconstants build/abilities.json, read
--- 2026-09-05 -- the same file and the same field the `axecull` block above
--- anchors on).  The repo's own copy of the game KV corroborates every number
--- that overlaps: tests/mock/special_value_shapes.lua carries
--- axe_berserkers_call / radius 315 (+85 from special_bonus_unique_axe_2),
--- AbilityCooldown `18 16 14 12`, AbilityManaCost `90 100 110 120`.  So unlike
--- `axecull`, whose anchor is RECORDED-only, this one is cross-checkable from
--- inside the repo without the network.
---
--- THE DEFECT.  X.ConsiderQ carries TWO spell-immunity vetoes, and Berserker's
--- Call is not stopped by spell immunity in the game:
---   (i) the interrupt branch: `npcEnemy:IsChanneling() and not npcEnemy:IsMagicImmune()`
---       -- Axe declines to break a channel he can in fact break.  The taunt
---       forces the enemy to attack him, and that is what ends the channel.
---   (ii) the initiation branch: `J.CanCastOnNonMagicImmune( botTarget )`
---       -- Axe declines the Call when his CURRENT target is spell-immune.
--- (ii) is the wider error of the two and it is worth stating separately,
--- because it is not only an immunity mistake: Berserker's Call is `No Target`,
--- an AoE taunt centred on Axe.  Gating it on one enemy's properties throws away
--- every OTHER enemy standing in the same 315u ring.  A spell-immune carry with
--- two vulnerable supports beside him is a full three-hero Call that the shipped
--- bot does not cast.
---
--- WHY IT IS A GATE AND NOT A PLAIN FIX.  It ADDS casts, and this stream ships an
--- action-adding change dark until a wave has sized its domain.  Gate OFF both
--- clauses reduce to the shipped predicate, byte for byte, because Lua
--- short-circuits `or`: on (i) the second operand is only reached on an immune
--- enemy, and on (ii) J.CanCastOnMagicImmune is J.CanCastOnNonMagicImmune minus
--- exactly the IsMagicImmune term (jmz_func.lua:961 vs :988), so every other
--- veto -- CanBeSeen, IsInvulnerable, IsSuspiciousIllusion, HasForbiddenModifier
--- -- still has to pass before the widened operand can be true.
---
--- THE COST SIDE, stated so it can be argued with.  Berserker's Call taunts; it
--- does not damage, so neither branch can waste a kill the way a mis-timed
--- Culling can.
--- On (i) the downside is bounded by the branch's own premise: an enemy who is
--- CHANNELING inside 265u is not attacking, and ending the channel is the point.
--- On (ii) it is bounded by J.IsGoingOnSomeone, which is upstream of the clause
--- and unchanged: Axe has ALREADY decided to commit on this target and is walking
--- into it either way.  What the Call adds on top of that decision is the taunt
--- (the target cannot walk away or act for 2.1/2.4/2.7/3.0s) and +12/13/14/15
--- armor on Axe for the same window, on the hero whose passive pays him for being
--- surrounded.  Pulling in OTHER enemies standing in the ring is not a new cost
--- either -- the shipped branch already casts the same AoE taunt whenever the
--- target happens not to be immune.
--- The honest difference from `axecull` is narrower than it looks and is stated
--- so nobody carries the wrong half across: `axecull` is bounded by a health test
--- that makes its cast a KILL, and there is no such guarantee here.  Do not quote
--- `axecull`'s "the downside is bounded by the health test" for this lever.
---
--- WHAT IS DELIBERATELY LEFT ALONE.  Only the immunity term moves.  The 315u
--- radius, the -50 / -90 margins, the creep-shove curfew, the Roshan and
--- Tormentor branches and the neutral-camp branch are untouched.  This is one
--- lever, not a bundle.
---
--- WHAT IS NOT KNOWN, and the two branches are blocked by DIFFERENT things.
--- The domain is UNSIZED.  tests/test_axe_cull_immune_veto.lua section 2 already
--- measured the immunity supply for this file (3 spell-immune hero-instants in the
--- corpus, all Juggernaut Blade Fury, none in a game containing Axe; zero Black
--- King Bars in any item slot), and that half is shared.  What is NEW here, and
--- measured 2026-09-05 over the 7 Axe-SUBJECT frames rather than assumed:
---   * the ONE frame with an enemy inside the 265u ring (ring_close, skywrath at
---     188u) has Berserker's Call at 17.0s of its own 18s rank-1 cooldown -- Axe
---     had just cast it -- and the 5 frames where Call IS ready hold zero enemies
---     inside the ring.  "Call ready" and "enemy in the ring" never co-occur.
---   * zero channeling hero-instants anywhere in those frames.
--- So branch (i) is validated on a real frame by a counterfactual with THREE
--- declared flips (cooldown, channeling, immunity), each isolated by a 2x2 in
--- tests/test_axe_call_immune_veto.lua rather than pooled.
--- Branch (ii) has SOURCE-LEVEL COVERAGE ONLY -- the `zusaether` disposition --
--- and its blockers are three, not one: `botTarget` is J.GetProperTarget and is
--- structurally nil on every fixture frame (GH #474), J.IsGoingOnSomeone is false
--- on this frame, and J.IsDisabled answers TRUE for the only in-ring enemy.  Any
--- test that drove it would be driving stubs, which is gate plumbing, not local
--- validation.  It is labelled as such in the test rather than left to be inferred.
--- ⚠️ CONSEQUENCE FOR THE VERDICT, registered before the wave and not after: the
--- two branches share one id, so a negative read cannot be attributed to either.
--- If a wave reads negative, the next rung is to SPLIT the id, not to reject the
--- fact.  Size it on a wave: iterations/queue.json `hero-30`.  Do NOT promote on
--- the (c) argument alone.
---
--- ============================================================================
--- THE SPLIT, 2026-09-06 (GH #577, hero-30 delivered).  The paragraph above is
--- the pre-registration; this is it being paid.  The id `axecallbkb` is RETIRED
--- and each branch now carries its own, because hero-30's census sized the two
--- branches and they are 38x apart:
---
---   branch (i)  X.IsCallPierceInterruptOn  -> `axecallbkb_i`
---               35 in-domain instants, 3 games, 4 of them spell-immune.
---   branch (ii) X.IsCallPierceInitiateOn   -> `axecallbkb_ii`
---               1,519 in-domain instants, 65 episodes, 36 games; 153 of them
---               spell-immune.  43.1% of the 218 immune instants have 1-2
---               NON-immune enemies inside the same 315u ring, which is the
---               value column that is (ii)'s alone.
---
--- The premise itself came back CONFIRMED, not falsified, and by corpus rather
--- than by web page: in 69 archived games Berserker's Call landed on an enemy
--- hero 1,141 times, 27 of those on a hero who was spell-immune at that instant
--- (20 Black King Bar, 7 Blade Fury), spread over 19 games -- i.e. the shipped
--- vetoes really do fire on real frames.  Immune share (i) 11.4% / (ii) 14.1%,
--- so the pre-registered `DOMAIN-NOT-REACHED` does NOT trigger for either.
--- Readings: iterations/reports/replay-check/domain_scan_hero_2_30_31.md §8.
---
--- ⚠️ WHY TWO IDS AND NOT AN UMBRELLA.  An umbrella that ORs the two back
--- together would reproduce exactly the composite hero-30 warned about: a wave
--- arming it reads a number (ii) dominates 38:1 and (i) cannot be seen inside.
--- So there is deliberately NO `axecallbkb` gate left anywhere in bots/.  A wave
--- that arms the retired string now arms NOTHING -- it was never in any armed
--- set (W49_wave.json records it landing gated and staying out), which is the
--- only reason retiring it outright is safe.  tests/test_axe_call_immune_veto.lua
--- asserts the retired string is absent from bots/ so this cannot rot back.
---
--- ⚠️ THE TWO IDS ARE INDEPENDENT AND MUST STAY THAT WAY.  Neither helper may
--- name the other's id (the `pullcad` trap: a gate naming a sibling freezes FALSE
--- the day the sibling is promoted, and check_armed_wiring.py still calls it
--- WIRED).  The test asserts each helper names exactly one id, and the real-frame
--- 2x2 asserts that arming (ii) ALONE does not fire branch (i).
--- ============================================================================
function X.IsCallPierceInterruptOn()

	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecallbkb_i' )

end


function X.IsCallPierceInitiateOn()

	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecallbkb_ii' )

end


function X.ConsiderQ()


	if not abilityQ:IsFullyCastable() then return 0 end

	local nSkillLV = abilityQ:GetLevel()
	
	local nRadius = abilityQ:GetSpecialValueInt( 'radius' )
	-- FACT, 2026-08-26 (GH #228, axis TALENTVALUE).  The second term is 0 and always
	-- has been: special_bonus_unique_axe_2 is a hero-UNIQUE talent, and unique talents
	-- own no KV block anywhere, so the handle answers no key -- `value` included.  The
	-- +85 lives inside the ability this line already read:
	--     axe_berserkers_call / "radius" { "value" "315"
	--                                      "special_bonus_unique_axe_2" "+85" }
	-- i.e. the engine folds it into `abilityQ:GetSpecialValueInt('radius')` above for a
	-- caster who trained it.  So nRadius is ALREADY correct, and repointing this term at
	-- a handle that answered would double-count.  Do not "fix" it; 21 sites tree-wide
	-- share the shape (tools/agent/talent_value_read_census.py,
	-- tests/test_talent_value_read_anchor.lua).
	if talent7:IsTrained() then nRadius = nRadius + talent7:GetSpecialValueInt( 'value' ) end
	
	local nCastRange = nRadius
	
	local nCastPoint = abilityQ:GetCastPoint()
	local nManaCost = abilityQ:GetManaCost()
	local nDamageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyList = J.GetAroundEnemyHeroList( nRadius - 50 )
--	local nInBonusEnemyList = J.GetAroundEnemyHeroList( nRadius + 200 )
	local hCastTarget = nil
	local sCastMotive = nil
	
	--打断敌人施法
	for _, npcEnemy in pairs( nInRangeEnemyList )
	do 
		if npcEnemy:IsChanneling()
			and ( not npcEnemy:IsMagicImmune() or X.IsCallPierceInterruptOn() ) -- see X.IsCallPierceInterruptOn
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
			and ( J.CanCastOnNonMagicImmune( botTarget )
					or ( X.IsCallPierceInitiateOn() and J.CanCastOnMagicImmune( botTarget ) ) ) -- see X.IsCallPierceInitiateOn
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


--- SOAK CANDIDATE 'axebhpure' (turbo-only, GH #154).  Not armed; gate OFF is the
--- shipped predicate, byte-for-byte, because the widening below is only ever
--- reached after J.WillMagicKillTarget has already answered false.
---
--- THE FACT.  Battle Hunger deals PURE damage -- `AbilityUnitDamageType`
--- `DAMAGE_TYPE_PURE` on axe_battle_hunger, and the tooltip property is
--- `DPS_Pure` (game KV via the d2vpkr mirror, the same source
--- tools/agent/gen_ability_meta.py reads; fetched 2026-08-24).  X.ConsiderW
--- nevertheless hands its damage claim to J.WillMagicKillTarget, which hardcodes
--- `nDamageType = DAMAGE_TYPE_MAGICAL` and finishes on
--- `npcTarget:GetActualIncomingDamage( EstDamage, nDamageType )`.  Pure damage is
--- not reduced by magic resistance, so the shipped kill branch under-states its
--- own spell by at least the 25% every hero carries at base, and by more against
--- any magic-resistance item.  At rank 4 with this file's t15 talent that is
--- 384 pure declared as 288.
---
--- IT IS NOT A HOUSE STYLE -- THIS FILE GETS IT RIGHT ELSEWHERE.  X.ConsiderR
--- declares `nDamageType = DAMAGE_TYPE_PURE` and compares Culling Blade against
--- RAW health (`GetHealth() + GetHealthRegen() * 0.8 < nKillDamage`), with no
--- mitigation term at all.  Same file, same damage type, opposite arithmetic.
--- Across the five focus heroes axe_battle_hunger is the ONLY ability whose KV
--- damage type is not MAGICAL and whose damage still reaches a magical-only kill
--- predicate (census in tests/test_axe_battle_hunger_pure.lua; the other kill
--- calls -- CM Frostbite, Lion Impale/Finger, Zeus Bolt, WK Hellfire Blast --
--- are all MAGICAL, and WK's passes its type explicitly).
---
--- WHY IT IS A GATE.  It ADDS a cast, and this stream ships an action-adding
--- change dark until a wave has sized its domain.
---
--- WHAT IS DELIBERATELY LEFT ALONE.  Exactly one term changes: the mitigation.
--- The spell-amp factor stays (the shipped helper applies it and this round is
--- one lever, not two), the 12-second regeneration term stays, and the widening
--- REFUSES every target J.WillMagicKillTarget holds a special opinion about
--- (Medusa's mana shield, Kunkka's ghost-ship delay, Templar Assassin's
--- refraction, and Bristleback's rear arc), so it cannot regress any of them --
--- three of those four absorb pure damage too.
---
--- WHAT IS NOT KNOWN, AND CANNOT BE KNOWN HERE.  The domain is UNSIZED and the
--- fixture corpus structurally cannot size it: `GetActualIncomingDamage` is not
--- modelled, so it answers the mock's generic `Get*` default 0 on all 1040 hero
--- handles in 104 fixtures, which makes J.WillMagicKillTarget false on all 966
--- living units and true on all 74 corpses.  Every kill branch in every focus
--- hero is therefore silent offline; a green fixture over this branch is a false
--- green, not evidence.  See the hero-13 request in iterations/queue.json.
function X.IsBattleHungerPureOn()

	return J.IsModeTurbo() and J.IsSoakCandidate( 'axebhpure' )

end


--- The modifiers (and the one unit name) J.WillMagicKillTarget scales its
--- estimate by.  The pure widening declines to have an opinion on any of them
--- rather than re-implementing four special cases it would then have to keep in
--- step; three of the four cut pure damage as well, so refusing is the safe side.
local tBattleHungerPureAbstain = {
	'modifier_medusa_mana_shield',
	'modifier_kunkka_ghost_ship_damage_delay',
	'modifier_templar_assassin_refraction_absorb',
}


--- Shipped predicate first, unchanged; the gated widening only ever answers on
--- the frames it already refused, so gate OFF is byte-for-byte the old behaviour.
function X.WillBattleHungerKill( npcEnemy, nDamage, nDelay )

	if J.WillMagicKillTarget( bot, npcEnemy, nDamage, nDelay ) then return true end

	if not X.IsBattleHungerPureOn() then return false end

	for _, sModifier in pairs( tBattleHungerPureAbstain )
	do
		if npcEnemy:HasModifier( sModifier ) then return false end
	end

	if npcEnemy:GetUnitName() == 'npc_dota_hero_bristleback' then return false end

	-- J.WillMagicKillTarget with its two magical-only terms neutralised: no
	-- resistance on the damage, and the regeneration it subtracts is no longer
	-- divided by a resistance factor.  Pure damage takes neither.
	local nEstDamage = nDamage * ( 1 + bot:GetSpellAmp() ) - npcEnemy:GetHealthRegen() * nDelay

	return nEstDamage >= npcEnemy:GetHealth()

end


--- Soak candidate `axebhrecast` (turbo-only, INERT until armed).  Written
--- 2026-09-06 under OWNER_PRIORITIES P4.4.
---
--- THE DEFECT, and it has TWO independent halves, either one sufficient.
--- X.ConsiderW carries the same veto at EIGHT sites, always in this shape:
---
---     and not <target>:HasModifier( 'modifier_axe_battle_hunger_self' )
---
--- i.e. "do not spend Battle Hunger on someone who already has it".  The name it
--- tests is not a name the target can ever carry:
---   (i) IT IS THE CASTER'S SIDE.  The debuff the target carries is
---       `modifier_axe_battle_hunger` -- that is the name bots/mode_team_roam_generic.lua
---       :1605 and bots/BotLib/hero_largo.lua:316 both read off an ENEMY/ALLY, and it is
---       the name that appears on enemy heroes in this repo's own replay fixtures.
---       The `_self` family is what Axe puts on HIMSELF for the movespeed.
---   (ii) IT IS ALSO STALE.  Across all 104 fixtures the caster-side modifier is
---       spelled `modifier_axe_battle_hunger_self_movespeed`, 18 sightings; the bare
---       `modifier_axe_battle_hunger_self` this file tests appears ZERO times, on
---       any unit, in any frame.  HasModifier is an exact-name lookup, not a prefix
---       match, in the engine and in tests/mock/replay_fixture.lua alike.
--- So the veto is structurally always-true and always has been: Axe has never once
--- declined a Battle Hunger on the ground that the target already had one.
---
--- THE FIX, and why it is not simply "correct the string".  Battle Hunger does not
--- stack (`should_stack` has no base in the ability KV; it is a SHARD grant), so a
--- re-cast REFRESHES the 12s debuff rather than adding to it -- worth `12 - remaining`
--- seconds -- while the same cast on a fresh enemy is worth a full 12s of pure DoT
--- plus a second slow.  Re-applying is therefore dominated wherever another
--- candidate exists AND the cast is not a kill-confirm.  X.axe_IsBattleHungerFresh
--- is wired at exactly THREE sites: the teamfight min-search, the laning-harass loop
--- and the retreat loop.  Each iterates a list, so a vetoed candidate is skipped and
--- the next one is considered, and none of the three claims the cast will kill.
--- FIVE SITES ARE DELIBERATELY LEFT ALONE, in two groups:
---   * the IsGoingOnSomeone branch, the jungle pick, Roshan and Tormentor have no
---     second candidate to fall through to, so a veto there is a pure loss of the
---     refresh with nothing bought;
---   * the KILL LOOP, and this one was not foreseen -- the fixture found it.  Its
---     own damage claim (X.WillBattleHungerKill) is priced on a FULL 12s duration,
---     which is what a re-cast restores, so vetoing an already-hungered target there
---     throws the kill away.  f_260820_043124_axe_blink_kill is the frame: a Wraith
---     King at 199 HP carrying 6.5s of the debuff, i.e. 130 of the 199 already
---     coming; only the refresh's full 240 finishes him.  An earlier draft of this
---     lever DID wire that site, and section 4 of the test now pins it unwired.
--- This is one lever, not a bundle: the dead `_self` term is not deleted anywhere.
--- At the five untouched sites it stands exactly as written; at the three wired ones
--- it survives verbatim as the helper's bound `bShipped`, which is what makes
--- gate-OFF byte-for-byte the shipped behaviour rather than a second change riding
--- along.
---
--- ⚠️ WHAT THE DIRECTION IS, STATED PRECISELY, BECAUSE IT IS NOT "FEWER ACTIONS".
--- The shipped predicate is evaluated first and bound; the armed path may only turn
--- its `true` into a `false`, and the last statement returns the shipped value.  So
--- the set of (branch, target) pairs the armed side accepts is a strict SUBSET of
--- the shipped side's, and therefore `armed casts Battle Hunger => shipped casts
--- Battle Hunger` on the same frame.  What it does NOT claim is that the ACTION is
--- the same: the whole point is that a vetoed candidate hands the branch to another
--- target, so the armed side can issue a DIFFERENT order on a frame where shipped
--- also issued one.  A negative wave reading can only mean "those refreshes were
--- worth more than the spread"; it can never mean the lever invented a cast.
--- X.ConsiderW is the LAST arm of X.SkillsComplement, so nothing upstream of it
--- (Culling Blade, Berserker's Call) can change sign because of this.
---
--- THE SHARD IS THE PREMISE, AND IT IS PINNED SEPARATELY.  With Aghanim's Shard the
--- ability KV turns `should_stack` on, and then a re-cast is a genuine second stack
--- -- the dominance argument above reverses.  Both of this file's buy lists carry
--- item_aghanims_shard, so this is not hypothetical; the armed leg stands down
--- whenever J.HasAghanimsShard is true.  That term is the premise of the (c)
--- argument expressed as code, the way `cmcreepcap`'s t25 row is.
---
--- WHAT IS NOT KNOWN.  The domain is UNSIZED.  Corpus supply, measured rather than
--- assumed (tests/test_axe_battle_hunger_recast.lua section 2): three Axe-SUBJECT
--- frames carry an enemy holding the real debuff, with 0.2s / 5.4s / 6.5s left, and
--- on two of them that enemy is the ONLY one inside Battle Hunger's cast range --
--- so on those two the armed side declines rather than spreads, which is the cost
--- side of this lever showing up in the corpus.  The one frame that can show the
--- SPREAD is f_260820_043637_axe_ring_close, and driving it needs two labelled
--- flips because no fixture frame reports a bot mode.  Size it on a wave:
--- iterations/queue.json `hero-35`.  Do NOT promote on the (c) argument alone.
function X.axe_IsBattleHungerFresh( hTarget )

	local bShipped = not hTarget:HasModifier( 'modifier_axe_battle_hunger_self' )

	if bShipped
		and J.IsModeTurbo() and J.IsSoakCandidate( 'axebhrecast' )
		and not J.HasAghanimsShard( bot )
		and hTarget:HasModifier( 'modifier_axe_battle_hunger' )
	then
		return false
	end

	return bShipped

end


function X.ConsiderW()


	if not abilityW:IsFullyCastable() then return 0 end

	local nSkillLV = abilityW:GetLevel()
	local nCastRange = abilityW:GetCastRange() + aetherRange
	-- No radius term here on purpose: Battle Hunger is single-target and its KV
	-- carries no radius key at all (tests/mock/special_value_shapes.lua).  A
	-- `local nRadius = 600` stood here, unread, until 2026-09-03; see
	-- tests/test_dead_numeric_local_census.lua.
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
			and X.WillBattleHungerKill( npcEnemy, nDamage, nDuration )
			-- NOT X.axe_IsBattleHungerFresh: see that helper's header.  The kill
			-- loop is the one list branch where the re-cast is the point -- its
			-- own damage claim is a FULL fresh duration, and on
			-- f_260820_043124_axe_blink_kill the refresh is exactly what carries
			-- a 199 HP Wraith King past a debuff with 6.5s left.
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
				and X.axe_IsBattleHungerFresh( npcEnemy )
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
				and X.axe_IsBattleHungerFresh( npcEnemy )
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
				and X.axe_IsBattleHungerFresh( npcEnemy )
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


--- Soak candidate `axecull` (turbo-only, INERT until armed) -- GH #146: let the
--- Culling Blade execute branch fire on a spell-immune target.
---
--- THE FACT.  Culling Blade pierces spell immunity -- `bkbpierce: "Yes"` on
--- axe_culling_blade, damage type Pure (odota/dotaconstants build/abilities.json,
--- package 10.8.0, read 2026-08-23; the same source the 09:50Z round used for the
--- duplicate-component laws).  Its whole point is that it kills a BKB'd hero.  The
--- shipped branch below nevertheless carried `not npcEnemy:IsMagicImmune()`, and
--- whoever wrote it flagged it on the spot: `--V BUG` is the ONLY occurrence of
--- that marker anywhere under bots/ (grep, 2026-08-23), i.e. an upstream author
--- knew and left it.
---
--- WHY IT IS A GATE AND NOT A PLAIN FIX.  It ADDS a cast, and this stream ships an
--- action-adding change dark until a wave has sized its domain.  Gate OFF the
--- clause reduces to `not npcEnemy:IsMagicImmune()` -- the shipped predicate,
--- unchanged, because Lua short-circuits `or` and the second operand is only
--- reached on an immune target.
---
--- THE COST SIDE, stated so it can be argued with.  Every other guard on the
--- branch stays: aegis, invulnerability, Linken's/Lotus/Aeon (X.HasSpecialModifier)
--- and the health test.  So the frames this opens are exactly "a visible enemy
--- hero inside 375u whose effective health is already below the execute
--- threshold, who happens to be spell-immune".  On those the cast is a kill, and
--- a kill resets Culling's own cooldown -- which is why this is one of the rare
--- levers whose downside is bounded by the health test that precedes it.
---
--- WHAT IS NOT KNOWN.  The domain is UNSIZED: the fixture corpus holds three
--- spell-immune hero-instants in 104 frames (all Juggernaut Blade Fury, none in a
--- game containing Axe) and ZERO Black King Bars in any item slot, so it cannot
--- answer this.  That is a SUPPLY reading, not an empty domain.  See
--- tests/test_axe_cull_immune_veto.lua and the hero-9 request in
--- iterations/queue.json -- do NOT promote this on the (c) argument alone.
function X.IsCullPierceOn()

	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecull' )

end


--- Soak candidate `cullthresh` (turbo-only, INERT until armed) -- the registered
--- `hero-2` lever, written 2026-09-05.  GH #115 section 5 / GH #146.
---
--- THE FACT, and it is now read off a REAL FRAME rather than a datafeed.  The
--- shipped estimate of Axe's own finisher is `150 + 100 * lv` = 250/350/450.  The
--- game's own KV says axe_culling_blade / AbilityValues / damage = `275 375 475`
--- (tests/mock/special_value_shapes.lua, generated from npc_dota_hero_axe.txt), and
--- on tests/fixtures/f_260820_043637_axe_ring_close.lua -- a real Axe instant with
--- Culling at rank 1 -- `abilityR:GetSpecialValueInt('damage')` answers 275 against
--- the formula's 250.  The bot therefore under-states its execute threshold by 25
--- at every rank and declines a guaranteed kill whenever a target sits in the
--- 25-point band (150 + 100*lv, damage[lv]].
---
--- WHY IT IS A GATE.  It strictly WIDENS the only test the branch has, i.e. it ADDS
--- casts, and this stream ships an action-adding change dark until a wave has sized
--- its domain.  Gate OFF this returns the shipped arithmetic INCLUDING the dead
--- talent term, so the unarmed tree is byte-equivalent to what shipped.
---
--- THE TALENT TERM IS INSIDE THE ARMED READ, NOT BESIDE IT.  `special_bonus_unique_axe_5`
--- (+150) lives inside axe_culling_blade / damage, where the engine folds it; the
--- shipped `talent8` line added it a second time from a hero-UNIQUE talent handle
--- that owns no KV block and therefore answers 0.  Adding it to the armed value
--- would double-count the day that handle ever answers.  So the armed branch
--- returns before the talent line -- this is the "drop this line in the same
--- change" the old comment here asked for.
---
--- THE DIRECTION IS STRUCTURAL, NOT HOPED FOR.  A getter that silently answers 0
--- is how `zusboltcap` (GH #175) turned an AoE health filter into "is anyone
--- there"; here a degenerate read would collapse the threshold and stop Axe culling
--- ENTIRELY -- a silent regression in the OPPOSITE direction to the one being
--- fixed, which no in-domain counter would ever report.  So the armed value is
--- taken only when it is STRICTLY GREATER than the shipped one, which makes "this
--- lever can only add casts" a property of the code rather than of the data.  A
--- first draft guarded with `nLive > 0` instead and its own direction test caught
--- that a small positive read (1) narrows the test; do not weaken it back.
--- The cost of the strictness, stated so it can be argued with: if a patch ever
--- LOWERS the KV threshold below 150 + 100*lv, this helper keeps the stale, higher
--- constant and Axe would cull targets it cannot kill.  That is why the 25-point
--- gap is a ratchet in two places (tests/test_axe_cull_threshold_gate.lua section 1
--- and tests/test_axe_culling_threshold_preflight.lua section 1): both go RED and
--- name the new ladder before this branch could act on it.
---
--- WHAT IS NOT KNOWN, and it is a band not an existence question.  The domain is a
--- 25-point strip on a continuous quantity.  Measured over this repo's whole frame
--- corpus (tests/fixtures/ + tests/frames/, 2026-09-05): 29 Axe instants, 24 with
--- Culling learned and off cooldown, 3 in-ring enemy rows, band occupied ZERO times
--- -- the same funnel tests/test_axe_culling_threshold_preflight.lua measured in
--- August, and its verdict NARROW-BAND-UNMEASURABLE stands FOR A FIXTURE LIBRARY.
--- What changed is the other half: tests/test_axe_culling_band_power.lua (2026-08-30)
--- showed 1 Hz timelines CAN size this by counting CROSSINGS, and the blocker that
--- left -- "the archive holds no game with Axe in it" (batch desk 2026-08-23,
--- 0/306) -- is falsified by tests/fixtures/tl_260905_010226_axe_outchan.json, a
--- verbatim slice of an archived dumper timeline from seed 4763 that carries an Axe.
--- Size it on crossings; do NOT promote this on the (c) argument alone.
function X.IsCullThresholdOn()

	return J.IsModeTurbo() and J.IsSoakCandidate( 'cullthresh' )

end


function X.CullKillThreshold( nSkillLV )

	local nKillDamage = 150 + 100 * nSkillLV
	if talent8 ~= nil and talent8:IsTrained() then nKillDamage = nKillDamage + talent8:GetSpecialValueInt( 'value' ) end

	if X.IsCullThresholdOn()
	then
		local nLive = abilityR:GetSpecialValueInt( 'damage' )
		if type( nLive ) == 'number' and nLive > nKillDamage
		then
			return nLive
		end
	end

	return nKillDamage

end


function X.ConsiderR()


	if not abilityR:IsFullyCastable() then return 0 end

	local nSkillLV = abilityR:GetLevel()
	local nCastRange = abilityR:GetCastRange()
	-- No radius term here on purpose: Culling Blade is single-target at
	-- AbilityCastRange 175, and its only *_aoe key is `speed_aoe` 900 -- the
	-- radius of the ALLY movespeed buff on a kill, not a targeting radius.  A
	-- `local nRadius = 600` stood here, unread, until 2026-09-03, eight lines
	-- above the most heavily annotated lever in this file and through every one
	-- of the four rounds that wrote those annotations; see
	-- tests/test_dead_numeric_local_census.lua.
	local nCastPoint = abilityR:GetCastPoint()
	local nManaCost = abilityR:GetManaCost()
	
	-- The registered `hero-2` lever, TAKEN 2026-09-05 and GATED -- the stale
	-- 150 + 100*lv (250/350/450) against the ability's real 275/375/475, and with it
	-- the double-count risk the old note here flagged in the `talent8` line.  Both
	-- now live inside X.CullKillThreshold, which reduces to the shipped arithmetic
	-- byte for byte while `cullthresh` is unarmed; read that helper's header for the
	-- fact, the degenerate-read guard, and what the domain still owes.
	local nKillDamage = X.CullKillThreshold( nSkillLV )

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
			and ( not npcEnemy:IsMagicImmune() or X.IsCullPierceOn() ) --V BUG (see X.IsCullPierceOn)
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
