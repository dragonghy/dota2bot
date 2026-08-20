-- Replay-fixture regression for GH #47 -- the FIRST execution audit of the
-- `zusult` gate, run by the replay group on the batch's own 22:11Z (a)-evidence
-- wave. Verdict there: WORKING on the Q side, LEAKING on the W side.
--
-- WHY IT LEAKED (code fact): Lightning Bolt is the one ability handle in
-- hero_zuus.lua with TWO consumers. X.ConsiderW bids it as a targeted cast and
-- was gated; X.ConsiderW2 bids the identical ability as a ground cast and was
-- NOT. Holding the first bid simply let the same mana leave through the second,
-- at the same target, on the very next lines of X.SkillsComplement. The audit
-- measured 3 such casts on the armed side against 0 leaked Arc Lightnings --
-- the split inside one side, not the cross-side totals, is the evidence: both
-- spells go through ONE gate call, so if the gate itself were dead Q would leak
-- too.
--
-- THE FRAME (game 20260819_222052_slot1, seed 869 radiant = the armed side,
-- dumper at 0.5s; the frame GH #47 itself nominated as the cleanest one):
--   t=540.9  Zeus, level 8, 1000/1000 HP -- untouched -- holding 152 of 812
--            mana. Thundergod's Wrath is level 1 with cooldown 0: ready, and
--            unaffordable. Three allies stand inside 800 units (slardar 481,
--            skywrath 523, chaos_knight 677) and shadow_shaman is 648 away at
--            978/978 HP, i.e. completely full.
--            He fires Lightning Bolt into that full-HP shadow_shaman for 240,
--            spending 118 of his 152 mana.                <-- THIS FIXTURE
--   t=544.7  49 more mana into Heavenly Jump.
--   t=564.4  Zeus dies. Thundergod's Wrath is STILL level 1, STILL cooldown 0,
--            and he is holding 77 mana. He died with his ultimate ready and
--            unaffordable, 23.5s after paying for that full-HP poke.
--            (fixture observed.died_after = 22.7 to the last live snapshot.)
--   t=628.4  The game's ONLY ult, 87s after this frame.
--
-- WHICH BRANCH: the audit could not name it offline and said so. This fixture
-- can, because it replays the real geometry: ConsiderW and ConsiderQ both bid
-- DESIRE_NONE here, so the queued bolt is unambiguously ConsiderW2's, and
-- walking a single ally out of the 800 ring silences it -- the firing clause is
-- `#nAllies >= 3`, which is exactly the leak the director predicted in
-- test_set.md §J.0.3. Note the correction to the audit's own count: the third
-- ally (chaos_knight, 677u) IS inside the ring on this frame, and all three are
-- real heroes -- the chaos_knight illusions are 7000+ units away, so the
-- illusion exposure the audit flagged separately is NOT what fired here.
--
-- FIX: X.ConsiderW2 now returns, as a third value, the enemy hero its location
-- was aimed at -- but only for its poke branches. The kill-AoE, channel-
-- interrupt and retreat branches keep reporting no target, so the gate (inert on
-- a nil target) can never stand between Zeus and a kill, an interrupt or his own
-- escape. X.SkillsComplement runs that target through the SAME
-- X.zuus_ShouldSaveManaForUlt call and the SAME `zusult` candidate id -- no new
-- gate, no new id, one lever.
--
-- EXTERNAL ANCHORS -- what does NOT come from the frame:
--   * Thundergod's Wrath mana cost. make_fixture.py extracts no ability specs.
--     Measured in this very replay: 848 -> 600 across the t=628.4 cast (248,
--     minus ~2-3 of regen); GH #47 measured 603 -> 387 and 332 -> 99 elsewhere
--     in the same wave (216 / 233). The conclusion here does NOT depend on the
--     choice: Zeus holds 152, and the hold is asserted at BOTH ends of that
--     measured band below.
--   * Lightning Bolt cast range 700 and Arc Lightning 900 (Liquipedia), which
--     the dumper reports as 0. Without them no bolt branch is reachable at all
--     and every case here would be a false green.
-- Everything the gate and the branch read -- Zeus's mana, the ult's level and
-- cooldown, every hero's HP and position, alive/dead -- is real frame data.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FRAME = 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua'

local ULT_MANA_COST = 225           -- external anchor, see header
local ULT_COST_LOW, ULT_COST_HIGH = 216, 248   -- measured band across the wave
local ULT_NAME   = 'zuus_thundergods_wrath'
local BOLT_NAME  = 'zuus_lightning_bolt'
local ARC_NAME   = 'zuus_arc_lightning'
local BOLT_RANGE, ARC_RANGE = 700, 900         -- external anchors, see header

--- Load the frame, anchor what the dumper cannot report, arm/disarm the gate.
local function load_zeus(bArmed, bTurbo, nUltCost)
    local J, bot, heroes, fx = rf.load(FRAME)

    local sAbilityList = J.Skill.GetAbilityList(bot)
    -- GH #36 tripwire: before ability_meta.lua taught the loader which name is
    -- the ultimate this slot was nil in every fixture and all ultimate logic
    -- short-circuited before reaching anything under test.
    assert(sAbilityList[6] == ULT_NAME,
        'the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    rawget(abilityR, '__spec').GetManaCost = nUltCost or ULT_MANA_COST
    rawget(bot:GetAbilityByName(BOLT_NAME), '__spec').GetCastRange = BOLT_RANGE
    rawget(bot:GetAbilityByName(ARC_NAME), '__spec').GetCastRange = ARC_RANGE

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(id) return id == 'zusult' end
        or function() return false end

    local X = rf.load_hero('zuus')
    return X, J, bot, heroes, abilityR, fx
end

--- Drive the real X.SkillsComplement() and return what reached the action queue.
local function run_skills(bArmed, bTurbo, nUltCost)
    local X, J, bot, heroes, abilityR, fx = load_zeus(bArmed, bTurbo, nUltCost)
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

-- ---------------------------------------------------------------- ground truth

tests['ground truth: 152 mana, a ready-but-unaffordable ult, a full-HP target'] = function()
    local X, _, bot, heroes, abilityR, fx = load_zeus(true)
    assert(fx.time == 540.9, 'this is the frame GH #47 nominated, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_zuus', 'subject is Zeus')
    assert(bot:GetLevel() == 8, 'Zeus is level 8, got ' .. bot:GetLevel())
    assert(bot:GetMana() == 152, 'real mana on the frame, got ' .. bot:GetMana())
    assert(bot:GetHealth() == bot:GetMaxHealth(),
        'Zeus is at full HP -- this is not a self-preservation cast')
    assert(abilityR:IsTrained() and abilityR:GetLevel() == 1, 'ult is level 1')
    assert(abilityR:GetCooldownTimeRemaining() == 0, 'ult is off cooldown')
    assert(not abilityR:IsFullyCastable(),
        '152 mana cannot pay ' .. abilityR:GetManaCost() .. ' -- ConsiderR bails on line 1')

    local ss = shaman(heroes)
    assert(ss:IsAlive() and ss:GetHealth() == ss:GetMaxHealth(),
        'the target shadow_shaman is at FULL health, got ' .. ss:GetHealth()
        .. '/' .. ss:GetMaxHealth())
    assert(ss:GetHealth() / ss:GetMaxHealth() > X.nUltSaveHealthFloor,
        'and therefore chip, not a kill window')
    local d = GetUnitToUnitDistance(bot, ss)
    assert(d > 600 and d < 700, 'shadow_shaman is ~648 away, got ' .. math.floor(d))
end

tests['ground truth: he died 22.7s later with that ult still ready and unpaid'] = function()
    local _, _, _, _, _, fx = load_zeus(true)
    assert(fx.observed ~= nil and fx.observed.died_after ~= nil, 'the frame carries ground truth')
    assert(fx.observed.died_after > 20 and fx.observed.died_after < 25,
        'Zeus died ~22.7s after this frame, got ' .. tostring(fx.observed.died_after))
    -- The replay's own snapshots at t=564.4: ult level 1, cooldown 0, 77 mana.
    -- That is the cost of this one poke, stated as the outcome it produced.
end

tests['ground truth: three real allies stand inside the 800 ring'] = function()
    local _, J, bot, heroes = load_zeus(true)
    local tAllies = J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
    assert(#tAllies == 3, 'ConsiderW2 sees exactly 3 allies within 800, got ' .. #tAllies)
    -- Name them, so a loader change that starts counting illusions or the bot
    -- itself is caught here rather than silently keeping this test green.
    local seen = {}
    for _, a in ipairs(tAllies) do seen[a:GetUnitName()] = math.floor(GetUnitToUnitDistance(bot, a)) end
    assert(seen['npc_dota_hero_slardar'], 'slardar is one of them')
    assert(seen['npc_dota_hero_skywrath_mage'], 'skywrath_mage is one of them')
    assert(seen['npc_dota_hero_chaos_knight'], 'the REAL chaos_knight is the third (677u)')
    assert(seen['npc_dota_hero_zuus'] == nil, 'the bot itself must not be counted')
    -- The chaos_knight illusions in this game are 7000+ away: the illusion
    -- exposure GH #47 recorded is real, but it is not what fires on this frame.
    local ck = heroes['npc_dota_hero_chaos_knight']
    assert(GetUnitToUnitDistance(bot, ck) < 800, 'the counted chaos_knight is the nearby, real one')
end

-- ------------------------------------------------------------------- gate off

tests['gate OFF: unarmed leaves the frame byte-identical to shipped'] = function()
    local X, _, bot, heroes = load_zeus(false)
    assert(X.zuus_ShouldSaveManaForUlt(bot, shaman(heroes)) == false,
        'unarmed, the helper must be inert')
end

tests['gate OFF: armed but NOT turbo is still inert'] = function()
    local X, _, bot, heroes = load_zeus(true, false)
    assert(X.zuus_ShouldSaveManaForUlt(bot, shaman(heroes)) == false,
        'the gate is turbo-only')
end

-- ------------------------------------------------- which branch actually fires

tests['branch: ConsiderW and ConsiderQ both bid NONE here -- the bolt is W2\'s'] = function()
    local _, X = run_skills(false)
    -- Called after SkillsComplement so the file-locals it seeds are populated.
    local nW = X.ConsiderW()
    local nQ = X.ConsiderQ()
    local nR = X.ConsiderR()
    assert(nW == BOT_ACTION_DESIRE_NONE, 'the targeted-W path does not bid here, got ' .. nW)
    assert(nQ == BOT_ACTION_DESIRE_NONE, 'Arc Lightning does not bid here, got ' .. nQ)
    assert(nR == BOT_ACTION_DESIRE_NONE, 'the ult cannot be paid for, got ' .. nR)
    local nW2, _, hTarget = X.ConsiderW2()
    assert(nW2 > 0, 'ConsiderW2 is the only bidder on this frame, got ' .. nW2)
    assert(hTarget ~= nil and hTarget:GetUnitName() == 'npc_dota_hero_shadow_shaman',
        'and it reports the hero it is aimed at')
end

tests['branch: walking one ally out of the 800 ring silences it => `#nAllies >= 3`'] = function()
    local _, X, _, _, heroes = run_skills(false)
    -- MUTATION of the real frame, deliberate: teleport skywrath_mage far away.
    rawget(heroes['npc_dota_hero_skywrath_mage'], '__spec').GetLocation = Vector(9000, 9000, 0)
    local nW2 = X.ConsiderW2()
    assert(nW2 == BOT_ACTION_DESIRE_NONE,
        'with only 2 allies nearby ConsiderW2 stops bidding, got ' .. nW2
        .. ' -- so the firing clause on the real frame is the ally count, '
        .. 'i.e. exactly the leak predicted in test_set.md J.0.3')
end

-- ---------------------------------------------------------------- gate armed

tests['armed: the helper holds the W2 target on the real frame'] = function()
    local X, _, bot, heroes = load_zeus(true)
    assert(X.zuus_ShouldSaveManaForUlt(bot, shaman(heroes)) == true,
        'ready-but-unaffordable ult + full-HP hero => save the mana')
end

tests['armed: the hold survives the whole measured band of ult mana costs'] = function()
    for _, nCost in ipairs({ ULT_COST_LOW, ULT_MANA_COST, ULT_COST_HIGH }) do
        local X, _, bot, heroes = load_zeus(true, nil, nCost)
        assert(X.zuus_ShouldSaveManaForUlt(bot, shaman(heroes)) == true,
            'the conclusion must not hinge on the anchor: cost=' .. nCost)
    end
    assert(152 < ULT_COST_LOW, 'Zeus\'s real 152 mana is under the whole band')
end

tests['armed: a nil target -- kill-AoE / channel / retreat branches -- is never held'] = function()
    local X, _, bot = load_zeus(true)
    assert(X.zuus_ShouldSaveManaForUlt(bot, nil) == false,
        'ConsiderW2 reports no target for those branches, and the gate must pass them')
end

-- ------------------------------------------------------------------ end to end
-- test_set.md 0b: assert the FINAL decision, not the helper's return value.
-- X.SkillsComplement is the only caller of ConsiderW2, and the gate sits between
-- its bid and the ActionQueue_* call, so driving it here covers the whole path.
-- No mode or attack-target mutation is needed on this frame: the branch that
-- fires reaches its target through J.GetVulnerableWeakestUnit, i.e. through real
-- positions and real HP only.

tests['end to end: shipped fires Lightning Bolt into the full-HP shadow_shaman'] = function()
    local log, _, _, bot, heroes, abilityR = run_skills(false)
    local names = ability_names(log)
    assert(contains(names, BOLT_NAME),
        'shipped Zeus spends the reserve, got {' .. table.concat(names, ',') .. '}')
    assert(not contains(names, ULT_NAME),
        'and it is NOT the ult: ' .. bot:GetMana() .. ' cannot pay ' .. abilityR:GetManaCost())
    -- It is the GROUND cast (ConsiderW2), aimed at the shadow_shaman's position.
    local found = false
    for _, e in ipairs(log) do
        if e.fn == 'ActionQueue_UseAbilityOnLocation'
            and type(e.args[1]) == 'table' and e.args[1]:GetName() == BOLT_NAME then
            found = true
            local v = e.args[2]
            local ss = shaman(heroes)
            assert(GetUnitToLocationDistance(ss, v) < 1,
                'the cast location is the shadow_shaman herself')
        end
    end
    assert(found, 'the leak is a UseAbilityOnLocation, which only ConsiderW2 issues')
end

tests['end to end: armed keeps the mana -- the final decision changes'] = function()
    local armed = ability_names((run_skills(true)))
    assert(not contains(armed, BOLT_NAME),
        'the held Lightning Bolt must not reach the action queue, got {'
        .. table.concat(armed, ',') .. '}')
    assert(not contains(armed, ARC_NAME),
        'nor may the bid fall through to Arc Lightning at the same target, got {'
        .. table.concat(armed, ',') .. '}')
end

tests['end to end: armed still takes the kill -- the floor releases W2 too'] = function()
    local X, J, bot, heroes = load_zeus(true)
    local ss = shaman(heroes)
    -- MUTATION of the real frame: drop the shadow_shaman under the health floor.
    rawget(ss, '__spec').GetHealth = math.floor(ss:GetMaxHealth() * 0.30)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local names = ability_names(log)
    assert(contains(names, BOLT_NAME),
        'a 30%-HP target is a kill window; the reserve must not block it, got {'
        .. table.concat(names, ',') .. '}')
    assert(J.IsSoakCandidate('zusult'), 'sanity: the gate really was armed for this run')
end

tests['armed: once the ult is affordable nothing is being denied'] = function()
    local X, _, bot, heroes = load_zeus(true)
    rawget(bot, '__spec').GetMana = ULT_MANA_COST      -- MUTATION of the real frame
    assert(X.zuus_ShouldSaveManaForUlt(bot, shaman(heroes)) == false,
        'the reserve only matters while the ult is mana-locked')
end

-- ------------------------------------------------------- source-level wiring
-- Cheap tripwires. The end-to-end cases above only exercise the branch that wins
-- on this one frame; these pin the shape of the change itself.

tests['wiring: SkillsComplement gates all THREE bids through one gate, one id'] = function()
    local f = assert(io.open('bots/BotLib/hero_zuus.lua'))
    local src = f:read('*a')
    f:close()
    -- GH #59 added a third argument (the bidding ability's own handle, so the
    -- `zusultx` domain can price the spend). The literals below move with it;
    -- what they pin -- that all THREE bids still route through the one gate --
    -- does not.
    assert(src:find('castQDesire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castQTarget, abilityQ )', 1, true),
        'the Arc Lightning bid must pass through the reserve gate')
    assert(src:find('castWDesire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castWTarget, abilityW )', 1, true),
        'the targeted Lightning Bolt bid must pass through the reserve gate')
    assert(src:find('castW2Desire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castW2Target, abilityW )', 1, true),
        'GH #47: the GROUND Lightning Bolt bid must pass through it too')
    assert(src:find('castW2Desire, castWLocation, castW2Target = X.ConsiderW2()', 1, true),
        'and it must receive the target ConsiderW2 reports')
    local _, nIds = src:gsub("J%.IsSoakCandidate%( 'zusult' %)", '')
    assert(nIds == 1, 'still exactly ONE gate call behind ONE id, found ' .. nIds)
    -- GH #59's widened domain is a SEPARATE id, so the count above stays 1.
    local _, nX = src:gsub("J%.IsSoakCandidate%( 'zusultx' %)", '')
    assert(nX == 1, '`zusultx` is read in exactly one place, found ' .. nX)
end

-- Counted by SHAPE (how many values the return carries), not by the name of the
-- variable -- a name-coupled version of this test let a mutation through that
-- handed the kill-AoE branch a target under a different variable name.
tests['wiring: only ConsiderW2\'s poke branches report a target'] = function()
    local f = assert(io.open('bots/BotLib/hero_zuus.lua'))
    local src = f:read('*a')
    f:close()
    local body = src:match('function X%.ConsiderW2%(%).-\nend\n')
    assert(body ~= nil, 'found the ConsiderW2 body')

    local tArity = {}
    for sLine in body:gmatch('[^\n]+') do
        local sReturn = sLine:match('return%s+BOT_ACTION_DESIRE_HIGH(.*)$')
        if sReturn then
            local _, nCommas = sReturn:gsub(',', '')
            tArity[#tArity + 1] = nCommas + 1
        end
    end
    assert(#tArity == 6,
        'ConsiderW2 has 6 bidding returns; a new one must declare whether it '
        .. 'reports a target, found ' .. #tArity)
    -- Source order: kill-AoE, channel-interrupt, retreat-AoE, then the three
    -- poke branches. Only the last three may hand the gate something to hold.
    for i = 1, 3 do
        assert(tArity[i] == 2,
            'return #' .. i .. ' (kill-AoE / channel-interrupt / retreat) must stay '
            .. 'targetless, so the gate can never hold a kill, an interrupt or an '
            .. 'escape -- it returns ' .. tArity[i] .. ' values')
    end
    for i = 4, 6 do
        assert(tArity[i] == 3,
            'poke return #' .. i .. ' must report the hero it aims at, or the leak '
            .. 'GH #47 measured comes straight back -- it returns ' .. tArity[i] .. ' values')
    end
end

return tests
