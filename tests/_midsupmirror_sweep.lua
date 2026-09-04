-- Heavy corpus sweep for tests/test_midsupmirror_checkability.lua, run as a
-- SUBPROCESS (backlog 0q: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame must not run on run_tests.lua's long-lived heap). The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  test_set.md §EF.7 registered FOUR members that the
-- J.HasAvailableSupportResponder mirror "could ask and does not":
--   J.IsGoingOnSomeone / J.CanEnemyInterruptTpChannel / the 15s fresh-respawn
--   window / the 45s bRepeatFront memory
-- and sorted them on ASKABILITY BY THE ENGINE, which puts all four in one
-- bucket. This census asks the other question -- CHECKABILITY ON THE CORPUS:
-- for each leg, can any corpus frame make it say anything at all?
--
-- It also re-measures the previous round's own headline domain. That sweep read
-- the helper through `pcall(...)` and, having no third bucket, counted a RAISE
-- as "did not fire". The `X` records below split the two apart.
--
-- Every threshold is PARSED OUT OF THE SHIPPED SOURCE, never hardcoded (the M13
-- lesson): move a number in jmz_func and this census must move with it.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   X <fixture> <hero>  one live frame where J.ShouldTpSupportTowerFight RAISED
--   D <fixture> <core> <support> <mode> <int> <resp> <front>
--       one support the SHIPPED predicate accepts on a core's firing frame,
--       with what each of the four unrepaired legs answers about it
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction J.', at + 10) or #src
    return src:sub(at, stop)
end

-- The four legs, as the RESPONDER LOOP spells them, and whether the MIRROR
-- carries them. Parsed, so "still short" is a fact about the tree, not prose.
local G = {}
local src = read_file(JMZ)
local loop = block(src, 'function J.ShouldTpSupportTowerFight( bot )')
local mirror = block(src, 'function J.HasAvailableSupportResponder( bot, hBuilding )')
local interrupt = block(src, 'function J.CanEnemyInterruptTpChannel( bot )')
G.LOOP = loop and 1 or 0
G.MIRROR = mirror and 1 or 0
local LEGS = { 'IsGoingOnSomeone', 'CanEnemyInterruptTpChannel',
    'lastRespawnTime', 'lastFrontAnswerT' }
for _, leg in ipairs(LEGS) do
    G['LOOP_' .. leg] = (loop and loop:find(leg, 1, true)) and 1 or 0
    G['MIRROR_' .. leg] = (mirror and mirror:find(leg, 1, true)) and 1 or 0
end
-- The narrow radius CanEnemyInterruptTpChannel scans when 'tpreach' is not
-- armed -- i.e. the radius that defines that leg's own domain.
G.INT_R = interrupt and tonumber(interrupt:match("bWide and %d+ or (%d+)")) or nil
G.FRESH_RESPAWN_S = loop and tonumber(loop:match('lastRespawnTime or %-999 %) < (%d+%.?%d*)'))
G.REPEAT_FRONT_S = loop and tonumber(loop:match('bot%.lastFrontAnswerT < (%d+%.?%d*)'))

local gk = {}
for k in pairs(G) do gk[#gk + 1] = k end
table.sort(gk)
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end
-- Zero-initialised so "the bucket was never reached" and "the bucket measured
-- zero" are never the same thing to the parser (the GH #171 shape).
for _, k in ipairs({ 'fixtures', 'live', 'fires', 'fires_core', 'trigger_raised',
    'mode_readable', 'mode_default', 'mode_nondefault', 'mode_would_veto',
    'int_false', 'int_true', 'int_raised', 'int_in_domain', 'int_in_domain_raised',
    'respawn_field', 'front_field', 'sup_accepted', 'sup_int_false',
    'sup_int_true', 'sup_int_raised', 'int_raised_sloc', 'trigger_raised_sloc',
    'shipped_disagrees' }) do
    rawset(c, k, 0)
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    J.IsSoakCandidate = function(id) return id == 'midtp' end

                    -- ---- leg 1: the active mode (J.IsGoingOnSomeone reads it)
                    local okm, mode = pcall(function() return bot:GetActiveMode() end)
                    if okm then
                        bump('mode_readable')
                        if mode == nil or mode == 0 then bump('mode_default')
                        else bump('mode_nondefault') end
                        local okg, going = pcall(J.IsGoingOnSomeone, bot)
                        if okg and going then bump('mode_would_veto') end
                    end

                    -- ---- leg 2: the TP-channel interrupt guard.  Its own
                    -- domain is "an enemy hero inside the narrow scan" -- the
                    -- helper early-returns false outside it, so a false there
                    -- is the guard abstaining, not the guard answering.
                    local okn, near = pcall(J.GetNearbyHeroes, bot, G.INT_R or 700,
                        true, BOT_MODE_NONE)
                    local bInDomain = okn and near ~= nil and #near > 0
                    if bInDomain then bump('int_in_domain') end
                    local oki, itp = pcall(J.CanEnemyInterruptTpChannel, bot)
                    if not oki then
                        bump('int_raised')
                        if bInDomain then bump('int_in_domain_raised') end
                        -- One cause, or several? A single shared signature is
                        -- what lets one instrument repair unblock all of them.
                        if tostring(itp):find("index local 'sLoc'", 1, true) then
                            bump('int_raised_sloc')
                        end
                    elseif itp then bump('int_true')
                    else bump('int_false') end

                    -- ---- legs 3 and 4: per-bot session memory, written by the
                    -- mode scripts ACROSS frames.  A one-frame fixture carries
                    -- no such history; count how often it is nonetheless there.
                    if rawget(bot, 'lastRespawnTime') ~= nil
                        or rawget(bot, 'lastDeadFrameTime') ~= nil then
                        bump('respawn_field')
                    end
                    if rawget(bot, 'lastFrontAnswerT') ~= nil then bump('front_field') end

                    -- ---- the decision domain, and the third bucket the
                    -- previous sweep did not have.
                    local okc, building = pcall(J.ShouldTpSupportTowerFight, bot)
                    if not okc then
                        bump('trigger_raised')
                        if tostring(building):find("index local 'sLoc'", 1, true) then
                            bump('trigger_raised_sloc')
                        end
                        out:write(string.format('X %s %s\n',
                            path:match('([^/]+)%.lua$'), u.name))
                    elseif building ~= nil then
                        bump('fires')
                        if J.IsCore(bot) then
                            bump('fires_core')
                            -- The mirror's member list, re-run here as a SHADOW
                            -- so each accepted support can be NAMED. Restricting
                            -- the team instead was tried and is wrong: several
                            -- members (J.GetPosition among them) rank the whole
                            -- roster, so a one-ally team changes the answer it
                            -- is supposed to be reporting. The `shipped` column
                            -- re-asks the real predicate over the real team and
                            -- the test asserts the two agree -- otherwise this
                            -- census would be measuring only itself.
                            local nAcc = 0
                            local tP = GetTeamPlayers(GetTeam()) or {}
                            for i = 1, #tP do
                                local hAlly = GetTeamMember(i)
                                if hAlly ~= nil and hAlly ~= bot
                                    and J.IsValidHero(hAlly)
                                    and hAlly:IsAlive()
                                    and J.GetPosition(hAlly) >= 4
                                    and hAlly:GetLevel() >= 6
                                    and not J.IsInTeamFight(hAlly, 1600)
                                    and not J.IsRetreating(hAlly)
                                    and GetUnitToUnitDistance(hAlly, building)
                                        > J.TP_RESPONSE_FAR_FLOOR then
                                    local tp = J.GetItem2(hAlly, 'item_tpscroll')
                                    local bt = J.GetItem2(hAlly, 'item_travel_boots')
                                    if (tp ~= nil and tp:IsFullyCastable())
                                        or (bt ~= nil and bt:IsFullyCastable()) then
                                        nAcc = nAcc + 1
                                        bump('sup_accepted')
                                        local okam, amode =
                                            pcall(function() return hAlly:GetActiveMode() end)
                                        local okai, aitp =
                                            pcall(J.CanEnemyInterruptTpChannel, hAlly)
                                        if not okai then bump('sup_int_raised')
                                        elseif aitp then bump('sup_int_true')
                                        else bump('sup_int_false') end
                                        out:write(string.format('D %s %s %s %s %s %s %s\n',
                                            path:match('([^/]+)%.lua$'), u.name,
                                            hAlly:GetUnitName(),
                                            okam and tostring(amode) or 'raise',
                                            okai and tostring(aitp) or 'raise',
                                            tostring(rawget(hAlly, 'lastRespawnTime')),
                                            tostring(rawget(hAlly, 'lastFrontAnswerT'))))
                                    end
                                end
                            end
                            if J.HasAvailableSupportResponder(bot, building)
                                ~= (nAcc > 0) then
                                bump('shipped_disagrees')
                            end
                        end
                    end
                end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')
