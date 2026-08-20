-- [defstale] DefendThink's "don't walk through fire" bail-out compares a
-- quantity against an older copy of itself.
--
-- The source's own comment (typescript/bots/FunLib/aba_defend.ts:901) calls it
-- "a small don't-walk-through-fire guard": more enemies on my PATH than IN
-- RANGE means step back. But both sides are the SAME query --
-- `jmz.GetLastSeenEnemiesNearLoc(botLocation, 1600)`:
--
--   * `pathEnemies` is that query, bucketed to 500ms on the bot handle;
--   * `ds.nInRangeEnemy` is that query, written at the BOTTOM of
--     GetDefendDesireHelper -- below SEVEN early returns. One of them,
--       #closeEnemiesDefend > 0 and #closeAlliesDefend >= #closeEnemiesDefend
--     fires on exactly the frames DefendThink runs on, i.e. whenever a fight is
--     happening within 900 of the bot. `bot._defend` is never reset, so during a
--     fight the right-hand side freezes at whatever it held before the fight
--     started -- or, if no helper call ever reached the bottom, at the initial
--     empty table (0).
--
-- So the comparison is never a path/range difference; it is bought entirely by
-- that staleness. When it is true the bot walks 700 back toward its fountain and
-- `return`s, abandoning every other DefendThink branch for the frame.
--
-- REAL FRAME: f_260819_223607_drow_defend_bail -- game 20260819_223607_slot1 at
-- t=330.4 (5:30). Subject drow_ranger (Dire), 609/780 hp (78%), standing 929u
-- from its own 56%-hp top tier-1 tower, last hit by ogre_magi 3.8s earlier, with
-- exactly ONE enemy (necrolyte) inside 1600. GROUND TRUTH from the replay: the
-- drow stayed -- it last-hit a creep at t=332.6, took 120 xp at t=336.9, put
-- 254 damage into ogre_magi between t=338.0 and t=339.9, and did not die for
-- another 42.5 seconds. Stepping back toward the fountain was the wrong call on
-- this frame, and it was not chosen for any reason a reader of the guard would
-- recognise.
--
-- CONTROL FRAME: f_260819_222526_jakiro_defend_fresh -- game
-- 20260819_222526_slot1 at t=358.5. Same lane, same shape, one difference that
-- matters: TWO enemies within 900 against one ally, so the helper does NOT take
-- the early return, reaches the bottom, and writes a live nInRangeEnemy. There
-- the guard is honestly false and armed must be a byte-for-byte no-op.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local BAIL = 'tests/fixtures/f_260819_223607_drow_defend_bail.lua'
local FRESH = 'tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- any arithmetic on desire constants (same reason as
-- tests/test_roamstale_collapse_action.lua).
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

--- Load a real frame with the real aba_defend module on top of it.
---   opts.armed  -- arm 'defstale' (nothing else is ever armed)
---   opts.turbo  -- set false to make J.IsModeTurbo() report a non-turbo game
local function world(path, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end

    J.IsSoakCandidate = function(id)
        return id == 'defstale' and opts.armed == true
    end
    if opts.turbo == false then
        J.IsModeTurbo = function() return false end
    end

    -- Per-lane push/defend desire is engine state, never a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    return J, bot, heroes, fx, Defend
end

--- One engine frame: bid all three defend lanes (which is what writes
--- ds.nInRangeEnemy when it gets that far), then run the winner's Think.
local function frame(path, opts)
    local J, bot, heroes, fx, Defend = world(path, opts)
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        Defend.GetDefendDesire(bot, lane)
    end
    local log = rf.record_actions(bot)
    Defend.DefendThink(bot, LANE_MID)
    return log, J, bot, heroes, fx, Defend
end

local function dist2d(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- ---------------------------------------------------------------------------
-- The frame itself. Every premise the defect rests on is asserted.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: a 78%-hp defender, under fire, one enemy inside 1600'] = function()
    local J, bot, heroes, fx = world(BAIL)
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(math.abs(fx.time - 330.4) < 1e-6, 'frame is t=330.4; got ' .. tostring(fx.time))
    assert(bot:GetHealth() == 609 and bot:GetMaxHealth() == 780,
        'subject is 609/780; got ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth())
    assert(bot:WasRecentlyDamagedByAnyHero(5),
        'the guard needs the under-fire half to be true on this frame')
    assert(not bot:WasRecentlyDamagedByAnyHero(3),
        'the last hero hit was 3.8s ago -- so the bail-out is bought by a memory, '
        .. 'not by damage landing right now')
    local here = bot:GetLocation()
    local near = J.GetLastSeenEnemiesNearLoc(here, 1600)
    assert(#near == 1, 'exactly one enemy inside 1600; got ' .. #near)
    local necro = heroes['npc_dota_hero_necrolyte']
    local d = dist2d(here, necro:GetLocation())
    assert(d > 800 and d < 900,
        'that enemy is the necrolyte at ~861u; got ' .. string.format('%.0f', d))
    assert(fx.observed and fx.observed.died_after == 42.5,
        'GROUND TRUTH: the subject survived another 42.5s after this frame; got '
        .. tostring(fx.observed and fx.observed.died_after))
end

tests['MECHANISM: the helper early-returns, so nInRangeEnemy is never written'] = function()
    local J, bot, _, _, Defend = world(BAIL)
    -- The early return that does it, asserted from the frame rather than assumed.
    local closeE = J.GetEnemiesNearLoc(bot:GetLocation(), 900)
    local closeA = J.GetAlliesNearLoc(bot:GetLocation(), 900)
    assert(#closeE > 0 and #closeA >= #closeE,
        'the `enemies within 900 and we are not outnumbered` early return must be '
        .. 'live here: got ' .. #closeE .. ' enemies vs ' .. #closeA .. ' allies')
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        local d = Defend.GetDefendDesireHelper(bot, lane)
        assert(math.abs(d - 0.3) < 1e-9,
            'every lane must take that early return (0.3); lane ' .. tostring(lane)
            .. ' returned ' .. tostring(d))
    end
    local ds = rawget(bot, '_defend')
    assert(#ds.nInRangeEnemy == 0,
        'so the right-hand side of the guard is still the initial empty table; got '
        .. #ds.nInRangeEnemy)
    -- ...while the left-hand side, the SAME query, is 1.
    assert(#J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600) == 1,
        'the identical query answers 1 on this very frame -- the difference between '
        .. 'the two sides is time, not meaning')
end

tests['REACHABLE: defend wins the script mode auction on this frame'] = function()
    local _, bot = world(BAIL)
    local best, bestName, defend = -1, 'none', -1
    local p = io.popen('ls bots/mode_*.lua')
    for path in p:lines() do
        GetDesire = nil -- luacheck: ignore
        local ok = pcall(dofile, path)
        if ok and type(GetDesire) == 'function' then
            local ok2, d = pcall(GetDesire)
            if ok2 and type(d) == 'number' then
                if path:find('defend_tower') and d > defend then defend = d end
                if d > best then best, bestName = d, path end
            end
        end
    end
    p:close()
    assert(defend >= 0, 'the defend modes must produce a number here')
    assert(defend >= best,
        'DefendThink only runs if a defend mode wins; best was ' .. bestName
        .. ' at ' .. string.format('%.2f', best) .. ' vs defend '
        .. string.format('%.2f', defend))
    -- LIMITATION, stated rather than hidden: the .dem carries no per-frame mode
    -- (GH #27) and the engine's own built-in modes have no script GetDesire, so
    -- this auction covers the SCRIPT modes only. It is a necessary condition for
    -- reachability, not a proof that the engine picked defend.
    assert(bot ~= nil)
end

-- ---------------------------------------------------------------------------
-- The defect.
-- ---------------------------------------------------------------------------

tests['DEFECT: shipped, the defender steps back toward its fountain'] = function()
    local log, J, bot = frame(BAIL)
    assert(#log == 1,
        'the bail-out returns immediately, so it is the only action of the frame; got '
        .. #log)
    assert(log[1].fn == 'Action_MoveToLocation',
        'expected the step-back move; got ' .. log[1].fn)
    local here, target = bot:GetLocation(), log[1].args[1]
    local step = dist2d(here, target)
    assert(step > 700 - 130 and step < 700 + 130,
        'the step is the guard\'s 700 plus its 120 jitter; got '
        .. string.format('%.0f', step))
    local fountain = J.GetTeamFountain()
    assert(dist2d(target, fountain) < dist2d(here, fountain),
        'and it points at our own fountain -- away from the tower being defended')
end

tests['FIX: armed, the frame is no longer spent walking backwards'] = function()
    local log = frame(BAIL, { armed = true })
    for _, a in ipairs(log) do
        assert(a.fn ~= 'Action_MoveToLocation',
            'armed, the staleness bail-out must not fire; still saw ' .. a.fn)
    end
end

tests['the fix is turbo-only'] = function()
    local log = frame(BAIL, { armed = true, turbo = false })
    assert(#log == 1 and log[1].fn == 'Action_MoveToLocation',
        'outside turbo the armed candidate must be inert, so the shipped bail-out '
        .. 'still fires')
end

-- ---------------------------------------------------------------------------
-- Separability: armed may only ever REMOVE this one action.
-- ---------------------------------------------------------------------------

tests['CONTROL: where the helper does reach the bottom, armed is a no-op'] = function()
    local J, bot, _, fx, Defend = world(FRESH)
    assert(math.abs(fx.time - 358.5) < 1e-6, 'control frame is t=358.5')
    local closeE = J.GetEnemiesNearLoc(bot:GetLocation(), 900)
    local closeA = J.GetAlliesNearLoc(bot:GetLocation(), 900)
    assert(#closeE > #closeA,
        'this frame must be outnumbered inside 900 so the early return is skipped; '
        .. 'got ' .. #closeE .. ' vs ' .. #closeA)
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        Defend.GetDefendDesire(bot, lane)
    end
    local ds = rawget(bot, '_defend')
    assert(#ds.nInRangeEnemy == #J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600),
        'with the bottom reached, the two sides agree exactly -- that is the whole '
        .. 'point: they are the same query')
    assert(bot:WasRecentlyDamagedByAnyHero(5),
        'the under-fire half is still true here, so only the count separates the '
        .. 'control from the defect frame')

    local shipped = frame(FRESH)
    local armed = frame(FRESH, { armed = true })
    assert(#shipped == #armed, 'armed must not change the action count on a frame '
        .. 'where the guard was honestly false; ' .. #shipped .. ' vs ' .. #armed)
    for i = 1, #shipped do
        assert(shipped[i].fn == armed[i].fn,
            'action ' .. i .. ' differs: ' .. shipped[i].fn .. ' vs ' .. armed[i].fn)
    end
    assert(#shipped >= 1 and shipped[1].fn ~= 'Action_MoveToLocation',
        'and the control frame must not be a step-back at all; got '
        .. (shipped[1] and shipped[1].fn or 'nothing'))
end

-- ---------------------------------------------------------------------------
-- Reverse assertions: if somebody repairs this properly, this file must say so.
-- ---------------------------------------------------------------------------

tests['REVERSE: both sides of the guard are still the same query'] = function()
    local src = io.open('bots/FunLib/aba_defend.lua'):read('*a')
    local n = select(2, src:gsub('GetLastSeenEnemiesNearLoc', ''))
    assert(n >= 2, 'expected the query to appear on both sides; got ' .. n)
    assert(src:find('pathEnemies = jmz.GetLastSeenEnemiesNearLoc(botLocation, 1600)', 1, true),
        'the PATH side is still that query taken at the bot\'s own location -- if it '
        .. 'has been re-pointed at the defend location, the defect is fixed properly '
        .. 'and this whole file must be re-derived')
    assert(src:find('ds.nInRangeEnemy = jmz.GetLastSeenEnemiesNearLoc(', 1, true),
        'the RANGE side is still that same query')
end

tests['REVERSE: the gate is a pure removal, not a new bid or a new action'] = function()
    local src = io.open('bots/FunLib/aba_defend.lua'):read('*a')
    local n = select(2, src:gsub("IsSoakCandidate%(\"defstale\"%)", ''))
    assert(n == 1, 'defstale must have exactly one call site in aba_defend; got ' .. n)
    local guard = src:match('\n([^\n]*bStaleBail[^\n]*=[^\n]*)\n')
    assert(guard and guard:find('IsModeTurbo', 1, true),
        'the candidate must stay turbo-gated; got: ' .. tostring(guard))
end

return tests
