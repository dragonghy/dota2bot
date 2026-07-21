local Utils = require( GetScriptDirectory()..'/FunLib/utils')
local J = require( GetScriptDirectory()..'/FunLib/jmz_func')

local Version      = require(GetScriptDirectory()..'/FunLib/version')
local Localization = require(GetScriptDirectory()..'/FunLib/localization')


local bot = GetBot()
local botName = bot:GetUnitName()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return end

local local_mode_laning_generic = nil
local nAllyCreeps = nil
local nEnemyCreeps = nil
local nFurthestEnemyAttackRange = 0
local nInRangeEnemy = nil
local botAssignedLane = nil
local botAttackRange = bot:GetAttackRange()
local attackDamage = bot:GetAttackDamage()
local nH, enemyBots = J.Utils.NumHumanBotPlayersInTeam(GetOpposingTeam())
local teamHumans, teamBots = J.Utils.NumHumanBotPlayersInTeam(GetTeam())

-- Announcer state
local hasPickedOneAnnouncer      = false
local lastAnnouncePrintedTime    = 0
local numberAnnouncePrinted      = 1
local announcementGapSeconds     = 6
local isChangePosMessageDone     = false

if Utils.BuggyHeroesDueToValveTooLazy[botName] then local_mode_laning_generic = dofile( GetScriptDirectory().."/FunLib/override_generic/mode_laning_generic" ) end

-- Custom active last-hit path (buggy heroes / a pos1 paired with a human pos5 /
-- soak candidate 'c3'). See the [LAB C3] note in GetDesire below. Evaluated once
-- at load, matching the historical Think guard; inert off these gates.
local bCustomLastHit = local_mode_laning_generic
	or (J.GetPosition(bot) == 1 and J.IsPosxHuman(5))
	or (J.IsSoakCandidate('c3') and J.GetPosition(bot) <= 3)

-- [lanefix/lf_undertower] Core active last-hit, re-armed under the lanefix
-- bundle. Measured on game 071903 with the missed-CS capture: 198 of 211
-- tower-killed lane creeps died with a hero of that team standing within 1400
-- of a tower -- bots are PRESENT and simply do not contest CS under tower
-- (Valve default logic), burning ~half the lane farm. A tower-proximity-only
-- takeover is NOT implementable at mode level (defining Think replaces the
-- Valve default wholesale; there is no fallback for the away-from-tower case),
-- so the fix re-arms the existing full active last-hit path (the c3 Think) for
-- cores -- the under-tower slice is where it matters most. Load-time flag like
-- the others; gated, inert by default.
-- PARKED outside the 'lanefix' bundle after the final-gate reject: this is a
-- wholesale replacement of Valve's default CS think and must be evaluated on
-- its own candidate ('lf_undertower'), never silently inside a bundle.
local bLaneFixCoreLH = J.IsModeTurbo() and J.IsSoakCandidate('lf_undertower')
	and J.GetPosition(bot) <= 3

-- [LAB suplh / GH #14] Support (pos 4-5) last-hit division. Turbo-only and
-- gated behind soak candidate 'suplh', so it is inert in shipped games and only
-- activates for A/B validation. When on, a support keeps laning mode selected so
-- its Think can arbitrate creep CS: deny + harass, and last-hit ONLY creeps that
-- no allied core (pos 1-3) is near enough to take -- leaving the contested farm
-- for the core instead of both contending for the same creeps.
local bSupLastHit = J.IsModeTurbo() and J.IsSoakCandidate('suplh')
	and J.GetPosition(bot) >= 4

-- [replay-review 071423/071859] Under 'lanefix', a support (pos 4-5) uses the
-- disciplined support laning think (deny / uncontested last-hit / harass) and,
-- when idle, stays near its carry to screen it -- instead of drifting off across
-- the map (Silencer and Oracle both wandered 7-13k away, leaving the carry
-- alone). Load-time flag, mirrors bSupLastHit; inert off the lanefix candidate.
local bLaneFixSupport = J.IsModeTurbo()
	and (J.IsSoakCandidate('lanefix') or J.IsSoakCandidate('lf_support'))
	and J.GetPosition(bot) >= 4

function GetDesire()
	PickOneAnnouncer()
	AnnounceMessages()

	if bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return BOT_MODE_DESIRE_NONE end
	local botLV = bot:GetLevel()
	local currentTime = DotaTime()

	botAttackRange = bot:GetAttackRange()
	nAllyCreeps = bot:GetNearbyLaneCreeps(1200, false)
	nEnemyCreeps = bot:GetNearbyLaneCreeps(800, true)
	nInRangeEnemy = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	nFurthestEnemyAttackRange = GetFurthestEnemyAttackRange(nInRangeEnemy)
	if local_mode_laning_generic then
		botAssignedLane = local_mode_laning_generic.GetBotTargetLane()
	else
		botAssignedLane = bot:GetAssignedLane()
	end
	attackDamage = bot:GetAttackDamage()
	if bot:GetItemSlotType(bot:FindItemSlot("item_quelling_blade")) == ITEM_SLOT_TYPE_MAIN then
		if bot:GetAttackRange() > 310 or bot:GetUnitName() == "npc_dota_hero_templar_assassin" then
			attackDamage = attackDamage + 4
		else
			attackDamage = attackDamage + 8
		end
	end

	if GetGameMode() == 23 then currentTime = currentTime * 1.65 end
	if currentTime < 0 then return BOT_ACTION_DESIRE_NONE end

	-- if DotaTime() > 20 and DotaTime() - skipLaningState.lastCheckTime < skipLaningState.checkGap then
	-- 	if skipLaningState.count > 6 then
	-- 		print('[WARN] Bot ' ..botName.. ' switching modes too often, now stop it for laning to avoid conflicts.')
	-- 		return 0
	-- 	end
	-- else
	-- 	skipLaningState.lastCheckTime = DotaTime()
	-- 	skipLaningState.count = 0
	-- end

	if J.GetEnemiesAroundAncient(bot, 3200) > 0 then
		return BOT_MODE_DESIRE_NONE
	end

	-- if J.GetDistanceFromAncient( bot, true ) < 6900 then
	-- 	return BOT_MODE_DESIRE_NONE
	-- end

	if bot:WasRecentlyDamagedByAnyHero(5)
	and #J.Utils.GetLastSeenEnemyIdsNearLocation(bot:GetLocation(), 800) > 0 then
		local nLaneFrontLocation = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
		local nDistFromLane = GetUnitToLocationDistance(bot, nLaneFrontLocation)
		if not J.WeAreStronger(bot, 1200) or (nDistFromLane > 700 and J.GetHP(bot) < 0.7) then
			return BOT_MODE_DESIRE_NONE
		end
	end

	-- 如果在打高地 就别撤退去干别的
	if J.Utils.IsTeamPushingSecondTierOrHighGround(bot) then
		return BOT_MODE_DESIRE_NONE
	end
	-- if J.ShouldGoFarmDuringLaning(bot) then
	-- 	return 0.2
	-- end

	-- [LAB suplh / GH #14] Support-core last-hit division. Keep a turbo-lane
	-- support in laning mode whenever there is CS to arbitrate (enemy creeps in
	-- range, or an ally creep worth denying) so its Think owns the decision:
	-- deny + harass, and last-hit only creeps no allied core can take. Reaching
	-- here already means the support is not in an immediate-danger/retreat state
	-- (handled above). Inert unless turbo + soak candidate 'suplh' (bSupLastHit).
	-- [lanefix] keeps a support in lane (with its carry) during the laning phase
	-- too, instead of drifting off; danger/retreat is handled above this point.
	if (bSupLastHit or bLaneFixSupport) and J.IsInLaningPhase() then
		if (nEnemyCreeps ~= nil and #nEnemyCreeps > 0)
		or J.IsValid(GetBestDenyCreep(nAllyCreeps)) then
			return 0.9
		end
	end

	-- [LAB C3] candidate-side cores (pos 1-3) use the custom last-hit logic
	-- below; stock condition only enabled it for buggy heroes or a pos1 bot
	-- paired with a human pos5, so farm bots ran Valve default CS (12-47 LH
	-- at 11 min). Inert off-farm.
	if local_mode_laning_generic or (J.GetPosition(bot) == 1 and J.IsPosxHuman(5))
		or (J.IsSoakCandidate('c3') and J.GetPosition(bot) <= 3)
		or bLaneFixCoreLH then
		-- last hit
		if J.IsInLaningPhase() then
			local hitCreep, _ = GetBestLastHitCreep(nEnemyCreeps)
			if J.IsValid(hitCreep) then
				if J.GetPosition(bot) <= 2 or not J.IsThereNonSelfCoreNearby(700) -- this is for e.g lone druid bear as pos1-2 with core LD nearby to do last hit.
				then
					return 0.9
				end
			end
		end
	end
	if local_mode_laning_generic and local_mode_laning_generic.GetDesire ~= nil then return local_mode_laning_generic.GetDesire() end

	if GetGameMode() == GAMEMODE_1V1MID or GetGameMode() == GAMEMODE_MO then
		return 1
	end

	if currentTime <= 10 then return 0.268 end
	if currentTime <= 9 * 60 and botLV <= 7 then return 0.446 end
	if currentTime <= 12 * 60 and botLV <= 11 then return 0.369 end
	if botLV <= 14 and J.GetCoresAverageNetworth() < 7000 then return 0.2 end

	J.Utils.GameStates.passiveLaningTime = true
	return 0.01
end

function GetFurthestEnemyAttackRange(enemyList)
	local attackRange = 0
	for _, enemy in pairs(enemyList) do
		if J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy) then
			local enemyAttackRange = enemy:GetAttackRange()
			if enemyAttackRange > attackRange then
				attackRange = enemyAttackRange
			end
		end
	end

	return attackRange
end

function GetBestLastHitCreep(hCreepList)
	local dmgDelta = attackDamage * 0.7

	local moveToCreep = nil
	for _, creep in pairs(hCreepList) do
		if J.IsValid(creep) and J.CanBeAttacked(creep) then
			local nDelay = J.GetAttackProDelayTime(bot, creep)
			if J.WillKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL, nDelay) then
				return creep, false
			end
			if J.WillKillTarget(creep, attackDamage + dmgDelta, DAMAGE_TYPE_PHYSICAL, nDelay) then
				moveToCreep = creep
			end
		end
	end
	if moveToCreep then
		return moveToCreep, true
	end

	return nil
end

function GetBestDenyCreep(hCreepList)
	for _, creep in pairs(hCreepList)
	do
		if J.IsValid(creep)
		and J.GetHP(creep) < 0.49
		and J.CanBeAttacked(creep)
		and creep:GetHealth() <= attackDamage
		then
			return creep
		end
	end

	return nil
end

-- [LAB suplh / GH #14] Is an allied core (pos 1-3) close enough to take the last
-- hit on this creep itself? True when a living, non-self, non-illusion allied
-- core is within ~800 of the creep (same-lane proximity) AND the creep is within
-- that core's attack reach plus a short walk buffer (so it can actually secure
-- it soon). Pure predicate over explicit args (no closed-over mutable state), so
-- it is unit-testable. Conservative: when no core clearly contests, the support
-- is free to take the creep and is not starved of gold.
function _suplh_IsCoreContestingCreep(hSelf, hCreep)
	if not J.IsValid(hCreep) then return false end
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if ally ~= hSelf
		and J.IsValidHero(ally)
		and not ally:IsIllusion()
		and J.IsCore(ally)
		then
			local nDist = GetUnitToUnitDistance(ally, hCreep)
			if nDist <= 800 and nDist <= ally:GetAttackRange() + 250 then
				return true
			end
		end
	end
	return false
end

-- Same kill check as GetBestLastHitCreep, but skips any creep an allied core can
-- take -- so a support only ever secures uncontested creeps.
local function GetSupportUncontestedLastHitCreep(hCreepList)
	local dmgDelta = attackDamage * 0.7
	local moveToCreep = nil
	for _, creep in pairs(hCreepList) do
		if J.IsValid(creep) and J.CanBeAttacked(creep)
		and not _suplh_IsCoreContestingCreep(bot, creep) then
			local nDelay = J.GetAttackProDelayTime(bot, creep)
			if J.WillKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL, nDelay) then
				return creep, false
			end
			if J.WillKillTarget(creep, attackDamage + dmgDelta, DAMAGE_TYPE_PHYSICAL, nDelay) then
				moveToCreep = creep
			end
		end
	end
	if moveToCreep then
		return moveToCreep, true
	end
	return nil
end

-- [LAB suplh / GH #14] Support laning behavior under the 'suplh' gate: deny own
-- creeps, secure only uncontested last-hits (never steal a core's farm), harass
-- an in-range enemy hero when it is safe, else hold the lane front. Suppressing
-- the contested last-hit is the whole point: a creep a core is near falls
-- through the last-hit branch and the support does not attack it.
local function DoSupportLaningThink()
	-- Deny own creeps first (time-sensitive; never the core's responsibility).
	local denyCreep = GetBestDenyCreep(nAllyCreeps)
	if J.IsValid(denyCreep) then
		bot:SetTarget(denyCreep)
		bot:Action_AttackUnit(denyCreep, true)
		return
	end

	-- Secure a last-hit ONLY when no allied core can take it (a lone support
	-- still needs gold); contested creeps are deliberately left for the core.
	local hitCreep, moveToCreep = GetSupportUncontestedLastHitCreep(nEnemyCreeps)
	if J.IsValid(hitCreep) then
		if GetUnitToUnitDistance(bot, hitCreep) > botAttackRange
		or (moveToCreep and GetUnitToUnitDistance(bot, hitCreep) > botAttackRange * 0.8) then
			bot:Action_MoveToUnit(hitCreep)
			return
		else
			bot:SetTarget(hitCreep)
			bot:Action_AttackUnit(hitCreep, true)
			return
		end
	end

	-- Harass: auto-attack an enemy hero already in range when it is safe to
	-- (healthy and locally stronger), so the support pressures the lane instead
	-- of idling on contested creeps it is no longer contesting.
	if J.GetHP(bot) >= 0.5 and J.WeAreStronger(bot, 1200) then
		local enemies = bot:GetNearbyHeroes(botAttackRange, true, BOT_MODE_NONE)
		for _, enemy in pairs(enemies) do
			if J.IsValidHero(enemy)
			and not J.IsSuspiciousIllusion(enemy)
			and J.CanBeAttacked(enemy) then
				bot:SetTarget(enemy)
				bot:Action_AttackUnit(enemy, true)
				return
			end
		end
	end

	-- [lanefix] Stay with the carry: if an allied core is laning nearby, hold a
	-- spot right next to it instead of the raw lane front, so the support screens
	-- the core rather than drifting off. Only the idle fallthrough is affected --
	-- deny / last-hit / harass above are unchanged.
	-- NARROWED after the final-gate reject: parking ON the carry clumped the
	-- team 23% tighter in 17/17 games (2-man gank targets, contested XP).
	-- Screen only when an enemy hero actually threatens the carry, and stand
	-- OFF the carry (400u toward our fountain), not on top of it.
	if J.IsLaneFixOn( 'support' ) then
		local hCore = J.GetLaneCoreToProtect( bot )
		if hCore ~= nil
			and #J.GetEnemiesNearLoc( hCore:GetLocation(), 1600 ) > 0 then
			local vCore = hCore:GetLocation()
			local vF = J.GetTeamFountain()
			local dx, dy = vF.x - vCore.x, vF.y - vCore.y
			local n = math.max( math.sqrt( dx * dx + dy * dy ), 1 )
			bot:Action_MoveToLocation(
				Vector( vCore.x + dx / n * 400, vCore.y + dy / n * 400, 0 ) )
			return
		end
	end

	-- Otherwise hold the lane front (mirrors the core path's positioning).
	local fLaneFrontAmount = GetLaneFrontAmount(GetTeam(), botAssignedLane, false)
	local fLaneFrontAmount_enemy = GetLaneFrontAmount(GetOpposingTeam(), botAssignedLane, false)
	local nLongestAttackRange = math.max(botAttackRange, 250, nFurthestEnemyAttackRange)
	local target_loc = GetLaneFrontLocation(GetTeam(), botAssignedLane, -nLongestAttackRange)
	if fLaneFrontAmount_enemy < fLaneFrontAmount then
		target_loc = GetLaneFrontLocation(GetOpposingTeam(), botAssignedLane, -nLongestAttackRange)
	end
	bot:Action_MoveToLocation(target_loc + RandomVector(50))
end

if bCustomLastHit or bSupLastHit or bLaneFixSupport or bLaneFixCoreLH then
	function Think()
		if bSupLastHit or bLaneFixSupport then
			DoSupportLaningThink()
			return
		end

		local hitCreep, moveToCreep = GetBestLastHitCreep(nEnemyCreeps)
		if J.IsValid(hitCreep) then
			if J.GetPosition(bot) <= 2 or not J.IsThereNonSelfCoreNearby(700)
			then
				if GetUnitToUnitDistance(bot, hitCreep) > botAttackRange
				or (moveToCreep and GetUnitToUnitDistance(bot, hitCreep) > botAttackRange * 0.8) then
					bot:Action_MoveToUnit(hitCreep)
					return
				else
					bot:SetTarget(hitCreep)
					bot:Action_AttackUnit(hitCreep, true)
					return
				end
			end
		end

		local denyCreep = GetBestDenyCreep(nAllyCreeps)
		if J.IsValid(denyCreep) then
			bot:SetTarget(denyCreep)
			bot:Action_AttackUnit(denyCreep, true)
			return
		end

		if local_mode_laning_generic then
			local_mode_laning_generic.Think()
		end

		local fLaneFrontAmount = GetLaneFrontAmount(GetTeam(), botAssignedLane, false)
		local fLaneFrontAmount_enemy = GetLaneFrontAmount(GetOpposingTeam(), botAssignedLane, false)

		local nLongestAttackRange = math.max(botAttackRange, 250, nFurthestEnemyAttackRange)

		local target_loc = GetLaneFrontLocation(GetTeam(), botAssignedLane, -nLongestAttackRange)
		if fLaneFrontAmount_enemy < fLaneFrontAmount then
			target_loc = GetLaneFrontLocation(GetOpposingTeam(), botAssignedLane, -nLongestAttackRange)
		end

		bot:Action_MoveToLocation(target_loc + RandomVector(50))
	end
end


function PickOneAnnouncer()
	if not hasPickedOneAnnouncer then
		for i, _ in pairs(GetTeamPlayers(GetTeam())) do
			local member = GetTeamMember(i)
			if member ~= nil and member.isAnnouncer then return end
		end
		bot.isAnnouncer = true
		hasPickedOneAnnouncer = true
	end
end

function AnnounceMessages()
	-- Only pre-game chatter
	if DotaTime() > 60 then return end

	local welcomeMessages = Localization.Get('welcome_msgs')
	local inTurbo         = J.IsModeTurbo()

	-- Staggered lines during negative DotaTime pre-game
	if ((inTurbo and DotaTime() > -50 + GetTeam() * 2) or (not inTurbo and DotaTime() > -75 + GetTeam() * 2))
	   and numberAnnouncePrinted < #welcomeMessages + 1
	   and bot.isAnnouncer
	   and DotaTime() < 0
	then
		if GameTime() - lastAnnouncePrintedTime >= announcementGapSeconds then
			local message      = welcomeMessages[numberAnnouncePrinted]
			local isFirstLine  = (numberAnnouncePrinted == 1)
			if message then
				-- Match original behavior: first line (or if no enemy bots) can be global
				bot:ActionImmediate_Chat(isFirstLine and (message .. Version.number) or message, enemyBots == 0 or isFirstLine)
			end
			numberAnnouncePrinted   = numberAnnouncePrinted + 1
			lastAnnouncePrintedTime = GameTime()
		end
	end

	-- Announce role during pre-game
	if GetGameMode() ~= GAMEMODE_1V1MID
	   and GetGameState() == GAME_STATE_PRE_GAME
	   and (bot.announcedRole == nil or bot.announcedRole ~= J.GetPosition(bot))
	then
		bot.announcedRole = J.GetPosition(bot)
		bot:ActionImmediate_Chat(Localization.Get('say_play_pos') .. J.GetPosition(bot), false)
	end

	-- Close position selection after horn if humans and bots mixed
	if GetGameMode() ~= GAMEMODE_1V1MID and not isChangePosMessageDone then
		if DotaTime() >= 0 and teamHumans > 0 and teamBots > 0 then
			bot:ActionImmediate_Chat(Localization.Get('pos_select_closed'), true)
			isChangePosMessageDone = true
		end
	end
end
