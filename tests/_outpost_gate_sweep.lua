-- Corpus half of the `outlatch` reading (GH #373). NOT a test: the runner only
-- picks up `test_*.lua`, and this file is a measuring instrument, not an
-- assertion. Run it by hand:
--
--     lua5.1 tests/_outpost_gate_sweep.lua
--
-- It answers the two questions that decide how much of mode_outpost_generic
-- this repo has ever been able to look at:
--
--   (A) On how many pinned frames is `IsEnemyTier2Down` true -- i.e. does the
--       mode's body below that early return execute at all?
--   (B) How many outposts does GetUnitList(UNIT_LIST_ALL) carry?
--
-- Reading as of 2026-08-31 (107 fixtures):
--
--   (A) 43 / 107 frames report "enemy tier-2 down", and that set is EQUAL --
--       not merely close -- to the set of fixtures that carry NO building
--       table at all. On those the loader's GetTower answers nil for every
--       slot, so "tier-2 is down" is a harness fact. On all 64 frames that DO
--       carry a building table, every enemy tier-2 tower stands, so the mode
--       returns at that line and everything below it -- the outpost sweep, the
--       latch, GetClosestOutpost, the whole of Think and its continuous
--       Action_AttackUnit at :117 -- is unreachable on every structure-bearing
--       frame in this repo.
--   (B) 0 outposts in 993 UNIT_LIST_ALL entries. UNMEASURABLE, not EMPTY:
--       tests/mock/replay_fixture.lua declares in its own comment that it
--       injects neither creeps nor structures into UNIT_LIST_ALL.
--
-- Print goes to stderr on purpose -- tests/mock/bot_api.lua stubs `print` to a
-- no-op (bot-side print never reaches the server console), so a sweep that
-- used print would exit 0 having said nothing.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

local function say(s) io.stderr:write(s .. '\n') end

local files = {}
local p = io.popen('ls tests/fixtures/f_*.lua')
for l in p:lines() do files[#files + 1] = l end
p:close()

local n_ok, n_err = 0, 0
local n_units, n_outposts = 0, 0
local t2_down, no_buildings = {}, {}

for _, f in ipairs(files) do
    local src = io.open(f):read('*a')
    if not src:find('buildings = {', 1, true) then no_buildings[f] = true end

    local ok = pcall(function()
        local _, bot = rf.load(f)
        assert(bot ~= nil, 'no subject')
        local opp = GetOpposingTeam()
        if GetTower(opp, TOWER_TOP_2) == nil
        or GetTower(opp, TOWER_MID_2) == nil
        or GetTower(opp, TOWER_BOT_2) == nil
        then
            t2_down[f] = true
        end
        for _, u in ipairs(GetUnitList(UNIT_LIST_ALL)) do
            n_units = n_units + 1
            local nm = u:GetUnitName()
            if nm == '#DOTA_OutpostName_North' or nm == '#DOTA_OutpostName_South' then
                n_outposts = n_outposts + 1
            end
        end
        n_ok = n_ok + 1
    end)
    if not ok then n_err = n_err + 1 end
end

local function size(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local only_t2, only_nb, both = 0, 0, 0
for f in pairs(t2_down) do
    if no_buildings[f] then both = both + 1 else only_t2 = only_t2 + 1 end
end
for f in pairs(no_buildings) do if not t2_down[f] then only_nb = only_nb + 1 end end

say(string.format('fixtures=%d loaded=%d err=%d', #files, n_ok, n_err))
say(string.format('(A) enemy-tier-2-down frames        = %d / %d', size(t2_down), n_ok))
say(string.format('    fixtures with NO building table = %d', size(no_buildings)))
say(string.format('    set difference: t2-only=%d  no-buildings-only=%d  both=%d',
    only_t2, only_nb, both))
say(string.format('    => the mode is reachable on %d structure-bearing frame(s)', only_t2))
say(string.format('(B) UNIT_LIST_ALL entries=%d  outpost entries=%d', n_units, n_outposts))
