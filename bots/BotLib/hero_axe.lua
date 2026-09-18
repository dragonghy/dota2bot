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

-- [axebuild] Call-max build (gated, turbo-only).  A PURE PERMUTATION of the row
-- above -- same fifteen entries, same multiset -- that swaps WHICH of the two
-- non-Helix basics gets its fourth point inside the first thirteen, and
-- therefore WHICH one the skill-point wall strands.
--
-- WHY A BUILD ROW IS A LEVER AT ALL, and this is the part that is not a
-- preference.  GH #366 / GH #822 / GH #864 settled that the level-up queue head
-- parks at entry 15 (the t15 talent) and never moves: thirteen ability points
-- get spent, in the multiset {4,4,3,2}, and entries 16 and 17 are bought by
-- nobody.  Entry 17 is always the ultimate's third point; entry 16 is the FOURTH
-- rank of whichever basic the first thirteen points left at 3, and which basic
-- that is is decided entirely by this literal.  tests/test_focus_strand_identity
-- .lua derives it offline and agrees with #822's wave column 8/8.
--
-- ⛔ SO THE STRAND CANNOT BE REMOVED -- #864 LIMIT 2, checked over 14 rows in
-- that file's section 5b.  Thirteen points across three basics and an ultimate
-- leave exactly one basic at rank 3 no matter how the row is written.  What a row
-- edit CAN do, and the only thing this candidate claims, is choose WHICH ability
-- pays.  Anyone quoting this block as "the wall is fixed" has misread it: the
-- wall itself lives in bots/ability_item_usage_generic.lua (127 heroes) and has
-- its own gated look-ahead, `skillstall` (GH #799).
--
-- WHAT THE SHIPPED ROW CHOOSES.  It strands `axe_berserkers_call`:
--
--     shipped   Call   r1@lv3  r2@lv13 r3@lv14 r4@lv16 = NEVER (entry 16)
--               Hunger r1@lv1  r2@lv8  r3@lv9  r4@lv11
--
-- i.e. Axe carries a RANK ONE Berserker's Call -- 2.1s taunt, 18s cooldown --
-- from hero level 3 to hero level 12, which in Turbo (docs/PROJECT.md: ~20
-- minute games, doubled XP) is most of the game's fighting window, while Battle
-- Hunger is finished at level 11.  (These are HERO LEVELS off the driven
-- GetSkillList, not row indices: level 10 goes on a talent, so entry 10 lands at
-- level 11 -- GH #134.)
--
-- WHAT THIS ROW CHOOSES INSTEAD.  It strands `axe_battle_hunger`:
--
--     armed     Call   r1@lv3  r2@lv8  r3@lv9  r4@lv11
--               Hunger r1@lv1  r2@lv13 r3@lv14 r4@lv16 = NEVER (entry 16)
--
-- ⚠️ NARROWNESS, and it is asserted rather than asserted-in-prose
-- (tests/test_axe_call_max_build.lua §4): Counter Helix and Culling Blade hold
-- IDENTICAL rank ladders under both rows -- Helix 2/4/5/7, Culling 6/12/17 --
-- and hero levels 1 through 7 are byte-identical.  The two rows first differ at
-- hero level 8.  So a wave reading is attributable to the Q/W allocation and to
-- nothing else in this literal.
--
-- THE PRICE OF THE SWAP, off the game's own KV (tests/mock/special_value_shapes
-- .lua, generated from npc_heroes.txt -- pinned by §5 of the test so a patch that
-- moves these numbers turns this paragraph red rather than stale):
--
--   axe_berserkers_call  duration 2.1/2.4/2.7/3.0   cooldown 18/16/14/12
--                        bonus_armor 12/13/14/15    radius 315 (flat)
--   axe_battle_hunger    damage_per_second 12/16/20/24   slow 18/22/26/30
--                        cooldown 20/15/10/5        duration 12.0 (flat)
--
-- The fourth rank of Call is +0.3s on an AoE 315-radius TAUNT and -2s cooldown;
-- the fourth rank of Hunger is +4 dps on ONE target for 12s (+48 pre-mitigation)
-- and -5s cooldown on a damage-over-time that does not stop a fight.  Against
-- Turbo health pools the Hunger rank is rounding; the Call rank is disable, which
-- is the only currency Axe's whole kit trades in.
--
-- ⚠️ WHAT IS GIVEN UP, stated because it is real and lands EARLIER than the gain:
-- Battle Hunger stays at rank 1 (20s cooldown, 12 dps, 18% slow, 600 cast range)
-- from level 1 to level 12, where the shipped row has it at rank 2 from level 8
-- and rank 4 from level 11.
-- That is laning/chasing harass traded for mid-game lockdown.  In Turbo the lane
-- phase is the short end of that trade; in normal mode it may not be, which is
-- exactly why this is `J.IsModeTurbo()`-gated and not a default.
--
-- ⚠️ THEORY (rule 2 condition (c), retrievable): standard Axe skill order is
-- Counter Helix first, Berserker's Call second, Battle Hunger last as a value
-- point.  This row is that order; the shipped row is not.  Note what is NOT
-- claimed: no wave has read either row, and this file's own ConsiderQ carries an
-- entire family of candidates about WHEN to Call (axecallring / axecallcrowd /
-- axecallnocap / axecallclock / axecallbkb_i / axecallbkb_ii) -- all of them
-- have been tuning the timing of an ability that is permanently one rank short.
--
-- Gated turbo + soak-candidate 'axebuild' so it is inert until an A/B wave says
-- otherwise; gate-off this file is byte-for-byte the shipped row (§2).
local tCallMaxBuildList = {
	{2,3,1,3,3,6,3,1,1,1,6,2,2,2,6},--pos3, Call maxed instead of Battle Hunger
}

local nAbilityBuildList
if J.IsModeTurbo() and J.IsSoakCandidate( 'axebuild' ) then
	nAbilityBuildList = J.Skill.GetRandomBuild( tCallMaxBuildList )
else
	nAbilityBuildList = J.Skill.GetRandomBuild( tAllAbilityBuildList )
end

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
--   * talent7 IS THE PICK AND IS STILL NEVER TRAINED, and the two halves of that
--     sentence come from different places.  This file's t25 row is {0,10} = index
--     [7], so the handle above is the one this Axe would train; the
--     `nRadius + talent7:GetSpecialValueInt('value')` line below is therefore the
--     pick's own read and not the abandoned half's.  It adds 0, and GH #228 says
--     that is CORRECT -- the engine has already folded the +85 into the base
--     `radius` the site reads, so a handle that answered would double-count.
--     CORRECTED 2026-09-13.  This bullet used to open "talent7 is LIVE from level
--     25" and end "it used to be protected by the branch being unreachable as
--     well, and now the fold argument is the only thing holding it up".  Both
--     halves are quoted rather than deleted, which is what
--     tests/test_focus_talent_reach_wall.lua section 4 requires of a retired
--     sentence: it may stand as a record, never on its own.  That was the retired
--     GH #84 premise's mistake taken from the
--     other side: it reads LEVEL REACHED as TALENT TRAINED.  GH #366 /
--     tests/test_skill_point_stall_frame.lua measured ten heroes at level 17-22
--     ALL holding thirteen ability points and at most ONE talent -- so reaching
--     level 25 buys nothing, and this file's own row says why: its third Culling
--     point is row entry 15, and thirteen points stop at entry 13.  The branch is
--     unreachable again, for a stronger reason than the one that was retired, and
--     the fold argument is back to being a second line of defence rather than the
--     only one.  Driven per-hero in tests/test_focus_talent_reach_wall.lua
--     section 2; carry #366's LIMIT (one frame, one game, one instant) with it.
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
---
--- ⭐ BOTH OF THOSE BOUNDS MOVED 2026-09-07 (hero, backlog -112, GH #577 §5).
--- Two archived frames were pinned into tests/frames/ and are driven by
--- tests/test_axe_call_staged_frames.lua.  Read that file before quoting either
--- paragraph above; neither is deleted, because each is still true OF THE CORPUS
--- FRAME it was taken on.
---   * BRANCH (i) NO LONGER NEEDS THREE FLIPS.  On
---     f_260831_061811_axe_call_tp_channel.lua (t=1209.9) Call is rank 3 at cd 0
---     IN THE REPLAY, and the enemy 190.2u away carries BOTH
---     `modifier_black_king_bar_immune` -- a name the shipped IsMagicImmune
---     override reads -- AND `modifier_teleporting`, with the replay
---     corroborating the channel behaviourally (he holds 190.2u across two
---     consecutive samples and is gone by t=1211.9).  What used to be three
---     invented flips is now two READER repairs and no invention.  ⚠️ The two
---     repairs do not have equal standing: the immunity one agrees with the
---     shipped override's own modifier list, the channel one has no shipped
---     criterion to agree with.  The test asserts that asymmetry.
---   * BRANCH (ii) IS STILL SOURCE-LEVEL-ONLY, but for a STRONGER reason.  Of
---     the three blockers, J.IsDisabled was corpus luck and is gone on
---     f_260828_002127_axe_call_bkb_ring.lua.  The other two are STRUCTURAL: the
---     behav dumper's snapshot schema carries no target channel and no
---     active-mode channel, so J.GetProperTarget is nil and J.IsGoingOnSomeone
---     false on EVERY frame make_fixture.py can produce -- not on this one by
---     accident.  ⇒ no fixture will ever size branch (ii); only a wave can.
---     That frame does carry (ii)'s VALUE COLUMN on real state, which is the
---     other half worth having: a spell-immune Lina at 75.1u with Necrolyte at
---     165.3u and a 228-HP Shadow Shaman at 276.9u, both non-immune, both inside
---     the 315u radius -- the three-hero taunt the shipped veto throws away.
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


--- The wall clock on X.ConsiderQ's 带线 firing point, and the turbo-only halving
--- of it.  Written as two named constants so a test mirrors the NUMBERS off the
--- source instead of re-typing them (the stale-mirror family,
--- tests/test_cast_ring_mirror_discipline.lua).
X.nQLanePushClockShipped = 6 * 60
X.nQLanePushClockTurbo   = 3 * 60


--- The wall-clock curfew on X.ConsiderQ's 带线 (lane-push) firing point.  Soak
--- candidate `axecallclock` (turbo-only, INERT until armed).  STANDALONE: this
--- function holds exactly one J.IsSoakCandidate call and it names only its own
--- id.
---
--- ⭐ THE DEFECT.  `DotaTime() > 6 * 60` is the ONLY wall clock anywhere in
--- bots/BotLib/hero_axe.lua, and 6 minutes is a NORMAL-MODE constant standing in
--- front of the one Axe play whose whole engine is online long before it.  The
--- branch taunts a lane wave onto Axe so that Counter Helix spins it down --
--- and THIS FILE'S OWN ability build maxes Counter Helix at hero level 7:
---
---     tAllAbilityBuildList = { {2,3,1,3,3,6,3,2,2,2,6,1,1,1,6} }  -- pos3
---                              ^   ^ ^   ^
---                          lv2 |   | |   `-- lv7: Counter Helix RANK 4
---                              |   | `------ lv5: rank 3
---                              `---`-------- lv2/lv4: ranks 1-2
---
--- so by the time the curfew lifts the payoff has been at full rank for several
--- hero levels.  In Turbo, where XP is doubled, level 7 arrives well inside the
--- window this clock closes.
---
--- ⚠️ WHAT THE CLOCK IS NOT, checked rather than assumed.  It is not a mana
--- policy: the same conjunction already carries `J.IsAllowedToSpam( bot,
--- nManaCost )`, which is this tree's own mana rationer, so a second
--- time-shaped rationer on the same `if` would be rationing twice.  It is not a
--- safety term either: the same conjunction already carries `#hEnemyList == 0`
--- (no enemy hero in view) and `#hAllyList <= 2`, which are the direct
--- measurements of "is it safe to stand in a wave" -- as with `cmtfclock`, the
--- proxy sits beside the measurement and overrides it.
---
--- ARMED: 3 * 60, the shipped number halved.  The 2x is not invented here -- it
--- is this repo's own stated Turbo pace ratio (docs/PROJECT.md: ~20 minute games
--- against ~35-40).  Halving rather than REMOVING is deliberate and is the
--- narrow change: whether this branch should carry a clock at all is a second
--- question, and conjoining the two would make one wave reading unattributable
--- to either.
---
--- ⚠️ DIRECTION: THIS IS A WIDENING, and it is the first thing a reader needs.
--- Every t past 6:00 is also past 3:00, so the armed predicate is a strict
--- SUPERSET of the shipped one: arming can only ADD 带线 taunts, inside the
--- window (3:00, 6:00], and can never remove one or move one onto a different
--- target.  A negative wave reading is attributable to "those early lane-push
--- taunts were not worth casting" and NEVER to a cast this lever refused.
--- Gate off (or non-turbo) the function is literally `DotaTime() > 6 * 60`.
---
--- ⚠️ HONEST BOUNDS, four, none of them rhetorical:
---   1. ⛔ END-TO-END DOMAIN IS 0 AND CANNOT BE ANYTHING ELSE TODAY.  The branch
---      also requires `#laneCreepList >= 4`, and the fixture corpus carries NO
---      non-hero units at all (GH #772: 1410/1410 dumped units are heroes).  So
---      no archived frame can drive this branch to its `return`.  What IS
---      measured is the GATE-LAYER domain -- the clock's own answer on real
---      frames at real DotaTime() -- which is the half this lever changes.
---      Quoting the two as one number would be an execution verification out of
---      thin air.
---   2. GATE-LAYER DOMAIN, stated as the number it is: over the 16 Axe-subject
---      instants in tests/fixtures/ + tests/frames/, exactly 2 sit inside
---      (3:00, 6:00] -- f_260909_215412_axe_call_init_224 (t=224.3, 3:44) and
---      f_260909_215412_axe_cull_viper_348 (t=348.0, 5:48).  Those are the two
---      frames on which shipped refuses on the clock and armed does not.  The
---      other 14 are byte-for-byte identical armed and shipped (13 past 6:00,
---      1 at 2:25 which BOTH legs refuse), which is what makes the direction
---      claim above an assertion over the corpus rather than a hope.
---   3. A corpus count is a DOMAIN, not a frequency.  How often a real Turbo
---      game puts Axe in a 4-creep wave with no enemy hero in view inside
---      (3:00, 6:00] is a wave question (iterations/queue.json hero-67).
---   4. This lever does NOT touch the branch's other five conjuncts, and in
---      particular not `#hAllyList <= 2` -- a lane-push taunt that should also
---      ask how many allies are standing in the same wave is a separate
---      question with a separate id; one lever at a time.
function X.axe_IsLanePushClockOpen()

	if J.IsModeTurbo() and J.IsSoakCandidate( 'axecallclock' )
	then
		return DotaTime() > X.nQLanePushClockTurbo
	end

	return DotaTime() > X.nQLanePushClockShipped

end


--- The ally-crowd cap on X.ConsiderQ's 带线 firing point, and the turbo-only
--- raising of it.  Two named constants so a test mirrors the NUMBERS off the
--- source instead of re-typing them (the stale-mirror family,
--- tests/test_cast_ring_mirror_discipline.lua).
---
--- ⚠️ BOTH NUMBERS COUNT AXE HIMSELF.  J.GetAlliesNearLoc (jmz_func.lua:474)
--- walks every living team member and keeps the ones inside the radius; the
--- caster is at distance 0 from his own location, so he is always element one.
--- Shipped `<= 2` therefore means "Axe plus at most ONE other ally", and armed
--- `<= 4` means "Axe plus at most THREE" -- i.e. armed still refuses exactly
--- one state, the full five-man stack.  Read the cap as a headcount and it is
--- off by one in both legs.
X.nQLanePushAllyCapShipped = 2
X.nQLanePushAllyCapTurbo   = 4


--- The ally-crowd cap on X.ConsiderQ's 带线 (lane-push) firing point.  Soak
--- candidate `axecallcrowd` (turbo-only, INERT until armed).  STANDALONE: this
--- function holds exactly one J.IsSoakCandidate call and it names only its own
--- id.
---
--- ⭐ THE DEFECT.  The 带线 branch taunts a >= 4 creep lane wave onto Axe so
--- Counter Helix spins it down, and it refuses to do so whenever two or more
--- allies stand within 1600u.  But `#hEnemyList == 0` is a conjunct of the SAME
--- `if`: the state this cap refuses is "a group of my team, standing in a lane
--- wave, with no enemy hero in view" -- which is not a danger, it is a GROUPED
--- PUSH, the one thing docs/PROJECT.md names as paying off MORE in Turbo than
--- in normal mode ("weaker towers, shorter games, grouped pushing pays off
--- more").  The cap is at its most restrictive exactly where the mode's own
--- doctrine wants the wave deleted fastest.
---
--- ⚠️ WHAT THE CAP IS NOT, checked rather than assumed -- the same two counts
--- X.axe_IsLanePushClockOpen's header had to make, and for the same reason:
---   * not a mana policy -- `J.IsAllowedToSpam( bot, nManaCost )` is already a
---     conjunct of this `if`, so a second, headcount-shaped rationer would be
---     rationing twice;
---   * not a safety term -- `#hEnemyList == 0` is already a conjunct, and it is
---     the direct measurement.  Allies do not make standing in a creep wave
---     more dangerous, and they do not reduce Counter Helix's proc rate: the
---     passive triggers on ATTACKS TAKEN, so a taunted wave pays the same
---     whether or not a teammate is beside Axe.
---
--- ⛔ NOT the radius.  The first draft of this lever moved the 1600u that
--- `hAllyList` is built with (hero_axe.lua:426) on the grounds that 1600 is ~5x
--- Berserker's Call's own 315u.  MEASURED FIRST, and the measurement killed it:
--- over the 16 Axe-subject instants in the corpus, shrinking 1600 -> 1200, 900,
--- 800 or 600 moves the answer to `<= 2` on ZERO of them (and 3 of 16 at 400).
--- The radius is true but not load-bearing; the CAP is.  §2.3 of
--- tests/test_axe_q_lane_push_crowd.lua keeps that measurement executable so
--- nobody re-derives the dead lever.
---
--- ARMED: 4, i.e. "everyone except the full five-man stack".  The number is not
--- free -- it is the largest cap that still leaves the branch a refusal to
--- make, and the corpus shows that refusal is occupied rather than theoretical
--- (f_260828_124358_axe_cull_promise, t=1452.8, all five alive inside 1600u).
--- Raising the cap to 5 would delete the conjunct, and whether this branch
--- should carry a crowd cap AT ALL is a second question: conjoining the two
--- would make one wave reading unattributable to either.
---
--- ⚠️ DIRECTION: THIS IS A WIDENING, and it is the first thing a reader needs.
--- Every count that satisfies `<= 2` also satisfies `<= 4`, so armed is a
--- strict SUPERSET of shipped: arming can only ADD 带线 taunts, and can never
--- remove one or move one onto a different target.  A negative wave reading is
--- attributable to "those grouped lane-push taunts were not worth casting" and
--- NEVER to a cast this lever refused.  Gate off (or non-turbo) the function is
--- literally `#hAllyList <= 2`.
---
--- ⚠️ HONEST BOUNDS, four, none of them rhetorical:
---   1. ⛔ END-TO-END DOMAIN IS 0 AND CANNOT BE ANYTHING ELSE TODAY, for the
---      same reason X.axe_IsLanePushClockOpen's is: the branch needs
---      `#laneCreepList >= 4` and the dumped corpus carries NO non-hero units
---      at all (GH #772).  What IS measured is the CONJUNCT-LAYER domain --
---      this cap's own answer on real frames -- which is the half this lever
---      changes.  Quoting the two as one number would be an execution
---      verification out of thin air.
---   2. CONJUNCT-LAYER DOMAIN, stated as the number it is: over the 16
---      Axe-subject instants, shipped admits 11 and armed admits 15, so the
---      lever moves 4 -- f_260909_215412_axe_cull_viper_348 (4 allies),
---      f_260909_215412_axe_cull_cm_415 (3), f_260909_215412_axe_cull_cm_838
---      (4), f_260831_061811_axe_call_tp_channel (4) -- and the 16th,
---      f_260828_124358_axe_cull_promise (5), is refused by BOTH legs.
---   3. ⛔ THE BRANCH-LEVEL DOMAIN IS 0 ON THIS CORPUS AND THE REASON IS
---      SELECTION, NOT RARITY.  `#hEnemyList == 0` holds on exactly 1 of the 16
---      Axe instants (f_260820_043637_axe_ring_alone), and that one already
---      passes shipped -- because these frames were harvested to study Call and
---      Culling Blade DECISIONS, i.e. moments with enemies present.  A corpus
---      of fight instants cannot size a no-enemy lane-push branch, and saying
---      "rare" when the honest word is "absent from this sample" is the error
---      this bound exists to block.  How often a real Turbo game puts 3-5
---      grouped allies in a 4-creep wave with no enemy hero in view is a wave
---      question (iterations/queue.json hero-93).
---   4. ⛔ NOT a bundle with `axecallclock`.  Both levers sit on conjuncts of
---      this same `if`, so arming both in one wave is a bundle read
---      attributable to neither, and neither gate names the other's id (the
---      `pullcad` trap).  The two are not redundant either: of the 4 instants
---      this lever moves, 3 are already past the shipped 6:00 clock, and the
---      4th (axe_cull_viper_348, t=348.0) is refused by the clock whether or
---      not this id is armed.  Section 7 of the test asserts the independence.
function X.axe_IsLanePushCrowdOpen( nAllyCount )

	if J.IsModeTurbo() and J.IsSoakCandidate( 'axecallcrowd' )
	then
		return nAllyCount <= X.nQLanePushAllyCapTurbo
	end

	return nAllyCount <= X.nQLanePushAllyCapShipped

end


--- Whether X.ConsiderQ's 带线 firing point carries an ally-crowd cap AT ALL.
--- Soak candidate `axecallnocap` (turbo-only, INERT until armed).  STANDALONE:
--- this function holds exactly one J.IsSoakCandidate call and it names only its
--- own id.
---
--- ⭐ THE DEFECT, and it is the SECOND question X.axe_IsLanePushCrowdOpen's
--- header wrote down and deliberately did not answer ("whether this branch
--- should carry a crowd cap AT ALL is a second question").  `axecallcrowd`
--- raises the cap from 2 to 4, which is the largest cap that still leaves the
--- conjunct a refusal to make.  The state it keeps refusing is the FULL
--- FIVE-MAN STACK standing in a lane wave with no enemy hero inside 1600u --
--- i.e. the single most unambiguous grouped push the game can present, and the
--- one docs/PROJECT.md names as paying off MORE in Turbo ("weaker towers,
--- shorter games, grouped pushing pays off more").  This id removes the
--- conjunct instead of moving it.
---
--- ⭐ WHY THE CAP IS NOT A COOLDOWN POLICY EITHER -- the one rationale
--- X.axe_IsLanePushCrowdOpen's header did NOT have to rule out, because at cap
--- 4 it still had somewhere to hide.  Berserker's Call costs a real cooldown
--- (AbilityCooldown 18/16/14/12, tests/mock/special_value_shapes.lua; 12s at
--- the rank this file's build has by hero level 7), so spending it on a creep
--- wave seconds before a fight is a genuine cost, and "five allies grouped with
--- no enemy in view" is a plausible pre-contact state.  But the shipped cap
--- does not ration that cooldown, it rations it BACKWARDS: shipped fires this
--- branch at `<= 2` -- Axe alone or with one ally, the state most likely to be
--- jumped and therefore most likely to need Call for a fight -- and refuses it
--- at four allies, the safest state on the board.  A cooldown argument that
--- holds against five allies holds STRICTLY HARDER against one.  Whatever the
--- cap is, it is not protecting the cooldown.
---
--- ⚠️ DIRECTION: THIS IS A WIDENING, and it is a strict superset of BOTH legs
--- it sits above.  Every ally count admitted by `<= 2` or by `<= 4` is admitted
--- here, because armed this conjunct is the constant true.  Arming can only ADD
--- 带线 taunts and can never remove one or move one onto a different target, so
--- a negative wave reading is attributable to "those grouped lane-push taunts
--- were not worth the cooldown" and NEVER to a cast this lever refused.  Gate
--- off (or non-turbo) the whole disjunction at the call site collapses to
--- `X.axe_IsLanePushCrowdOpen( #hAllyList )`, which gate-off is `#hAllyList <=
--- 2`, byte for byte.
---
--- ⚠️ HONEST BOUNDS, five, none of them rhetorical:
---   1. CONJUNCT-LAYER DOMAIN, stated as the number it is: over the 16
---      Axe-subject instants in tests/fixtures/ + tests/frames/, shipped admits
---      11, `axecallcrowd` armed admits 15, and this id armed admits 16.  So
---      this lever moves 5 instants against shipped, and exactly ONE against
---      `axecallcrowd` -- f_260828_124358_axe_cull_promise (t=1452.8, all five
---      allies alive inside 1600u), the frame that frames the whole question.
---   2. ⛔ THAT ONE SEPARATING FRAME SEPARATES THE TWO IDS AT THE CONJUNCT
---      LAYER ONLY, and the reason is on the same `if`: at that instant there
---      is 1 enemy hero inside 1600u, so `#hEnemyList == 0` refuses the branch
---      whatever this conjunct answers.  The corpus therefore contains ZERO
---      frames where this id changes what Axe does, and quoting the "1" as a
---      behaviour difference would be an execution verification out of thin
---      air.  §3.2 of the test pins the enemy count so the claim cannot rot.
---   3. ⛔ THE BRANCH-LEVEL DOMAIN IS 0 ON THIS CORPUS AND THE REASON IS
---      SELECTION, NOT RARITY -- identical to `axecallcrowd`'s bound 3, and it
---      does not get to be counted as new evidence here: `#hEnemyList == 0`
---      holds on exactly 1 of the 16 instants, because these frames were
---      harvested to study Call and Culling Blade DECISIONS, i.e. moments with
---      enemies present.  How often a real Turbo game puts a full five-man
---      stack in a 4-creep wave with no enemy hero in view is a wave question
---      (iterations/queue.json hero-94).
---   4. ⛔ END-TO-END DOMAIN IS 0 AND CANNOT BE ANYTHING ELSE TODAY: the branch
---      also needs `#laneCreepList >= 4`, and the dumped corpus carries no
---      non-hero units at all (GH #772, state.json:CORPUS_HAS_NO_NONHERO_UNITS_20260912).
---   5. ⛔ NOT a bundle with `axecallcrowd`, and the reason is stronger than
---      the usual one-lever-at-a-time: this id DOMINATES it.  Armed, the
---      disjunction short-circuits true before `axecallcrowd`'s cap is ever
---      consulted, so a wave that arms both measures THIS id alone while the
---      verdict table would carry two names.  Also ⛔ not a bundle with
---      `axecallclock` (a third conjunct of the same `if`).  Neither gate names
---      another id -- the `pullcad` trap -- and §7 asserts both directions.
function X.axe_IsLanePushCrowdCapOff()

	if J.IsModeTurbo() and J.IsSoakCandidate( 'axecallnocap' )
	then
		return true
	end

	return false

end


--- Soak candidate `axecallring` (turbo-only, INERT until armed) -- the ANCHOR of
--- X.ConsiderQ's initiation firing point, which is a different question from the
--- IMMUNITY of it (`axecallbkb_ii`, above).
---
--- THE DEFECT.  Berserker's Call is `No Target`: an AoE taunt centred on Axe that
--- takes every enemy hero inside `radius` (315; tests/mock/special_value_shapes.lua
--- carries the KV, and the +85 from special_bonus_unique_axe_2 is already folded
--- into the handle X.ConsiderQ reads).  The shipped initiation branch nevertheless
--- decides whether to cast it by interrogating ONE unit:
---
---     J.IsValidHero( botTarget ) and J.IsInRange( botTarget, bot, nRadius - 90 )
---
--- `botTarget` is J.GetProperTarget -- whoever Axe happens to be committing on.
--- When that one hero stands outside the shrunken 225u ring the whole branch
--- declines, and nothing downstream asks again: the remaining firing points are a
--- channel interrupt, a creep-shove curfew, Roshan, Tormentor and a neutral camp.
--- So a full multi-hero Call is thrown away because the WRONG HERO was the one
--- asked about.
---
--- ⚠️ THIS IS NOT `axecallbkb_ii` RE-STATED, and the two must not be quoted as one
--- sentence.  That id widens WHICH ANSWER the one interrogated unit may give (a
--- spell-immune botTarget stops vetoing).  It leaves the anchor exactly where it
--- is: with botTarget out of the ring, arming it still changes nothing.  This id
--- moves the ANCHOR and leaves every immunity term alone -- the counter below
--- applies the shipped J.CanCastOnNonMagicImmune to each ring member, i.e. the
--- CONSERVATIVE reading, so an immune hero in the ring does not get counted here
--- either.  ⛔ Neither gate names the other's id (the `pullcad` trap: a gate that
--- names a sibling freezes FALSE the day the sibling is promoted, and
--- check_armed_wiring.py still calls it WIRED).  Arming BOTH in one wave is a
--- bundle read and is attributable to neither; section 7 of
--- tests/test_axe_call_ring_anchor.lua asserts the independence.
---
--- WHY IT IS A GATE AND NOT A PLAIN FIX.  It ADDS casts, and this stream ships an
--- action-adding change dark until a wave has sized its domain.  Gate OFF the
--- block below is ABSENT, not re-derived: it is a separate `if` placed AFTER the
--- shipped branch, so with the gate down X.ConsiderQ is byte-for-byte the shipped
--- decision on every frame.
---
--- DIRECTION BY CONSTRUCTION, not by today's corpus.  The shipped branch is
--- evaluated FIRST and is untouched, and this block only ever `return`s a desire
--- where the shipped code fell through.  ⇒ arming can only ADD a Call; it can
--- never remove one and can never move one onto a different instant.  A negative
--- wave read is therefore attributable to "those extra multi-hero Calls were not
--- worth their cooldown", and never to a Call this lever took away.
---
--- THE QUORUM IS 2, AND THAT CHOICE IS THE CONSERVATIVE SIDE.  A quorum of 1
--- would also fire whenever any single castable enemy stands in the ring -- which
--- would make this a superset of the shipped branch and would triple the offline
--- domain (3 further Axe frames hold exactly one in-ring enemy).  It is refused
--- on purpose: a Call spent on ONE hero who is not the one Axe committed on is
--- the marginal case, and the argument this lever stands on -- that the ring and
--- not the anchor is what a no-target AoE is worth -- only bites at >= 2.  The
--- quorum is a named field so the test mirrors the number off the source instead
--- of retyping it (the stale-mirror family).
---
--- WHAT IS DELIBERATELY LEFT ALONE.  One term moves: the anchor.  The 315u
--- radius, the -50 search ring, the -90 anti-whiff margin (kept, and handed to
--- the counter so the number is read off ONE place), the `not J.IsDisabled`
--- veto, J.IsGoingOnSomeone, the creep-shove curfew, Roshan, Tormentor and the
--- neutral-camp branch are untouched.  This is one lever, not a bundle.
---
--- WHAT IS NOT KNOWN.  The domain is UNSIZED and only a wave can size it; what IS
--- measured, on real frames rather than assumed, is in
--- tests/test_axe_call_ring_anchor.lua:
---   * Over the 28 Call-READY Axe hero rows in tests/fixtures/ + tests/frames/,
---     exactly ONE holds >= 2 live enemy heroes inside the 225u ring:
---     tests/frames/f_260828_002127_axe_call_bkb_ring.lua (t=982.1, Call rank 3
---     at cd 0, 319 mana against a 110 cost).  24 hold zero, 3 hold one.
---   * On that frame the ring is Lina at 75.1u and Necrophos at 165.3u, both
---     castable under the SHIPPED reader, while Shadow Shaman -- the enemy Axe is
---     actually hitting, per that frame's own recent_damage (four 19-point Axe
---     attack instances inside the window) -- stands at 276.9u, OUTSIDE the 225u
---     anchor test and INSIDE the 315u taunt.  That is the defect's value column
---     on real state: three heroes in the AoE, and the one the shipped branch
---     asks about is the one that fails it.
---   * J.IsGoingOnSomeone is false on EVERY frame make_fixture.py can produce
---     (the behav dumper's snapshot schema carries no active-mode channel; GH
---     #577 section 5), so section 4 repairs that ONE reader and labels the
---     repair as FRAME ground truth (the recent_damage above), not as agreement
---     with a shipped criterion -- the weaker of the two standings that file
---     distinguishes.  Sizing still needs a wave: iterations/queue.json hero-91.
function X.IsCallRingOn()

	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecallring' )

end


--- How many enemy heroes this Call would taunt AND the shipped readers agree it
--- may be cast at, inside the ring the caller names.
---
--- `nRing` is handed in by the call site so the -90 margin is read off ONE place.
--- Argument order on J.IsInRange is its own ( origin, target, radius ): that puts
--- the CanBeSeen test on the ENEMY, which is the unit whose visibility the count
--- is about.  (The shipped branch writes it the other way round,
--- `J.IsInRange( botTarget, bot, ... )`, which lands CanBeSeen on Axe himself --
--- harmless there only because J.CanCastOnNonMagicImmune( botTarget ) already
--- tested the target's visibility on the same line.)
---
--- A nil list answers 0 -- the RESTRICTIVE default, because a permissive one
--- would make a caller that forgot its argument fire the branch on every frame.
function X.axe_CountCallRingTargets( tEnemies, nRing )

	if tEnemies == nil then return 0 end

	local nCount = 0
	for _, npcEnemy in pairs( tEnemies )
	do
		if J.IsValidHero( npcEnemy )
			and J.IsInRange( bot, npcEnemy, nRing )
			and J.CanCastOnNonMagicImmune( npcEnemy )
			and not J.IsDisabled( npcEnemy )
		then
			nCount = nCount + 1
		end
	end

	return nCount

end


--- How many heroes the ring must hold before `axecallring` fires.  See the
--- header above for why it is 2 and not 1.
X.nCallRingQuorum = 2


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

	-- [axecallring] The ring, not the anchor.  Gate off this whole block is
	-- ABSENT -- it is a separate `if` placed after the shipped branch, so with
	-- the gate down X.ConsiderQ answers exactly what it shipped.  See
	-- X.IsCallRingOn for the defect, the direction argument and the domain.
	if X.IsCallRingOn()
		and J.IsGoingOnSomeone( bot )
	then
		local nRingTargets = X.axe_CountCallRingTargets( nInRangeEnemyList, nRadius - 90 )
		if nRingTargets >= X.nCallRingQuorum
		then
			sCastMotive = 'Q-环'..nRingTargets
			return BOT_ACTION_DESIRE_HIGH, sCastMotive
		end
	end



	--带线时嘲讽小兵攻击自己
	if ( J.IsPushing( bot ) or J.IsDefending( bot ) or J.IsFarming( bot ) )
		and J.IsAllowedToSpam( bot, nManaCost )
		and bot:GetAttackTarget() ~= nil
		-- [axecallclock] gate off this is `DotaTime() > 6 * 60`, byte for byte.
		-- See X.axe_IsLanePushClockOpen -- the only wall clock in this file, and
		-- it stands in front of the Call/Counter-Helix wave clear this file's own
		-- build has at rank 4 by hero level 7.
		and X.axe_IsLanePushClockOpen()
		-- [axecallcrowd] gate off this is `#hAllyList <= 2`, byte for byte.
		-- See X.axe_IsLanePushCrowdOpen -- the cap refuses a GROUPED PUSH, and
		-- `#hEnemyList == 0` below the disjunction is what makes it a push
		-- rather than a fight.  The count includes Axe himself.  (It read "on
		-- the next line" until axecallnocap put a disjunction between them.)
		-- [axecallnocap] the SECOND question: whether this conjunct should exist
		-- at all.  Gate off X.axe_IsLanePushCrowdCapOff() is `false`, so the
		-- whole disjunction is the cap alone, byte for byte.  Armed it
		-- short-circuits true and therefore DOMINATES axecallcrowd -- see that
		-- helper's bound 5; the two must never be armed in one wave.
		and ( X.axe_IsLanePushCrowdOpen( #hAllyList )
				or X.axe_IsLanePushCrowdCapOff() )
		and #hEnemyList == 0
	then
		local laneCreepList = bot:GetNearbyLaneCreeps( nRadius - 50, true )
		-- [glyphany] gate off this is `not laneCreepList[1]:HasModifier(
		-- "modifier_fountain_glyph" )`, byte for byte.  Berserker's Call taunts
		-- the WHOLE ring (>= 4 creeps here) and the veto was interrogating one
		-- of them.  See J.IsGlyphVetoClear in bots/FunLib/jmz_func.lua.
		if #laneCreepList >= 4
			and J.IsGlyphVetoClear( laneCreepList )
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
--- ⭐ THE DOMAIN CAME BACK MEASURED, AND IT NARROWED THIS LEVER -- 2026-09-09.
--- GH #562 (replay-check, `owed_executions.json:hero_domain_scan_2_30_31`, 72 games /
--- 577 replay episodes / 273 of them inside this gate's shard premise) stratified the
--- in-gate episodes by the ONE thing the dominance argument above rests on -- whether
--- another candidate was there to take the cast:
---
---     pure cost    (target lived, ZERO other candidate)  121 episodes  1.68 / game
---     pure benefit (target lived, >= 1 other candidate)   30 episodes  0.42 / game
---     kill-confirm (target died within 5s)               122 episodes  (97 to Axe)
---
--- i.e. cost : benefit ~ 4 : 1, and 81.3% of in-gate episodes had NO alternative at
--- all.  The reading did not find a new defect; it found that the sentence three
--- paragraphs up -- "re-applying is dominated wherever ANOTHER CANDIDATE EXISTS" --
--- was never written into the code.  The veto fired on the premise's antecedent
--- unchecked, so on four in-gate episodes out of five the armed side forfeited a
--- refresh worth `12 - remaining` seconds and bought nothing with it.
---
--- SO THE PREMISE IS NOW A CONJUNCT: X.axe_HasHungerAlternative.  The veto fires only
--- when the SAME list this call site is iterating carries a candidate that is not
--- already hungered and that the site would accept.  This is a NARROWING OF THE ARMED
--- LEG, not a new lever and not a new id: the refusal set shrinks, so the armed
--- accepted set grows toward -- and stays inside -- the shipped one.  Both directional
--- claims above therefore still hold verbatim (armed ⊆ shipped; `armed casts =>
--- shipped casts`), and the corpus frame that used to read as a DECLINE now reads as
--- the shipped cast, which is the 121-episode stratum disappearing.
---
--- ⚠️ ONE OVER-APPROXIMATION, REGISTERED RATHER THAN ARGUED AWAY.  At the 团战 site
--- the alternative test deliberately omits X.axe_IsHungerFightTargetInReach, because
--- that conjunct carries a DIFFERENT soak id (`axebhreach`) and letting this lever's
--- decision depend on another id's armed state is the pullcad trap.  So when both are
--- armed the alternative test can certify a candidate the reach term would refuse,
--- and that residue is exactly the reach ring's +200 band.  The other two sites carry
--- no gated conjunct and are exact (the lane loop's own
--- `GetAttackTarget() == nil` is passed in as fExtra).
---
--- WHAT IS NOT KNOWN.  The BENEFIT half is still not fixture-drivable.  Corpus supply,
--- measured rather than assumed (tests/test_axe_battle_hunger_recast.lua section 2):
--- three Axe-SUBJECT frames carry an enemy holding the real debuff, with 0.2s / 5.4s /
--- 6.5s left, and on two of them that enemy is the ONLY one inside Battle Hunger's
--- cast range -- those two are the cost stratum, and they are what section 3 now pins
--- as a no-op.  The 30 benefit episodes GH #562 located ((game, t) listed in its
--- table) are the frames that would drive the spread; asking for them is queue.json
--- `hero-35`.  Do NOT promote on the (c) argument alone.
function X.axe_IsBattleHungerFresh( hTarget, tCandidates, fExtra )

	local bShipped = not hTarget:HasModifier( 'modifier_axe_battle_hunger_self' )

	if bShipped
		and J.IsModeTurbo() and J.IsSoakCandidate( 'axebhrecast' )
		and not J.HasAghanimsShard( bot )
		and hTarget:HasModifier( 'modifier_axe_battle_hunger' )
		and X.axe_HasHungerAlternative( hTarget, tCandidates, fExtra )
	then
		return false
	end

	return bShipped

end


--- The premise of `axebhrecast` as a predicate: does THIS call site's own candidate
--- list hold somebody else worth the cast?  Carries no soak id of its own on purpose
--- -- it is only ever reached from inside the armed branch of
--- X.axe_IsBattleHungerFresh, so with the gate off it is unreachable and gate-OFF
--- behaviour is byte-for-byte the shipped veto.
---
--- `tCandidates == nil` answers FALSE, i.e. NO VETO.  That is the conservative
--- default in this lever's direction: an unproven alternative must never cost a
--- refresh, and it keeps every one-argument caller (the tests' corpus sweeps) on the
--- shipped answer instead of silently re-baselining them.
---
--- The terms are the site's own acceptance terms, minus anything gated.  `fExtra` is
--- how a site adds its extra unconditional conjunct (the lane loop's
--- `GetAttackTarget() == nil`); it is not a hook for a second gate.
--- The identity test is redundant with the debuff test -- hTarget carries the debuff
--- whenever this is reached -- and is kept because "another" is the whole claim.
function X.axe_HasHungerAlternative( hTarget, tCandidates, fExtra )

	if tCandidates == nil then return false end

	for _, npcOther in pairs( tCandidates )
	do
		if npcOther ~= hTarget
			and J.IsValid( npcOther )
			and not npcOther:HasModifier( 'modifier_axe_battle_hunger' )
			and not npcOther:HasModifier( 'modifier_axe_battle_hunger_self' )
			and J.CanCastOnNonMagicImmune( npcOther )
			and J.CanCastOnTargetAdvanced( npcOther )
			and ( fExtra == nil or fExtra( npcOther ) )
		then
			return true
		end
	end

	return false

end


--- The lane-harass loop's own extra conjunct, lifted to a name so the alternative
--- test at that site is the SAME predicate the site applies rather than a looser
--- restatement of it.  Pure read, no gate.
---
--- ⚠️ THE SITE CALLS IT TOO, and that is deliberate rather than tidiness.  Passing
--- it in as a function VALUE and leaving `npcEnemy:GetAttackTarget() == nil` written
--- out at the site would make this the first function-value alias under bots/BotLib/,
--- and tests/test_hero_export_reachability.py says in its own LIMITS that such an
--- alias defeats its closure ("the fix is here, not in the ceiling").  It caught this
--- on the push gate.  Calling it at the site keeps the census reading the truth
--- without touching the instrument or its ratchet -- and the predicate is then
--- written once, which is the property the fExtra argument wanted in the first place.
--- Gate-free and behaviour-identical: same read, same operator, same answer.
function X.axe_IsHungerHarassIdle( hUnit )

	return hUnit:GetAttackTarget() == nil

end


--- The reach term the 团战 (teamfight) firing point of X.ConsiderW has never
--- had.  Soak candidate `axebhreach` (turbo-only, INERT until armed).  Written
--- 2026-09-08 under OWNER_PRIORITIES P4.4 (i).
---
--- THE DEFECT.  X.ConsiderW builds TWO search rings off one cast range --
---     nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange )
---     nInBonusEnemyList = J.GetAroundEnemyHeroList( nCastRange + 200 )
--- -- and then bids from EIGHT firing points.  SIX of them bound the target to
--- the cast range, by one of the two conventions this function itself writes:
---
---     kill loop     nInRangeEnemyList
---     先手          J.IsInRange( botTarget, bot, nCastRange )
---     lane harass   nInRangeEnemyList
---     retreat       nInRangeEnemyList
---     roshan        J.IsInRange( bot, botTarget, nCastRange )
---     tormentor     J.IsInRange( bot, botTarget, nCastRange )
---
--- The 团战 min-search is the ONE hero-targeting point that iterates the +200
--- ring carrying no distance term at all.  (The jungle pick reads
--- `bot:GetNearbyNeutralCreeps( nCastRange + 100 )` and is unbounded too; it is
--- deliberately NOT touched -- see WHAT IS LEFT ALONE.)
---
--- WHY THIS IS NOT JUST ANOTHER 200-UNIT WALK, and this is the whole lever.
--- The other five hero points are FIRST-MATCH loops: a candidate that fails
--- hands the branch to the next one.  This one is a MIN-SEARCH.  It keeps the
--- single lowest-health enemy in the +200 ring and bids on HIM -- so an
--- out-of-range winner does not merely ADD a walk, it DISPLACES every in-range
--- candidate the same loop already certified legal.  Electing the far weak
--- enemy IS the decision not to cast on the near one, and no later firing point
--- picks the near one up (see NO RELOCATION).  What the engine is then handed is
--- `bot:ActionQueue_UseAbilityOnEntity( abilityW, castWTarget )`, and on an
--- out-of-range target that order is a MOVE order first: a melee Axe walks the
--- gap, toward whichever enemy is closest to dying -- which in a teamfight is
--- the backline he did not decide to dive.  Same family as `lionrreach`
--- (GH #617) / `wkqlane` (GH #621) / `cmlaneband` (GH #630) / `zusjumpland`
--- (GH #634), and NOT the same defect: those four each widen ONE bid.  This one
--- is a selection rule whose search set is wider than its own reach, so the
--- error it makes is a swap, not only a stretch.
---
--- ARMED: a candidate must be inside `nCastRange`.  That bound is not invented
--- here -- it is this function's OWN gate: three firing points spell it
--- `J.IsInRange( ..., nCastRange )` and three more read it off
--- nInRangeEnemyList.  nCastRange is PASSED IN rather than re-read, so the
--- aether-lens term (X.SkillsComplement sets aetherRange = 225 on
--- item_aether_lens, and both of this file's buy lists carry the item) composes
--- exactly as the other six points see it.
---
--- DIRECTION BY CONSTRUCTION, not by today's data.  The armed candidate set is
--- a strict SUBSET of the shipped one and the branch takes a MINIMUM over it:
---   * shipped elects nobody           => armed elects nobody;
---   * shipped's winner is in range    => he is in the armed subset and is
---                                        still its minimum => armed elects the
---                                        SAME hero, byte for byte;
---   * shipped's winner is out of range => armed elects the weakest REACHABLE
---                                        candidate, or nobody.
--- So arming can never add a cast, and can never move one onto a target FURTHER
--- away.  A negative wave read is attributable to "those approaches were worth
--- taking"; it can never mean the lever invented a cast.
---
--- NO RELOCATION, in closed form rather than by inspection -- the `lionrreach`
--- trap, answered.  If the armed subset is empty then NO enemy inside
--- nCastRange passed {J.IsValid, X.axe_IsBattleHungerFresh,
--- J.CanCastOnNonMagicImmune, J.CanCastOnTargetAdvanced}.  The two
--- hero-targeting firing points BELOW this one (lane harass, retreat) iterate
--- nInRangeEnemyList and apply that same four-term filter plus extra conjuncts
--- of their own, so neither can fire on a hero either.  A refused frame is
--- therefore NO HERO CAST, not a cast that moved.  The only bid still reachable
--- below is the jungle pick, whose target is a neutral creep -- a different unit
--- class, not the displaced hero.  Section 5.4 of
--- tests/test_axe_battle_hunger_fight_reach.lua pins that pick UNBOUNDED so a
--- later round cannot read this file as having fixed it.
---
--- WHAT IS DELIBERATELY LEFT ALONE.  One conjunct at ONE site.
---   * The +200 search ring stays.  This lever filters the ring; it does not
---     shrink it.  A future round that wants to argue the ring itself should say
---     so and own it.
---   * The jungle pick's unbounded `nCastRange + 100` neutral read stays: its
---     target is a CREEP, its premise is J.IsFarming, and a walk toward a camp
---     shares none of this branch's cost story.  Section 5 asserts it is still
---     unbounded so a later round cannot read this file as having fixed it.
---     ⭐ SUPERSEDED 2026-09-15 by `axebhcamp`, which is the round this bullet
---     asked for: the jungle pick now elects from a gated in-reach SUBSET of
---     that same ring (X.axe_HungerCampCandidates, below).  The ring itself --
---     `GetNearbyNeutralCreeps( nCastRange + 100 )` -- is still read unbounded,
---     so the sentence above is now true of the QUERY and false of the PICK.
---     §5.4 was rewritten to assert the new shape rather than deleted; this
---     lever's own claims (subset, no relocation, no added hero cast) are
---     untouched, because `axebhcamp` moves no hero-targeting firing point.
---   * `axebhrecast` and `axebhpure` are untouched.  This conjunct sits BESIDE
---     X.axe_IsBattleHungerFresh in the same `if`, each carrying its own id, and
---     the two ids are NEVER conjoined inside one predicate -- that is the
---     pullcad trap, and it is mutation M9 of tools/agent/mutstand_axebhreach.sh.
---     Composition is fine and is what independent conjuncts are for; a
---     dependency written as a code conjunction is not.
---
--- WHAT IS NOT KNOWN, stated precisely because it is NOT "the domain is empty".
--- The domain is UNSIZED, and the corpus cannot size it, because the BRANCH
--- PREMISE and the BAND never co-occur offline.  J.IsInTeamFight( bot, 1200 )
--- wants two nearby allies, and on every one of the 6 corpus frames that puts an
--- enemy hero in the band Axe has at most one; the premise itself holds on 6
--- OTHER frames, and the intersection is ZERO.  Section 1 counts all of that
--- rather than narrating it.  So section 3 drives the ELECTION on the real frame
--- with the premise injected (the geometry, the health, the ranks and the 600
--- cast range are real and untouched), and section 4 drives X.SkillsComplement
--- END TO END with nothing injected but the cooldown on the 6 premise-real
--- frames: the branch really fires on 4 of them, on all 4 the elected enemy is
--- already inside nCastRange, and arming changes the action on none of the 6.
--- That pair is what separates "inert where it should be" from DEAD WIRING; it
--- is NOT a domain size.  Size it on a wave: iterations/queue.json `hero-50`.
--- Do NOT promote on the (c) argument alone.
function X.axe_IsHungerFightTargetInReach( hTarget, nCastRange )

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhreach' ) ) then return true end

	return J.IsInRange( bot, hTarget, nCastRange )

end


--- Which camp creeps may the 打野 bid elect from?
---
--- Soak candidate `axebhcamp` (turbo-only, INERT until armed) -- the LAST
--- unbounded ring in X.ConsiderW, and the one the sibling `axebhreach` header
--- above pinned open on purpose ("a later round that bounded it should say so
--- there").  This is that round; that bullet and §5.4 of
--- tests/test_axe_battle_hunger_fight_reach.lua both now say so.
---
--- THE DEFECT.  X.ConsiderW bids from eight firing points.  Seven bound their
--- target to the cast range the function computed on its own first working
--- line (`nCastRange = abilityW:GetCastRange() + aetherRange`) -- six by the
--- two conventions the function itself writes, and the 团战 min-search by
--- `axebhreach`.  The 打野 pick is the one left:
---
---     local neutralCreepList = bot:GetNearbyNeutralCreeps( nCastRange + 100 )
---     local targetCreep      = J.GetMostHpUnit( neutralCreepList )
---
--- There is no distance term of any kind between that list and
--- `return BOT_ACTION_DESIRE_HIGH, hCastTarget`.
---
--- WHY THE 100 IS NOT THE SIZE OF THE MISTAKE, and this is the whole point.
--- A first-match loop over a ring 100 units too wide costs at most a 100-unit
--- walk.  This is not a first-match loop -- it is a SELECTION RULE, and it
--- selects on the one axis that is anti-correlated with being close: MOST HP.
--- Axe melees the camp he is clearing from ~128 units, so the creeps in the
--- outer band are not the camp he is on, they are the NEXT camp; and the unit
--- J.GetMostHpUnit prefers is exactly the big one (golem / ancient / centaur
--- khan) that a neighbouring box is likelier to hold than the one he already
--- ground down.  So the band member does not merely ADD a walk, it DISPLACES
--- the in-reach creep that the same list already admitted -- the `axebhreach`
--- swap argument, on the branch that sibling declined to touch.
---
--- WHAT THE WALK COSTS.  X.SkillsComplement hands the returned handle to
--- ActionQueue_UseAbilityOnEntity, and a cast order on a unit beyond cast range
--- is a MOVE order first.  The bid is BOT_ACTION_DESIRE_HIGH, so for the length
--- of that walk it outranks the farming mode that put him in the camp; he
--- leaves a camp he was mid-clear on, and arrives inside the aggro radius of a
--- box he did not choose to pull.
---
--- SIZE OF THE BAND, off the KV snapshot rather than guessed.
--- axe_battle_hunger / AbilityCastRange is `600 700 800 900`
--- (tests/mock/special_value_shapes.lua), so the band (nCastRange,
--- nCastRange + 100] is 600->700 at rank 1 and 900->1000 at rank 4 -- and at
--- rank 1 its outer edge is exactly the rank-2 cast range, i.e. the branch
--- already searches at the reach Axe will not have until his next point in W.
---
--- DIRECTION -- three claims that hold, and one residue that is registered
--- rather than argued away.
---   1. SUBSET OF CANDIDATES.  The armed pick is always a member of the list
---      the shipped query returned; this predicate only ever removes entries.
---   2. NEVER FURTHER.  Every surviving entry is inside nCastRange, so the
---      armed pick is never further away than the shipped pick.
---   3. NO-OP EXACTLY WHEN THE SHIPPED PICK IS ALREADY IN REACH.  If the
---      overall max-health unit is inside nCastRange it is still the max of the
---      filtered list, so J.MostHpUnitOf returns the SAME HANDLE -- ties
---      included, because that scan keeps the first `uHp > maxHP` under
---      iteration order and the filter below preserves order (ipairs in, array
---      out).  Gate off, the shipped table is returned unchanged, by identity.
---   4. ⚠️ RESIDUE: ARMING CAN ADD A BID.  Unlike the 团战 site, this branch
---      applies four more conjuncts AFTER the election (J.IsValid,
---      not J.IsRoshan, no `_self` modifier, not J.CanKillTarget), and those
---      are re-evaluated on a DIFFERENT creep.  So a frame where the shipped
---      far pick failed `not J.CanKillTarget` can bid once armed.  That is a
---      real widening of the bid set and it is NOT claimed away: the added bid
---      is a Battle Hunger, inside cast range, on a camp creep Axe cannot just
---      auto-attack down, which is the branch's own stated purpose -- but a
---      wave that reads this lever negative may attribute it here.
---      tests/test_axe_hunger_camp_reach.lua §3.3 drives that case explicitly.
---
--- NO DEPENDENCY WRITTEN AS A CONJUNCTION.  This predicate names `axebhcamp`
--- and nothing else.  `abilanc` lives INSIDE J.GetMostHpUnit, one call below,
--- and composition through a call boundary is not the pullcad trap; conjoining
--- the two ids inside this body would be, and mutation M10 of
--- tools/agent/mutstand_axebhcamp.sh is that mutation.
---
--- WHAT IS NOT KNOWN, and it is a HARDER not-known than `axebhreach`'s.  The
--- domain is UNSIZED and this corpus CANNOT size it, for a structural reason:
--- a fixture carries no neutral units at all (make_fixture.py dumps heroes and
--- structures only), and the opt-in model that synthesizes them from
--- `recent_damage` stands every one of them AT THE SUBJECT'S OWN LOCATION --
--- DISTANCE IS NOT MODELLED (tests/mock/replay_fixture.lua, the declared world
--- assumption).  So on every frame in the repo this predicate answers "in
--- reach" for every creep it is handed, and the offline band count is ZERO BY
--- CONSTRUCTION.  ⛔ That zero is an instrument reading, not a domain: nobody
--- may report it as "the lever is dead" (GH #838's shape).  §2 of the test
--- DRIVES the construction rather than narrating it, and is a one-way
--- tripwire -- the day the dumper carries positioned neutrals it goes red and
--- says so instead of staying green on an expired claim.
--- What the corpus CAN buy is the RING: nCastRange on real Axe frames, off the
--- real ability handle, which is what §1 measures.  ⚠️ A reading about the
--- ring is not a reading about the branch firing.
--- ⛔ NO ONE MAY REPORT A NUMBER OF BIDS THIS LEVER MOVES.  Evidence is
--- requested as iterations/queue.json `hero-92` (zero EC2, archive-only).
--- Do NOT promote on the (c) argument alone.
function X.axe_HungerCampCandidates( tCreepList, nCastRange )

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhcamp' ) ) then return tCreepList end

	if type( tCreepList ) ~= 'table' or type( nCastRange ) ~= 'number' then return tCreepList end

	local tInReach = {}

	for _, hCreep in ipairs( tCreepList )
	do
		if J.IsInRange( bot, hCreep, nCastRange )
		then
			tInReach[#tInReach + 1] = hCreep
		end
	end

	return tInReach

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
				and X.axe_IsBattleHungerFresh( npcEnemy, nInBonusEnemyList )
				and J.CanCastOnNonMagicImmune( npcEnemy )
				and J.CanCastOnTargetAdvanced( npcEnemy )
				and X.axe_IsHungerFightTargetInReach( npcEnemy, nCastRange )
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
				and X.axe_IsHungerHarassIdle( npcEnemy )
				and X.axe_IsBattleHungerFresh( npcEnemy, nInRangeEnemyList, X.axe_IsHungerHarassIdle )
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
				and X.axe_IsBattleHungerFresh( npcEnemy, nInRangeEnemyList )
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

		-- `axebhcamp` filters the ring; it does not shrink the query above.
		local targetCreep = J.GetMostHpUnit( X.axe_HungerCampCandidates( neutralCreepList, nCastRange ) )

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
--- THE DOMAIN IS NARROWER THAN THIS HEADER USED TO SAY, and it is narrower in two
--- independent places.  Both come from GH #366 /
--- tests/test_skill_point_stall_frame.lua: ten heroes at level 17-22 ALL holding
--- thirteen ability points and at most one talent.  Driven against this file's own
--- row in tests/test_focus_talent_reach_wall.lua sections 2/2b:
---   * THE THIRD BAND IS AN EMPTY STRATUM.  This file's build row puts Culling's
---     third point in entry 15 and thirteen points stop at entry 13, so the
---     ability holds rank 2 for the whole game.  The domain is
---     [250,275) at rank 1 and [350,375) at rank 2 -- the [450,475) band written
---     here, in the hero-2 queue row and in cullthresh_domain.py's docstring
---     cannot be occupied.  A wave that budgets for three bands budgets a third of
---     its power on nothing; the scanner itself is safe (it reads rank off the
---     dump and prints `rank_hist`), the expectation is what was wrong.
---   * THE `talent8` TERM CAN NEVER FIRE, so the double-count risk this header
---     names above is not a risk that has to be traded against anything.  It was
---     already dead by tier-pick (one talent per tier, this row takes [7]); it is
---     now dead by reachability as well.  What that buys is a clean statement of
---     what arming does: the armed/shipped difference is an unconditional +25 at
---     BOTH reachable ranks, with no state in which the shipped value could be the
---     larger one.
--- Carry #366's LIMIT with both: one frame, one game, one instant.
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


--- Soak candidate `axecullreach` (turbo-only, INERT until armed) -- written
--- 2026-09-08 under OWNER_PRIORITIES P4.4 (i).  GH issue filed the same round.
---
--- THE DEFECT, and it is a REACH mismatch, not a threshold one -- `cullthresh`
--- above is about HOW LOW the target's health has to be, this one is about HOW
--- FAR AWAY it may stand.  X.ConsiderR builds TWO enemy lists:
---
---     local nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange )        -- 175
---     local nInBonusEnemyList = J.GetAroundEnemyHeroList( nCastRange + 200 )  -- 375
---
--- and its one firing loop reads the SECOND, with no distance term anywhere in
--- the loop body.  The first list was DEAD -- computed every frame and never
--- read -- until this lever; that is the tell, and it is the same shape the Lion
--- round gated as `lionrreach` (GH #617).  `nCastRange` is measured, not assumed:
--- `abilityR:GetCastRange()` answers 175 on all three real frames in
--- tests/test_axe_cull_reach.lua, so the loop selects targets up to 114% FARTHER
--- than the ability can reach.
---
--- EVERY OTHER REACH IN THIS FILE IS TIGHTER THAN ITS RAW VALUE, which is why
--- the +200 reads as an oversight rather than a policy: X.ConsiderQ's channel
--- interrupt uses `nRadius - 50`, its initiation branch `nRadius - 90`, its
--- lane-taunt `nRadius - 50` and its neutral-farm branch `nRadius - 50`.  This
--- loop is the only place in hero_axe.lua that ADDS.
---
--- WHY IT COSTS SOMETHING, and the mechanism is DOMINANCE, not the walk itself.
--- X.ConsiderR is the FIRST arm of X.SkillsComplement and that arm `return`s
--- unconditionally once its desire clears 0.  So for every frame a sub-threshold
--- enemy sits in the (175, 375] band, the bot queues a Culling Blade it cannot
--- yet reach AND never asks X.ConsiderQ or X.ConsiderW at all.  Berserker's
--- Call's radius is 315 -- most of the band is INSIDE it -- so the suppressed
--- question is precisely "should I taunt the target I am walking at".  On the
--- real frame tests/frames/f_260828_002127_axe_call_bkb_ring.lua (t=982.1) all
--- three living enemies stand at 75.1u / 165.3u / 276.9u, Call is rank 3 with
--- cooldown 0 and 319 mana against a 110 cost, and the shipped tree spends the
--- frame ordering a Culling Blade at the one 101.9u OUT of reach.
---
--- WHY IT IS A GATE, and the direction is a property of the CODE.  Armed, the
--- loop reads a list built by the SAME helper with a SMALLER radius, so the
--- armed pool is a subset of the shipped one and this lever can only ever
--- DELETE a Culling order, never add one (asserted on real frames, not argued).
--- Gate OFF, X.CullTargetPool returns nInBonusEnemyList and the branch is the
--- shipped one byte for byte.
---
--- THE HERO-LEVEL CONSEQUENCE IS NOT A NARROWING, and it is stated rather than
--- hidden: a frame the armed loop declines falls through to X.ConsiderQ and
--- X.ConsiderW, which may then fire.  That is the POINT of the lever, and it is
--- also why "armed Axe casts fewer spells" is NOT a prediction of it.  The
--- fixture corpus cannot show that half -- X.ConsiderQ's mode predicates
--- (J.IsGoingOnSomeone / IsPushing / IsFarming) are structurally false in the
--- fixture world, so all three frames answer 0 there whatever this gate does.
--- tests/test_axe_cull_reach.lua asserts that limit instead of papering it.
---
--- ⛔ THIS HELPER NAMES EXACTLY ONE ID.  It must never be conjoined with
--- `cullthresh` or `axecull`: a gate naming a sibling freezes FALSE the day the
--- sibling is promoted (the `pullcad` trap) and check_armed_wiring.py still
--- calls it WIRED.  The two levers are orthogonal (threshold vs reach) and a
--- wave arming both buys their composite, not either.
function X.IsCullReachOn()

	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecullreach' )

end


--- The pool X.ConsiderR's execute loop selects from.  Armed: only enemies the
--- ability can actually reach this frame.  Unarmed: the shipped bonus ring.
function X.CullTargetPool( tInRangeEnemyList, tInBonusEnemyList )

	if X.IsCullReachOn()
	then
		return tInRangeEnemyList
	end

	return tInBonusEnemyList

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


--- Blade Mail's Damage Return share, as a FRACTION.  RECORDED KV read, and the
--- word RECORDED is load bearing: there is no in-repo cross-check for it,
--- because tests/mock/special_value_shapes.lua snapshots HERO ability KV only
--- and `item_blade_mail` is not in this tree at all.  Read 2026-09-15 from the
--- d2vpkr mirror (dota/scripts/npc/items.txt, "item_blade_mail"):
---     "duration" "5.5"   "passive_reflection_constant" "10"
---     "passive_reflection_pct" "15"   "active_reflection_pct" "85"
--- `modifier_item_blade_mail_reflect` is the ACTIVE modifier -- the 5.5s one --
--- so 85 is the share that applies on every frame the guard below can see it.
--- A LIVE read (the enemy's own item handle -> GetSpecialValueInt) is NOT
--- attempted on purpose: the fixture loader hands back item handles with no KV
--- installed, so such a read answers 0 offline and its fallback would be the
--- only path anything ever drove.  A constant that is watched beats a live read
--- that is not.  Section 6 of tests/test_axe_cull_blade_mail.lua pins this
--- literal against the KV line quoted above.
local nCullReflectShare = 0.85


--- Soak candidate `axecullbm` (turbo-only, INERT until armed).  GH #833.
---
--- ⛔ THIS HELPER NAMES EXACTLY ONE ID.  It must never be conjoined with
--- `cullthresh`, `axecull` or `axecullreach`: a gate naming a sibling freezes
--- FALSE the day the sibling is promoted (the `pullcad` trap) and
--- check_armed_wiring.py still calls it WIRED.  Section 6 asserts the single
--- id from the source.
function X.IsCullReflectOn()

	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecullbm' )

end


--- Would Culling this target's Damage Return kill Axe?  The last conjunct of
--- X.ConsiderR's execute loop.  Unarmed it returns false on every frame, so the
--- loop is byte-for-byte the shipped one until somebody arms `axecullbm`.
---
--- THE RULING THIS RESTS ON, BOUGHT 2026-09-15 AND NOT ASSUMED.  GH #833 filed
--- the gap -- the execute loop asks seven vetoes and none of them is Blade Mail,
--- while hero_windrunner.lua and hero_primal_beast.lua both ask it -- but
--- refused to call it a defect, because it hangs on whether the kill below the
--- threshold is a reflectable damage instance, and it said that question could
--- not be settled offline.  ⭐ IT DISSOLVES RATHER THAN RESOLVING: there is no
--- kill-threshold branch to ask about.  `axe_culling_blade` carries no
--- kill_threshold key at all -- not in the live KV (d2vpkr
--- dota/scripts/npc/heroes/npc_dota_hero_axe.txt, read 2026-09-15: a grep for
--- `kill` and for `threshold` over the whole hero file returns nothing) and not
--- in this tree's own snapshot (tests/mock/special_value_shapes.lua
--- ['axe_culling_blade'] holds AbilityCastPoint / AbilityCastRange /
--- AbilityCooldown / AbilityManaCost / armor_bonus / armor_per_stack /
--- charge_speed / damage / speed_aoe / speed_bonus / speed_duration and nothing
--- else).  What the ability has is `damage` 275/375/475 at
--- `AbilityUnitDamageType DAMAGE_TYPE_PURE`; the threshold mechanic was folded
--- into that damage, which is what this file's own talent8 note has said since
--- 2026-08-27 and what `cullthresh` exists to read.  So X.ConsiderR's health
--- test is a LETHALITY PREDICATE OVER A PURE DAMAGE INSTANCE, not a
--- kill-threshold branch, and an ordinary pure damage instance is reflected.
--- ⇒ condition (c) holds, and it holds for a reason two independent sources
--- agree on.
---
--- ⭐⭐ AND THE SIBLING PATTERN IS THE WRONG FIX HERE, which is the sharper half.
--- The three block/reflect vetoes already in X.HasSpecialModifier
--- (modifier_antimage_spell_shield, modifier_item_lotus_orb_active,
--- modifier_item_sphere_target) all stop the cast from killing anything: the
--- spell is eaten and the 80s cooldown buys nothing, so refusing is free.  Blade
--- Mail is NOT that family -- the cull still lands and the target still dies;
--- what Axe pays is health.  Copying windrunner's and primal_beast's blanket
--- `not HasModifier('modifier_item_blade_mail_reflect')` into this loop would
--- throw away a certain hero kill every time an enemy had popped the item, and
--- those two call sites are ordinary damage and initiation rather than an
--- execution, so their line does not transfer.  This lever therefore vetoes
--- ONLY the frames where the return kills Axe.
---
--- WHAT ARMED DOES, and why THIS bound rather than a bigger one.  The one thing
--- the KV cannot settle is the MAGNITUDE: Damage Return is 85% of damage taken,
--- and whether a lethal blow's excess counts as taken is a C++ question no
--- offline stand can answer.  So the return lies somewhere in
---     [ 0.85 * target health , 0.85 * the damage instance ]
--- and the LOWER end is true under BOTH readings.  The guard uses the lower end
--- -- `bot:GetHealth() <= 0.85 * npcEnemy:GetHealth()` -- so it fires only where
--- Axe dies whichever reading is right, and the unresolved mechanism never
--- leaks into the lever.  ⚠️ The price of that choice is stated rather than
--- hidden: under the damage-instance reading there are further frames where Axe
--- also dies (return up to 0.85 * nKillDamage, i.e. up to 403 at rank 3) and
--- this lever deliberately leaves every one of them alone until somebody buys
--- the mechanism.  It is the narrow half of the defect on purpose.
---
--- ⛔ DIRECTION.  Armed adds a conjunct to a loop that already has seven, so the
--- armed target set is a subset of the shipped one and this lever can only ever
--- DELETE a Culling order, never add one.  A negative wave reads "the deleted
--- culls were worth more than Axe's life" and NEVER "N reflects were survived":
--- no offline stand, and no counter, can price a death that did not happen.
--- Direction is guaranteed by SHAPE, not by today's numbers.
---
--- ⚠️ HONEST BOUNDS, four:
---   1. THE DECISION DOMAIN ON THIS CORPUS IS ZERO, measured this round and not
---      inherited: 142 frames / 1420 hero rows, 23 rows holding blade_mail, 3
---      rows carrying an ACTIVE modifier_item_blade_mail_reflect in 2 files, and
---      NOT ONE of them below a cull threshold.  Section 2 drives that census.
---      ⭐ What the corpus does carry, and what GH #833's own scan missed by
---      looking only in tests/fixtures/, is a real frame with BOTH operands:
---      tests/frames/f_260831_061811_axe_call_tp_channel.lua t=1209.9 has Axe
---      (rank-2 Culling, cooldown 0) and a Bristleback with an active reflect
---      190.2u away -- INSIDE the shipped 375 pool, one conjunct short of this
---      guard.  The supply is real and the instrument reads it; the frequency is
---      not measured here and no number is claimed for it (queue.json hero-89).
---   2. THE 0.85 IS A RECORDED KV READ with no in-repo cross-check -- see
---      nCullReflectShare above.  Do not quote it as verified.
---   3. THE RETURN IS ASSUMED TO REACH AXE UNREDUCED.  If the engine applies a
---      resistance to it, the guard can veto a cull Axe would have survived.
---      That error is in the DELETE direction, which bound 1's shape already
---      covers, and it cannot make the guard miss a death.
---   4. "THE ORDER IS DELETED" IS NOT "AXE LIVES".  A declined frame falls
---      through to X.ConsiderQ and X.ConsiderW, which may fire; and the fixture
---      world answers 0 for those (their mode predicates are structurally
---      false, tests/test_axe_cull_reach.lua section 9).  "Armed Axe casts
---      fewer spells" is NOT a prediction of this lever.
function X.IsCullReflectLethal( npcEnemy )

	if not X.IsCullReflectOn()
	then
		return false
	end

	if npcEnemy == nil or not npcEnemy:HasModifier( 'modifier_item_blade_mail_reflect' )
	then
		return false
	end

	local nSelfHealth = bot:GetHealth()
	local nTargetHealth = npcEnemy:GetHealth()
	if type( nSelfHealth ) ~= 'number' or type( nTargetHealth ) ~= 'number'
	then
		return false
	end

	return nSelfHealth <= nCullReflectShare * nTargetHealth

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
	-- The pool is chosen by X.CullTargetPool: the shipped bonus ring (nCastRange
	-- + 200) while `axecullreach` is unarmed, and the ability's real reach
	-- (nCastRange) once it is armed.  Read that helper's header for the fact,
	-- the direction guarantee, and the hero-level consequence.
	for _, npcEnemy in pairs( X.CullTargetPool( nInRangeEnemyList, nInBonusEnemyList ) )
	do
		if J.IsValidHero( npcEnemy )
			and npcEnemy:CanBeSeen()
			and npcEnemy:GetHealth() + npcEnemy:GetHealthRegen() * 0.8 < nKillDamage
			and not J.IsHaveAegis( npcEnemy )
			and not npcEnemy:IsInvulnerable()
			and ( not npcEnemy:IsMagicImmune() or X.IsCullPierceOn() ) --V BUG (see X.IsCullPierceOn)
			and not X.HasSpecialModifier( npcEnemy )
			and not X.IsKillBotAntiMage( npcEnemy )
			-- soak candidate `axecullbm` -- see X.IsCullReflectLethal above.  It
			-- returns false on every frame while unarmed, so this conjunct is a
			-- no-op until somebody arms it.  It is placed LAST so the shipped
			-- conjuncts keep their order and their short-circuit cost.
			and not X.IsCullReflectLethal( npcEnemy )
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
