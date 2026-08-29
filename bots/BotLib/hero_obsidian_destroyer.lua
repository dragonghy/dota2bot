local X = {}
local bot = GetBot()

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Minion = dofile( GetScriptDirectory()..'/FunLib/aba_minion' )
local sTalentList = J.Skill.GetTalentList( bot )
local sAbilityList = J.Skill.GetAbilityList( bot )
local sRole = J.Item.GetRoleItemsBuyList( bot )

local tTalentTreeList = {
						['t25'] = {0, 10},
						['t20'] = {0, 10},
						['t15'] = {10, 0},
						['t10'] = {10, 0},
}

local tAllAbilityBuildList = {
						{2,1,4,2,2,6,2,1,1,1,6,4,4,4,6},--pos2
}

-- [GH #287 §2] Soak candidate 'odbuild' (turbo-only). The SAME row with its
-- one mis-resolved index aimed at the ability the row's own arithmetic says it
-- meant. Nothing else about the order moves -- this is an index repair, not a
-- rethink of the build.
--
-- WHAT THE INDEX RESOLVES TO. J.Skill.GetAbilityList (bots/FunLib/aba_skill.lua)
-- walks the engine's slots in order; OD's slot row (tests/mock/hero_slots.lua,
-- from the game's own npc_heroes.txt) is
--   0 arcane_orb / 1 astral_imprisonment / 2 objurgation / 3 generic_hidden /
--   4 equilibrium / 5 sanity_eclipse
-- and the ultimate at slot >= 4 goes to the FIXED index 6. So the list this
-- hero is levelled from is
--   [1] arcane_orb  [2] astral_imprisonment  [3] objurgation
--   [4] generic_hidden  ([5] equilibrium, the innate, when the walk keeps it)
--   [6] sanity_eclipse
-- The shipped row above spends FOUR points on [4] and never names [3].
-- tests/test_build_index_resolution.lua measured [4] = 'generic_hidden' in 2 of
-- 2 drop-worlds, the only unconditional placeholder reference in the repo.
--
-- WHY [3] IS WHAT THE AUTHOR MEANT, not a guess. The row is 15 entries and
-- spends 4+4+4+3: OD has exactly three learnable basics (four ranks each) plus a
-- three-rank ultimate, so 15 only balances if the 4x block is a basic -- and the
-- only basic the row never names is the one at index 3. The two fixes GH #287
-- §2 proposed were written for a different mechanism (a nil at index 6 from an
-- ultimate below slot 4); OD's ultimate is at slot 5 and index 6 is already
-- written, so neither of them applies here.
--
-- WHAT IT BUYS. Today those four points buy nothing: the level-up consumer meets
-- 'generic_hidden' at the head and drops it (bots/ability_item_usage_generic.lua
-- :351, or the not-found branch above it -- which one depends on whether the
-- engine hands back a handle for the placeholder, and that is not readable
-- offline). Either way the point is not lost, but objurgation stays at rank 0
-- for the whole game, which makes X.ConsiderObjurgation below dead code: its
-- first condition is Objurgation:IsFullyCastable(), false at rank 0. That
-- handler is a mana-pool-scaling barrier (mana_pool_to_barrier_pct + barrier) on
-- a hero whose whole item build is mana, and it has never once run.
--
-- BOUNDS. This is a static reading of which index names what; it does not say
-- the fix wins games. Condition (a) is a replay question and is asked in the
-- report. Turbo-only and gated, so shipped behaviour is byte-identical until
-- 'odbuild' is armed.
local tObjurgationBuildList = {
						{2,1,3,2,2,6,2,1,1,1,6,3,3,3,6},--pos2, index 4 -> 3
}

local nAbilityBuildList
if J.IsModeTurbo() and J.IsSoakCandidate( 'odbuild' ) then
	nAbilityBuildList = J.Skill.GetRandomBuild( tObjurgationBuildList )
else
	nAbilityBuildList = J.Skill.GetRandomBuild( tAllAbilityBuildList )
end

local nTalentBuildList = J.Skill.GetTalentBuild( tTalentTreeList )

local sRoleItemsBuyList = {}

sRoleItemsBuyList['pos_2'] = {
    "item_tango",
    "item_double_branches",
    "item_faerie_fire",

    "item_double_null_talisman",
    "item_power_treads",
    "item_magic_wand",
    "item_witch_blade",
    "item_blink",
    "item_dragon_lance",
    "item_black_king_bar",--
    "item_force_staff",
    "item_hurricane_pike",--
    "item_aghanims_shard",
    "item_devastator",--
    "item_travel_boots",
    "item_moon_shard",
    "item_sheepstick",--
    "item_arcane_blink",--
    "item_travel_boots_2",--
    "item_ultimate_scepter_2",
}

sRoleItemsBuyList['pos_1'] = sRoleItemsBuyList['pos_2']

sRoleItemsBuyList['pos_3'] = sRoleItemsBuyList['pos_2']

sRoleItemsBuyList['pos_4'] = sRoleItemsBuyList['pos_2']

sRoleItemsBuyList['pos_5'] = sRoleItemsBuyList['pos_2']

X['sBuyList'] = sRoleItemsBuyList[sRole]

X['sSellList'] = {
    "item_null_talisman",
    "item_magic_wand",
}

if J.Role.IsPvNMode() or J.Role.IsAllShadow() then X['sBuyList'], X['sSellList'] = { 'PvN_mid' }, {} end

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

local ArcaneOrb             = bot:GetAbilityByName('obsidian_destroyer_arcane_orb')
local AstralImprisonment    = bot:GetAbilityByName('obsidian_destroyer_astral_imprisonment')
local EssenceAura           = bot:GetAbilityByName('obsidian_destroyer_essence_aura')
local SanitysEclipse        = bot:GetAbilityByName('obsidian_destroyer_sanity_eclipse')
local Objurgation           = bot:GetAbilityByName('obsidian_destroyer_objurgation')

local ArcaneOrbDesire, ArcaneOrbTarget
local AstralImprisonmentDesire, AstralImprisonmentTarget
local SanitysEclipseDesire, SanitysEclipseLocation
local ObjurgationDesire

function X.SkillsComplement()
    if J.CanNotUseAbility(bot) then return end

	if ArcaneOrb:IsTrained()
	and ArcaneOrb:GetAutoCastState( ) == false
	and bot:GetLevel() >= 9
	then
		ArcaneOrb:ToggleAutoCast()
	end

    ObjurgationDesire = X.ConsiderObjurgation()
    if ObjurgationDesire > 0
    then
        bot:Action_UseAbility(Objurgation)
        return
    end

    SanitysEclipseDesire, SanitysEclipseLocation = X.ConsiderSanitysEclipse()
    if SanitysEclipseDesire > 0
    then
        bot:Action_UseAbilityOnLocation(SanitysEclipse, SanitysEclipseLocation)
        return
    end

    AstralImprisonmentDesire, AstralImprisonmentTarget = X.ConsiderAstralImprisonment()
    if AstralImprisonmentDesire > 0
    then
        bot:Action_UseAbilityOnEntity(AstralImprisonment, AstralImprisonmentTarget)
        return
    end

    ArcaneOrbDesire, ArcaneOrbTarget = X.ConsiderArcaneOrb()
    if ArcaneOrbDesire > 0
    then
        bot:Action_UseAbilityOnEntity(ArcaneOrb, ArcaneOrbTarget)
        return
    end
end

function X.ConsiderArcaneOrb()
    if not ArcaneOrb:IsFullyCastable()
    or ArcaneOrb:GetAutoCastState()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nMul = ArcaneOrb:GetSpecialValueInt('mana_pool_damage_pct') / 100
    local nDamage = bot:GetAttackDamage() + bot:GetMana() * nMul
    local nAttackRange = bot:GetAttackRange()
    local botTarget = J.GetProperTarget(bot)

    if J.IsGoingOnSomeone(bot)
	then
        local weakestTarget = J.GetVulnerableWeakestUnit(bot, true, true, nAttackRange)
        local nInRangeAlly = J.GetNearbyHeroes(bot,800, false, BOT_MODE_NONE)

		if J.IsValidTarget(weakestTarget)
        and not J.IsSuspiciousIllusion(weakestTarget)
        and not weakestTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not weakestTarget:HasModifier('modifier_dazzle_shallow_grave')
        and not weakestTarget:HasModifier('modifier_necrolyte_reapers_scythe')
        and not weakestTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
		then
            local nTargetInRangeAlly = J.GetNearbyHeroes(weakestTarget, 800, false, BOT_MODE_NONE)

            if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
            and #nInRangeAlly >= #nTargetInRangeAlly
            then
                return BOT_ACTION_DESIRE_HIGH, weakestTarget
            end
		end
	end

    -- if J.IsLaning(bot)
	-- then
	-- 	local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(nAttackRange + 200, true)

	-- 	for _, creep in pairs(nEnemyLaneCreeps)
	-- 	do
	-- 		if J.IsValid(creep)
	-- 		and J.CanKillTarget(creep, nDamage, DAMAGE_TYPE_PURE)
	-- 		then
	-- 			local nCreepInRangeHero = creep:GetNearbyHeroes(500, false, BOT_MODE_NONE)

	-- 			if nCreepInRangeHero ~= nil and #nCreepInRangeHero >= 1
	-- 			then
	-- 				return BOT_ACTION_DESIRE_HIGH, creep
	-- 			end
	-- 		end
	-- 	end
	-- end

    if J.IsDoingRoshan(bot)
    then
        if J.IsRoshan(botTarget)
        and J.CanCastOnNonMagicImmune(botTarget)
        and J.IsInRange(bot, botTarget, 500)
        and J.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

    if J.IsDoingTormentor(bot)
    then
        if J.IsTormentor(botTarget)
        and J.IsInRange(bot, botTarget, 400)
        and J.IsAttacking(bot)
        then
            return BOT_ACTION_DESIRE_HIGH, botTarget
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderAstralImprisonment()
    if not AstralImprisonment:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    local nCastRange = AstralImprisonment:GetCastRange()
	local nDamage = AstralImprisonment:GetSpecialValueInt('damage')
    local nDuration = AstralImprisonment:GetSpecialValueInt('prison_duration')
    local botTarget = J.GetProperTarget(bot)

    local nEnemyHeroes = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
    for _, enemyHero in pairs(nEnemyHeroes)
    do
        if J.IsValidHero(enemyHero)
        and J.CanCastOnNonMagicImmune(enemyHero)
        and not J.IsSuspiciousIllusion(enemyHero)
        then
            if enemyHero:IsChanneling() or J.IsCastingUltimateAbility(enemyHero)
            then
                return BOT_ACTION_DESIRE_HIGH, enemyHero
            end

            local nInRangeAlly = J.GetNearbyHeroes(bot,1000, false, BOT_MODE_NONE)

            if J.CanKillTarget(enemyHero, nDamage, DAMAGE_TYPE_MAGICAL)
            and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
            and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
            and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
            and not enemyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
            and nInRangeAlly ~= nil and #nInRangeAlly <= 1
            then
                return BOT_ACTION_DESIRE_HIGH, enemyHero
            end
        end
    end

	if J.IsInTeamFight(bot, 1200)
	then
        local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
        for _, allyHero in pairs(nInRangeAlly)
        do
            if J.IsValidHero(allyHero)
            and not allyHero:IsIllusion()
            and allyHero:WasRecentlyDamagedByAnyHero(1)
            then
                if allyHero:HasModifier('modifier_enigma_black_hole_pull')
                or allyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
                or allyHero:HasModifier('modifier_legion_commander_duel')
                or allyHero:HasModifier('modifier_necrolyte_reapers_scythe')
                or J.GetHP(allyHero) < 0.33
                then
                    return BOT_ACTION_DESIRE_HIGH, allyHero
                end
            end
        end

        local strongestTarget = J.GetStrongestUnit(nCastRange + 150, bot, true, false, nDuration)
        if strongestTarget == nil
        then
            strongestTarget = J.GetStrongestUnit(nCastRange + 250, bot, true, true, nDuration)
        end
        if J.IsValidTarget(strongestTarget) then
            local nTargetInRangeAlly = J.GetNearbyHeroes(strongestTarget, 800, false, BOT_MODE_NONE)
            if #nTargetInRangeAlly >= 2 then
                if J.IsInRange(bot, strongestTarget, nCastRange)
                and not J.IsSuspiciousIllusion(strongestTarget)
                and not J.IsDisabled(strongestTarget)
                and not J.IsTaunted(strongestTarget)
                and not strongestTarget:HasModifier('modifier_abaddon_borrowed_time')
                and not strongestTarget:HasModifier('modifier_dazzle_shallow_grave')
                and not strongestTarget:HasModifier('modifier_enigma_black_hole_pull')
                and not strongestTarget:HasModifier('modifier_faceless_void_chronosphere_freeze')
                and not strongestTarget:HasModifier('modifier_necrolyte_reapers_scythe')
                and not strongestTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
                then
                    return BOT_ACTION_DESIRE_HIGH, strongestTarget
                end
            end
        end
	end

    if J.IsGoingOnSomeone(bot)
	then
		if J.IsValidTarget(botTarget)
        and J.CanCastOnNonMagicImmune(botTarget)
        and J.IsInRange(bot, botTarget, nCastRange)
        and not J.IsSuspiciousIllusion(botTarget)
        and not J.IsDisabled(botTarget)
        and not J.IsTaunted(botTarget)
        and not botTarget:HasModifier('modifier_abaddon_borrowed_time')
        and not botTarget:HasModifier('modifier_dazzle_shallow_grave')
        and not botTarget:HasModifier('modifier_enigma_black_hole_pull')
        and not botTarget:HasModifier('modifier_faceless_void_chronosphere_freeze')
        and not botTarget:HasModifier('modifier_necrolyte_reapers_scythe')
        and not botTarget:HasModifier('modifier_templar_assassin_refraction_absorb')
		then
            local nInRangeAlly = J.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
            -- 1v1
            local nTargetInRangeAlly = J.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
            if #nInRangeAlly <= 1 and #nTargetInRangeAlly <= 1 then return BOT_ACTION_DESIRE_HIGH, botTarget end

            -- has more then 1 enemy and target has high hp
            if #nTargetInRangeAlly >= 2 and J.GetHP(botTarget) > 0.8 then return BOT_ACTION_DESIRE_HIGH, botTarget end

            local isChasing = J.IsChasingTarget(bot, botTarget)
            -- more ally v less enemy but target not running
            if #nInRangeAlly >= 2 and #nTargetInRangeAlly <= 1 and not isChasing then return BOT_ACTION_DESIRE_NONE, nil end
            if #nInRangeAlly > 2 and #nInRangeAlly > #nTargetInRangeAlly and not isChasing then return BOT_ACTION_DESIRE_NONE, nil end

            -- more ally v less enemy and target running
            if #nInRangeAlly >= #nTargetInRangeAlly and isChasing then return BOT_ACTION_DESIRE_HIGH, botTarget end
            local nInLongRangeAlly = J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
            if #nInLongRangeAlly > #nInRangeAlly
            and #nInLongRangeAlly > #nTargetInRangeAlly
            and J.IsRunning(botTarget)
            then
                return BOT_ACTION_DESIRE_HIGH, botTarget
            end
		end
	end

    if J.IsRetreating(bot)
    then
        local nInRangeAlly = J.GetNearbyHeroes(bot,800, false, BOT_MODE_NONE)
        local nInRangeEnemy = J.GetNearbyHeroes(bot,800, true, BOT_MODE_NONE)

        if nInRangeAlly ~= nil and nInRangeEnemy
        and J.IsValidHero(nInRangeEnemy[1])
        and J.CanCastOnNonMagicImmune(nInRangeEnemy[1])
        and J.IsInRange(bot, nInRangeEnemy[1], nCastRange)
        and J.IsRunning(nInRangeEnemy[1])
        and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
        and not J.IsSuspiciousIllusion(nInRangeEnemy[1])
        and not J.IsDisabled(nInRangeEnemy[1])
        and not nInRangeEnemy[1]:HasModifier('modifier_enigma_black_hole_pull')
        and not nInRangeEnemy[1]:HasModifier('modifier_faceless_void_chronosphere_freeze')
        and not nInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
        then
            local nTargetInRangeAlly = J.GetNearbyHeroes(nInRangeEnemy[1], 800, false, BOT_MODE_NONE)

            if nTargetInRangeAlly ~= nil
            and ((#nTargetInRangeAlly > #nInRangeAlly)
                or (J.GetHP(bot) < 0.72 and bot:WasRecentlyDamagedByAnyHero(1.9)))
            then
                return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1]
            end
        end
    end

    if J.IsLaning(bot)
    and J.IsInLaningPhase()
	then
		if J.GetMP(bot) > 0.65
        then
            local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
            for _, enemyHero in pairs(nInRangeEnemy)
            do
                if J.IsValidHero(enemyHero)
                and J.CanCastOnNonMagicImmune(enemyHero)
                and J.IsAttacking(enemyHero)
                and not J.IsSuspiciousIllusion(enemyHero)
                and (not enemyHero:IsDisarmed()
                    or not enemyHero:IsStunned()
                    or not enemyHero:IsHexed())
                then
                    return BOT_ACTION_DESIRE_HIGH, enemyHero
                end
            end
        end
	end

    if J.IsDoingTormentor(bot)
    then
        if J.IsTormentor(botTarget)
        and J.IsInRange(bot, botTarget, 400)
        then
            if J.GetHP(bot) < 0.2
            then
                return BOT_ACTION_DESIRE_HIGH, bot
            end

            local nInRangeAlly = J.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
            for _, allyHero in pairs(nInRangeAlly)
            do
                if J.IsValidHero(allyHero)
                and J.GetHP(allyHero) < 0.3
                and not allyHero:IsIllusion()
                and not allyHero:HasModifier('modifier_abaddon_borrowed_time')
                and not allyHero:HasModifier('modifier_dazzle_shallow_grave')
                and not allyHero:HasModifier('modifier_templar_assassin_refraction_absorb')
                then
                    return BOT_ACTION_DESIRE_HIGH, allyHero
                end
            end
        end
    end

    local nAllyHeroes = J.GetNearbyHeroes(bot,nCastRange, false, BOT_MODE_NONE)
    for _, allyHero in pairs(nAllyHeroes)
    do
        local nAllyInRangeEnemy = J.GetNearbyHeroes(allyHero, nCastRange, true, BOT_MODE_NONE)

        if J.IsRetreating(allyHero)
        and allyHero:WasRecentlyDamagedByAnyHero(1.6)
        and not allyHero:IsChanneling()
        and not allyHero:IsIllusion()
        and J.GetMP(bot) > 0.31
        then
            if nAllyInRangeEnemy ~= nil and #nAllyInRangeEnemy >= 1
            and J.IsValidHero(nAllyInRangeEnemy[1])
            and J.CanCastOnNonMagicImmune(nAllyInRangeEnemy[1])
            and J.IsInRange(allyHero, nAllyInRangeEnemy[1], 400)
            and J.IsInRange(bot, nAllyInRangeEnemy[1], nCastRange)
            and J.IsRunning(allyHero)
            and nAllyInRangeEnemy[1]:IsFacingLocation(allyHero:GetLocation(), 30)
            and not J.IsDisabled(nAllyInRangeEnemy[1])
            and not J.IsTaunted(nAllyInRangeEnemy[1])
            and not J.IsSuspiciousIllusion(nAllyInRangeEnemy[1])
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_legion_commander_duel')
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_enigma_black_hole_pull')
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_faceless_void_chronosphere_freeze')
            and not nAllyInRangeEnemy[1]:HasModifier('modifier_necrolyte_reapers_scythe')
            then
                return BOT_ACTION_DESIRE_HIGH, nAllyInRangeEnemy[1]
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

function X.ConsiderSanitysEclipse()
    if not SanitysEclipse:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE, 0
    end

	local nCastRange = SanitysEclipse:GetCastRange()
	local nMultiplier = SanitysEclipse:GetSpecialValueFloat('damage_multiplier')
    local nBaseDamage = SanitysEclipse:GetSpecialValueFloat('base_damage')
    local nRadius = SanitysEclipse:GetSpecialValueInt('radius')

    if J.IsGoingOnSomeone(bot)
	then
        local nInRangeAlly = J.GetNearbyHeroes(bot,1200, false, BOT_MODE_NONE)

        local nInRangeEnemy = J.GetNearbyHeroes(bot,nCastRange, true, BOT_MODE_NONE)
        for _, enemyHero in pairs(nInRangeEnemy)
        do
            if J.IsValidTarget(enemyHero)
            and J.CanCastOnNonMagicImmune(enemyHero)
            and not J.IsSuspiciousIllusion(enemyHero)
            and not enemyHero:HasModifier('modifier_abaddon_borrowed_time')
            and not enemyHero:HasModifier('modifier_dazzle_shallow_grave')
            and not enemyHero:HasModifier('modifier_enigma_black_hole_pull')
            and not enemyHero:HasModifier('modifier_faceless_void_chronosphere_freeze')
            and not enemyHero:HasModifier('modifier_legion_commander_duel')
            and not enemyHero:HasModifier('modifier_necrolyte_reapers_scythe')
            and not enemyHero:HasModifier('modifier_oracle_false_promise_timer')
            then
                local nTargetInRangeAlly = J.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
                local nManaDiff = math.abs(bot:GetMana() - enemyHero:GetMana())
                local nDamage = nManaDiff * nMultiplier

                if nInRangeAlly ~= nil and nTargetInRangeAlly ~= nil
                and #nInRangeAlly >= #nTargetInRangeAlly
                and J.CanKillTarget(enemyHero, nBaseDamage + nDamage, DAMAGE_TYPE_MAGICAL)
                then
                    return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
                end
            end
        end

        -- GH #54: the loop above is the ONLY exit this ability has, and it asks
        -- an area nuke a single-target question ("can this one enemy be killed
        -- by it"). The gated branch below adds the missing area criterion. It
        -- deliberately sits BELOW the loop, so every frame the shipped code
        -- already acts on keeps its shipped decision byte for byte -- armed,
        -- this can only turn a NONE into a cast, never redirect a cast.
        local vAoeLoc = X.od_GetEclipseAoeLocation(bot, nCastRange, nRadius, nBaseDamage, nMultiplier)
        if vAoeLoc ~= nil
        then
            return BOT_ACTION_DESIRE_HIGH, vAoeLoc
        end
	end

    return BOT_ACTION_DESIRE_NONE, 0
end

-- How many enemies one cast must cover before the area branch fires, and how
-- much of an enemy's CURRENT health the cast must be worth for that enemy to
-- count towards the total. Both are read by tests/test_replay_260819_od_eclipse_aoe.lua.
X.nRAoeMinTargets   = 2
X.nRAoeMinDamagePct = 0.25

--- Is this enemy worth counting as one of the area cast's targets?
--- Sanity's Eclipse damage is (caster mana - target mana) * multiplier + base,
--- so an enemy whose mana is at or above OD's own takes nothing from it and
--- must not inflate the coverage count.
--- The shipped loop's modifier blacklist (borrowed time, shallow grave, duel,
--- reaper's scythe, ...) is NOT reproduced here on purpose: those all answer
--- "will this one enemy actually die", which is exactly the question this
--- branch does not ask -- a chrono'd or grave'd enemy is still real damage
--- taken by everyone else caught in the same circle.
--- Nor is J.IsSuspiciousIllusion re-checked: J.CanCastOnNonMagicImmune already
--- ends in that exact call (jmz_func.lua), so a second one would be dead code
--- -- and illusion padding is a live risk in this very replay, so the test
--- suite pins the cross-layer fact instead of a branch that cannot run.
function X.od_IsEclipseWorthHitting(hBot, hEnemy, nBaseDamage, nMultiplier)
    if not J.IsValidTarget(hEnemy)
    or not J.CanCastOnNonMagicImmune(hEnemy)
    then
        return false
    end

    local nManaGap = hBot:GetMana() - hEnemy:GetMana()
    if nManaGap <= 0 then return false end

    local nDamage = nBaseDamage + nManaGap * nMultiplier

    return nDamage >= hEnemy:GetHealth() * X.nRAoeMinDamagePct
end

--- Best point to drop Sanity's Eclipse on, or nil for "no area cast here".
--- Gated: turbo-only, soak candidate 'odaoe'. Unarmed it returns nil on its
--- first line, so the shipped decision is unchanged down to the byte.
---
--- CORPUS PRE-FLIGHT 2026-08-21 (hero stream, test_set.md section V.7):
--- the domain is REACHABLE -- unlike `wkreincarnmp` and `axeblink`, which were
--- both withdrawn as unreachable. Over the 19-game 2026-08-19 22:11Z turbo
--- wave (9 of them with OD), armed differs from shipped on 30 frames = 10
--- EPISODES spread over 7 of the 9 games, ~1.1 episodes/game. Quote the
--- episode number, not the frame number (director ruling, test_set.md Z.2).
--- Load-bearing clause is SUPPLY, not a competing guard: 4092 castable frames
--- -> 47 with >= 2 living enemies inside the 700 cast range (-98.9%); the two
--- tunables below then cost only -6 and -1, and the shipped loop pre-empts 10.
--- AUDITED LIVENESS (director's two columns, test_set.md section AA.2): the
--- numbers above are the re-read on `roam_conversion.is_dead()` (DEATH event
--- -> respawn), not the condemned `hp > 0` proxy. The proxy cost exactly ONE
--- frame and ZERO episodes (31/10 -> 30/10): OD's own snapshot stamped at his
--- DEATH tick, still reading 29 HP (20260819_223055 t=650.5). And 8 of the 10
--- episodes are >= 2 frames long, while the measured post-DEATH lag stays
--- under one 0.5s sample, so a phantom can only forge a length-1 episode --
--- the domain survives the audit on both columns.
--- So retuning nRAoeMinTargets / nRAoeMinDamagePct buys almost nothing; the
--- ceiling is set by how rarely two enemies stand within 700 of OD.
--- The band this branch opens is coherent: median 620 effective damage split
--- over two heroes, typically ~85-96% of one target's current HP plus
--- ~25-60% of a second -- i.e. exactly the near-double-kill the shipped
--- single-target `CanKillTarget` question throws away.
--- FACT THAT PINS THE CONSTANTS: Sanity's Eclipse is level 1 in 9 games of 9
--- (turbo ends before the second point), so radius is always 500, base_damage
--- always 200 and cooldown always 140s -- the same "ult stuck at level 1"
--- family as Lion's Finger of Death (hero.md backlog #7). Datafeed hero_id=76,
--- pulled 2026-08-21: cast_range 700, radius 500/525/550, base_damage
--- 200/300/400, damage_multiplier 0.4, mana 200/300/400, cd 140/130/120.
--- Measurement tool: tools/batch_test/behavioral/od_eclipse_aoe_domain.py.
--- Every count there is an UPPER bound (J.IsGoingOnSomeone and fog are not in
--- the .dem), and arming needs a wave whose seeds actually draft OD -- only
--- 2 of the 4 lineups in that wave did (GH #46, one seed = one lineup).
--- Candidate centres are every worthwhile enemy's own position plus every
--- pairwise midpoint of them -- enough to cover any pair that a single circle
--- can hold at all, without depending on bot:FindAoELocation (which the engine
--- answers but a replay fixture cannot, GH #27 family).
function X.od_GetEclipseAoeLocation(hBot, nCastRange, nRadius, nBaseDamage, nMultiplier)
    if not (J.IsModeTurbo() and J.IsSoakCandidate('odaoe')) then return nil end

    if nCastRange == nil or nCastRange <= 0 or nRadius == nil or nRadius <= 0 then
        return nil
    end

    local tNearbyEnemy = J.GetNearbyHeroes(hBot, nCastRange, true, BOT_MODE_NONE)
    if tNearbyEnemy == nil or #tNearbyEnemy < X.nRAoeMinTargets then return nil end

    local tHittable = {}
    for _, hEnemy in pairs(tNearbyEnemy)
    do
        if X.od_IsEclipseWorthHitting(hBot, hEnemy, nBaseDamage, nMultiplier)
        then
            table.insert(tHittable, hEnemy)
        end
    end
    if #tHittable < X.nRAoeMinTargets then return nil end

    local tCandidate = {}
    for i = 1, #tHittable
    do
        local vFirst = tHittable[i]:GetLocation()
        table.insert(tCandidate, vFirst)
        for k = i + 1, #tHittable
        do
            -- NOTE: not named vJ -- tests/test_no_undefined_jmz_refs.lua scans
            -- for the literal 'J.' and would read vJ.x as a J.x helper call.
            local vSecond = tHittable[k]:GetLocation()
            table.insert(tCandidate, Vector((vFirst.x + vSecond.x) / 2,
                (vFirst.y + vSecond.y) / 2, (vFirst.z + vSecond.z) / 2))
        end
    end

    local vBest, nBest = nil, 0
    for _, vLoc in pairs(tCandidate)
    do
        -- Belt and braces: every candidate is either an enemy the engine
        -- already reported inside nCastRange or the midpoint of two of them,
        -- and a disk is convex, so this can only fail if the engine's own
        -- radius disagrees with a straight-line distance (hull radii). No test
        -- can reach the false side; it is pinned by a source-level tripwire.
        if GetUnitToLocationDistance(hBot, vLoc) <= nCastRange
        then
            local nCovered = 0
            for _, hEnemy in pairs(tHittable)
            do
                if GetUnitToLocationDistance(hEnemy, vLoc) <= nRadius
                then
                    nCovered = nCovered + 1
                end
            end

            if nCovered > nBest
            then
                vBest, nBest = vLoc, nCovered
            end
        end
    end

    if nBest >= X.nRAoeMinTargets then return vBest, nBest end

    return nil
end

function X.ConsiderObjurgation()
    if not Objurgation:IsFullyCastable()
    then
        return BOT_ACTION_DESIRE_NONE
    end

    local nBarrierPct = Objurgation:GetSpecialValueFloat('mana_pool_to_barrier_pct') / 100
    local nBarrierFlat = Objurgation:GetSpecialValueFloat('barrier')
    local nBarrier = nBarrierFlat + bot:GetMana() * nBarrierPct

    if J.IsInTeamFight(bot, 1200)
    then
        if J.GetHP(bot) < 0.7
        and bot:WasRecentlyDamagedByAnyHero(2)
        then
            return BOT_ACTION_DESIRE_HIGH
        end

        local nInRangeEnemy = J.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
        if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    if J.IsGoingOnSomeone(bot)
    then
        local botTarget = J.GetProperTarget(bot)
        local nInRangeEnemy = J.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)

        if J.IsValidTarget(botTarget)
        and nInRangeEnemy ~= nil and #nInRangeEnemy >= 1
        and J.IsInRange(bot, botTarget, bot:GetAttackRange() + 200)
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    if J.IsRetreating(bot)
    then
        if J.GetHP(bot) < 0.5
        and bot:WasRecentlyDamagedByAnyHero(2)
        then
            return BOT_ACTION_DESIRE_HIGH
        end
    end

    return BOT_ACTION_DESIRE_NONE
end

return X