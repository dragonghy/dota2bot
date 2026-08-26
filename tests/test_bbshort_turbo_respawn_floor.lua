-- GH #222 -- the buyback ladder's third normal-mode duration, and the one that
-- shuts the ladder's only turbo-reachable rung for whole deaths at a time.
--
-- ability_item_usage_generic's BuybackUsageComplement runs a three-rung ladder.
-- Between rung 1 (defend a badly hurt ancient) and rungs 2/3 sits
--     if nFullRespawnTime < 60 then return end
-- and 60, like the 80 that GH #215 scaled one rung down, is a NORMAL-mode
-- duration. Turbo scales every respawn duration by 0.75 (the factor
-- J.TURBO_RESPAWN_FACTOR already pins), so the number was never re-based.
--
-- THE FINDING DOES NOT DEPEND ON HOW THE GETTER IS READ, and that is the
-- strongest thing about it. Read the local under the name it claims (a full
-- respawn DURATION -- "a short respawn is not worth buying out of") and the
-- gate selects a strictly smaller set of heroes in turbo than it was written
-- to. Read it under the documented semantics (GetRespawnTime is the REMAINING
-- time -- GH #208, `bbrespawn`) and the turbo ceiling bites outright: remaining
-- <= R <= 75, so rungs 2/3 are reachable only while remaining is in [60, 75] --
-- the first R - 60 <= 15 seconds of a death -- and for every hero whose turbo
-- respawn duration is under 60s the gate is already true at elapsed 0, so those
-- rungs are shut for the WHOLE death.
--
-- WHAT THIS IS NOT. It is NOT the clean structural zero 'bbfight' has. Above
-- R = 60 the rungs do open, so the honest claim is a domain the mode shrank,
-- and the rows below measure it as a domain rather than asserting a zero the
-- arithmetic does not support. The one place a zero IS claimed -- turbo respawn
-- durations under 60s -- is claimed per-R and controlled, because two
-- independent things shut cells in this ladder and only one of them is this
-- gate (see [defect-control]).
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number.
-- The SUBJECT half is real: the bot driven below is a hero the dump recorded as
-- genuinely DEAD (`alive = false`) on one real turbo frame, at that frame's own
-- clock. Two halves are NOT in the corpus and are pinned as world facts rather
-- than assumed:
--   [W1] no fixture carries a respawn time, so R is a DECLARED stand-in, and a
--        COUNTING-DOWN one (the getter is fed R - e at elapsed e) -- GH #208's
--        first criterion: a constant stand-in models the very misreading the
--        neighbouring lever is about and would pass for the wrong reason;
--   [W3] rung 3's own conditions (an ancient exists, enemies near it outnumber
--        the living allies) are WORLD facts, not respawn arithmetic. This file
--        measures REACHING the rung, never buying back. Whether the world half
--        ever holds is a corpus question with no denominator here, and the
--        rows below are named so they cannot be read as one.
-- The engine facts themselves (respawn table maximum, turbo factor) are
-- external to this repo and unverifiable from this container. They are named
-- constants in jmz_func and [source] pins them, so a drift is a red test rather
-- than a silently stale conclusion.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIX  = 'tests/fixtures/f_080225_wk_revive.lua'
local JMZ  = 'bots/FunLib/jmz_func.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'
local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

local DEAD = { 'npc_dota_hero_zuus', 8 }
local FRAME_T = 403.0

-- The shipped ladder's own constants, written out here so the model below is
-- comparable against the source rather than against a memory of it. [source]
-- asserts each one is still the text in the tree.
local GATE_FULL   = 60   -- this round's lever, unarmed
local GATE_ARMED  = 45   -- 60 * 0.75, what armed turbo gets
local GATE_LATE   = 40   -- `if nRemainingRespawnTime < 40 then return end`

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function load_with(sCand)
    if sCand == nil then
        os.remove(SIDE_PATH)
    else
        local f = assert(io.open(SIDE_PATH, 'w'))
        f:write("return { side = 'radiant', cand = '" .. sCand .. "' }\n")
        f:close()
    end
    local J, _, heroes = rf.load(FIX, DEAD[1])
    local bot = heroes[DEAD[1]]
    assert(bot ~= nil, 'fixture no longer carries ' .. DEAD[1])
    return J, bot
end

local function armed(sCand, fn)
    local J, bot = load_with(sCand)
    local ok, err = pcall(fn, J, bot)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

----------------------------------------------------------------------
-- The reachable turbo world. R is a respawn DURATION, so the grid is
-- the turbo image of the documented table (12..100 scaled by 0.75 =
-- 9..75) and never anything above the ceiling. Unlike 'bbfight''s grid
-- this one carries R = 50 and R = 55: they are the band where the
-- shipped gate is shut for the entire death but the armed one is not,
-- and a grid without them cannot see this lever at all.
----------------------------------------------------------------------
local R_GRID = { 9, 20, 40, 50, 55, 60, 70, 75 }
local E_GRID = { 0, 1, 5, 7, 10, 15, 20, 30, 45 }

local function each_cell(fn)
    for _, R in ipairs(R_GRID) do
        for _, e in ipairs(E_GRID) do
            if e <= R then fn(R, e) end
        end
    end
end

-- The two readings of the same getter that the ladder actually mixes.
-- `nFullRespawnTime` is the raw engine value, which is what THIS gate tests;
-- `nRemainingRespawnTime` is the shipped double subtraction unless 'bbrespawn'
-- is armed, and it is what the rung BELOW the gate tests.
local function engine_remaining(R, e) return R - e end
local function shipped_reading(R, e) return R - 2 * e end

-- The shipped control flow from this gate down to rung 3, in the order the file
-- writes it. Rung 2 is skipped on purpose: GH #215 proved it a structural zero
-- in turbo unless 'bbfight' is also armed, so crediting this lever with any of
-- its cells would be crediting it with another id's work.
-- Returns 'gate' when this round's lever sends the function home, 'late' when
-- the `< 40` rung below does, true when rung 3 is REACHED (see [W3] -- reached,
-- not taken).
local function reaches_ancient_rung(R, e, nGate, fReading)
    if engine_remaining(R, e) < nGate then return 'gate' end
    if fReading(R, e) < GATE_LATE then return 'late' end
    return true
end

local function count_open(nGate, fReading, fFilter)
    local n = 0
    each_cell(function(R, e)
        if (fFilter == nil or fFilter(R, e))
            and reaches_ancient_rung(R, e, nGate, fReading) == true then
            n = n + 1
        end
    end)
    return n
end

----------------------------------------------------------------------
-- [frame] the subject really is a dead hero on a real turbo frame
----------------------------------------------------------------------

tests['[frame] the subject is a hero the dump recorded as dead'] = function()
    local _, bot = load_with(nil)
    assert(bot:IsAlive() == false,
        DEAD[1] .. ' is alive on this frame now; the fixture moved')
    assert(bot:GetLevel() == DEAD[2], string.format(
        'the frame moved: %s used to be level %d here, now %d',
        DEAD[1], DEAD[2], bot:GetLevel()))
end

tests['[frame] the frame is a turbo frame, which is the whole domain'] = function()
    load_with(nil)
    assert(DotaTime() == FRAME_T, string.format(
        'fixture clock moved: expected %.1f, got %s', FRAME_T, tostring(DotaTime())))
    assert(GetGameMode() == GAMEMODE_TURBO,
        'the gate is turbo-only, so the frame has to be a turbo frame')
end

----------------------------------------------------------------------
-- [W1]/[W3] the halves the corpus does NOT have, asserted so they
-- cannot drift into claims
----------------------------------------------------------------------

tests['[W1] no fixture carries a respawn time, so R is a declared stand-in'] = function()
    local _, bot = load_with(nil)
    assert(bot:GetRespawnTime() == 0,
        'GetRespawnTime is absent from the dump; got ' .. tostring(bot:GetRespawnTime()))
    local n = 0
    local p = assert(io.popen("grep -l '[ ,{]respawn *=' tests/fixtures/*.lua 2>/dev/null"))
    for _ in p:lines() do n = n + 1 end
    p:close()
    assert(n == 0, 'a fixture started carrying a respawn field; use it instead of a stand-in')
end

tests['[W3] the model stops at reaching the rung, never at buying back'] = function()
    -- Stated as an assertion on the shipped source rather than as prose: rung 3
    -- guards its buyback with two world counts this file does not model, so a
    -- number produced above is a count of cells that REACH the rung. If the
    -- world half ever disappears from the tree, the rows here start meaning
    -- something they did not, and this fails first.
    local body = read_file(AIUG)
    assert(body:find('local nEnemyCount = X.GetNumEnemyNearby( ancient )', 1, true),
        'rung 3 lost its enemy count; the [lever] rows are no longer bounded by [W3]')
    assert(body:find('if nEnemyCount > 0 and nEnemyCount >= nAllyCount', 1, true),
        'rung 3 lost its outnumbered test; re-read what the open cells now mean')
end

----------------------------------------------------------------------
-- [arith] the finding, and an explicit refusal to overclaim it
----------------------------------------------------------------------

tests['[arith] the shipped floor is a normal-mode duration under the ceiling'] = function()
    local J = load_with(nil)
    local nCeiling = J.RESPAWN_TABLE_MAX * J.TURBO_RESPAWN_FACTOR
    assert(nCeiling == 75, 'turbo respawn ceiling: got ' .. tostring(nCeiling))
    assert(J.BUYBACK_SHORT_FLOOR == GATE_FULL,
        'the shipped floor moved from ' .. GATE_FULL .. ' to ' .. tostring(J.BUYBACK_SHORT_FLOOR))
    assert(J.BUYBACK_SHORT_FLOOR * J.TURBO_RESPAWN_FACTOR == GATE_ARMED, string.format(
        'the scaled floor is %s, not %d; re-derive the grid readings',
        tostring(J.BUYBACK_SHORT_FLOOR * J.TURBO_RESPAWN_FACTOR), GATE_ARMED))
    -- The refusal. 'bbfight' could say ceiling < floor and be done; this one
    -- cannot, and saying so here stops the next reader from borrowing that
    -- sentence for this lever.
    assert(J.BUYBACK_SHORT_FLOOR < nCeiling, string.format(
        'floor %d is now at or above the ceiling %.1f -- that would make this a '
        .. 'structural zero, which it deliberately is NOT claimed to be',
        J.BUYBACK_SHORT_FLOOR, nCeiling))
    -- The window above the floor, which is the whole of what shipped turbo gets.
    assert(nCeiling - J.BUYBACK_SHORT_FLOOR == 15, string.format(
        'the shipped window is fifteen seconds of the longest death; got %.1f',
        nCeiling - J.BUYBACK_SHORT_FLOOR))
    for _, R in ipairs(R_GRID) do
        assert(R <= nCeiling, string.format(
            'R=%d is above the turbo ceiling %.1f; the grid is modelling a '
            .. 'world turbo cannot reach', R, nCeiling))
    end
end

----------------------------------------------------------------------
-- [defect] shipped, the rung is shut for whole deaths at a time
----------------------------------------------------------------------

tests['[defect] shipped, every turbo respawn under 60s is shut all death long'] = function()
    local nCells = 0
    each_cell(function() nCells = nCells + 1 end)
    assert(nCells == 64, 'the grid moved to ' .. nCells .. ' cells; re-derive every count below')
    for _, R in ipairs(R_GRID) do
        if R < GATE_FULL then
            for _, reading in ipairs({ shipped_reading, engine_remaining }) do
                local n = count_open(GATE_FULL, reading, function(r) return r == R end)
                assert(n == 0, string.format(
                    'R=%d opened %d cells under the shipped gate; the whole-death '
                    .. 'shutdown claim is stale', R, n))
            end
        end
    end
end

tests['[defect] shipped, the reachable set is small and lives at the top'] = function()
    -- Counted rather than asserted zero, because it is not zero -- see [arith].
    -- 12 of 64: R=60 at e=0 only, R=70 for e<=10, R=75 for e<=15.
    local n = count_open(GATE_FULL, shipped_reading)
    assert(n == 12, 'shipped open cells: ' .. n .. ' (expected 12)')
    each_cell(function(R, e)
        if reaches_ancient_rung(R, e, GATE_FULL, shipped_reading) == true then
            assert(R >= GATE_FULL, string.format(
                'R=%d e=%d opens below the floor; the arithmetic is wrong somewhere', R, e))
        end
    end)
end

tests['[defect-control] two things shut cells here and only one is this gate'] = function()
    -- Without this control an "R=9 and R=20 never open" reading would be
    -- credited to the lever, and the lever cannot touch them: with the gate
    -- REMOVED ENTIRELY those rows are still shut, by the `< 40` rung below.
    -- This is GH #215's second criterion applied to a different pair of
    -- reasons -- do not launder the other one into this defect.
    for _, R in ipairs({ 9, 20 }) do
        local n = count_open(0, shipped_reading, function(r) return r == R end)
        assert(n == 0, string.format(
            'R=%d opens %d cells with no gate at all, so the gate was never what '
            .. 'shut it; the control has gone stale', R, n))
    end
    -- And the rows where the gate IS the binding constraint, so the control
    -- cannot pass by shutting everything.
    local nGateBound = 0
    for _, R in ipairs({ 40, 50, 55 }) do
        nGateBound = nGateBound + count_open(0, shipped_reading, function(r) return r == R end)
    end
    assert(nGateBound == 8, string.format(
        'with no gate, R in {40,50,55} opens %d cells (expected 8); those are the '
        .. 'cells the shipped gate is responsible for shutting', nGateBound))
end

----------------------------------------------------------------------
-- [lever] armed, the domain grows -- and it grows WITHOUT the neighbours
----------------------------------------------------------------------

tests['[lever] armed, the reachable set doubles on the shipped readings'] = function()
    -- Both neighbouring ids unarmed: the rung below still reads R - 2e and rung
    -- 2 is still a structural zero. This is the GH #207 pre-check -- 'bbshort'
    -- armed ALONE has to be able to fire, or it is a leg that cannot be
    -- measured in any wave that does not happen to carry its partners.
    local nShipped = count_open(GATE_FULL, shipped_reading)
    local nArmed   = count_open(GATE_ARMED, shipped_reading)
    assert(nArmed > nShipped, "'bbshort' armed alone must be able to fire")
    assert(nShipped == 12 and nArmed == 24, string.format(
        'open cells shipped/armed: %d/%d (expected 12/24)', nShipped, nArmed))
end

tests['[lever] armed opens deaths that were shut end to end, not just longer windows'] = function()
    -- The part that matters strategically. R = 50 and R = 55 are turbo respawn
    -- durations where the shipped gate is true at elapsed 0, i.e. rung 3 is
    -- unreachable for the entire death; armed, the first seconds of those
    -- deaths come back.
    for _, R in ipairs({ 50, 55 }) do
        local nBefore = count_open(GATE_FULL, shipped_reading, function(r) return r == R end)
        local nAfter  = count_open(GATE_ARMED, shipped_reading, function(r) return r == R end)
        assert(nBefore == 0, string.format('R=%d used to be shut all death; now %d', R, nBefore))
        assert(nAfter > 0, string.format(
            'R=%d is still shut all death with the lever armed; the lever buys '
            .. 'nothing where it was supposed to buy the most', R))
    end
    assert(count_open(GATE_ARMED, shipped_reading, function(r) return r == 50 end) == 3)
    assert(count_open(GATE_ARMED, shipped_reading, function(r) return r == 55 end) == 4)
    -- And the honest other side: R = 40 stays shut even armed, because 40 is
    -- below the scaled floor too. The lever is not claimed to rescue it.
    assert(count_open(GATE_ARMED, shipped_reading, function(r) return r == 40 end) == 0,
        'R=40 now opens armed; the scaled floor moved and the claim needs redoing')
end

tests['[lever] armed is strictly one-directional: it never closes a cell'] = function()
    each_cell(function(R, e)
        for _, reading in ipairs({ shipped_reading, engine_remaining }) do
            local before = reaches_ancient_rung(R, e, GATE_FULL, reading)
            local after  = reaches_ancient_rung(R, e, GATE_ARMED, reading)
            if before == true then
                assert(after == true, string.format(
                    'R=%d e=%d reached the rung and now does not', R, e))
            end
            -- The lever may only ever convert a 'gate' into something else. It
            -- must never move the `< 40` rung below it, which belongs to
            -- 'bbrespawn''s round, not this one.
            if before == 'late' then
                assert(after == 'late', string.format(
                    'R=%d e=%d moved the rung BELOW the gate; wrong lever', R, e))
            end
        end
    end)
end

tests['[lever] with bbrespawn also armed the window only widens'] = function()
    -- Monotone in the neighbour, so a wave that carries both cannot produce a
    -- smaller domain than this file measured alone.
    each_cell(function(R, e)
        if reaches_ancient_rung(R, e, GATE_ARMED, shipped_reading) == true then
            assert(reaches_ancient_rung(R, e, GATE_ARMED, engine_remaining) == true,
                string.format('R=%d e=%d opens on the shipped reading but not the '
                    .. 'fixed one; the two legs are not monotone', R, e))
        end
    end)
end

----------------------------------------------------------------------
-- [gate] unarmed is the shipped literal, to the number
----------------------------------------------------------------------

tests['[gate] unarmed the floor is exactly the shipped 60'] = function()
    local J = load_with(nil)
    assert(J.BuybackShortRespawnFloor() == GATE_FULL,
        'unarmed floor: got ' .. tostring(J.BuybackShortRespawnFloor()))
end

tests['[gate] armed and turbo the floor is the scaled 45'] = function()
    armed('bbshort', function(J)
        assert(J.IsModeTurbo(), 'the fixture frame is turbo')
        assert(J.BuybackShortRespawnFloor() == GATE_ARMED,
            'armed floor: got ' .. tostring(J.BuybackShortRespawnFloor()))
    end)
end

tests['[gate] neither neighbour in the wave arms this one'] = function()
    for _, sOther in ipairs({ 'bbfight', 'bbrespawn' }) do
        armed(sOther, function(J)
            assert(J.BuybackShortRespawnFloor() == GATE_FULL, string.format(
                "arming '%s' must leave this floor at the shipped %d", sOther, GATE_FULL))
        end)
    end
end

tests['[gate] the wrong side does not arm it either'] = function()
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'dire', cand = 'bbshort' }\n")
    f:close()
    local ok, err = pcall(function()
        local J, _, heroes = rf.load(FIX, DEAD[1])
        assert(heroes[DEAD[1]]:GetTeam() == 2, 'the subject used to be radiant here')
        assert(not J.IsSoakCandidate('bbshort'), 'dire side must not arm a radiant subject')
        assert(J.BuybackShortRespawnFloor() == GATE_FULL, 'and the floor stays shipped')
    end)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

----------------------------------------------------------------------
-- [source] the tree still says what the model above assumes
----------------------------------------------------------------------

tests['[source] the gate is one conjunct against a mode predicate'] = function()
    local body = read_file(JMZ)
    local fn = body:match('function J%.BuybackShortRespawnFloor.-\nend')
    assert(fn ~= nil, 'J.BuybackShortRespawnFloor lost its body')
    local gate = fn:match('\n\tif ([^\n]-IsSoakCandidate[^\n]-) then')
    assert(gate ~= nil, 'J.BuybackShortRespawnFloor lost its gate line')
    assert(gate == "J.IsModeTurbo() and J.IsSoakCandidate( 'bbshort' )",
        'the gate line changed shape: ' .. tostring(gate))
    local _, n = body:gsub("IsSoakCandidate%(%s*'bbshort'%s*%)", '')
    assert(n == 1, 'exactly one resolution site for this id; got ' .. tostring(n))
end

tests['[source] the armed value is derived from named constants, not retyped'] = function()
    local body = read_file(JMZ)
    assert(body:find('J.TURBO_RESPAWN_FACTOR = 0.75', 1, true),
        'the turbo respawn factor is no longer pinned at 0.75')
    assert(body:find('J.BUYBACK_SHORT_FLOOR  = 60', 1, true),
        'the shipped floor is no longer pinned at 60')
    local fn = body:match('function J%.BuybackShortRespawnFloor.-\nend')
    assert(fn:find('J.BUYBACK_SHORT_FLOOR * J.TURBO_RESPAWN_FACTOR', 1, true),
        'the armed value must be the scaled constant, not a re-guessed literal')
    assert(not fn:find('45', 1, true),
        'the scaled value is derived, never written down; got a literal 45')
end

tests['[source] the call site delegates and the literal 60 is gone'] = function()
    local body = read_file(AIUG)
    assert(body:find('if nFullRespawnTime < J.BuybackShortRespawnFloor() then', 1, true),
        'the gate no longer delegates to the helper')
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then
            assert(not line:find('nFullRespawnTime < 60', 1, true),
                'the shipped literal is still live somewhere in this file')
        end
    end
    -- The read this gate consumes is still the raw getter, which is what makes
    -- engine_remaining() the right model for it and not shipped_reading().
    assert(body:find('local nFullRespawnTime = bot:GetRespawnTime()', 1, true),
        'the gate now reads something else; the model above is testing a ladder that is gone')
end

----------------------------------------------------------------------
-- [limit] what this lever does NOT move
----------------------------------------------------------------------

tests['[limit] the other three thresholds in the ladder are untouched'] = function()
    local body = read_file(AIUG)
    assert(body:find('nRemainingRespawnTime > 20', 1, true),
        'rung 1 changed; it is not this round\'s lever')
    assert(body:find('and nRemainingRespawnTime > J.BuybackFightRespawnFloor()', 1, true),
        "rung 2 changed; it is 'bbfight''s, landed last round")
    assert(body:find('if nRemainingRespawnTime < ' .. GATE_LATE, 1, true),
        'rung 3\'s floor changed; it is not this round\'s lever')
end

tests['[limit] the double subtraction itself is still bbrespawn\'s, not this one'] = function()
    local body = read_file(JMZ)
    local fn = body:match('function J%.RespawnRemaining.-\nend')
    assert(fn ~= nil, 'J.RespawnRemaining lost its body')
    assert(fn:find('hBot:GetRespawnTime() - ( DotaTime() - fDeathTime )', 1, true),
        'the shipped double subtraction moved; this round did not touch it, so '
        .. 'something else did and the [lever] readings need re-deriving')
end

return tests
