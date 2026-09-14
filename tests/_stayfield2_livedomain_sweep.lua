-- Corpus sweep helper for tests/test_stayfield2_live_domain.lua.
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$', and
-- this file is meant to be run in its own process by that test via io.popen --
-- same reason as tests/_stayfield2_margin_sweep.lua.
--
-- ⭐ WHAT IS NEW HERE, and it is one word: WHICH STRING.
--
-- tests/test_stayfield2_marginal_domain.lua established the closed form
--
--     margin( stayfield2 ) = S and not T = S and ( not T3 or not T5 )
--
-- with S = J.ShouldRegenNotGoHome, T = J.ShouldStayAndRegen. That reading was
-- taken in a world where the ONLY armed id was 'stayfield2' itself. Today's
-- member string (iterations/streams/test_set.md) carries 26 ids, and two of
-- them sit INSIDE that closed form:
--
--   * 'fieldsip' is a clause of S. Unarmed, J.IsFieldSipEnough returns the
--     literal `true` and S is the three-clause predicate the closed form was
--     derived from. ARMED, it adds a MAGNITUDE test (the drinkable in the bag
--     must be worth >= J.FIELD_SIP_MIN_FRACTION of max HP), so S gets STRICTLY
--     harder and the margin can only shrink.
--   * 'staytower' is a clause of T (added 2026-09-06), and it is NOT armed
--     today. Unarmed, T loses its "no enemy tower within 1200" requirement, so
--     T gets strictly EASIER -- it absorbs more -- and again the margin can
--     only shrink.
--
-- Both live ids push the SAME way. So the question this sweep buys is not
-- "what is the closed form" (that is settled) but "how much of that domain is
-- left on the string the waves actually fly", and it is a question no reading
-- taken on a single-id world can answer.
--
-- ⛔ THE ERROR SHAPE THIS IS AN INSTANCE OF (charter 0NEXT10 / GH #277): a rate
-- measured on the wrong population. There the wrong population was the corpus
-- (whole-corpus pass rate standing in for a domain-conditional one); here it is
-- the WORLD (a single-id arm standing in for the live member string). Same
-- defect, different axis, and neither is visible from the reading itself.
--
-- Usage: lua5.1 tests/_stayfield2_livedomain_sweep.lua '<armed csv>'
-- Emits machine-readable lines on stdout:
--   ARMED n=<n> md5ish=<len>
--   SOLO   frames=<n> S=<n> T=<n> margin=<n>
--   LIVE   frames=<n> S=<n> T=<n> margin=<n>
--   DELTA  s_lost=<n> t_gained=<n> margin_lost=<n>
--   WHYS   sip_killed=<n> other=<n>
--   WHYT   tower_only=<n> other=<n>
--   CLAUSE_LIVE dmg=<n> supply=<n> both=<n> neither=<n>
--   FRAME <fixture> <hero> solo_S=<0|1> solo_T=<0|1> live_S=<0|1> live_T=<0|1> hp=<f>

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local ARMED_CSV = ...
assert(type(ARMED_CSV) == 'string' and ARMED_CSV ~= '',
    'usage: lua5.1 tests/_stayfield2_livedomain_sweep.lua "<armed csv>"')

local function split(csv)
    local out = {}
    for a in tostring(csv):gmatch('[^,]+') do out[#out + 1] = a end
    return out
end

local ARMED_LIVE = split(ARMED_CSV)

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = f end
    end
    p:close()
    table.sort(files)
    return files
end

local function hero_names(path)
    local fx = dofile('tests/fixtures/' .. path)
    local out = {}
    for _, u in ipairs(fx.units or {}) do
        if type(u.name) == 'string' and u.name:match('^npc_dota_hero_') then
            out[#out + 1] = u.name
        end
    end
    return out
end

--- Install one fixture with one hero as the subject, in the HONEST turbo world
--- (GH #93: by name the fixture world is Turbo, by the literal 23 it is not,
--- and both S and T open with IsModeTurbo).
local function world(path, subject)
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load('tests/fixtures/' .. path, subject)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    return J, bot
end

--- ⭐ ONE LOAD, TWO WORLDS. The solo and live worlds differ in NOTHING but the
--- gate closure -- `world()` used to take the arm list only to install this
--- function, and every predicate below reads it at CALL time. So re-pointing
--- `J.IsSoakCandidate` between two readings gives the same two worlds as two
--- `rf.load` calls, at half the fixture-loading cost. MEASURED, end to end
--- through the calling test on this container: 177s -> 45s. That matters
--- because the calling test is tagged [detector] and therefore runs inside
--- 开工自检's Lua leg, whose budget is 120s FOR THE WHOLE LEG -- a 177s member
--- is not a slow test, it is a leg that stops certifying anything (the leg was
--- already reporting UNCERTIFIABLE on timeout when this landed).
---
--- ⚠️ IT IS AN ASSUMPTION THAT THIS IS EQUIVALENT, and the assumption is that
--- nothing between load and call MEMOISES a gate answer. It is NOT asserted by
--- comment: every number here was first taken by the two-load implementation,
--- and the one-load version reproduces the whole of stdout -- all seven counter
--- lines AND all 24 per-frame lines -- BYTE-IDENTICALLY (`diff` clean, 2026-09-14).
--- If a helper ever starts caching its gate, that equality is what breaks, and
--- it breaks loudly in the calling test.
local function arm(J, armed_list)
    local set = {}
    for _, a in ipairs(armed_list) do set[a] = true end
    J.IsSoakCandidate = function(id) return set[id] == true end
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- The two clauses of J.ShouldStayAndRegen that IsFieldRegenSituation does NOT
--- imply, evaluated with the SAME operands the shipped helper uses.
local function t_clauses(J, bot)
    local bDmg = bot:WasRecentlyDamagedByAnyHero(3.0) == true
    local bHasFlask = J.IsItemAvailable('item_flask') ~= nil
        or bot:HasModifier('modifier_flask_healing')
        or bot:HasModifier('modifier_tango_heal')
    local bSupply = bHasFlask or bot:GetGold() >= 90
    return bDmg, bSupply
end

local SOLO = { 'stayfield2' }

local nFrames = 0
local sS, sT, sM = 0, 0, 0
local lS, lT, lM = 0, 0, 0
local dSlost, dTgain, dMlost = 0, 0, 0
local wSip, wSother = 0, 0
local wTtower, wTother = 0, 0
local cDmg, cSupply, cBoth, cNeither = 0, 0, 0, 0
local frames = {}

for _, path in ipairs(fixture_files()) do
    for _, hero in ipairs(hero_names(path)) do
        local ok, err = pcall(function()
            local Js, bots_ = world(path, hero)
            if bots_ == nil or not bots_:IsAlive() then return end
            nFrames = nFrames + 1
            arm(Js, SOLO)

            local S0 = Js.ShouldRegenNotGoHome(bots_) == true
            local T0 = Js.ShouldStayAndRegen(bots_) == true
            local nHP = Js.GetHP(bots_)
            if S0 then sS = sS + 1 end
            if T0 then sT = sT + 1 end
            if S0 and not T0 then sM = sM + 1 end

            -- The SITUATION half of S, read in the solo world: it carries no
            -- gate of its own, so it is the part of S that 'fieldsip' cannot
            -- touch. S0 and not S1 with situation still true <=> the magnitude
            -- clause is what killed it.
            local sit0 = Js.IsFieldRegenSituation(bots_) == true

            local Jl, botl = Js, bots_
            arm(Jl, ARMED_LIVE)
            local S1 = Jl.ShouldRegenNotGoHome(botl) == true
            local T1 = Jl.ShouldStayAndRegen(botl) == true
            if S1 then lS = lS + 1 end
            if T1 then lT = lT + 1 end
            if S1 and not T1 then lM = lM + 1 end

            if S0 and not S1 then
                dSlost = dSlost + 1
                -- Attribute: did the magnitude clause do it, or something else?
                local sipOK = Jl.IsFieldSipEnough(botl) == true
                if sit0 and not sipOK then wSip = wSip + 1 else wSother = wSother + 1 end
            end
            if T1 and not T0 then
                dTgain = dTgain + 1
                -- 'staytower' is armed in SOLO? no -- it is armed in neither
                -- list unless the live string carries it. The only clause that
                -- can differ here is the gated tower one, so attribute by
                -- asking whether a tower is inside 1200 at all.
                local nTow = #botl:GetNearbyTowers(1200, true)
                if nTow > 0 then wTtower = wTtower + 1 else wTother = wTother + 1 end
            end
            if (S0 and not T0) and not (S1 and not T1) then dMlost = dMlost + 1 end

            if S1 and not T1 then
                local bDmg, bSupply = t_clauses(Jl, botl)
                if bDmg and not bSupply then cBoth = cBoth + 1
                elseif bDmg then cDmg = cDmg + 1
                elseif not bSupply then cSupply = cSupply + 1
                else cNeither = cNeither + 1 end
            end

            if S0 or S1 then
                frames[#frames + 1] = string.format(
                    'FRAME %s %s solo_S=%d solo_T=%d live_S=%d live_T=%d hp=%.4f',
                    path, hero, S0 and 1 or 0, T0 and 1 or 0,
                    S1 and 1 or 0, T1 and 1 or 0, nHP)
            end
        end)
        if not ok then io.write('ERR ' .. path .. ' ' .. hero .. ' ' .. tostring(err) .. '\n') end
        unprobe()
    end
end

io.write(string.format('ARMED n=%d md5ish=%d\n', #ARMED_LIVE, #ARMED_CSV))
io.write(string.format('SOLO   frames=%d S=%d T=%d margin=%d\n', nFrames, sS, sT, sM))
io.write(string.format('LIVE   frames=%d S=%d T=%d margin=%d\n', nFrames, lS, lT, lM))
io.write(string.format('DELTA  s_lost=%d t_gained=%d margin_lost=%d\n', dSlost, dTgain, dMlost))
io.write(string.format('WHYS   sip_killed=%d other=%d\n', wSip, wSother))
io.write(string.format('WHYT   tower_only=%d other=%d\n', wTtower, wTother))
io.write(string.format('CLAUSE_LIVE dmg=%d supply=%d both=%d neither=%d\n',
    cDmg, cSupply, cBoth, cNeither))
for _, l in ipairs(frames) do io.write(l .. '\n') end
