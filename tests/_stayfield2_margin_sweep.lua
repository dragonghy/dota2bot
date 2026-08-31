-- Corpus sweep helper for tests/test_stayfield2_marginal_domain.lua.
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$', and
-- this file is meant to be run in its own process by that test via io.popen --
-- same reason as tests/_stayfield_walk_sweep.lua (charter 0q: driving the whole
-- corpus through a shipped file inside the suite's own process makes the cost
-- depend on where the caller lands in the alphabet).
--
-- WHAT IT COUNTS. At the `stayfield2` call site (mode_retreat_generic
-- GetDesireHelper) the promoted, ungated veto J.ShouldStayAndRegen returns
-- BOT_MODE_DESIRE_NONE one statement earlier. So the frames `stayfield2` can
-- still change are S and not T, where
--
--     S = J.ShouldRegenNotGoHome( bot )     -- the gated predicate
--     T = J.ShouldStayAndRegen( bot )       -- the promoted absorber
--
-- and this sweep measures, on every LIVE hero of every fixture driven as its
-- own subject, the 2x2 (S, T) plus -- for the S frames -- WHICH clause of T
-- failed. The calling test turns the clause counts into the closed form.
--
-- Every hero is driven as subject, not only fixture.self: the charter (0P2 (b))
-- records that the self-only sweep had 100 subject frames and could not measure
-- a frequency at all, while the all-heroes sweep has ~900.
--
-- Usage: lua5.1 tests/_stayfield2_margin_sweep.lua
-- Emits machine-readable lines on stdout:
--   COUNT frames=<n> S=<n> T=<n> ST=<n> margin=<n>
--   CLAUSE dmg=<n> supply=<n> both=<n> neither=<n>
--   HPBAND s_above55=<n> t_in_55_75=<n>
--   RING mono_checked=<n> mono_violations=<n>
--   BAGSALVE bag_frames=<n> margin_without=<n> margin_with=<n>
--   BID s_frames=<n> moved=<n> moved_in_margin=<n> moved_in_absorbed=<n>
--   SIGN subsample=<n> natural_neg=<n> natural_zero=<n> natural_pos=<n> margin_neg=<n> margin_pos=<n>
--   FRAME <fixture> <hero> S=<0|1> T=<0|1> dmg=<0|1> supply=<0|1> hp=<f> bid_off=<x> bid_on=<x>

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files +1] = f end
    end
    p:close()
    table.sort(files)
    return files
end

--- The fixture's own declared subject, keyed by file. That is the slice the
--- sibling sweep drives, and it is fixed by the corpus, not by any reading.
local self_of = {}

--- Hero names carried by one fixture, read off the raw table so the loader is
--- not asked for a subject it will reject.
local function hero_names(path)
    local fx = dofile('tests/fixtures/' .. path)
    self_of[path] = fx.self
    local out = {}
    for _, u in ipairs(fx.units or {}) do
        if type(u.name) == 'string' and u.name:match('^npc_dota_hero_') then
            out[#out + 1] = u.name
        end
    end
    return out
end

--- Install one fixture with one hero as the subject, in the HONEST turbo world
--- (GH #93 / the fifteenth world assertion: by name the fixture world is Turbo,
--- by the literal 23 it is not, and both S and T open with IsModeTurbo).
local function world(path, subject, armed)
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load('tests/fixtures/' .. path, subject)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    J.IsSoakCandidate = function(id)
        if armed == nil then return false end
        for a in tostring(armed):gmatch('[^,]+') do
            if a == id then return true end
        end
        return false
    end
    return J, bot
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

local RETREAT = 'bots/mode_retreat_generic.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, so a desire
-- comparison without these is a comparison of garbage (test_set.md §F).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

--- Declarations the retreat mode needs before it can be driven at all; the same
--- set (and the same reasons) as tests/_stayfield_walk_sweep.lua.
local function declare_world(J)
    for k, v in pairs(DESIRE) do _G[k] = v end
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    J.Utils['GameStates'] = J.Utils['GameStates'] or {}
    J.Utils['GameStates']['defendPings'] = { pingedTime = -1000 }
end

-- Compiled ONCE. `dofile` re-parses the 1,087-line mode file on every call, and
-- this sweep drives it ~1,000 times; the chunk still has to be re-EXECUTED per
-- world (its top-level `local bot = GetBot()` and its `require`s are per-world
-- state, and rf.load resets the module cache), which is what calling the
-- compiled chunk does. Same semantics as dofile, without the parse.
local RETREAT_CHUNK = assert(loadfile(RETREAT))

local function retreat_bid()
    GetDesire, Think = nil, nil -- luacheck: ignore
    local ok = pcall(RETREAT_CHUNK)
    local out = 'CRASH'
    if ok and type(GetDesire) == 'function' then
        local ok2, d = pcall(GetDesire)
        if ok2 and type(d) == 'number' then out = d end
    end
    GetDesire, Think = nil, nil -- luacheck: ignore
    return out
end

local nFrames, nS, nT, nST, nMargin = 0, 0, 0, 0, 0
local cDmg, cSupply, cBoth, cNeither = 0, 0, 0, 0
local nSAbove55, nTin5575 = 0, 0
local nMono, nMonoBad = 0, 0
local nMargin2 = 0
local nBagFrames, nBagMarginWithout, nBagMarginWith = 0, 0, 0
local nBidMoved, nBidMovedMargin, nBidMovedAbsorbed = 0, 0, 0
local nSubsample, nNatNeg, nNatZero, nNatPos = 0, 0, 0, 0
local nMarginNeg, nMarginPos = 0, 0
local frames = {}

for _, path in ipairs(fixture_files()) do
    for _, hero in ipairs(hero_names(path)) do
        local ok, err = pcall(function()
            local J, bot = world(path, hero, 'stayfield2')
            if bot == nil or not bot:IsAlive() then return end
            nFrames = nFrames + 1

            local S = J.ShouldRegenNotGoHome(bot) == true
            local T = J.ShouldStayAndRegen(bot) == true
            if S then nS = nS + 1 end
            if T then nT = nT + 1 end
            if S and T then nST = nST + 1 end
            if S and not T then nMargin = nMargin + 1 end

            if S then
                local bDmg, bSupply = t_clauses(J, bot)
                -- T false <=> bDmg or not bSupply (given S implies the other
                -- three clauses); count which side did it.
                if bDmg and not bSupply then cBoth = cBoth + 1
                elseif bDmg then cDmg = cDmg + 1
                elseif not bSupply then cSupply = cSupply + 1
                else cNeither = cNeither + 1 end
            end

            -- The HP-band half of the implication, measured rather than
            -- assumed: no S frame may sit above 0.55, and the band T owns
            -- alone is (0.55, 0.75].
            local nHP = J.GetHP(bot)
            if S and nHP > 0.55 then nSAbove55 = nSAbove55 + 1 end
            if T and nHP > 0.55 and nHP <= 0.75 then nTin5575 = nTin5575 + 1 end

            -- The ring half: 1600 empty must imply 1200 empty. Monotonicity in
            -- the radius is a property of the shipped selector, not an axiom.
            local n16 = #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
            local n12 = #J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
            nMono = nMono + 1
            if n12 > n16 then nMonoBad = nMonoBad + 1 end

            -- bagsalve as a reachability CREATOR at this site: a backpacked
            -- salve makes HasFieldRegenSource true while IsItemAvailable
            -- (slots 0-5) stays nil, so the supply clause of T can still fail.
            if S and not T then nMargin2 = nMargin2 + 1 end

            -- ⭐ THE SIGN CENSUS. mode_retreat_generic ends
            -- `return Min(nDesire, 1.0)` -- clamped ABOVE, never below, while
            -- two subtractions inside (-0.25 "nobody around", -0.75 "laning
            -- phase and unhurt") can drive it under zero. So the natural bid of
            -- this mode is a SIGNED quantity, and every guard above it that
            -- early-outs with the constant BOT_MODE_DESIRE_NONE (0.0) RAISES
            -- the bid on any frame whose natural value is negative. Counted for
            -- the whole live population, not just the S frames, because that is
            -- the number that says whether the shape is marginal or general.
            --
            -- ONE world load per frame, deliberately. Off the S frames the
            -- armed and unarmed worlds bid IDENTICALLY -- the gated call is the
            -- only difference and it returns the same false in both -- so the
            -- armed drive IS the natural bid there. The 23 S frames pay for
            -- their own second load below. (Cost, measured: reloading the
            -- fixture for all 993 pushed this sweep past ten minutes, which is
            -- the budget GH #358 is about.)
            -- Driven on TWO populations, and the difference is declared:
            --   * every S frame (all 23) -- the set this id can act on;
            --   * plus, for the population shape, the fixture's OWN subject
            --     (`hero == fx.self`) on every fixture -- the ~107-frame slice
            --     tests/_stayfield_walk_sweep.lua already uses, chosen before
            --     any reading was taken and not filtered by anything measured
            --     here.
            -- Driving the bid for all 993 costs >10 minutes, which is the
            -- suite budget GH #358 is about; the subsample is the honest
            -- version of that trade, declared rather than quietly taken.
            local bSubsample = (hero == self_of[path])
            local bidOff, bidOn, natural

            if S or bSubsample then
                declare_world(J)
                bidOn = retreat_bid()
                natural = bidOn
            end

            if S then
                local J2, bot2 = world(path, hero, nil)
                declare_world(J2)
                bidOff = retreat_bid()
                natural = bidOff
                local bMoved = tostring(bidOn) ~= tostring(bidOff)
                if bMoved then
                    nBidMoved = nBidMoved + 1
                    if T then nBidMovedAbsorbed = nBidMovedAbsorbed + 1
                    else nBidMovedMargin = nBidMovedMargin + 1 end
                end
                frames[#frames + 1] = string.format(
                    'FRAME %s %s S=1 T=%d dmg=%d supply=%d hp=%.4f bid_off=%s bid_on=%s',
                    path, hero, T and 1 or 0,
                    (select(1, t_clauses(J2, bot2))) and 1 or 0,
                    (select(2, t_clauses(J2, bot2))) and 1 or 0,
                    nHP, tostring(bidOff), tostring(bidOn))
            end

            if bSubsample and type(natural) == 'number' then
                nSubsample = nSubsample + 1
                if natural < 0 then nNatNeg = nNatNeg + 1
                elseif natural == 0 then nNatZero = nNatZero + 1
                else nNatPos = nNatPos + 1 end
            end
            if S and not T and type(natural) == 'number' then
                if natural < 0 then nMarginNeg = nMarginNeg + 1
                elseif natural > 0 then nMarginPos = nMarginPos + 1 end
            end
        end)
        if not ok then io.write('ERR ' .. path .. ' ' .. hero .. ' ' .. tostring(err) .. '\n') end
        unprobe()

        -- The bagsalve leg is driven ONLY where it can possibly differ: the
        -- widening reads slots 6-8 for a salve and nothing else, so a frame
        -- with no backpacked salve answers identically armed or not. Cheap
        -- pre-filter, then a real drive on the survivors -- not a model of one.
        local ok2, err2 = pcall(function()
            local J, bot = world(path, hero, nil)
            if bot == nil or not bot:IsAlive() then return end
            local bBagSalve = false
            for i = 6, 8 do
                local hItem = bot:GetItemInSlot(i)
                if hItem ~= nil and hItem:GetName() == 'item_flask' then bBagSalve = true end
            end
            if not bBagSalve then return end
            nBagFrames = nBagFrames + 1
            local Jw, botw = world(path, hero, 'stayfield2')
            if Jw.ShouldRegenNotGoHome(botw) == true
                and Jw.ShouldStayAndRegen(botw) ~= true
            then
                nBagMarginWithout = nBagMarginWithout + 1
            end
            local J2, bot2 = world(path, hero, 'stayfield2,bagsalve')
            if J2.ShouldRegenNotGoHome(bot2) == true
                and J2.ShouldStayAndRegen(bot2) ~= true
            then
                nBagMarginWith = nBagMarginWith + 1
            end
            local _ = J
        end)
        if not ok2 then io.write('ERR2 ' .. path .. ' ' .. hero .. ' ' .. tostring(err2) .. '\n') end
        unprobe()
    end
end

io.write(string.format('COUNT frames=%d S=%d T=%d ST=%d margin=%d\n',
    nFrames, nS, nT, nST, nMargin))
io.write(string.format('CLAUSE dmg=%d supply=%d both=%d neither=%d\n',
    cDmg, cSupply, cBoth, cNeither))
io.write(string.format('HPBAND s_above55=%d t_in_55_75=%d\n', nSAbove55, nTin5575))
io.write(string.format('RING mono_checked=%d mono_violations=%d\n', nMono, nMonoBad))
io.write(string.format('BAGSALVE bag_frames=%d margin_without=%d margin_with=%d\n',
    nBagFrames, nBagMarginWithout, nBagMarginWith))
assert(nMargin2 == nMargin, 'internal: the margin was counted twice and disagreed')
io.write(string.format('BID s_frames=%d moved=%d moved_in_margin=%d moved_in_absorbed=%d\n',
    nS, nBidMoved, nBidMovedMargin, nBidMovedAbsorbed))
io.write(string.format(
    'SIGN subsample=%d natural_neg=%d natural_zero=%d natural_pos=%d margin_neg=%d margin_pos=%d\n',
    nSubsample, nNatNeg, nNatZero, nNatPos, nMarginNeg, nMarginPos))
for _, l in ipairs(frames) do io.write(l .. '\n') end
