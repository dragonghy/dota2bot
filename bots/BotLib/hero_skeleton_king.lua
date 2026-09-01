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
--     skeleton_king_INNATE_vampiric_spirit -- 33 of 33 -- and the feed's
--     skeleton_king_vampiric_spirit appears on 0.  Lion is identical
--     (lion_innate_to_hell_and_back 23/23 vs the feed's lion_to_hell_and_back 0).
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
-- section 2 of tests/test_wk_fact_anchor.lua shows is a level-20 test.  It used
-- to say the GH #84 census read that on 0 of 210 turbo hero-slots, i.e. never;
-- CORRECTED 2026-08-27 -- that zero was the 10-minute batch cap, and this hero
-- is one of the three focus heroes the first post-cap frame catches above 20
-- (level 26; GH #235).  The bypass IS live from level 20 on.  (It is NOT a
-- defect, checked 2026-08-23: the talent at that slot is "+5 Bone Guard
-- Skeletons Spawned" over a base min_skeleton_spawn of 0, so with it trained a
-- release from an empty bank still fields five skeletons and "release regardless
-- of the bank" is the right rule.  tests/test_wk_bone_guard_talent_bypass.lua
-- section 1.)
--
-- BOUNDED 2026-08-27 (hero, fixture talent census): "the bypass IS live from
-- level 20 on" is an argument from the game's KV plus a level reading, and that
-- is ALL it can ever be here -- no frame this repo holds can confirm the bypass
-- fires, and none ever will while sTalentList[6] is a `special_bonus_unique_*`
-- row.  Across 960 hero-frames in tests/fixtures/ there are 67 talent sightings
-- and every one is a GENERIC row; hero-unique rows appear zero times, on any
-- hero, at any level -- including a level-19 frame holding three trained
-- talents.  So a corpus read of talent6:IsTrained() can only come back zero
-- whether or not it is trained, and the zero is not evidence.
--
-- DECIDED 2026-08-27, later the same day, on the first post-cap frame (GH #235,
-- still parked in iterations/pending/): the fork left open above -- dumper drops
-- unique talents, OR the bots never train them -- comes down on the DUMPER.  Ten
-- hero-slots at levels 22-27, this hero among them at 26, must have spent 36
-- talent points between them by the shipped level-up queue; the frame shows 8,
-- all generic.  Three heroes at levels 24-25 show none at all, which "the bots
-- only take generic rows" cannot produce -- a generic pick is a visible row.
-- Consequence for the block above and for the four other TALENTPRICE rounds:
-- the rows they priced ARE rows the bots take; what no frame can do is confirm
-- which.  tests/test_lategame_talent_visibility.lua.
-- tests/test_fixture_talent_blindness.lua, tools/agent/fixture_talent_census.py.
-- So in turbo every early
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
                                    -- (33/33 frames); the feed's spelling is on 0
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
  [2] special_bonus_unique_wraith_king_facet_1    blast_dot_duration +2  (NOT the
      slow duration -- that half of what the KV lists is DEAD, settled below and
      pinned by tests/mock/talent_slots.lua + tests/mock/special_value_shapes.lua.
      The surviving half is the whole of X.wk_GetBlastKillDamage's t10 arithmetic,
      so a reader sent to the dead half is sent away from the only live one.)
  [3] special_bonus_unique_wraith_king_11         +s Wraithfire Blast stun dur.
  [4] special_bonus_hp_300                        +300 health
  [5] special_bonus_attack_speed_50               +50 attack speed
  [6] special_bonus_unique_wraith_king_facet_3    + Bone Guard skeletons spawned
  [7] special_bonus_unique_wraith_king_10         -s Mortal Strike cooldown
  [8] special_bonus_unique_wraith_king_4          Reincarnation casts Wraithfire

tTalentTreeList above therefore resolves to [2] at t10, [4] at t15, [6] at t20 and
[7] at t25 ({10,0} takes the even/right index, {0,10} the odd/left one -- see
aba_skill.lua:135).  All four picks are taken in turbo.  This used to read "only
the t10 and t15 picks can ever be taken in turbo: the level census behind GH #84
read level >= 20 on 0 of 210 hero-slots, high-water 19".  CORRECTED 2026-08-27:
that zero was the batch harness's 10-minute economy cap, not turbo.  Owner
priority P3 (GH #108) removed the cap and the first frame past it has Wraith King
himself at level 26 in a 24.9-minute naturally-ended game (GH #235).

THE FACET BLOCKER, SETTLED 2026-08-27 -- IT WAS NEVER A BLOCKER
---------------------------------------------------------------
This block used to end "both of his t20/t25 alternatives at [2] and [6] are
FACET rows, and nothing in this repo reads which facet the game rolled -- settle
that before pricing the pair".  Settled, and with a stronger answer than the
question asked for.  tools/agent/facet_census.py reads the `Facets` block out of
the same npc_heroes.txt this project already takes slot order from:

  * ROSTER-WIDE, 0 of 339 facet entries name a `special_bonus_*` row or an
    AbilityIndex inside the talent run (10..17).  A facet block carries Icon /
    Color / GradientID / Deprecated and, at most, an `Abilities` sub-block that
    GRANTS an ability.  No facet can move a talent slot for ANY hero, so a
    t20/t25 price is never an argument about a row the game might not ship --
    for Wraith King or for the other four.
  * WRAITH KING has exactly two facet entries and BOTH read `"Deprecated" "true"`,
    i.e. neither can be rolled.  So do all of Axe's (2), Zeus's (2), Lion's (2)
    and Crystal Maiden's (4): the focus five have ZERO live facets between them.
  * The two names are not decoration.  `skeleton_king_facet_bone_guard` granted
    `skeleton_king_bone_guard` at AbilityIndex 1 -- which is WHY Bone Guard is a
    plain "Ability2" on this hero today.  `skeleton_king_facet_cursed_blade`
    granted `skeleton_king_spectral_blade` -- which is the MECHANISM behind the
    fact recorded at abilityW below as an observation only ("a name that exists
    nowhere in the game's ability set"): the only thing that ever granted it is
    deprecated.  The `_facet_1` / `_facet_3` in the talent names is vestige from
    that era, not a live condition.
  * CONSEQUENCE FOR THE PRICE: half of what the KV says [2] and [6] do lands on
    `skeleton_king_spectral_blade` (cursed_damage_pct +15 and curse_cooldown -25%)
    and is therefore DEAD.  What survives is exactly `blast_dot_duration +2` for
    [2] and `min_skeleton_spawn +5` for [6] -- price those halves and nothing else.

Two things that are NOT proved here, kept apart because conflating them is how
this would go wrong: (i) a facet can still gate a talent's VALUE through
`required_facet` inside AbilityValues -- this hero has one such key
(reincarnation/clear_curse, required_facet skeleton_king_facet_cursed_blade,
i.e. also dead) but that is special_value_key_census.py's ground; (ii) "facets
are dead everywhere now" is FALSE -- 32 entries across 12 heroes are live, and
three of them (Lich, Tidehunter, Witch Doctor) sit in this project's candidate
hero pool, so the day one of those joins the focus five its talent pricing has
to ask this question again.  tests/test_wk_facet_settlement.lua and
tests/mock/hero_facets.lua.

⚠️ ONE SOURCE ONLY, AND THE OBVIOUS SECOND OPINION IS A TRAP.  Valve's
datafeed/herodata endpoint answers `facets: []` and `facet_abilities: []` for
EVERY hero queried (7 of 7 on 2026-08-27, this hero and Bristleback included) --
and Bristleback demonstrably has facet machinery in the KV.  Reading WK's empty
array there as "he has no facets" would have produced the right conclusion for
the wrong reason, and the same read would have "proved" it for heroes where it
is false.  The KV is the source; the feed is not a second opinion about facets.

THE PRICE, 2026-08-27 -- BOTH ROWS STAY (t20 [6], t25 [7]), argued not assumed
------------------------------------------------------------------------------
t20 KEEPS [6] on the REACHABILITY ruler, and it is the strongest case in the
focus five for keeping a row: [6] is the ONLY talent in this hero's tree that
the shipped decision layer reads.  `talent6:IsTrained()` is the OR-bypass on
both branches of X.ConsiderW, and what it bypasses is the bank threshold this
file's own GH #17 block argues is close to unreachable (cap 8 by hero level 7,
on the hero the batch reads at 15 last hits and 0.6 kills a game).  Taking [6]
turns Bone Guard from "fires when a bank he struggles to fill is full" into
"fires on its flat 42s cooldown with at least five skeletons guaranteed"
(min_skeleton_spawn 0 -> 5).  The alternative [5] is `special_bonus_attack_speed_50`,
a pure stat block with no decision-layer contact at all -- and moving the row to
it would FREEZE `talent6:IsTrained()` false forever, killing the only place a
talent changes a command in this file.  That is the Lion GH #166 hazard and the
one Zeus's t25 round refused for the same reason; here it would also throw away
the fix, not just the wiring.

t25 KEEPS [7] (`..._wraith_king_10`, Mortal Strike AbilityCooldown 5 -> 3) over
[8] (`..._wraith_king_4`, Reincarnation casts Wraithfire Blast instead of the
slow).  Neither is read by any decision layer here and neither can create a
stale reading -- [7] folds into an AbilityCooldown nothing in this file reads,
[8] into `reincarnation/trigger_wraithfire_blast`, a key with no reader in the
repo -- so unlike t20 this is a pure combat-power question and size decides it.
Three things decide it the same way:
  * QUANTIZATION.  [7] is a RATE: +66.7% crit frequency (crit_mult 280% at rank
    4, and the shipped row maxes Mortal Strike by hero level 8), paid on every
    attack for the rest of the game.  [8] is an EVENT: it needs Wraith King to
    die with enemies inside 900 and Reincarnation off its rank-3 cooldown (KV
    120; the frames read 110 -- MEASURED (4) below).  t25 is reached in the last
    minutes of a turbo game, and that window is now measured rather than read
    off one frame: mean 208s over 49 games.  [8]'s expected number of payouts in
    it is 0.408 -- "at or below ONE, and can easily be zero" was the right
    shape, and the measurement lands far below one -- while [7] pays out on
    every swing in the same window.
  * NET, NOT GROSS.  [8] does not ADD its effect, it REPLACES one: the shipped
    Reincarnation already slows everything within slow_radius 600 by -75% move
    and -75 attack for 4s.  What [8] buys is the DIFFERENCE between that and a
    rank-4 blast (1.6s stun, 140 + 2s x 80 dot, -20% slow, 900 radius) -- and
    reincarnate_time is 3, so the 1.6s stun has expired 1.4s BEFORE he is back
    on his feet, whereas the 4s slow it replaces still has a second left at that
    instant.  A stun that ends while its owner is still un-attackable is worth
    less to a bot than the chase-denial it displaced.
  * THE BUILD SPENDS ON [7]'S AXIS.  This is a pos_1/pos_3 right-click hero
    whose only damage ability IS Mortal Strike; the crit compounds with every
    damage and attack-speed item in sRoleItemsBuyList.  This is the half of
    Axe's t20 argument that came out the OTHER way there (his role lists buy no
    attack items, so his +attack-damage row did not compound); the ruler is the
    same, the hero is not.
MEASURED, 2026-08-30 -- the corpus question this paragraph used to owe came back
------------------------------------------------------------------------------
GH #328, from replay-check's iterations/reports/replay-check/20260830T071054Z.md
and its detector tools/batch_test/behavioral/wk_reincarn_trigger_domain.py, over
the W17 + W17-R archives: 71 of 72 WK games scanned wide, 8 frame-by-frame, 261
trigger episodes, carrier denominator 96 WK hero-games.  It replaces the HONEST
BOUNDS paragraph that stood here, four of whose facts were wrong; the verdict
they hedged is now the measured one.  What each correction does to the price:

  (1) "no frame in this repo shows a Wraith King at 25" is RETIRED.  He reaches
      20 in 96/96 hero-games and 25 in 60/96 (62.5%); the frame-by-frame subset
      reads 49/71 with a high-water of 30.  The row is played, not theoretical.
  (2) The window is no longer inferred from ONE post-cap game.  n=49: mean 208s
      (3.5 min), min 32s, max 453s.  GH #235's game (level 26 at 23:02 of a
      24.9-minute game) sits INSIDE that distribution; it was not an outlier.
  (3) The three conditions in QUANTIZATION are not equally scarce, and the old
      ordering priced the wrong one.  At a trigger, P(>=1 enemy inside 900) is
      95.0% over the whole corpus and 85.0% in the >=25 stratum, so "enemies
      inside 900" does almost no work.  The scarce condition is THE TRIGGER
      ITSELF: of 49 games that reach 25, thirty never trigger again after 25,
      eighteen trigger once, one twice.  Conclusion unchanged, reason re-weighted.
  (4) The rank-3 cooldown is 120 in the KV, but the frames read 109-110 (rank 1
      179, rank 2 149-150; n=3).  One parameter explains it exactly and it is
      already in this repo: reincarnation/AbilityCooldown carries a
      `special_bonus_scepter` of -10, and item_ultimate_scepter is in BOTH of
      this hero's buy rows, so the Wraith King who is alive at 25 is the one who
      has it.  120 - 10 = 110.  That is an EXPLANATION, not a confirmation: n=3,
      and no frame here proves the scepter was owned.  Nothing below leans on it
      except the ceiling in (6), which uses the SMALLER number and therefore
      errs in [8]'s favour.
  (5) THE PRICE, RECOMPUTED.  [8] gross = 0.408 triggers x 0.650 extra enemies
      that the 900 ring catches and the 600 one does not (>=25 stratum means
      1.900 against 1.250) = 0.265 extra enemies touched per level-25 game, and
      that is GROSS -- the NET, NOT GROSS bullet above still has to come off it.
      [7] over the same window = 208/3 - 208/5 = +27.7 crit opportunities at
      full attack uptime, +27.7f at uptime f.  Break-even is 0.650 x T = 27.7f,
      i.e. T = 42.6 triggers per game at f=1 and still T = 10.7 at a pessimistic
      f=0.25, against a measured T = 0.408.
  (6) AND [8] CANNOT REACH BREAK-EVEN, which is a stronger statement than losing
      to it.  At a 110s rank-3 cooldown the mean 208s window holds at most
      floor(208/110)+1 = 2 triggers, and the longest window in the corpus, 453s,
      at most 5.  The corpus maximum observed is exactly 2.  Break-even needs
      ~43 (~11 at f=0.25).  The re-price this paragraph used to invite -- "if
      that number turns out high, [8]'s case improves" -- is closed by a
      ceiling, not by a sample size.
  (7) One prediction registered against this axis came out FALSE, recorded as
      such: "the radius advantage is on paper only".  Over the whole corpus
      mean(900) - mean(600) = 0.789 enemies.  The radius advantage is REAL.  It
      is small, and what kills [8] is the trigger rate, not the ring.

LIMITS.  (5) compares EVENTS, not damage: "extra enemies inside a 1.6s stun that
has expired before he is back on his feet" and "extra 280% crits on a hero whose
whole item row amplifies right-clicks" are not the same unit, and nothing in the
corpus converts them per frame.  What survives the mismatch is the two orders of
magnitude and the sign, both of which run against [8] on its GROSS number,
before the deduction the NET bullet owes it.  Nothing here is gated, so both
rows are live in every turbo game that reaches the level; keeping them is a
decision, not an omission.  tests/test_wk_t25_reincarn_pricing.lua holds this
arithmetic to the KV and to the shipped row, and goes red if a constant moves
without the row moving with it.

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
-- MECHANISM found 2026-08-27: the name is real in npc_heroes.txt, but the only
-- thing that ever granted it is the facet `skeleton_king_facet_cursed_blade`,
-- and that facet reads "Deprecated" "true" -- so it is granted in no game.  See
-- the facet settlement in the block above; this upgrades a recorded observation
-- to a cause, and it is why no patch note is going to bring the name back on its
-- own.
-- Seeding it with the real name leaves that fallback in place and is a no-op for
-- every read of abilityW (the fallback re-fetches the same handle).
local abilityW = bot:GetAbilityByName('skeleton_king_bone_guard')
local abilityR = bot:GetAbilityByName('skeleton_king_reincarnation')
-- talent6 is sTalentList[6] = the t20 slot (aba_skill.lua:140).  Both places it is
-- read below are OR-bypasses.  This used to say they contribute nothing "in turbo
-- -- where level 20 does not happen"; CORRECTED 2026-08-27 (GH #235): level 20
-- does happen, this hero reaches 26 in the first frame taken past the removed
-- batch cap, so from level 20 the bypasses are live and the sibling stack test is
-- no longer the whole condition.  What they mean now that they ARE live: index 6
-- is "+5 Bone Guard Skeletons Spawned", a
-- flat floor, so the bypass buys "release even on an empty bank" and that is
-- coherent, not a bug.  (The KV gives that talent a second effect,
-- spectral_blade/curse_cooldown -25%, and it is DEAD -- spectral_blade is granted
-- only by a deprecated facet.  The flat floor is the whole of what slot 6 buys;
-- see the facet settlement above.  Slot 6 is also facet-INVARIANT: no facet block
-- in the game's roster names a talent row, so this handle binds the same talent in
-- every game.)  One residual is registered rather than settled -- if the
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

--- [wkqdmg] gated (turbo + soak candidate): what the HERO kill-confirm in
--- X.ConsiderQ is allowed to claim Hellfire Blast will do.
---
--- THE SHIPPED CLAIM AND WHY IT IS ONE.  The kill check below reads
--- `nDamage * 1.68` off a hardcode that is neither honest number (the block on
--- X.ConsiderQ's own nDamage line has the arithmetic): 168/235/302/370 CLAIMED
--- magical damage against an impact of 80/100/120/140 and an impact-plus-whole-dot
--- of 120/180/240/300.  Read off the handle instead, the same two numbers come
--- from `damage` and `blast_dot_damage x blast_dot_duration`, and the engine folds
--- a trained talent into them (GH #228) -- which the hardcode structurally cannot
--- see: the t10 pick doubles blast_dot_duration, so the honest read is rank- AND
--- talent-dependent while the hardcode is neither.
---
--- THE DOMAIN, and it is not what this note said before GH #311.  Because
--- `math.min` only ever withdraws, the armed side differs from shipped exactly
--- where the honest read is SMALLER, and joined to the shipped upgrade row that is
--- hero level <= 12 -- Q's second point is row entry 12 of tAllAbilityBuildList,
--- which J.Skill.GetSkillList lands at hero level 13 (levels 10/15/20/25 are
--- talent slots and spend no ability point).  Hero 2-9: narrows 168 -> 120.  Hero
--- 10-12: the t10 talent lifts the honest read to 160, so it narrows by 8, NOT by
--- more.  Hero 13+: Q is rank 2, the honest read overtakes shipped (260 > 235.2)
--- and min returns shipped -- this lever is a byte-for-byte no-op there.
--- Arming `wkbuild` moves that no-op floor from hero 13 to hero 10, NOT the whole
--- domain to hero 5: rank 2 before the talent still narrows, harder (55.2).  See
--- the ConsiderQ note below and tests/test_wk_qdmg_domain.lua, which derives both
--- ladders from the real J.Skill.GetSkillList rather than re-typing them.
---
--- WHY MIN AND NOT THE HONEST NUMBER.  Taking the handle read straight would ADD
--- casts at rank 2+ once the t10 talent lands (260 > 235), and this stream ships
--- an action-adding change only with a sized domain.  `math.min` makes the armed
--- side a pure NARROWING -- it can only withdraw a claimed kill, never invent one
--- -- which is the discipline GH #165 wrote down and the shape hero_lion.lua's
--- `lionhexaoe` note names.
---
--- WHAT IS DELIBERATELY NOT MODELLED, stated so it can be argued with: the blast
--- also brings a 1.0-1.6s stun and a -20% slow, and a melee Wraith King standing
--- on the target converts those into autoattacks.  The 1.68 is plausibly a
--- stand-in for exactly that.  This lever does not price it (J.GetTotalAttackWillRealDamage
--- exists and would; using it is a separate change with its own frame), so the
--- armed side is the strictly conservative reading: "the blast ALONE kills".
---
--- THE REAL FRAME (tests/test_replay_260820_wk_blast_overclaim.lua):
--- f_260820_181711_wk_l1trade_333, t=333.5, a juggernaut at 160 HP.  Shipped
--- claims 168 and fires; impact-plus-dot is 120 and cannot.  It is the ONLY frame
--- in the band across the whole 107-frame corpus, and it was invisible until the
--- same round fixed the mock default that made `J.CanKillTarget` answer false for
--- every non-PURE damage type on every frame (tests/mock/bot_api.lua).
--- ⚠️ Q is on a 13.3s cooldown on that frame, so driving the branch end to end
--- needs a LABELLED cooldown mutation; the 160 HP, the ranks and the distance are
--- real frame data.
function X.wk_GetBlastKillDamage( hAbility )

	local nShipped = ( 40 * ( hAbility:GetLevel() - 1 ) + 100 ) * 1.68

	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkqdmg' ) ) then return nShipped end

	local nImpact = hAbility:GetSpecialValueInt( 'damage' )
	local nDotDps = hAbility:GetSpecialValueInt( 'blast_dot_damage' )
	local nDotDur = hAbility:GetSpecialValueFloat( 'blast_dot_duration' )

	-- A zero here means the read did not resolve (a renamed key answers 0
	-- silently -- tools/agent/special_value_key_census.py exists because of it).
	-- Fall back to the shipped claim rather than to a fabricated 0-damage world.
	if nImpact <= 0 or nDotDps <= 0 or nDotDur <= 0 then return nShipped end

	local nHonest = nImpact + nDotDps * nDotDur

	if nHonest < nShipped then return nHonest end

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
	--
	-- WIDENED 2026-08-27 (talent pricing round): the gap is not static.  The
	-- shipped t10 pick is slot [2] = ..._wraith_king_facet_1, whose surviving half
	-- is blast_dot_duration +2 -- and because blast_dot_damage is PER SECOND,
	-- doubling the duration 2 -> 4 doubles the dot: the honest impact-plus-dot
	-- goes 120/180/240/300 -> 160/260/360/460.  The engine folds that into the
	-- handle (GH #228) but this hardcode never asked the handle, so it is
	-- mis-scaled at every rank.  Whoever repairs it should read blast_dot_damage x
	-- blast_dot_duration off abilityQ rather than re-typing a second constant,
	-- which is the same repair Crystal Maiden's ConsiderW needs (that one is exact
	-- only while no talent touches the duration).
	--
	-- CORRECTED 2026-08-29 (GH #311, which quotes the retired sentences verbatim).
	-- What stood here said the gap widens from hero level 10 on, and that the
	-- constant goes stale in the thinks-it-cannot-kill direction from there.  Both
	-- sentences were argued PER Q RANK and never joined to the shipped upgrade
	-- row, and joined to it the direction reverses.  The row
	-- (tAllAbilityBuildList, :76) spends Q's SECOND point at row
	-- entry 12, which J.Skill.GetSkillList lands at HERO LEVEL 13, not 12 -- levels
	-- 10/15/20/25 are talent slots and consume no ability point.  So at hero level
	-- 10, when the t10 talent doubles the dot, Q is still RANK 1, and the doubling
	-- moves the honest read 120 -> 160 against a shipped claim of 168: the gap does
	-- not open, it NARROWS from 48 to 8.  From rank 2 on with the talent trained
	-- the honest read OVERTAKES shipped (260 > 235.2, 360 > 302.4, 460 > 369.6), so
	-- X.wk_GetBlastKillDamage's math.min returns the shipped constant unchanged.
	--
	-- ⇒ THE `wkqdmg` DOMAIN, under the shipped row: hero 2-9 narrow by 48, hero
	-- 10-12 narrow by 8, hero 13+ is a byte-for-byte no-op.  90 games of real
	-- frames agree (tools/batch_test/behavioral/wkqdmg_domain.py: Q sits at rank 1
	-- from hero level 2 through 12 and reaches rank 2 at 13; 66.7% of hero-target Q
	-- casts are in the rank-1 band).  Anyone hunting this lever above hero 12 under
	-- the shipped row is looking where it CANNOT act.
	--
	-- ⚠️ THAT DOMAIN IS CONDITIONAL ON `wkbuild` BEING UNARMED, and the two do not
	-- compose the obvious way.  tKillBuildList (:159) takes Q's second point at
	-- row entry 5 = hero level 5, and the tempting reading -- "so the domain moves
	-- forward to hero 5" -- is wrong, because the rank ladder is only half of the
	-- domain and the dot duration is the other half.  Rank 2 at a 2s dot still
	-- narrows, and by MORE (235.2 - 180 = 55.2 > 48).  What arming wkbuild
	-- actually removes is the TOP: rank 2 meets the t10 talent at hero 10 instead
	-- of 13, so the domain runs hero 2-9 (48 then 55.2) instead of hero 2-12 (48
	-- then 8).  Armed together, wkqdmg is therefore measured on a different and
	-- more heavily weighted population than its own frames describe.  Both ladders
	-- are derived from the real J.Skill.GetSkillList (never re-typed) in
	-- tests/test_wk_qdmg_domain.lua §5.
	--
	-- ⇒ RE-REGISTERED 2026-09-01 (hero stream, answering GH #390's rec 2 and 3;
	-- tests/test_wk_q_castrange_meter_domain.lua).  Everything above this line is
	-- the ARITHMETIC domain -- which hero levels the constant is even wrong on.
	-- The DECISION domain is a strictly smaller set and has one conjunct nobody
	-- had written down:
	--
	--     ehp0 in (armed claim, shipped claim]      the band -- unchanged
	--   AND the target is inside nCastRange + 80    the GATE, not the search ring
	--   AND no downstream firing point returns the same target on that frame
	--
	-- The third conjunct is closed form, not a corpus reading.  The kill-confirm
	-- branch below is firing point 2 of TEN in this function and ALL TEN return
	-- the same constant, BOT_ACTION_DESIRE_HIGH; they differ only in the target.
	-- So suppressing point 2 can lower the CAST COUNT only when all eight
	-- downstream points also decline on that frame.  On every other frame the
	-- cast still happens and the two legs are indistinguishable by cast count --
	-- by construction, which is what GH #390's t=243.4 frame ran into (the armed
	-- leg cast anyway, off the phase-boots chase) and why its armed leg casting
	-- MORE than baseline (108 vs 97) is not evidence against the lever.
	-- THE OBSERVABLE OF THIS LEVER IS TARGET IDENTITY, NEVER CAST COUNT.
	--
	-- ⚠️ AND THE FIXTURE ARCHIVE CANNOT CORROBORATE ANY OF IT, because
	-- `nCastRange` below has been ZERO on every frame ever driven through this
	-- function: GetCastRange is on no spec in tests/mock/, so the generic `^Get`
	-- default answers 0 -- 36 of 36 live-WK instants.  Fifth of the meter-zero
	-- family (GetActualIncomingDamage, GetAbilityDamage GH #175, GetManaCost,
	-- GetAOERadius GH #386), and the only one whose answer is ALREADY IN THE
	-- TREE: tests/mock/special_value_shapes.lua carries AbilityCastRange = 525
	-- for this ability, three lines above the mana ladder that got wired up on
	-- 2026-09-01.  The zero shrinks the search ring 855 -> 330, the tight ring
	-- 568 -> 43 and the kill gate 605 -> 80, so it UNDERSTATES reach.  Measured:
	-- of the 18 archive frames that reach this body, the loop below is entered on
	-- 0 under the zero and on 2 with 525 fed back.  ⇒ a fixture-archive zero on
	-- this branch is not a second opinion on the replay group's 0/97; it is a
	-- reading that was never able to disagree.  Repairing the meter is tree-wide
	-- (433 call sites / 150 files) and is NOT done here.
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
				-- [wkqdmg] gate off this is `nDamage * 1.68`, byte for byte.
				and J.CanKillTarget( npcEnemy, X.wk_GetBlastKillDamage( abilityQ ), nDamageType )
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
	-- This used to argue from GH #84's turbo level census (level >= 20 on 0 of 210
	-- hero-slots, HIGH-WATER OF 19), reading the crossing level as "the tail of
	-- that distribution instead of never".  CORRECTED 2026-08-27 (GH #235): the
	-- census was taken under a 10-minute batch cap that owner priority P3
	-- (GH #108) removed, and the first frame past it has this hero at level 26,
	-- high-water 27.  The crossing level is not in a tail at all -- it is ordinary.
	-- The correction only STRENGTHENS this note, which is why it survives it: the
	-- branch is even less arithmetically dead than the note claimed.  What IS
	-- wrong with it is narrower and survives both readings: at
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
	--   row indices as levels).  This used to add "which is where GH #84's turbo
	--   level census actually lives (0 of 210 hero-slots reached 20; high-water
	--   19)" -- RETIRED 2026-08-27 (GH #235): that census ran under a 10-minute
	--   batch cap, and levels 13-27 are ordinary now, so "levels 2-12 is where
	--   turbo lives" is no longer a supporting argument for anything.  The
	--   measurement below is untouched by that and still carries the branch.
	--   Measured
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

-- NOT VALIDATABLE ON A FIXTURE (measured 2026-08-23, census re-read 2026-08-28
-- over a corpus grown by two frames -- GH #274).  The first guard below asks
-- for modifier_skeleton_king_bone_guard, and that modifier is on 0 of the 36
-- Wraith King frames in tests/fixtures -- including the 19 that carry a modifier
-- list at all, 19 of which carry a sibling modifier_skeleton_king_* .  So this
-- function returns 0 on 36 of 36 real frames whatever else is true of them, and a
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
	-- special_bonus_attack_speed_50 -- nothing to do with mana.  The handle it
	-- needed is gone with it.)
	-- CORRECTED 2026-08-27 (GH #235): the clause struck here read "and unreachable in
	-- turbo regardless".  It is the second hole the 02:15Z sweep left, and a
	-- different one from the tenth-phrasing hole -- this claim is SPLIT ACROSS A LINE
	-- BREAK, so no line-by-line sweep can match it however many phrasings it carries.
	-- tests/test_level_premise_registry.lua section 3 scans adjacent line pairs for
	-- exactly that reason.  Nothing about this note's conclusion moves: the talent is
	-- an attack-speed row and has nothing to do with mana whether it is trained or
	-- not, which is why only the reachability clause is struck.  This hero's own t20
	-- and t25 pricing is still OWED (baton 2 of GH #238 section 6 takes him LAST,
	-- because two of his rows are FACET rows); do not read this edit as that pricing.
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
