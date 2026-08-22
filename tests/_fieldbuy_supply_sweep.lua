-- Corpus sweep helper for tests/test_replay_260822_fieldbuy_supply.lua.
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$' and
-- this file is meant to be run in its own process by that test via io.popen
-- (strategy charter 0q: driving the whole corpus through a big shipped file
-- inside the suite's own process churns GC on a heap a thousand earlier tests
-- have already grown, and the cost then depends on where the calling file
-- lands in the alphabet).
--
-- Usage: lua5.1 tests/_fieldbuy_supply_sweep.lua
-- Emits machine-readable lines on stdout:
--   COUNT fixtures=<n> live=<n> band=<n> band_dry=<n> situation=<n>
--         has=<n> dry=<n> unarmed=<n>
--   HOLE laning=<n> level6plus=<n> both=<n> hpceil=<n>
--   DRY <fixture> <hero> <hp> <level> <laning 0|1>
--
-- Every number here is read off the SHIPPED helpers running on real frames.
-- The buckets are a partition by construction (situation == has + dry) and the
-- calling test asserts that, so the two halves of owner priority P2 cannot
-- silently drift apart.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

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

local n = {
    live = 0, band = 0, band_dry = 0, situation = 0,
    has = 0, dry = 0, unarmed = 0,
}
local hole = { laning = 0, level6plus = 0, both = 0, hpceil = 0 }
local dry_rows = {}

local files = fixture_files()

for _, path in ipairs(files) do
    -- One load to learn the roster, then one load per hero so each subject
    -- drives its own frame (the loader rebuilds vision from that hero's team).
    local ok0, names = pcall(function()
        local _, _, heroes = rf.load('tests/fixtures/' .. path)
        local out = {}
        for name in pairs(heroes) do out[#out + 1] = name end
        table.sort(out)
        return out
    end)
    if not ok0 then
        io.write('ERR ' .. path .. ' roster ' .. tostring(names) .. '\n')
        names = {}
    end

    for _, hero in ipairs(names) do
        local ok, err = pcall(function()
            local J, bot = rf.load('tests/fixtures/' .. path, hero)
            if bot == nil or not bot:IsAlive() then return end
            n.live = n.live + 1

            -- Nothing armed: the gate must be shut on every single frame.
            J.IsSoakCandidate = function() return false end
            if J.ShouldFieldBuyRegen(bot) then n.unarmed = n.unarmed + 1 end

            J.IsSoakCandidate = function(id) return id == 'fieldbuy' end

            local nHP = J.GetHP(bot)
            local bHas = J.HasFieldRegenSource(bot) == true
            local bSit = J.IsFieldRegenSituation(bot) == true

            if nHP >= 0.18 and nHP <= 0.55 then
                n.band = n.band + 1
                if not bHas then n.band_dry = n.band_dry + 1 end
            end

            if bSit then
                n.situation = n.situation + 1
                if bHas then
                    n.has = n.has + 1
                else
                    n.dry = n.dry + 1
                    local bLaning = J.IsInLaningPhase() == true
                    local nLevel = bot:GetLevel()
                    if bLaning then hole.laning = hole.laning + 1 end
                    if nLevel >= 6 then hole.level6plus = hole.level6plus + 1 end
                    if bLaning and nLevel >= 6 then hole.both = hole.both + 1 end
                    if nHP >= 0.45 then hole.hpceil = hole.hpceil + 1 end
                    dry_rows[#dry_rows + 1] = string.format(
                        'DRY %s %s %.4f %d %d',
                        path, hero, nHP, nLevel, bLaning and 1 or 0)
                end
            end
        end)
        if not ok then
            io.write('ERR ' .. path .. ' ' .. hero .. ' ' .. tostring(err) .. '\n')
        end
    end
end

io.write(string.format(
    'COUNT fixtures=%d live=%d band=%d band_dry=%d situation=%d has=%d dry=%d unarmed=%d\n',
    #files, n.live, n.band, n.band_dry, n.situation, n.has, n.dry, n.unarmed))
io.write(string.format('HOLE laning=%d level6plus=%d both=%d hpceil=%d\n',
    hole.laning, hole.level6plus, hole.both, hole.hpceil))
for _, l in ipairs(dry_rows) do io.write(l .. '\n') end
