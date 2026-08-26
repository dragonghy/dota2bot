-- GH #215 -- the buyback ladder's level-25 teamfight branch asks for a number
-- turbo cannot produce.
--
-- ability_item_usage_generic's BuybackUsageComplement ends in a three-rung
-- ladder. The middle rung is
--     if bot:GetLevel() > 24 and nRemainingRespawnTime > 80 then <buyback>
-- and 80 is a NORMAL-mode duration. Two documented engine facts decide it:
-- the hero respawn table runs 12s (level 1) .. 100s (level 25 and above), and
-- turbo respawn is 25% faster. The turbo ceiling is therefore 100 * 0.75 = 75
-- seconds -- five below the floor -- so the branch is a STRUCTURAL ZERO in
-- turbo, at the respawn table's own maximum, on the single level it was
-- written for. Fix: J.BuybackFightRespawnFloor, gated 'bbfight', turbo-only,
-- scaling the threshold by the same documented 0.75 rather than re-guessing it.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number.
-- The SUBJECT half is real: the bot driven below is a hero the dump recorded
-- as genuinely DEAD (`alive = false`) on one real turbo frame, and the clock is
-- that frame's own 403.0.
-- Two halves are NOT in the corpus and are not pretended to be, and each is
-- pinned as a world fact rather than assumed:
--   [W1] no fixture carries a respawn time at all, so R is a DECLARED stand-in
--        -- and, as in GH #208, a COUNTING-DOWN one (the getter is fed R - e at
--        elapsed e), because a constant stand-in models the very misreading the
--        neighbouring lever is about and would make these rows pass for the
--        wrong reason;
--   [W2] the whole fixture archive tops out at level 19, so `GetLevel() > 24`
--        has never been seen on a real frame either. The branch is unreachable
--        in the corpus for TWO independent reasons; only one of them is a code
--        defect, and this file is careful not to launder the other into one.
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

-- The shipped ladder's own constants, written out here so the model below can
-- be compared against the source rather than against a memory of it. [source]
-- asserts each one is still the text in the tree.
local GATE_FULL   = 60   -- `if nFullRespawnTime < 60 then return end`
local FLOOR_FIGHT = 80   -- `and nRemainingRespawnTime > 80`
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
-- The reachable turbo world: R is a respawn DURATION, so the grid is
-- the turbo image of the documented table (12..100 scaled by 0.75 =
-- 9..75) and never anything above the ceiling. Cells with e > R are
-- dropped -- the hero has already respawned there.
----------------------------------------------------------------------
local R_GRID = { 9, 20, 40, 60, 70, 75 }
local E_GRID = { 0, 1, 5, 7, 10, 15, 20, 30, 45 }

local function each_cell(fn)
    for _, R in ipairs(R_GRID) do
        for _, e in ipairs(E_GRID) do
            if e <= R then fn(R, e) end
        end
    end
end

-- The two readings of the same getter that the ladder actually mixes.
-- `nFullRespawnTime` is the raw engine value; `nRemainingRespawnTime` is the
-- shipped double subtraction unless 'bbrespawn' is armed. This lever must work
-- on the SHIPPED reading -- see the GH #207 note in jmz_func.
local function engine_remaining(R, e) return R - e end
local function shipped_reading(R, e) return R - 2 * e end

-- The shipped control flow from the top of the ladder down to the teamfight
-- rung, modelled in the same order the file writes it. Returns 'blocked' when
-- the gate above the rung sends the function home, true/false otherwise.
local function fight_rung(R, e, nFloor, fReading, nLevel)
    if engine_remaining(R, e) < GATE_FULL then return 'blocked' end
    return (nLevel > 24) and (fReading(R, e) > nFloor)
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
-- [W1]/[W2] the two halves the corpus does NOT have, asserted so they
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

tests['[W2] no fixture carries a level-25 hero, so the level conjunct is one too'] = function()
    local nMax = 0
    local p = assert(io.popen(
        "grep -ho 'level = [0-9]*' tests/fixtures/*.lua 2>/dev/null | grep -o '[0-9]*'"))
    for line in p:lines() do
        local v = tonumber(line)
        if v and v > nMax then nMax = v end
    end
    p:close()
    assert(nMax > 0, 'the level sweep read nothing; the fixture format moved')
    assert(nMax < 25, string.format(
        'the archive now reaches level %d -- the level conjunct is observable, '
        .. 'so stop declaring it and pin the branch on that frame instead', nMax))
    -- Recorded, not merely bounded: the next round should not have to re-measure.
    assert(nMax == 19, string.format(
        'the archive ceiling moved from 19 to %d; re-read whether the branch is '
        .. 'still corpus-unreachable for TWO reasons or only one', nMax))
end

----------------------------------------------------------------------
-- [arith] the finding itself: a dominance between two constants
----------------------------------------------------------------------

tests['[arith] the turbo respawn ceiling is strictly below the shipped floor'] = function()
    local J = load_with(nil)
    local nCeiling = J.RESPAWN_TABLE_MAX * J.TURBO_RESPAWN_FACTOR
    assert(nCeiling == 75, 'turbo respawn ceiling: got ' .. tostring(nCeiling))
    assert(nCeiling < J.BUYBACK_FIGHT_FLOOR, string.format(
        'the whole finding is this inequality: ceiling %.1f vs floor %d',
        nCeiling, J.BUYBACK_FIGHT_FLOOR))
    assert(J.BUYBACK_FIGHT_FLOOR - nCeiling == 5,
        'the margin is five seconds; if it moved, the verdict has to be re-derived')
    -- The grid below must not quietly step outside the world it claims to model.
    for _, R in ipairs(R_GRID) do
        assert(R <= nCeiling, string.format(
            'R=%d is above the turbo ceiling %.1f; the grid is modelling a '
            .. 'world turbo cannot reach', R, nCeiling))
    end
end

----------------------------------------------------------------------
-- [defect] shipped, the rung never opens -- on EITHER reading
----------------------------------------------------------------------

tests['[defect] shipped, the teamfight rung is false on every reachable cell'] = function()
    local nOpen, nCells = 0, 0
    each_cell(function(R, e)
        nCells = nCells + 1
        -- level 25 DECLARED (see [W2]); the level conjunct is granted, so any
        -- zero found here is the respawn threshold's and nothing else's.
        for _, reading in ipairs({ shipped_reading, engine_remaining }) do
            if fight_rung(R, e, FLOOR_FIGHT, reading, 25) == true then
                nOpen = nOpen + 1
            end
        end
    end)
    assert(nCells >= 40, 'the grid shrank to ' .. nCells .. ' cells; it is no longer a sweep')
    assert(nOpen == 0, string.format(
        'the shipped rung opened on %d of %d cells; it is not a structural zero '
        .. 'any more and this whole file is stale', nOpen, nCells))
end

tests['[defect] granting the level conjunct is what isolates the defect'] = function()
    -- Control for the test above: at the fixture's real level the rung is false
    -- for a DIFFERENT reason, so a run that forgot to declare the level would
    -- read as "structural zero" while proving nothing about the threshold.
    local nFalseForLevel = 0
    each_cell(function(R, e)
        if fight_rung(R, e, FLOOR_FIGHT * 0, engine_remaining, DEAD[2]) == false then
            nFalseForLevel = nFalseForLevel + 1
        end
    end)
    assert(nFalseForLevel > 0, 'the level conjunct alone should be able to close the rung')
end

----------------------------------------------------------------------
-- [lever] armed, the rung has a domain -- and gets it WITHOUT 'bbrespawn'
----------------------------------------------------------------------

tests['[lever] armed, the rung opens on a non-empty set of reachable cells'] = function()
    local open = {}
    each_cell(function(R, e)
        if fight_rung(R, e, FLOOR_FIGHT * 0.75, shipped_reading, 25) == true then
            open[#open + 1] = string.format('R=%d,e=%d', R, e)
        end
    end)
    assert(#open > 0,
        'armed the rung still never opens; the lever buys nothing and must not ship')
    -- Pinned, not merely non-empty: the shipped R - 2e reading is a steep decay,
    -- so the window is the first seconds of the longest deaths only.
    -- R=70,e=0/1 and R=75,e=0/1/5/7 -- the top of the table, early in the death.
    assert(#open == 6, 'armed-open cells: ' .. #open .. ' (' .. table.concat(open, ' ') .. ')')
end

tests['[lever] the armed domain does not depend on bbrespawn (GH #207)'] = function()
    -- The rows above already use the SHIPPED reading. This states the property
    -- they buy: arming 'bbfight' alone is enough, so the leg cannot become a
    -- structural zero because a partner id is missing from the wave string.
    local nAlone = 0
    each_cell(function(R, e)
        if fight_rung(R, e, FLOOR_FIGHT * 0.75, shipped_reading, 25) == true then
            nAlone = nAlone + 1
        end
    end)
    assert(nAlone > 0, "'bbfight' armed alone must be able to fire")
    -- And with the neighbouring fix also armed the window can only widen: the
    -- engine reading decays half as fast, never faster.
    each_cell(function(R, e)
        if fight_rung(R, e, FLOOR_FIGHT * 0.75, shipped_reading, 25) == true then
            assert(fight_rung(R, e, FLOOR_FIGHT * 0.75, engine_remaining, 25) == true,
                string.format('R=%d e=%d opens on the shipped reading but not the '
                    .. 'fixed one; the two legs are not monotone', R, e))
        end
    end)
end

tests['[lever] armed is strictly one-directional: it never closes a rung'] = function()
    each_cell(function(R, e)
        for _, reading in ipairs({ shipped_reading, engine_remaining }) do
            local before = fight_rung(R, e, FLOOR_FIGHT, reading, 25)
            local after  = fight_rung(R, e, FLOOR_FIGHT * 0.75, reading, 25)
            if before == true then
                assert(after == true, string.format(
                    'R=%d e=%d used to buy back and now does not', R, e))
            end
            assert((before == 'blocked') == (after == 'blocked'),
                'the lever must not move the gate ABOVE the rung')
        end
    end)
end

----------------------------------------------------------------------
-- [gate] unarmed is the shipped literal, to the number
----------------------------------------------------------------------

tests['[gate] unarmed the floor is exactly the shipped 80'] = function()
    local J = load_with(nil)
    assert(J.BuybackFightRespawnFloor() == 80,
        'unarmed floor: got ' .. tostring(J.BuybackFightRespawnFloor()))
end

tests['[gate] armed and turbo the floor is the scaled 60'] = function()
    armed('bbfight', function(J)
        assert(J.IsModeTurbo(), 'the fixture frame is turbo')
        assert(J.BuybackFightRespawnFloor() == 60,
            'armed floor: got ' .. tostring(J.BuybackFightRespawnFloor()))
    end)
end

tests['[gate] a different candidate in the wave does not arm this one'] = function()
    armed('bbrespawn', function(J)
        assert(J.BuybackFightRespawnFloor() == 80,
            "another id's wave must leave this floor at the shipped 80")
    end)
end

tests['[gate] the wrong side does not arm it either'] = function()
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'dire', cand = 'bbfight' }\n")
    f:close()
    local ok, err = pcall(function()
        local J, _, heroes = rf.load(FIX, DEAD[1])
        assert(heroes[DEAD[1]]:GetTeam() == 2, 'the subject used to be radiant here')
        assert(not J.IsSoakCandidate('bbfight'), 'dire side must not arm a radiant subject')
        assert(J.BuybackFightRespawnFloor() == 80, 'and the floor stays shipped')
    end)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

----------------------------------------------------------------------
-- [source] the tree still says what the model above assumes
----------------------------------------------------------------------

tests['[source] the gate is one conjunct against a mode predicate'] = function()
    local body = read_file(JMZ)
    local fn = body:match('function J%.BuybackFightRespawnFloor.-\nend')
    assert(fn ~= nil, 'J.BuybackFightRespawnFloor lost its body')
    local gate = fn:match('\n\tif ([^\n]-IsSoakCandidate[^\n]-) then')
    assert(gate ~= nil, 'J.BuybackFightRespawnFloor lost its gate line')
    assert(gate == "J.IsModeTurbo() and J.IsSoakCandidate( 'bbfight' )",
        'the gate line changed shape: ' .. tostring(gate))
    local _, n = body:gsub("IsSoakCandidate%(%s*'bbfight'%s*%)", '')
    assert(n == 1, 'exactly one resolution site for this id; got ' .. tostring(n))
end

tests['[source] the three engine constants are named, not inlined'] = function()
    local body = read_file(JMZ)
    assert(body:find('J.RESPAWN_TABLE_MAX    = 100', 1, true),
        'the respawn table maximum is no longer pinned at 100')
    assert(body:find('J.TURBO_RESPAWN_FACTOR = 0.75', 1, true),
        'the turbo respawn factor is no longer pinned at 0.75')
    assert(body:find('J.BUYBACK_FIGHT_FLOOR  = 80', 1, true),
        'the shipped floor is no longer pinned at 80')
    local fn = body:match('function J%.BuybackFightRespawnFloor.-\nend')
    assert(fn:find('J.BUYBACK_FIGHT_FLOOR * J.TURBO_RESPAWN_FACTOR', 1, true),
        'the armed value must be the scaled constant, not a re-guessed literal')
    assert(not fn:find('60', 1, true),
        'the scaled value is derived, never written down; got a literal 60')
end

tests['[source] the call site delegates and the literal 80 is gone'] = function()
    local body = read_file(AIUG)
    assert(body:find('and nRemainingRespawnTime > J.BuybackFightRespawnFloor()', 1, true),
        'the teamfight rung no longer delegates to the helper')
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then
            assert(not line:find('nRemainingRespawnTime > 80', 1, true),
                'the shipped literal is still live somewhere in this file')
        end
    end
end

tests['[source] the ladder constants this model assumes are still the tree'] = function()
    local body = read_file(AIUG)
    -- RATCHET MOVED, NOT LOOSENED (GH #222). This used to read the literal
    -- `if nFullRespawnTime < 60 then` off the tree. That gate is now behind
    -- 'bbshort', so the pin follows it to the helper -- and what fight_rung()
    -- actually depends on is not the literal but the VALUE this gate takes
    -- while 'bbshort' is not in the wave string, which is what is asserted.
    assert(body:find('if nFullRespawnTime < J.BuybackShortRespawnFloor() then', 1, true),
        'the gate above the rung moved; fight_rung() models a ladder that is gone')
    local jmz = read_file(JMZ)
    assert(jmz:find('J.BUYBACK_SHORT_FLOOR  = ' .. GATE_FULL, 1, true),
        'the gate above the rung no longer defaults to ' .. GATE_FULL
        .. '; fight_rung() is modelling the wrong ladder for an unarmed wave')
    assert(body:find('if nRemainingRespawnTime < ' .. GATE_LATE .. '\n', 1, true)
        or body:find('nRemainingRespawnTime < ' .. GATE_LATE, 1, true),
        'the gate below the rung moved; re-read the ladder before trusting [limit]')
end

----------------------------------------------------------------------
-- [limit] what this lever does NOT move
----------------------------------------------------------------------

tests['[limit] the sibling misreading moved in its own round, and only there'] = function()
    local body = read_file(AIUG)
    -- GH #208's registered NEXT CELL, taken up in GH #222 as 'bbshort'. RATCHET
    -- MOVED, NOT LOOSENED: the row used to assert the sibling was untouched; it
    -- now asserts the sibling moved to exactly ONE place and that this file's
    -- own lever did not ride along with it. `nFullRespawnTime` is still the
    -- same getter read under a name that claims a constant, which is why the
    -- [defect] rows above use engine_remaining() for the gate and not a
    -- per-death constant.
    assert(body:find('local nFullRespawnTime = bot:GetRespawnTime()', 1, true),
        'the sibling read moved; re-check whether this lever is still alone')
    assert(body:find('if nFullRespawnTime < J.BuybackShortRespawnFloor() then', 1, true),
        "the sibling gate is not behind 'bbshort' any more; the NEXT CELL note "
        .. 'in jmz_func and the [source] row above are both stale')
    local jmz = read_file(JMZ)
    local _, nOther = jmz:gsub("IsSoakCandidate%(%s*'bbshort'%s*%)", '')
    assert(nOther == 1, "'bbshort' must stay one resolution site; got " .. tostring(nOther))
    local fn = jmz:match('function J%.BuybackFightRespawnFloor.-\nend')
    assert(not fn:find('bbshort', 1, true),
        'this round\'s lever picked up the sibling id; the two must stay separable')
end

tests['[limit] the other two rungs of the ladder keep their shipped thresholds'] = function()
    local body = read_file(AIUG)
    assert(body:find('nRemainingRespawnTime > 20', 1, true),
        'the ancient rung above the gate changed; it is not this round\'s lever')
    assert(body:find('nRemainingRespawnTime < 40', 1, true),
        'the rung below the gate changed; it is not this round\'s lever')
end

return tests
