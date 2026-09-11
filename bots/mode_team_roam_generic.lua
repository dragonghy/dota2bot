local bot = GetBot()
local botName = bot:GetUnitName()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return end

local Utils = require(GetScriptDirectory()..'/FunLib/utils')
local EnemyRoles = require(GetScriptDirectory()..'/FunLib/enemy_role_estimation')
local Localization = require(GetScriptDirectory()..'/FunLib/localization')
local Customize = require(GetScriptDirectory()..'/Customize/general')
Customize.ThinkLess = Customize.Enable and Customize.ThinkLess or 1
local J = require(GetScriptDirectory()..'/FunLib/jmz_func')
local Item = require(GetScriptDirectory()..'/FunLib/aba_item')
local Roles = require(GetScriptDirectory()..'/FunLib/aba_role')
local AttackSpecialUnit = dofile(GetScriptDirectory()..'/FunLib/aba_special_units')

local X = {}
local team = GetTeam()

-- ==============================
-- Runtime state
-- ==============================
local targetUnit = nil
local towerCreepMode, towerCreep = false, nil
local towerTime, towerCreepTime = 0, 0
local nTpSolt = 15

local beInitDone, IsSupport, IsHeroCore, bePvNMode = false, false, false, false
local ShouldAttackSpecialUnit = false
local lastIdleStateCheck, isInIdleState = -1, false
local ShouldHelpAlly, ShouldHelpWhenCoreIsTargeted = false, false
local nearbyAllies, nearbyEnemies

-- Pickup / swap timers
local PickedItem = nil
local minPickItemCost = 200
local ignorePickupList, tryPickCount = {}, 0
local ConsiderDroppedTime = -90
local SwappedCheeseTime   = -90
local SwappedClarityTime  = -90
local SwappedFlaskTime    = -90
local SwappedSmokeTime    = -90
local SwappedRefresherShardTime = -90
local SwappedMoonshardTime = -90
-- [bagtango] Own throttle, never shared with SwappedFlaskTime: a shared stamp
-- would make the shipped flask rescuer's cadence depend on whether this id is
-- armed, i.e. the un-armed tree would stop being byte-identical.
local SwappedFieldRegenTime = -90
local lastCheckBotToDropTime = 0

local IsAvoidingAbilityZone = false

local hTargetCreep = nil

-- Target stickiness + desire clamp
local TARGET_LOCK_SEC = 1.2
local targetLockUntil = -90

local function SetStickyTarget(t)
    if t == nil then return end
    -- Don't switch targets too fast
    if targetUnit ~= nil and targetUnit ~= t and DotaTime() < targetLockUntil then
        return
    end
    targetUnit = t
    bot:SetTarget(t)
    targetLockUntil = DotaTime() + TARGET_LOCK_SEC
end

-- [GH #7/#20] Set when this frame's roam desire is a DEFENSIVE COLLAPSE (punish an
-- enemy diving our tower / over-chasing a low ally right next to us), as opposed
-- to an ordinary roam/gank. A collapse is a local, numbers-gated emergency; the
-- lane-push cap below must NOT throttle it. Reset each frame in GetDesireHelper.
local bDefensiveCollapse = false

-- [GH #31] Set when this frame's roam desire is a LANE-KILL COMMIT (L1-TRADE /
-- L5-COMBO below). Distinct from bDefensiveCollapse: those punish an enemy that
-- came to us, these initiate on an enemy laner. Both share the property that the
-- lane-push cap must not throttle them, for opposite-looking but identical
-- reasons -- see the cap's own comment. Reset each frame in GetDesireHelper.
local bLaneKillCommit = false

-- Pure, testable predicate (global, mirrors _suplh_* in mode_laning_generic):
-- given a raw roam desire, whether it is a defensive collapse, the puller bot,
-- and whether it is a lane-kill commit, return the lane-capped desire. Exposed
-- as a global so a unit test can drive it directly with controlled J stubs
-- rather than steering all of GetDesire.
-- [GH #7] EXEMPT a defensive collapse (tower-dive / over-chase punish): those
-- return 0.98 deliberately and were being soft-ceiled to 0.72 during laning --
-- exactly when tower dives happen -- so the punish lost to the bot's own laning
-- desire and the dive went unpunished (observed 4.6 unpunished dives/game with #7
-- nominally shipped). Uncapping a collapse during laning COULD cause
-- over-commitment, so the exemption is gated (turbo + 'divecap') until A/B.
-- [GH #31] EXEMPT a lane-kill commit (L1-TRADE / L5-COMBO). Those two branches
-- bid 0.92 to outbid the PROMOTED lanesurv retreat (0.75) -- that relative
-- ordering is the whole point of the value, see their comments below. But both
-- helpers HARD-REQUIRE J.IsInLaningPhase(), so the cap's own trigger condition is
-- a SUPERSET of their entire domain: every frame they can fire on is a frame the
-- cap fires on, so 0.92 was clobbered to 0.72 100% of the time. The literal was
-- unreachable and the effective bid landed BELOW the 0.75 it was chosen to beat,
-- with the perverse side effect of being non-monotonic in HP (a healthy core bid
-- 0.72, a half-HP one ~0.90). The cap is aimed at ordinary roam/gank drifting
-- into laning; a laning-phase-only lane kill IS laning micro, so it is not what
-- the cap is defending against. No extra soak gate here: the flag can only ever
-- be set from inside branches already gated on 'l1trade'/'l5combo', so shipped
-- defaults are untouched. Verified 15 mirror games / 333 opportunity episodes
-- showed no attributable effect from either id (replay-check, GH #31).
function _divecap_CapForLanePush(desire, bCollapse, hBot, bLaneKill)
    if bCollapse and J.IsModeTurbo() and J.IsSoakCandidate('divecap') then
        return desire
    end
    if bLaneKill then
        return desire
    end
    if J.IsInLaningPhase() or J.IsPushing(hBot) then
        -- [capmono, GH #31 follow-up] The line below calls itself a "soft
        -- ceiling" but implements a CLIFF: only desires >0.9 are pulled down,
        -- and they land at 0.72 -- BELOW everything in (0.72, 0.9] that passes
        -- untouched. Every remaining capped branch bids
        -- RemapValClamped(GetHP(bot), 0, 0.5|0.6, NONE, 0.98), so the effective
        -- bid is non-monotonic in HP with its MAXIMUM at ~46% HP: a full-HP
        -- hero collapses at 0.72 (loses to the promoted lanesurv retreat, 0.75)
        -- while a 43%-HP one collapses at ~0.84 and WINS -- the hero least able
        -- to survive the fight is the one pinned into it. That is the wave13
        -- pin-into-death shape the lane-kill branches carry
        -- J.ShouldReleaseLaneCommit to escape; ConsiderHelpAlly /
        -- ConsiderHelpWhenCoreIsTargeted / punish-dive / punish-over-chase have
        -- no such release. GH #31 fixed the same inversion for the lane-kill
        -- pair by EXEMPTING them; this is the opposite, strictly conservative
        -- half -- make the ceiling a real ceiling for everything still capped.
        -- It only ever LOWERS a desire, so it cannot cause the over-commitment
        -- that keeps the 'divecap' exemption gated. Gated turbo + 'capmono';
        -- shipped defaults are byte-for-byte the cliff below.
        if J.IsModeTurbo() and J.IsSoakCandidate('capmono') then
            if desire > 0.72 then return 0.72 end
            return desire
        end
        if desire > 0.9 then return 0.72 end  -- soft ceiling
    end
    return desire
end

local function CapForLanePush(desire)
    -- keep "team roam" from overpowering laning/pushing micro
    return _divecap_CapForLanePush(desire, bDefensiveCollapse, bot, bLaneKillCommit)
end

function GetDesire()
    -- local cacheKey = 'GetTeamRoamDesire'..tostring(bot:GetPlayerID())
    -- local cachedVar = J.Utils.GetCachedVars(cacheKey, 0.2 * (1 + Customize.ThinkLess))
    -- if DotaTime() > 30 and cachedVar ~= nil then return cachedVar end

    local res = GetDesireHelper()
    res = CapForLanePush(res)

    -- J.Utils.SetCachedVars(cacheKey, res)
    return res
end
function GetDesireHelper()
    bDefensiveCollapse = false
    bLaneKillCommit = false
    -- [roamstale] `hTargetCreep` is written in exactly ONE place -- the last-hit
    -- branch far below -- which sits UNDER every early-returning branch in this
    -- helper (ConsiderHelpWhenCoreIsTargeted, ConsiderHelpAlly, punish-dive,
    -- punish-over-chase, l1trade, l5combo). It is never reset, and Think() reads
    -- it FIRST and `return`s on it. So on every frame one of those branches wins
    -- the auction, this mode's Think attacks LAST FRAME'S creep and the collapse
    -- target the desire was computed from is never touched -- the desire says
    -- "collapse on the invader", the action says "keep last-hitting". That is
    -- the watched 232228 shape (WK, stun ready, hovering ~1000u from a 69% solo
    -- Juggernaut for 17s while the punish branch was bidding for him).
    -- Reset here, the variable means what its only writer and its only reader
    -- both assume: THIS frame's last-hit creep. It is reassigned below on every
    -- frame that reaches the branch, so the delta is confined to exactly the
    -- frames an early branch returned; it can only ever REMOVE a stale creep
    -- attack, never add one, and it changes no desire value anywhere (nothing
    -- reads hTargetCreep before its assignment).
    --
    -- PROMOTED (was soak-candidate 'roamstale') 2026-08-19; condition (a)
    -- RETRACTED and replaced 2026-08-21 (GH #94, test_set.md AG). The id is
    -- RETAINED on (c)+(b), not on (a) -- read the retraction before quoting
    -- any number from here.
    --   (a) RETRACTED -- the promoting number was a DiD, and the DiD's second
    --       term is not a control. Same 32 replays, re-decomposed as
    --       DiD = (Aarm-Barm) - (Abase-Bbase): out-of-domain "hit a hero within
    --       4s" reads ARMED A-B +7.7pp (p=0.0997, n=78/104) with the
    --       BASELINE-vs-BASELINE leg at -12.8pp (p=0.0079) -- ~63% of the
    --       registered +22.9pp lived between two legs running identical shipped
    --       code, so it cannot be this reset. Both arms ran the same 4 seeds and
    --       the same tree, so there is no arm-level nuisance for a DiD to
    --       remove; the isolated estimator is ARMED A-B alone (both candidate
    --       sides face opponents whose CODE is identical), and differencing the
    --       baseline leg in can only add variance. Under that estimator the
    --       out-of-domain benefit is DIRECTIONAL BUT UNESTABLISHED, and the
    --       better-powered in-domain window -- clean null leg (+0.4pp, p=0.93),
    --       supply ratio 0.98, 5x the episodes -- reads AGAINST the reset:
    --       delivery onto heroes -7.2pp (p=0.0128), zero-damage +7.1pp
    --       (p=0.0091). Episode count for this corpus is 2117, not the 1855
    --       first registered (the scanner changed under it after 08-19).
    --       Verdict: EXECUTES, isolated and measurable; benefit UNESTABLISHED.
    --       The retraction itself is threshold-free -- it is arithmetic on the
    --       registered DiD, so it holds whatever domain you scan. The in-domain
    --       COST is NOT threshold-free: it is scanned at VICTIM_HP = 0.40, the
    --       same free parameter GH #92 just walked (0.40 -> 1.01) to flip a
    --       neighbouring reading's sign monotonically. Its supply is balanced
    --       (0.98) where #92's artefact is zero, which is reassuring and is not
    --       a sweep. Quote the cost as PROVISIONAL until swept.
    --   (b) NO VISIBLE HARM -- A-B paired economic delta null on all four
    --       metrics: gpm +5.48 (z=+0.31), xpm +5.60, deaths -0.08,
    --       last_hits -0.05. Note the bound is wide (4-seed MDE ~35.6 gpm).
    --   (c) RATIONALE -- a plain unreset-handle defect: writer, reader and
    --       variable name all mean "this frame's creep", only the missing reset
    --       disagreed.
    -- MECHANISM, corrected by that same data (issue #39's shape was wrong, its
    -- direction right): the effect lives entirely at >=600u and the <=300u
    -- subset is flat, so a stale handle does NOT send the bot off to hit a
    -- creep -- Action_AttackUnit on a handle that has since died simply does
    -- nothing, and the bot stands still. What this reset restores is DELIVERY
    -- ONTO DISTANT TARGETS, not near-target selection.
    -- That mechanism correction is the one claim here that got INDEPENDENTLY
    -- CONFIRMED on 2026-08-21 rather than retracted: the creep-instead-of-hero
    -- signature reads 2.4% vs 2.4% in-domain (Fisher p=1.0000) and 0.0% vs 0.0%
    -- out-of-domain across the two arms -- the hijack the original issue named
    -- has an effect size of exactly zero, which is what "the bot stands still"
    -- predicts. It also rules this branch out as the -28 gpm shared-consumer
    -- defect (test_set.md AF.3): a behaviour both arms show 2.4% of the time
    -- cannot carry -28.
    -- Precision, because the distinction matters: what is confirmed is the
    -- "stands still, does not go hit a creep" half. The >=600u / <=300u split
    -- in the sentence above is itself a DiD-derived breakdown and inherits the
    -- retraction in (a) -- do not quote those two distances as measured.
    -- Turbo-only, matching the domain every measurement above was taken in;
    -- normal mode keeps the stale handle byte-for-byte. Extending it there is a
    -- separate decision with no evidence behind it yet.
    -- NOT A RESIDUAL ANY MORE (issue #45, gated 'roamreach'): the loiter cell
    -- was registered as a within-arm delta (12/409 vs 3/409). Re-estimated
    -- 2026-08-21 as ARMED A-B it survives -- 12/409 vs 2/322 = +2.3pp, z=2.26,
    -- with its own baseline leg near zero (+0.5pp) -- and it is the NARROW form
    -- of the in-domain zero-damage cost in (a) above (+7.1pp, p=0.0091, full
    -- corpus, clean supply). So the laning cost and this loiter are one thing,
    -- and 'roamreach' is the lever that decides whether this reset is net
    -- positive at all: if the cost survives the VICTIM_HP sweep and 'roamreach'
    -- cannot remove it, roamstale is a behaviour change with a measured cost and
    -- no measured benefit and goes back behind its gate (test_set.md AG.4 --
    -- the sweep comes first, a re-gate on an unswept threshold would repeat the
    -- mistake being corrected here). Its ECONOMIC account is
    -- separately FALSIFIED: #45 predicted the loiter would eat last hits, and
    -- the isolated read is last_hits A-B -0.05 (the -2.16 it pointed at is
    -- equally present in both arms, so it is not this).
    if J.IsModeTurbo() then
        hTargetCreep = nil
    end
    if bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then
        return BOT_MODE_DESIRE_NONE
    end

    Utils.SetFrameProcessTime(bot)
    EnemyRoles.UpdateEnemyHeroPositions()

    IsAvoidingAbilityZone = false

    bot.laneToPush   = J.GetMostPushLaneDesire()
    bot.laneToDefend = J.GetMostDefendLaneDesire()

    if DotaTime() - lastIdleStateCheck >= 1 or isInIdleState then
        isInIdleState = J.CheckBotIdleState()
        lastIdleStateCheck = DotaTime()
    end

    if not beInitDone then
        beInitDone = true
        bePvNMode = J.Role.IsPvNMode()
        IsHeroCore = J.IsCore(bot)
        IsSupport  = not IsHeroCore
    end

    ItemOpsDesire()

    local target
    target, ShouldHelpWhenCoreIsTargeted = X.ConsiderHelpWhenCoreIsTargeted()
    if ShouldHelpWhenCoreIsTargeted then
        SetStickyTarget(target)
        targetUnit = target
        return RemapValClamped(J.GetHP(bot), 0, 0.5, BOT_MODE_DESIRE_NONE, 0.98)
    end

    nearbyAllies = J.GetAlliesNearLoc(bot:GetLocation(), 2200)
    nearbyEnemies = J.GetEnemiesNearLoc(bot:GetLocation(), 2000)

    target, ShouldHelpAlly = ConsiderHelpAlly()
    if ShouldHelpAlly then
        SetStickyTarget(target)
        targetUnit = target
        return RemapValClamped(J.GetHP(bot), 0, 0.6, BOT_MODE_DESIRE_NONE, 0.98)
    end

    -- [GH #7] Punish a tower dive: if an enemy is over-extended under one of our
    -- buildings AND it is safe to commit (lethal or numbers), collapse on it so
    -- nearby controllers + a core TP guarantee the kill. J.ShouldPunishDive is
    -- PROMOTED (was soak-candidate 'punish') under the Class-B micro-behavior
    -- policy: turbo default-on, no candidate gate; normal mode unchanged. Its
    -- own-half domain extension is separately gated on 'ownhalf'.
    local punishTarget = J.ShouldPunishDive(bot)
    if punishTarget ~= nil then
        SetStickyTarget(punishTarget)
        targetUnit = punishTarget
        bDefensiveCollapse = true
        return RemapValClamped(J.GetHP(bot), 0, 0.5, BOT_MODE_DESIRE_NONE, 0.98)
    end

    -- [GH #20] Punish an over-chase: if an enemy has over-chased a low-HP ally
    -- deep into our side, out-running its own support, AND collapsing is safe
    -- (lethal or numbers), turn and counter-kill instead of fleeing. Same
    -- collapse pathway as the tower-dive punish, different trigger source. Gated
    -- inside J.ShouldPunishOverchase (turbo + 'overchase' soak candidate), so
    -- this is inert in shipped/normal play until an A/B win promotes it.
    local overchaseTarget = J.ShouldPunishOverchase(bot)
    if overchaseTarget ~= nil then
        SetStickyTarget(overchaseTarget)
        targetUnit = overchaseTarget
        bDefensiveCollapse = true
        return RemapValClamped(J.GetHP(bot), 0, 0.5, BOT_MODE_DESIRE_NONE, 0.98)
    end

    -- [L1-TRADE, rehomed after the Group A REJECT 20260723] Lane-kill window:
    -- the backed core converts an open lethal kill via THIS battle-tested
    -- collapse pathway instead of the (condemned) laning-Think replacement.
    -- All gating/self-risk/depth-leash lives in J.ShouldInitiateLaneKill
    -- (turbo + 'l1trade'); inert by default.
    -- [wave13 fingerprint 20260723] Both rehomed branches self-release when
    -- the collapsing bot is the one dying (J.ShouldReleaseLaneCommit) -- the
    -- old 0.95 bid outbid the PROMOTED lanesurv retreat (0.75) and pinned
    -- bots into losing trades. And the commit-lock stamps ONCE per
    -- engagement: a per-frame-renewed lock is an infinite lock (kite could
    -- never fire).
    local laneKillTarget = J.ShouldInitiateLaneKill(bot)
    if laneKillTarget ~= nil and not J.ShouldReleaseLaneCommit(bot) then
        if bot.laneCommitUntil == nil or DotaTime() > bot.laneCommitUntil then
            -- Commit-lock: we initiated -> finish the trade, no kite-abort
            -- for 4s (anti-oscillation, watched 182007).
            bot.laneCommitUntil = DotaTime() + 4.0
        end
        SetStickyTarget(laneKillTarget)
        targetUnit = laneKillTarget
        -- [GH #31] exempt from the lane-push cap; see _divecap_CapForLanePush.
        bLaneKillCommit = true
        return RemapValClamped(J.GetHP(bot), 0, 0.5, BOT_MODE_DESIRE_NONE, 0.92)
    end

    -- [L5-COMBO, rehomed after the Group A REJECT 20260723] Support kill-call
    -- on the too-deep enemy 4: same pathway, stricter self-risk gates inside
    -- J.ShouldSupportComboKill (turbo + 'l5combo'); inert by default.
    local comboTarget = J.ShouldSupportComboKill(bot)
    if comboTarget ~= nil and not J.ShouldReleaseLaneCommit(bot) then
        if bot.laneCommitUntil == nil or DotaTime() > bot.laneCommitUntil then
            bot.laneCommitUntil = DotaTime() + 4.0
        end
        SetStickyTarget(comboTarget)
        targetUnit = comboTarget
        -- [GH #31] exempt from the lane-push cap; see _divecap_CapForLanePush.
        bLaneKillCommit = true
        return RemapValClamped(J.GetHP(bot), 0, 0.5, BOT_MODE_DESIRE_NONE, 0.92)
    end

	hTargetCreep = X.GetLastHitCreep()
	if J.IsValid(hTargetCreep) and J.CanBeAttacked(hTargetCreep) then
		return 1.5
	end

    if not bot:IsAlive() or bot:GetCurrentActionType() == BOT_ACTION_TYPE_DELAY then
        return BOT_MODE_DESIRE_NONE
    end

    local nDesire = AttackSpecialUnit.GetDesire(bot)
    if nDesire > 0 then
        ShouldAttackSpecialUnit = true
        return RemapValClamped(J.GetHP(bot), 0.1, 0.8, BOT_MODE_DESIRE_NONE, nDesire)
    end

    if J.IsInLaningPhase() and bot:HasModifier('modifier_warlock_upheaval') then
        IsAvoidingAbilityZone = true
        return BOT_ACTION_DESIRE_VERYHIGH + 0.1
    end

    if HasModifierThatNeedToAvoidEffects() then
        IsAvoidingAbilityZone = true
        return RemapValClamped(J.GetHP(bot), 0.3, 1, BOT_ACTION_DESIRE_VERYHIGH, BOT_ACTION_DESIRE_NONE)
    end

    if not J.IsFarming(bot) and not J.IsPushing(bot) and not J.IsDefending(bot)
    and not J.IsDoingRoshan(bot) and not J.IsDoingTormentor(bot)
    and bot:GetActiveMode() ~= BOT_MODE_RUNE
    and bot:GetActiveMode() ~= BOT_MODE_SECRET_SHOP
    and bot:GetActiveMode() ~= BOT_MODE_OUTPOST
    and bot:GetActiveMode() ~= BOT_MODE_WARD
    and bot:GetActiveMode() ~= BOT_MODE_ATTACK
    and bot:GetActiveMode() ~= BOT_MODE_DEFEND_ALLY
    and bot:GetActiveMode() ~= BOT_MODE_ROAM then
        return BOT_ACTION_DESIRE_NONE
    elseif #nearbyAllies >= #nearbyEnemies then
        if IsHeroCore then
            local botTarget, targetDesire = X.CarryFindTarget()
            if botTarget ~= nil then
                targetUnit = botTarget
                bot:SetTarget(botTarget)
                return RemapValClamped(J.GetHP(bot), 0, 0.4, BOT_MODE_DESIRE_NONE, targetDesire)
            end
        end
        if IsSupport then
            local botTarget, targetDesire = X.SupportFindTarget()
            if botTarget ~= nil then
                targetUnit = botTarget
                bot:SetTarget(botTarget)
                return RemapValClamped(J.GetHP(bot), 0, 0.4, BOT_MODE_DESIRE_NONE, targetDesire)
            end
        end

        if bot:IsAlive() and bot:DistanceFromFountain() > 4600 then
            if towerTime ~= 0 and X.IsValid(towerCreep) and DotaTime() < towerTime + towerCreepTime then
                return RemapValClamped(J.GetHP(bot), 0, 0.4, BOT_MODE_DESIRE_NONE, 0.9)
            else
                towerTime, towerCreepMode = 0, false
            end

            towerCreepTime, towerCreep = X.ShouldAttackTowerCreep(bot)
            if towerCreepTime ~= 0 and towerCreep ~= nil then
                if towerTime == 0 then
                    towerTime = DotaTime()
                    towerCreepMode = true
                end
                bot:SetTarget(towerCreep)
                return RemapValClamped(J.GetHP(bot), 0, 0.4, BOT_MODE_DESIRE_NONE, 0.9)
            end
        end
    end

    return 0.0
end

function X.GetLastHitCreep()
	if J.IsRetreating(bot)
	or (not J.IsCore(bot) and J.IsThereCoreNearby(800))
	or J.IsInTeamFight(bot, 1200)
	then
		return nil
	end

	local nEnemyTowers = bot:GetNearbyTowers(1000, true)
	local nEnemyCreeps = bot:GetNearbyCreeps(1200, true)
	for _, creep in pairs(nEnemyCreeps) do
		if J.IsValid(creep)
		and J.CanBeAttacked(creep)
		and J.IsInRange(bot, creep, bot:GetAttackRange() + 300)
		and not J.IsRoshan(creep)
		and not J.IsTormentor(creep)
		then
			local nDelay = J.GetAttackProDelayTime(bot, creep)
			if J.WillKillTarget(creep, bot:GetAttackDamage()-1, DAMAGE_TYPE_PHYSICAL, nDelay)
			and (#nEnemyTowers == 0 or (J.IsValidBuilding(nEnemyTowers[1]) and not J.IsInRange(creep, nEnemyTowers[1], 750)))
			then
				local nInRangeAlly = J.GetAlliesNearLoc(creep:GetLocation(), 1000)
				local nInRangeEnemy = J.GetEnemiesNearLoc(creep:GetLocation(), 1000)
				if #nInRangeAlly >= #nInRangeEnemy then
					return creep
				end
			end
		end
	end

	return nil
end

-- ==============================
-- Avoid zones
-- ==============================
function HasModifierThatNeedToAvoidEffects()
    return bot:HasModifier('modifier_jakiro_macropyre_burn')
        or bot:HasModifier('modifier_dark_seer_wall_slow')
        or ((bot:HasModifier('modifier_sandking_sand_storm_slow') or bot:HasModifier('modifier_sand_king_epicenter_slow'))
            and (not bot:HasModifier("modifier_black_king_bar_immune")
                or not bot:HasModifier("modifier_magic_immune")
                or not bot:HasModifier("modifier_omniknight_repel")))
end

-- ==============================
-- Desire Helpers
-- ==============================
function ConsiderHelpAlly()
    if J.GetHP(bot) < 0.3 then return nil, false end

    local nRadius = 3500
    local nModeDesire = bot:GetActiveModeDesire()
    local nClosestAlly = J.GetClosestAlly(bot, nRadius)

    if  nClosestAlly ~= nil
    and J.GetHP(bot) >= J.GetHP(nClosestAlly)
    and (not J.IsCore(bot) or (J.IsCore(bot) and (not J.IsInLaningPhase() or J.IsInRange(bot, nClosestAlly, 1600))))
    and not J.IsGoingOnSomeone(bot)
    and not (J.IsRetreating(bot) and nModeDesire > 0.8) then
        local nInRangeAlly = J.GetAlliesNearLoc(nClosestAlly:GetLocation(), 1200)
        local nInRangeEnemy = J.GetEnemiesNearLoc(nClosestAlly:GetLocation(), 1600)

        for _, enemyHero in pairs(nInRangeEnemy) do
            if J.IsValidHero(enemyHero)
            and GetUnitToUnitDistance(enemyHero, nClosestAlly) <= 1600
            and (#nInRangeAlly + 1 >= #nInRangeEnemy) then
                if (enemyHero:GetAttackTarget() == nClosestAlly or J.IsChasingTarget(enemyHero, nClosestAlly))
                or nClosestAlly:WasRecentlyDamagedByHero(enemyHero, 2.5) then
                    return enemyHero, true
                end
            end
        end
    end

    return nil, false
end

-- ==============================
-- Lifecycle
-- ==============================
function OnStart() end

function OnEnd()
    towerTime = 0
    towerCreepMode = false
    PickedItem = nil
end

-- ==============================
-- Think
-- ==============================

--- [roamreach, GH #45] The longest range at which this bot can do ANYTHING to a
--- target right now: its attack range, or the cast range of a levelled and
--- currently castable ability if that reaches further.
local function _roamreach_ThreatReach(hBot)
    local nReach = hBot:GetAttackRange() or 0
    for slot = 0, 5 do
        local hAbility = hBot:GetAbilityInSlot(slot)
        if hAbility ~= nil and hAbility:GetLevel() > 0 and hAbility:IsFullyCastable() then
            local nCast = hAbility:GetCastRange()
            if type(nCast) == 'number' and nCast > nReach then nReach = nCast end
        end
    end
    return nReach
end

--- [roamreach, GH #45] Hand an out-of-reach HERO target a BOUNDED approach
--- instead of an open-ended attack-follow. Returns true when it took the order.
---
--- `Action_AttackUnit(hTarget, false)` is a CONTINUOUS order (docs/
--- BOT_API_REFERENCE.md): the engine pursues the target until it dies or a new
--- order arrives. It therefore outlives the desire that justified it -- and it
--- outlives it in the one place nothing can clean up, because the release this
--- mode does own (the >1800 leash above) lives in THIS Think, which the engine
--- stops calling the moment another mode wins the auction. So a collapse branch
--- that is true for one frame can buy a cross-map chase.
---
--- REAL FRAME (20260819_181742_slot1, arm A of the roamstale bisect): at
--- t=312.5 the punish-dive branch ('ownhalf') returns a 41%-HP Dragon Knight
--- 805u away and team_roam wins the auction at 0.72, so Shadow Shaman -- attack
--- range 400, Hex 550, Shackles 400, Ether Shock 500, i.e. NOTHING that reaches
--- 805u -- is handed a continuous attack order. Six seconds later (t=318.5) not
--- one branch in this helper is true any more and its bid is 0, yet the bot is
--- still 760u behind the same target: it chased for 12s across ~3900u, stayed in
--- the 644-870u band the whole way, cast nothing, dealt zero damage, and the
--- target regenerated 23% -> 42% HP while its own lane creeps went unfarmed.
---
--- Armed, an unreachable hero target gets `Action_MoveToLocation(its position)`:
--- a FINITE order. While this mode keeps winning it is re-issued every frame, so
--- the approach is unchanged; when the mode loses the auction the leftover order
--- expires ~one target-distance later instead of dragging the bot across the
--- map. In-reach targets keep the shipped continuous attack byte-for-byte -- the
--- commit only becomes a promise once we can actually keep it. Standard play:
--- don't chase what you can't catch without a way to close (a lock, a slow, or
--- an ally in front); the lane you left costs more than the kill you won't get.
--- Gated turbo + 'roamreach'; inert by default.
local function _roamreach_BoundedChase(hTarget)
    if not (J.IsModeTurbo() and J.IsSoakCandidate('roamreach')) then return false end
    if hTarget == nil or not hTarget:IsHero() then return false end
    if GetUnitToUnitDistance(bot, hTarget) <= _roamreach_ThreatReach(bot) then return false end
    bot:Action_MoveToLocation(hTarget:GetLocation())
    return true
end

function Think()
    if J.CanNotUseAction(bot) then return end
	-- diabled think less to avoid failing to last hit
    -- if J.Utils.IsBotThinkingMeaningfulAction(bot, Customize.ThinkLess, "team_roam") then return end

    ItemOpsThink()

	if J.IsValid(hTargetCreep) then
		bot:Action_AttackUnit(hTargetCreep, true)
		return
	end

	-- Leash & validity guard to prevent pacing back and forth
	if targetUnit ~= nil then
		if (not J.Utils.IsValidUnit(targetUnit))
		or (not X.CanBeAttacked(targetUnit))
		or (GetUnitToUnitDistance(bot, targetUnit) > 1800)  -- too far = drop it
		or (bot:GetActiveMode() == BOT_MODE_LANING and GetUnitToUnitDistance(bot, targetUnit) > bot:GetAttackRange() + 250)
		then
			targetUnit = nil
		end
	end

    if IsAvoidingAbilityZone then
        bot:Action_MoveToLocation(Utils.GetOffsetLocationTowardsTargetLocation(bot:GetLocation(), J.GetTeamFountain(), 600) + RandomVector(200))
        return
    end

    if ShouldAttackSpecialUnit then
        AttackSpecialUnit.Think()
    end

    if towerCreepMode then
        bot:Action_AttackUnit(towerCreep, false)
        return
    end

    --- [roamidle, GH #370] Let the stuck-recovery order survive the frame that
    --- issued it.
    ---
    --- Shipped, this block has NO control-flow consequence: it re-assigns
    --- `isInIdleState` and falls through. But `J.CheckBotIdleState()` is not a
    --- query -- in its recovery arm it ORDERS, `Action_ClearActions(true)` then
    --- `ActionQueue_AttackMove(laneFront)` (jmz_func.lua:11994/11998). Eleven
    --- lines below, whenever `targetUnit` is valid, this Think issues
    --- `bot:Action_AttackUnit(targetUnit, false)` -- and an `Action_*` order
    --- "CLEARS the entire action queue and sets this as the new (and only)
    --- action" (docs/BOT_API_REFERENCE.md:1715). So the relocation is destroyed
    --- on the same frame it was issued, and it is destroyed exactly when the bot
    --- has a roam target -- i.e. the anti-stuck recovery is a no-op precisely in
    --- the situation this mode creates.
    ---
    --- It repeats every frame, not every 3s: the `return true` in that helper
    --- sits ABOVE the two lines that refresh the sampling anchor
    --- (`botState.botLocation` / `lastCheckTime`, jmz_func.lua:12010-12011), so
    --- once idle is latched the >= 3s gate never closes again. Both call sites
    --- then take their per-frame path (`... or isInIdleState` at :259, and this
    --- block), which makes the wiped `Action_ClearActions(true)` a per-frame
    --- event over every other system's queued actions too.
    ---
    --- Armed, a call that actually relocated ends this frame's Think, so the
    --- queued attack-move stands. Standard play: a recovery action has to
    --- outrank routine ordering or it is not a recovery. Narrow by construction
    --- -- the `else` arm of that helper orders nothing and reaches the same
    --- `return true`, so `bRelocated` (not `isInIdleState`) is what gates the
    --- return, and a bot that is idle "for unknown reasons" still falls through
    --- to the shipped branches byte for byte.
    --- Gated turbo + 'roamidle'; inert by default.
    if isInIdleState then
        local bRelocated
        isInIdleState, bRelocated = J.CheckBotIdleState()
        if bRelocated and J.IsModeTurbo() and J.IsSoakCandidate('roamidle') then
            return
        end
    end

    if ShouldHelpAlly and J.Utils.IsValidUnit(targetUnit) then
        if not _roamreach_BoundedChase(targetUnit) then
            bot:Action_AttackUnit(targetUnit, false)
        end
        return
    end

    if (IsHeroCore or IsSupport) and J.Utils.IsValidUnit(targetUnit) then
        if not _roamreach_BoundedChase(targetUnit) then
            bot:Action_AttackUnit(targetUnit, false)
        end
        return
    end
end

-- [lvlany 20260910] "IS ANY NEARBY ENEMY AT LEAST LEVEL N" ANSWERED BY ONE
-- ARBITRARY MEMBER OF THE LIST.
--
-- Shipped, X.SupportFindTarget's laning last-hit guard reads
--     (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 10)
-- from J.GetNearbyHeroes(bot, 750, true, BOT_MODE_NONE).  The question the
-- conjunction is asking is existential -- "is there a dangerous (level >= 10)
-- enemy standing on me?" -- and the empty-list leg written right beside it
-- (`[1] == nil`) is what says so: the author already spent a term separating
-- "nobody here" from "somebody here who is weak".
--
-- ⭐ WHY THIS IS A STRICTLY HARDER CASE THAN 'anyhero' (2026-09-10T19:37Z), NOT
-- A COPY OF IT, AND THE DIFFERENCE IS THE WHOLE POINT.  There the repair leaned
-- on a measured fact about ORDER -- J.GetEnemiesNearLoc table.inserts in
-- GetUnitList order and never sorts, so `[1]` is an arbitrary member rather than
-- the nearest.  Here the list IS ordered and correctly so: the engine promises
-- it (docs/BOT_API_REFERENCE.md:1229, "All return tables sorted by distance
-- (closest first)") and J.GetNearbyHeroes only filters, never reorders
-- (jmz_func.lua:2856).  `[1]` really is the nearest visible enemy hero -- and
-- the guard is still wrong, because the quantified predicate is LEVEL and the
-- nearest enemy is not the highest-level one.  So 'anyhero' would be repaired by
-- an engine that started sorting; this one would not be touched by it.  Section
-- 1b pins the order rather than assuming it, precisely so that the argument here
-- does not quietly become the argument there.
--
-- WHAT IT COSTS.  The guard is the safety half of a branch that returns
-- BOT_MODE_DESIRE_ABSOLUTE * 0.97 to walk up and last-hit/deny creeps in lane.
-- When `[1]` happens to be the level-5 support and the level-12 offlaner is the
-- other name in the same 750 radius, the guard reads "clear" and a bot capped
-- at level 8 (bot:GetLevel() <= 8, the term above it) commits to the creep
-- wave with a hero four levels up inside kill range.
--
-- DOMAIN, measured on the frame corpus by
-- tests/test_lvlany_first_member_level_quantifier.lua, not asserted here.
-- ⛔ Its limits are stated in that file BEFORE any count is read: the mock's
-- enemy list contains the querying hero itself, so every count is taken with
-- self removed and measures the GEOMETRY of a set of heroes carrying real dump
-- levels -- not enemy semantics, and no in-game fire rate is claimed from it.
--
-- ⭐ THE WHOLE CHANGE IS INSIDE THE GATE, and the unarmed leg is the shipped
-- expression term for term -- including its position in the conjunction, so the
-- short-circuit order is unchanged.  That is why the repair is a helper called
-- from the same slot rather than a hoisted local: a hoisted read would evaluate
-- GetLevel() on calls where the shipped code never reaches the term.  Section 3b
-- of the test measures that equality on every driven row instead of reading it
-- off the diff.
--
-- ⛔ FROZEN-HOLD per OWNER_PRIORITIES P4.2 (new ids do not enter the armed set
-- while it is above 20).  Registered in state.json:lvlany_20260910; the armed
-- string, queue.json and test_set.md are untouched.
--
-- ⛔ SCOPE IS ONE CALL SITE ON PURPOSE.  The identical expression sat at three
-- more places in this file.  They are NOT changed by THIS lever -- one lever at
-- a time is what the lanefix bundle cost us -- and they are pinned as an
-- assertion (section 7 of this lever's test) so the baton is a counted line, not
-- a memory.  2026-09-11: the first of the three was taken off that baton by
-- 'lvlcarry' (X.CarryFindTarget's deny guard, level 12, its own id and its own
-- helper -- see the block above X.NoNearbyEnemyAtLevelCarry).  TWO remain: the
-- second level-12 site in X.CarryFindTarget, and the level-10 one inside
-- X.CanAttackTogether.
function X.NoNearbyEnemyAtLevel(tHeroes, nLevel)
	if tHeroes == nil or tHeroes[1] == nil then return true end
	if J.IsModeTurbo() and J.IsSoakCandidate('lvlany') then
		for i = 1, #tHeroes do
			if tHeroes[i]:GetLevel() >= nLevel then return false end
		end
		return true
	end
	return tHeroes[1]:GetLevel() < nLevel
end

-- [lvlcarry 20260911] THE SAME EXISTENTIAL-QUESTION-ANSWERED-BY-THE-NEAREST
-- DEFECT, TAKEN OFF THE BATON 'lvlany' LEFT (one of the three siblings named in
-- the block above).  This one is X.CarryFindTarget's last-hit/deny guard:
--     local nNearbyEnemyHeroes = bot:GetNearbyHeroes(650, true, BOT_MODE_NONE)
--     if IsModeSuitHit
--        and (botHP > 0.38 or not bot:WasRecentlyDamagedByAnyHero(3.0))
--        and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 12)
-- The empty-list leg beside it is again what proves the question is existential:
-- the author already spent a term separating "nobody here" from "somebody here
-- who is weak".  What the expression answers is "is the NEAREST one weak".
--
-- ⭐ THREE DIFFERENCES FROM 'lvlany', AND THEY ARE WHY THIS IS A SECOND LEVER
-- RATHER THAN THE SAME ONE WIDENED.  (1) Different function, different branch:
-- the support's laning guard there, the carry's deny/tower-last-hit branch here.
-- (2) Different constants: r = 650 and level 12, not 750 and 10 -- and the
-- corpus reads differently at them (the miss population is 2 here against 7
-- there; see the sweep in the test).  (3) ⛔ Different PRODUCER: this call site
-- reads bot:GetNearbyHeroes DIRECTLY, not J.GetNearbyHeroes, so the list is not
-- put through J.IsValidHero / the meepo-clone filter.  That is a separate
-- pre-existing question and it is NOT touched here; section 4d of the test
-- measures that on this corpus the two lists never differ, so nothing below
-- rests on the difference either way.
--
-- ⛔ WHY A SECOND HELPER RATHER THAN A SECOND CALLER OF THE ONE ABOVE.  Sharing
-- it would put both call sites behind the single id 'lvlany', which is exactly
-- the bundling the lanefix rejections (gpm -74.5, then -88.7, 0/4 comps) cost
-- us; and giving the shared helper two ids would be the pullcad trap, where a
-- gate written as a conjunction of ids freezes FALSE the day either is promoted.
-- One lever, one id, one call site.  The duplication is nine lines and is the
-- cheap side of that trade.
--
-- WHAT IT COSTS.  The branch this guard protects walks the bot up to last-hit
-- and deny at BOT_MODE_DESIRE_ABSOLUTE * 0.97, and the term above it caps the
-- bot at level 8.  When the nearest enemy is the level-8 offlaner standing 191
-- units away and a level-12 Lina is the other name inside the same 650, the
-- guard reads "clear" -- that frame is real and is the anchor of the test
-- (tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua, slardar at level 7).
--
-- DOMAIN AND LIMITS are measured in
-- tests/test_lvlcarry_carry_deny_level_quantifier.lua and stated there BEFORE
-- any count is read -- in particular, the branch's other terms (IsModeSuitHit,
-- WasRecentlyDamagedByAnyHero, the two fountain distances) are not driven by
-- this corpus, so no in-game fire rate is claimed anywhere.
--
-- ⭐ THE WHOLE CHANGE IS INSIDE THE GATE and the unarmed leg is the shipped
-- expression term for term, in the same slot of the same conjunction, so the
-- short-circuit order is unchanged.  Section 3b measures that equality on all
-- 1306 live rows rather than reading it off the diff.
--
-- ⛔ FROZEN-HOLD per OWNER_PRIORITIES P4.2 (new ids do not enter the armed set
-- while it is above 20).  Registered in state.json:lvlcarry_20260911; the armed
-- string, queue.json and test_set.md are untouched.
function X.NoNearbyEnemyAtLevelCarry(tHeroes, nLevel)
	if tHeroes == nil or tHeroes[1] == nil then return true end
	if J.IsModeTurbo() and J.IsSoakCandidate('lvlcarry') then
		for i = 1, #tHeroes do
			if tHeroes[i]:GetLevel() >= nLevel then return false end
		end
		return true
	end
	return tHeroes[1]:GetLevel() < nLevel
end

-- [lvlgroup 20260911] THE SECOND SIBLING OFF 'lvlany'S BATON: X.CarryFindTarget's
-- GROUP-PUSH BRANCH ASKS THE SAME EXISTENTIAL LEVEL QUESTION OF THE NEAREST HERO.
--     if IsModeSuitHit and bot:GetLevel() <= 8
--        and X.CanAttackTogether(bot)
--        and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 12)
-- Same list (the raw bot:GetNearbyHeroes(650,...) local declared above the deny
-- branch), same threshold, same empty-list leg proving the question is
-- existential.  The branch it guards ganks a creep our own tower is about to
-- kill, at BOT_MODE_DESIRE_ABSOLUTE, with the bot capped at level 8.
--
-- ⛔⛔ READ THIS BEFORE ANY NUMBER: THIS LEVER IS WEAKER THAN 'lvlcarry', AND THE
-- WEAKNESS IS MEASURED, NOT SUSPECTED.  Its own predicate change is driven on 2
-- real rows (the same r650/th12 miss population 'lvlcarry' reports).  But the
-- BRANCH those rows sit in never opens on this corpus: both miss rows carry ZERO
-- allies within 1200, so `X.CanAttackTogether(bot)` -- a conjunct standing beside
-- this guard -- is false on both, and arming changes the branch's outcome on
-- 0 rows.  That zero is NOT structural: 13 rows do carry >=2 allies within 1200
-- AND >=2 enemies within 650 (the shape a miss needs), and none of the 13 is a
-- miss.  tests/test_lvlgroup_group_push_level_quantifier.lua section 5 asserts
-- the 0 as an EQUALITY over that 13-row candidate population, so the day a
-- fixture lands in the shape, this file goes red and the lever can finally be
-- driven end to end.
--
-- ⭐ WHAT CARRIES THE LEVER WHILE THAT ZERO STANDS IS THE DIRECTION, AND IT IS
-- MEASURED OVER ALL 1306 LIVE ROWS (section 3e), NOT ARGUED FROM THE DIFF.
-- Armed answers `not any(level >= nLevel)`; shipped answers `[1] < nLevel`; the
-- first IMPLIES the second whenever `[1]` exists.  So armed is a pure NARROWING:
-- it can only ever WITHDRAW the "clear" answer this branch needs, never grant one
-- baseline withheld.  The branch can therefore open strictly less often armed
-- than unarmed and never more -- the same safety shape 'glyphany' and 'wkqdmg'
-- ship on.  ⛔ That is a bound on the DIRECTION of the change, not a fire rate,
-- and no fire rate is claimed anywhere in this lever's file.
--
-- ⛔ SAME BAR AS 'lvlcarry', STATED ONCE SO THE FAMILY STOPS DRIFTING.  The bar
-- this lever is taken on is "the lever's own predicate change is driven on real
-- rows", with branch reachability registered separately as the weaker bound
-- above.  'lvlcarry' section 7b had judged the REMAINING sibling (the level-10
-- site inside X.CanAttackTogether) unbuyable on the stricter "full predicate
-- flips" bar.  Under the bar used here that sibling is buyable too (4 miss rows
-- at its own r=600/level 10) -- see the amended comment on 7b, changed in the
-- same commit rather than left claiming a criterion nobody is applying.  It is
-- NOT taken here: one lever at a time is what the lanefix bundle cost us.
--
-- ⛔ WHY A THIRD HELPER AND NOT A SECOND CALLER OF X.NoNearbyEnemyAtLevelCarry.
-- Sharing would put both call sites behind the single id 'lvlcarry' -- the
-- lanefix bundling (gpm -74.5, then -88.7, 0/4 comps) rebuilt by hand -- and a
-- shared helper reading two ids is the pullcad trap, frozen FALSE the day either
-- is promoted.  'lvlcarry' section 5b pins its caller count at exactly 1 for
-- this reason, so sharing would also turn that file red.  One lever, one id, one
-- call site; nine duplicated lines is the cheap side of the trade.
--
-- ⛔ FROZEN-HOLD per OWNER_PRIORITIES P4.2 (new ids do not enter the armed set
-- while it is above 20).  Registered in state.json:lvlgroup_20260911; the armed
-- string, queue.json and test_set.md are untouched.
function X.NoNearbyEnemyAtLevelGroup(tHeroes, nLevel)
	if tHeroes == nil or tHeroes[1] == nil then return true end
	if J.IsModeTurbo() and J.IsSoakCandidate('lvlgroup') then
		for i = 1, #tHeroes do
			if tHeroes[i]:GetLevel() >= nLevel then return false end
		end
		return true
	end
	return tHeroes[1]:GetLevel() < nLevel
end

-- [lvltogether 20260911] THE LAST SIBLING OFF 'lvlany'S BATON, AND THE ONE THAT
-- IS SHAPED DIFFERENTLY FROM THE OTHER THREE: X.CanAttackTogether's own level
-- guard.
--     local nNearbyEnemyHeroes = bot:GetNearbyHeroes(600,true,BOT_MODE_NONE)
--     return ... and #allies >= 2
--            and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 10)
-- Same defect as its three siblings -- an EXISTENTIAL question ("is anybody
-- dangerous standing here") answered by `[1]` -- and the empty-list leg beside
-- it is again the author's own proof that the question is existential.
--
-- ⭐⭐ TWO THINGS ARE NEW HERE, AND THEY ARE WHY THIS IS ITS OWN LEVER RATHER
-- THAN THE THIRD COPY OF ONE.
--   (1) ⛔ THE SUBJECT IS NOT THE ASKING BOT. X.CanAttackTogether takes a HERO
--       PARAMETER, and three of its four call sites pass an ALLY, not the
--       querying bot (X.GetCanTogetherCount walks the ally list; two branches in
--       X.SupportFindTarget/X.CarryFindTarget call it on a specific ally). So
--       this guard is also answering "does MY ALLY have a dangerous enemy next
--       to them", and that answer is what gets COUNTED into "how many of us can
--       go in". None of the other three siblings is ever evaluated about anyone
--       but the bot doing the asking. Section 1 of
--       tests/test_lvltogether_can_attack_together_level_quantifier.lua measures
--       that population separately (868 ally evaluations, 1 of them a miss).
--   (2) ⛔ ONE PREDICATE, ONE SOURCE SITE, BUT FOUR BRANCHES. The three siblings
--       each gate one call site; this one gates a predicate that four branches
--       read. That is NOT the lanefix bundling -- bundling is several DIFFERENT
--       levers armed by one id, and this is one lever whose defect happens to
--       live in a shared helper, where "fix it at the call site" would mean
--       writing the same repair four times. But it does mean this id moves more
--       behaviour than any of its siblings, which is a reason to keep it alone
--       and gated, not a reason to widen it. Section 5c pins the caller count.
--
-- ⛔ THE ZERO, SHARPER THAN 'lvlgroup'S AND ASSERTED THE SAME WAY. Arming changes
-- this helper's answer on 4 real rows (its own cell, r = 600 / level 10 -- the
-- population 'lvlcarry' section 7b registered) but changes X.CanAttackTogether's
-- RETURN on 0, because all 4 carry fewer than 2 allies within 1200. What is new
-- is that the test can say exactly what is missing: all 4 satisfy EVERY OTHER
-- conjunct (alive, not illusion, GetProperTarget == nil) -- an equality, not a
-- floor -- so `#allies >= 2` is the single term between them and a flip. The
-- candidate shape (>= 2 allies within 1200 AND >= 2 enemies within 600) exists on
-- 11 live rows, so the zero is small-sample, not structural, and section 5 keeps
-- it as an EQUALITY: the day a fixture lands in the shape, this goes red and the
-- lever can be driven end to end. ⭐ That red is good news; take it as the drive.
--
-- ⭐ WHAT CARRIES THE LEVER WHILE THAT ZERO STANDS IS THE DIRECTION, MEASURED
-- OVER ALL 1306 LIVE ROWS (sections 3e and 5) RATHER THAN ARGUED FROM THE DIFF.
-- Armed answers `not any(level >= nLevel)`; shipped answers `[1] < nLevel`; the
-- first implies the second whenever `[1]` exists, so armed is a pure NARROWING.
-- Here that bound reaches further than it did for the siblings: because three
-- call sites COUNT the answer, "never grants a true baseline withheld" means the
-- co-attacker count can only ever go DOWN armed -- the bots can become more
-- cautious about grouping onto a target, never more reckless. Same safety shape
-- 'glyphany' and 'wkqdmg' ship on.
--
-- ⛔ THE BAR IS THE ONE 'lvlgroup' PUT IN FORCE and 'lvlcarry' section 7b was
-- amended to: "the lever's OWN predicate change is driven on real rows", with
-- reachability of what reads it registered separately as the weaker bound. This
-- sibling was already judged buyable under that bar, in writing, by both of those
-- files -- taking it now is executing that judgement, not re-opening it.
--
-- ⛔ WHY A FOURTH HELPER AND NOT A FOURTH CALLER OF ONE ABOVE. Sharing would arm
-- two or more sites together (the lanefix bundling, gpm -74.5 then -88.7, 0/4
-- comps, rebuilt by hand), and a shared helper reading two ids is the pullcad
-- trap -- frozen FALSE the day either is promoted. 'lvlcarry' section 5b and
-- 'lvlgroup' section 5c each pin their caller count at exactly 1, so sharing
-- would also turn those files red. One lever, one id, one definition site.
--
-- ⛔ FROZEN-HOLD per OWNER_PRIORITIES P4.2 (new ids do not enter the armed set
-- while it is above 20). Registered in state.json:lvltogether_20260911; the armed
-- string, queue.json and test_set.md are untouched.
function X.NoNearbyEnemyAtLevelTogether(tHeroes, nLevel)
	if tHeroes == nil or tHeroes[1] == nil then return true end
	if J.IsModeTurbo() and J.IsSoakCandidate('lvltogether') then
		for i = 1, #tHeroes do
			if tHeroes[i]:GetLevel() >= nLevel then return false end
		end
		return true
	end
	return tHeroes[1]:GetLevel() < nLevel
end

-- ==============================
-- Support / Carry target selection
-- (guarded by emergency retreat)
-- ==============================
function X.SupportFindTarget()
    if X.CanNotUseAttack(bot) or DotaTime() < 0 then return nil, 0 end

    local IsModeSuitHit = X.IsModeSuitToHitCreep(bot)
    local nAttackRange = math.min(bot:GetAttackRange() + 50, 1200)

    local nTarget = J.GetProperTarget(bot)
    local botMode = bot:GetActiveMode()
    local botLV   = bot:GetLevel()
    local botAD   = bot:GetAttackDamage()
    local botBAD  = X.GetAttackDamageToCreep(bot) - 1

    if X.CanBeAttacked(nTarget) and nTarget == targetUnit and GetUnitToUnitDistance(bot, nTarget) <= 1600 then
        if nTarget:GetTeam() == bot:GetTeam() then
            if nTarget:GetHealth() > X.GetLastHitHealth(bot, nTarget) then
                return nTarget, BOT_MODE_DESIRE_VERYHIGH * 1.08
            end
            return nTarget, BOT_MODE_DESIRE_VERYHIGH * 1.04
        end
        if nTarget:IsCourier()
        and GetUnitToUnitDistance(bot, nTarget) <= nAttackRange + 300
        and J.GetHP(bot) > 0.3 and not J.IsRetreating(bot) then
            return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 1.5
        end
        if nTarget:IsHero() and (bot:GetCurrentMovementSpeed() < 300 or botLV >= 25) then
            return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 1.2
        end
        if J.IsPushing(bot) and not nTarget:IsHero() then return nil, 0 end
        if not nTarget:IsHero() and GetUnitToUnitDistance(bot, nTarget) < nAttackRange + 50 then
            return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 0.98
        end
        if not nTarget:IsHero() and GetUnitToUnitDistance(bot, nTarget) > nAttackRange + 300 then
            return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 0.7
        end
        return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 0.96
    end

	-- Avoid derailing laning/pushing for courier hunts
	if not J.IsInLaningPhase() and not J.IsPushing(bot) then
		local enemyCourier = X.GetEnemyCourier(bot, nAttackRange + botLV * 2 + 20)  -- or +30 in carry version
		if enemyCourier ~= nil and not enemyCourier:IsAttackImmune() and not enemyCourier:IsInvulnerable()
		and J.GetHP(bot) > 0.3 and not J.IsRetreating(bot) then
			return enemyCourier, BOT_MODE_DESIRE_ABSOLUTE * 1.2
		end
	end

    if botMode == BOT_MODE_RETREAT and botLV > 9 and not X.CanBeInVisible(bot) and X.ShouldNotRetreat(bot) then
        nTarget = J.GetAttackableWeakestUnit(bot, nAttackRange + 50, true, true)
        if nTarget ~= nil then return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 1.09 end
    end

    local attackDamage = botBAD - 1
    if IsModeSuitHit and not X.HasHumanAlly(bot) and (J.GetHP(bot) > 0.5 or not bot:WasRecentlyDamagedByAnyHero(2.0)) then
        local nBonusRange = botLV > 20 and 200 or (botLV > 12 and 300 or 400)
        nTarget = X.GetNearbyLastHitCreep(false, true, attackDamage, nAttackRange + nBonusRange, bot)
        if nTarget ~= nil then return nTarget, BOT_MODE_DESIRE_ABSOLUTE end

        local nEnemyTowers = bot:GetNearbyTowers(nAttackRange + 150, true)
        if X.CanBeAttacked(nEnemyTowers[1]) and J.IsWithoutTarget(bot) and X.IsLastHitCreep(nEnemyTowers[1], botAD * 2) then
            return nEnemyTowers[1], BOT_MODE_DESIRE_ABSOLUTE
        end

        local nNeutrals = bot:GetNearbyNeutralCreeps(nAttackRange + 150)
        local nAllies = J.GetNearbyHeroes(bot, 1300, false, BOT_MODE_NONE)
        if J.IsWithoutTarget(bot) and botMode ~= BOT_MODE_FARM and #nNeutrals > 0 and #nAllies <= 1 then
            for i = 1, #nNeutrals do
                if X.CanBeAttacked(nNeutrals[i]) and not X.IsAllysTarget(nNeutrals[i])
                and not J.IsTormentor(nNeutrals[i]) and not J.IsRoshan(nNeutrals[i])
                and X.IsLastHitCreep(nNeutrals[i], attackDamage) then
                    return nNeutrals[i], BOT_MODE_DESIRE_ABSOLUTE
                end
            end
        end
    end

    local denyDamage = botAD + 3
    local nNearbyEnemyHeroes = J.GetNearbyHeroes(bot, 750, true, BOT_MODE_NONE)
    if IsModeSuitHit and bot:GetLevel() <= 8
    and bot:GetNetWorth() < 13998
    and (J.GetHP(bot) > 0.38 or not bot:WasRecentlyDamagedByAnyHero(3.0))
    -- [lvlany 20260910] see the block above X.NoNearbyEnemyAtLevel. Unarmed
    -- this is `nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel()
    -- < 10`, in this slot, with the same short-circuit order.
    and X.NoNearbyEnemyAtLevel(nNearbyEnemyHeroes, 10)
    and bot:DistanceFromFountain() > 3800
    and J.GetDistanceFromEnemyFountain(bot) > 5000 then

        local nWillAttackCreeps = X.GetExceptRangeLastHitCreep(true, attackDamage * 1.1, 0, nAttackRange + 60, bot)
        if nWillAttackCreeps == nil or denyDamage > 130 or not X.IsOthersTarget(nWillAttackCreeps) or not X.IsMostAttackDamage(bot) then
            nTarget = X.GetNearbyLastHitCreep(false, false, denyDamage, nAttackRange + 300, bot)
            if nTarget ~= nil then return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 0.97 end
        end

        local nAllyTowers = bot:GetNearbyTowers(nAttackRange + 300, false)
        if J.IsWithoutTarget(bot) and #nAllyTowers > 0 then
            if X.CanBeAttacked(nAllyTowers[1]) and J.GetHP(nAllyTowers[1]) < 0.08 and X.IsLastHitCreep(nAllyTowers[1], denyDamage * 3) then
                return nAllyTowers[1], BOT_MODE_DESIRE_ABSOLUTE
            end
        end
    end

    return nil, 0
end

function X.CarryFindTarget()
    if X.CanNotUseAttack(bot) or DotaTime() < 0 then return nil, 0 end

    local IsModeSuitHit = X.IsModeSuitToHitCreep(bot)
    local nAttackRange = math.min(bot:GetAttackRange() + 50, 1170)
    if botName == "npc_dota_hero_templar_assassin" then nAttackRange = nAttackRange + 100 end

	local nTarget = J.GetProperTarget(bot);	
	local botHP   = bot:GetHealth()/bot:GetMaxHealth();
	local botMode = bot:GetActiveMode();
	local botLV   = bot:GetLevel();
    local botAD   = bot:GetAttackDamage() - 0.8
    local botBAD  = X.GetAttackDamageToCreep(bot) - 1.2

    if X.CanBeAttacked(nTarget) and nTarget == targetUnit and GetUnitToUnitDistance(bot, nTarget) <= 1600 then
        if nTarget:GetTeam() == bot:GetTeam() then
            if nTarget:GetHealth() > X.GetLastHitHealth(bot, nTarget) then
                return nTarget, BOT_MODE_DESIRE_VERYHIGH * 1.08
            end
            return nTarget, BOT_MODE_DESIRE_VERYHIGH * 1.04
        end
        if nTarget:IsCourier()
        and GetUnitToUnitDistance(bot, nTarget) <= nAttackRange + 300
        and J.GetHP(bot) > 0.3 and not J.IsRetreating(bot) then
            return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 1.5
        end
        if nTarget:IsHero() and (bot:GetCurrentMovementSpeed() < 300 or botLV >= 25) then
            if botName == "npc_dota_hero_antimage" then
                local bAbility = bot:GetAbilityByName("antimage_blink")
                if bAbility ~= nil and bAbility:IsFullyCastable() then return nil, BOT_MODE_DESIRE_NONE end
            end
            return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 1.2
        end
        if J.IsPushing(bot) and not nTarget:IsHero() then return nil, 0 end
        if not nTarget:IsHero() and GetUnitToUnitDistance(bot, nTarget) < nAttackRange + 50 then
            return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 0.98
        end
        if not nTarget:IsHero() and GetUnitToUnitDistance(bot, nTarget) > nAttackRange + 300 then
            return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 0.7
        end
        return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 0.96
    end

    if bot:HasModifier('modifier_phantom_lancer_phantom_edge_boost') then
        return nil, 0
    end

	-- Avoid derailing laning/pushing for courier hunts
	if not J.IsInLaningPhase() and not J.IsPushing(bot) then
		local enemyCourier = X.GetEnemyCourier(bot, nAttackRange + botLV * 2 + 20)  -- or +30 in carry version
		if enemyCourier ~= nil and not enemyCourier:IsAttackImmune() and not enemyCourier:IsInvulnerable()
		and J.GetHP(bot) > 0.3 and not J.IsRetreating(bot) then
			return enemyCourier, BOT_MODE_DESIRE_ABSOLUTE * 1.2
		end
	end

    if botMode == BOT_MODE_RETREAT
    and botName ~= "npc_dota_hero_bristleback"
    and botLV > 9
    and not X.CanBeInVisible(bot)
    and X.ShouldNotRetreat(bot) then
        nTarget = J.GetAttackableWeakestUnit(bot, nAttackRange + 50, true, true)
        if nTarget ~= nil then return nTarget, BOT_MODE_DESIRE_ABSOLUTE * 1.09 end
    end

    local cItem = J.IsItemAvailable("item_echo_sabre")
    if  cItem ~= nil and (cItem:IsFullyCastable() or cItem:GetCooldownTimeRemaining() < bot:GetAttackPoint() +0.8)
		and IsModeSuitHit
		and (botHP > 0.35 or not bot:WasRecentlyDamagedByAnyHero(1.0))
	then
		local echoDamage = botBAD *2;
		if (cItem:IsFullyCastable() or cItem:GetCooldownTimeRemaining() <  bot:GetAttackPoint())
		then
			nTarget = X.GetNearbyLastHitCreep(true, true, echoDamage, 350, bot);
			if nTarget ~= nil then return nTarget,BOT_MODE_DESIRE_ABSOLUTE *0.98; end
		end
		local nEnemyTowers = bot:GetNearbyTowers(1000,true);			
		if (cItem:IsFullyCastable() or cItem:GetCooldownTimeRemaining() <  bot:GetAttackPoint() +0.8)
			and #nEnemyTowers == 0
		then
			for i=400, 580, 60 do
				nTarget = X.GetExceptRangeLastHitCreep(true, echoDamage, 350, i, bot);
				if nTarget ~= nil 
				   then return nTarget,BOT_MODE_DESIRE_HIGH; end
			end
		end
	end

	local attackDamage = botBAD;
	if  IsModeSuitHit
		and not X.HasHumanAlly( bot )
		and ( botHP > 0.5 or not bot:WasRecentlyDamagedByAnyHero(2.0))
	then
		local nBonusRange = 430;
		if botLV > 12 then nBonusRange = 380; end
		if botLV > 20 then nBonusRange = 330; end

		nTarget = X.GetNearbyLastHitCreep(true, true, attackDamage, nAttackRange + nBonusRange, bot);
		if nTarget ~= nil
		then
			return nTarget,BOT_MODE_DESIRE_ABSOLUTE;
		end
	end

	local denyDamage = botAD + 3
	local nNearbyEnemyHeroes = bot:GetNearbyHeroes(650,true,BOT_MODE_NONE);
	if  IsModeSuitHit
		and ( botHP > 0.38 or not bot:WasRecentlyDamagedByAnyHero(3.0))
		-- [lvlcarry 20260911] see the block above X.NoNearbyEnemyAtLevelCarry.
		-- Unarmed this is `nNearbyEnemyHeroes[1] == nil or
		-- nNearbyEnemyHeroes[1]:GetLevel() < 12` term for term, in this slot.
		and X.NoNearbyEnemyAtLevelCarry(nNearbyEnemyHeroes, 12)
		and bot:DistanceFromFountain() > 3800
		and J.GetDistanceFromEnemyFountain(bot) > 5000
	then
		if bot:GetLevel() <= 8
		then
			local nWillAttackCreeps = X.GetExceptRangeLastHitCreep(true, attackDamage *1.5, 0, nAttackRange +60, bot);
			if nWillAttackCreeps == nil
				or denyDamage > 130
				or not X.IsOthersTarget(nWillAttackCreeps)
				or not X.IsMostAttackDamage(bot)
			then
				nTarget = X.GetNearbyLastHitCreep(false, false, denyDamage, nAttackRange +300, bot);
				if nTarget ~= nil then
					return nTarget,BOT_MODE_DESIRE_ABSOLUTE *0.97;
				end
			end
		end

		local nAllyTowers = bot:GetNearbyTowers(nAttackRange + 300, false);
		if J.IsWithoutTarget(bot)
		   and #nAllyTowers > 0
		then
			if X.CanBeAttacked(nAllyTowers[1])
			   and J.GetHP(nAllyTowers[1]) < 0.05
			   and X.IsLastHitCreep(nAllyTowers[1],denyDamage * 3)
			then
				return nAllyTowers[1],BOT_MODE_DESIRE_ABSOLUTE;
			end
		end
	end

	if  IsModeSuitHit
		and bot:GetLevel() <= 8
		and X.CanAttackTogether(bot)
		-- [lvlgroup 20260911] see the block above X.NoNearbyEnemyAtLevelGroup.
		-- Unarmed this is `nNearbyEnemyHeroes[1] == nil or
		-- nNearbyEnemyHeroes[1]:GetLevel() < 12` term for term, in this slot, so
		-- the short-circuit order is unchanged.
		and X.NoNearbyEnemyAtLevelGroup(nNearbyEnemyHeroes, 12)
		and bot:DistanceFromFountain() > 3800
		and J.GetDistanceFromEnemyFountain(bot) > 5000
	 then
	     local nAllies = bot:GetNearbyHeroes(1200,false,BOT_MODE_NONE);
		 local nNum = X.GetCanTogetherCount(nAllies)
		 local centerAlly = X.GetMostDamageUnit(nAllies);
		 if centerAlly ~= nil and nNum >= 2
		 then
			local nTowerCreeps = centerAlly:GetNearbyLaneCreeps(1600,true);
			local nAllyTower = bot:GetNearbyTowers(1400,false);
			if(nAllyTower[1] ~= nil and nAllyTower[1]:GetAttackTarget() ~= nil)
			then
				local nTowerDamage = nAllyTower[1]:GetAttackDamage();
				local nTowerTarget = nAllyTower[1]:GetAttackTarget();
				for _,creep in pairs(nTowerCreeps)
				do
					if  nTowerTarget == creep
						and X.CanBeAttacked(creep)
						and creep:GetHealth() < X.GetLastHitHealth(nAllyTower[1],creep)
						and creep:GetHealth() > X.GetLastHitHealth(bot,creep)
					then
						local togetherDamage = 0;
						local togetherCount = 0;
						for _,ally in pairs(nAllies)
						do
							if X.CanAttackTogether(ally)
								and GetUnitToUnitDistance(ally,creep) <= ally:GetAttackRange() +50
							then
								togetherDamage = ally:GetAttackDamage() + togetherDamage;
								togetherCount =  togetherCount +1;
							end
						end
						if X.IsLastHitCreep(creep,togetherDamage)
						   and togetherCount >= 2
						   and GetUnitToUnitDistance(bot,creep) <= bot:GetAttackRange() +50
						then
							return creep,BOT_MODE_DESIRE_ABSOLUTE;
						end
					end
				end
		    end

			local nWillAttackCreeps = X.GetExceptRangeLastHitCreep(true, centerAlly:GetAttackDamage() *1.2, 0, 800, centerAlly);
			if nWillAttackCreeps == nil 
				or not X.IsOthersTarget(nWillAttackCreeps)
			then
				local nDenyCreeps = centerAlly:GetNearbyCreeps(1600,false);
				for _,creep in pairs(nDenyCreeps)
				do
					if X.CanBeAttacked(creep)
					and creep:GetHealth()/creep:GetMaxHealth() < 0.5
					and not X.IsLastHitCreep(creep,denyDamage)
					and not J.IsTormentor(creep)
					and not J.IsRoshan(creep)
					then
						local togetherDamage = 0;
						local togetherCount = 0;
						for _,ally in pairs(nAllies)
						do
							if X.CanAttackTogether(ally)
								and GetUnitToUnitDistance(ally,creep) <= ally:GetAttackRange() + 150 
							then
								togetherDamage = ally:GetAttackDamage() + togetherDamage;
								togetherCount = togetherCount +1;
							end
						end
						if X.IsLastHitCreep(creep,togetherDamage)
						   and togetherCount >= 2
						   and GetUnitToUnitDistance(bot,creep) <= bot:GetAttackRange() + 150
						then
							return creep,BOT_MODE_DESIRE_HIGH;
						end
					end
				end
			end
		end

	end

	local nNearbyEnemyHeroes = bot:GetNearbyHeroes(1600,true,BOT_MODE_NONE);
	local nEnemyLaneCreep = bot:GetNearbyLaneCreeps(1200, true);
	local nWillAttackCreeps = X.GetExceptRangeLastHitCreep(true, attackDamage *1.2, 0, nAttackRange + 120, bot);
	if  IsModeSuitHit
		and botLV >= 8
		and nNearbyEnemyHeroes[1] == nil
		and ( attackDamage > 118 or bot:GetSecondsPerAttack() < 0.7 )
		and ( nWillAttackCreeps == nil or not X.IsMostAttackDamage(bot) or not X.IsOthersTarget(nWillAttackCreeps))
	then
		local nEnemyTowers = bot:GetNearbyTowers(900,true);
		if botName ~= "npc_dota_hero_templar_assassin"
		then
			local nTwoHitCreeps = bot:GetNearbyLaneCreeps(nAttackRange +150, true);
			for _,creep in pairs(nTwoHitCreeps)
			do
				if X.CanBeAttacked(creep)
				   and not X.IsLastHitCreep(creep,attackDamage *1.2)
				   and not X.IsOthersTarget(creep)
				then
					local nAllyLaneCreep = bot:GetNearbyLaneCreeps(600, false);
					if X.IsLastHitCreep(creep,attackDamage *2)
					then
						return creep,BOT_MODE_DESIRE_ABSOLUTE;
					elseif X.IsLastHitCreep(creep,attackDamage *3 - 5) 
							and #nAllyLaneCreep == 0 and botLV >= 3						
						then
							return creep,BOT_MODE_DESIRE_ABSOLUTE *0.9;
					end
				end
			end
		end

		if  bot:DistanceFromFountain() > 3800 
			and not bePvNMode and bot:GetLevel() <= 6
			and J.GetDistanceFromEnemyFountain(bot) > 5000
			and nEnemyTowers[1] == nil
			and bot:GetNetWorth() < 19800
			and denyDamage > 110
		then
			local nTwoHitDenyCreeps = bot:GetNearbyCreeps(nAttackRange +120, false);
			for _,creep in pairs(nTwoHitDenyCreeps)
			do
				if X.CanBeAttacked(creep)
				and creep:GetHealth()/creep:GetMaxHealth() < 0.5
				and X.IsLastHitCreep(creep,denyDamage *2)
				and ( not X.IsLastHitCreep(creep,denyDamage *1.2) or #nEnemyLaneCreep == 0 )
				and not X.IsOthersTarget(creep)
				and not J.IsTormentor(creep)
				and not J.IsRoshan(creep)
				then
					return creep,BOT_MODE_DESIRE_ABSOLUTE;
				end
			end
		end

		local nEnemysCreeps = bot:GetNearbyCreeps(1600,true)
		local nAttackAlly = J.GetSpecialModeAllies(bot, 2500, BOT_MODE_ATTACK);
		local nTeamFightLocation = J.GetTeamFightLocation(bot);
		local nDefendLane,nDefendDesire = J.GetMostDefendLaneDesire();
		if  X.CanBeAttacked(nEnemysCreeps[1])
		and bot:GetHealth() > 300
		and not X.IsAllysTarget(nEnemysCreeps[1])
		and not J.IsRoshan(nEnemysCreeps[1])
		and (nEnemysCreeps[1]:GetTeam() == TEAM_NEUTRAL or attackDamage > 110)
		and ( not nEnemysCreeps[1]:IsAncientCreep() or attackDamage > 150 )
		and ( not J.IsKeyWordUnit("warlock", nEnemysCreeps[1]) or J.GetHP(bot) > 0.58 )		
		and ( nTeamFightLocation == nil or GetUnitToLocationDistance(bot,nTeamFightLocation) >= 3000 )
		and ( nDefendDesire <= 0.8 )
		and botMode ~= BOT_MODE_FARM
		and botMode ~= BOT_MODE_RUNE
		and botMode ~= BOT_MODE_LANING
		and botMode ~= BOT_MODE_ASSEMBLE
		and botMode ~= BOT_MODE_SECRET_SHOP
		and botMode ~= BOT_MODE_SIDE_SHOP
		and botMode ~= BOT_MODE_WARD
		and GetRoshanDesire() < BOT_MODE_DESIRE_HIGH	
		and not bot:WasRecentlyDamagedByAnyHero(2.0)
		and bot:GetAttackTarget() == nil
		and botLV >= 10
		and #nAttackAlly == 0
		and #nEnemyTowers == 0
		and not J.IsTormentor(nEnemysCreeps[1])
		and not J.IsRoshan(nEnemysCreeps[1])
		then
			if nEnemysCreeps[1]:GetTeam() == TEAM_NEUTRAL 
			   and J.IsInRange(bot, nEnemysCreeps[1], nAttackRange + 100)
			   and ( #nEnemysCreeps <= 2 
			         or attackDamage > 220 
					 or botName == "npc_dota_hero_antimage" )
			then
				J.Role['availableCampTable'] = X.UpdateCommonCamp(nEnemysCreeps[1], J.Role['availableCampTable']);
			end
			return nEnemysCreeps[1],BOT_MODE_DESIRE_ABSOLUTE;
		end

		if bot:GetHealth() > 160 
		   and J.IsWithoutTarget(bot)
		then
			local nNeutrals = bot:GetNearbyNeutralCreeps(nAttackRange + 150);
			if #nNeutrals > 0
			   and botMode ~= BOT_MODE_FARM
			then
				for i = 1,#nNeutrals
				do
					if X.CanBeAttacked(nNeutrals[i])
						and not X.IsAllysTarget(nNeutrals[i])
						and not J.IsTormentor(nNeutrals[i])
						and not J.IsRoshan(nNeutrals[i])
						and X.IsLastHitCreep(nNeutrals[i],attackDamage * 2)
					then
						return nNeutrals[i],BOT_MODE_DESIRE_ABSOLUTE; 
					end
				end
			end
		end
	end
    return nil,0;
end

local bHumanAlly = nil
function X.HasHumanAlly( bot )
	if bHumanAlly == false then return false end
	if bHumanAlly == nil
	then
		local teamPlayerIDList = GetTeamPlayers( GetTeam() )
		for i = 1, #teamPlayerIDList
		do
			if not IsPlayerBot( teamPlayerIDList[i] )
			then
				bHumanAlly = true
				break
			end
		end	
		if bHumanAlly ~= true then bHumanAlly = false end
	end
	local allyHeroList = bot:GetNearbyHeroes( 900, false, BOT_MODE_NONE )
	for _, npcAlly in pairs( allyHeroList )
	do
		if not npcAlly:IsBot()
		then
			return true
		end
	end
	return false
end

function X.IsCreepTarget(nUnit)
	local bot = GetBot();
	local nCreeps = bot:GetNearbyCreeps(1200,true);
	for _,creep in pairs(nCreeps)
	do
		if  X.IsValid(creep)
		and creep:GetAttackTarget() == nUnit
		and not J.IsTormentor(creep)
		and not J.IsRoshan(creep)
		then
			return true;
		end
	end
	
	local nCreeps = bot:GetNearbyCreeps(1200,false);
	for _,creep in pairs(nCreeps)
	do
		if X.IsValid(creep)
		and creep:GetAttackTarget() == nUnit
		and not J.IsTormentor(creep)
		and not J.IsRoshan(creep)
		then
			return true;
		end
	end

	return false;
end

-- ==============================
-- Generic utils (many of yours kept)
-- ==============================
function X.IsValid(u) return u ~= nil and not u:IsNull() and u:IsAlive() and u:CanBeSeen() end

function X.GetAttackDamageToCreep( bot )
	if bot:GetItemSlotType(bot:FindItemSlot("item_quelling_blade")) == ITEM_SLOT_TYPE_MAIN
	then
		if bot:GetAttackRange() > 310 or bot:GetUnitName() == "npc_dota_hero_templar_assassin"
		then
			return bot:GetAttackDamage() + 4;
		else
			return bot:GetAttackDamage() + 8;
		end
	end
	if bot:FindItemSlot("item_bfury") >= 0
	then
		return bot:GetAttackDamage() + 15;
	end
	return bot:GetAttackDamage();
end

function X.CanNotUseAttack(b)
    return not b:IsAlive() or J.HasQueuedAction(b) or b:IsInvulnerable() or b:IsCastingAbility()
        or b:IsUsingAbility() or b:IsChanneling() or b:IsStunned() or b:IsDisarmed()
        or b:IsHexed() or b:IsRooted() or X.WillBreakInvisible(b)
end

function X.WillBreakInvisible(b)
    local invis = {
        ["npc_dota_hero_riki"] = true,
        ["npc_dota_hero_phantom_assassin"] = true,
        ["npc_dota_hero_templar_assassin"] = true,
        ["npc_dota_hero_bounty_hunter"] = true,
    }
    if b:IsInvisible() and not invis[b:GetUnitName()] then return true end
    return false
end

function X.CanBeAttacked(unit)
    return unit ~= nil and unit:IsAlive() and unit:CanBeSeen() and not unit:IsNull()
        and not unit:IsAttackImmune() and not unit:IsInvulnerable()
        and not unit:HasModifier("modifier_fountain_glyph")
        and (unit:GetTeam() == team or not unit:HasModifier("modifier_crystal_maiden_frostbite"))
        and (unit:GetTeam() ~= team or (unit:GetUnitName() ~= "npc_dota_wraith_king_skeleton_warrior"
            and unit:GetHealth()/unit:GetMaxHealth() < 0.5))
end

-- Courier scan (unchanged)
local courierFindCD, lastFindTime = 0.1, -90
function X.GetEnemyCourier(b, nRadius)
    if GetGameMode() == 23 then return nil end
    if J.GetDistanceFromEnemyFountain(b) < 1400 then return nil end
    if DotaTime() > lastFindTime + courierFindCD then
        lastFindTime = DotaTime()
        for _,u in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
            if u and u:IsCourier() and u:IsAlive()
            and GetUnitToUnitDistance(b, u) <= nRadius
            and not u:IsInvulnerable() and not u:IsAttackImmune()
            and not u:HasModifier('modifier_fountain_aura') then
                return u
            end
        end
    end
    return nil
end

function X.WeakestUnitExceptRangeCanBeAttacked(bHero, bEnemy, nRange, nRadius, bot)
	local units = {};
	local weakest = nil;
	local weakestHP = 4999;
	local realHP = 0;
	if nRadius > 1600 then nRadius = 1600 end;
	
	if bHero then
		units = bot:GetNearbyHeroes(nRadius, bEnemy, BOT_MODE_NONE);
	else	
		units = bot:GetNearbyLaneCreeps(nRadius, bEnemy);
	end
	
	for _,u in pairs(units) do
		if  X.IsValid(u)
		and GetUnitToUnitDistance(bot,u) > nRange 
		and X.CanBeAttacked(u)
		and not u:HasModifier("modifier_crystal_maiden_frostbite")
		then
			realHP = u:GetHealth() / 1;
			
			if realHP < weakestHP
			then
				weakest = u;
				weakestHP = realHP;
			end			
		end
	end
	return weakest;
end

function X.GetNearbyLastHitCreep(ignorAlly, bEnemy, nDamage, nRadius, bot)

	if nRadius > 1600 then nRadius = 1600 end;
	local nNearbyCreeps = bot:GetNearbyLaneCreeps(nRadius, bEnemy);
	local nDamageType = DAMAGE_TYPE_PHYSICAL;
	local botName = bot:GetUnitName();


	if  bEnemy 
		and botName == "npc_dota_hero_templar_assassin" --V bug
		and bot:HasModifier("modifier_templar_assassin_refraction_damage")
	then
		local cAbility = bot:GetAbilityByName( "templar_assassin_refraction" );
		local bonusDamage = cAbility:GetSpecialValueInt( 'bonus_damage' );
		nDamage = nDamage + bonusDamage;
	end

	if  bEnemy
		and botName == "npc_dota_hero_kunkka"
	then
		local cAbility = bot:GetAbilityByName( "kunkka_tidebringer" );
		if cAbility:IsFullyCastable() 
		then
			local bonusDamage = cAbility:GetSpecialValueInt( 'damage_bonus' );
			nDamage = nDamage + bonusDamage;
		end
	end


	for _,nCreep in pairs(nNearbyCreeps)
	do
		if X.CanBeAttacked(nCreep) and nCreep:GetHealth() < ( nDamage + 256 )
		and ( ignorAlly or not X.IsAllysTarget(nCreep) )
		then
		
			local nAttackProDelayTime = J.GetAttackProDelayTime(bot,nCreep) ;
			
			if bEnemy and botName == "npc_dota_hero_antimage"
				and J.IsKeyWordUnit("ranged",nCreep)
			then
				local cAbility = bot:GetAbilityByName( "antimage_mana_break" );
				if cAbility:IsTrained()
				then
					local bonusDamage = 0.5 * cAbility:GetSpecialValueInt( 'mana_per_hit' );
					nDamage = nDamage + bonusDamage;
				end
			end
		
			
			local nRealDamage = nDamage * 1
				
			if J.WillKillTarget(nCreep,nRealDamage,nDamageType,nAttackProDelayTime)
			then
				return nCreep;
			end
		
		end
	end
	return nil;
end

function X.GetExceptRangeLastHitCreep(bEnemy,nDamage,nRange,nRadius,bot)
	
	local nCreep = X.WeakestUnitExceptRangeCanBeAttacked(false, bEnemy, nRange, nRadius, bot);
	local nDamageType = DAMAGE_TYPE_PHYSICAL;

	if X.IsValid(nCreep)
	then
		if not bEnemy and nCreep:GetHealth()/nCreep:GetMaxHealth() >= 0.5
		then return nil end	
	
		nDamage = nDamage * 1 ;

		local nAttackProDelayTime = J.GetAttackProDelayTime(bot,nCreep);
		
		if J.WillKillTarget(nCreep,nDamage,nDamageType,nAttackProDelayTime)
		then		
			return nCreep;
		end

	end

	return nil;
end

function X.IsLastHitCreep(nCreep,nDamage)
	
	if X.CanBeAttacked(nCreep)
	then
		
		nDamage = nDamage * 1;
		
		if nCreep:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_PHYSICAL) + J.GetCreepAttackProjectileWillRealDamage(nCreep,0.66) > nCreep:GetHealth() +1
		then 
		    return true;
		end
		
	end
	 
	return false;
	
end


function X.GetLastHitHealth(bot,nCreep)
	
	if X.CanBeAttacked(nCreep)
	then
	   
       local nDamage = X.GetAttackDamageToCreep(bot) * 1
		
	   return nCreep:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_PHYSICAL);
	end
	 
	return bot:GetAttackDamage();

end


function X.IsAllysTarget(unit)
	local bot = GetBot();
	local allies = bot:GetNearbyHeroes(1000,false,BOT_MODE_NONE);
	if #allies < 2 then return false end;
	
	for _,ally in pairs(allies) 
	do
		if  ally ~= bot
			and not ally:IsIllusion()
			and ( ally:GetTarget() == unit or ally:GetAttackTarget() == unit )
		then
			return true;
		end
	end
	return false;
end


function X.IsEnemysTarget(unit)
	local bot = GetBot();
	local enemys = bot:GetNearbyHeroes(1600,true,BOT_MODE_NONE);
	for _,enemy in pairs(enemys) 
	do
		if  X.IsValid(enemy) and J.GetProperTarget(enemy) == unit 
		then
			return true;
		end
	end
	return false;
end


function X.CanAttackTogether(bot)
   
   local allies = bot:GetNearbyHeroes(1200,false,BOT_MODE_NONE);
   local nNearbyEnemyHeroes = bot:GetNearbyHeroes(600,true,BOT_MODE_NONE);
   
   return bot ~= nil and bot:IsAlive()
		  and not bot:IsIllusion()
		  and J.GetProperTarget(bot) == nil
	      and #allies >= 2
		  -- [lvltogether 20260911] see X.NoNearbyEnemyAtLevelTogether above.
		  and X.NoNearbyEnemyAtLevelTogether(nNearbyEnemyHeroes, 10)
   
end


function X.GetMostDamageUnit(nUnits)
	
	local mostAttackDamage = 0;
	local mostUnit = nil;
	for _,unit in pairs(nUnits)
	do
		if unit ~= nil and unit:IsAlive()
			and J.GetProperTarget(unit) == nil
			and unit:GetAttackDamage() > mostAttackDamage
		then
			mostAttackDamage = unit:GetAttackDamage();
			mostUnit = unit;
		end
	end
	
	return mostUnit;

end


function X.GetCanTogetherCount(nAllies)
	
	local nNum = 0;
	for _,ally in pairs(nAllies)
	do
		if X.IsValid(ally) and X.CanAttackTogether(ally)
		then
			nNum = nNum +1;
		end
	end
	
	return nNum;

end

function X.IsOthersTarget(nUnit)
	local bot = GetBot();

	if X.IsValid(nUnit)
	then
		if X.IsAllysTarget(nUnit)
		then
			return true;
		end
		
		if X.IsEnemysTarget(nUnit)
		then
			return true;
		end
		
		if X.IsCreepTarget(nUnit)
		then
			return true
		end
		
		local nTowers = bot:GetNearbyTowers(1600,true);
		for _,tower in pairs(nTowers)
		do
			if J.IsValidBuilding(tower)
			   and tower:GetAttackTarget() == nUnit
			then
				return true;
			end
		end
		
		local nTowers = bot:GetNearbyTowers(1600,false);
		for _,tower in pairs(nTowers)
		do
			if J.IsValidBuilding(tower)
			   and tower:GetAttackTarget() == nUnit
			then
				return true;
			end
		end
	end
	
	return false;

end

function X.CanBeInVisible(bot)

	local nEnemyTowers = bot:GetNearbyTowers(800,true);
	if #nEnemyTowers > 0 
	   or bot:HasModifier("modifier_item_dustofappearance")
	then 
		return false;
	end

	if bot:IsInvisible()
	then
		return true;
	end

	local glimer = J.IsItemAvailable("item_glimmer_cape");
	if glimer ~= nil and glimer:IsFullyCastable() 
	then
		return true;			
	end
	
	local invissword = J.IsItemAvailable("item_invis_sword");
	if invissword ~= nil and invissword:IsFullyCastable() 
	then
		return true;			
	end
	
	local silveredge = J.IsItemAvailable("item_silver_edge");
	if silveredge ~= nil and silveredge:IsFullyCastable() 
	then
		return true;			
	end

	return false;
end

local lastUpdateTime = 0
function X.UpdateCommonCamp(creep, AvailableCamp)
	if lastUpdateTime < DotaTime() - 3.0
	then
		lastUpdateTime = DotaTime();
		for i = 1, #AvailableCamp
		do
			if GetUnitToLocationDistance(creep,AvailableCamp[i].cattr.location) < 500 then
				table.remove(AvailableCamp, i);
				return AvailableCamp;
			end
		end
	end
	return AvailableCamp;
end

-- ==============================
-- Help when core targeted (unchanged)
-- ==============================
function X.ConsiderHelpWhenCoreIsTargeted()
    local nRadius = 3500
    local nModeDesire = bot:GetActiveModeDesire()
    local nClosestCore = J.GetClosestCore(bot, nRadius)

    if  nClosestCore ~= nil
    and J.GetHP(nClosestCore) > 0.2
    and (not J.IsCore(bot) or bot.isBear or (J.IsCore(bot) and (not J.IsInLaningPhase() or J.IsInRange(bot, nClosestCore, 1600))))
    and not J.IsGoingOnSomeone(bot)
    and not (J.IsRetreating(bot) and nModeDesire > 0.8) then
        local nInRangeAlly = J.GetAlliesNearLoc(nClosestCore:GetLocation(), 1200)
        local nInRangeEnemy = J.GetEnemiesNearLoc(nClosestCore:GetLocation(), 1600)

        for _, enemyHero in pairs(nInRangeEnemy) do
            if  J.IsValidHero(enemyHero)
            and GetUnitToUnitDistance(enemyHero, nClosestCore) <= 1600
            and (#nInRangeAlly + 1 >= #nInRangeEnemy) then
                if (enemyHero:GetAttackTarget() == nClosestCore or J.IsChasingTarget(enemyHero, nClosestCore))
                or nClosestCore:WasRecentlyDamagedByHero(enemyHero, 2.5) then
                    return enemyHero, true
                end
            end
        end
    end

    return nil, false
end

-- [lvlhitcreep 20260911] SOAK CANDIDATE -- NOT PROMOTED, gate is live below.
--
-- THE DEFECT, and it is the 'lvlany' family's shape in a NEW function. Shipped:
--     if #nEnemyHeroes >= 3 or (nEnemyHeroes[1] ~= nil and nEnemyHeroes[1]:GetLevel() >= 8)
-- J.GetEnemyList keeps GetNearbyHeroes' distance sort, so `[1]` is the NEAREST
-- live enemy. The question the line asks is existential -- "is a dangerous enemy
-- standing here" -- and the `#nEnemyHeroes >= 3` leg beside it is the author's
-- own proof of that: a term was already spent asking about the GROUP. What the
-- level term actually answers is "is the NEAREST one dangerous", so a level-5
-- support screening a level-12 core at 700 units reads SAFE TO KEEP LAST-HITTING.
--
-- ⭐⭐ WHAT IS DIFFERENT FROM ALL THREE SIBLINGS, and it is the reason this one
-- was worth taking: 'lvlany', 'lvlcarry', 'lvlgroup' and 'lvltogether' each
-- carried `cat_flip == 0` -- arming changed the helper's answer but never the
-- enclosing function's RETURN on any real row. Here arming flips
-- X.IsModeSuitToHitCreep's own early return on 9 live rows of the frame corpus
-- (10 rows change the predicate; 1 of those already had >= 3 enemies, so the
-- first leg had short-circuited it). This lever is driven END TO END on frames
-- that exist, which is the bar 'lvlgroup' put in force, met without an owed
-- fixture. tests/test_lvlhitcreep_suit_to_hit_creep_level_quantifier.lua §5.
--
-- ⛔ DIRECTION, measured over all 1306 live rows (§3): armed answers
-- `any(level >= nLevel)`, shipped answers `[1] >= nLevel`, and `[1]` is a MEMBER
-- of the list, so shipped TRUE implies armed TRUE -- armed is a pure WIDENING of
-- the DANGER predicate, i.e. a pure NARROWING of the permission it guards. It
-- can only ever WITHDRAW a "suitable to hit creeps", never grant one baseline
-- withheld: the bot gets more cautious about standing there auto-attacking
-- creeps, never more reckless. 0 direction violations on the corpus, asserted as
-- an equality. ⛔ That is a bound on the DIRECTION, not a fire rate; no fire
-- rate is claimed here or in the test.
--
-- ⛔ THE DOMAIN IS SELF-LIMITING AND THAT IS NOT AN ACCIDENT. The two answers
-- can only differ while the nearest enemy is below 8 and someone behind them is
-- not, i.e. during the mixed-level window; once both sides are past 8 the
-- nearest is dangerous too and shipped already fires. So this does not become
-- "any enemy within 750 stops farming" in the late game.
--
-- ⛔ FROZEN-HOLD per OWNER_PRIORITIES P4.2 (new ids do not enter the armed set
-- while it is above 20). Registered in state.json:lvlhitcreep_20260911; the
-- armed string, queue.json and test_set.md are untouched.
function X.AnyEnemyAtLevelHitCreep(tHeroes, nLevel)
	if tHeroes == nil or tHeroes[1] == nil then return false end
	if J.IsModeTurbo() and J.IsSoakCandidate('lvlhitcreep') then
		for i = 1, #tHeroes do
			if tHeroes[i]:GetLevel() >= nLevel then return true end
		end
		return false
	end
	return tHeroes[1]:GetLevel() >= nLevel
end

function X.IsModeSuitToHitCreep(b)
    local botMode = b:GetActiveMode()
    local nEnemyHeroes = J.GetEnemyList(b, 750)
    if #nEnemyHeroes >= 3 or X.AnyEnemyAtLevelHitCreep(nEnemyHeroes, 8) then
        return false
    end
    if b:HasModifier("modifier_axe_battle_hunger") then
        if #b:GetNearbyLaneCreeps(b:GetAttackRange() + 180, true) > 0 then return true end
    end
    if b:GetLevel() <= 3 and botMode ~= BOT_MODE_EVASIVE_MANEUVERS
    and (botMode ~= BOT_MODE_RETREAT or (botMode == BOT_MODE_RETREAT and b:GetActiveModeDesire() < 0.78)) then
        return true
    end
    return botMode ~= BOT_MODE_ATTACK
        and botMode ~= BOT_MODE_EVASIVE_MANEUVERS
        and (botMode ~= BOT_MODE_RETREAT or (botMode == BOT_MODE_RETREAT and b:GetActiveModeDesire() < 0.68))
end

function X.IsMostAttackDamage(b)
    for _,ally in pairs(J.GetNearbyHeroes(b, 800, false, BOT_MODE_NONE)) do
        if ally ~= b and not X.CanNotUseAttack(ally) and ally:GetAttackDamage() > b:GetAttackDamage() then
            return false
        end
    end
    return true
end

-- ==============================
-- Retreat logic hardening
-- ==============================
function X.ShouldNotRetreat(b)
    do
        local a = J.GetAlliesNearLoc(b:GetLocation(), 1000)
        local e = J.GetEnemiesNearLoc(b:GetLocation(), 1000)
        local losing = (#a < #e) or not J.WeAreStronger(b, 1000)
        if (b:WasRecentlyDamagedByAnyHero(1.2) or b:WasRecentlyDamagedByTower(1.2)) and losing then
            return false
        end
    end

    if b:HasModifier("modifier_item_satanic_unholy")
       or b:HasModifier("modifier_abaddon_borrowed_time")
       or (b:GetCurrentMovementSpeed() < 240 and not b:HasModifier("modifier_arc_warden_spark_wraith_purge")) then
        return true
    end

    local nAttackAlly = J.GetNearbyHeroes(b, 1000, false, BOT_MODE_ATTACK)
    if (b:HasModifier("modifier_item_mask_of_madness_berserk") or J.CanIgnoreLowHp(b))
    and (#nAttackAlly >= 1 or J.GetHP(b) > 0.6)
    and (b:WasRecentlyDamagedByAnyHero(1) or b:WasRecentlyDamagedByTower(1)) then
        return true
    end

    local nAllies = J.GetAllyList(b, 800)
    if #nAllies <= 1 then return false end

    if (botName == "npc_dota_hero_medusa" or b:FindItemSlot("item_abyssal_blade") >= 0)
       or b:HasModifier('modifier_muerta_pierce_the_veil_buff')
    and (b:WasRecentlyDamagedByAnyHero(1) or J.GetHP(b) > 0.2 or b:WasRecentlyDamagedByTower(1))
    and #nAllies >= 3 and #nAttackAlly >= 1 then
        return true
    end

    if botName == "npc_dota_hero_skeleton_king" and b:GetLevel() >= 6 and #nAttackAlly >= 1 then
        local abilityR = b:GetAbilityByName("skeleton_king_reincarnation")
        if abilityR and abilityR:GetCooldownTimeRemaining() <= 1.0 and b:GetMana() >= 160 then
            return true
        end
    end

    for _,ally in pairs(nAllies) do
        if J.IsValid(ally) then
            if J.GetHP(b) >= 0.3 and (
                (J.GetHP(ally) > 0.88 and ally:GetLevel() >= 12 and ally:GetActiveMode() ~= BOT_MODE_RETREAT)
                or ally:HasModifier("modifier_black_king_bar_immune") or ally:IsMagicImmune()
                or (ally:HasModifier("modifier_item_mask_of_madness_berserk") and ally:GetAttackTarget() ~= nil)
                or ally:HasModifier("modifier_abaddon_borrowed_time")
                or ally:HasModifier("modifier_item_satanic_unholy")
                or J.CanIgnoreLowHp(ally)
            ) then
                return true
            end
        end
    end

    return false
end

-- ==============================
-- Tower creep targeting (guarded)
-- ==============================
local fLastReturnTime = 0
function X.ShouldAttackTowerCreep(b)
    if X.CanNotUseAttack(b) then return 0 end

    if b:GetLevel() > 2
    and b:GetAnimActivity() == 1502
    and b:GetTarget() == nil and b:GetAttackTarget() == nil
    and X.IsModeSuitToHitCreep(b)
    and J.GetHP(b) > 0.38
    and not b:WasRecentlyDamagedByAnyHero(2.0) then
        local nRange = math.min(b:GetAttackRange() + 150, 1250)
        local allyCreeps = b:GetNearbyLaneCreeps(800, false)
        local enemyCreeps = b:GetNearbyLaneCreeps(800, true)
        local attackTime = b:GetSecondsPerAttack() * 0.75
        local attackTarget = nil
        local nEnemyTowers = b:GetNearbyTowers(nRange, true)
        local bMS = b:GetCurrentMovementSpeed()

        if X.CanBeAttacked(nEnemyTowers[1])
        and (nEnemyTowers[1]:GetAttackTarget() ~= b or J.GetHP(b) > 0.8)
        and #allyCreeps > 0
        and fLastReturnTime < DotaTime() - 1.0 then
            attackTarget = nEnemyTowers[1]
            local nDist = GetUnitToUnitDistance(b, attackTarget) - b:GetAttackRange()
            if nDist > 0 then attackTime = attackTime + nDist / bMS end
            fLastReturnTime = DotaTime()
            return attackTime, attackTarget
        end

        local nEnemyBarracks = b:GetNearbyBarracks(nRange, true)
        if X.CanBeAttacked(nEnemyBarracks[1]) and #allyCreeps > 0 then
            attackTarget = nEnemyBarracks[1]
            local nDist = GetUnitToUnitDistance(b, attackTarget) - b:GetAttackRange()
            if nDist > 0 then attackTime = attackTime + nDist / bMS end
            return attackTime, attackTarget
        end

        local nEnemyAncient = GetAncient(GetOpposingTeam())
        if J.IsInRange(b, nEnemyAncient, nRange + 80)
        and X.CanBeAttacked(nEnemyAncient) and #enemyCreeps == 0 then
            attackTarget = nEnemyAncient
            local nDist = GetUnitToUnitDistance(b, attackTarget) - b:GetAttackRange()
            if nDist > 0 then attackTime = attackTime + nDist / bMS end
            return attackTime, attackTarget
        end
    end

    local nTowers = b:GetNearbyTowers(1600, false)
    if nTowers[1] == nil or not X.IsMostAttackDamage(b) or b:GetLevel() > 12 then
        return 0, nil
    end

    if nTowers[1] ~= nil and nTowers[1]:GetAttackTarget() ~= nil then
        local towerTarget = nTowers[1]:GetAttackTarget()
        local hAllyCreepList = b:GetNearbyLaneCreeps(500, false)
        if not towerTarget:IsHero() and X.CanBeAttacked(towerTarget)
        and #hAllyCreepList == 0 and not X.IsCreepTarget(towerTarget)
        and GetUnitToUnitDistance(b, towerTarget) < b:GetAttackRange() + 100 then
            local towerRealDamage = X.GetLastHitHealth(nTowers[1], towerTarget)
            local botRealDamage   = X.GetLastHitHealth(b, towerTarget)
            local attackTime      = b:GetSecondsPerAttack() - 0.3
            local towerTargetHealth = towerTarget:GetHealth()
            if towerRealDamage > botRealDamage
            and towerTargetHealth > towerRealDamage
            and towerTargetHealth % towerRealDamage > botRealDamage then
                return attackTime, towerTarget
            end
        end
    end

    return 0, nil
end

-- ==============================
-- Items & pick/drops (unchanged logic; minor cleanup)
-- ==============================
function ItemOpsDesire()
    if DotaTime() >= ConsiderDroppedTime + 2.0 then
        for _, droppedItem in pairs(GetDroppedItemList()) do
            if droppedItem ~= nil then
                local itemName = droppedItem.item:GetName()
                if not J.Utils.SetContains(itemName) and not J.Utils.HasValue(Item['tEarlyConsumableItem'], itemName) then
                    if itemName == 'item_aegis' and J.GetPosition(bot) <= 3 and not J.HasItem(bot, 'item_aegis') then
                        if J.Item.GetEmptyNonBackpackInventoryAmount(bot) == 0 then
                            local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)
                            local emptySlot = J.Item.GetEmptyBackpackSlot(bot)
                            if lessValItem ~= -1 and emptySlot ~= -1 then
                                bot:ActionImmediate_SwapItems(emptySlot, lessValItem)
                            end
                        end
                        PickedItem = droppedItem
                    end
                    if itemName == 'item_cheese' and J.GetPosition(bot) <= 3 and not J.HasItem(bot, 'item_aegis') then
                        PickedItem = droppedItem
                    end
                    if itemName == 'item_refresher_shard' then
                        local mostCDHero = J.GetMostUltimateCDUnit()
                        if mostCDHero ~= nil and mostCDHero:IsBot() and bot == mostCDHero then
                            PickedItem = droppedItem
                        end
                    end
                    local nDropOwner = droppedItem.owner
                    if nDropOwner ~= nil and nDropOwner == bot and not string.find(itemName, 'token') then
                        PickedItem = droppedItem
                    end
                    if PickedItem ~= nil and GetItemCost(itemName) > minPickItemCost then
                        return RemapValClamped(J.Utils.GetLocationToLocationDistance(droppedItem.location, bot:GetLocation()),
                            5000, 0, BOT_ACTION_DESIRE_NONE, BOT_ACTION_DESIRE_VERYHIGH)
                    end
                end
            end
        end
        ConsiderDroppedTime = DotaTime()
    end

    TrySellOrDropItem()
    SwapSmokeSupport()
    TrySwapInvItemForCheese()
    TrySwapInvItemForRefresherShard()
    TrySwapInvItemForClarity()
    TrySwapInvItemForFlask()
    -- [bagtango] Appended AFTER the shipped flask rescuer, never inserted into
    -- it, so with this id un-armed every call above evaluates byte-identically.
    TrySwapInvItemForFieldRegen()
    TrySwapInvItemForSmoke()
    TrySwapInvItemForMoonshard()
end

function ItemOpsThink()
    if PickedItem ~= nil then
        if J.Item.GetEmptyInventoryAmount(bot) > 0 and not PickedItem.item:IsNull() then
            local itemName = PickedItem.item:GetName()
            if tryPickCount >= 3 and not Utils.SetContains(itemName) then
                tryPickCount = 0
                Utils.AddToSet(ignorePickupList, PickedItem.item)
            end
            if not Utils.SetContains(itemName) and not Utils.HasValue(Item['tEarlyConsumableItem'], itemName) then
                if itemName == 'item_aegis' or itemName == 'item_cheese' then
                    if J.GetPosition(bot) <= 3 and not J.HasItem(bot, 'item_aegis') then
                        GoPickUpItem(PickedItem)
                    end
                else
                    GoPickUpItem(PickedItem)
                end
            end
        end
    end
end

function GoPickUpItem(goPickItem)
    local distance = GetUnitToLocationDistance(bot, goPickItem.location)
    if distance > 200 and distance < 2000 then
        bot:Action_MoveToLocation(goPickItem.location)
    elseif distance <= 100 then
        tryPickCount = tryPickCount + 1
        bot:Action_PickUpItem(goPickItem.item)
        return
    end
end

-- Swap smoke after killing Roshan
function SwapSmokeSupport()
	if J.IsDoingRoshan(bot)
	then
		local botTarget = bot:GetAttackTarget()

		if J.IsRoshan(botTarget)
		and J.IsAttacking(bot)
		then
			local smokeSlot = bot:FindItemSlot('item_smoke_of_deceit')

			if bot:GetItemSlotType(smokeSlot) == ITEM_SLOT_TYPE_BACKPACK
			then
				local leastCostItem = J.FindLeastExpensiveItemSlot()
	
				if leastCostItem ~= -1
				then
					bot:ActionImmediate_SwapItems(smokeSlot, leastCostItem)
				end
			end
		end
	end
end
-- Swap Items for healing
function TrySwapInvItemForClarity()
	if 	DotaTime() >= SwappedClarityTime + 6.3
	and bot:GetActiveMode() ~= BOT_MODE_WARD
	then
		local cSlot = bot:FindItemSlot('item_clarity')
		if cSlot and bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK
		then
			local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)

			if lessValItem ~= -1
			then
				bot:ActionImmediate_SwapItems(cSlot, lessValItem)
			end
		end

		SwappedClarityTime = DotaTime()
	end
end
function TrySwapInvItemForFlask()
	if 	DotaTime() >= SwappedFlaskTime + 6.2
	and bot:GetActiveMode() ~= BOT_MODE_WARD
	then
		local cSlot = bot:FindItemSlot('item_flask')
		if cSlot and bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK
		then
			local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)

			if lessValItem ~= -1
			then
				bot:ActionImmediate_SwapItems(cSlot, lessValItem)
			end
		end

		SwappedFlaskTime = DotaTime()
	end
end

-- [bagtango / owner priority P2, GH #734, 2026-09-11] The OTHER FOUR members of
-- the supply set this tree recognises, and the reason the flask rescuer above
-- does not already cover them.
--
-- The defect, stated as a set difference. J.HasFieldRegenSource (jmz_func ~5571)
-- accepts FIVE things as "something to drink in the field": item_flask,
-- item_tango, item_tango_single, item_faerie_fire, and a charged item_bottle.
-- The shipped backpack rescuers in this file cover item_clarity, item_flask,
-- item_smoke_of_deceit, item_moon_shard, item_cheese and item_refresher_shard.
-- Intersect those two lists and exactly ONE regen source has a rescuer: the
-- flask. A tango or a faerie fire that is delivered into slots 6-8 is therefore
-- stuck there for the rest of the game -- not for 6.2 seconds, not until a main
-- slot frees, permanently -- because nothing in the tree ever swaps it out and a
-- backpacked item cannot be activated.
--
-- ⭐ THIS IS NOT GH #734's PROPOSED FIX, and the distinction is load-bearing.
-- #734 proposes narrowing the fieldbuy purchase gate from
-- Item.GetEmptyInventoryAmount (slots 0..8) to GetEmptyNonBackpackInventoryAmount
-- (slots 0..5). That proposal is the same one GH #123 made and it was MEASURED
-- AND REFUTED on this corpus -- see tests/test_fieldbuy_backpack_rescuer.lua:
-- it would silence the id on 13 of 28 dry domain frames (46.4%) while the
-- shipped rescuer would have worked on 13 of those 13. That file's closing
-- bound is the pointer this block picks up, verbatim: "this file does not claim
-- the residual is not real. It claims the purchase gate is not its cause.
-- Finding the cause is a separate unit." This is that unit, and it lands on the
-- OTHER side of the trade -- it makes MORE backpacked supply drinkable rather
-- than buying less of it, so it cannot reproduce the 46.4% loss the refutation
-- priced.
--
-- ⚠️ WHAT THIS DOES AND DOES NOT CLAIM ABOUT #734's 18.0% STUCK. It does not
-- claim to be the whole of it. #734's own three frame examples are all flasks,
-- which already have a rescuer, so some of that population has a different
-- cause still unfound (two open hypotheses are registered in this round's
-- report; both need a corpus read this site cannot do). What is claimed here is
-- narrower and is provable off the source alone, which is why it is the piece
-- taken first: for tango / tango_single / faerie_fire the stuck rate is not a
-- measured residual at all, it is 100% BY CONSTRUCTION.
--
-- Direction is fixed by CONSTRUCTION: arming can only move a consumable from a
-- slot where it cannot be used into one where it can, and the displaced item is
-- chosen by the same GetMainInvLessValItemSlot the five shipped rescuers use --
-- which already refuses every item on Item['sCanNotSwitchItems'] (aegis, cheese,
-- bloodstone, gem, moon shard, BKB, the lotuses). It can add no purchase, no
-- cast and no movement.
--
-- No thrash by construction: after one swap the item IS in a main slot, so
-- GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK is false on the next poll
-- and the block is a no-op until another one lands in the bag.
--
-- Turbo is NOT structural here and so is asked EXPLICITLY. Unlike the
-- J.ShouldFieldBuyRegen family in jmz_func -- whose callers all pass through
-- J.IsFieldRegenSituation, whose first line is IsModeTurbo -- this function is
-- reached from ItemOpsDesire on every frame in every mode, so there is no turbo
-- ancestor to inherit. Omitting the check would ship a normal-mode behaviour
-- change behind a turbo-only charter.
--
-- Gated STANDALONE -- exactly one id in this condition and exactly one call
-- site, never a conjunction of two and never a second caller of a shared helper
-- (the 'pullcad' trap, and the 'lvlany' §5b nail). In particular it does NOT
-- read J.HasFieldRegenSource and does not depend on 'bagsalve' or 'staybag':
-- those two widen what the tree BELIEVES it is carrying, this widens what it can
-- actually reach. A single-arm wave can therefore see this id on its own.
--
-- The bottle is deliberately NOT in the list. It is the one member whose backpack
-- problem this mechanism cannot fix: bottle refills at the fountain and its
-- charge state, not its slot, is what the supply read turns on -- and swapping a
-- full bottle into main displaces a real item for a source 'staybottle' already
-- reads in flight. One lever, three items.
function TrySwapInvItemForFieldRegen()
	if not J.IsSoakCandidate('bagtango') then return end
	if not J.IsModeTurbo() then return end

	if 	DotaTime() >= SwappedFieldRegenTime + 6.4
	and bot:GetActiveMode() ~= BOT_MODE_WARD
	then
		for _, sName in ipairs({ 'item_tango', 'item_tango_single', 'item_faerie_fire' })
		do
			local cSlot = bot:FindItemSlot(sName)
			if cSlot ~= nil and cSlot >= 0
			and bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK
			then
				local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)

				if lessValItem ~= -1
				then
					bot:ActionImmediate_SwapItems(cSlot, lessValItem)
					break
				end
			end
		end

		SwappedFieldRegenTime = DotaTime()
	end
end

function TrySwapInvItemForSmoke()
	if 	DotaTime() >= SwappedSmokeTime + 15
	then
		local cSlot = bot:FindItemSlot('item_smoke_of_deceit')
		if cSlot and bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK
		then
			local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)

			if lessValItem ~= -1
			then
				bot:ActionImmediate_SwapItems(cSlot, lessValItem)
			end
		end

		SwappedSmokeTime = DotaTime()
	end
end

-- Swap Items for moonshard
function TrySwapInvItemForMoonshard()
	if DotaTime() >= SwappedMoonshardTime + 10.0
	and bot:GetActiveMode() ~= BOT_MODE_WARD
	then
		local cSlot = bot:FindItemSlot('item_moon_shard')
		if cSlot and bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK
		then
			local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)

			if lessValItem ~= -1
			then
				bot:ActionImmediate_SwapItems(cSlot, lessValItem)
			end
		end
		SwappedMoonshardTime = DotaTime()
	end
end

-- Swap Items for Cheese
function TrySwapInvItemForCheese()
	if 	DotaTime() >= SwappedCheeseTime + 2.3
	and bot:GetActiveMode() ~= BOT_MODE_WARD
	then
		local cSlot = bot:FindItemSlot('item_cheese')

		if bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK
		then
			local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)

			if lessValItem ~= -1
			then
				bot:ActionImmediate_SwapItems(cSlot, lessValItem)
			end
		end

		SwappedCheeseTime = DotaTime()
	end
end

-- Swap Items for Refresher Shard
function TrySwapInvItemForRefresherShard()
	if 	DotaTime() >= SwappedRefresherShardTime + 2.2
	and bot:GetActiveMode() ~= BOT_MODE_WARD
	then
		local rSlot = bot:FindItemSlot('item_refresher_shard')

		if bot:GetItemSlotType(rSlot) == ITEM_SLOT_TYPE_BACKPACK
		then
			local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)

			if lessValItem ~= -1
			then
				bot:ActionImmediate_SwapItems(rSlot, lessValItem)
			end
		end

		SwappedRefresherShardTime = DotaTime()
	end
end

function TrySellOrDropItem()
	if DotaTime() > 0 and DotaTime() - lastCheckBotToDropTime > 3
	then
		lastCheckBotToDropTime = DotaTime()

		-- 再尝试丢/卖掉
		if bot:GetLevel() >= 6 and bot:GetNetWorth() >= 14000 and Utils.CountBackpackEmptySpace(bot) <= 1 then
			for i = 1, #Item['tEarlyConsumableItem']
			do
				local itemName = Item['tEarlyConsumableItem'][i]
				local itemSlot = bot:FindItemSlot( itemName )
				if itemSlot >= 6 and itemSlot <= 8
				then
					local distance = bot:DistanceFromFountain()
					if distance <= 300 then
						bot:ActionImmediate_SellItem( bot:GetItemInSlot( itemSlot ))
					elseif distance >= 3000 then
						bot:Action_DropItem( bot:GetItemInSlot( itemSlot ), bot:GetLocation() )
					end
				end
			end
		end
	end
end

function J.FindLeastExpensiveItemSlot()
	local minCost = 100000
	local idx = -1

	for i = 0, 5
	do
		if bot:GetItemInSlot(i) ~= nil
		and bot:GetItemInSlot(i):GetName() ~= 'item_aegis'
		and bot:GetItemInSlot(i):GetName() ~= 'item_rapier'
		then
			local item = bot:GetItemInSlot(i):GetName()

			if GetItemCost(item) < minCost
			and not (item == 'item_ward_observer' or item == 'item_ward_sentry')
			then
				minCost = GetItemCost(item)
				idx = i
			end
		end
	end

	return idx
end

X.GetDesire = GetDesire
X.Think = Think

return X
