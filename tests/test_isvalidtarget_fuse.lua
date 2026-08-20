-- [GH #64] `J.IsValidTarget` is a detonator with a fuse record; this file is
-- the pin that keeps the record attached to it.
--
-- The defect: `J.IsValidTarget(nTarget)` returns `J.Utils.IsValidHero(nTarget)`
-- -- it is `J.IsValidHero` under a wider-sounding name. 376 call sites read it
-- as "is this a valid target", 287 of them pass `botTarget`
-- (J.GetProperTarget -> bot:GetTarget()/GetAttackTarget()), which is a creep or
-- a building for most of a laning/pushing/roshing game. Every branch written
-- for a NON-hero target is therefore switched off exactly in the situation it
-- was written for (three confirmed: snapfire GobbleUp=='creep',
-- mode_roam tombstone, invoker roshan/boss).
--
-- What this test does NOT do: it does not fix any of that. Widening the
-- delegate would change hundreds of shipped decisions at once -- the `lanefix`
-- shape (locally defensible, aggregate negative). What it does is make the
-- three properties that the cleanup depends on impossible to break silently:
--
--   1. the equivalence is an executable fact, not a claim in a comment
--      (and the narrowing is asserted positively: a creep and a tower are
--      valid UNITS that this predicate rejects -- that IS the defect);
--   2. the fuse record stays next to the delegate, naming the live wires;
--   3. the call-site count is a ratchet -- it may shrink, never grow.
--
-- Ratchet etiquette: when call sites are retired (renamed to J.IsValidHero
-- where the argument is a hero by construction, or fixed as gated behaviour
-- changes), LOWER `CALL_SITE_CEILING` in the same commit. A test that fails
-- because someone added a 377th site is doing its job.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local SOURCE = 'bots/FunLib/jmz_func.lua'
local FUSE_MARK = '[GH #64] FUSE RECORD'

-- Call sites of J.IsValidTarget in bots/, excluding the definition itself.
-- Measured 2026-08-20 at commit ee4eb28. ONLY EVER LOWER THIS.
local CALL_SITE_CEILING = 376

-- Files whose branches are known to be inverted by this gate. The fuse record
-- must keep naming them; the test does not pin line numbers (they drift), it
-- pins that the record names the file and that the file still has a call site.
local LIVE_WIRE_FILES = {
    'bots/BotLib/hero_snapfire.lua',
    'bots/mode_roam_generic.lua',
    'bots/BotLib/hero_invoker.lua',
}

local tests = {}

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_skeleton_king')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func')
end

local function read(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

-- Every lua file under bots/, in a stable order.
local function bot_lua_files()
    local out = {}
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    assert(#out > 0, 'found no lua files under bots/ -- is the cwd the repo root?')
    return out
end

-- { total = N, per_file = { [path] = n } }, comment lines and the definition
-- line excluded (same counting rule as the fuse record's numbers).
local function count_call_sites()
    local total, per_file = 0, {}
    for _, path in ipairs(bot_lua_files()) do
        for line in io.lines(path) do
            local code = line:match('^%s*(.-)%s*$')
            if not code:match('^%-%-') then
                local n = select(2, line:gsub('J%.IsValidTarget%(', ''))
                if code:match('^function%s+J%.IsValidTarget%(') then n = n - 1 end
                if n > 0 then
                    total = total + n
                    per_file[path] = (per_file[path] or 0) + n
                end
            end
        end
    end
    return { total = total, per_file = per_file }
end

-- The synthetic world: one of each thing a call site can be handed.
-- `unit` is the argument, `is_unit` is what IsValidUnit must answer for it.
local function specimens()
    local base = {
        IsNull = false, CanBeSeen = true, IsAlive = true,
        IsInvulnerable = false, IsIllusion = false, IsBuilding = false,
    }
    local function unit(over)
        local spec = {}
        for k, v in pairs(base) do spec[k] = v end
        for k, v in pairs(over or {}) do spec[k] = v end
        return api.MakeUnit(spec)
    end
    return {
        { name = 'a living enemy hero',
          unit = unit({ IsHero = true, GetUnitName = 'npc_dota_hero_lion' }),
          is_unit = true, is_hero = true },
        { name = 'a lane creep',
          unit = unit({ IsHero = false, IsCreep = true,
                        GetUnitName = 'npc_dota_creep_lane' }),
          is_unit = true, is_hero = false },
        { name = 'a standing tower',
          unit = unit({ IsHero = false, IsBuilding = true,
                        GetUnitName = 'npc_dota_badguys_tower1_mid' }),
          is_unit = true, is_hero = false },
        { name = 'roshan',
          unit = unit({ IsHero = false, GetUnitName = 'npc_dota_roshan' }),
          is_unit = true, is_hero = false },
        { name = 'a dead hero',
          unit = unit({ IsHero = true, IsAlive = false,
                        GetUnitName = 'npc_dota_hero_lion' }),
          is_unit = false, is_hero = false },
        { name = 'nil', unit = nil, is_unit = false, is_hero = false },
    }
end

----------------------------------------------------------------------
-- 1. the equivalence, as an executable fact
----------------------------------------------------------------------

tests['J.IsValidTarget answers exactly what J.IsValidHero answers'] = function()
    local J = fresh_jmz()
    for _, s in ipairs(specimens()) do
        local target = J.IsValidTarget(s.unit)
        local hero = J.IsValidHero(s.unit)
        assert(target == hero, string.format(
            'IsValidTarget/IsValidHero disagree on %s (%s vs %s) -- if this is '
            .. 'deliberate, the fuse record in %s is now the checklist you owe '
            .. 'the reviewer (GH #64)',
            s.name, tostring(target), tostring(hero), SOURCE))
        assert(target == s.is_hero, string.format(
            'IsValidTarget(%s) == %s, expected %s',
            s.name, tostring(target), tostring(s.is_hero)))
    end
end

tests['the predicate is strictly narrower than IsValidUnit -- the defect itself']
= function()
    local J = fresh_jmz()
    local narrowed = 0
    for _, s in ipairs(specimens()) do
        assert(J.Utils.IsValidUnit(s.unit) == s.is_unit, string.format(
            'IsValidUnit(%s) == %s, expected %s -- the specimen, not the '
            .. 'predicate, is probably wrong',
            s.name, tostring(J.Utils.IsValidUnit(s.unit)), tostring(s.is_unit)))
        if s.is_unit and not s.is_hero then
            narrowed = narrowed + 1
            assert(J.IsValidTarget(s.unit) == false, string.format(
                '%s is a valid unit that IsValidTarget accepted -- the delegate '
                .. 'has been widened; walk the fuse record in %s before this '
                .. 'ships (GH #64)', s.name, SOURCE))
        end
    end
    assert(narrowed >= 3, 'expected creep/tower/roshan specimens to exercise '
        .. 'the narrowing, got ' .. narrowed)
end

tests['the delegate in source still reads IsValidHero'] = function()
    local body = read(SOURCE):match(
        'function%s+J%.IsValidTarget%s*%(.-%)(.-)\nend')
    assert(body, 'cannot find function J.IsValidTarget in ' .. SOURCE)
    local code = {}
    for line in body:gmatch('[^\n]+') do
        local stripped = line:match('^%s*(.-)%s*$')
        if not stripped:match('^%-%-') and stripped ~= '' then
            code[#code + 1] = stripped
        end
    end
    assert(#code == 1 and code[1] == 'return J.Utils.IsValidHero(nTarget)',
        'the delegate changed. That is the one edit the fuse record in '
        .. SOURCE .. ' exists for: it arms every branch listed there plus the '
        .. '287 unread botTarget sites. Update the record and this test '
        .. 'together, never the delegate alone (GH #64). Body was: '
        .. table.concat(code, ' | '))
end

----------------------------------------------------------------------
-- 2. the fuse record stays attached
----------------------------------------------------------------------

tests['the fuse record sits with the delegate and names the live wires']
= function()
    local src = read(SOURCE)
    local mark = src:find(FUSE_MARK, 1, true)
    assert(mark, 'the fuse record is gone from ' .. SOURCE .. '. It is the only '
        .. 'record of what switching the delegate would set off; the NOTE it '
        .. 'replaced left none, which is how GH #64 stayed invisible for years.')
    local def = src:find('function J.IsValidTarget(', 1, true)
    assert(def and mark < def and (def - mark) < 2500,
        'the fuse record must sit immediately above function J.IsValidTarget '
        .. '-- a record the next editor does not see is not a record')

    for _, path in ipairs(LIVE_WIRE_FILES) do
        assert(src:find(path, 1, true), string.format(
            'the fuse record no longer names %s. If that branch was fixed, drop '
            .. 'it from the record AND from LIVE_WIRE_FILES here, in the same '
            .. 'commit (GH #64).', path))
        local counts = count_call_sites()
        assert((counts.per_file[path] or 0) > 0, string.format(
            '%s is named as a live wire but has no J.IsValidTarget call left -- '
            .. 'the record is stale', path))
    end
end

----------------------------------------------------------------------
-- 3. the ratchet
----------------------------------------------------------------------

tests['the J.IsValidTarget call-site count only ever shrinks'] = function()
    local counts = count_call_sites()
    if counts.total > CALL_SITE_CEILING then
        local worst, n = nil, 0
        for path, c in pairs(counts.per_file) do
            if c > n then worst, n = path, c end
        end
        error(string.format(
            'J.IsValidTarget now has %d call sites, ceiling is %d. This '
            .. 'predicate means "is a valid HERO" -- a new call site is a new '
            .. 'branch that is off whenever its target is a creep, a tower or '
            .. 'roshan. Use J.IsValidHero (says what it does) or J.Utils.'
            .. 'IsValidUnit (if you really mean any unit). Heaviest file: %s '
            .. '(%d). See GH #64.', counts.total, CALL_SITE_CEILING, worst, n))
    end
    -- A ceiling that drifts far above reality stops catching anything; keep it
    -- honest by requiring the cleanup commit to lower it.
    assert(counts.total >= CALL_SITE_CEILING, string.format(
        'call sites dropped to %d (ceiling %d) -- good, now lower '
        .. 'CALL_SITE_CEILING to %d in this same commit so the ratchet keeps '
        .. 'its grip', counts.total, CALL_SITE_CEILING, counts.total))
end

return tests
