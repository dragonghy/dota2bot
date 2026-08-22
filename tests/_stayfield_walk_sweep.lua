-- Corpus sweep helper for tests/test_replay_260822_lina_walk_home.lua.
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$', and
-- this file is meant to be run in its own process by that test via io.popen.
-- The reason is the 2026-08-21 measurement recorded in the strategy charter
-- (0q): driving the whole fixture corpus through a big shipped file inside the
-- suite's own process churns GC on a heap already grown by a thousand earlier
-- tests, and the cost then depends on where the calling file lands in the
-- alphabet. In a fresh subprocess this sweep is ~5 seconds flat.
--
-- Usage: lua5.1 tests/_stayfield_walk_sweep.lua
-- Emits machine-readable lines on stdout:
--   COUNT fixtures=<n> live=<n> fires=<n> moved=<n>
--   FIRE <fixture> <hp> <bid_off> <bid_on>
--   READING <fixture> <byname_off> <byname_on> <honest_off> <honest_on>

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

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

local RETREAT = 'bots/mode_retreat_generic.lua'

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

--- Install a fixture world. `armed` is the soak id to arm, or nil for none.
--- `honest` additionally gives the world the game mode the engine would have
--- given it (GH #93 / the fifteenth world assertion: by name the fixture world
--- is Turbo, by the literal 23 it is not). The probe is cleared on every entry
--- so it can never follow this sweep out of the loop.
local function world(path, armed, honest)
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load('tests/fixtures/' .. path)
    for k, v in pairs(DESIRE) do _G[k] = v end
    -- Per-lane push/defend desire is engine state, not a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    -- GH #61: the loader refuses GetLaneFrontLocation; declared explicitly so
    -- the mode file can be driven at all. The calling test measures that the
    -- retreat bid does not depend on where it points.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    -- GH #91 / the fourteenth world assertion: declare that nobody pinged
    -- defence recently, rather than letting the lazily-initialised stamp read
    -- its own initialiser. The calling test measures that this one is not
    -- load-bearing for the retreat bid either.
    J.Utils['GameStates'] = J.Utils['GameStates'] or {}
    J.Utils['GameStates']['defendPings'] = { pingedTime = -1000 }
    if honest then
        GAMEMODE_TURBO = 23                      -- luacheck: ignore
        GetGameMode = function() return 23 end   -- luacheck: ignore
    end
    J.IsSoakCandidate = function(id) return armed ~= nil and id == armed end
    return J, bot
end

local function unprobe()
    GAMEMODE_TURBO = nil                                  -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end    -- luacheck: ignore
end

local function retreat_bid()
    GetDesire, Think = nil, nil -- luacheck: ignore
    local ok = pcall(dofile, RETREAT)
    local out = 'CRASH'
    if ok and type(GetDesire) == 'function' then
        local ok2, d = pcall(GetDesire)
        if ok2 and type(d) == 'number' then out = d end
    end
    GetDesire, Think = nil, nil -- luacheck: ignore
    return out
end

local files = fixture_files()
local nLive, nFire, nMoved = 0, 0, 0
local fires = {}

for _, path in ipairs(files) do
    local ok, err = pcall(function()
        local J, bot = world(path, 'stayfield2', false)
        if bot == nil or not bot:IsAlive() then return end
        nLive = nLive + 1
        local bFire = J.ShouldRegenNotGoHome(bot) == true
        local nHP = bot:GetHealth() / bot:GetMaxHealth()
        local bidOn = retreat_bid()
        world(path, nil, false)
        local bidOff = retreat_bid()
        if bFire then
            nFire = nFire + 1
            fires[#fires + 1] = string.format('FIRE %s %.4f %s %s',
                path, nHP, tostring(bidOff), tostring(bidOn))
        end
        if tostring(bidOn) ~= tostring(bidOff) then nMoved = nMoved + 1 end
    end)
    if not ok then io.write('ERR ' .. path .. ' ' .. tostring(err) .. '\n') end
    unprobe()
end

io.write(string.format('COUNT fixtures=%d live=%d fires=%d moved=%d\n',
    #files, nLive, nFire, nMoved))
for _, l in ipairs(fires) do io.write(l .. '\n') end

-- The two pinned frames under both game-mode readings. The fifteenth world
-- assertion measured that 18 of 96 fixtures change their winning mode when the
-- world is read honestly, so "which reading is this bid from" is a real
-- question and is answered here rather than assumed.
for _, path in ipairs({ 'f_260822_063722_lina_tp_home.lua',
                        'f_260822_063559_slardar_tp_forward.lua' }) do
    local out = {}
    for _, honest in ipairs({ false, true }) do
        world(path, nil, honest)
        out[#out + 1] = tostring(retreat_bid())
        world(path, 'stayfield2', honest)
        out[#out + 1] = tostring(retreat_bid())
        unprobe()
    end
    io.write(string.format('READING %s %s %s %s %s\n', path, out[1], out[2], out[3], out[4]))
end
