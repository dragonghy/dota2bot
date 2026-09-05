local bot = GetBot()
local botName = bot:GetUnitName()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return end

local J = require( GetScriptDirectory()..'/FunLib/jmz_func')
local Customize = require( GetScriptDirectory()..'/Customize/general' )

local Outposts = {}
local DidWeGetOutpost = false
local ClosestOutpost = nil
local ClosestOutpostDist = 10000

-- Soak candidate 'outlatch'. Shortest possible re-scan spacing, so the retry
-- the gate adds is bounded by wall clock instead of by frames. Outposts are
-- map-static, so one attempt per game second finds them within a second of
-- their becoming enumerable while costing at most one GetUnitList sweep per
-- second per bot -- and only until the first non-empty scan closes the latch.
local OUTPOST_RESCAN_INTERVAL = 1.0
local NextOutpostScanTime = -math.huge

local IsEnemyTier2Down = false
local hAbilityCapture = bot:GetAbilityByName('ability_capture')

function GetDesire()
	-- local cacheKey = 'GetOutpostDesire'..tostring(bot:GetPlayerID())
	-- local cachedVar = J.Utils.GetCachedVars(cacheKey, 0.5 * (1 + Customize.ThinkLess))
	-- if DotaTime() > 30 and cachedVar ~= nil then return cachedVar end
	local res = GetDesireHelper()
	-- J.Utils.SetCachedVars(cacheKey, res)
	return res
end
function GetDesireHelper()
	if bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return BOT_MODE_DESIRE_NONE end

	if not IsEnemyTier2Down
	then
		if GetTower(GetOpposingTeam(), TOWER_TOP_2) == nil
		or GetTower(GetOpposingTeam(), TOWER_MID_2) == nil
		or GetTower(GetOpposingTeam(), TOWER_BOT_2) == nil
		then
			IsEnemyTier2Down = true
		end
	end

	if J.IsTeamPushingHighGround(bot) then
		return BOT_MODE_DESIRE_NONE;
	end

	if J.GetEnemiesAroundAncient(bot, 3200) > 0 then
		return BOT_MODE_DESIRE_NONE
	end

	-- local botMode = bot:GetActiveMode()
	-- if (J.IsPushing(bot) or J.IsDefending(bot) or J.IsDoingRoshan(bot) or J.IsDoingTormentor(bot)
	-- or botMode == BOT_MODE_RUNE or botMode == BOT_MODE_SECRET_SHOP or botMode == BOT_MODE_WARD or botMode == BOT_MODE_ROAM)
	-- and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH then
	-- 	return BOT_MODE_DESIRE_NONE
	-- end

	----------
	-- Outpost
	----------

	if not IsEnemyTier2Down then return BOT_ACTION_DESIRE_NONE end

	if not DidWeGetOutpost
	then
		if botName == 'npc_dota_hero_invoker' then return BOT_ACTION_DESIRE_NONE end

		-- Gated ('outlatch'). The shipped latch below records that we LOOKED,
		-- not that we FOUND: `DidWeGetOutpost = true` runs unconditionally
		-- after the sweep, so a single sweep that returns no outpost closes the
		-- only door there is. `Outposts` has exactly one writer (this
		-- table.insert) and exactly one reader (GetClosestOutpost), so an empty
		-- table is PERMANENT: GetClosestOutpost answers nil for the rest of the
		-- game, the desire below is BOT_ACTION_DESIRE_NONE forever, and this
		-- whole mode is dead for this bot -- silently, with no error and no
		-- retry. Armed, the latch records the postcondition it is meant to gate.
		local bRescan = J.IsModeTurbo() and J.IsSoakCandidate('outlatch')

		if bRescan
		then
			if DotaTime() < NextOutpostScanTime then return BOT_ACTION_DESIRE_NONE end
			NextOutpostScanTime = DotaTime() + OUTPOST_RESCAN_INTERVAL
		end

		for _, unit in pairs(GetUnitList(UNIT_LIST_ALL))
		do
			if unit:GetUnitName() == '#DOTA_OutpostName_North'
			or unit:GetUnitName() == '#DOTA_OutpostName_South'
			then
				table.insert(Outposts, unit)
			end
		end

		-- Shipped when the gate is shut: `not bRescan` is true, so this is the
		-- unconditional `true` byte for byte. The sweep can only run while
		-- Outposts is empty, so the retry cannot duplicate an entry.
		DidWeGetOutpost = not bRescan or #Outposts > 0
	end

	ClosestOutpost, ClosestOutpostDist = GetClosestOutpost()
	if ClosestOutpost ~= nil and ClosestOutpostDist < 3000
	and not IsEnemyCloserToOutpostLoc(ClosestOutpost:GetLocation(), ClosestOutpostDist)
	and IsSuitableToCaptureOutpost()
	then
		if GetUnitToUnitDistance(bot, ClosestOutpost) < 600
		then
			local nInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), bot:GetCurrentVisionRange())
			if nInRangeEnemy ~= nil and #nInRangeEnemy >= 1
			then
				return BOT_ACTION_DESIRE_NONE
			end
		end

		-- Soak candidate 'outcommit' (GH #511). The bid below is a pure distance
		-- remap topping out at BOT_ACTION_DESIRE_HIGH (0.75), and it returns the
		-- SAME number on the frame a capture channel starts as on the frame it
		-- is 5.9s deep: the seconds already sunk into the channel are invisible
		-- to it. mode_farm_generic's own bid, meanwhile, is a remap that reaches
		-- BOT_MODE_DESIRE_VERYHIGH (0.9), so an ordinary farm tick outbids a
		-- nearly-finished capture. Measured in W47 (37 games): 53 channels, 13
		-- completions, 40 aborts (75.5%) burning 66.6 hero-seconds -- and on 34
		-- of 36 sampled aborts NOTHING in this file had changed (full hp, no
		-- enemy in vision, 5v5), so the order that cut the channel came from
		-- another mode winning the tick, not from any veto here.
		--
		-- Armed, hold the mode for exactly as long as OUR OWN channel is
		-- running: `bot:IsChanneling()` plus the outpost carrying
		-- `modifier_watch_tower_capturing` -- the combat log puts that modifier
		-- on the OUTPOST, not on the capturing hero. Both conjuncts are needed:
		-- the modifier alone would also be true while an ALLY channels this
		-- outpost, which is not this bot's sunk cost.
		--
		-- Every shipped veto above still runs first and unchanged -- including
		-- the "any enemy inside vision while within 600u" abort right above, so
		-- this cannot pin a bot in a fight. It only RAISES the number on frames
		-- the shipped tree already bid on. Bound, declared: 0.9 clears the
		-- shipped 0.75 and matches the top of farm's remap; that it wins every
		-- arbitration is not established offline, only that it no longer loses
		-- to a bid the shipped 0.75 sat below.
		if J.IsModeTurbo() and J.IsSoakCandidate('outcommit')
		and bot:IsChanneling()
		and ClosestOutpost:HasModifier('modifier_watch_tower_capturing')
		then
			return BOT_MODE_DESIRE_VERYHIGH
		end

		return RemapValClamped(GetUnitToUnitDistance(bot, ClosestOutpost), 3000, 0, BOT_ACTION_DESIRE_VERYLOW, BOT_ACTION_DESIRE_HIGH )
	end

	return BOT_ACTION_DESIRE_NONE
end

function OnStart()

end

function OnEnd()
	ClosestOutpost = nil
	ClosestOutpostDist = 10000
	ShouldWaitInBaseToHeal = false
end

function Think()
	if J.CanNotUseAction(bot) then return end
	if J.Utils.IsBotThinkingMeaningfulAction(bot, Customize.ThinkLess, "outpost") then return end

	if ClosestOutpost ~= nil
	then
		if GetUnitToUnitDistance(bot, ClosestOutpost) > 300
		then
			bot:Action_MoveToLocation(ClosestOutpost:GetLocation())
			return
		else
			if hAbilityCapture then
				bot:Action_UseAbilityOnEntity(hAbilityCapture, ClosestOutpost)
			else
				bot:Action_AttackUnit(ClosestOutpost, false)
			end
			return
		end
	end
end

function GetClosestOutpost()
	local closest = nil
	local dist = 10000

	for i = 1, 2
	do
		if Outposts[i] ~= nil
		and Outposts[i]:GetTeam() ~= GetTeam()
		and GetUnitToUnitDistance(bot, Outposts[i]) < dist
		and not Outposts[i]:IsNull()
		and not Outposts[i]:IsInvulnerable()
		then
			closest = Outposts[i]
			dist = GetUnitToUnitDistance(bot, Outposts[i])
		end
	end

	return closest, dist
end

function IsEnemyCloserToOutpostLoc(opLoc, botDist)
	for _, id in pairs(GetTeamPlayers(GetOpposingTeam()))
	do
		local info = GetHeroLastSeenInfo(id)

		if info ~= nil
		then
			local dInfo = info[1]
			if dInfo ~= nil
			then
				if dInfo ~= nil
				and dInfo.time_since_seen < 5
				and J.GetDistance(dInfo.location, opLoc) < botDist
				then
					return true
				end
			end
		end
	end

	return false
end

function IsSuitableToCaptureOutpost()
	local botTarget = J.GetProperTarget(bot)

	if (J.IsGoingOnSomeone(bot) and J.IsValidTarget(botTarget) and GetUnitToUnitDistance(bot, botTarget) < 700)
	or J.IsDefending(bot)
	or (J.IsDoingTormentor(bot) and J.IsTormentor(botTarget) and J.IsAttacking(bot))
	or (J.IsDoingRoshan(bot) and J.IsRoshan(botTarget) and J.IsAttacking(bot))
	or (J.IsRetreating(bot) and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH)
	or bot:WasRecentlyDamagedByAnyHero(5)
	or bot:GetActiveMode() == BOT_MODE_DEFEND_ALLY
	or J.GetNumOfAliveHeroes( false ) < J.GetNumOfAliveHeroes( true )
	then
		return false
	end

	return true
end
