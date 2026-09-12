-- [arbheart] Does the host mode even BID on arbheart's own pinned frame?
--
-- WHY THIS FILE EXISTS.  GH #775 (replay-check, 2026-09-12) reported that the
-- release predicate of soak candidate `arbheart` is condition-for-condition
-- equivalent to the shipped anti-steal guard that sits on the jungle-camp
-- desire branch, and that the shipped guard answers FIRST and answers
-- `BOT_MODE_DESIRE_NONE` -- it removes the mode `arbheart` is parasitic on.
-- #775 §3 then bounds that finding: the guard sits on ONE branch, so the
-- domain is NARROWED, not empty, and #775 §6 asks for a fixture on a BYPASS
-- exit (a positive bid that never consults the guard) as the only satisfiable
-- form of the acceptance sentence in
-- `state.json:arbheart_retire_20260903.next_baton`.
--
-- WHAT THIS FILE MEASURED, and it is one layer above what #775 asked about.
-- On arbheart's own pinned frame the host mode bids NONE through EVERY exit,
-- and the guard #775 names is never reached at all: control stops one
-- conjunct earlier, at `J.Site.IsTimeToFarm(bot)` (mode_farm_generic.lua:502),
-- which for this subject is false BY ROLE, not by geometry --
-- crystal_maiden is the fixture's own drafted position 5, has no
-- `ConsiderIsTimeToFarm` entry among the 74 heroes that have one, and so fails
-- both of that function's two ways to say yes.  The other nine positive-desire
-- exits (ten in total, counted off the source in [read R2]) are closed
-- for their own reasons (arc-warden clone / meepo clone / a hand of midas she
-- does not carry / core-or-late-game-or-level-18, and she is a level-15
-- support).  Measured, not argued: the line trace below records every line of
-- `mode_farm_generic.lua` the frame executes, and the last one inside
-- `GetDesireHelper` is its terminal `return BOT_MODE_DESIRE_NONE`.
--
-- WHY THAT MATTERS FOR THE VERDICT.  All three existing arbheart files
-- (`test_arbheart_farm_camp_heartbeat.lua`, `test_arbheart_release_retires_camp.lua`,
-- `test_arbheart_repick_relatch.lua`) call `Think()` directly on this world.
-- In game `Think()` runs only for the mode that won `GetDesire()`, and on this
-- frame this mode bids zero -- so every reading arbheart carries was taken on
-- a tick the engine would not have run.  That is not a claim that the gate is
-- broken; it is the price of its (a) evidence, and until now it was unpriced.
--
-- THE OTHER HALF: the mechanism is fine once a bid exists.  Section C restores
-- a positive bid through the bypass exit #775 §6 names and drives the full
-- heartbeat: armed, the camp an ally holds is released AND retired on a tick
-- whose own `GetDesire()` is 0.45; unarmed the table is untouched.  Guard A is
-- not consulted on that path -- which is the sharp form of #775's boundary:
-- on the exits that can bid, the guard never runs; on the exit the guard sits
-- on, the bid is already dead.
--
-- LIMITS (declared, not engineered around).
--  L1. Section C is a CONSTRUCTION and is named as one.  Two things are
--      supplied that this frame cannot answer:
--      (a) lane-front coordinates -- the loader REFUSES `GetLaneFrontLocation`
--          (GH #61) and tells the caller to declare them; the values below are
--          declared and their enemy-count consequence is asserted, not assumed;
--      (b) `J.Site.IsTimeToFarm` forced true for a position-5 support, which
--          the shipped role gate says cannot happen for her.  So section C
--          witnesses the MECHANISM on a real frame, never the frequency.  The
--          frequency question stays where #775 §6 route 2 put it: the dumper
--          carries no mode field.
--  L2. `J.IsFarming` is mocked to name spirit_breaker, exactly as the three
--      sibling files do -- the fixture carries positions, not mode state.
--  L3. Roles read off the fixture are trustworthy only for the subject's own
--      team: `aba_role.GetPosition` answers from `assignedRole` for dire (which
--      the fixture supplies for all ten heroes) and falls through to a slot
--      default for radiant.  Every role assertion below is therefore restricted
--      to dire, and that restriction is asserted rather than assumed.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua'
local SOURCE  = 'bots/mode_farm_generic.lua'

-- The ancient frog camp centre (GH #455 §1, off the frame's own `creeps[]`).
local CAMP_X_LOC = { -592.9, 4840.6 }
-- A second camp far from every hero on the frame, so a correct retire leaves
-- something behind: an empty table cannot tell "retired the right one" from
-- "retired everything".
local CAMP_Y_LOC = { -8000.0, -8000.0 }

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

-- Declared lane fronts (L1a).  Two of the three are parked in map corners so
-- the early-game lane scan can find a lane with no enemy within 1400u; the
-- assertion in [C1] reads that consequence off the frame instead of trusting
-- the choice.
local LANE_FRONTS = {
    [1] = { -6000, 5000 },
    [2] = { 0, 0 },
    [3] = { 6000, -5000 },
}

-- opts.subject     -> load a different roster hero as the bot (default CM)
-- opts.armed       -> arm 'arbheart'
-- opts.ally_farms  -> J.IsFarming names spirit_breaker (default true)
-- opts.lane_fronts -> declare GetLaneFrontLocation (L1a)
-- opts.force_farm  -> force J.Site.IsTimeToFarm true (L1b)
-- opts.source      -> load this Lua source text instead of the shipped file
local function world(opts)
    opts = opts or {}
    local J, bot, heroes = rf.load(FIXTURE, opts.subject or 'npc_dota_hero_crystal_maiden')
    for k, v in pairs(DESIRE) do _G[k] = v end

    local dota = require(GetScriptDirectory() .. '/ts_libs/dota/index')
    for _, h in pairs(heroes) do
        -- Same setting the sibling files use: the dumper carries no mode, and
        -- Farm is the value most favourable to exclusion inside IsTheClosestOne.
        h.GetActiveMode = function() return dota.BotMode.Farm end
    end

    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id)
        if id == 'arbheart' then return opts.armed == true end
        return false                      -- slotarb in particular stays OFF
    end

    local sb = heroes['npc_dota_hero_spirit_breaker']
    assert(sb, 'setup: spirit_breaker missing from the fixture roster')
    J.IsFarming = function(who)           -- L2
        if opts.ally_farms == false then return false end
        return who == sb
    end
    J.IsCampSwitchSafe = function() return true end

    local CAMP_X = { cattr = { location = api.Vector(CAMP_X_LOC[1], CAMP_X_LOC[2], 0) } }
    local CAMP_Y = { cattr = { location = api.Vector(CAMP_Y_LOC[1], CAMP_Y_LOC[2], 0) } }

    J.Role = J.Role or {}
    J.Role['availableCampTable'] = { CAMP_X, CAMP_Y }
    -- Left real on purpose: UpdateAvailableCamp, GetClosestNeutralSpwan,
    -- IsTheClosestOne, IsTimeToFarm (unless opts.force_farm).
    J.Site.FilterFarmNeutrals = function(t) return t or {} end
    J.Site.GetFarmLaneTarget = function() return nil end
    J.Site.FindFarmNeutralTarget = function() return nil end
    J.Site.IsModeSuitableToFarm = function() return true end
    if opts.force_farm then
        J.Site.IsTimeToFarm = function() return true end   -- L1b
    end

    _G._testTime = 850.1
    GameTime = function() return _G._testTime end  -- luacheck: ignore
    GetPushLaneDesire = function() return 0 end    -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end  -- luacheck: ignore
    GetRoshanDesire = function() return 0 end      -- luacheck: ignore
    if opts.lane_fronts then
        GetLaneFrontLocation = function(_, lane)   -- luacheck: ignore
            local v = LANE_FRONTS[lane] or LANE_FRONTS[2]
            return api.Vector(v[1], v[2], 0)
        end
    end

    rf.declare_defend_ping(J, 'stale')

    if opts.source then
        local chunk, err = loadstring(opts.source, 'mode_farm_generic_variant')
        assert(chunk, 'variant source failed to parse: ' .. tostring(err))
        chunk()
    else
        dofile(SOURCE)
    end

    return {
        J = J, bot = bot, heroes = heroes, sb = sb,
        CAMP_X = CAMP_X, CAMP_Y = CAMP_Y,
        table_now = function() return J.Role['availableCampTable'] end,
    }
end

local function read_source()
    local f = assert(io.open(SOURCE, 'r'))
    local src = f:read('*a')
    f:close()
    return src
end

local function source_lines()
    local out = {}
    for line in (read_source() .. '\n'):gmatch('([^\n]*)\n') do out[#out + 1] = line end
    return out
end

-- Every line of GetDesireHelper that hands back a desire ABOVE none, found by
-- reading the shipped source rather than by hard-coding line numbers -- the
-- whole point is to notice when the set of exits changes.
local function positive_exit_lines()
    local lines, out = source_lines(), {}
    local inHelper = false
    for i, text in ipairs(lines) do
        if text:match('^function GetDesireHelper%(%)') then inHelper = true
        elseif inHelper and text:match('^function ') then inHelper = false end
        if inHelper and text:match('return%s') and not text:match('BOT_MODE_DESIRE_NONE')
            and (text:match('RemapValClamped') or text:match('BOT_MODE_DESIRE_')) then
            out[#out + 1] = i
        end
    end
    return out
end

-- The last line of GetDesireHelper: its terminal `return BOT_MODE_DESIRE_NONE`.
local function terminal_none_line()
    local lines = source_lines()
    local inHelper, last = false, nil
    for i, text in ipairs(lines) do
        if text:match('^function GetDesireHelper%(%)') then inHelper = true
        elseif inHelper and text:match('^function ') then inHelper = false end
        if inHelper and text:match('return BOT_MODE_DESIRE_NONE') then last = i end
    end
    return last
end

-- The anti-steal guard #775 calls "guard A": the ally scan on the jungle-camp
-- desire branch that answers BOT_MODE_DESIRE_NONE.
local function guard_a_lines()
    local lines = source_lines()
    for i, text in ipairs(lines) do
        if text:match("local nCampAllies = J%.GetAlliesNearLoc%(preferedCamp%.cattr%.location, 800%)") then
            return i, i + 6
        end
    end
    return nil
end

-- Run GetDesire() under a line hook and return every line of the shipped file
-- that executed.
local function trace_desire(w)
    local seen, order = {}, {}
    debug.sethook(function(_, ln)
        local info = debug.getinfo(2, 'S')
        local src = info and info.short_src or ''
        if src:find('mode_farm_generic') then
            seen[ln] = true
            order[#order + 1] = ln
        end
    end, 'l')
    local desire = GetDesire()
    debug.sethook()
    return desire, seen, order, w
end

local function last_helper_line(order)
    local first = nil
    local lines = source_lines()
    for i, text in ipairs(lines) do
        if text:match('^function GetDesireHelper%(%)') then first = i break end
    end
    local last
    for _, ln in ipairs(order) do
        if first and ln > first then last = ln end
    end
    return last
end

-- ---------------------------------------------------------------------------
-- A. WORLD FACTS -- the frame, asserted rather than assumed.
-- ---------------------------------------------------------------------------

tests['[world W1] the pinned geometry: ally inside the window, bot outside the splice'] = function()
    local w = world({})
    local camp = w.CAMP_X.cattr.location
    local dSB = GetUnitToLocationDistance(w.sb, camp)
    local dCM = GetUnitToLocationDistance(w.bot, camp)
    assert(math.abs(dSB - 574.8) < 5, ('SB->camp moved: %.1f'):format(dSB))
    assert(math.abs(dCM - 5991.9) < 5, ('CM->camp moved: %.1f'):format(dCM))
    assert(w.bot:GetTeam() == 3 and w.sb:GetTeam() == 3, 'both subjects are dire on this frame')
end

tests['[world W2] the subject is the draft\'s position 5, and no Consider entry names her'] = function()
    local w = world({})
    local Site = require(GetScriptDirectory() .. '/FunLib/aba_site')
    assert(w.J.GetPosition(w.bot) == 5,
        'the fixture\'s own roles block drafts crystal_maiden at 5; got ' ..
        tostring(w.J.GetPosition(w.bot)))
    assert(Site.ConsiderIsTimeToFarm['npc_dota_hero_crystal_maiden'] == nil,
        'crystal_maiden has gained a ConsiderIsTimeToFarm entry -- IsTimeToFarm ' ..
        'can now answer yes for her by a route this file does not model')
    local nConsider = 0
    for _ in pairs(Site.ConsiderIsTimeToFarm) do nConsider = nConsider + 1 end
    assert(nConsider == 74, 'the Consider table moved from 74 heroes to ' .. nConsider ..
        ' -- re-read whether the subject is still outside it')
end

-- ---------------------------------------------------------------------------
-- B. THE READING -- what the host mode actually bids on this frame.
-- ---------------------------------------------------------------------------

tests['[read R1] the host mode bids NONE on arbheart\'s own pinned frame'] = function()
    -- The lane fronts of L1a are declared on THIS leg deliberately, even though
    -- the shipped tree never reaches the lane scan.  Two reasons, both about
    -- what a future reader can see: it proves the declaration section C relies
    -- on is inert here, and it keeps this assertion able to see a change that
    -- opens the block -- without the declaration such a change dies inside the
    -- loader's GH #61 refusal and the file reports a missing lane front instead
    -- of a bid that moved.
    local w = world({ lane_fronts = true })
    local desire = GetDesire()
    assert(desire == BOT_MODE_DESIRE_NONE,
        'mode_farm_generic must bid NONE here -- if this ever goes positive the ' ..
        'three sibling arbheart files stop measuring a tick the engine skips, ' ..
        'and their readings need re-pricing, not this assertion relaxing; got ' ..
        tostring(desire))
    -- IsAttacking stays the fixture's own answer, as in the sibling files: if it
    -- ever read true the shipped :919 guard would retire the camp by itself.
    assert(w.J.IsAttacking(w.sb) == false, 'spirit_breaker now reads IsAttacking on this frame')
    -- And the same frame WITHOUT the declaration reads the same number, so the
    -- declaration is not what produced it.
    world({})
    local bare = GetDesire()
    assert(bare == desire, ('the declared lane fronts changed the bid (%s with, %s ' ..
        'without) -- they are supposed to be unreachable on the shipped tree'):format(
        tostring(desire), tostring(bare)))
end

tests['[read R2] every positive-desire exit is closed: the trace reaches none of them'] = function()
    local w = world({})
    local desire, seen, order = trace_desire(w)
    local exits = positive_exit_lines()
    -- TEN, counted off the source by the scanner above, not by hand: the two
    -- `BOT_MODE_DESIRE_ABSOLUTE * 1.1` escape bids near the top of the helper,
    -- the arc-warden and meepo clone bids, the midas bid, the two lane-front
    -- bids, the VERYLOW low-health camp bid, the camp bid, and the late-game
    -- tail bid.  GH #775 §3 counts SIX; the difference is which returns each
    -- count admits (it lists the bypass exits it cared about, not every
    -- positive return), and the method is registered here so the two numbers
    -- can be compared instead of silently disagreeing.
    assert(#exits == 10, 'GetDesireHelper now has ' .. #exits .. ' positive-desire exits, ' ..
        'not the 10 this reading enumerated -- re-read which ones are reachable')
    local reached = {}
    for _, ln in ipairs(exits) do if seen[ln] then reached[#reached + 1] = ln end end
    assert(#reached == 0, 'a positive-desire exit executed on this frame (lines ' ..
        table.concat(reached, ',') .. ') while the bid read ' .. tostring(desire))
    local term = terminal_none_line()
    assert(last_helper_line(order) == term,
        ('the helper must leave through its terminal `return BOT_MODE_DESIRE_NONE` ' ..
         '(line %s); last executed helper line was %s'):format(tostring(term),
            tostring(last_helper_line(order))))
end

tests['[read R3] the guard GH #775 names is never consulted on this frame'] = function()
    local w = world({})
    local _, seen = trace_desire(w)
    local lo, hi = guard_a_lines()
    assert(lo, 'guard A (the 800u ally scan on the jungle-camp branch) is gone or reshaped')
    for ln = lo, hi do
        assert(not seen[ln], ('guard A executed (line %d) -- #775 §2 describes THIS frame ' ..
            'as one where the guard answers first; the measurement says control stops ' ..
            'a conjunct earlier and never gets there'):format(ln))
    end
end

tests['[read R4] the conjunct that closes it is IsTimeToFarm, false under every BotMode'] = function()
    local w = world({})
    local Site = require(GetScriptDirectory() .. '/FunLib/aba_site')
    local dota = require(GetScriptDirectory() .. '/ts_libs/dota/index')
    assert(Site.IsTimeToFarm(w.bot) == false, 'IsTimeToFarm now answers yes for the subject')
    -- IsTimeToFarm has a push-tower branch that reads GetActiveMode, which the
    -- dumper does not carry.  So sweep every mode value instead of picking one:
    -- the answer is false for all of them on this frame, which makes the reading
    -- independent of the one thing the fixture cannot say.
    local nModes, nTrue = 0, 0
    for _, v in pairs(dota.BotMode) do
        if type(v) == 'number' then
            nModes = nModes + 1
            w.bot.GetActiveMode = function() return v end
            if Site.IsTimeToFarm(w.bot) then nTrue = nTrue + 1 end
        end
    end
    assert(nModes == 22, 'BotMode now has ' .. nModes .. ' values, not 22')
    assert(nTrue == 0, 'IsTimeToFarm went true under ' .. nTrue .. ' mode value(s) -- the ' ..
        'close is no longer independent of the mode field the dumper lacks')
end

tests['[read R5] the split is by role: dire cores read true, both dire supports false'] = function()
    local w = world({})
    local Site = require(GetScriptDirectory() .. '/FunLib/aba_site')
    local nCore, nSupport = 0, 0
    local seenDire = 0
    for _, h in pairs(w.heroes) do
        if h:GetTeam() == 3 then                                  -- L3
            seenDire = seenDire + 1
            local pos = w.J.GetPosition(h)
            local itf = Site.IsTimeToFarm(h)
            if pos <= 3 then
                nCore = nCore + 1
                assert(itf == true, ('dire core %s (pos %d) must pass IsTimeToFarm on this ' ..
                    'frame'):format(h:GetUnitName(), pos))
            else
                nSupport = nSupport + 1
                assert(itf == false, ('dire support %s (pos %d) must fail IsTimeToFarm'):format(
                    h:GetUnitName(), pos))
            end
        end
    end
    assert(seenDire == 5, 'dire roster is ' .. seenDire .. ' heroes, not 5')
    assert(nCore == 3 and nSupport == 2,
        ('dire reads %d cores / %d supports on this frame, not 3/2'):format(nCore, nSupport))
end

tests['[source S1] the guard, the latch and both in-block exits sit inside that conjunction'] = function()
    local src = read_source()
    local block = src:match('\n\tif GetGameMode%(%) ~= GAMEMODE_MO\n(.-)\n\tend\n')
    assert(block, 'the IsTimeToFarm conjunction is gone or reshaped')
    assert(block:match('and J%.Site%.IsTimeToFarm%(bot%)'),
        'IsTimeToFarm is no longer a conjunct of this block -- the reading above ' ..
        'is about THIS gate and must be re-taken')
    assert(block:match('local nCampAllies = J%.GetAlliesNearLoc%(preferedCamp%.cattr%.location, 800%)'),
        'guard A has left the block; #775 §2 assumes it is inside')
    assert(block:match('if preferedCamp == nil then preferedCamp = ClosestCamp%(bot, availableCamp%)'),
        'the jungle-branch camp latch has left the block')
    local _, nReturns = block:gsub('return ', '')
    assert(nReturns == 7, 'the block now has ' .. nReturns .. ' returns, not the 7 this ' ..
        'reading enumerated (2 positive lane exits, 1 positive camp exit, 1 bare nFarmCap, ' ..
        '1 verylow, 2 none -- one of which is guard A)')
end

-- ---------------------------------------------------------------------------
-- C. MUTATION + CONSTRUCTION -- the zero is caused by that conjunct, and the
-- mechanism works once a bid exists.
-- ---------------------------------------------------------------------------

tests['[mutation M1] deleting the IsTimeToFarm conjunct turns the zero into a bid'] = function()
    local src = read_source()
    local mutated, n = src:gsub('\n\tand J%.Site%.IsTimeToFarm%(bot%)', '', 1)
    assert(n == 1, 'M1: the conjunct did not match exactly once (n=' .. n .. ')')
    -- Lane fronts declared (L1a) because the block behind the conjunct reaches
    -- X.IsNearLaneFront, and the loader refuses to invent lane fronts (GH #61).
    world({ lane_fronts = true, source = mutated })
    local desire = GetDesire()
    assert(type(desire) == 'number' and desire > 0,
        'M1: with the conjunct deleted the same frame must produce a positive bid -- ' ..
        'if it does not, the zero read in R1 has a second cause and R4 is not the ' ..
        'whole reason; got ' .. tostring(desire))
end

tests['[construction C1] with a bid restored, the release AND retire fire on a live tick'] = function()
    -- L1: both supports are declared.  What is being witnessed is the mechanism
    -- on a real frame, never how often the world offers it.
    local function leg(armed)
        local w = world({ armed = armed, lane_fronts = true, force_farm = true })
        -- The declared lane fronts must actually leave a lane with no enemy
        -- inside 1400u, or the early-game exit never fires and this leg would be
        -- measuring the camp branch by accident.
        local nFree = 0
        for lane = 1, 3 do
            local front = api.Vector(LANE_FRONTS[lane][1], LANE_FRONTS[lane][2], 0)
            if #w.J.GetEnemiesNearLoc(front, 1400) == 0 then nFree = nFree + 1 end
        end
        assert(nFree >= 1, 'the declared lane fronts leave no enemy-free lane')
        local d1 = GetDesire()
        Think()
        _G._testTime = 851.15
        local d2 = GetDesire()
        Think()
        return w, d1, d2
    end

    local wArmed, a1, a2 = leg(true)
    assert(a1 > 0 and a2 > 0, ('both ticks must carry a live bid; got %s / %s'):format(
        tostring(a1), tostring(a2)))
    local tbl = wArmed.table_now()
    local hasX, hasY = false, false
    for _, c in ipairs(tbl) do
        if c == wArmed.CAMP_X then hasX = true end
        if c == wArmed.CAMP_Y then hasY = true end
    end
    assert(not hasX and hasY and #tbl == 1,
        'armed, on a tick the engine would have run, the camp the ally holds must be ' ..
        'released AND retired while the other camp stays')

    local wShipped = leg(false)
    local tbl2, hasX2 = wShipped.table_now(), false
    for _, c in ipairs(tbl2) do if c == wShipped.CAMP_X then hasX2 = true end end
    assert(hasX2 and #tbl2 == 2,
        'unarmed the table must come through untouched -- otherwise the armed leg ' ..
        'above is not measuring the gate')
end

tests['[construction C2] the exit that carries that bid never consults guard A'] = function()
    local w = world({ lane_fronts = true, force_farm = true })
    local desire, seen = trace_desire(w)
    assert(desire > 0, 'setup: this leg exists to trace a POSITIVE bid; got ' .. tostring(desire))
    local lo, hi = guard_a_lines()
    assert(lo, 'guard A (the 800u ally scan on the jungle-camp branch) is gone or reshaped')
    for ln = lo, hi do
        assert(not seen[ln],
            ('guard A executed (line %d) on the bypass exit -- then the equivalence #775 §1 ' ..
             'reports WOULD bite here and the release could not fire on this tick'):format(ln))
    end
end

return tests
