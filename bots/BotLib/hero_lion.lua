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

-- TALENT LADDER, re-anchored 2026-08-22 against
-- https://www.dota2.com/datafeed/herodata?language=english&hero_id=26 (the same
-- method as GH #104/#115/#122).  {0,10} takes the ODD index of a tier's pair,
-- {10,0} the EVEN one; that wiring is arithmetic inside J.Skill.GetTalentBuild and
-- is read out of the code in tests/test_focus_talent_anchor.lua, never assumed.
--   t10 [1] +10% Mana Drain slow          [2] +20 movement speed   <- {10,0} takes [2]
--       [1] = special_bonus_unique_lion_6, [2] = special_bonus_movement_speed_20
--   t15 [3] -2s Hex cooldown              [4] +15% To Hell and Back amp
--       [3] = special_bonus_unique_lion_5, [4] = special_bonus_unique_lion_11
--   t20 [5] +20 Finger dmg per kill       [6] Earth Spike 30-degree cone
--       [5] = special_bonus_unique_lion_8, [6] = special_bonus_unique_lion_10
--   t25 [7] +250 AoE Hex                  [8] +600 Earth Spike cast range
--       [7] = special_bonus_unique_lion_4, [8] = special_bonus_unique_lion_2
-- t20/t25 are LIVE rows, and for this hero that is not a bookkeeping note.  This
-- line used to read "t20/t25 are dead rows in turbo (GH #84: level >= 20 on 0 of
-- 210 hero-slots)"; CORRECTED 2026-08-27, because that zero belonged to the batch
-- harness and not to turbo -- games self-terminated at a 10-minute economy cap.
-- Owner priority P3 (GH #108) removed the cap and the first frame past it reads
-- ten heroes at level 22-27 in a 24.9-minute naturally-ended game (GH #235).
--
-- t25 CHANGED 2026-08-27: {10, 0} -> {0, 10}, i.e. index [8] -> [7].  This is the
-- first time either of this hero's two late rows has been ARGUED rather than
-- inherited from the OpenHyperAI snapshot, and it is a real behaviour change in
-- every turbo game that reaches level 25 -- talent rows are not gated.  Three
-- reasons, in ascending order of how much they belong to THIS project:
--   1. Standard strategy, and the weakest of the three because anyone can look it
--      up: +250 Hex radius is Lion's marquee t25.  It turns a single-target 4s
--      disable into a team-wide one centred on the target; +600 Earth Spike cast
--      range adds no disable and no damage, only delivery distance.
--   2. It is worth MORE to a bot than to a human, and [8] is worth LESS.  Hex is
--      DOTA_ABILITY_BEHAVIOR_UNIT_TARGET: the +250 radius is applied by the engine
--      on cast, so a bot collects the whole talent with zero aiming, zero
--      prediction and zero new code.  Earth Spike is a LINE skillshot with travel
--      time, the one ability on this hero that must be led; raising its cast range
--      500 -> 1100 more than doubles the lead distance, and an unled line's hit
--      rate falls with distance.  [8] hands extra range to the ability the bot is
--      worst at, [7] hands a free radius to the one it just clicks.
--   3. It removes GH #166's live defect STRUCTURALLY instead of gating around it.
--      Fifteen reads in this file ask `talent8` whether "Hex is an area spell now"
--      while slot 8 is the Earth-Spike-range half and does not touch lion_voodoo
--      at all.  With [7] trained, talent8 is structurally untrained in the shipped
--      build, X.IsHexAoe answers false everywhere, and false is the CORRECT answer
--      for a unit-target ability under either talent: the entity dispatch is kept
--      and the cast-legality check is no longer skipped.  Nothing is lost, because
--      the engine applies the radius whether or not this file knows about it.
-- WHAT IS GIVEN UP, stated so it is not discovered later as a surprise: the
-- `J.GetAoeEnemyHeroLocation` branch in X.ConsiderW (the "W-团控" one) is skipped
-- when IsHexAoe is false, so the bot no longer PREFERS a clustered target once it
-- really does have AoE Hex.  That is a missed optimisation, not a defect -- the
-- most-dangerous-enemy branch directly below it serves the same fight -- and it is
-- a WIDENING, which GH #166 §9 deliberately left to a later hand.  Filed there.
-- t20 PRICED 2026-08-27 and NOT CHANGED -- the row already takes [6].
-- [6] is the 30-degree cone, which is the side this desk would have argued for
-- anyway, so the pricing confirmed the inheritance rather than rubber-stamping it.
-- [5] (+20 Finger
-- damage per kill) pays only after Finger KILLS, and it arrives at level 20 -- late
-- in a ~20-minute turbo game, with few casts left to bank stacks on.  [6] is
-- unconditional and it buys the same thing reason 2 above buys: forgiveness for
-- lateral aiming error on the one skillshot this bot must lead.  Nothing in this
-- file reads talent6, and nothing needs to -- the cone is applied by the engine.
--
-- t10 CHANGED 2026-08-22: [1] -> [2].  Not because +20 move speed is the bigger
-- payout -- it is the smaller one -- but because of where each one can be COLLECTED:
--   * [1] adds +10 percentage points to Mana Drain's slow (15/20/25/30 -> 25/30/
--     35/40), and it is only collectible while this bot is channelling Mana Drain
--     ON AN ENEMY HERO.  X.ConsiderE has four returns and only two of them hand
--     back an enemy hero: the mana top-up branch takes a CREEP and requires
--     #hEnemyList == 0 (no hero in range to slow), and the illusion branch takes an
--     illusion.  Both of the enemy-hero branches sit
--     BELOW `if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0 end`,
--     so they are a RESIDUAL action: they need Earth Spike, Hex and Finger of Death
--     to be simultaneously unavailable, and then also an enemy hero within 850u with
--     more than 200 mana, undisabled, and not killable.
--   * [2] is collected on every frame the hero moves, with no predicate at all.
--   * Measured on real frames (tests/test_lion_t10_payoff.lua, section 1): of the
--     living-Lion frames in this repo's fixture library, the Q/W/R gate above those
--     branches is open on a minority, and the full precondition chain is satisfied
--     on a couple -- both of which are fixtures cut specifically to study Lion's
--     drain.  [2] pays on every one of those frames.
-- HONEST BOUNDS: the fixture library is curated for OTHER investigations, so those
-- counts are existence reads, not densities (the stream's standing §Y.2 limit) --
-- how many enemy-hero drain channels a real game contains is an open corpus
-- question, filed as queue.json hero-4.  The shipped build puts Mana Drain at RANK
-- 3 when the t10 choice is made -- level 10 goes to a TALENT, so only nine ability
-- points are down and the row's 10th entry lands at level 11 (corrected
-- 2026-08-23; the first write-up said rank 4 by counting row indices as levels).
-- So the abandoned side is giving up 25 -> 35, not its largest payout of 30 -> 40,
-- which makes this change better supported than it was written up as; either way
-- we are giving it up on frequency grounds,
-- the same trade as the Zeus t15 row.  +20 is measured against a 290 base (datafeed)
-- and this hero's pos_4/pos_5 outfit macro carries Arcane Boots, so the RELATIVE
-- gain in practice is about +6%, not +7%.  The ally half of [1] (Mana Drain can feed
-- an ally at 50% rate) is unreachable either way: X.ConsiderE has no ally branch.
--
-- t15 RE-EXAMINED 2026-08-23 and still NOT changed -- but on measurements this
-- time, not on "neither side can be measured".  The pair is [3] -2.0s Hex cooldown
-- (special_bonus_unique_lion_5) against [4] +15% To Hell and Back Debuff/Spell Amp
-- (special_bonus_unique_lion_11), and the row keeps [4].  Both of the 2026-08-22
-- note's legs turned out to be wrong, in OPPOSITE directions:
--   * [4]'s two windows -- after a respawn until the next kill/assist, and after a
--     kill/assist while that hero is dead -- are NOT invisible.  Fixtures cut after
--     2026-08-19 carry modifiers, and both windows are in the corpus today:
--     modifier_lion_to_hell_and_back_buff on 2 frames, ..._respawn_buff on 1, out
--     of the 10 Lion frames that carry modifier state at all.  GH #27 survives for
--     ITEM CHARGES only.
--   * [3] is worth MORE than that note priced it.  24s is Hex at rank 1, which is
--     what the corpus holds (its Lions top out at level 11) -- not what the domain
--     holds.  The talent exists only from level 15, and by level 15 this build has
--     put three points in Hex: rank 3, a 16 second cooldown.  So -2.0s buys +14.3%
--     Hex casts at the moment of choice (16/14), and +20% from level 16 when Hex
--     reaches rank 4 -- against the +9.1% a 24s cooldown would have given.
--     (The old note also had rank 2 arriving at level 12; it arrives at 13.
--     Cause: the build row's index is not the hero level -- J.Skill.GetSkillList
--     spends levels 10 and 15 on talents and pushes every later ability entry back.
--     Read out of that function in tests/skill_level_map.lua, never restated.)
-- KEPT [4] ANYWAY, and the reason is a measurement of what is scarce: a cooldown
-- reduction only pays when the cooldown is what stopped a cast, and on the corpus
-- frames that have Hex learned it is READY and affordable on 9 of 20.  Lion stands
-- around with his disable up nearly half the time -- targets are scarce, Hex charges
-- are not.  The <= 2s band the talent converts is hit on 0 of those frames against
-- an expectation of ~0.9, i.e. UNDERPOWERED, not EMPTY (GH #115).  The incumbent has
-- the opposite shape: it multiplies the casts that DO happen, and its spell-amp half
-- also raises Earth Spike and Finger of Death damage -- so the old "both sides buy
-- the same thing (Hex disable)" was wrong too; [4] is the broader of the two.
-- REJECTED SIDE'S BEST CASE: the respawn window is switched off by SUCCESS (it ends
-- on the next kill or assist) and the kill window needs one already banked, so
-- neither is available in an even fight -- which is where a shorter Hex cooldown
-- would pay.  It loses to a resource that is idle half the time.
-- HONEST BOUNDS: no frame in this corpus is in domain (Lion tops out at level 11 --
-- every number above is a proxy read four levels below the tier); n = 3 windows is
-- an existence read on fixtures curated for other investigations, not a density;
-- "inside a window" is not "collected a payout"; and the ready-Hex count says the
-- cooldown was not binding AT THOSE INSTANTS, not that no cast was ever delayed by
-- it -- that event-side count is still queue.json hero-4.  Talent magnitudes come
-- from odota dotaconstants; the datafeed carries the names but leaves special_values
-- empty for both.  Pinned in tests/test_lion_t15_payoff.lua.
--
-- ABILITY-NAME FOOTNOTE (2026-08-23).  Lion's innate is the ONE ability on this
-- hero where the datafeed and the engine disagree on the name: the feed calls it
-- lion_to_hell_and_back, the engine calls it lion_innate_to_hell_and_back on
-- 22 of 22 Lion frames in tests/fixtures/ (the feed's spelling: 0).  Nothing in
-- this file matches on it -- the bindings below take sAbilityList indices
-- 1,2,3,6 and the build row names the same four -- so an innate landing at
-- index 4 (which it does whenever ability:IsHidden() is false; GetAbilityList
-- has no innate flag to consult) cannot reach anything here.  Zeus and Crystal
-- Maiden bind index 4/5 and are the two that would care.  Measured and pinned in
-- tests/test_focus_innate_index_anchor.lua.
local tTalentTreeList = {
						['t25'] = {0, 10},
						['t20'] = {10, 0},
						['t15'] = {10, 0},
						['t10'] = {10, 0},
}

local tAllAbilityBuildList = {
						{1,3,1,2,3,6,1,1,3,3,6,2,2,2,6},
}

local nAbilityBuildList = J.Skill.GetRandomBuild( tAllAbilityBuildList )

local nTalentBuildList = J.Skill.GetTalentBuild( tTalentTreeList )

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_4'] = {
	"item_blood_grenade",
	"item_priest_outfit",
	"item_mekansm",
	"item_aether_lens",
	"item_glimmer_cape",--
	"item_blink",
	"item_guardian_greaves",--
	"item_aghanims_shard",
	"item_spirit_vessel",--
	"item_ultimate_scepter",
--	"item_wraith_pact",
	"item_shivas_guard",--
	"item_moon_shard",
	"item_octarine_core",--
	"item_overwhelming_blink",--
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_5'] = {
    "item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_aether_lens",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_pipe",
	"item_blink",
    "item_ultimate_scepter",
	-- "item_cyclone",
--	"item_wraith_pact",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_1'] = {
    "item_tango",
    "item_double_branches",
    "item_faerie_fire",

    "item_double_null_talisman",
    "item_power_treads",
    "item_magic_wand",
    "item_kaya",
    "item_ultimate_scepter",
    "item_kaya_and_sange",--
	"item_force_staff",
	"item_hurricane_pike",--
	"item_orchid",
	"item_aghanims_shard",
	"item_bloodthorn",--
	"item_sheepstick",--
	"item_moon_shard",
	"item_octarine_core",--
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_2'] = {
    "item_tango",
    "item_double_branches",
    "item_faerie_fire",

    "item_double_null_talisman",
    "item_power_treads",
    "item_magic_wand",
    "item_kaya",
    "item_ultimate_scepter",
    "item_kaya_and_sange",--
    "item_aether_lens",
    "item_black_king_bar",--
    "item_shivas_guard",--
    "item_aghanims_shard",
	"item_octarine_core",--
    -- "item_sheepstick",--
    "item_moon_shard",
    "item_ultimate_scepter_2",
    "item_travel_boots_2",--
}

sRoleItemsBuyList['pos_3'] = sRoleItemsBuyList['pos_2']

X['sBuyList'] = sRoleItemsBuyList[sRole]

X['sSellList'] = {

	"item_black_king_bar",
	"item_quelling_blade",

	"item_octarine_core",--
	"item_hand_of_midas",
}

if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_mage' }, {} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )

X['bDeafaultAbility'] = false
X['bDeafaultItem'] = true

function X.MinionThink(hMinionUnit)

	if Minion.IsValidUnit( hMinionUnit )
	then
		Minion.IllusionThink( hMinionUnit )
	end

end

--[[

npc_dota_hero_lion

"Ability1"		"lion_impale"
"Ability2"		"lion_voodoo"
"Ability3"		"lion_mana_drain"
"Ability4"		"generic_hidden"
"Ability5"		"generic_hidden"
"Ability6"		"lion_finger_of_death"
"Ability10"		"special_bonus_cast_range_100"
"Ability11"		"special_bonus_attack_damage_90"
"Ability12"		"special_bonus_unique_lion_3"
"Ability13"		"special_bonus_gold_income_25"
"Ability14"		"special_bonus_hp_500"
"Ability15"		"special_bonus_unique_lion"
"Ability16"		"special_bonus_unique_lion_2"
"Ability17"		"special_bonus_unique_lion_4"

modifier_lion_impale
modifier_lion_voodoo
modifier_lion_mana_drain
modifier_lion_finger_of_death_kill_counter
modifier_lion_finger_of_death
modifier_lion_finger_of_death_delay
modifier_lion_arcana_kill_effect

--]]

local abilityQ = bot:GetAbilityByName( sAbilityList[1] )
local abilityW = bot:GetAbilityByName( sAbilityList[2] )
local abilityE = bot:GetAbilityByName( sAbilityList[3] )
local abilityR = bot:GetAbilityByName( sAbilityList[6] )
local talent4 = bot:GetAbilityByName( sTalentList[4] )
local talent5 = bot:GetAbilityByName( sTalentList[5] )
-- FACT (GH #166, two sources joined by tools/agent/talent_slot_census.py, read
-- 2026-08-24).  sTalentList is built by aba_skill.X.GetTalentList in the game's
-- own talent ROW order, so index 7 / 8 are the two halves of the t25 row:
--
--     [7] special_bonus_unique_lion_4  ->  lion_voodoo/radius            = +250
--     [8] special_bonus_unique_lion_2  ->  lion_impale/AbilityCastRange  = +600
--
-- Every read of `talent8` below decides something about lion_voodoo (Hex) -- yet
-- the talent it names modifies lion_impale.  The Hex-AoE talent is the OTHER
-- half of the same row.  Read through X.IsHexAoe, never raw; see the note there.
--
-- SINCE 2026-08-27 the handle is also STRUCTURALLY UNTRAINED: the t25 row above
-- takes {0, 10} = [7], and a hero trains ONE talent per tier, so `talent8` can
-- never answer IsTrained() true in the shipped build.  The binding is kept, and
-- so is the gate in X.IsHexAoe, because neither the row nor Valve's slot order is
-- this file's to guarantee -- if either moves, the guard is what stands between
-- the change and fifteen location orders on a unit-target ability.
local talent8 = bot:GetAbilityByName( sTalentList[8] )

local castQDesire, castQLocation
local castWDesire, castWTarget
local castEDesire, castETarget
local castRDesire, castRTarget

local nMP, nHP, nLV, hEnemyList, hAllyList, botTarget, sMotive
local aetherRange = 0
local lastCastQTime = -99


function X.SkillsComplement()

	if X.ConsiderStopDrain() > 0
	then
		bot:Action_ClearActions( true )
		return
	end

	if J.CanNotUseAbility( bot ) or bot:IsInvisible() then return end

	-- [hero.md backlog #7 third layer, investigation 2026-08-20T19:xxZ]
	-- What USED to sit here: `nKeepMana = 400`, declared local at the top of
	-- the file and set here on every SkillsComplement tick. It was NEVER read.
	-- Grep across bots/ (both this file and jmz_func) confirms zero readers,
	-- so removing it is a documented no-op. Left as a comment so the next
	-- reader does not assume Lion reserves mana for Finger of Death: he does
	-- not. Impale (90-150), Hex (110-200) and their fallback branches all
	-- spend without consulting the ult's 200/400/600 cost. This is the same
	-- shape the zusult / zusultx audit named on Zeus (hero.md backlog #4);
	-- the actual fix belongs to a gated turbo lever mirroring
	-- X.zuus_ShouldSaveManaForUlt, and needs a real Lion frame with Finger
	-- off cooldown and mp in [cost, cost + spend) before it can ship.
	--
	-- SINCE ADJUDICATED -- do not read the paragraph above as work pending a
	-- dump. That lever is `lionult` in GH #73, and the director STRUCK it on
	-- 2026-08-20T23:00Z after a corpus pre-flight measured its domain empty
	-- over 1216 frames. The ruling attached one revival condition: the
	-- emptiness was to be recorded as holding AT FINGER LEVEL 1 only, because
	-- the cost ladder is {200, 400, 600} and a 400 line was expected to bite
	-- against the ~380 mana-pool bottom seen then; if Turbo games ever reached
	-- hero level 12+, the lever was to be RE-MEASURED rather than quoted.
	--
	-- Re-measured 2026-09-01, and it does not revive. The archive now holds a
	-- Finger at rank 2 (cost 400) on a level-20 Lion -- but that Lion's pool is
	-- 1551, not 380. Levels move BOTH sides of the ruling's arithmetic, and
	-- not at the same rate: the band [cost, cost + spend) is only ever as wide
	-- as the cheapest basic, Impale's ladder ENDS at 150 (rank 4, ~hero level
	-- 7), and the pool does not end. So the band is frozen at 150 mana while
	-- its denominator grows -- 21.2% of the pool at hero level 8, 9.7% at
	-- level 20. Leveling SHRINKS this lever's domain. The reading, its funnel
	-- (24 live-Lion instants -> 13 trained -> 3 off cooldown -> 3 affordable ->
	-- 0 in band, i.e. COOLDOWN is the binding clause, not mana), and its honest
	-- bounds (n=1 at rank 2; rank 3 unmeasured) are pinned in
	-- tests/test_lion_ult_reserve_domain.lua, which goes red if the domain
	-- stops being empty. The count "6 Lion frames" above was true when written
	-- and is now four times out of date; the file is the live number.
	aetherRange = 0
	nLV = bot:GetLevel()
	nMP = bot:GetMana()/bot:GetMaxMana()
	nHP = bot:GetHealth()/bot:GetMaxHealth()
	botTarget = J.GetProperTarget( bot )
	hEnemyList = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )
	hAllyList = J.GetAlliesNearLoc( bot:GetLocation(), 1600 )

	local aether = J.IsItemAvailable( "item_aether_lens" )
	-- Soak candidate 'aetherlens' (turbo-only), resolved inside
	-- J.GetAetherLensRangeBonus -- the shipped 250 is 25 more than the item's own
	-- KV grants (cast_range_bonus 225).  Gate off, this returns the 250 it is
	-- handed, so the four consumers below (Q :590, W :789, E :976, R :1102) are
	-- byte-for-byte the shipped ones.  Argument, ground truth and scope: the block
	-- above the helper in bots/FunLib/jmz_func.lua.
	if aether ~= nil then aetherRange = J.GetAetherLensRangeBonus( aether, 250 ) end
--	if talent4:IsTrained() then aetherRange = aetherRange + talent4:GetSpecialValueInt( "value" ) end
	

	castEDesire, castETarget, sMotive = X.ConsiderE()
	if ( castEDesire > 0 )
	then
		J.SetReportMotive( bDebugMode, sMotive )

		bot:Action_ClearActions( false )

		bot:ActionQueue_UseAbilityOnEntity( abilityE, castETarget )
		return
	end


	castRDesire, castRTarget, sMotive = X.ConsiderR()
	if ( castRDesire > 0 )
	then
		J.SetReportMotive( bDebugMode, sMotive )

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbilityOnEntity( abilityR, castRTarget )
		return

	end


	castQDesire, castQLocation, sMotive = X.ConsiderQ()
	if ( castQDesire > 0 )
	then
		J.SetReportMotive( bDebugMode, sMotive )

		J.SetQueuePtToINT( bot, true )

		bot:ActionQueue_UseAbilityOnLocation( abilityQ, castQLocation )
		lastCastQTime = DotaTime()
		return
	end


	castWDesire, castWTarget, sMotive = X.ConsiderW()
	if ( castWDesire > 0 )
	then
		J.SetReportMotive( bDebugMode, sMotive )

		J.SetQueuePtToINT( bot, true )

		if X.IsHexAoe()
		then
			bot:ActionQueue_UseAbilityOnLocation( abilityW, castWTarget )
		else
			bot:ActionQueue_UseAbilityOnEntity( abilityW, castWTarget )
		end
		return
	end


end

function X.ConsiderStopDrain()

	if X.IsAbilityEChanneling()
		and J.IsRetreating( bot )
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	-- [liondrainstop] the shipped release above only fires on J.IsRetreating,
	-- but a rooted hero is by construction not walking home -- the retreat
	-- mode fires when it looks safe to run, and Mana Drain's ~600u root during
	-- a fight blocks that from ever kicking in. Mirror of lion_IsDrainSafeToStart
	-- (same predicate, same danger radius, same 2s hero-damage window) applied
	-- to a channel that has ALREADY started; the second lever for the same shape,
	-- one at a time -- start-refusal cannot save a channel that started clean and
	-- turned unsafe (an enemy walked in / began hitting Lion mid-channel).
	if X.IsAbilityEChanneling()
		and X.lion_ShouldStopDrain( bot )
	then
		return BOT_ACTION_DESIRE_HIGH
	end

	return BOT_ACTION_DESIRE_NONE

end


function X.IsAbilityEChanneling()

	if bot:IsChanneling()
	then
		local nEnemyCreepList = bot:GetNearbyCreeps( 1200, true )
		for _, nCreep in pairs( nEnemyCreepList )
		do
			if nCreep:HasModifier( "modifier_lion_mana_drain" )
			then
				return true
			end
		end

		local nEnemyHeroList = J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE )
		for _, npcEnemy in pairs( nEnemyHeroList )
		do
			if npcEnemy:HasModifier( "modifier_lion_mana_drain" )
			then
				return true
			end
		end
	end

	return false

end


-- [lionqdmg] The damage Earth Spike's KILL branch is allowed to claim.
--
-- WHY THIS EXISTS.  `hAbility:GetAbilityDamage()` reads the ability's TOP-LEVEL
-- `AbilityDamage` KV field and nothing else, and `lion_impale` declares none in
-- this patch: its "// Damage." block is literally empty and the per-level
-- 105/170/235/300 lives in `AbilityValues/damage`.  So the shipped read below is
-- a hard 0.  Axis `0DMG` (GH #175, tools/agent/ability_damage_census.py): `lion`
-- is absent from tests/mock/ability_damage.lua's NONZERO table, which proves the
-- read is 0 whichever of Lion's own abilities the handle points at -- no handle
-- resolution needed.
--
-- DIRECTION, READ AT THIS CALL SITE (a silent zero cuts differently per site --
-- the whole lesson of hero_zuus.lua's X.GetBoltKillHealthCap, where the same
-- zero WIDENS).  Here the value's only consumer is J.WillMagicKillTarget in
-- X.ConsiderQ's kill loop, whose estimate is
--     EstDamage = nDamage * ( 1 + spellAmp ) - healthRegen * 5.0 / magicResist
-- so at nDamage = 0 it is <= 0 for every rank, every spell amp, every target,
-- and the final `nRealDamage >= GetHealth()` is false against anything alive.
-- That is a CEILING, not a pessimistic margin: the branch cannot fire at all,
-- and no level, item or amplification revives it.  GH #175 filed this direction
-- and deliberately did not fix it -- un-deadening a kill branch is a WIDENING
-- and needs its own evidence and its own id.  This is that id.
--
-- SHAPE (the GH #162 house rule, same as X.GetBoltKillHealthCap).  The shipped
-- expression is this function's LAST statement and the armed branch is the only
-- detour, so gate-off equivalence is structural; and an armed key answering <= 0
-- falls through to the shipped expression rather than inventing a default.
--
-- ONE LEVER, deliberately.  Spell amp is NOT folded in here (J.WillMagicKillTarget
-- applies it itself), and the `5.0` second regen delay that call site passes --
-- the only literal delay among this repo's J.WillMagicKillTarget call sites, all
-- the others being nCastPoint or a travel-time expression, against an Earth Spike
-- cast point of 0.3 -- is left exactly as shipped and is NOT part of this id.
-- Domain, the driven ceiling and the corpus limit: tests/test_lion_q_kill_damage.lua.
function X.GetImpaleKillDamage( hAbility )

	if J.IsModeTurbo() and J.IsSoakCandidate( 'lionqdmg' )
	then
		local nKvDamage = hAbility:GetSpecialValueInt( 'damage' )
		if nKvDamage > 0
		then
			return nKvDamage
		end
	end

	return hAbility:GetAbilityDamage()

end


function X.ConsiderQ()


	if not abilityQ:IsFullyCastable() then return 0 end
	-- [lanefix] Conserve mana in lane when no kill is on the table.
	if J.ShouldConserveManaInLane( bot ) then return 0 end

	local nSkillLV = abilityQ:GetLevel()
	local nCastRange = abilityQ:GetCastRange() + aetherRange + 20
	local nRadius	 = abilityQ:GetSpecialValueInt( "width" )
	local nCastPoint = abilityQ:GetCastPoint()
	local nManaCost = abilityQ:GetManaCost()
	local nDamage = X.GetImpaleKillDamage( abilityQ )
	local nDamageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyList = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )
	local nInBonusEnemyList = J.GetNearbyHeroes(bot, nCastRange + 200, true, BOT_MODE_NONE )

	local nTargetLocation = nil

	--击杀
	for _, npcEnemy in pairs( nInBonusEnemyList )
	do
		if J.IsValidHero( npcEnemy )
			and J.CanCastOnNonMagicImmune( npcEnemy )
			and J.WillMagicKillTarget( bot, npcEnemy, nDamage, 5.0 )
		then
			nTargetLocation = npcEnemy:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation, 'Q-击杀'..J.Chat.GetNormName( npcEnemy )
		end
	end

	--Aoe
	local nCanHurtEnemyAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius + 10, 0, 0 )
	if nCanHurtEnemyAoE.count >= 3
	then
		nTargetLocation = nCanHurtEnemyAoE.targetloc
		return BOT_ACTION_DESIRE_HIGH, nTargetLocation, 'Q-Aoe:'..( nCanHurtEnemyAoE.count )
	end

	--团战
	if J.IsInTeamFight( bot, 1200 )
	then
		local nAoeLoc = J.GetAoeEnemyHeroLocation( bot, nCastRange, nRadius + 20, 2 )
		if nAoeLoc ~= nil
		then
			nTargetLocation = nAoeLoc
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation, 'Q-团控'
		end
	end


	--攻击
	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and J.CanCastOnNonMagicImmune( botTarget )
			and J.IsInRange( botTarget, bot, nCastRange + 300 )
		then
			if nSkillLV >= 2 or nMP > 0.68 or J.GetHP( botTarget ) < 0.5
			then
				local nDelayTime = nCastPoint + GetUnitToUnitDistance( bot, botTarget )/1600
				nTargetLocation = J.GetDelayCastLocation( bot, botTarget, nCastRange, 260, nDelayTime )
				if nTargetLocation ~= nil
				then
					return BOT_ACTION_DESIRE_HIGH, nTargetLocation, 'Q-攻击:'..J.Chat.GetNormName( botTarget )
				end
			end
		end
	end


	--撤退
	if J.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do
			if J.IsValid( npcEnemy )
				and ( bot:WasRecentlyDamagedByHero( npcEnemy, 5.0 ) or bot:GetActiveModeDesire() > 0.7 )
				and J.CanCastOnNonMagicImmune( npcEnemy )
			then
				nTargetLocation = npcEnemy:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, 'Q-撤退:'..J.Chat.GetNormName( npcEnemy )
			end
		end
	end


	--Farm
	if J.IsFarming( bot )
		and nSkillLV >= 2
		and J.GetManaAfter( nManaCost ) > 0.3
	then
		local nNeutralCreeps = bot:GetNearbyNeutralCreeps( nCastRange )
		if #nNeutralCreeps >= 3
		then
			local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange, nRadius + 50, 0, 0 )
			if locationAoE.count >= 2
			then
				nTargetLocation = locationAoE.targetloc
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-打钱:"..locationAoE.count
			end
		end
		local nLaneCreeps = bot:GetNearbyLaneCreeps( nCastRange, true )
		if #nLaneCreeps >= 3
		then
			local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange, nRadius + 50, 0, 0 )
			if locationAoE.count >= 3
			then
				nTargetLocation = locationAoE.targetloc
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-Farm:"..locationAoE.count
			end
		end
	end


	--Push
	if ( J.IsPushing( bot ) or J.IsDefending( bot ) or J.IsFarming( bot ) )
		and J.IsAllowedToSpam( bot, nManaCost )
		and nSkillLV >= 4 and DotaTime() > 9 * 60
		and #hAllyList <= 2 and #hEnemyList == 0
		and not bot:HasScepter()
	then
		local laneCreepList = bot:GetNearbyLaneCreeps( 1300, true )
		if #laneCreepList >= 5
			and J.IsValid( laneCreepList[1] )
			and not laneCreepList[1]:HasModifier( "modifier_fountain_glyph" )
		then
			local locationAoEHurt = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange, nRadius + 90, 0, 0 )
			if locationAoEHurt.count >= 3
			then
				nTargetLocation = locationAoEHurt.targetloc
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-推线"..locationAoEHurt.count
			end
		end
	end


	--Roshan
	if J.IsDoingRoshan( bot )
		and J.GetManaAfter( nManaCost ) > 0.3
	then
		if J.IsRoshan( botTarget )
			and J.IsInRange( botTarget, bot, nCastRange )
		then
			nTargetLocation = botTarget:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation
		end
	end

	if J.IsDoingTormentor(bot)
	then
		if J.IsTormentor(botTarget)
		and J.IsInRange(bot, botTarget, nCastRange)
		and J.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), ''
		end
	end

	--常规
	if ( #hEnemyList > 0 or bot:WasRecentlyDamagedByAnyHero( 3.0 ) )
		and ( bot:GetActiveMode() ~= BOT_MODE_RETREAT or #hAllyList >= 2 )
		and #nInRangeEnemyList >= 1
		and nLV >= 15
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy ) 
				and J.IsInRange( bot, npcEnemy, nCastRange )
			then
				nTargetLocation = npcEnemy:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, 'Q-常规'
			end
		end
	end

	--Farming: use Earth Spike on neutral creeps
	if J.IsFarming( bot )
		and J.GetManaAfter( nManaCost ) > 0.3
		and nSkillLV >= 2
	then
		local nNeutralCreeps = bot:GetNearbyNeutralCreeps( nCastRange )
		if nNeutralCreeps ~= nil and #nNeutralCreeps >= 3
		then
			local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange, nRadius + 50, 0, 0 )
			if locationAoE.count >= 3
			then
				return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc, 'Q-Farm neutrals'
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE


end


function X.ConsiderW()


	if not abilityW:IsFullyCastable()
		or lastCastQTime > DotaTime() - 0.8
	then return 0 end

	local nSkillLV = abilityW:GetLevel()
	local nCastRange = abilityW:GetCastRange() + aetherRange
	local nCastPoint = abilityW:GetCastPoint()
	-- nManaCost is UNREAD here, and that is registered rather than tidied away:
	-- this is one of only two sites in the focus five (the other is
	-- hero_zuus.lua X.ConsiderE) where wiring it to the tree's live idiom --
	-- `J.GetManaAfter( nManaCost ) > 0.3` -- would point the same direction the
	-- idiom points.  Hex has no mana reserve of any kind, is not an ultimate,
	-- and does not restore mana; the other seven registered sites each fail one
	-- of those three for a different reason.  Adding the reserve is a BEHAVIOUR
	-- change: it needs a gated turbo candidate and a real frame, not an edit
	-- here.  See tests/test_dead_manacost_binding_census.lua for the register.
	local nManaCost = abilityW:GetManaCost()
	local nDamage = abilityW:GetAbilityDamage()
	local nDamageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyList = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )
	local nInBonusEnemyList = J.GetNearbyHeroes(bot, nCastRange + 300, true, BOT_MODE_NONE )

	--打断
	for _, npcEnemy in pairs( nInBonusEnemyList )
	do
		if J.IsValidHero( npcEnemy )
			and ( J.CanCastOnTargetAdvanced( npcEnemy ) or X.IsHexAoe() )
			and J.CanCastOnNonMagicImmune( npcEnemy )
		then
			if npcEnemy:IsChanneling()
			then
				if X.IsHexAoe()
				then
					return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation(), 'W-打断吟唱:'..J.Chat.GetNormName( npcEnemy )
				else
					return BOT_ACTION_DESIRE_HIGH, npcEnemy, 'W-打断吟唱:'..J.Chat.GetNormName( npcEnemy )
				end
			end

			if npcEnemy:IsCastingAbility()
				and J.IsInRange( bot, npcEnemy, nCastRange + 50 )
			then
				if X.IsHexAoe()
				then
					return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation(), 'W-打断施法:'..J.Chat.GetNormName( npcEnemy )
				else
					return BOT_ACTION_DESIRE_HIGH, npcEnemy, 'W-打断施法:'..J.Chat.GetNormName( npcEnemy )
				end
			end
		end
	end


	--团战中对最强的敌人使用
	if J.IsInTeamFight( bot, 1200 )
		and ( #nInBonusEnemyList >= 2 or #hAllyList >= 3 )
	then

		if X.IsHexAoe()
		then
			local nAoeLoc = J.GetAoeEnemyHeroLocation( bot, nCastRange, 250, 2 )
			if nAoeLoc ~= nil
			then
				return BOT_ACTION_DESIRE_HIGH, nAoeLoc, 'W-团控'
			end
		end


		local npcMostDangerousEnemy = nil
		local nMostDangerousDamage = 0
		for _, npcEnemy in pairs( nInBonusEnemyList )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and ( J.CanCastOnTargetAdvanced( npcEnemy ) or X.IsHexAoe() )
				and not J.IsDisabled( npcEnemy )
				and not J.IsTaunted( npcEnemy )
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

		if npcMostDangerousEnemy ~= nil
			and J.IsInRange( bot, npcMostDangerousEnemy, nCastRange + 50 )
		then
			if X.IsHexAoe()
			then
				return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy:GetLocation(), 'W-团战:'..J.Chat.GetNormName( npcMostDangerousEnemy )
			else
				return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy, 'W-团战:'..J.Chat.GetNormName( npcMostDangerousEnemy )
			end
		end

	end


	--攻击
	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and J.CanCastOnNonMagicImmune( botTarget )
			and ( J.CanCastOnTargetAdvanced( botTarget ) or X.IsHexAoe() )
			and J.IsInRange( bot, botTarget, nCastRange + 150 )
			and not J.IsDisabled( botTarget )
			and not J.IsTaunted( botTarget )
			and not botTarget:IsDisarmed()
		then
			if X.IsHexAoe()
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), 'W-进攻:'..J.Chat.GetNormName( botTarget )
			else
				return BOT_ACTION_DESIRE_HIGH, botTarget, 'W-进攻:'..J.Chat.GetNormName( botTarget )
			end
		end
	end


	--保护自己
	if bot:WasRecentlyDamagedByAnyHero( 3.0 ) and nLV >= 10
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #nInRangeEnemyList >= 1
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do
			if J.IsValid( npcEnemy )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and ( J.CanCastOnTargetAdvanced( npcEnemy ) or X.IsHexAoe() )
				and not J.IsDisabled( npcEnemy )
				and not J.IsTaunted( npcEnemy )
				and not npcEnemy:IsDisarmed()
			then
				if X.IsHexAoe()
				then
					return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation(), 'W-保护自己:'..J.Chat.GetNormName( npcEnemy )
				else
					return BOT_ACTION_DESIRE_HIGH, npcEnemy, 'W-保护自己'
				end
			end
		end
	end


	--撤退
	if J.IsRetreating( bot )
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do
			if J.IsValidHero( npcEnemy )
				and ( bot:WasRecentlyDamagedByHero( npcEnemy, 4.0 )
						or GetUnitToUnitDistance( bot, npcEnemy ) <= 600 )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and ( J.CanCastOnTargetAdvanced( npcEnemy ) or X.IsHexAoe() )
				and not J.IsDisabled( npcEnemy )
				and not J.IsTaunted( npcEnemy )
				and not npcEnemy:IsDisarmed()
			then
				if X.IsHexAoe()
				then
					return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation(), 'W-撤退:'..J.Chat.GetNormName( npcEnemy )
				else
					return BOT_ACTION_DESIRE_HIGH, npcEnemy, "W-撤退:"..J.Chat.GetNormName( npcEnemy )
				end
			end
		end
	end

	--roshan
	if J.IsDoingRoshan( bot ) and nMP > 0.6
	then
		if J.IsRoshan( botTarget )
			and J.IsInRange( bot, botTarget, nCastRange )
			and not J.IsDisabled( botTarget )
			and not botTarget:IsDisarmed()
		then
			if X.IsHexAoe()
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), 'W-肉山:'..J.Chat.GetNormName( botTarget )
			else
				return BOT_ACTION_DESIRE_HIGH, botTarget, "W-肉山"
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE


end


function X.ConsiderE()


	if not abilityE:IsFullyCastable() then return 0 end

	local nSkillLV = abilityE:GetLevel()
	local nCastRange = abilityE:GetCastRange() + aetherRange
	local nCastPoint = abilityE:GetCastPoint()
	local nManaCost = abilityE:GetManaCost()
	local nDamage = abilityE:GetAbilityDamage()
	local nDamageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyList = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )

	local nDuration = abilityE:GetSpecialValueFloat( 'duration' )
	local nManaDrain = abilityE:GetSpecialValueInt( 'mana_per_second' ) * nDuration
	local nLostMana = bot:GetMaxMana() - bot:GetMana()

	local nEnemyTowers = bot:GetNearbyTowers( 1000, true )

	--缺蓝的时候抽蓝
	if #hEnemyList == 0 and #nEnemyTowers == 0
		and not J.IsRetreating( bot )
		and not bot:WasRecentlyDamagedByAnyHero( 2.0 )
		and ( nLostMana > nManaDrain + bot:GetManaRegen() * nDuration + 50
				or nLostMana > 500 )
	then
		local nEnemyCreepList = bot:GetNearbyCreeps( 1600, true )
		for _, nCreep in pairs( nEnemyCreepList )
		do
			if J.IsValid( nCreep )
				and ( nCreep:GetMana() > nManaDrain * 0.8 or nCreep:GetMana() > 349 )
				and J.CanCastOnNonMagicImmune( nCreep )
			then
				return BOT_ACTION_DESIRE_HIGH, nCreep, 'E-补篮'
			end
		end
	end


	--秒杀幻像
	if #hEnemyList >= 1
	then
		local nTargetIllusion = nil
		local nMaxHealth = 0
		local nIllusionCount = 0
		for _, npcEnemy in pairs( hEnemyList )
		do
			if J.IsValidHero( npcEnemy )
				and npcEnemy:GetUnitName() ~= "npc_dota_hero_chaos_knight"
				and npcEnemy:GetUnitName() ~= "npc_dota_hero_vengefulspirit"
				and J.IsInRange( npcEnemy, bot, nCastRange + 300 )
				and J.IsSuspiciousIllusion( npcEnemy )
			then
				nIllusionCount = nIllusionCount + 1
				if npcEnemy:GetHealth() > nMaxHealth
				then
					nTargetIllusion = npcEnemy
					nMaxHealth = npcEnemy:GetHealth()
				end
			end
		end

		if nTargetIllusion ~= nil
			and ( nIllusionCount >= 2 or J.GetHP( nTargetIllusion ) > 0.9 )
		then
			return BOT_ACTION_DESIRE_HIGH, nTargetIllusion, 'E-清理幻像:'..J.Chat.GetNormName( nTargetIllusion )
		end
	end


	if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0 end

	-- [liondrain] Both combat drain branches below sit AFTER the check above,
	-- i.e. they only ever fire when Impale, Hex and Finger are all unavailable.
	-- That is exactly the state in which a support being hit at close range
	-- should be walking away: Mana Drain is a multi-second STATIONARY channel
	-- with no defensive value, and while it runs J.CanNotUseAbility( bot ) is
	-- true (IsChanneling) so X.SkillsComplement returns on its second line --
	-- Lion cannot cast anything at all until the channel ends, and the only
	-- release is X.ConsiderStopDrain, which fires only on J.IsRetreating.
	if not X.lion_IsDrainSafeToStart( bot ) then return 0 end

	--团战吸蓝
	if J.IsInTeamFight( bot, 1000 )
	then
		for _, npcEnemy in pairs( hEnemyList )
		do
			if J.IsValidHero( npcEnemy )
				and J.IsInRange( bot, npcEnemy, nCastRange )
				and not npcEnemy:HasModifier( "modifier_lion_finger_of_death" )
				and npcEnemy:GetMana() > 200
				and J.CanCastOnMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and not J.IsDisabled( npcEnemy )
				and ( not J.IsValidHero( botTarget ) or not X.MayKillTarget( botTarget ) )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy, 'E-团战吸篮:'..J.Chat.GetNormName( npcEnemy )
			end
		end
	end


	--打架抽蓝
	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and not botTarget:HasModifier( "modifier_lion_finger_of_death" )
			and botTarget:GetMana() > 200
			and J.IsInRange( bot, botTarget, nCastRange )
			and J.CanCastOnNonMagicImmune( botTarget )
			and J.CanCastOnTargetAdvanced( botTarget )
			and not J.IsDisabled( botTarget )
			and not X.MayKillTarget( botTarget )
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, 'E-抽篮:'..J.Chat.GetNormName( botTarget )
		end
	end


	return BOT_ACTION_DESIRE_NONE


end


function X.ConsiderR()


	if not abilityR:IsFullyCastable() then return 0 end

	local nSkillLV = abilityR:GetLevel()
	local nRadius	 = 0
	local nCastRange = abilityR:GetCastRange() + aetherRange
	if nCastRange > 1200 then nCastRange = 1200 end
	local nCastPoint = abilityR:GetCastPoint()
	local nManaCost = abilityR:GetManaCost()
	local nDamageBonus = X.GetAbilityRDamageBonus()
	local nRawDamage = 475 + 125 * nSkillLV
	if bot:HasScepter()
	then
		nRadius = X.GetAbilityRSplashRadius()
		nRawDamage = 575 + 125 * nSkillLV
	end

	local nDamage = nRawDamage + nDamageBonus
	local nDamageType = DAMAGE_TYPE_MAGICAL

	local nInRangeEnemyList = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )
	local nInBonusEnemyList = J.GetNearbyHeroes(bot, nCastRange + 400, true, BOT_MODE_NONE )

	--击杀
	for _, npcEnemy in pairs( nInBonusEnemyList )
	do
		if J.IsValidHero( npcEnemy )
			and X.CanCastAbilityROnTarget( npcEnemy )
		then
			if J.WillMagicKillTarget( bot, npcEnemy, nDamage, nCastPoint + 0.25 )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy, 'R击杀'..J.Chat.GetNormName( npcEnemy )
			end
		end
	end

	--团战对最弱的敌人
	-- [ultcash / freehunt#1] a DYING lion cashes the finger out even at ult
	-- level 1 (watched 231244 t=10:50: lion died holding a ready finger; the
	-- nSkillLV >= 2 clause kept the low-HP branch shut). Gated in the helper.
	if J.IsInTeamFight( bot, 600 )
		or ( nHP < 0.4 and ( nSkillLV >= 2 or J.IsDyingUnderAttack( bot ) ) )
	then
		local npcWeakestEnemy = nil
		local npcWeakestEnemyHealth = 10000

		for _, npcEnemy in pairs( nInBonusEnemyList )
		do
			if J.IsValid( npcEnemy )
				and X.CanCastAbilityROnTarget( npcEnemy )
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
			and J.WillMagicKillTarget( bot, npcWeakestEnemy, nDamage , nCastPoint + 0.25 )
		then
			return BOT_ACTION_DESIRE_HIGH, npcWeakestEnemy, 'R团战'..J.Chat.GetNormName( npcWeakestEnemy )
		end

		--有A后的团战Aoe
		if bot:HasScepter()
		then
			local hNearbyEnemyList = J.GetEnemyList( bot, nCastRange + nRadius + 200 )
			local nMaxAoeCount = 1
			local nBestAoeEnemy = nil
			for _, npcEnemy in pairs( nInBonusEnemyList )
			do
				if J.IsValidHero( npcEnemy )
					and J.IsInRange( bot, npcEnemy, nCastRange + 150 )
					and not npcEnemy:IsMagicImmune()
					and not npcEnemy:IsInvulnerable()
				then
					local nAoeCount = 0
					for _, nEnemy in pairs( hNearbyEnemyList )
					do
						if J.IsInRange( npcEnemy, nEnemy, nRadius )
							and not nEnemy:IsMagicImmune()
							and not nEnemy:IsInvulnerable()
						then
							nAoeCount = nAoeCount + 1
						end
					end
					if nAoeCount > nMaxAoeCount
					then
						nMaxAoeCount = nAoeCount
						nBestAoeEnemy = npcEnemy
					end
				end
			end

			if nBestAoeEnemy ~= nil
				and ( nMaxAoeCount >= 4
					or ( nMaxAoeCount >= 3 and nHP < 0.46 ) )
			then
				return BOT_ACTION_DESIRE_HIGH, nBestAoeEnemy, 'R团战Aoe:'..J.Chat.GetNormName( nBestAoeEnemy )
			end
		end

	end


	--打架
	if J.IsGoingOnSomeone( bot )
	then
		if J.IsValidHero( botTarget )
			and J.IsInRange( botTarget, bot, nCastRange + 200 )
			and X.CanCastAbilityROnTarget( botTarget )
		then
			if J.WillMagicKillTarget( bot, botTarget, nDamage , nCastPoint + 0.25 ) or ( nHP < 0.2 and nSkillLV >= 2 )
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "R打架"..J.Chat.GetNormName( botTarget )
			end
		end
	end





	--撤退
	if J.IsRetreating( bot ) and nSkillLV >= 2
		and nHP < 0.3 and bot:WasRecentlyDamagedByAnyHero( 3.0 )
	then
		for _, npcEnemy in pairs( nInRangeEnemyList )
		do
			if J.IsValidHero( npcEnemy )
				and X.CanCastAbilityROnTarget( npcEnemy )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy, "R死前大"..J.Chat.GetNormName( npcEnemy )
			end
		end
	end


	--带线
	if bot:HasScepter()
		and ( J.IsPushing( bot ) or J.IsFarming( bot ) or J.IsDefending( bot ) )
		and nSkillLV >= 3
		and #hEnemyList == 0
		and #hAllyList <= 2
	then
		local nEnemyCreepList = bot:GetNearbyLaneCreeps( 1200, true )
		if #nEnemyCreepList >= 5
			and not nEnemyCreepList[1]:HasModifier( "modifier_fountain_glyph" )
		then
			local nMaxAoeCount = 4
			local nBestCreep = nil
			for _, nCreep in pairs( nEnemyCreepList )
			do
				local nAoeCount = J.GetNearbyAroundLocationUnitCount( true, false, nRadius, nCreep:GetLocation() )
				if nAoeCount > nMaxAoeCount
				then
					nBestCreep = nCreep
					nMaxAoeCount = nAoeCount
				end
			end
			if nBestCreep ~= nil
			then
				return BOT_ACTION_DESIRE_HIGH, nBestCreep, "R-带线"
			end
		end
	end

	--roshan
	if J.IsDoingRoshan( bot )
		and J.GetManaAfter( nManaCost ) > 0.3
	then
		if J.IsRoshan( botTarget ) and J.GetHP( botTarget ) > 0.2
			and J.IsInRange( bot, botTarget, nCastRange )
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

	return BOT_ACTION_DESIRE_NONE


end


--- Splash radius of a scepter Finger of Death, in units.
---
--- SHIPPED (no gate, tried first): the key `splash_radius_scepter`, which this
--- file has always read off lion_finger_of_death.
---
--- WIDENED (soak candidate 'lionsplash', GH #162): that key is not in the
--- ability's AbilityValues block in this patch.  Its name today is
--- 'splash_radius' (npc_dota_hero_lion.txt: AbilityValues/splash_radius/
--- special_bonus_scepter = 325, affected_by_aoe_increase = 1), and a
--- GetSpecialValueInt for a key the ability does not have answers 0 -- with no
--- error, and nothing a bot-side print could show (AGENTS.md).  So the shipped
--- read is a silent zero, and BOTH consumers of nRadius in X.ConsiderR are
--- dead code whenever Lion holds a scepter:
---   * the R团战Aoe branch counts enemies within nRadius of the candidate and
---     needs > 1; at radius 0 only the candidate itself is ever inside, so the
---     count is 1 and the branch cannot fire;
---   * the R-带线 branch needs GetNearbyAroundLocationUnitCount(..., nRadius,
---     ...) > 4 around a creep; at radius 0 it cannot clear 4.
---
--- The widening is one-directional by construction: the shipped key runs FIRST
--- and wins whenever it answers anything positive, so gate-off is structurally
--- -- not merely measurably -- the shipped path, and gate-on differs only on
--- the exact frames where the shipped key reads 0 AND the current key does not.
--- (Which is why this is a candidate and not a promoted default: see the LIMIT
--- in tests/test_lion_r_splash_radius_key.lua -- the offline world answers 0
--- for EVERY key and false for HasScepter, so no fixture can watch it fire.)
function X.GetAbilityRSplashRadius()

	local nShipped = abilityR:GetSpecialValueInt( 'splash_radius_scepter' )
	if nShipped > 0 then return nShipped end

	if J.IsModeTurbo() and J.IsSoakCandidate( 'lionsplash' )
	then
		local nCurrent = abilityR:GetSpecialValueInt( 'splash_radius' )
		if nCurrent > 0 then return nCurrent end
	end

	return nShipped

end


function X.GetAbilityRDamageBonus()

	-- FACT, 2026-08-26 (GH #228, axis TALENTVALUE).  nTalantDamage is 0 and always has
	-- been: special_bonus_unique_lion_8 is a hero-UNIQUE talent, and unique talents own
	-- no KV block anywhere, so the handle answers no key -- `value` included.  The +20
	-- lives inside the ability the next line already reads:
	--     lion_finger_of_death / "damage_per_kill" { "value" "25"
	--                                                "special_bonus_unique_lion_8" "+20" }
	-- which is where the engine folds it for a caster who trained it.  So nDamageBonus
	-- is ALREADY correct and repointing this term would double-count -- the same fold
	-- the neighbouring GH #162 repair (`splash_radius`, an entry with no base value at
	-- all) depends on to be worth anything.  Do not "fix" it; 21 sites tree-wide share
	-- the shape (tools/agent/talent_value_read_census.py,
	-- tests/test_talent_value_read_anchor.lua).
	local nTalantDamage = talent5:IsTrained() and talent5:GetSpecialValueInt( 'value' ) or 0
	local nDamageBonus = abilityR:GetSpecialValueInt( 'damage_per_kill' ) + nTalantDamage
	local sModifierName = "modifier_lion_finger_of_death_kill_counter"
	local nModifierCount = J.GetModifierCount( bot, sModifierName )
	

	return nModifierCount * nDamageBonus

end


function X.CanCastAbilityROnTarget( nTarget )

	if J.CanCastOnTargetAdvanced( nTarget )
		and not nTarget:HasModifier( "modifier_arc_warden_tempest_double" )
		and not J.IsHaveAegis( nTarget )
	then
		return J.CanCastOnNonMagicImmune( nTarget )
	end

	return false

end


--- Is Hex an AREA spell right now?  Every `talent8` read in X.ConsiderW,
--- X.ConsiderStopDrain and the W dispatch in X.SkillsComplement asks this one
--- question, so they all come through here.
---
--- WHY IT IS A QUESTION AT ALL (GH #166).  `talent8` = sTalentList[8] =
--- special_bonus_unique_lion_2, which the game's KV shows as an override on
--- lion_impale/AbilityCastRange (+600).  It does not touch lion_voodoo.  The
--- talent that gives Hex a radius is special_bonus_unique_lion_4 (+250), and it
--- is sTalentList[7] -- the other half of the same t25 row.  So the shipped
--- reads name the wrong half.  This file's own tTalentTreeList USED TO pick
--- ['t25'] = {10, 0} => aba_skill.X.GetTalentBuild index 4 = 8, i.e. the build
--- trained exactly the half that makes these reads answer true.
---
--- CHANGED 2026-08-27: the row now takes {0, 10} = [7], the real +250 Hex radius.
--- One talent per tier => `talent8` is structurally untrained => every read here
--- answers false, which is the CORRECT answer for a unit-target ability under
--- either talent.  That was not the reason for the change (see the t25 pricing
--- block at the top of this file: [7] is simply the stronger talent, and more so
--- for a bot than for a human) -- it is what the change happens to buy, and it
--- means the two consequences below are now unreachable BY CONSTRUCTION rather
--- than merely gated.  The gate is kept anyway: neither the row nor Valve's slot
--- order is this file's to guarantee, and a green test is not a promise.
---
--- Two things go wrong when it does, and only the first needs the engine:
---   * the dispatch swaps ActionQueue_UseAbilityOnEntity for
---     ActionQueue_UseAbilityOnLocation, while lion_voodoo's AbilityBehavior is
---     DOTA_ABILITY_BEHAVIOR_UNIT_TARGET with no talent override anywhere in the
---     KV -- a location order for a unit-target ability.  What the engine does
---     with that cannot be settled offline (AGENTS.md: no bot-side debugging),
---     so it is stated as the risk it is, not as a measured no-op;
---   * `( J.CanCastOnTargetAdvanced( x ) or X.IsHexAoe() )` drops the
---     cast-legality check on the strength of the same false premise.  That one
---     needs no engine reading to be wrong: Hex is unit-targeted either way, so
---     there is never a reason to skip it.
---
--- NARROWING (soak candidate 'lionhexaoe', turbo-only).  The shipped read runs
--- FIRST and a `return false` is the only thing the armed path can add, so
--- gate-off equivalence is structural rather than measured -- the dual of the
--- widening shape GH #154 wrote down, and the same discipline as GH #165's
--- "armed may only take the min".
function X.IsHexAoe()

	if talent8 == nil or not talent8:IsTrained() then return false end

	if J.IsModeTurbo() and J.IsSoakCandidate( 'lionhexaoe' ) then return false end

	return true

end


-- An enemy hero closer than this is assumed to stay on top of Lion for the
-- whole channel (Mana Drain roots him; he cannot walk out of it without
-- breaking it, which the shipped X.ConsiderStopDrain only does when retreating).
-- The two pinned frames bound this constant to [484, 781): 484 is the closest
-- observed channel that must be refused, 781 the nearest one that must still be
-- allowed. Written as an assertion in tests/test_replay_260819_lion_drain.lua,
-- so moving this number self-reports.
X.nEDrainDangerRadius = 500

--- [liondrain] gated (turbo + soak candidate): is it safe to START a Mana Drain
--- channel right now? False only when Lion is already being hit by an enemy
--- hero AND one is inside X.nEDrainDangerRadius -- i.e. he would be rooting
--- himself, mute, in front of someone who is currently killing him.
--- Deliberately narrow: the mana-refill and illusion branches sit ABOVE the
--- call site and are untouched, and being merely NEAR an enemy is not enough
--- (taking hero damage is what separates the observed deaths from the observed
--- safe channels at the same distance).
function X.lion_IsDrainSafeToStart( hBot )

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'liondrain' ) ) then return true end

	if not hBot:WasRecentlyDamagedByAnyHero( 2.0 ) then return true end

	-- J.GetNearbyHeroes already drops corpses, Meepo clones and tempest doubles
	-- (it filters every element through J.IsValidHero), so emptiness is the
	-- whole question here -- re-checking validity would be dead code.
	local nCloseEnemyList = J.GetNearbyHeroes( hBot, X.nEDrainDangerRadius, true, BOT_MODE_NONE )
	if nCloseEnemyList ~= nil and #nCloseEnemyList > 0
	then
		return false
	end

	return true

end


--- [liondrainstop] gated (turbo + soak candidate): should Lion RELEASE an
--- already-running Mana Drain channel right now? True only when the same
--- pressure test that refuses to start one (a hero currently killing him AND
--- inside X.nEDrainDangerRadius) is met -- the second lever, one at a time.
--- Deliberately uses the SAME predicate as lion_IsDrainSafeToStart (with the
--- polarity flipped): start-refusal cannot save a channel that starts clean
--- and turns unsafe (an enemy walks in / begins hitting Lion during it), so
--- this catches the residual class the start guard cannot see. Gate off (or
--- non-turbo) => false, and X.ConsiderStopDrain keeps its shipped shape.
function X.lion_ShouldStopDrain( hBot )

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainstop' ) ) then return false end

	if not hBot:WasRecentlyDamagedByAnyHero( 2.0 ) then return false end

	local nCloseEnemyList = J.GetNearbyHeroes( hBot, X.nEDrainDangerRadius, true, BOT_MODE_NONE )
	if nCloseEnemyList == nil or #nCloseEnemyList == 0
	then
		return false
	end

	return true

end


function X.IsOtherAbilityFullyCastable()

	return abilityQ:IsFullyCastable() or abilityW:IsFullyCastable() or abilityR:IsFullyCastable()

end


function X.MayKillTarget( nTarget )

	if nTarget:HasModifier( "modifier_lion_finger_of_death" )
	then
		return true
	end

	local nDamageToTarget = bot:GetEstimatedDamageToTarget( true, botTarget, 9.0, DAMAGE_TYPE_PHYSICAL )
	if J.CanKillTarget( botTarget, nDamageToTarget, DAMAGE_TYPE_PHYSICAL )
	then
		return true
	end

	return false

end

return X
-- dota2jmz@163.com QQ:2462331592..
