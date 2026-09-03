-- GH #208 -- "how long am I still dead" is computed by subtracting the elapsed
-- time from a getter that ALREADY reports the remaining time.
--
-- docs/BOT_API_REFERENCE.md documents Unit:GetRespawnTime() as "Seconds until
-- this hero respawns" -- a number that counts DOWN on its own.
-- X.GetRemainingRespawnTime (ability_item_usage_generic) shipped as
-- `bot:GetRespawnTime() - ( DotaTime() - fDeathTime )`, so with R the respawn
-- duration and e the seconds since death the engine hands back R - e and the
-- expression returns R - 2e: a reading that decays at twice the wall clock and
-- crosses zero at the HALFWAY point of the death. Every consumer of that
-- number is a LOWER bound on it, so the error can only close a buyback the
-- rule meant to allow. Fix: J.RespawnRemaining, gated 'bbrespawn', turbo-only.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number.
-- The SUBJECT half is real: the bot driven below is a hero the dump recorded
-- as genuinely DEAD (`alive = false`) on one real turbo frame, and the clock
-- the shipped expression subtracts with -- DotaTime() -- is that frame's own
-- 403.0, not a number invented here.
-- The RESPAWN half is NOT in the corpus and is not pretended to be: world fact
-- [W1] asserts the dumper carries no respawn field at all. R is therefore a
-- DECLARED stand-in, and it is declared as a COUNTING-DOWN one -- each cell
-- hands the getter R - e, which is what the engine would report at that
-- elapsed time -- because a constant stand-in would model the very misreading
-- under test and make every row below pass for the wrong reason. Every reading
-- here is an arithmetic identity of the helper driven on a real dead subject,
-- not corpus data. The only counts claimed as tree data are the ones under
-- [W1], [source] and [limit], which read the source and the archive directly.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')               -- owns the shared switch

local FIX  = 'tests/fixtures/f_080225_wk_revive.lua'
local JMZ  = 'bots/FunLib/jmz_func.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'
local SIDE_PATH = ss.PATH                          -- gitignored, farm-only

-- Nothing may be armed when this file LOADS -- the only moment that sees the
-- state the process started in. The armed cases sort before the gate-off ones
-- and each used to end in an unconditional remove, so an inherited leftover was
-- deleted before any per-case guard could name it (GH #417).
ss.assert_clean('test_bbrespawn_double_subtract')

-- The one hero this frame recorded as dead. Level is asserted too, so a
-- regenerated fixture that quietly swaps the subject fails here instead of
-- silently re-pointing every reading below at a living hero.
local DEAD = { 'npc_dota_hero_zuus', 8 }
local FRAME_T = 403.0

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- Load the frame with the gate file in a chosen state. The soak conf is cached
-- in a jmz_func upvalue on first read, and rf.load resets the module table, so
-- the file has to be written BEFORE the load -- writing it afterwards would
-- leave every "armed" row silently running the shipped leg.
-- ...and for the same reason the unarmed leg CANNOT be a remove: an
-- unconditional remove here deletes whatever another process armed a
-- millisecond ago, and that process then reads the unarmed value out of an
-- assertion that says nothing about the switch (GH #365 §3). `ss.assert_clean`
-- states what the remove was standing in for -- "this leg measures the shipped
-- tree" -- as a claim instead of an act.
local function load_with(sCand, sSide)
    if sCand == nil then
        ss.assert_clean('unarmed leg')
    else
        ss.arm(sCand, sSide or 'radiant')
    end
    local J, _, heroes = rf.load(FIX, DEAD[1])
    local bot = heroes[DEAD[1]]
    assert(bot ~= nil, 'fixture no longer carries ' .. DEAD[1])
    return J, bot
end

-- Run fn(J, bot) with the gate file armed for sCand, and always clean up.
local function armed(sCand, fn, sSide)
    local J, bot = load_with(sCand, sSide)
    local ok, err = pcall(fn, J, bot)
    if sCand == nil and ok then ss.assert_clean('unarmed leg, after the case body') end
    -- The switch cause OUTRANKS the assertion it caused; `finish` owns that
    -- ordering, and is a no-op on the leg that armed nothing.
    ss.finish(ok, err)
end

-- Declare the one field the dump lacks, on the real handle, at the value the
-- engine would report e seconds into an R-second death. The mock's unit
-- __index re-reads __spec at call time, so this is the whole stand-in.
local function declare_respawn(bot, R, e)
    rawget(bot, '__spec').GetRespawnTime = R - e
end

-- The shipped expression, written out once so the rows below compare the
-- helper against the ORIGINAL text rather than against a paraphrase of it.
local function shipped(bot, fDeathTime)
    if fDeathTime == 0 then return 0 end
    return bot:GetRespawnTime() - (DotaTime() - fDeathTime)
end

-- R x elapsed, exhaustive on a grid that straddles every consumer threshold in
-- the buyback rule (20, 40, 80) and both sides of the R/2 crossing. Cells with
-- e > R are dropped: the hero has already respawned there.
local R_GRID = { 20, 30, 40, 60, 80, 100 }
local E_GRID = { 0, 1, 5, 10, 15, 20, 30, 45, 60 }

local function each_cell(bot, fn)
    for _, R in ipairs(R_GRID) do
        for _, e in ipairs(E_GRID) do
            if e <= R then
                declare_respawn(bot, R, e)
                fn(R, e, DotaTime() - e)
            end
        end
    end
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
    assert(bot:GetHealth() == 0, 'a dead hero carries 0 health')
end

tests['[frame] the clock the shipped expression subtracts with is the real one'] = function()
    load_with(nil)
    assert(DotaTime() == FRAME_T, string.format(
        'fixture clock moved: expected %.1f, got %s', FRAME_T, tostring(DotaTime())))
    assert(GetGameMode() == GAMEMODE_TURBO,
        'the gate is turbo-only, so the frame has to be a turbo frame')
end

----------------------------------------------------------------------
-- [W1] the corpus half this file does NOT have, asserted so it cannot
-- drift into a claim
----------------------------------------------------------------------

tests['[W1] no fixture carries a respawn time, so R is a declared stand-in'] = function()
    local _, bot = load_with(nil)
    -- Un-declared, the mock answers the Get* default. That default is the
    -- proof the dumper has no such field, and it is also why every R above is
    -- written down in the test rather than read off the frame.
    assert(bot:GetRespawnTime() == 0,
        'GetRespawnTime is absent from the dump; got ' .. tostring(bot:GetRespawnTime()))
    -- Archive-wide, on the FIELD not the substring: several fixtures carry a
    -- modifier literally named modifier_necrolyte_reapers_scythe_respawn_time,
    -- which is a buff on a hero, not a respawn clock.
    local n = 0
    local p = assert(io.popen("grep -l '[ ,{]respawn *=' tests/fixtures/*.lua 2>/dev/null"))
    for _ in p:lines() do n = n + 1 end
    p:close()
    assert(n == 0, 'a fixture started carrying a respawn field; use it instead of a stand-in')
end

----------------------------------------------------------------------
-- [lever] unarmed is the shipped expression; armed is the getter
----------------------------------------------------------------------

tests['[lever] unarmed, the helper reads R - 2e on every cell'] = function()
    local J, bot = load_with(nil)
    each_cell(bot, function(R, e, fDeath)
        assert(J.RespawnRemaining(bot, fDeath) == R - 2 * e, string.format(
            'unarmed should reproduce the double subtraction at R=%d e=%d; got %s',
            R, e, tostring(J.RespawnRemaining(bot, fDeath))))
        assert(J.RespawnRemaining(bot, fDeath) == shipped(bot, fDeath),
            string.format('unarmed drifted from the shipped body at R=%d e=%d', R, e))
    end)
end

tests['[lever] armed, the helper reads the engine value R - e on every cell'] = function()
    armed('bbrespawn', function(J, bot)
        each_cell(bot, function(R, e, fDeath)
            assert(J.RespawnRemaining(bot, fDeath) == R - e, string.format(
                'armed should hand back the engine value at R=%d e=%d; got %s',
                R, e, tostring(J.RespawnRemaining(bot, fDeath))))
        end)
    end)
end

tests['[lever] the gap between the two legs is exactly the elapsed time'] = function()
    local unarmedJ, unarmedBot = load_with(nil)
    local seen = {}
    each_cell(unarmedBot, function(R, e, fDeath)
        seen[R .. ':' .. e] = unarmedJ.RespawnRemaining(unarmedBot, fDeath)
    end)
    armed('bbrespawn', function(J, bot)
        each_cell(bot, function(R, e, fDeath)
            local gap = J.RespawnRemaining(bot, fDeath) - seen[R .. ':' .. e]
            assert(gap == e, string.format(
                'the error is one extra subtraction of the elapsed time; '
                .. 'R=%d e=%d gave a gap of %s', R, e, tostring(gap)))
        end)
    end)
end

----------------------------------------------------------------------
-- [defect] what the extra subtraction costs the buyback rule
----------------------------------------------------------------------

tests['[defect] the shipped reading crosses zero halfway through the death'] = function()
    local R = 40
    local J, bot = load_with(nil)
    -- Still dead for another R/2 seconds, and the number every buyback gate
    -- reads is already at zero.
    declare_respawn(bot, R, R / 2)
    assert(J.RespawnRemaining(bot, DotaTime() - R / 2) == 0,
        'the shipped reading should be 0 at e = R/2')
    declare_respawn(bot, R, R / 2 + 1)
    assert(J.RespawnRemaining(bot, DotaTime() - (R / 2 + 1)) < 0,
        'and negative past it, while the hero is still lying down')
    armed('bbrespawn', function(J2, bot2)
        declare_respawn(bot2, R, R / 2)
        assert(J2.RespawnRemaining(bot2, DotaTime() - R / 2) == R / 2,
            'armed, the reading is the R/2 seconds of waiting that are left')
    end)
end

tests['[defect] the ancient-defense window shrinks from R-20 to (R-20)/2'] = function()
    -- The one buyback branch turbo can reach gates on `> 20` (see [limit]).
    local R = 60
    local function opens(J, bot, e)
        declare_respawn(bot, R, e)
        return J.RespawnRemaining(bot, DotaTime() - e) > 20
    end
    local J, bot = load_with(nil)
    -- Unarmed the branch shuts at e = (R-20)/2 = 20; armed it stays open to
    -- e = R-20 = 40, which is what the threshold was written to mean.
    assert(opens(J, bot, 19), 'unarmed the branch is open just under (R-20)/2')
    assert(not opens(J, bot, 21), 'and shut just over it')
    armed('bbrespawn', function(J2, bot2)
        assert(opens(J2, bot2, 21), 'armed it is still open there')
        assert(opens(J2, bot2, 39), 'and all the way to R-20')
        assert(not opens(J2, bot2, 41), 'and shut past R-20, as written')
    end)
end

----------------------------------------------------------------------
-- [gate] armed by exactly one id, and only in turbo
----------------------------------------------------------------------

tests['[gate] another candidate does not arm this one'] = function()
    armed('abilanc', function(J, bot)
        declare_respawn(bot, 40, 10)
        local fDeath = DotaTime() - 10
        assert(J.RespawnRemaining(bot, fDeath) == shipped(bot, fDeath),
            'an unrelated armed id must leave this helper on the shipped body')
    end)
end

tests['[gate] with no soak file at all the helper is the shipped body'] = function()
    local J, bot = load_with(nil)
    declare_respawn(bot, 40, 10)
    local fDeath = DotaTime() - 10
    assert(J.RespawnRemaining(bot, fDeath) == shipped(bot, fDeath),
        'no gate file means shipped behaviour')
end

tests['[gate] the wrong side does not arm it either'] = function()
    -- The subject is radiant on this frame, so a dire-side wave must leave the
    -- shipped leg running for it.
    armed('bbrespawn', function(J, bot)
        assert(bot:GetTeam() == 2, 'the subject used to be radiant here')
        assert(J.IsSoakCandidate('bbrespawn'), 'radiant side arms it')
    end)
    armed('bbrespawn', function(J, bot)
        declare_respawn(bot, 40, 10)
        local fDeath = DotaTime() - 10
        assert(not J.IsSoakCandidate('bbrespawn'), 'dire side must not arm a radiant subject')
        assert(J.RespawnRemaining(bot, fDeath) == shipped(bot, fDeath),
            'and the helper stays on the shipped body')
    end, 'dire')
end

----------------------------------------------------------------------
-- [control] the two short circuits, on both legs
----------------------------------------------------------------------

tests['[control] a nil bot and a zero death time answer 0 on both legs'] = function()
    local J, bot = load_with(nil)
    declare_respawn(bot, 40, 10)
    assert(J.RespawnRemaining(nil, DotaTime() - 10) == 0, 'nil bot, unarmed')
    assert(J.RespawnRemaining(bot, 0) == 0, 'fDeathTime == 0, unarmed')
    armed('bbrespawn', function(J2, bot2)
        declare_respawn(bot2, 40, 10)
        assert(J2.RespawnRemaining(nil, DotaTime() - 10) == 0, 'nil bot, armed')
        assert(J2.RespawnRemaining(bot2, 0) == 0,
            'fDeathTime == 0 short circuits BEFORE the gate; armed must not '
            .. 'start reporting a respawn time for a hero that is alive')
    end)
end

----------------------------------------------------------------------
-- [source] the gate is one conjunct against a mode predicate
----------------------------------------------------------------------

tests['[source] the gate cannot be a structural zero leg (GH #207)'] = function()
    local body = read_file(JMZ)
    -- GH #207: a gate written as IsSoakCandidate('X') and IsSoakCandidate('Y')
    -- freezes FALSE the day Y is promoted, and the wiring check cannot see it.
    -- This one's other half is a MODE predicate, so it has no such partner.
    local fn = body:match('function J%.RespawnRemaining.-\nend')
    assert(fn ~= nil, 'J.RespawnRemaining lost its body')
    local gate = fn:match('\n\tif ([^\n]-IsSoakCandidate[^\n]-) then')
    assert(gate ~= nil, 'J.RespawnRemaining lost its gate line')
    assert(gate == "J.IsModeTurbo() and J.IsSoakCandidate( 'bbrespawn' )",
        'the gate line changed shape: ' .. tostring(gate))
    local _, n = body:gsub("IsSoakCandidate%(%s*'bbrespawn'%s*%)", '')
    assert(n == 1, 'exactly one resolution site for this id; got ' .. tostring(n))
end

tests['[source] the call site delegates, and the old expression is gone'] = function()
    local body = read_file(AIUG)
    assert(body:find('return J.RespawnRemaining( bot, fDeathTime )', 1, true),
        'X.GetRemainingRespawnTime no longer delegates to the helper')
    -- The comment above the call site quotes the old expression, so count only
    -- non-comment lines -- GH #193's lesson about ratchets that cannot tell a
    -- quotation from a call.
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then
            assert(not line:find('GetRespawnTime() - ( DotaTime()', 1, true),
                'the double subtraction is still live somewhere in this file')
        end
    end
end

----------------------------------------------------------------------
-- [limit] what this lever does NOT move, asserted so it cannot drift
-- into a claim -- and counted, so the next cell has a denominator
----------------------------------------------------------------------

tests['[limit] the sibling misreading of the same getter is untouched'] = function()
    local body = read_file(AIUG)
    -- `nFullRespawnTime` is the SAME getter read under the same wrong name.
    -- Under the documented semantics this line means "stop considering buyback
    -- once you are within a minute of respawning", not the intended "a short
    -- respawn is not worth buying out of". It gates the two branches BELOW it;
    -- this round's lever gates the branch ABOVE it.
    --
    -- RATCHET MOVED, NOT LOOSENED (GH #222). Its own round came: the sibling
    -- is behind 'bbshort' now. What this row exists to protect is unchanged --
    -- that THIS file's lever did not silently absorb the sibling -- so the pin
    -- follows it rather than being deleted, and gains the separability check
    -- the old literal could not express.
    assert(body:find('local nFullRespawnTime = bot:GetRespawnTime()', 1, true),
        'the sibling read moved; re-check whether this lever is still alone')
    assert(body:find('if nFullRespawnTime < J.BuybackShortRespawnFloor() then', 1, true),
        "the sibling gate is not behind 'bbshort' any more; the NEXT CELL note "
        .. 'in jmz_func is now stale')
    local jmz = read_file(JMZ)
    local fn = jmz:match('function J%.RespawnRemaining.-\nend')
    assert(fn ~= nil and not fn:find('bbshort', 1, true),
        "this file's helper picked up the sibling id; the two must stay separable")
end

tests['[limit] the consumers of this number, counted'] = function()
    local body = read_file(AIUG)
    local n = 0
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') and line:find('nRemainingRespawnTime', 1, true) then
            n = n + 1
        end
    end
    -- One assignment plus the three thresholds the helper moves (> 20, > 80,
    -- < 40). If the tree grows a fourth, this fails rather than the report
    -- going quietly stale about which gates the fix touches.
    assert(n == 4, 'readers of nRemainingRespawnTime; got ' .. tostring(n))
end

return tests
