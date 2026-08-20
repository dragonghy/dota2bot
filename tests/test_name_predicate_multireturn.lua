-- [GH #51] "Does this unit's name contain X?" answered true for every unit.
--
-- `string.find` is a MULTI-return function. TypeScriptToLua compiles any
-- assignment or `!== null` comparison of a multi-return call into a TABLE
-- CONSTRUCTOR, and a table is never nil:
--
--     const result = string.find(unit.GetUnitName(), name);   // TS
--     local result = {string.find(unit:GetUnitName(), name)}  -- generated Lua
--     return result ~= nil                                    -- ALWAYS true
--
-- The issue reported four call sites of `Utils.IsUnitWithName`. The same
-- compiled shape was present ELEVEN times in two generated files, and the two
-- that were not in the issue are the ones with numbers attached to them --
-- both in aba_defend, both on the shipped default path, neither gated:
--
--   * `ShouldDefend` (aba_defend.ts:502) weights the enemy creeps around a
--     threatened building. Its first test, `siege and not upgraded`, was
--     `true and false` = never; its second, `upgraded_mega`, was always true.
--     So EVERY enemy creep near the building scored 0.6 instead of the 0.2 the
--     author wrote for an ordinary creep -- a 3x inflation, and the
--     warlock_golem / lone_druid_bear branches below it were dead code.
--     A four-creep lane wave scored floor(2.4) = 2 "nearby enemies" with no
--     enemy hero present at all.
--   * `WeightedEnemiesAroundLocation` (aba_defend.ts:250), same chain shape:
--     anything in the enemy-hero list that is not a valid non-illusion hero
--     scored 0.6 where the author's chain gives an illusion 0.
--
-- The fix is `.includes()`, which tstl compiles to __TS__StringIncludes -- the
-- nil check happens inside the helper, on a single value. Semantics change
-- from Lua PATTERN matching to PLAIN substring; every call site passes a
-- literal with no magic characters, so no match changes, and plain is the
-- safer default for a name test.
--
-- Note on what this file can and cannot see: the fixture loader answers
-- UNIT_LIST_ENEMIES with `{}` (only ENEMY_HEROES / ALLIED_HEROES are carried),
-- so NO fixture in the repo can exercise a creep-weight chain -- the creeps in
-- test 5/6 below are SYNTHETIC and declared as such. That is the same class of
-- gap as GH #61 / the GetTower one, recorded in test_set.md §0b.

package.path = 'tests/?.lua;' .. package.path

local tests = {}

local TOKEN = 'tests/fixtures/f_260820_043140_wd_defend_token.lua'

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
    BOT_ACTION_DESIRE_NONE     = 0.0,
    BOT_ACTION_DESIRE_VERYLOW  = 0.1,
    BOT_ACTION_DESIRE_LOW      = 0.25,
    BOT_ACTION_DESIRE_MODERATE = 0.5,
    BOT_ACTION_DESIRE_HIGH     = 0.75,
    BOT_ACTION_DESIRE_VERYHIGH = 0.9,
    BOT_ACTION_DESIRE_ABSOLUTE = 1.0,
}

--- Real frame + the real aba_defend / utils modules on top of it.
--- `creeps` (optional) is a list of specs for SYNTHETIC enemy creeps; they are
--- handed to the module through UNIT_LIST_ENEMIES, which is where
--- updateDefendUnitStateCache() reads its enemyCreeps from.
local function world(path, creeps)
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') or k:find('ts_libs') then
            package.loaded[k] = nil
        end
    end
    local rf = require('mock.replay_fixture')
    local api = require('mock.bot_api')
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end
    J.IsSoakCandidate = function() return false end

    if creeps then
        local made = {}
        for i, spec in ipairs(creeps) do
            made[i] = api.MakeUnit({
                GetUnitName = spec.name,
                GetLocation = spec.loc,
                IsCreep = true,
                IsAncientCreep = false,
                IsAlive = true,
                IsNull = false,
                CanBeSeen = true,
                IsBuilding = false,
                IsHero = false,
                IsIllusion = false,
                IsDominated = false,
                HasModifier = false,
                GetTeam = spec.team,
            })
        end
        local prev = GetUnitList
        GetUnitList = function(kind) -- luacheck: ignore
            if kind == UNIT_LIST_ENEMIES then return made end
            return prev(kind)
        end
    end

    GetPushLaneDesire = function() return 0 end     -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end   -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    local Utils = require(GetScriptDirectory() .. '/FunLib/utils')
    return J, bot, heroes, fx, Defend, Utils, api
end

local function dist2d(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

--- The one own tower on this frame that has an enemy hero inside 1600.
local function threatened_own_tower(J, bot)
    local found = nil
    for i = 0, 10 do
        local t = GetTower(bot:GetTeam(), i)
        if t ~= nil and t:IsAlive()
        and #J.GetLastSeenEnemiesNearLoc(t:GetLocation(), 1600) > 0 then
            found = found or t
        end
    end
    return found
end

-- ---------------------------------------------------------------------------
-- 1-3. The predicate itself.
-- ---------------------------------------------------------------------------

tests['a hero is not a lone druid bear'] = function()
    local _, _, _, _, _, Utils, api = world(TOKEN)
    local axe = api.MakeUnit({ GetUnitName = 'npc_dota_hero_axe' })
    assert(Utils.IsUnitWithName(axe, 'lone_druid_bear') == false,
        'IsUnitWithName must answer false when the name does not contain the needle')
    assert(Utils.IsBear(axe) == false,
        'IsBear(axe) must be false -- this is the predicate item_purchase_generic:703 '
        .. 'asks about EVERY hero on EVERY tick')
end

tests['a bear is a lone druid bear'] = function()
    local _, _, _, _, _, Utils, api = world(TOKEN)
    local bear = api.MakeUnit({ GetUnitName = 'npc_dota_lone_druid_bear4' })
    assert(Utils.IsUnitWithName(bear, 'lone_druid_bear') == true,
        'the true case must still be true -- the fix is not "always false"')
    assert(Utils.IsBear(bear) == true, 'IsBear(bear)')
end

tests['FindAllyWithName returns the named ally, not the first one'] = function()
    local _, _, _, _, _, Utils, api = world(TOKEN)
    local first  = api.MakeUnit({ GetUnitName = 'npc_dota_hero_axe',
                                  IsHero = true, IsAlive = true, IsNull = false,
                                  CanBeSeen = true, IsIllusion = false, IsBuilding = false })
    local second = api.MakeUnit({ GetUnitName = 'npc_dota_hero_zuus',
                                  IsHero = true, IsAlive = true, IsNull = false,
                                  CanBeSeen = true, IsIllusion = false, IsBuilding = false })
    local prev = GetUnitList
    GetUnitList = function(kind) -- luacheck: ignore
        if kind == UNIT_LIST_ALLIED_HEROES then return { first, second } end
        return prev(kind)
    end
    local found = Utils.FindAllyWithName('zuus')
    assert(found == second,
        'FindAllyWithName("zuus") must skip the axe -- it returned '
        .. tostring(found and found:GetUnitName()))
    assert(Utils.FindAllyWithName('lich') == nil,
        'and it must answer nil when nobody matches')
end

-- ---------------------------------------------------------------------------
-- 4-6. End to end: what the broken predicate did to a real defend decision.
--
-- REAL FRAME: f_260820_043140_wd_defend_token -- game 20260820_043140_slot1 at
-- t=297.5. Subject witch_doctor (Dire, drafted role 4), full health, 915u from
-- its own 99%-hp mid tier-1 tower, which has exactly ONE enemy hero
-- (death_prophet) inside 1600. On that frame shipped ShouldDefend is false
-- (nNearby == 1 and the {4,5} arbitration hands the token elsewhere -- that is
-- GH #58's subject, not this file's).
--
-- The creeps are synthetic (see the header). What is real is the frame they
-- are placed on and the arithmetic the chain does with them.
-- ---------------------------------------------------------------------------

--- n synthetic creeps of one name, all placed 300u from the tower.
local function wave(tower, n, name)
    local loc = tower:GetLocation()
    local out = {}
    for i = 1, n do
        out[i] = { name = name, team = 3,
                   loc = { x = loc.x + 300, y = loc.y + (i * 10), z = loc.z } }
    end
    return out
end

tests['REAL FRAME: one enemy hero by the tower, and shipped says do not go'] = function()
    local J, bot, heroes, fx, Defend = world(TOKEN)
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(math.abs(fx.time - 297.5) < 1e-6, 'frame is t=297.5; got ' .. tostring(fx.time))
    local tower = threatened_own_tower(J, bot)
    assert(tower ~= nil, 'the frame must carry the subject\'s own towers')
    assert(tower:GetHealth() / tower:GetMaxHealth() > 0.99, 'the tower is untouched')
    local near = J.GetLastSeenEnemiesNearLoc(tower:GetLocation(), 1600)
    assert(#near == 1, 'exactly one enemy hero inside 1600 of it; got ' .. #near)
    local dp = heroes['npc_dota_hero_death_prophet']
    assert(dp ~= nil, 'that enemy is the death prophet')
    assert(dist2d(bot:GetLocation(), tower:GetLocation()) < 1000,
        'the subject is right next to the tower it is deciding about')
    assert(Defend.ShouldDefend(bot, tower, 1600) == false,
        'baseline for the next two tests: with no creeps in the world at all, '
        .. 'this frame does not call the subject to defend')
end

tests['a plain creep wave must not summon a defender by itself'] = function()
    -- The control is measured FIRST: world() rebuilds the shared globals, so a
    -- module handle from an earlier world stops being meaningful once a later
    -- one exists.
    local J, bot, _, _, Defend = world(TOKEN)
    local tower = threatened_own_tower(J, bot)
    local control = Defend.ShouldDefend(bot, tower, 1600)
    assert(control == false, 'control: this frame without creeps')
    -- Four ordinary melee creeps: the author's chain gives each 0.2, so
    -- floor(0.8) = 0 and nNearby is unchanged at 1. The wrapped-multireturn
    -- chain gave each 0.6 -> floor(2.4) = 2 -> nNearby 3, which is the
    -- "three enemies are here" branch and pulls role 4 in.
    local J2, bot2, _, _, Defend2 = world(TOKEN,
        wave(tower, 4, 'npc_dota_creep_badguys_melee'))
    local tower2 = threatened_own_tower(J2, bot2)
    assert(Defend2.ShouldDefend(bot2, tower2, 1600) == control,
        'four ordinary lane creeps changed the answer -- a creep wave is not '
        .. 'three enemy heroes')
end

tests['but the weights still tell creep types apart'] = function()
    -- The fix must not degenerate into "every creep is 0.2", and the branches
    -- BELOW the always-true one were unreachable, not merely mis-weighted.
    -- Two warlock golems are 1.0 each by the author's chain -> floor(2.0) = 2
    -- -> nNearby 3, which does call role 4 in. Under the wrapped-multireturn
    -- chain they were 0.6 each -> floor(1.2) = 1 -> nNearby 2 -> nobody comes.
    -- Same frame, same unit count, different name.
    local J, bot, _, _, Defend = world(TOKEN)
    local tower = threatened_own_tower(J, bot)
    assert(Defend.ShouldDefend(bot, tower, 1600) == false,
        'control: the same frame without them')
    local J2, bot2, _, _, Defend2 = world(TOKEN,
        wave(tower, 2, 'npc_dota_warlock_golem'))
    local tower2 = threatened_own_tower(J2, bot2)
    assert(Defend2.ShouldDefend(bot2, tower2, 1600) == true,
        'two warlock golems at the tower must read as a real threat (1.0 each)')
end

-- ---------------------------------------------------------------------------
-- 7-8. Ratchet. The shape, not this instance of it.
-- ---------------------------------------------------------------------------

--- Every .lua under bots/, as {path, line, text}.
local function bot_lua_lines()
    local out = {}
    local p = io.popen('find bots -name "*.lua" | sort')
    for path in p:lines() do
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            out[#out + 1] = { path = path, n = n, text = line }
        end
    end
    p:close()
    return out
end

tests['RATCHET: no multi-return call is wrapped in a table constructor'] = function()
    -- `{string.find(...)}` and friends: the table is never nil, so every
    -- `~= nil` / truthiness test on it is a constant. Written with the real
    -- generated spacing, including the `({...})` parenthesised form.
    local needles = { 'find', 'gsub', 'match', 'gmatch', 'byte', 'rep' }
    local bad = {}
    for _, l in ipairs(bot_lua_lines()) do
        for _, needle in ipairs(needles) do
            if l.text:find('{%s*string%.' .. needle .. '%s*%(') then
                bad[#bad + 1] = l.path .. ':' .. l.n .. ': ' .. l.text:gsub('^%s+', '')
            end
        end
        if l.text:find('{%s*pcall%s*%(') and not l.text:find('local%s+[%w_]+,') then
            bad[#bad + 1] = l.path .. ':' .. l.n .. ': ' .. l.text:gsub('^%s+', '')
        end
    end
    assert(#bad == 0,
        'a multi-return call wrapped in a table constructor is a constant-true '
        .. 'predicate (GH #51). Fix the TS with .includes()/destructuring:\n  '
        .. table.concat(bad, '\n  '))
end

tests['RATCHET: the TS source cannot regenerate it'] = function()
    -- The Lua is generated; guarding only the Lua would let the next
    -- `npm run build` put it back. `string.find` compared to null, or assigned,
    -- is the TS shape that produces it.
    local bad = {}
    local p = io.popen('find typescript/bots -name "*.ts" | sort')
    for path in p:lines() do
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            local code = line:gsub('^%s*//.*$', '')
            if code:find('string%.find%s*%(')
            and (code:find('!==%s*null') or code:find('===%s*null')
                 or code:find('=%s*string%.find') or code:find('&&%s*string%.find')) then
                bad[#bad + 1] = path .. ':' .. n .. ': ' .. code:gsub('^%s+', '')
            end
            n = n + 0
        end
    end
    p:close()
    assert(#bad == 0,
        'tstl wraps a compared/assigned string.find into a table constructor. '
        .. 'Use `.includes()` for a substring test, or destructure '
        .. '`const [pos] = string.find(...)` when the index is needed:\n  '
        .. table.concat(bad, '\n  '))
end

return tests
