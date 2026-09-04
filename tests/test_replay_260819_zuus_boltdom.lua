-- Replay-fixture validation for `zusboltdom` (GH #477).
--
-- WHAT GH #477 MEASURED.  The replay group re-audited `zusult` on W44's other
-- two machines (43/43 games swept, unparseable 0) and found 3 frame-by-frame
-- confirmed Lightning Bolts on the armed leg that sit inside the gate's own
-- domain -- all in 20260904_003453_slot8 (seed 3426, radiant armed), targets at
-- 1.00 / 1.00 / 0.82 HP, ult level 1 and cooldown 0 on all three, spend
-- confirmed (mana -131 / -131, W cooldown 0 -> 6.0).  The other two exempt
-- branches of X.ConsiderW2 were excluded frame by frame.  What is left is the
-- kill-AoE branch: it hands FindAoELocation a filter of 0, the engine reads 0
-- as "no HP filter" (docs/BOT_API_REFERENCE.md § `FindAoELocation` (:1400 today, :1288 when first cited -- find it by heading, the line number drifts)), so the branch fires on
-- "there is an enemy hero in range" while still claiming GH #47's KILL
-- EXEMPTION -- it returns no target, and the reserve gate is inert on nil.
--
-- WHICH FRAME THIS IS, AND WHY IT IS NOT THE ONE GH #477 NOMINATED.  #477 asks
-- for t=404.4 of 20260904_003453_slot8; that frame is not dumped yet and the
-- dump is the replay group's ball (its own re-dump is blocked behind GH #478).
-- This file uses the frame the repo already owns for exactly this gate --
-- 20260819_222052_slot1 t=540.9, the GH #47 frame -- because it carries the
-- same shape the three leaks share, and carries it as real data:
--
--   Zeus, level 8, 152 of 812 mana, at FULL health, not retreating
--   (GetActiveMode 0, BOT_MODE_RETREAT 1005).
--   Thundergod's Wrath: trained, level 1, cooldown 0 -> ready and unaffordable.
--   shadow_shaman  978/978 (1.00 HP)  648u away   <- the weakest enemy in range
--   centaur       1462/1462 (1.00 HP)  715u away
--   viper                       dead   524u away
--
-- So the reserve gate's every clause holds here just as it held on all three
-- of #477's frames; the only question this file asks is whether the kill-AoE
-- branch lets the gate see the target.
--
-- THE ONE READER THIS FILE SUPPLIES, AND WHY THAT IS NOT CIRCULAR.
-- tests/mock/replay_fixture.lua answers every HERO FindAoELocation search with
-- {count = 0} -- deliberately, and it says so in its own header: switching the
-- hero side on moves readings in ~two dozen census tests at once and is a
-- decision to take on purpose. So the kill-AoE branch is UNREACHABLE BY
-- CONSTRUCTION in the fixture world, and this file overrides the reader on the
-- bot, as that same header directs ("a test that needs a cluster the fixture
-- does not have still overrides the spec").
--
-- The override is not a stand-in for the answer: it applies the engine's
-- DOCUMENTED rule (nMaxHealth <= 0 => no HP filter) to the frame's OWN heroes,
-- their OWN positions and their OWN health. Nothing about the count is
-- invented -- it is computed. Two properties keep it honest:
--   * it errs the same direction the loader does. Candidate centres are the
--     qualifying heroes' own positions, which lower-bounds the true optimum;
--     every case below only needs count >= 1 vs count == 0, and on that
--     question the lower bound is EXACT (>= 1 iff some qualifying hero is in
--     range at all).
--   * it is driven by BOTH filter values on the same frame, so the assertions
--     below separate "the filter is degenerate" from "there is a hero nearby":
--     with nMaxHealth 0 the count is 1+, with the real KV damage (380) it is 0,
--     because both live enemies in range are at four figures of health.
--
-- EXTERNAL ANCHORS -- what does not come from the frame:
--   * Thundergod's Wrath mana cost 225 (GH #47 measured 216-248 across that
--     wave). Asserted across the whole band, as in the sibling file.
--   * Nothing else. Bolt cast range and the bolt's KV damage are read from the
--     frame itself now (850 and 380) -- see `kvgetters`, 2026-09-04 -- and the
--     range assertion below is written so it holds at 700 too, the anchor the
--     sibling file froze before those getters were specced.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FRAME = 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua'

local ULT_MANA_COST = 225
local ULT_COST_LOW, ULT_COST_HIGH = 216, 248
local ULT_NAME  = 'zuus_thundergods_wrath'
local BOLT_NAME = 'zuus_lightning_bolt'
local ARC_NAME  = 'zuus_arc_lightning'
local BOLT_SPREAD = 325            -- zuus_lightning_bolt/AbilityValues/spread_aoe

--- The engine's hero AoE search, per docs/BOT_API_REFERENCE.md § `FindAoELocation` (:1400 today, :1288 when first cited -- find it by heading, the line number drifts), computed
--- over the frame's real heroes. Returns the same shape the engine does.
--- `nMaxHealth <= 0` means NO HP filter; anything else keeps only heroes at or
--- under it.
local function hero_aoe_reader(bot, heroes)
    return function(self, bEnemies, bHeroes, vBase, nMaxDist, nRadius, _fFuture, nMaxHealth)
        if bHeroes ~= true then
            -- Not this half: leave the creep search to the loader's own answer.
            return { count = 0, targetloc = self:GetLocation() }
        end
        local base = vBase or self:GetLocation()
        local nCap = tonumber(nMaxHealth) or 0
        local tHit = {}
        for _, h in pairs(heroes) do
            local bSide = (bEnemies == true) and (h:GetTeam() ~= bot:GetTeam())
                or (bEnemies == false) and (h:GetTeam() == bot:GetTeam())
            if bSide and h:IsAlive()
                and (nCap <= 0 or h:GetHealth() <= nCap)
                and GetUnitToLocationDistance(h, base) <= nMaxDist + nRadius
            then
                tHit[#tHit + 1] = h
            end
        end
        -- Candidate centres = the qualifying heroes themselves (a lower bound
        -- on the optimum; exact for the >= 1 question every case here asks).
        local nBest, vBest = 0, self:GetLocation()
        for _, c in ipairs(tHit) do
            local n = 0
            for _, h in ipairs(tHit) do
                if GetUnitToUnitDistance(c, h) <= nRadius then n = n + 1 end
            end
            if n > nBest then nBest, vBest = n, c:GetLocation() end
        end
        return { count = nBest, targetloc = vBest }
    end
end

--- Load the frame, arm the given candidate ids, and supply the hero AoE reader.
local function load_zeus(tArmed, bTurbo, nUltCost)
    local J, bot, heroes, fx = rf.load(FRAME)

    local sAbilityList = J.Skill.GetAbilityList(bot)
    assert(sAbilityList[6] == ULT_NAME,
        'the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    rawget(abilityR, '__spec').GetManaCost = nUltCost or ULT_MANA_COST

    rawget(bot, '__spec').FindAoELocation = hero_aoe_reader(bot, heroes)

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    local tOn = {}
    for _, id in ipairs(tArmed or {}) do tOn[id] = true end
    J.IsSoakCandidate = function(id) return tOn[id] == true end

    local X = rf.load_hero('zuus')
    return X, J, bot, heroes, abilityR, fx
end

local function run_skills(tArmed, bTurbo, nUltCost)
    local X, J, bot, heroes, abilityR, fx = load_zeus(tArmed, bTurbo, nUltCost)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, X, J, bot, heroes, abilityR, fx
end

local function ability_names(log)
    local t = {}
    for _, e in ipairs(log) do
        if e.fn:find('UseAbility') then
            local a = e.args[1]
            t[#t + 1] = (type(a) == 'table' and a.GetName) and a:GetName() or tostring(a)
        end
    end
    return t
end

local function contains(t, s)
    for _, v in ipairs(t) do if v == s then return true end end
    return false
end

local function shaman(heroes) return heroes['npc_dota_hero_shadow_shaman'] end

local tests = {}

-- ------------------------------------------------------------- 1. ground truth

tests['ground truth: the frame carries every clause of the reserve gate'] = function()
    local X, J, bot, heroes, abilityR, fx = load_zeus({ 'zusult' })
    assert(fx.time == 540.9, 'the GH #47 frame, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_zuus', 'subject is Zeus')
    assert(bot:GetMana() == 152, 'real mana on the frame, got ' .. bot:GetMana())
    assert(abilityR:IsTrained() and abilityR:GetCooldownTimeRemaining() == 0,
        'the ult is ready')
    assert(not abilityR:IsFullyCastable(), 'and unaffordable at 152 mana')
    assert(not J.IsRetreating(bot), 'Zeus is not retreating on this frame')
    assert(bot:GetActiveMode() ~= BOT_MODE_RETREAT, 'nor is he in RETREAT mode')
    local ss = shaman(heroes)
    assert(ss:IsAlive() and ss:GetHealth() == ss:GetMaxHealth(),
        'the weakest enemy in range is at FULL health, got ' .. ss:GetHealth())
    assert(J.GetHP(ss) > X.nUltSaveHealthFloor, 'i.e. chip, not a kill window')
    assert(X.zuus_ShouldSaveManaForUlt(bot, ss) == true,
        'so the reserve gate WANTS to hold a bid at this target')
end

tests['ground truth: the bolt damage KV is real, and GetAbilityDamage is the zero'] = function()
    local _, _, bot = load_zeus({})
    local w = bot:GetAbilityByName(BOLT_NAME)
    assert(w:GetAbilityDamage() == 0,
        'zuus_lightning_bolt declares no top-level AbilityDamage, got '
        .. tostring(w:GetAbilityDamage()))
    assert(w:GetSpecialValueInt('damage') == 380,
        'AbilityValues/damage at level 4 is 380, got ' .. tostring(w:GetSpecialValueInt('damage')))
end

tests['ground truth: both live enemies in range are four-figure health'] = function()
    local _, _, bot, heroes = load_zeus({})
    local nReach = bot:GetAbilityByName(BOLT_NAME):GetCastRange() + BOLT_SPREAD
    local nSeen = 0
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
            and GetUnitToUnitDistance(bot, h) <= nReach then
            nSeen = nSeen + 1
            assert(h:GetHealth() > 380,
                h:GetUnitName() .. ' is above the bolt KV damage, got ' .. h:GetHealth())
        end
    end
    assert(nSeen == 2, 'shadow_shaman and centaur, got ' .. nSeen)
    -- Written so it also holds at the sibling file's frozen 700 anchor:
    assert(GetUnitToUnitDistance(bot, shaman(heroes)) < 700 + BOLT_SPREAD,
        'the conclusion does not hinge on which cast-range reading is used')
end

-- --------------------------------------------- 2. the defect, on the real frame

tests['defect: with the shipped zero filter the kill-AoE branch fires on FULL-HP heroes'] = function()
    local _, X = run_skills({ 'zusult' })
    local nDesire, _, hTarget = X.ConsiderW2()
    assert(nDesire > 0, 'the branch bids, got ' .. tostring(nDesire))
    -- The kill exemption is what makes this a leak: the branch that fired is
    -- the one that reports nothing, so the gate above never sees the target.
    assert(hTarget == nil,
        'unarmed, the kill-AoE branch still claims the kill exemption')
end

tests['defect: shipped spends the reserve into a 1.00-HP target'] = function()
    local log, _, _, bot, _, abilityR = run_skills({ 'zusult' })
    local names = ability_names(log)
    assert(contains(names, BOLT_NAME),
        'the leak GH #477 measured, reproduced on a real frame; got {'
        .. table.concat(names, ',') .. '}')
    assert(not contains(names, ULT_NAME),
        'and it is not the ult: ' .. bot:GetMana() .. ' cannot pay ' .. abilityR:GetManaCost())
end

-- ------------------------------------------------------------- 3. the fix works

tests['armed: zusboltdom drops the exemption and the reserve survives'] = function()
    local log, X = run_skills({ 'zusult', 'zusboltdom' })
    local _, _, hTarget = X.ConsiderW2()
    assert(hTarget ~= nil and hTarget:GetUnitName() == 'npc_dota_hero_shadow_shaman',
        'the degenerate filter means the branch must name what it is aimed at')
    local names = ability_names(log)
    assert(not contains(names, BOLT_NAME),
        'the held Lightning Bolt must not reach the action queue, got {'
        .. table.concat(names, ',') .. '}')
    assert(not contains(names, ARC_NAME),
        'nor may the bid fall through to Arc Lightning at the same target, got {'
        .. table.concat(names, ',') .. '}')
end

tests['armed: the hold survives the whole measured band of ult mana costs'] = function()
    for _, nCost in ipairs({ ULT_COST_LOW, ULT_MANA_COST, ULT_COST_HIGH }) do
        local names = ability_names((run_skills({ 'zusult', 'zusboltdom' }, nil, nCost)))
        assert(not contains(names, BOLT_NAME),
            'the conclusion must not hinge on the anchor: cost=' .. nCost)
    end
end

-- ------------------------------------------- 4. it does not cost Zeus any kills

tests['armed: a REAL kill window still fires -- the exemption is only dropped when the filter is degenerate'] = function()
    local X, _, bot, heroes = load_zeus({ 'zusult', 'zusboltdom' })
    -- MUTATION of the real frame, and the only one in this file: put the
    -- shadow_shaman under the bolt's actual damage so the branch has a genuine
    -- kill to claim. Position, team, everything else stays real.
    rawget(shaman(heroes), '__spec').GetHealth = 100
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    assert(contains(ability_names(log), BOLT_NAME),
        'a 100-HP target is a kill window and must never be held, got {'
        .. table.concat(ability_names(log), ',') .. '}')
end

tests['armed: with zusboltcap the filter is real, so the exemption comes back untouched'] = function()
    local X, _, bot, heroes = load_zeus({ 'zusult', 'zusboltdom', 'zusboltcap' })
    -- Same 100-HP kill window; now the cap is the KV damage rather than zero,
    -- and the helper must answer nil BECAUSE OF THE VALUE, not because of the id.
    rawget(shaman(heroes), '__spec').GetHealth = 100
    local _, _, hTarget = X.ConsiderW2()
    assert(hTarget == nil,
        'a real kill filter keeps GH #47\'s exemption')
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    assert(contains(ability_names(log), BOLT_NAME), 'and the kill goes through')
end

tests['armed: zusboltcap alone already silences the branch on the untouched frame'] = function()
    local _, X = run_skills({ 'zusult', 'zusboltcap' })
    local nDesire, _, hTarget = X.ConsiderW2()
    -- Both live enemies are four-figure health against a 380 cap, so the
    -- kill-AoE branch does not fire at all -- whatever bids here is a later
    -- branch, and it is not the kill-AoE return that reports nil.
    assert(hTarget ~= nil or nDesire == BOT_ACTION_DESIRE_NONE,
        'with a real cap, no targetless kill-AoE bid may survive on this frame')
end

-- ------------------------------------------------------------------ 5. gate off

tests['gate OFF: unarmed zusboltdom is byte-equivalent to shipped'] = function()
    local shipped = ability_names((run_skills({ 'zusult' })))
    local X = load_zeus({ 'zusult' })
    assert(X.BoltAoEKillTarget(0, shaman(select(4, load_zeus({ 'zusult' })))) == nil,
        'unarmed, the helper reports nothing whatever the cap says')
    assert(contains(shipped, BOLT_NAME), 'and the shipped decision is unchanged')
end

tests['gate OFF: armed but NOT turbo is inert'] = function()
    local X, _, _, heroes = load_zeus({ 'zusult', 'zusboltdom' }, false)
    assert(X.BoltAoEKillTarget(0, shaman(heroes)) == nil, 'the gate is turbo-only')
end

tests['gate OFF: a different armed candidate does not move it'] = function()
    local X, _, _, heroes = load_zeus({ 'zusult', 'zusaether' })
    assert(X.BoltAoEKillTarget(0, shaman(heroes)) == nil,
        'only zusboltdom arms zusboltdom')
    -- Positive control inside the same case: the id really is the only thing
    -- standing between this call and a non-nil answer.
    local Y, _, _, tHeroes = load_zeus({ 'zusult', 'zusaether', 'zusboltdom' })
    assert(Y.BoltAoEKillTarget(0, shaman(tHeroes)) ~= nil,
        'positive control: arming it does change the answer')
end

-- --------------------------------------------------------- 6. the helper itself

tests['helper: the switch is the cap VALUE, across its whole shape'] = function()
    local X, _, _, heroes = load_zeus({ 'zusboltdom' })
    local ss = shaman(heroes)
    assert(X.BoltAoEKillTarget(0, ss) == ss, 'zero: no HP filter => report')
    assert(X.BoltAoEKillTarget(-1, ss) == ss, 'negative is not a filter either')
    assert(X.BoltAoEKillTarget(1, ss) == nil, 'one is a filter, however small')
    assert(X.BoltAoEKillTarget(380, ss) == nil, 'the real KV damage is a filter')
    assert(X.BoltAoEKillTarget(nil, ss) == nil, 'a non-number is not a degenerate cap')
    assert(X.BoltAoEKillTarget('0', ss) == nil, 'and neither is a string that looks like one')
end

-- ------------------------------------------------------- 7. source-level wiring

tests['wiring: the dependency is written as a value test, never as a sibling id'] = function()
    local f = assert(io.open('bots/BotLib/hero_zuus.lua'))
    local src = f:read('*a')
    f:close()
    local body = src:match('function X%.BoltAoEKillTarget%b()(.-)\nend\n')
    assert(body ~= nil, 'found the helper body')
    assert(body:find("J%.IsSoakCandidate%( 'zusboltdom' %)"), 'it reads its own id')
    -- The pullcad trap (AGENTS.md): a gate that names another candidate freezes
    -- FALSE the day that candidate is promoted. This one must key on the value.
    assert(not body:find('zusboltcap', 1, true),
        'the helper must not name zusboltcap -- promoting it would freeze this gate')
    assert(body:find('nHealthCap <= 0', 1, true), 'the switch is the cap value')
    local _, nCalls = src:gsub('X%.BoltAoEKillTarget%(', '')
    assert(nCalls == 2, 'declared once, called once, found ' .. nCalls .. ' occurrences')
end

return tests
