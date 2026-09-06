local J = require( GetScriptDirectory()..'/FunLib/jmz_func')
local Customize = require( GetScriptDirectory()..'/Customize/general' )

local bot = GetBot()
local botName = bot:GetUnitName()

if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return end

local cAbility = nil
local TinkerShouldWaitInBaseToHeal = false

local ShouldWaitInBaseToHeal = false
local TPScroll = nil

local ShouldMoveCloseTowerForEdict = false
local EdictTowerTarget = nil

local ShouldMoveOutsideFountain = false
local ShouldMoveOutsideFountainCheckTime = 0
local MoveOutsideFountainDistance = 1500
local BearAttackLimitDistance = 1100
local TetherBreakDistance = 1000
local ConsiderHeroSpecificRoaming = {}

local laneToGank = nil
local lastGankDecisionTime = 0
local gankDecisionHoldTime = 30 -- 30s commitment to a gank decision (was 90s — too long, bots wasted laning time)
local TwinGates = J.Utils.GameStates.twinGates
local targetGate
local gateWarp = bot:GetAbilityByName("twin_gate_portal_warp")
local enableGateUsage = false -- twin_gate_portal_warp to be fixed
local arriveGankLocTime = 0
local gankTimeAfterArrival = 15 -- 15s stay at gank location (was 33s — too long doing nothing)
local gankGapTime = 3 * 60 -- 3 min between ganks (was 6 min — too restrictive)
local lastStaticLinkDebuffStack = 0
local AnyUnitAffectedByChainFrost = false
local HasPossibleWallOfReplicaAround = false
local ShouldBotsSpreadOut = false
local nChainFrostBounceDistance = 600 + 150
local cachedTombstoneZombieSlowState = 0
local nInRangeEnemy, nInRangeAlly, allyTowers, enemyTowers, trySeduce, shouldTempRetreat, botTarget, shouldGoBackToFountain, nInCloseRangeEnemy, nInCloseRangeAlly

local tangoDesire, tangoTarget, tangoSlot

local laneAndT1s = {
	{LANE_TOP, TOWER_TOP_1},
	{LANE_MID, TOWER_MID_1},
	{LANE_BOT, TOWER_BOT_1}
}

function GetDesire()
	-- local cacheKey = 'GetRoamDesire'..tostring(bot:GetPlayerID())
	-- local cachedVar = J.Utils.GetCachedVars(cacheKey, 0.5 * (1 + Customize.ThinkLess))
	-- if DotaTime() > 30 and cachedVar ~= nil then return cachedVar end
	local res = GetDesireHelper()
	-- J.Utils.SetCachedVars(cacheKey, res)
	return res
end
function GetDesireHelper()
	botName = bot:GetUnitName()
	if bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return BOT_MODE_DESIRE_NONE end

	trySeduce = false
	shouldTempRetreat = false
	TPScroll = J.Utils.GetItemFromFullInventory(bot, 'item_tpscroll')
	botTarget = J.GetProperTarget(bot)
	nInRangeEnemy = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)

	-- [pull rehome, owner directive 20260723] Pulling STAYS; the laning-Think
	-- replacement goes. During a pull window (both helpers are self-guarded:
	-- turbo + role + safety + :12/:42 timing, plus the 'pullcamp' candidate on
	-- the camp side -- the creep side was PROMOTED 2026-08-23) this
	-- bot bids ROAM desire and roam's own Think executes the pull action for
	-- those few seconds -- Valve's native laning runs the rest of the game.
	-- Plans are re-evaluated every frame; a closed window clears them so a
	-- stale plan can never hijack a roam entered for other reasons.
	-- [wave13 fingerprint 20260723] Pulling is a PEACETIME action: the first
	-- cut had no combat awareness and bots left lane / paced beside camps
	-- while enemies watched from 1600-1800 (163732 SK died mid-pull-wait) or
	-- tanked camps at half HP.
	-- [GH #13 20260819] ...but the two pulls need DIFFERENT safety rules, and
	-- sharing one made the creep pull a DEAD BRANCH. A camp pull walks a
	-- support out of lane into the jungle, so J.IsLanePullSafe (nothing
	-- visible within 1800) is exactly right there. A creep pull is performed
	-- AT the lane opponent -- J.ShouldCreepPullLane requires an enemy hero
	-- within 1000 as the aggro-draw target -- so "no enemy within 1800" could
	-- never hold on a frame where it wanted to fire, and the replay desk
	-- measured zero pull behavior in 13/13 batch games. J.IsCreepPullSafe
	-- keeps the anti-ambush intent for the lane case (the lane opponents may
	-- be there; a third hero lurking in the 1000-1800 ring may not).
	-- Both triggers are self-guarded (turbo + role + timing, plus the
	-- 'pullcamp' candidate on the camp side) and are asked FIRST, so a
	-- non-turbo game early-outs before any world scanning -- normal-mode
	-- behavior and cost are unchanged. The creep side is PROMOTED as of
	-- 2026-08-23, so in TURBO it now runs by default.
	local pull = J.ShouldCreepPullLane(bot)
	if pull ~= nil and J.IsCreepPullSafe(bot) then
		bot.roamCreepPull = pull
		bot.roamCampPull = nil
		return 0.9
	end
	local vCamp = J.ShouldPullNeutralCamp(bot)
	if vCamp ~= nil and J.IsLanePullSafe(bot) then
		bot.roamCampPull = vCamp
		bot.roamCreepPull = nil
		return 0.9
	end
	bot.roamCreepPull, bot.roamCampPull = nil, nil
	nInRangeAlly = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nInCloseRangeEnemy = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE)
	nInCloseRangeAlly = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE)
	allyTowers = bot:GetNearbyTowers(1600, false)
	enemyTowers = bot:GetNearbyTowers(1600, true)

	-- if ConsiderWaitInBaseToHeal()
	-- and GetUnitToLocationDistance(bot, J.GetTeamFountain()) > 5500
	-- then
	-- 	return BOT_ACTION_DESIRE_ABSOLUTE
	-- end

	tangoDesire, tangoTarget = ConsiderUseTango()
	if tangoDesire > 0 then
		return BOT_MODE_DESIRE_ABSOLUTE
	end

	TinkerShouldWaitInBaseToHeal = TinkerWaitInBaseAndHeal()
	if TinkerShouldWaitInBaseToHeal
	then
		return BOT_ACTION_DESIRE_ABSOLUTE
	end

	if bot:HasModifier('modifier_fountain_aura_buff') and DotaTime() > 0 and DotaTime() - ShouldMoveOutsideFountainCheckTime < 2 then
		return Clamp(bot:GetActiveModeDesire() + 0.2, 0, 1.1)
	else
		ShouldMoveOutsideFountain = false
	end

	if ConsiderHeroMoveOutsideFountain() then
		ShouldMoveOutsideFountain = true
		ShouldMoveOutsideFountainCheckTime = DotaTime()
		return Clamp(bot:GetActiveModeDesire() + 0.2, 0, 1.1)
	end

	-- unit special abilities
	local specialRoaming = ConsiderHeroSpecificRoaming[botName]
	if specialRoaming then
		-- return specialRoaming
		local specialDesire = specialRoaming()
		if specialDesire and specialDesire > 0 then
			if specialDesire <= 1 then
				return Clamp(specialDesire, 0, 0.99)
			else
				return specialDesire
			end
		end
	end

	-- general items or conditions.
	local generalRoaming = ConsiderGeneralRoamingInConditions()
	if generalRoaming then
		if generalRoaming > 0 and generalRoaming <= 1 then
			return Clamp(generalRoaming, 0, 0.99)
		else
			return generalRoaming
		end
	end

	-- if J.IsValidHero(botTarget)
	-- and (J.GetModifierTime(botTarget, 'modifier_dazzle_shallow_grave') > 0.5
	-- 	or J.GetModifierTime(botTarget, 'modifier_oracle_false_promise_timer') > 0.5
	-- 	or botTarget:HasModifier('modifier_skeleton_king_reincarnation_scepter_active')
	-- 	or botTarget:HasModifier('modifier_item_helm_of_the_undying_active'))
	-- and J.GetHP(botTarget) < 0.2 and botName ~= "npc_dota_hero_axe"
	-- then
	-- 	local nAttackTarget = J.GetAttackableWeakestUnit( bot, bot:GetAttackRange() + 400, true, true )
	-- 	bot:SetTarget( nAttackTarget )
	-- end

	return BOT_MODE_DESIRE_NONE
end

function Think()
    if J.CanNotUseAction(bot) then return end
	-- [GH #186 20260825] Soak candidate 'pullthink': THE DRAG STEP IS NEVER
	-- ISSUED ON 42% OF POKE FRAMES, and the reason is this line, not the drag.
	--
	-- The camp-pull cadence below is "poke the camp, then walk lane-ward in
	-- between so the neutrals follow". The walk is an order the cadence has to
	-- issue every beat -- and this throttle returns BEFORE the cadence is
	-- reached whenever bot:GetAnimActivity() is one of utils.lua's
	-- meaningfulActivities, a list that opens with ACTIVITY_RUN and
	-- ACTIVITY_ATTACK. A hero that is mid-attack-animation on the camp it just
	-- poked is BY CONSTRUCTION in ACTIVITY_ATTACK, so the frames on which the
	-- drag must be ordered are exactly the frames this line eats. The neutrals
	-- keep hitting back, the hero re-acquires them, and the throttle never
	-- reopens: the replay desk's reading is 31 of 73 armed poke frames moving
	-- < 50 u in the following second (ab 48% / ba 39%, same sign), with one
	-- hero standing on 6 CONSECUTIVE seconds of identical coordinates while its
	-- HP fell 1.00 -> 0.84. That is the wave13 "stood and TANKED the camp"
	-- fingerprint the cadence below was written to remove, reappearing through
	-- a line the cadence cannot see.
	--
	-- Skipping the throttle costs nothing here: the camp-pull branch returns
	-- before ThinkIndividualRoaming / ThinkGeneralRoaming, so the work this
	-- knob exists to skip is not reached on these frames anyway.
	--
	-- WHY THIS IS INVISIBLE TO EVERY TEST WE HAVE (world assertion): the mock
	-- answers bot:GetAnimActivity() with a fabricated 0 on every corpus frame,
	-- and 0 is not any ACTIVITY_* the engine sends -- the GH #133 shape. On top
	-- of that, ACTIVITY_* are undefined globals under the mock, so utils.lua
	-- builds meaningfulActivities as an EMPTY table. Two independent reasons
	-- this line reads false locally; tests/test_pullthink_anim_throttle.lua
	-- injects the activity to make it readable at all.
	--
	-- Turbo is structural, not asserted: bot.roamCampPull only exists when
	-- J.ShouldPullNeutralCamp returned non-nil, and that opens with
	-- J.IsModeTurbo() and the 'pullcamp' gate. Unarmed, the added test is one
	-- nil compare on a field that is nil in every non-pull frame, and the
	-- throttle is asked exactly as shipped.
	--
	-- Scoped to the CAMP pull only. The creep pull hits the same line, but its
	-- cadence already holds for the wind-up (promoted 'pullbeat'), and one
	-- lever at a time -- see the report's hand-off.
	--
	-- [GH #326 20260830] Soak candidate 'creepthink': THE DEFERRED HALF ABOVE,
	-- now with its own bearing frame. GH #326 photographed necrolyte on
	-- 20260830_003408_slot1 (seed 1828, ab/armed, W27) inside a pull-certified
	-- episode: SIX consecutive seconds of BYTE-IDENTICAL coordinates
	-- (-5847, 5064) while four melee lane creeps ate it from 0.96 HP down to
	-- 0.37, with four right-clicks (252.4 / 254.0 / 255.4 / 257.0) landing
	-- inside that stillness. That is the zuus camp frame of GH #186 with the
	-- creeps swapped in -- the SAME mechanism, on the branch the note above
	-- deferred: a ranged core that right-clicks a lane opponent inside its
	-- attack range stays in ACTIVITY_ATTACK while the aggroed wave beats on it,
	-- so this line returns on every frame the drag has to be ordered on, and
	-- the hero never walks the wave back.
	--
	-- READ #326 §"证据" AGAINST THIS: that issue infers from the same table
	-- that "neither leg can write zero-displacement + 1.5s right-clicks", and
	-- concludes the still frames are DOMAIN LEAKAGE rather than branch output
	-- (its 40.0-51.8% non-branch lower bound rests on exactly that step). The
	-- branch CAN write that shape, and this is how: the drag order is not
	-- issued at all. The shipped 1.2s beat also predicts the observed
	-- 1.4/1.6s gaps under this line -- a poke deferred to the first frame the
	-- throttle happens to reopen is LATE, never early.
	--
	-- ITS OWN ID, NOT A SECOND CLAUSE OF 'pullthink': the two domains are
	-- mutually exclusive BY CONSTRUCTION -- GetDesire nils roamCampPull when it
	-- sets roamCreepPull and vice versa (see the two branches above) -- so
	-- disjointness, not relative strength, is what decides the packaging, and
	-- one shared id would make neither condition-(a) reading attributable.
	-- Gated STANDALONE for the 'pullcad' trap: written as
	-- `IsSoakCandidate('creepthink') and IsSoakCandidate('pullbeat')` it would
	-- be frozen FALSE, because 'pullbeat' was promoted 2026-08-23 and a
	-- promoted id is in no armed string.
	--
	-- Turbo is structural here too, and for the sibling reason: roamCreepPull
	-- only exists when J.ShouldCreepPullLane returned non-nil, and that opens
	-- with J.IsModeTurbo(). Unarmed, this adds one nil compare on a field that
	-- is nil in every non-pull frame; the throttle is asked exactly as shipped.
	-- Skipping it costs nothing for the same reason as the camp side: the
	-- creep-pull branch returns before ThinkIndividualRoaming /
	-- ThinkGeneralRoaming, so the work this knob exists to skip is not reached.
	if not (bot.roamCampPull ~= nil and J.IsSoakCandidate('pullthink'))
	and not (bot.roamCreepPull ~= nil and J.IsSoakCandidate('creepthink'))
	and J.Utils.IsBotThinkingMeaningfulAction(bot, Customize.ThinkLess, "roam") then return end

	-- [pull rehome 20260723] Execute the pull plan set by GetDesire this
	-- frame (cleared there whenever the window is closed, so no staleness).
	if bot.roamCreepPull ~= nil then
		local pull = bot.roamCreepPull
		local now = DotaTime()
		-- Approximate the human 勾线 cadence: attack-order the enemy hero
		-- for a beat (redirects the adjacent enemy creeps' aggro onto us),
		-- then walk to the retreat point to drag the wave onto our side.
		-- [owner P1 condition (c) 20260823] soak candidate 'pullcad' -- the
		-- beat between aggro pokes. The shipped 1.2s predates any reading of
		-- the engine mechanic: the published numbers put a drawn creep aggro at
		-- 2.3s and put a COOLDOWN of 2-3s on drawing it again (Liquipedia Lane
		-- Creeps / Hotspawn's aggro guide). The replay desk's own GH #143
		-- measurement -- one right-click buys a median 2.2s of creep chase --
		-- is that same 2.3s seen from the other side. So beats 2 and 3 of a
		-- 1.2s cadence are structurally unable to draw anything: the first
		-- lands inside the live aggro, the second inside its cooldown. They are
		-- not free either -- Action_AttackUnit on a hero out of attack range
		-- walks us TOWARD that hero, so an ineffective re-poke drags the
		-- already-aggroed wave the wrong way. 3.0s clears both the 2.3s aggro
		-- and the 3s upper reading of the cooldown, and it is the cadence the
		-- sister camp pull below already uses for the same reason.
		--
		-- [DUTY-CYCLE CORRECTION 20260831] This comment used to state the
		-- effect bare: "the drag owns 2.5s of every 3.0s (83%) against 0.7s of
		-- every 1.2s (58%)".  That is (nBeat - 0.5)/nBeat, which presupposes
		-- this branch is asked on EVERY engine frame.  The throttle at the top
		-- of Think falsifies that presupposition: the branch is asked only on
		-- frames the throttle reopens, and a hero that just poked sits in
		-- ACTIVITY_ATTACK for a whole attack cycle R (soak candidate
		-- 'creepthink', GH #326, test_set.md §CK).  The two numbers are kept
		-- rather than deleted because they are not wrong: they are the R -> 0
		-- reading, and R -> 0 is precisely the world where 'creepthink' is
		-- armed.  Driven on the real zoned-mid frame for 30 s with R swept over
		-- the only attack-cycle band this corpus has measured (1.4-1.7 s, from
		-- GH #326's four right-clicks at 252.4 / 254.0 / 255.4 / 257.0), the
		-- drag's share of frames is:
		--
		--     neither armed          0.0%
		--     'pullcad' only         41.2-50.1%
		--     'creepthink' only      58.4%
		--     both armed             83.4%
		--
		-- (tests/test_pullcad_throttled_duty.lua drives all four rows.)  So in
		-- the world that actually ships -- throttle live, 'creepthink' gated --
		-- this lever does not widen a drag that already owns 58% of the window;
		-- it lifts the drag OUT OF THE EMPTY SET, by raising nBeat above R.
		-- That is the same inequality 'creepthink' attacks from the other side
		-- by driving R to ~0, which is why the two are strongly NON-additive
		-- (0 -> 50 and 0 -> 58 separately, 0 -> 83 together) and why 'pullcad'
		-- readings from W30 on may not be pooled with W25-W29 (§CO.1).  The
		-- 41.2-50.1% row is a LOWER bound: the model leaves the walking hero
		-- out of ACTIVITY_RUN, which is also a meaningful activity and can only
		-- defer the NEXT poke.  The 0.0% row leans on neither -- a hero never
		-- ordered to move is never running -- and holds for every R >= nBeat.
		--
		-- Either way the drag window the creeps see is 1.5-2.5 s against the
		-- 2.3 s they actually follow, which is what this beat was picked for.
		-- The wind-up hold below IS A STRUCTURAL PRECONDITION of this lever, not
		-- a recommendation: without it the poke is cancelled 33ms after it is
		-- ordered, so aggro is drawn only by luck and a LONGER beat would merely
		-- buy fewer lucky draws -- strictly worse than shipped.
		-- [PROMOTE FOLLOW-UP 20260823] Until that hold was promoted, this gate
		-- read `IsSoakCandidate('pullcad') and IsSoakCandidate('pullbeat')` --
		-- the dependency expressed as a conjunction so nobody had to remember
		-- it in prose. Promoting 'pullbeat' DELETES it from every armed string,
		-- which would have made that conjunction permanently false: 'pullcad'
		-- would be a byte-for-byte no-op in every wave, check_armed_wiring.py
		-- would still report it WIRED (the call site exists), and the verdict
		-- would come back "no effect" with nothing anywhere raising a hand --
		-- exactly the campgrade near-miss shape. The conjunct is dropped
		-- because the precondition is now satisfied BY CONSTRUCTION, which is
		-- strictly stronger than a gate; the invariant that replaces it is the
		-- source-level test asserting the hold is unconditional.
		local nBeat = 1.2
		if J.IsSoakCandidate('pullcad') then
			nBeat = 3.0
		end
		if bot.creepPullAttackTime == nil or (now - bot.creepPullAttackTime) > nBeat then
			bot:Action_AttackUnit(pull.enemy, true)
			bot.creepPullAttackTime = now
		elseif (now - bot.creepPullAttackTime) < 0.5 then
			-- [GH #143 20260823] PROMOTED (was soak-candidate 'pullbeat')
			-- 2026-08-23, as one atom with 'creeppull' -- see the owner-rule-2
			-- evidence in J.ShouldCreepPullLane's header. Never promoted apart:
			-- 'creeppull' without this hold is the configuration GH #143
			-- measured as broken, and it is not what W3 measured. ISSUE NO ORDER
			-- for one attack wind-up after the aggro poke. The cadence above
			-- ordered the attack and then, on the VERY NEXT frame (1/30 s
			-- later), issued a move order -- which cancels an attack that has
			-- not started yet. Pinned on a real laning frame: the order log
			-- over 46 frames is `A` then 36 consecutive `M`, i.e. the poke is
			-- cancelled 33 ms after it is ordered, every single beat. Creep
			-- aggro only redirects onto us once the attack actually BEGINS
			-- (the human 勾线 is attack-then-cancel AFTER the wind-up starts),
			-- so the pre-fix cadence draws aggro only by luck -- which is what
			-- the replay desk measured in GH #143: 26.8% of armed pull
			-- episodes have no creep ever turning around, and 47.5% carry a
			-- single right-click in the whole episode.
			-- Issuing NO action leaves the attack order running, so this is a
			-- hold, not a new order. 0.5 s covers the median hero attack point
			-- (~0.3-0.65 s); it is deliberately shorter than the 1.2 s beat so
			-- the drag still owns most of the window. GetAttackPoint() would be
			-- the principled source but it is absent from the mock, and
			-- GetAttackRange() -- the other obvious way to spend this frame --
			-- reads the fabricated mock default 150 on 966/966 corpus frames
			-- (world assertion 21), so neither can be validated locally.
			-- Turbo is structural here: the enclosing plan only exists when
			-- J.ShouldCreepPullLane returned non-nil, and that opens with
			-- J.IsModeTurbo().
		else
			bot:Action_MoveToLocation(pull.retreat)
		end
		return
	end
	if bot.roamCampPull ~= nil then
		-- [wave13] Aggro-then-DRAG cadence: the first cut attacked the camp
		-- every frame, so a puller stood and TANKED the neutrals (one bot
		-- died to a camp at 50% HP). Poke once every 3s, walk home-ward in
		-- between so the camp follows into the lane path.
		local now = DotaTime()
		local tNeut = bot:GetNearbyNeutralCreeps(1400)
		local bCampHere = tNeut ~= nil and #tNeut > 0 and J.IsValid(tNeut[1])
		-- [OWNER_PRIORITIES P1 20260904] Soak candidate 'campbind': POKE THE CAMP
		-- WE PLANNED. The line below used to read tNeut[1] -- the neutral nearest
		-- the BOT -- so every camp J.ShouldPullNeutralCamp rejected (enemy team,
		-- past our half, off this lane) was poked anyway as soon as its creeps
		-- were the nearest ones, and the selector governed only where the bot
		-- walked. Unarmed the helper answers tNeut[1] under the same J.IsValid
		-- test bCampHere just applied, so this is byte-for-byte the shipped poke;
		-- armed it answers nil when no visible neutral belongs to the planned
		-- camp, and then NO ORDER is issued this frame -- which leaves the walk
		-- toward bot.roamCampPull from the previous frame running, exactly the
		-- hold semantics the wind-up branch below relies on. bCampHere itself is
		-- deliberately NOT rebound: the drag and walk branches keep the shipped
		-- control flow, so the only frames this lever can change are poke frames.
		local hPoke = J.GetCampPullPokeTarget(tNeut, bot.roamCampPull)
		if bCampHere
		and (bot.campPullAttackTime == nil or now - bot.campPullAttackTime > 3.0) then
			if hPoke ~= nil then
				bot:Action_AttackUnit(hPoke, true)
				bot.campPullAttackTime = now
			end
		elseif bCampHere
		and J.IsSoakCandidate('pullthink')
		and (now - bot.campPullAttackTime) < 0.5 then
			-- [GH #186 20260825] Part two of 'pullthink', and a STRUCTURAL
			-- PRECONDITION of part one rather than a second lever. This is the
			-- wind-up hold the sister creep-pull branch above already ships
			-- (promoted 'pullbeat', GH #143): issue NO ORDER for one attack
			-- wind-up after the poke, which leaves the attack order running.
			--
			-- The camp branch never had it because it never needed it: the
			-- throttle above was eating the next frame anyway. Un-eating that
			-- frame without this hold would hand the camp pull the exact defect
			-- GH #143 measured on the creep pull -- Action_MoveToLocation on the
			-- frame after Action_AttackUnit cancels an attack whose wind-up has
			-- not started, so the poke lands no damage and the neutrals never
			-- acquire. The 46-frame order log that pinned it there reads
			-- `A` then 36 consecutive `M`. Shipping part one alone is therefore
			-- not "a smaller change", it is the configuration already measured
			-- as broken, which is why both parts read ONE id.
			--
			-- Deliberately NOT written as `IsSoakCandidate('pullthink') and
			-- IsSoakCandidate('pullbeat')`: 'pullbeat' was promoted 2026-08-23
			-- and a promoted id is in no armed string, so that conjunction would
			-- be frozen FALSE in every wave while check_armed_wiring.py still
			-- called it WIRED -- the pullcad trap, verbatim.
			--
			-- 0.5 s and the reasoning behind it are the promoted branch's, not a
			-- new number: it covers the median hero attack point (~0.3-0.65 s)
			-- and stays well inside the 3.0 s beat so the drag still owns most
			-- of the window. GetAttackPoint() would be the principled source but
			-- it is absent from the mock.
			--
			-- Reaching this elseif with bCampHere implies campPullAttackTime is
			-- non-nil (the branch above claims the nil case), same as upstairs.
		elseif bCampHere then
			-- [GH #117, 20260825] 'pulldrag': walk toward THIS LANE, not toward
			-- home. The line below already says "so the camp follows into the
			-- lane path" -- the fountain was standing in for the lane path, and
			-- on the four camps the engine actually pulls from that proxy wastes
			-- 81-87% of every step (see J.GetLanePullDragTarget for the table).
			-- nil = not armed / lane unreadable -> the shipped home-ward walk,
			-- byte for byte.
			local vB, vF = bot:GetLocation(), J.GetTeamFountain()
			local vLane = J.GetLanePullDragTarget(bot, bot.roamCampPull)
			if vLane ~= nil then vF = vLane end
			local dx, dy = vF.x - vB.x, vF.y - vB.y
			local n = math.sqrt(dx * dx + dy * dy)
			if n > 1 then
				bot:Action_MoveToLocation(Vector(
					vB.x + dx / n * 500, vB.y + dy / n * 500, vB.z))
			end
		else
			bot:Action_MoveToLocation(bot.roamCampPull)
		end
		return
	end

	nInRangeEnemy = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)

	ThinkIndividualRoaming() -- unit special abilities
	ThinkGeneralRoaming() -- general items or conditions.
	ThinkActualGankingInLanes()
end

function ThinkIndividualRoaming()
	if tangoDesire and tangoDesire > 0 and tangoTarget then
		local hItem = bot:GetItemInSlot( tangoSlot )
		bot:Action_UseAbilityOnTree( hItem, tangoTarget )
		return
	end

	-- Heal in Base
	-- Just for TP. Too much back and forth when "forcing" them try to walk to fountain; <- not reliable and misses farm.
	if ShouldWaitInBaseToHeal
	then
		if GetUnitToLocationDistance(bot, J.GetTeamFountain()) > 150
		then
			nInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), 1400)
			if J.Item.GetItemCharges(bot, 'item_tpscroll') >= 1
			and nInRangeEnemy ~= nil and #nInRangeEnemy == 0
			then
				if botName == 'npc_dota_hero_furion'
				then
					local Teleportation = bot:GetAbilityByName('furion_teleportation')
					if Teleportation:IsTrained()
					and Teleportation:IsFullyCastable()
					then
						bot:Action_UseAbilityOnLocation(Teleportation, J.GetTeamFountain())
						return
					end
				end

				if TPScroll ~= nil
				and not TPScroll:IsNull()
				and TPScroll:IsFullyCastable()
				then
					bot:Action_UseAbilityOnLocation(TPScroll, J.GetTeamFountain())
					return
				end
			end
		else
			if J.GetHP(bot) < 0.85 or J.GetMP(bot) < 0.85
			then
				if J.Item.GetItemCharges(bot, 'item_tpscroll') <= 1
				and bot:GetGold() >= GetItemCost('item_tpscroll')
				then
					bot:ActionImmediate_PurchaseItem('item_tpscroll')
					return
				end

				bot:Action_MoveToLocation(bot:GetLocation() + 150)
				return
			else
				ShouldWaitInBaseToHeal = false
			end
		end
	end

	-- Tinker
	if TinkerShouldWaitInBaseToHeal
	then
		if J.GetHP(bot) < 0.8 or J.GetMP(bot) < 0.8
		then
			bot:Action_ClearActions(true)
			return
		end
	end

	-- Spirit Breaker
	if bot:HasModifier('modifier_spirit_breaker_charge_of_darkness')
	then
		bot:Action_ClearActions(false)
		if bot.chargeRetreat and #nInRangeEnemy == 0 then
			if IsLocationPassable(bot:GetLocation()) then
				bot.chargeRetreat = false
				bot:Action_MoveToLocation(bot:GetLocation() + RandomVector(150))
				return
			end
		end
		return
	end

	-- Batrider
	if bot:HasModifier('modifier_batrider_flaming_lasso_self')
	then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	-- Nyx Assassin
	if bot.canVendettaKill
	then
		if J.IsValid(bot.vendettaTarget)
		then
			if GetUnitToUnitDistance(bot, bot.vendettaTarget) > bot:GetAttackRange() + 200
			then
				bot:Action_MoveToLocation(bot.vendettaTarget:GetLocation())
				return
			else
				bot:Action_AttackUnit(bot.vendettaTarget, true)
				return
			end
		end
	end

	-- Rolling Thunder
	if bot:HasModifier('modifier_pangolier_gyroshell')
	then
		if J.IsInTeamFight(bot, 1600)
		then
			local target = nil
			local hp = 0
			for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES))
			do
				if J.IsValidHero(enemyHero)
				and J.IsInRange(bot, enemyHero, 2200)
				and J.CanBeAttacked(enemyHero)
				and J.CanCastOnNonMagicImmune(enemyHero)
				and not enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
				and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
				and hp < enemyHero:GetHealth()
				then
					hp = enemyHero:GetHealth()
					target = enemyHero
				end
			end

			if target ~= nil
			then
				local moveLoc = J.GetCorrectLoc(target, 0.2)
				bot:Action_MoveToLocation(moveLoc)
				return
			end
		end

		if J.IsRetreating(bot)
		then
			bot:Action_MoveToLocation(J.GetTeamFountain())
			return
		end

		local tEnemyHeroes = bot:GetNearbyHeroes(880, true, BOT_MODE_NONE)
		if J.IsValidHero(tEnemyHeroes[1])
		and not tEnemyHeroes[1]:HasModifier('modifier_faceless_void_chronosphere_freeze')
		then
			bot:Action_MoveToLocation(J.GetCorrectLoc(tEnemyHeroes[1], 0.2))
			return
		end

		local tCreeps = bot:GetNearbyCreeps(880, true)
		if J.IsValid(tCreeps[1])
		then
			bot:Action_MoveToLocation(J.GetCorrectLoc(tCreeps[1], 0.2))
			return
		end
	end

	-- Primal Beast (Trample)
	if bot:HasModifier('modifier_primal_beast_trample') then
		local tAllyHeroes = J.GetAlliesNearLoc(bot:GetLocation(), 1200)
		local tEnemyHeroes = J.GetEnemiesNearLoc(bot:GetLocation(), 1200)

		if #tEnemyHeroes > #tAllyHeroes + 1
		or (not J.WeAreStronger(bot, 800) and J.GetHP(bot) < 0.55)
		or (#tEnemyHeroes > 0 and J.GetHP(bot) < 0.3) then
			TrampleToBase()
			return
		end

		-- bot.trample_status {1 - type, 2 - location, 3 - target, if any}
		if bot.trample_status ~= nil and type(bot.trample_status) == "table" then
			if bot.trample_status[1] == 'engaging' then
				if J.IsValidHero(bot.trample_status[3]) then
					DoTrample(J.GetCorrectLoc( bot.trample_status[3], 0.2 ))
					return
				elseif #tEnemyHeroes > 0 then
					local target = nil
					local hp = 0
					for _, enemyHero in pairs(tEnemyHeroes) do
						if J.IsValidHero(enemyHero)
						and J.IsInRange(bot, enemyHero, 2200)
						and J.CanBeAttacked(enemyHero)
						and J.CanCastOnNonMagicImmune(enemyHero)
						and not enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
						and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
						and hp < enemyHero:GetHealth()
						then
							hp = enemyHero:GetHealth()
							target = enemyHero
						end
					end

					if target ~= nil then
						DoTrample(J.GetCorrectLoc( target, 0.2 ))
						return
					end
				else
					if #tAllyHeroes >= #tEnemyHeroes and J.WeAreStronger(bot, 800) then
						for _, ally in pairs(tAllyHeroes) do
							if J.IsValidHero(ally) and not J.IsSuspiciousIllusion(ally) then
								local allyTarget = ally:GetAttackTarget()
								if J.IsValidHero(allyTarget) then
									DoTrample(J.GetCorrectLoc( allyTarget, 0.2 ))
									return
								end
							end
						end
					end
				end
				-- TrampleToBase()
				return
			elseif bot.trample_status[1] == 'retreating' then
				TrampleToBase()
				return
			elseif bot.trample_status[1] == 'farming' or bot.trample_status[1] == 'laning' then
				local tCreeps = bot:GetNearbyCreeps(1200, true)
				if J.IsValid(tCreeps[1]) and J.CanBeAttacked(tCreeps[1])
				then
					local nLocationAoE = bot:FindAoELocation(true, false, tCreeps[1]:GetLocation(), 0, 300, 0, 0)
					if nLocationAoE.count > 0 then
						DoTrample(nLocationAoE.targetloc)
						return
					end
				else
					TrampleToBase()
					return
				end
			elseif bot.trample_status[1] == 'miniboss' then
				if J.IsValid(bot.trample_status[3]) then
					DoTrample(bot.trample_status[2])
					return
				else
					TrampleToBase()
					return
				end
			end
		end
		TrampleToBase()
		return
	end

	-- Primal Beast (Onslaught)
	if bot:HasModifier('modifier_primal_beast_onslaught_windup')
	or bot:HasModifier('modifier_prevent_taunts')
	or bot:HasModifier('modifier_primal_beast_onslaught_movement_adjustable')
	then
		if bot.onslaught_status ~= nil then
			if bot.onslaught_status[1] == 'engage' then
				if J.IsValidHero(bot.onslaught_status[2]) then
					bot:Action_MoveToLocation(J.GetCorrectLoc(bot.onslaught_status[2], 0.3))
					return
				else
					local target = nil
					local targetHealth = math.huge
					for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
						if J.IsValidHero(enemy)
						and J.IsInRange(bot, enemy, 1600)
						and J.CanBeAttacked(enemy)
						and not J.IsEnemyBlackHoleInLocation(enemy:GetLocation())
						and not J.IsEnemyChronosphereInLocation(enemy:GetLocation())
						and not enemy:HasModifier('modifier_necrolyte_reapers_scythe')
						then
							local enemyHealth = enemy:GetHealth()
							if enemyHealth < targetHealth then
								targetHealth = enemyHealth
								target = enemy
							end
						end
					end

					if target ~= nil then
						bot:Action_MoveToLocation(J.GetCorrectLoc(target, 0.3))
						return
					end

					for i = 1, #GetTeamPlayers( GetTeam() ) do
						local member = GetTeamMember(i)
						if J.IsValidHero(member)
						and J.IsInRange(bot, member, 1600)
						then
							local memberTarget = member:GetAttackTarget()
							if J.IsValidHero(memberTarget)
							and J.IsInRange(bot, memberTarget, 1600)
							and not J.IsEnemyBlackHoleInLocation(memberTarget:GetLocation())
							and not J.IsEnemyChronosphereInLocation(memberTarget:GetLocation())
							and not memberTarget:HasModifier('modifier_necrolyte_reapers_scythe')
							then
								bot:Action_MoveToLocation(J.GetCorrectLoc(memberTarget, 0.3))
								return
							end
						end
					end
				end
			end
		elseif bot.onslaught_status[1] == 'retreat' then
			bot:Action_MoveToLocation(bot.onslaught_status[2])
			return
		elseif bot.onslaught_status[1] == 'farm' then
			local nCreeps = bot:GetNearbyCreeps(800, true)
			if J.IsValid(nCreeps[1])
			and not J.IsRunning(nCreeps[1])
			and J.CanBeAttacked(nCreeps[1])
			then
				local nLocationAoE = bot:FindAoELocation(true, false, nCreeps[1]:GetLocation(), 0, 200, 0, 0)
				if ((#nCreeps >= 4 and nLocationAoE.count >= 4))
				or (#nCreeps >= 2 and nLocationAoE.count >= 2 and nCreeps[1]:IsAncientCreep())
				then
					bot:Action_MoveToLocation(nLocationAoE.targetloc)
					return
				end
			end
		end
	end

	-- Phoenix
	if bot:HasModifier('modifier_phoenix_sun_ray')
	then
		local nRadius = 130
		local nBeamDistance = 1150
		local vBeamEndLoc = J.GetFaceTowardDistanceLocation(bot, nBeamDistance)

		if J.IsValidHero(bot.sun_ray_target) then
			bot:Action_MoveToLocation(bot.sun_ray_target:GetLocation())
			return
		end

		-- beam other enemy
		local tEnemyHeroes = bot:GetNearbyHeroes(nBeamDistance, true, BOT_MODE_NONE)
		for _, enemy in pairs(tEnemyHeroes) do
			if J.IsValidHero(enemy)
			and J.CanCastOnNonMagicImmune(enemy)
			and not enemy:HasModifier('modifier_abaddon_borrowed_time')
			and not enemy:HasModifier('modifier_dazzle_shallow_grave')
			and not enemy:HasModifier('modifier_necrolyte_reapers_scythe') then
				bot.sun_ray_target = enemy
				bot:Action_MoveToLocation(enemy:GetLocation())
				return
			end
		end

		-- heal ally
		local tInRangeAlly = bot:GetNearbyHeroes(nBeamDistance, false, BOT_MODE_NONE)
		for _, ally in pairs(tInRangeAlly)
		do
			if J.IsValidHero(ally)
			and bot ~= ally
			and J.GetHP(ally) < 0.5
			and ally:WasRecentlyDamagedByAnyHero(3.5)
			and not ally:IsIllusion()
			and bot:IsFacingLocation(ally:GetLocation(), 60)
			then
				if not J.IsRunning(ally)
				or ally:IsStunned()
				or ally:IsRooted()
				or ally:IsHexed()
				or ally:HasModifier('modifier_bane_fiends_grip')
				or ally:HasModifier('modifier_faceless_void_chronosphere_freeze')
				or ally:HasModifier('modifier_enigma_black_hole_pull') then
					bot.sun_ray_target = ally
					bot:Action_MoveToLocation(ally:GetLocation())
					return
				end
			end
		end
	end

	-- Snapfire
	if bot:HasModifier('modifier_snapfire_mortimer_kisses')
	then
		local nKissesTarget = GetMortimerKissesTarget()

		if nKissesTarget ~= nil
		then
			local eta = (GetUnitToUnitDistance(bot, nKissesTarget) / 1300) + 0.3
			bot:Action_MoveToLocation(J.GetCorrectLoc(nKissesTarget, eta))
			return
		end
	end

	-- Leshrac
	if ShouldMoveCloseTowerForEdict
	then
		if EdictTowerTarget ~= nil
		then
			if GetUnitToUnitDistance(bot, EdictTowerTarget) > 350
			then
				bot:Action_MoveToLocation(EdictTowerTarget:GetLocation())
				return
			end
		end
	end

	-- Void Spirit
	if bot:HasModifier('modifier_void_spirit_dissimilate_phase')
	then
		local botTarget = J.GetProperTarget(bot)

		if J.IsGoingOnSomeone(bot)
		then
			if J.IsValidTarget(botTarget)
			then
				bot:Action_MoveToLocation(botTarget:GetLocation())
			end
		end

		if J.IsRetreating(bot)
		then
			bot:Action_MoveToLocation(J.GetEscapeLoc())
		end

		return
	end

	-- Marci
	if bot:HasModifier("modifier_marci_unleash") then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and GetUnitToUnitDistance(bot, botTarget) > bot:GetAttackRange() + 200
		then
			bot:Action_MoveToLocation(botTarget:GetLocation())
			return
		else
			bot:Action_AttackUnit(botTarget, false)
			return
		end
	end

	if bot:HasModifier("modifier_muerta_pierce_the_veil_buff")
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and GetUnitToUnitDistance(bot, botTarget) > bot:GetAttackRange() + 200
		then
			bot:Action_MoveToLocation(botTarget:GetLocation())
			return
		else
			bot:Action_AttackUnit(botTarget, false)
			return
		end
	end

	if bot:HasModifier('modifier_razor_static_link_buff') then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) then
			local distanceFromHero = GetUnitToUnitDistance(bot, botTarget)
			if distanceFromHero > bot:GetAttackRange()
			then
				bot:Action_MoveToLocation(botTarget:GetLocation() + RandomVector(200))
				return
			elseif distanceFromHero <= bot:GetAttackRange() / 2 then
				bot:Action_AttackUnit(botTarget, false)
				return
			end
		end
	end

	if bot:HasModifier("modifier_faceless_void_chronosphere")
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and GetUnitToUnitDistance(bot, botTarget) > bot:GetAttackRange() + 200
		then
			bot:Action_MoveToLocation(botTarget:GetLocation())
			return
		else
			bot:Action_AttackUnit(botTarget, false)
			return
		end
	end

	-- Leshrac
	if bot:HasModifier("modifier_leshrac_pulse_nova")
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and GetUnitToUnitDistance(bot, botTarget) > 400
		then
			bot:Action_MoveToLocation(botTarget:GetLocation())
			return
		else
			bot:ActionQueue_AttackUnit(botTarget, false)
			return
		end
	end

	if bot:HasModifier("modifier_wisp_tether")
	and J.IsValid(bot.stateTetheredHero) then
		if GetUnitToUnitDistance(bot, bot.stateTetheredHero) > TetherBreakDistance - 400 then
			bot:Action_MoveToLocation(bot.stateTetheredHero:GetLocation())
			return
		else
			local botTarget = J.GetProperTarget(bot)
			if J.IsValidTarget(botTarget) then
				bot:ActionQueue_AttackUnit(botTarget, false)
			end
			return
		end
	end

	if botName == 'npc_dota_hero_lone_druid_bear' then
		if J.IsTryingtoUseAbility(bot) then return BOT_MODE_DESIRE_NONE end

		local hero = J.Utils.GetLoneDruid(bot).hero
		-- local hasUltimateScepter = J.Item.HasItem(bot, 'item_ultimate_scepter') or bot:HasModifier('modifier_item_ultimate_scepter_consumed')
		local distanceFromHero = GetUnitToUnitDistance(J.Utils.GetLoneDruid(bot).hero, bot)
		local target = hero:GetAttackTarget() or J.GetProperTarget(hero) or J.GetProperTarget(bot)

		if distanceFromHero > BearAttackLimitDistance
		then
			bot:Action_MoveToLocation(hero:GetLocation())
			return
		end

		local avoidDangerous = (#bot:GetNearbyLaneCreeps(400, true) < 3 and #bot:GetNearbyTowers(800, true) == 0) or bot:GetLevel() >= 3
		if J.Utils.IsValidUnit(target)
		and distanceFromHero <= BearAttackLimitDistance
		and GetUnitToUnitDistance(hero, target) < BearAttackLimitDistance + 250
		and avoidDangerous then
			if GetUnitToUnitDistance(hero, target) > hero:GetAttackRange() + 200 then
				bot:Action_MoveToLocation(target:GetLocation())
				return
			else
				bot:Action_AttackUnit(target, false)
				return
			end
		end

		target = J.GetAttackableWeakestUnitFromList(hero, hero:GetNearbyHeroes(BearAttackLimitDistance + 250, true, BOT_MODE_NONE))
		if target ~= nil
		and avoidDangerous
		then
			bot:Action_AttackUnit(target, false)
			return
		end
		return
	end

	-- [rotscope, GH #368] The queued attack below reads a DIFFERENT variable
	-- than the guard four lines above it protects.
	--
	-- `local botTarget` inside the Rot block shadows the FILE-LOCAL `botTarget`
	-- (declared at the top of this file, written only inside GetDesireHelper),
	-- and the shadow's scope ENDS with that block. So the order is issued on
	-- the file-local handle, which nothing here validated and nothing here
	-- measured the distance to -- while `J.IsValidTarget(...) and dist > 400`
	-- guarded the inner one and then went out of scope.
	--
	-- Three consequences, none of them Pudge-specific reasoning:
	--   * it fires UNCONDITIONALLY for Pudge -- Rot toggled or not, target
	--     valid or not, at any distance;
	--   * `bOnce = false` makes it a CONTINUOUS order, the exact shape
	--     'roamreach' (GH #45) exists to keep out of a Think that stops being
	--     called the moment another mode wins the auction;
	--   * the handle can be STALE: GetDesireHelper returns before assigning it
	--     whenever the bot is invulnerable, dead, an illusion or not a hero,
	--     so the previous frame's target survives -- the 'roamstale' (GH #39,
	--     PROMOTED stable-v1) disease in a second file.
	--
	-- REAL FRAME (tests/fixtures/f_113203_pudge_homeroute_silent.lua, subject
	-- pudge): shipped, this line is the ONLY order the whole of
	-- ThinkIndividualRoaming issues on that frame, and its target is nil.
	-- Nothing in the repo had ever seen it: tests/mock/replay_fixture.lua's
	-- record_actions did not hook ActionQueue_AttackUnit until 2026-08-31, so
	-- every reader of that log answered "no attack was ordered" here.
	--
	-- Armed, the order moves INSIDE the Rot block and onto the handle the
	-- guard actually checked, and is issued only when that handle is a valid
	-- unit (J.IsValid -- the wide predicate, so a creep still counts; see the
	-- FUSE RECORD on J.IsValidTarget in jmz_func.lua). Unarmed the shipped
	-- line runs unchanged, on the same variable, in the same place.
	-- Gated turbo + 'rotscope'; inert by default.
	if botName == 'npc_dota_hero_pudge' then
		local rotscope = J.IsModeTurbo() and J.IsSoakCandidate('rotscope')
		local Rot = bot:GetAbilityByName('pudge_rot')
		if Rot:GetToggleState()
		then
			local botTarget = J.GetProperTarget(bot)
			if J.IsValidTarget(botTarget) and GetUnitToUnitDistance(bot, botTarget) > 400
			then
				bot:Action_MoveToLocation(botTarget:GetLocation())
				return
			end
			if rotscope and J.IsValid(botTarget)
			then
				bot:ActionQueue_AttackUnit(botTarget, false)
			end
		end
		if not rotscope
		then
			bot:ActionQueue_AttackUnit(botTarget, false)
		end
	end

	if botName == 'npc_dota_hero_nevermore' then
		if J.Utils.IsTruelyInvisible(bot) then
			local botTarget = J.GetProperTarget(bot)
			if J.IsValidTarget(botTarget) and GetUnitToUnitDistance(bot, botTarget) > 400
			then
				bot:Action_MoveToLocation(botTarget:GetLocation())
				return
			end
		end
	end
end

local trample_step = 12
local trample = {}
function DoTrample(vLoc)
	trample = J.Utils.GetCirclarPointsAroundCenterPoint(vLoc, 300, 12)
	if trample_step < 12 then
		bot:Action_MoveToLocation(trample[trample_step])
		trample_step = trample_step + 1
	else
		trample_step = 1
	end
end
function TrampleToBase()
	trample_step = 12
	trample = {}
	bot:Action_MoveToLocation(J.GetTeamFountain())
end

function ThinkGeneralRoaming()
	-- Get out of fountain if in item mode
	if ShouldMoveOutsideFountain
	then
		bot:Action_AttackMove(J.Utils.GetOffsetLocationTowardsTargetLocation(J.GetTeamFountain(), J.GetEnemyFountain(), MoveOutsideFountainDistance))
		return
	end

	if shouldGoBackToFountain then
		if bot:HasModifier('modifier_fountain_aura_buff')
		   or (J.GetHP(bot) > 0.8 and J.GetMP(bot) > 0.7) then
			shouldGoBackToFountain = false
		end
	end

	if AnyUnitAffectedByChainFrost then
		J.Utils.SmartSpreadOut(bot, nChainFrostBounceDistance, nChainFrostBounceDistance, nInRangeEnemy, false)
		return
	end

	if HasPossibleWallOfReplicaAround then
		J.Utils.MoveBotSafely(bot)
		return
	end

	if ShouldBotsSpreadOut then
		J.Utils.SmartSpreadOut(bot, 450, 450, nInRangeEnemy, false)
		return
	end

	if bot:GetActiveMode() == BOT_MODE_ITEM
	and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH
	and (botName == 'npc_dota_hero_lone_druid_bear' or bot:HasModifier('modifier_arc_warden_tempest_double') or J.IsMeepoClone(bot))
	then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if bot:HasModifier("modifier_item_mask_of_madness_berserk") then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValid(botTarget) then
			if GetUnitToUnitDistance(bot, botTarget) > bot:GetAttackRange() + 200
			then
				bot:Action_MoveToLocation(botTarget:GetLocation())
				return
			else
				bot:Action_AttackUnit(botTarget, false)
				return
			end
		end
	end

	if J.GetModifierTime(bot, "modifier_flask_healing") >= 1 then
		if #bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE) >= 1 and J.GetHP(bot) < 0.8 then
			bot:Action_MoveToLocation(J.GetTeamFountain())
			return
		end
	end

	if bot:HasModifier("modifier_skeleton_king_reincarnation_scepter_active") or bot:HasModifier("modifier_item_helm_of_the_undying_active") then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValid(botTarget) then
			if GetUnitToUnitDistance(bot, botTarget) > bot:GetAttackRange() + 200
			then
				bot:Action_MoveToLocation(botTarget:GetLocation())
				return
			else
				bot:Action_AttackUnit(botTarget, false)
				return
			end
		end
	end

	if bot:HasModifier("modifier_nevermore_shadowraze_debuff") then
		MoveAwayFromTarget(GetTargetEnemy("npc_dota_hero_nevermore"), 1350)
		return
	end

	if bot:HasModifier("modifier_razor_static_link_debuff") then
		MoveAwayFromTarget(GetTargetEnemy("npc_dota_hero_razor"), 1200)
		return
	end

	if bot:HasModifier("modifier_primal_beast_trample") then
		MoveAwayFromTarget(GetTargetEnemy("npc_dota_hero_primal_beast"), 1200)
		return
	end

	if botName == 'npc_dota_hero_lone_druid' then
		if J.GetHP(bot) < 0.65 or J.GetMP(bot) < 0.35 then
			bot:Action_MoveToLocation(J.GetTeamFountain()); return
		end
	end

	if bot:HasModifier("modifier_ursa_fury_swipes_damage_increase") then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if bot:HasModifier("modifier_monkey_king_quadruple_tap_counter") then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if bot:HasModifier("modifier_slark_essence_shift_debuff_counter") then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if bot:HasModifier("modifier_silencer_glaives_of_wisdom_debuff_counter") then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if bot:HasModifier("modifier_dazzle_poison_touch") then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if bot:HasModifier("modifier_maledict") then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if bot:HasModifier("modifier_viper_poison_attack_slow") then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if J.GetModifierCount(bot, "modifier_huskar_burning_spear_debuff") >= 3 then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if J.GetModifierCount(bot, "modifier_batrider_sticky_napalm") >= 3 then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if bot:HasModifier("modifier_undying_tombstone_zombie_deathstrike_slow") then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if J.GetModifierCount(bot, "modifier_bristleback_quill_spray") >= 3 then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if trySeduce then
		allyTowers = bot:GetNearbyTowers(1600, false)
		if allyTowers[1] then
			local distanceFromFountain = GetUnitToLocationDistance(bot, J.GetTeamFountain())
			local towerFromFountain = GetUnitToLocationDistance(allyTowers[1], J.GetTeamFountain())
			local distanceToTower = GetUnitToUnitDistance(bot, allyTowers[1])
			if distanceFromFountain > towerFromFountain and distanceToTower > 300 then
				bot:Action_MoveToLocation(allyTowers[1]:GetLocation() + RandomVector(150))
			else
				bot:Action_MoveToLocation(J.GetTeamFountain())
			end
			return
		end
	end

	if shouldTempRetreat then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end

	if shouldGoBackToFountain then
		bot:Action_MoveToLocation(J.GetTeamFountain())
		return
	end
end

function GeneralReactToStackedDebuff(enemyHeroName)
	local enemy = GetTargetEnemy(enemyHeroName)
	if enemy ~= nil then -- nil check is enough here
		if J.GetHP(bot) > 0.6 and not J.Utils.NumActionTypeInQueue(BOT_ACTION_TYPE_ATTACK) <= 2 then
			bot:ActionImmediate_Ping(enemy:GetLocation().x, enemy:GetLocation().y, true)
			bot:ActionQueue_AttackUnit(enemy, false)
		else
			local fountainLoc = J.GetTeamFountain()
			bot:Action_MoveToLocation(fountainLoc)
		end
	end
end

function MoveAwayFromTarget(target, keepDistance)
	if J.IsValidHero(target) and GetUnitToUnitDistance(bot, target) < keepDistance then
		if GetUnitToLocationDistance(target, J.GetTeamFountain()) > GetUnitToLocationDistance(bot, J.GetTeamFountain()) then
			bot:Action_MoveToLocation(J.GetTeamFountain())
		else
			bot:Action_MoveToLocation(J.Utils.GetOffsetLocationTowardsTargetLocation(target:GetLocation(), bot:GetLocation(), keepDistance * 2))
		end
	end
end

function ActualGankDesire()
	SetupTwinGates()

	if J.IsInLaningPhase()
	and not bot:WasRecentlyDamagedByAnyHero(2)
	and (botTarget == nil or #nInRangeEnemy <= 0 or nInRangeEnemy[1] ~= botTarget) then
		local botLvl = bot:GetLevel()
		if (J.GetPosition(bot) == 2 and botLvl >= 6 and J.GetHP(bot) > 0.7 and J.GetMP(bot) > 0.5) -- mid player roaming
		or (J.GetPosition(bot) > 3 and botLvl > 3 and J.GetHP(bot) > 0.6 and J.GetMP(bot) > 0.5) -- supports roaming
		then
			return CheckLaneToGank(J.GetPosition(bot))
		end
	end
	return BOT_MODE_DESIRE_NONE
end

function SetupTwinGates()
	if #TwinGates == 0 then
		for _, unit in pairs(GetUnitList(UNIT_LIST_ALL))
		do
			local name = unit:GetUnitName()
			if name == 'npc_dota_unit_twin_gate'
			then
				table.insert(TwinGates, unit)
				print("Twin gate: " .. name .. ". " .. tostring(unit:GetLocation()))
			end
			if #TwinGates >= 2 then
				break
			end
		end
	end
end

function ThinkActualGankingInLanes()
	if laneToGank ~= nil then
		-- Abort gank if the target lane no longer has enemies (they left)
		local nEnemiesInGankLane = J.GetEnemyCountInLane(laneToGank)
		if nEnemiesInGankLane == 0 then
			laneToGank = nil
			return
		end

		local targetLoc = GetLaneFrontLocation(GetTeam(), laneToGank, -300)
		local distanceToGankLoc = GetUnitToLocationDistance(bot, targetLoc)
		if distanceToGankLoc > 5000 then
			if J.GetPosition(bot) > 3
			and targetGate ~= nil
			and enableGateUsage
			then
				print('Trying to use gate '..botName)
				local distanceToGate = GetUnitToUnitDistance(bot, targetGate)
				if distanceToGate > 350 then
					bot:Action_MoveToLocation(targetGate:GetLocation())
					return
				elseif gateWarp:IsFullyCastable()
				then
					bot:Action_UseAbilityOnEntity(gateWarp, targetGate)
					return
				end
			end
		end

		if distanceToGankLoc > bot:GetAttackRange() + 300 and bot:WasRecentlyDamagedByAnyHero(1.5) then
			bot:Action_MoveToLocation(targetLoc)
		end
		if distanceToGankLoc < 600 and DotaTime() - arriveGankLocTime > gankTimeAfterArrival * 1.1 then
			arriveGankLocTime = DotaTime()
		end
		if DotaTime() - arriveGankLocTime > gankTimeAfterArrival then
			laneToGank = nil
		end
	end
end

function OnStart()
end

function OnEnd()
	laneToGank = nil
	targetGate = nil
	if shouldGoBackToFountain and IsInHealthyState() then
		shouldGoBackToFountain = false
	end
end

function IsInHealthyState()
	return botName ~= 'npc_dota_hero_huskar' and J.GetHP(bot) > 0.7 and J.GetMP(bot) > 0.6
end

function CheckLaneToGank(botPosition)

	-- Don't gank if enemies are already near us (we're in a fight)
	if #J.GetEnemiesNearLoc(bot:GetLocation(), 800) > 0 then
		return BOT_MODE_DESIRE_NONE
	end

	-- If we committed to a gank, REVALIDATE before continuing
	-- (enemy may have left the lane since we decided)
	if DotaTime() - lastGankDecisionTime <= gankDecisionHoldTime and laneToGank ~= nil then
		local nEnemiesStillThere = J.GetEnemyCountInLane(laneToGank)
		if nEnemiesStillThere == 0 then
			-- Enemy left — cancel the gank, go back to what we were doing
			laneToGank = nil
			lastGankDecisionTime = 0
			return BOT_MODE_DESIRE_NONE
		end
		return BOT_ACTION_DESIRE_VERYHIGH
	end

	-- Cores should NOT gank during laning — they lose too much farm/XP
	local nPos = J.GetPosition(bot)
	if J.IsInLaningPhase() then
		if nPos == 1 or nPos == 2 then
			return BOT_MODE_DESIRE_NONE
		end
	end

	local botLevel = bot:GetLevel()
	local botLvlTooLow = (nPos == 1 and botLevel < 10) or
		(nPos == 2 and botLevel < 8) or
		(nPos == 3 and botLevel < 6) or
		(nPos == 4 and botLevel < 4) or
		(nPos == 5 and botLevel < 3)

	if (DotaTime() - lastGankDecisionTime < gankGapTime and lastGankDecisionTime ~= 0)
		or botLvlTooLow then
		return BOT_MODE_DESIRE_NONE
	end

	if not HasSufficientMana(300) then
		return BOT_MODE_DESIRE_NONE
	end

	-- Evaluate each lane for gank viability
	local bestLane = nil
	local bestDesire = 0

	for _, lane in pairs(laneAndT1s) do
		local enemyCountInLane = J.GetEnemyCountInLane(lane[1])
		if enemyCountInLane > 0 then
			local tTower = GetTower(GetTeam(), lane[2])
			if tTower ~= nil then
				local laneFront = GetLaneFrontLocation(GetTeam(), lane[1], 0)
				local laneFrontToT1Dist = GetUnitToLocationDistance(tTower, laneFront)
				local nInRangeAlly = J.GetAlliesNearLoc(laneFront, 1200)
				local botDistToLane = GetUnitToLocationDistance(bot, laneFront)

				-- Skip lanes that are too far away (> 4000 units without a TP
				-- scroll — would take too long) and our own assigned lane
				local bTooFar = botDistToLane > 4000 and not J.HasItem(bot, 'item_tpscroll')
				if not bTooFar and lane[1] ~= bot:GetAssignedLane() then
					-- Better gank conditions: enemy is pushed forward (closer to our tower)
					-- AND we have at least 1 ally there to help
					local bEnemyOverextended = laneFrontToT1Dist < 2500
					local bAllyPresent = #nInRangeAlly >= 1

					if bEnemyOverextended and bAllyPresent then
						local desire = RemapValClamped(botDistToLane, 4000, 600, BOT_ACTION_DESIRE_MODERATE, BOT_ACTION_DESIRE_HIGH)
						-- Bonus desire if enemy is outnumbered
						if enemyCountInLane <= #nInRangeAlly then
							desire = desire + 0.1
						end
						if desire > bestDesire then
							bestDesire = desire
							bestLane = lane[1]
						end
					end
				end
			end
		end
	end

	if bestLane then
		laneToGank = bestLane
		lastGankDecisionTime = DotaTime()
		return Clamp(bestDesire, 0, BOT_ACTION_DESIRE_VERYHIGH)
	end

	return BOT_MODE_DESIRE_NONE
end

function HasSufficientMana(nMana)
	return bot:GetMana() > nMana and botName ~= 'npc_dota_hero_huskar'
end

function GetGateNearLane(laneLoc)
	local minDis = 99999
	local tGate
	for _, gate in pairs(TwinGates)
	do
		local distanceToGate = GetUnitToLocationDistance(gate, laneLoc)
		if distanceToGate < minDis then
			tGate = gate
			minDis = distanceToGate
		end
	end
	return tGate
end


function TinkerWaitInBaseAndHeal()
	if botName == 'npc_dota_hero_tinker'
	and bot.healInBase
	and GetUnitToLocationDistance(bot, J.GetTeamFountain()) < 500
	then
		return true
	end

	return false
end

function GetMortimerKissesTarget()
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES))
	do
		if J.IsValidHero(enemyHero)
		and J.IsInRange(bot, enemyHero, 3000 + (275 / 2))
		and J.CanCastOnNonMagicImmune(enemyHero)
		and not J.IsInRange(bot, enemyHero, 600)
		then
			if J.IsLocationInChrono(enemyHero:GetLocation())
			or J.IsLocationInBlackHole(enemyHero:GetLocation())
			then
				return enemyHero
			end
		end

		if J.IsValidHero(enemyHero)
		and J.IsInRange(bot, enemyHero, 3000 + (275 / 2))
		and J.CanCastOnNonMagicImmune(enemyHero)
		and not J.IsInRange(bot, enemyHero, 600)
		and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
		and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
		and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
		and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
		then
			return enemyHero
		end
	end

	local nCreeps = bot:GetNearbyCreeps(1600, true)
	if J.IsValid(nCreeps[1])
	then
		return nCreeps[1]
	end

	return nil
end

function ConsiderUseTango()
	if bot:HasModifier('modifier_tango_heal') then return BOT_ACTION_DESIRE_NONE, nil end

	tangoDesire = 0
	tangoSlot = J.FindItemSlotNotInNonbackpack(bot, "item_tango")
	if tangoSlot < 0 then
		tangoSlot = J.FindItemSlotNotInNonbackpack(bot, "item_tango_single")
	end
	if tangoSlot >= 0
	and bot:OriginalGetMaxHealth() - bot:OriginalGetHealth() > 250
	and J.GetHP(bot) < 0.6
	and not J.IsAttacking(bot)
	and not bot:WasRecentlyDamagedByAnyHero(2) then
		local trees = bot:GetNearbyTrees( 800 )
		local targetTree = trees[1]
		local nearEnemyList = J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE )
		local nearestEnemy = nearEnemyList[1]
		local nearTowerList = bot:GetNearbyTowers( 1400, true )
		local nearestTower = nearTowerList[1]
		if targetTree ~= nil
		then
			local targetTreeLoc = GetTreeLocation( targetTree )
			if IsLocationVisible( targetTreeLoc )
				and IsLocationPassable( targetTreeLoc )
				-- and ( #nearEnemyList == 0 or not J.IsInRange( bot, nearestEnemy, 800 ) )
				and ( #nearEnemyList == 0 or GetUnitToLocationDistance( bot, targetTreeLoc ) * 1.6 < GetUnitToUnitDistance( bot, nearestEnemy ) )
				and ( #nearTowerList == 0 or GetUnitToLocationDistance( nearestTower, targetTreeLoc ) > 920 )
			then
				return BOT_ACTION_DESIRE_HIGH, targetTree
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end

-- Just for TP. Too much back and forth when "forcing" them try to walk to fountain; <- not reliable and misses farm.
function ConsiderWaitInBaseToHeal()
	local ProphetTP = nil
	if botName == 'npc_dota_hero_furion'
	then
		ProphetTP = bot:GetAbilityByName('furion_teleportation')
	end

	if not J.IsInLaningPhase()
	and not (J.IsFarming(bot) and J.IsAttacking(bot))
	and nInRangeEnemy ~= nil and #nInRangeEnemy == 0
	and GetUnitToUnitDistance(bot, GetAncient(GetOpposingTeam())) > 2400
	and (  (TPScroll ~= nil and TPScroll:IsFullyCastable())
		or (ProphetTP ~= nil and ProphetTP:IsTrained() and ProphetTP:IsFullyCastable()))
	then
		if (J.GetHP(bot) < 0.25
			and bot:GetHealthRegen() < 15
			and botName ~= 'npc_dota_hero_huskar'
			and botName ~= 'npc_dota_hero_slark'
			and botName ~= 'npc_dota_hero_necrolyte'
			and not bot:HasModifier('modifier_tango_heal')
			and not bot:HasModifier('modifier_flask_healing')
			and not bot:HasModifier('modifier_alchemist_chemical_rage')
			and not bot:HasModifier('modifier_arc_warden_tempest_double')
			and not bot:HasModifier('modifier_juggernaut_healing_ward_heal')
			and not bot:HasModifier('modifier_oracle_purifying_flames')
			and not bot:HasModifier('modifier_warlock_fatal_bonds')
			and not bot:HasModifier('modifier_item_satanic_unholy')
			and not bot:HasModifier('modifier_item_spirit_vessel_heal')
			and not bot:HasModifier('modifier_item_urn_heal'))
		or (((J.IsCore(bot) and J.GetMP(bot) < 0.25 and (J.GetHP(bot) < 0.75 and bot:GetHealthRegen() < 10))
				or ((not J.IsCore(bot) and J.GetMP(bot) < 0.25 and bot:GetHealthRegen() < 10)))
			and botName ~= 'npc_dota_hero_necrolyte'
			-- [waitclar / owner priority P2, 2026-09-06] The leg above this one
			-- refuses the trip on TEN regen modifiers; this one, which fires on
			-- MANA, refuses on none -- and the tree already has a word for
			-- "mana is arriving in the field".
			--
			-- The defect, as the two legs of one `or`.  Both legs send the bot
			-- home with a TP.  The HP leg (20 lines up) is triggered by
			-- `J.GetHP(bot) < 0.25` and vetoes on ten modifiers meaning "this
			-- hero is already recovering, or must not be moved" -- among them
			-- oracle_purifying_flames, warlock_fatal_bonds, item_satanic_unholy,
			-- the urn and the spirit vessel, and two (chemical rage, tempest
			-- double) that are not consumables at all.  That last part is the
			-- point: the list reached for everything it could think of, so what
			-- it skipped it skipped on purpose or not at all.  This leg is
			-- triggered by `J.GetMP(bot) < 0.25` and carries no supply veto of
			-- any kind.  So a bot that has already drunk a clarity -- mana
			-- arriving, in the field, paid for -- still reads as "needs to go to
			-- base for mana" and TPs.
			--
			-- ⭐ IT IS THIS LEG THAT ACTUALLY FIRES, measured rather than
			-- assumed: over the 1012 live hero frames this corpus carries,
			-- ConsiderWaitInBaseToHeal answers true on 6, and 5 of the 6 come
			-- through THIS leg (tests/_waitclar_sweep.lua).  The pinned frame is
			-- one of them and is the cleanest statement of the defect the corpus
			-- has: f_260819_222559_od_eclipse_solo, medusa at hp = 1.000 (FULL
			-- health), mp = 0.149, holding a ticking 'modifier_clarity_potion'
			-- -- and the shipped function says go home.
			--
			-- ⭐⭐ WHY THE CLARITY, AND WHY THIS IS NOT THE "does mana count as
			-- sustain" OPINION.  That opinion was priced and REFUSED the same
			-- round on J.ShouldStayAndRegen, whose whole domain is an HP band
			-- (0.18-0.75): counting a mana consumable there would hold a HURT
			-- bot in the field with no health arriving.  Here the quantity the
			-- veto is about and the quantity the trigger reads are THE SAME
			-- QUANTITY -- this leg fires on `GetMP < 0.25` and the clarity
			-- restores mana -- so no new opinion is needed.  Three shipped sites
			-- already treat a ticking clarity as a reason not to go home: the
			-- '撤退:3' and '回复状态' home-TP branches
			-- (ability_item_usage_generic ~5661, ~5975) both list it, and
			-- FunLib/aba_buff.lua's `hero_is_healing` names it.  A fourth gives
			-- it a CAST PATH, which is exactly what the refused urn widening
			-- lacked: X.ConsiderItemDesire["item_clarity"] drinks one at
			-- `GetMP < 0.4` with no enemy in range, ungated -- so the modifier
			-- being up means this bot pressed the button itself.
			--
			-- Direction is fixed by CONSTRUCTION: a veto appended to a
			-- conjunction, so arming can only turn this leg's TRUE into FALSE,
			-- i.e. only PREVENT base trips.  It can never send home a bot that
			-- was not already going.  Un-armed, J.IsSoakCandidate is the first
			-- conjunct inside the `not (...)`, so it short-circuits to
			-- `not false` = true and neither engine call below it happens.
			-- Gated STANDALONE -- one id in this condition, never a conjunction
			-- of two (the 'pullcad' trap).  Turbo is NOT structural on this path
			-- (nothing above asks), so it is asked explicitly here.
			--
			-- Honest bounds.  (1) The domain is ONE frame of 1012 and that is a
			-- measurement, not an apology: 12 frames carry the modifier, 3 of
			-- those are also under `GetMP < 0.25`, and 1 clears the outer guard
			-- (not laning, no enemy inside 1200, >2400 from the enemy ancient, a
			-- castable TP).  tests/_waitclar_sweep.lua emits a row per carrier
			-- with the clause that stopped it, so "the corpus has no clarities"
			-- can never read the same as "it has clarities this function rejects
			-- earlier".  (2) It does not suppress an ESCAPE: the outer guard this
			-- leg sits under already requires no enemy hero within 1200 and more
			-- than 2400 units from the enemy ancient, so the trip it cancels is a
			-- supply trip, not a retreat.  (3) A clarity is interrupted by hero
			-- damage, so a frame is an instant and the mana may not all arrive --
			-- the magnitude question 'fieldsip' owns on the other family; this
			-- lever does not borrow it.  (4) It leaves the HP leg above
			-- untouched, including the 'modifier_bottle_regeneration' that list
			-- is ALSO missing -- a separate finding with a separate domain (0
			-- frames on this corpus: all 3 bottle carriers sit above the 0.25 HP
			-- trigger), filed rather than bundled in.
			and not (J.IsSoakCandidate('waitclar')
				and J.IsModeTurbo()
				and bot:HasModifier('modifier_clarity_potion'))
			and not (J.IsPushing(bot) and #J.GetAlliesNearLoc(bot:GetLocation(), 900) >= 3))
		then
			ShouldWaitInBaseToHeal = true
			return true
		end
	end

	return false
end

function ConsiderHeroMoveOutsideFountain()
	if DotaTime() < 0 then return false end
	if bot:DistanceFromFountain() > MoveOutsideFountainDistance then return false end

	if ((bot:HasModifier('modifier_fountain_aura_buff') -- in fountain with high hp
		and J.GetHP(bot) > 0.95)
	and (botName == 'npc_dota_hero_huskar' -- is huskar (ignore mana)
		or (bot:GetActiveMode() == BOT_MODE_ITEM -- is stuck in item mode
			and J.GetMP(bot) > 0.95)))
	then
		return true
	end
	if bot:GetActiveMode() == BOT_MODE_ITEM then
		for _, droppedItem in pairs(GetDroppedItemList()) do
            if droppedItem ~= nil
            and GetUnitToLocationDistance(bot, droppedItem.location) < 1200
            then
				local iName = droppedItem.item:GetName()
				if not (iName == 'item_aegis'
				or iName == 'item_rapier'
				or iName == 'item_cheese'
				or iName == 'item_gem')
				then
					return true
				end
            end
        end
	end

	return false
end

function CanBeAffectedByChainFrost()
	if bot:HasModifier("modifier_black_king_bar_immune") or bot:IsMagicImmune() then
		return false
	end
	local searchRange = nChainFrostBounceDistance
	if J.HasEnemyIceSpireNearby(bot, searchRange) then return true end
	if bot:HasModifier('modifier_lich_chainfrost_slow') then
		local allyCreeps = bot:GetNearbyCreeps(searchRange, false)
		if #allyCreeps > 0 then return true end
		local allyHeores = bot:GetNearbyHeroes(searchRange, false, BOT_MODE_NONE)
		if #allyHeores > 1 then return true end
	end
	return J.AnyAllyAffectedByChainFrost(bot, searchRange)
end

function ConsiderGeneralRoamingInConditions()
	if J.GetHP(bot) < 0.35 then
		return BOT_ACTION_DESIRE_NONE
	end

	-- if not botTarget then
	-- 	botTarget = J.GetAttackableWeakestUnit( bot, 1500, true, true )
	-- 	bot:SetTarget( botTarget )
	-- end

	if bot:HasModifier("modifier_item_mask_of_madness_berserk") then
		if J.IsValid(botTarget) and J.GetHP(bot) > 0.3 then
			return BOT_ACTION_DESIRE_ABSOLUTE
		end
	end

	if J.GetModifierTime(bot, "modifier_flask_healing") >= 1.5 then
		if #nInCloseRangeEnemy >= 1 and J.GetHP(bot) < 0.8 then
			return BOT_ACTION_DESIRE_ABSOLUTE
		end
	end

	if bot:HasModifier("modifier_skeleton_king_reincarnation_scepter_active") or bot:HasModifier("modifier_item_helm_of_the_undying_active") then
		if not J.IsValidHero(botTarget) then
			botTarget = J.GetAttackableWeakestUnit( bot, 1600, true, true )
		end
		if J.IsValidHero(botTarget) then
			bot:SetTarget( botTarget )
			return BOT_ACTION_DESIRE_ABSOLUTE * 2
		end
	end

	if bot:HasModifier("modifier_razor_static_link_debuff") then
		local staticLinkDebuffStack = J.GetModifierCount( bot, "modifier_razor_static_link_debuff" )
		if staticLinkDebuffStack > lastStaticLinkDebuffStack then
			local enemy = GetTargetEnemy("npc_dota_hero_razor")
			if enemy ~= nil and J.GetHP(bot) - 0.2 < J.GetHP(enemy) and GetUnitToUnitDistance(bot, enemy) <= 850 then
				return BOT_ACTION_DESIRE_ABSOLUTE * 1.1
			end
		end
	end

	if bot:HasModifier("modifier_bloodseeker_rupture") then
		if J.IsRunning(bot) and not J.IsAttacking(bot) then
			return 0.6
		end
		if not nInCloseRangeEnemy or #nInCloseRangeEnemy == 0 then
			return 0.7
		end
	end

	if botName == 'npc_dota_hero_lone_druid'
	and not bot:HasModifier("modifier_lone_druid_true_form") then
		if nInRangeEnemy and J.IsValidHero(nInRangeEnemy[1])
		and J.IsInRange(bot, nInRangeEnemy[1], math.max(bot:GetAttackRange(), nInRangeEnemy[1]:GetAttackRange()) - 250) then
			return 0.6
		end
	end

	local quillSparyStack = J.GetModifierCount(bot, "modifier_bristleback_quill_spray")
	if quillSparyStack >= 3 then -- 14s
		local enemy = GetTargetEnemy("npc_dota_hero_bristleback")
		if enemy ~= nil
		and (#nInRangeEnemy >= #nInRangeAlly or enemy:GetLevel() >= bot:GetLevel())
		and J.GetHP(bot) < J.GetHP(enemy) + 0.2
		and GetUnitToUnitDistance(bot, enemy) <= 900
		and GetUnitToLocationDistance(bot, J.GetTeamFountain()) > 1000 then
			return RemapValClamped(quillSparyStack / J.GetHP(bot), 10, 50, BOT_ACTION_DESIRE_LOW, BOT_ACTION_DESIRE_ABSOLUTE)
		end
	end

	if bot:HasModifier("modifier_primal_beast_trample") then
		local enemy = GetTargetEnemy("npc_dota_hero_primal_beast")
		local distanceToEnemy =  GetUnitToUnitDistance(bot, enemy)
		if enemy ~= nil and J.GetHP(bot) - 0.2 < J.GetHP(enemy) and distanceToEnemy <= 500 and distanceToEnemy > 250 then
			return BOT_ACTION_DESIRE_ABSOLUTE
		end
	end

	AnyUnitAffectedByChainFrost = CanBeAffectedByChainFrost()
	if AnyUnitAffectedByChainFrost then
		local hasLowHpEnemy = false
		for _, enemy in pairs(nInCloseRangeEnemy) do
			if J.Utils.IsValidHero(enemy)
			and not J.IsSuspiciousIllusion(enemy)
			and J.GetHP(enemy) < 0.2 then
				hasLowHpEnemy = true
			end
		end
		if not hasLowHpEnemy then
			local crowd = #nInCloseRangeAlly
			local hp = J.GetHP(bot)
			return Clamp(0.35 + 0.35 * (crowd >= 2 and 1 or 0) + 0.3 * (hp < 0.6 and 1 or 0), 0.35, 0.85)
			-- return RemapValClamped(hp, 0, 0.6, BOT_ACTION_DESIRE_NONE, 0.98)
		end
		AnyUnitAffectedByChainFrost = false
	end

	-- HasPossibleWallOfReplicaAround = J.Utils.HasPossibleWallOfReplicaAround(bot)
	-- if HasPossibleWallOfReplicaAround then
	-- 	local hasLowHpEnemy = false
	-- 	for _, enemy in pairs(nInCloseRangeEnemy) do
	-- 		if J.Utils.IsValidHero(enemy)
	-- 		and not J.IsSuspiciousIllusion(enemy)
	-- 		and J.GetHP(enemy) < 0.2 then
	-- 			hasLowHpEnemy = true
	-- 		end
	-- 	end
	-- 	if not hasLowHpEnemy then
	-- 		return BOT_ACTION_DESIRE_ABSOLUTE
	-- 	end
	-- end

	if bot:GetActiveMode() == BOT_MODE_ITEM
	and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH
	and (botName == 'npc_dota_hero_lone_druid_bear' or bot:HasModifier('modifier_arc_warden_tempest_double') or J.IsMeepoClone(bot))
	then
		for _, droppedItem in pairs(GetDroppedItemList()) do
            if droppedItem ~= nil
            and droppedItem.item:GetName() == 'item_aegis'
            and GetUnitToLocationDistance(bot, droppedItem.location) < 300
            then
                return BOT_ACTION_DESIRE_ABSOLUTE
            end
        end
	end

	-- 留一个bot抵御超级兵 看家
	-- if J.GetHP(GetAncient(bot:GetTeam())) < 0.99 then
		
	-- end

	-- 目前可能会导致bot往敌方队伍里走或者浪费时间乱走被团灭
	local isBotTryingHardToAttack = J.IsAttacking(bot) or (bot:GetActiveMode() == BOT_MODE_ATTACK and bot:GetActiveModeDesire() > 0.7)
	ShouldBotsSpreadOut = not isBotTryingHardToAttack and J.Utils.ShouldBotsSpreadOut(bot, 450)
	if ShouldBotsSpreadOut then
		return 0.91
	end

	if J.IsInLaningPhase() then

		-- 状态不好 回泉水补给
		if not bot:WasRecentlyDamagedByAnyHero(1.5)
		and not J.HasHealingItem(bot)
		and not botName == 'npc_dota_hero_huskar'
		and (
			(shouldGoBackToFountain and not IsInHealthyState())
			or (J.GetHP(bot) < 0.22 or (J.GetHP(bot) < 0.3 and J.GetMP(bot) < 0.22))
		) then
			shouldGoBackToFountain = true
			return BOT_ACTION_DESIRE_ABSOLUTE * 1.5
		end

		if J.GetModifierCount(bot, "modifier_nevermore_shadowraze_debuff") >= 2 then -- 7s
			local enemy = GetTargetEnemy("npc_dota_hero_nevermore")
			if enemy ~= nil and J.GetHP(bot) < J.GetHP(enemy) and GetUnitToUnitDistance(bot, enemy) <= 1200 then
				return BOT_ACTION_DESIRE_VERYHIGH * 1.2
			end
		end

		if J.GetModifierCount(bot, "modifier_monkey_king_quadruple_tap_counter") >= 2 then -- 7 - 10s
			local enemy = GetTargetEnemy("npc_dota_hero_monkey_king")
			if enemy ~= nil and J.GetHP(bot) < J.GetHP(enemy) and GetUnitToUnitDistance(bot, enemy) <= enemy:GetAttackRange() * 3 then
				return BOT_ACTION_DESIRE_VERYHIGH * 1.2
			end
		end

		if J.GetModifierCount(bot, "modifier_viper_poison_attack_slow") >= 2 then -- 4s
			local enemy = GetTargetEnemy("npc_dota_hero_viper")
			if enemy ~= nil and J.GetHP(bot) < J.GetHP(enemy) and GetUnitToUnitDistance(bot, enemy) <= enemy:GetAttackRange() * 2 then
				return BOT_ACTION_DESIRE_VERYHIGH * 1.2
			end
		end

		if J.GetModifierCount(bot, "modifier_huskar_burning_spear_debuff") >= 3 then -- 9s
			local enemy = GetTargetEnemy("npc_dota_hero_huskar")
			if enemy ~= nil and J.GetHP(bot) < J.GetHP(enemy) + 0.2 and GetUnitToUnitDistance(bot, enemy) <= enemy:GetAttackRange() * 2 then
				return BOT_ACTION_DESIRE_VERYHIGH * 1.2
			end
		end

		if J.GetModifierCount(bot, "modifier_batrider_sticky_napalm") >= 3 then -- 6s
			local enemy = GetTargetEnemy("npc_dota_hero_batrider")
			if enemy ~= nil and J.GetHP(bot) < J.GetHP(enemy) + 0.2 and GetUnitToUnitDistance(bot, enemy) <= enemy:GetAttackRange() * 3 then
				return BOT_ACTION_DESIRE_VERYHIGH * 1.2
			end
		end

		if bot:HasModifier("modifier_undying_tombstone_zombie_deathstrike_slow") then
			cachedTombstoneZombieSlowState = DotaTime()
			if J.IsValidTarget(botTarget) and not J.Utils.IsUnitWithName(botTarget, "tombstone") then
				local enemy = J.FindEnemyUnit("tombstone")
				if not enemy then
					enemy = GetTargetEnemy("npc_dota_hero_undying")
				end
				if J.GetHP(bot) < 0.8
				and ((J.IsValid(enemy) and GetUnitToUnitDistance(enemy, bot) < 1200) or (DotaTime() - cachedTombstoneZombieSlowState < 3))
				and J.IsValidHero(nInRangeEnemy[1]) and J.GetHP(nInRangeEnemy) > 0.35 then
					return BOT_ACTION_DESIRE_VERYHIGH * 1.2
				end
			end
		end

		-- long duration debuff
		if not J.WeAreStronger(bot, 1200) then
			if J.GetModifierCount(bot, "modifier_slark_essence_shift_debuff_counter") >= 2 then -- 20 - 80s
				local enemy = GetTargetEnemy("npc_dota_hero_slark")
				if enemy ~= nil and J.GetHP(bot) < J.GetHP(enemy) + 0.1 and GetUnitToUnitDistance(bot, enemy) <= 750 then
					return BOT_ACTION_DESIRE_ABSOLUTE * 1.1
				end
			end

			if J.GetModifierCount(bot, "modifier_silencer_glaives_of_wisdom_debuff_counter") >= 2 then -- 20 - 35s
				local enemy = GetTargetEnemy("npc_dota_hero_silencer")
				if enemy ~= nil and J.GetHP(bot) < 0.5 and J.GetHP(bot) < J.GetHP(enemy) + 0.1 and GetUnitToUnitDistance(bot, enemy) <= enemy:GetAttackRange() * 2.5 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end

			if J.GetModifierCount(bot, "modifier_ursa_fury_swipes_damage_increase") >= 2 then -- 8 - 20s
				local enemy = GetTargetEnemy("npc_dota_hero_ursa")
				if enemy ~= nil and J.GetHP(bot) < J.GetHP(enemy) + 0.1 and GetUnitToUnitDistance(bot, enemy) <= 450 then
					return BOT_ACTION_DESIRE_VERYHIGH
				end
			end

			if bot:HasModifier("modifier_dazzle_poison_touch") then -- 5s - forever
				local enemy = GetTargetEnemy("npc_dota_hero_dazzle")
				if enemy ~= nil and J.GetHP(bot) < 0.6 and J.GetHP(bot) < J.GetHP(enemy) + 0.1 and GetUnitToUnitDistance(bot, enemy) <= enemy:GetAttackRange() * 2 then
					return BOT_ACTION_DESIRE_VERYHIGH
				end
			end

			if bot:HasModifier("modifier_maledict") then -- 5s - forever
				local enemy = GetTargetEnemy("npc_dota_hero_witch_doctor")
				if enemy ~= nil and J.GetHP(bot) < 0.6 and J.GetHP(bot) < J.GetHP(enemy) + 0.1 and GetUnitToUnitDistance(bot, enemy) <= enemy:GetAttackRange() * 2 then
					return BOT_ACTION_DESIRE_VERYHIGH * 1.2
				end
			end
		end

		-- 尝试勾引
		if #nInRangeEnemy >= 1
		and #allyTowers >= 1
		and GetUnitToUnitDistance(allyTowers[1], bot) < 1600
		and bot:GetActiveModeDesire() < 0.9
		and #nInRangeAlly <= #nInRangeEnemy then
			for _, enemy in pairs(nInRangeEnemy) do
				if J.Utils.IsValidHero(enemy) then
					if enemy:IsFacingLocation(bot:GetLocation(), 45)
					and J.IsInRange(bot, enemy, enemy:GetAttackRange() * 1.5 + 550)
					and J.GetHP(enemy) > J.GetHP(bot) - 0.15
					and bot:WasRecentlyDamagedByAnyHero(5)
					and J.GetHP(bot) < 0.75 and J.GetHP(bot) > 0.3 -- don't block real retreat action
					then
						trySeduce = true
						return BOT_ACTION_DESIRE_VERYHIGH
					end
				end
			end
		end
	end

	if bot:WasRecentlyDamagedByTower(0.2) then
		if #nInCloseRangeAlly >= 2 and J.GetHP(nInCloseRangeAlly[2]) > J.GetHP(bot) then
			bot:Action_AttackUnit(nInCloseRangeAlly[2], true)
		else
			local allyCreeps = bot:GetNearbyCreeps(1000, false)
			if #allyCreeps >= 1 and J.IsValid(allyCreeps[1]) then
				bot:Action_AttackUnit(allyCreeps[1], true)
			end
		end
	end

	-- local actualGankingDesire = ActualGankDesire()
	-- if actualGankingDesire > 0 then
	-- 	lastGankDecisionTime = DotaTime()
	-- 	return actualGankingDesire
	-- end
	return BOT_ACTION_DESIRE_NONE
end

function GetTargetEnemy(unitName)
	for _, enemyHero in pairs(nInRangeEnemy)
	do
		if J.IsValidHero(enemyHero) and enemyHero:GetUnitName() == unitName then
			return enemyHero
		end
	end
	return nil
end

------------------------------
-- Hero Channel/Kill/CC abilities
------------------------------
-- ConsiderHeroSpecificRoaming['npc_dota_hero_rubick'] = function ()
-- 	if bot:IsChanneling() or bot:IsUsingAbility() or bot:IsCastingAbility()
-- 	then
-- 		return BOT_MODE_DESIRE_ABSOLUTE
-- 	end
-- 	return BOT_MODE_DESIRE_NONE
-- end

function CheckHighPriorityChannelAbility(abilityName)
	if cAbility == nil then cAbility = bot:GetAbilityByName(abilityName) end;
	if cAbility:IsTrained() and (cAbility:IsInAbilityPhase() or bot:IsChanneling()) then
		return BOT_MODE_DESIRE_ABSOLUTE;
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_pugna'] = function ()
	return CheckHighPriorityChannelAbility("pugna_life_drain")
end

ConsiderHeroSpecificRoaming['npc_dota_hero_drow_ranger'] = function ()
	return CheckHighPriorityChannelAbility("drow_ranger_multishot")
end

ConsiderHeroSpecificRoaming['npc_dota_hero_shadow_shaman'] = function ()
	return CheckHighPriorityChannelAbility("shadow_shaman_shackles")
end

ConsiderHeroSpecificRoaming['npc_dota_hero_clinkz'] = function ()
	return CheckHighPriorityChannelAbility("clinkz_burning_barrage")
end

ConsiderHeroSpecificRoaming['npc_dota_hero_tiny'] = function ()
	return CheckHighPriorityChannelAbility("tiny_tree_channel")
end

ConsiderHeroSpecificRoaming['npc_dota_hero_hoodwink'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("hoodwink_sharpshooter") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier('modifier_hoodwink_sharpshooter_windup') then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
end

ConsiderHeroSpecificRoaming['npc_dota_hero_void_spirit'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("void_spirit_dissimilate") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier("modifier_void_spirit_dissimilate_phase")
		then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_elder_titan'] = function ()
	return CheckHighPriorityChannelAbility("elder_titan_echo_stomp")
end

ConsiderHeroSpecificRoaming['npc_dota_hero_primal_beast'] = function ()
	cAbility = bot:GetAbilityByName("primal_beast_onslaught")
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier('modifier_primal_beast_onslaught_windup') or bot:HasModifier('modifier_prevent_taunts') or bot:HasModifier('modifier_primal_beast_onslaught_movement_adjustable') then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end

	cAbility = bot:GetAbilityByName("primal_beast_trample")
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or (bot:HasModifier('modifier_primal_beast_trample') and J.GetHP(bot) > 0.3) then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end

	cAbility = bot:GetAbilityByName("primal_beast_pulverize")
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier('modifier_primal_beast_pulverize_self') then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_batrider'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("batrider_flaming_lasso") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier("modifier_batrider_flaming_lasso_self")
		then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_enigma'] = function ()
	return CheckHighPriorityChannelAbility("enigma_black_hole")
end

ConsiderHeroSpecificRoaming['npc_dota_hero_keeper_of_the_light'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("keeper_of_the_light_illuminate") end
	if cAbility:IsInAbilityPhase() or bot:IsChanneling() or bot:HasModifier('modifier_keeper_of_the_light_illuminate') then
		return BOT_MODE_DESIRE_ABSOLUTE
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_meepo'] = function ()
	return CheckHighPriorityChannelAbility("meepo_poof")
end

ConsiderHeroSpecificRoaming['npc_dota_hero_monkey_king'] = function ()
	-- Protect Primal Spring channel
	cAbility = bot:GetAbilityByName("monkey_king_primal_spring")
	if cAbility ~= nil and cAbility:IsTrained() then
		if cAbility:IsInAbilityPhase() or bot:IsChanneling() then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end

	-- After landing from Tree Dance, hold position briefly to avoid
	-- erratic movement (tree_dance_status tracks the jump timing)
	if not bot:IsChanneling() and bot.tree_dance_status then
		local eta = bot.tree_dance_status.eta or 0
		local elapsed = DotaTime() - (bot.tree_dance_status.cast_time or 0)
		if elapsed > (3.0 + eta) and elapsed < (4.0 + eta) then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end

	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_nyx_assassin'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("nyx_assassin_vendetta") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier('modifier_nyx_assassin_vendetta')
		then
			if bot.canVendettaKill
			then
				return BOT_MODE_DESIRE_ABSOLUTE
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_pangolier'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("pangolier_gyroshell") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier('modifier_pangolier_gyroshell')
		then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_phoenix'] = function ()
	cAbility = bot:GetAbilityByName("phoenix_supernova")
	if cAbility:IsTrained()
	then
		if bot:HasModifier('modifier_phoenix_supernova_hiding') then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end

	cAbility = bot:GetAbilityByName("phoenix_sun_ray")
	if cAbility:IsTrained()
	then
		if bot:HasModifier('modifier_phoenix_sun_ray')
		then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
end

ConsiderHeroSpecificRoaming['npc_dota_hero_puck'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("puck_phase_shift") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier('modifier_puck_phase_shift') then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_ringmaster'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("ringmaster_tame_the_beasts") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier("modifier_ringmaster_tame_the_beasts") then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_snapfire'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("snapfire_mortimer_kisses") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier('modifier_snapfire_mortimer_kisses') then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_spirit_breaker'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("spirit_breaker_charge_of_darkness") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:HasModifier('modifier_spirit_breaker_charge_of_darkness') then
			return BOT_MODE_DESIRE_ABSOLUTE * 1.2
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_windrunner'] = function ()
	return CheckHighPriorityChannelAbility("windrunner_powershot")
end
ConsiderHeroSpecificRoaming['npc_dota_hero_invoker'] = function ()
	if J.IsValid(botTarget)
	and GetUnitToUnitDistance(bot, botTarget) < bot:GetAttackRange() - 100
	and (botTarget:HasModifier("modifier_invoker_tornado") or botTarget:HasModifier("modifier_item_wind_waker")
		or botTarget:HasModifier("modifier_eul_cyclone") or botTarget:HasModifier("modifier_item_cyclone") or botTarget:IsInvulnerable())
	and (J.GetHP(botTarget) > 0.3 or J.GetHP(botTarget) > J.GetHP(bot)) then
		return BOT_MODE_DESIRE_ABSOLUTE * 0.96
	end
end

ConsiderHeroSpecificRoaming['npc_dota_hero_tinker'] = function ()
	if cAbility == nil then cAbility = bot:GetAbilityByName("tinker_rearm") end
	if cAbility:IsTrained()
	then
		if cAbility:IsInAbilityPhase() or bot:IsChanneling() or bot:HasModifier('modifier_tinker_rearm') then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_leshrac'] = function ()
	if bot:HasModifier("modifier_leshrac_diabolic_edict")
	then
		local DiabolicEdict = bot:GetAbilityByName('leshrac_diabolic_edict')
		if DiabolicEdict:IsTrained()
		then
			local nRadius = DiabolicEdict:GetSpecialValueInt('radius')
			if J.IsPushing(bot)
			then
				local nEnemyTowers = bot:GetNearbyTowers(1600, true)
				local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nRadius, true)
				if nEnemyTowers ~= nil and #nEnemyTowers >= 1
				and J.IsValidBuilding(nEnemyTowers[1])
				and J.CanBeAttacked(nEnemyTowers[1])
				and not J.IsInRange(bot, nEnemyTowers[1], nRadius - 75)
				and nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps <= 2
				then
					EdictTowerTarget = nEnemyTowers[1]
					return BOT_MODE_DESIRE_VERYHIGH
				end
			end
		end
	end

	if bot:HasModifier("modifier_leshrac_pulse_nova")
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and J.GetHP(bot) > J.GetHP(botTarget) then
			if GetUnitToUnitDistance(bot, botTarget) > 400
			then
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_lone_druid_bear'] = function ()
	if J.IsTryingtoUseAbility(bot) then return BOT_MODE_DESIRE_NONE end

	local hero = J.Utils.GetLoneDruid(bot).hero
	local heroTarget = hero:GetAttackTarget()
	local hasUltimateScepter = J.Item.HasItem(bot, 'item_ultimate_scepter') or bot:HasModifier('modifier_item_ultimate_scepter_consumed')
    local distanceFromHero = GetUnitToUnitDistance(J.Utils.GetLoneDruid(bot).hero, bot)

    if J.IsValidHero(hero)
	and J.GetHP(bot) >= J.GetHP(hero) - 0.2 -- hp is higher or within 20% lower than hero.
	and J.GetHP(bot) > 0.25
	and not hasUltimateScepter
	then
        if distanceFromHero > BearAttackLimitDistance then
			return BOT_MODE_DESIRE_ABSOLUTE * 1.2
        end
		local avoidDangerous = (#bot:GetNearbyLaneCreeps(400, true) < 3 and #bot:GetNearbyTowers(800, true) == 0) or bot:GetLevel() >= 3
		if J.Utils.IsValidUnit(heroTarget)
		and distanceFromHero <= BearAttackLimitDistance
		and GetUnitToUnitDistance(hero, heroTarget) < BearAttackLimitDistance + 250
		and avoidDangerous
		then
			return BOT_MODE_DESIRE_ABSOLUTE * 1.2
		end

		local target = J.GetAttackableWeakestUnitFromList(hero, hero:GetNearbyHeroes(BearAttackLimitDistance + 250, true, BOT_MODE_NONE))
		if target ~= nil
		and avoidDangerous
		then
			return BOT_MODE_DESIRE_ABSOLUTE * 1.2
		end
    end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_marci'] = function ()
	if bot:HasModifier("modifier_marci_unleash")
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and J.GetHP(bot) > J.GetHP(botTarget) then
			if J.IsInTeamFight(bot, 1500) then
				return BOT_MODE_DESIRE_VERYHIGH
			end
			if J.IsGoingOnSomeone(bot) and #nInRangeEnemy >= 1 then
				return BOT_MODE_DESIRE_ABSOLUTE
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_wisp'] = function ()
	if bot:HasModifier("modifier_wisp_tether") and DotaTime() > 60
	then
		if J.IsValid(bot.stateTetheredHero)
		and J.GetHP(bot) > 0.5
		and GetUnitToUnitDistance(bot, bot.stateTetheredHero) > TetherBreakDistance - 200 then
			return BOT_MODE_DESIRE_ABSOLUTE * 0.85
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_pudge'] = function ()
	local Rot = bot:GetAbilityByName('pudge_rot')
	if Rot ~= nil and Rot:GetToggleState() and J.WeAreStronger(bot, 1200)
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and J.GetHP(bot) > J.GetHP(botTarget) then
			return BOT_MODE_DESIRE_ABSOLUTE * 0.85
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_muerta'] = function ()
	if bot:HasModifier("modifier_muerta_pierce_the_veil_buff")
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and J.GetHP(bot) > 0.2 then
			if J.IsInTeamFight(bot, 1500) then
				return BOT_MODE_DESIRE_VERYHIGH
			end
			if J.IsGoingOnSomeone(bot) and #nInRangeEnemy >= 1 then
				return BOT_MODE_DESIRE_ABSOLUTE
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_razor'] = function ()
	if bot:HasModifier("modifier_razor_static_link_buff")
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidHero(botTarget) and J.GetHP(bot) > 0.3 and J.GetHP(bot) >= J.GetHP(botTarget) then
			if enemyTowers == nil or #enemyTowers == 0 or GetUnitToUnitDistance(bot, enemyTowers[1]) > 850 then
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_faceless_void'] = function ()
	if bot:HasModifier("modifier_faceless_void_chronosphere")
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidTarget(botTarget) and J.GetHP(bot) > 0.25
		and J.IsLocationInChrono(botTarget:GetLocation()) then
			return BOT_MODE_DESIRE_VERYHIGH
		end
	end
	return BOT_MODE_DESIRE_NONE
end

ConsiderHeroSpecificRoaming['npc_dota_hero_nevermore'] = function ()
	bot.invisUltCombo = false
	if J.Utils.IsTruelyInvisible(bot)
	and bot:GetAbilityByName("nevermore_requiem"):IsFullyCastable()
	then
		local botTarget = J.GetProperTarget(bot)
		if J.IsValidHero(botTarget) and J.GetHP(bot) > 0.5 and J.GetHP(botTarget) > 0.5 and botTarget:GetHealth() > 800 then
			if enemyTowers == nil or #enemyTowers == 0 or GetUnitToUnitDistance(bot, enemyTowers[1]) > 850 then
				bot.invisUltCombo = true
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
