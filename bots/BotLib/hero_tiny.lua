local X = {}
local bot = GetBot()

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Minion = dofile( GetScriptDirectory()..'/FunLib/aba_minion' )
local sTalentList = J.Skill.GetTalentList( bot )
local sAbilityList = J.Skill.GetAbilityList( bot )
local sRole = J.Item.GetRoleItemsBuyList( bot )

local tTalentTreeList = {
					{--pos1
                        ['t25'] = {10, 0},
						['t20'] = {0, 10},
						['t15'] = {0, 10},
						['t10'] = {10, 0},
                    },
                    {--pos2
                        ['t25'] = {10, 0},
                        ['t20'] = {0, 10},
                        ['t15'] = {10, 0},
                        ['t10'] = {10, 0},
                    },
}

local tAllAbilityBuildList = {
						{3,1,3,2,3,6,3,1,1,1,6,2,2,2,6},--pos1
                        {3,1,1,2,1,6,1,2,2,2,6,3,3,3,6},--pos2
}

local nAbilityBuildList
local nTalentBuildList

if sRole == "pos_1"
then
    nAbilityBuildList   = tAllAbilityBuildList[1]
    nTalentBuildList    = J.Skill.GetTalentBuild(tTalentTreeList[1])
else
    nAbilityBuildList   = tAllAbilityBuildList[2]
    nTalentBuildList    = J.Skill.GetTalentBuild(tTalentTreeList[2])
end

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_1'] = {
    "item_tango",
    "item_quelling_blade",
    "item_slippers",
    "item_circlet",
    "item_double_branches",

    "item_wraith_band",
    "item_magic_wand",
    "item_hand_of_midas",
    "item_power_treads",
    "item_echo_sabre",
    "item_blink",
    "item_black_king_bar",--
    "item_aghanims_shard",
    "item_greater_crit",--
    "item_butterfly",--
    "item_satanic",--
    "item_moon_shard",
    "item_swift_blink",--
    "item_travel_boots_2",--
    "item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_2'] = {
    "item_tango",
    "item_double_branches",
    "item_faerie_fire",
    "item_quelling_blade",

    "item_bottle",
    "item_power_treads",
    "item_magic_wand",
    "item_blink",
    "item_echo_sabre",
    "item_aghanims_shard",
    "item_black_king_bar",--
    "item_greater_crit",--
    "item_assault",--
    "item_moon_shard",
    "item_satanic",--
    "item_swift_blink",--
    "item_travel_boots_2",--

    "item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_4'] = {
    "item_tango",
    "item_quelling_blade",
    "item_slippers",
    "item_circlet",
    "item_double_branches",

    "item_wraith_band",
    "item_magic_wand",
    "item_hand_of_midas",
    "item_power_treads",
    "item_echo_sabre",
    "item_blink",
    "item_black_king_bar",--
    "item_aghanims_shard",
    "item_greater_crit",--
    "item_butterfly",--
    "item_satanic",--
    "item_moon_shard",
    "item_swift_blink",--
    "item_travel_boots_2",--
    "item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_5'] = sRoleItemsBuyList['pos_4']

sRoleItemsBuyList['pos_3'] = sRoleItemsBuyList['pos_4']

X['sBuyList'] = sRoleItemsBuyList[sRole]

X['sSellList'] = {

	"item_black_king_bar",
	"item_quelling_blade",

}

if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_antimage' }, {} end

nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] = J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )

X['bDeafaultAbility'] = false
X['bDeafaultItem'] = false

function X.MinionThink(hMinionUnit)
	if Minion.IsValidUnit( hMinionUnit )
	then
		if J.IsValidHero(hMinionUnit) and hMinionUnit:IsIllusion()
		then
			Minion.IllusionThink( hMinionUnit )
		end
	end
end

local Avalanche     = bot:GetAbilityByName("tiny_avalanche")
local Toss          = bot:GetAbilityByName("tiny_toss")
local TreeGrab      = bot:GetAbilityByName("tiny_tree_grab")
local TreeThrow     = bot:GetAbilityByName("tiny_toss_tree")
local TreeVolley    = bot:GetAbilityByName("tiny_tree_channel")

local AvalancheDesire, AvalancheTarget
local TossDesire, TossTarget
local TreeGrabDesire, TreeGrabTarget
local TreeThrowDesire, TreeThrowTarget
local TreeVolleyDesire, TreeVolleyTarget

local BlinkTossDesire, BlinkTossTarget

local Blink
local BlinkLocation

function X.SkillsComplement()
	if J.CanNotUseAbility(bot) then return end

	-- Not sure why not tossing to ally..?
	BlinkTossDesire, BlinkTossTarget = X.ConsiderBlinkToss()
	if BlinkTossDesire > 0
	then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(Blink, BlinkLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnEntity(Toss, BlinkTossTarget)
		return
	end

	AvalancheDesire, AvalancheTarget = X.ConsiderAvalanche()
	if AvalancheDesire > 0
	then
		bot:Action_UseAbilityOnLocation(Avalanche, AvalancheTarget)
		return
	end

	TossDesire, TossTarget = X.ConsiderToss()
	if TossDesire > 0
	then
		bot:Action_UseAbilityOnEntity(Toss, TossTarget)
		return
	end

	TreeGrabDesire, TreeGrabTarget = X.ConsiderTreeGrab()
	if TreeGrabDesire > 0
	then
		bot:Action_UseAbilityOnTree(TreeGrab, TreeGrabTarget)
		return
	end

	TreeThrowDesire, TreeThrowTarget = X.ConsiderTreeThrow()
	if TreeThrowDesire > 0
	then
		bot:Action_UseAbilityOnEntity(TreeThrow, TreeThrowTarget)
		return
	end

	TreeVolleyDesire, TreeVolleyTarget = X.ConsiderTreeVolley()
	if TreeVolleyDesire > 0
	then
		bot:Action_UseAbilityOnLocation(TreeVolley, TreeVolleyTarget)
		return
	end
end

function X.ConsiderAvalanche()
    if not Avalanche:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nCastRange = J.GetProperCastRange(false, bot, Avalanche:GetCastRange())
	local nRadius = Avalanche:GetSpecialValueInt('radius')
	-- ⚠️ `'value'` IS NOT A KEY OF THIS ABILITY -- this read is a silent 0, so
	-- nDamage is 0 and the CanKillTarget finisher branch below cannot fire.
	-- tiny_avalanche's AbilityValues entries are AbilityCastRange / radius /
	-- tick_interval / total_duration / tick_count / stun_duration /
	-- projectile_speed / avalanche_damage / AbilityCooldown; `value` is the
	-- INNER key of the long-form entries, not an entry.  Intended key:
	-- `avalanche_damage` (90/180/270/360).  Axis ABILVALUE, GH #228 §6.3 --
	-- census: tools/agent/ability_value_key_census.py.  Repairing this is a
	-- behaviour change on a non-focus hero and is NOT annotation work: it needs
	-- a gate and a real frame, so it is registered, not done here.
	local nDamage = Avalanche:GetSpecialValueInt('value') * (1 + bot:GetSpellAmp())
	local nManaCost = Avalanche:GetManaCost()
	local botTarget = J.GetProperTarget(bot)

	local nEnemyHeroes = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
	do
		if J.IsValidHero(enemyHero)
		and J.CanCastOnNonMagicImmune(enemyHero)
		and not J.IsSuspiciousIllusion(enemyHero)
		then
			if (enemyHero:IsChanneling() or J.IsCastingUltimateAbility(enemyHero))
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end

			if J.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier('modifier_abaddon_aphotic_shield')
			and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
			and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
			and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
			and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end

	if J.IsGoingOnSomeone(bot)
	then
		local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange + 200, false, BOT_MODE_NONE)
		local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

		if J.IsValidTarget(botTarget)
		and J.CanCastOnNonMagicImmune(botTarget)
		and J.IsInRange(bot, botTarget, nCastRange - 50)
		and not J.IsSuspiciousIllusion(botTarget)
		and not J.IsDisabled(botTarget)
		and not botTarget:HasModifier('modifier_abaddon_aphotic_shield')
		and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
		and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
		and not botTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
		and nInRangeAlly ~= nil and nInRangeEnemy ~= nil
		and #nInRangeAlly >= #nInRangeEnemy
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end

	if J.IsRetreating(bot)
	then
		local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange + 200, false, BOT_MODE_NONE)
		local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

		if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
		and ((#nInRangeEnemy > #nInRangeAlly)
			or (J.GetHP(bot) < 0.58 and bot:WasRecentlyDamagedByAnyHero(2)))
		and J.IsValidHero(nInRangeEnemy[1])
		and J.CanCastOnNonMagicImmune(nInRangeEnemy[1])
		and J.IsInRange(bot, nInRangeEnemy[1], nCastRange)
		and not J.IsSuspiciousIllusion(nInRangeEnemy[1])
		and not J.IsDisabled(nInRangeEnemy[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1]:GetLocation()
		end
	end

	if (J.IsPushing(bot) or J.IsDefending(bot))
	and J.CanSpamSpell(bot, nManaCost)
	then
		local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nCastRange, true)
		local nLocationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0)

		if nEnemyLaneCreeps ~= nil and #nEnemyLaneCreeps >= 4
		and nLocationAoE.count >= 4
		then
			return BOT_ACTION_DESIRE_HIGH, nLocationAoE.targetloc
		end
	end

	if J.IsFarming(bot)
	then
		local nNeutralCreeps = bot:GetNearbyNeutralCreeps(nCastRange)
		local nLocationAoE = bot:FindAoELocation(true, false, bot:GetLocation(), nCastRange, nRadius, 0, 0)

		if nNeutralCreeps ~= nil and #nNeutralCreeps >= 3
		and nLocationAoE.count >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, nLocationAoE.targetloc
		end
	end

	if J.IsLaning(bot)
	and J.IsAllowedToSpam(bot, nManaCost)
	then
		local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nRadius, true)

		for _, creep in pairs(nEnemyLaneCreeps)
		do
			if J.IsValid(creep)
			and (J.IsKeyWordUnit('ranged', creep) or J.IsKeyWordUnit('siege', creep))
			and creep:GetHealth() <= nDamage
			then
				local nInRangeEnemy = J.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)

				if nInRangeEnemy ~= nil and #nInRangeEnemy >= 1
				and GetUnitToUnitDistance(creep, nInRangeEnemy[1]) <= 600
				then
					return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
				end
			end
		end
	end

	if J.IsDoingRoshan(bot)
	then
		if J.IsRoshan(botTarget)
		and J.CanCastOnNonMagicImmune(botTarget)
		and J.IsInRange(bot, botTarget, nCastRange)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end

	if J.IsDoingTormentor(bot)
	then
		if J.IsTormentor(botTarget)
		and J.CanCastOnNonMagicImmune(botTarget)
		and J.IsInRange(bot, botTarget, nCastRange)
		and J.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderToss()
    if not Toss:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nCastRange = J.GetProperCastRange(false, bot, Toss:GetCastRange())
	local nDamage = Toss:GetSpecialValueInt('toss_damage') * (1 + bot:GetSpellAmp())
	local nRadius = Toss:GetSpecialValueInt('grab_radius')
	local botTarget = J.GetProperTarget(bot)

	local nEnemyHeroes = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
	do
		if J.IsValidHero(enemyHero)
		and J.CanCastOnNonMagicImmune(enemyHero)
		and not J.IsSuspiciousIllusion(enemyHero)
		then
			if (enemyHero:IsChanneling() or J.IsCastingUltimateAbility(enemyHero))
			and Avalanche:IsTrained() and not Avalanche:IsCooldownReady()
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end

			if J.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier('modifier_abaddon_aphotic_shield')
			and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
			and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
			and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
			and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end

	if J.IsGoingOnSomeone(bot)
	and not CanDoBlinkToss()
	then
		local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange + 200, false, BOT_MODE_NONE)
		local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

		if J.IsValidTarget(botTarget)
		and J.CanCastOnNonMagicImmune(botTarget)
		and not J.IsSuspiciousIllusion(botTarget)
		and not J.IsDisabled(botTarget)
		and not botTarget:HasModifier('modifier_faceless_void_chronosphere_freeze')
		and not botTarget:HasModifier('modifier_legion_commander_duel')
		and nInRangeAlly ~= nil and nInRangeEnemy ~= nil
		and #nInRangeAlly >= #nInRangeEnemy
		then
			if J.IsInRange(bot, botTarget, nRadius)
			then
				local chronodTarget = nil
				local nInRangeEnemy2 = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
				for _, enemyHero in pairs(nInRangeEnemy2)
				do
					if J.IsValidHero(enemyHero)
					and J.CanCastOnNonMagicImmune(enemyHero)
					and J.IsInRange(bot, enemyHero, nCastRange)
					and not J.IsSuspiciousIllusion(enemyHero)
					and enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
					then
						chronodTarget = enemyHero
						break
					end
				end

				if chronodTarget ~= nil
				then
					for _, enemyHero in pairs(nInRangeEnemy2)
					do
						if J.IsValidHero(enemyHero)
						and J.CanCastOnNonMagicImmune(enemyHero)
						and J.IsInRange(bot, enemyHero, nRadius)
						and not J.IsSuspiciousIllusion(enemyHero)
						then
							return BOT_ACTION_DESIRE_HIGH, chronodTarget
						end
					end
				end

				return BOT_ACTION_DESIRE_HIGH, botTarget
			else
				if J.IsInRange(bot, botTarget, nCastRange)
				then
					local nAllyLaneCreeps = bot:GetNearbyLaneCreeps(nRadius, false)
					local nCreeps = bot:GetNearbyCreeps(nRadius, true)

					if (nAllyLaneCreeps ~= nil and #nAllyLaneCreeps >= 1)
					or (nCreeps ~= nil and #nCreeps >= 1)
					then
						return BOT_ACTION_DESIRE_HIGH, botTarget
					end

					local nTargetAllies = J.GetEnemiesNearLoc(botTarget:GetLocation(), nRadius)
					if nTargetAllies ~= nil and #nTargetAllies <= 1
					then
						local nInRangeAllyToToss = J.GetNearbyHeroes(bot,nRadius, false, BOT_MODE_NONE)
						if nInRangeAllyToToss ~= nil and #nInRangeAllyToToss >= 1
						and GetUnitToUnitDistance(bot, botTarget) > nRadius + 75
						then
							return BOT_ACTION_DESIRE_HIGH, botTarget
						end
					end
				end
			end
		end
	end

	if J.IsRetreating(bot)
	then
		local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange + 200, false, BOT_MODE_NONE)
		local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

		-- `J.GetHP(bot)` here is a RATIO, not a predicate: jmz_func.lua:4003 returns
		-- `nCurHealth / nMaxHealth` (and a bare 0 when dead), so it is truthy for
		-- every unit on every frame -- 0 is true in Lua. The conjunct therefore
		-- costs a division and decides nothing, and the disjunction collapses to
		-- `#enemies > #allies or WasRecentlyDamagedByAnyHero(2)`. Inside a retreat
		-- the right-hand side is nearly always true, so the outnumbered test on the
		-- left is dominated too: shipped Tiny tosses while retreating at ANY health,
		-- full health included.
		-- The repo answers what the missing half was: 64 sites write this exact
		-- idiom as `J.GetHP(bot) < X and bot:WasRecentlyDamagedByAnyHero(...)`
		-- (mode X = 0.65, 11 sites); 6 dropped the `< X`, this being one.
		-- soak candidate 'hpbool' (turbo-only). Gate shut, the added conjunct is
		-- `not false` = true and the shipped expression stands unchanged; armed, it
		-- is the threshold the other 64 copies carry. Strictly fewer casts, never
		-- more.
		if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
		and ((#nInRangeEnemy > #nInRangeAlly)
			or (J.GetHP(bot) and bot:WasRecentlyDamagedByAnyHero(2)
				and (not (J.IsModeTurbo() and J.IsSoakCandidate('hpbool'))
					or J.GetHP(bot) < 0.65)))
		and J.IsValidHero(nInRangeEnemy[1])
		and J.CanCastOnNonMagicImmune(nInRangeEnemy[1])
		and not J.IsSuspiciousIllusion(nInRangeEnemy[1])
		and not J.IsDisabled(nInRangeEnemy[1])
		then
			local loc = J.GetEscapeLoc()
			local furthestTarget = J.GetFurthestUnitToLocationFrommAll(bot, nCastRange, loc)

			if furthestTarget ~= nil
			and GetUnitToUnitDistance(bot, furthestTarget) > nRadius
			then
				local tTarget = J.GetClosestUnitToLocationFrommAll2(bot, nRadius, bot:GetLocation())

				if J.IsValidTarget(tTarget)
				and tTarget:GetTeam() ~= bot:GetTeam()
				then
					return BOT_ACTION_DESIRE_MODERATE, furthestTarget
				end
			elseif furthestTarget ~= nil and GetUnitToUnitDistance(furthestTarget, bot) <= nRadius
			then
				local tTarget = J.GetClosestUnitToLocationFrommAll2(bot, nRadius, bot:GetLocation())

				if J.IsValidTarget(tTarget)
				and tTarget:GetTeam() ~= bot:GetTeam()
				then
					return BOT_ACTION_DESIRE_MODERATE, tTarget
				end
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderTreeGrab()
	if not TreeGrab:IsFullyCastable()
	or bot:HasModifier('modifier_tiny_tree_grab')
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nEnemyHeroes = J.GetNearbyHeroes(bot,700, true, BOT_MODE_NONE)

	-- [GH #88] An `and bot:GetHealth() > 0.15` clause used to sit between the
	-- two below. GetHealth() returns HIT POINTS, so it was true on every frame
	-- it could be evaluated in: X.SkillsComplement returns early on
	-- J.CanNotUseAbility(bot), whose FIRST clause is `not bot:IsAlive()`, so
	-- this line only ever ran with at least 1 hp. Deleting it is therefore
	-- behaviour-equivalent, and it is deleted rather than repaired on purpose:
	--
	--   * Repairing it to `J.GetHP(bot) > 0.15` would be a NEW VETO -- a
	--     behaviour change, which by team rule needs a gate plus condition (a)
	--     evidence from a real game. For Tiny that evidence is structurally
	--     unbuyable: the soak farm drafts only from the curated pool in
	--     tools/batch_test/soak/hero_pool.txt (41 heroes, no Tiny), and the
	--     archive agrees -- 0 appearances in 11048 banked validation games
	--     across 112 seeds. A gate no corpus can execute is armed == shipped,
	--     i.e. the axeblink trap by construction.
	--   * Condition (c) is weak on its own terms anyway. The two surviving
	--     clauses already require that Tiny is NOT retreating and that there is
	--     no enemy hero within 700, and Tree Grab is an instant self-buff that
	--     neither channels nor displaces him -- so the frames the repair would
	--     have vetoed are frames where nothing was threatening him. "The author
	--     meant 15%" is the target of a repair, not an argument for one.
	--
	-- Revive this only with a real reason, not with the typo as the reason.
	-- tests/test_tiny_treegrab_hp_noop.lua pins both halves and goes red if
	-- Tiny ever enters the draft pool (the one fact that would make (a) buyable).
	--
	-- Noted separately, deliberately NOT fixed here (one lever at a time): the
	-- search radius below is 1200, which is not the ability's cast range, so the
	-- queued Action_UseAbilityOnTree can walk Tiny some distance to reach the
	-- tree. That is a movement cost -- and the one cost an hp floor here might
	-- genuinely have addressed -- but it is a different defect with a different
	-- fix, and it is present at every hp value, not just below 15%.
	if not J.IsRetreating(bot)
	and bot:DistanceFromFountain() > 800
	and nEnemyHeroes ~= nil and #nEnemyHeroes == 0
	then
		local nTrees = bot:GetNearbyTrees(1200)

		if nTrees ~= nil and #nTrees > 0
		and (IsLocationVisible(GetTreeLocation(nTrees[1]))
			or IsLocationPassable(GetTreeLocation(nTrees[1])))
		then
			return BOT_ACTION_DESIRE_HIGH, nTrees[1]
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderTreeThrow()
	if not TreeThrow:IsFullyCastable()
	or not bot:HasModifier('modifier_tiny_tree_grab')
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nCastRange = TreeThrow:GetSpecialValueInt('range')
	local nDamage = bot:GetAttackDamage()
	local nAttackCount = bot:GetModifierStackCount(bot:GetModifierByName('modifier_tiny_tree_grab'))
	local botTarget = J.GetProperTarget(bot)

	local nEnemyHeroes = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nEnemyHeroes)
	do
		if J.IsValidHero(enemyHero)
		and J.IsInRange(bot, enemyHero, nCastRange)
		and not J.IsSuspiciousIllusion(enemyHero)
		then
			if (J.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_PHYSICAL)
				or J.IsRetreating(bot) and J.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_PHYSICAL))
			and not enemyHero:HasModifier('modifier_abaddon_aphotic_shield')
			and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
			and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
			and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
			and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end

	if J.IsGoingOnSomeone(bot)
	then
		local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange + 100, false, BOT_MODE_NONE)
		local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

		if J.IsValidTarget(botTarget)
		and J.IsInRange(bot, botTarget, nCastRange)
		and not J.IsInRange(bot, botTarget, bot:GetAttackRange() + 50)
		and not J.IsSuspiciousIllusion(botTarget)
		and not botTarget:HasModifier('modifier_abaddon_aphotic_shield')
		and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
		and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
		and not botTarget:HasModifier('modifier_oracle_false_promise_timer')
		and not botTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
		and nInRangeAlly ~= nil and nInRangeEnemy ~= nil
		and #nInRangeAlly >= #nInRangeEnemy
		and nAttackCount <= 2
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end

	if J.IsRetreating(bot)
	then
		local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange + 100, false, BOT_MODE_NONE)
		local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
		local weakestTarget = J.GetVulnerableWeakestUnit(bot, true, true, nCastRange)

		if nInRangeAlly ~= nil and nInRangeEnemy ~= nil
		and ((#nInRangeEnemy > #nInRangeAlly)
			or (J.GetHP(bot) < 0.65 and bot:WasRecentlyDamagedByAnyHero(2)))
		and J.IsValidTarget(weakestTarget)
		and not J.IsSuspiciousIllusion(weakestTarget)
		and not weakestTarget:HasModifier('modifier_abaddon_aphotic_shield')
		and not weakestTarget:HasModifier('modifier_abaddon_borrowed_time')
		and not weakestTarget:HasModifier('modifier_dazzle_shallow_grave')
		and not weakestTarget:HasModifier('modifier_oracle_false_promise_timer')
		and not weakestTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
		then
			return BOT_ACTION_DESIRE_HIGH, weakestTarget
		end
	end

	if J.IsLaning(bot)
	then
		local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nCastRange, true)

		for _, creep in pairs(nEnemyLaneCreeps)
		do
			if J.IsValid(creep)
			and (J.IsKeyWordUnit('ranged', creep) or J.IsKeyWordUnit('siege', creep))
			and creep:GetHealth() <= nDamage
			then
				local nInRangeEnemy = J.GetNearbyHeroes(bot,1600, true, BOT_MODE_NONE)

				if nInRangeEnemy ~= nil and #nInRangeEnemy >= 1
				and GetUnitToUnitDistance(creep, nInRangeEnemy[1]) <= 600
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderTreeVolley()
	if bot:HasScepter()
	or not TreeVolley:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end

	local nCastRange = J.GetProperCastRange(false, bot, TreeVolley:GetCastRange())
	local nCastPoint = TreeVolley:GetCastPoint()
	local nRadius = TreeVolley:GetSpecialValueInt('tree_grab_radius')
	local nSplashRadius = TreeVolley:GetSpecialValueInt('splash_radius')
	local botTarget = J.GetProperTarget(bot)

	if J.IsInTeamFight(bot, 1200)
	then
		local nTrees = bot:GetNearbyTrees(nRadius)

		if #nTrees >= 3
		then
			local nLocationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nSplashRadius, nCastPoint, 0)

			if nLocationAoE.count >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, nLocationAoE.targetloc
			end
		end
	end

	if J.IsGoingOnSomeone(bot)
	then
		local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange + 100, false, BOT_MODE_NONE)
		local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

		if J.IsValidTarget(botTarget)
		and J.IsValidTarget(botTarget)
		and not J.IsSuspiciousIllusion(botTarget)
		and not botTarget:HasModifier('modifier_abaddon_aphotic_shield')
		and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
		and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
		and not botTarget:HasModifier('modifier_oracle_false_promise_timer')
		and not botTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
		and nInRangeAlly ~= nil and nInRangeEnemy ~= nil
		and #nInRangeAlly >= #nInRangeEnemy
		and GetUnitToUnitDistance(bot, botTarget) >= 500
		then
			local nTrees = bot:GetNearbyTrees(nRadius)

			if #nTrees >= 3
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end

	return BOT_ACTION_DESIRE_NONE, 0
end

function X.ConsiderBlinkToss()
    if CanDoBlinkToss()
    then
		local nCastRange = J.GetProperCastRange(false, bot, Toss:GetCastRange())
		local nRadius = Toss:GetSpecialValueInt('grab_radius')
		local botTarget = J.GetProperTarget(bot)

		if J.IsGoingOnSomeone(bot)
		then
			local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
			local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)

			if J.IsValidTarget(botTarget)
			and J.CanCastOnNonMagicImmune(botTarget)
			and not J.IsSuspiciousIllusion(botTarget)
			and not J.IsDisabled(botTarget)
			and not botTarget:HasModifier('modifier_faceless_void_chronosphere_freeze')
			and not botTarget:HasModifier('modifier_legion_commander_duel')
			and nInRangeAlly ~= nil and nInRangeEnemy ~= nil
			and #nInRangeAlly >= #nInRangeEnemy
			and #nInRangeAlly >= 1
			then
				if J.IsInRange(bot, botTarget, nCastRange)
				and GetUnitToUnitDistance(bot, botTarget) > nRadius
				then
					BlinkLocation = botTarget:GetLocation()
					return BOT_ACTION_DESIRE_HIGH, nInRangeAlly[#nInRangeAlly]
				end
			end
		end
    end

    return BOT_ACTION_DESIRE_NONE
end

function CanDoBlinkToss()
    if Toss:IsFullyCastable()
    and Blink ~= nil and Blink:IsFullyCastable()
    then
        local manaCost = Toss:GetManaCost()

        if bot:GetMana() >= manaCost
        then
            return true
        end
    end

    return false
end

function HasBlink()
    local blink = nil

    for i = 0, 5
    do
		local item = bot:GetItemInSlot(i)

		if item ~= nil
        and (item:GetName() == "item_blink" or item:GetName() == "item_overwhelming_blink" or item:GetName() == "item_arcane_blink" or item:GetName() == "item_swift_blink")
        then
			blink = item
			break
		end
	end

    if blink ~= nil
    and blink:IsFullyCastable()
	then
        Blink = blink
        return true
	end

    return false
end

return X