-- Corpus domain census for the STRATEGY group's posture family, run as a
-- SUBPROCESS (backlog 0q: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame must not run on run_tests.lua's long-lived heap). The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- WHY THIS EXISTS.  The charter's next slot demands a `bots/` lever from this
-- group's own scope (TP discipline / support arbitration / push-defend posture)
-- and demands the domain be PRICED FIRST -- 0GRENHARASS/0PINEVADE both ended in
-- "priced, then refused" because the lever's domain measured 0.  The TP legs
-- were priced at 0 by §EH (they read cross-frame bot-VM state a one-frame
-- fixture cannot carry).  The three POSTURE helpers read only world state --
-- hero positions, HP, buildings, ancients -- which is exactly what a fixture
-- frame carries as ground truth, so they are the family members a corpus CAN
-- witness.  This census says by how much.
--
-- Every threshold is PARSED OUT OF THE SHIPPED SOURCE, never hardcoded (the M13
-- lesson): move a number in jmz_func and this census must move with it.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <what>   one live frame in a named domain
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

local G = {}
local src = read_file(JMZ)
local push = block(src, 'function J.ShouldAbortDeepSoloPush( bot )')
local dive = block(src, 'function J.ShouldPunishDive( bot )')
local chase = block(src, 'function J.ShouldPunishOverchase( bot )')
G.PUSH = push and 1 or 0
G.DIVE = dive and 1 or 0
G.CHASE = chase and 1 or 0
-- pushguard's three numbers, in the order the source states them.
G.PUSH_DEPTH = push and tonumber(push:match('nDepth <= (%d+)'))
G.PUSH_ALLY_R = push and tonumber(push:match('GetNearbyHeroes%( bot, (%d+), false'))
G.PUSH_ENEMY_R = push and tonumber(push:match('GetNearbyHeroes%( bot, (%d+), true'))
G.PUSH_DEFENDERS = push and tonumber(push:match('nDefenders >= (%d+)'))
-- the dive/overchase domain radii
G.DIVE_COLLAPSE_R = dive and tonumber(dive:match('GetNearbyHeroes%( bot, (%d+), true'))
G.DIVE_BUILDING_R = dive and tonumber(dive:match('building %) <= (%d+)'))
G.DIVE_OWNHALF = dive and tonumber(dive:match('nInvadeDepth >= (%d+)'))
G.CHASE_COLLAPSE_R = chase and tonumber(chase:match('GetNearbyHeroes%( bot, (%d+), true'))
G.CHASE_ISOLATED_R = chase and tonumber(chase:match('GetEnemiesNearLoc%( vEnemyLoc, (%d+) %)'))
G.CHASE_ALLY_R = chase and tonumber(chase:match('GetAlliesNearLoc%( vEnemyLoc, (%d+) %)'))
G.CHASE_LOW_HP = chase and tonumber(chase:match('GetHP%( ally %) < (0%.%d+)'))

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
for _, k in ipairs({ 'fixtures', 'live',
    'pg_depth', 'pg_depth_solo', 'pg_fires', 'pg_raised',
    'pg_ally_blocked', 'pg_ally_blocked_illusion',
    'pd_pairs', 'pd_fires_shipped', 'pd_fires_ownhalf', 'pd_ownhalf_only', 'pd_raised',
    'oc_pairs', 'oc_isolated', 'oc_deep', 'oc_iso_deep', 'oc_fires', 'oc_raised',
    'oc_lowally_near', 'oc_lowally_is_self' }) do
    rawset(c, k, 0)
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local short = path:match('([^/]+)%.lua$')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local armed = {}
                    J.IsSoakCandidate = function(id) return armed[id] == true end

                    -- ---- pushguard (PROMOTED: live in every turbo game).
                    -- Its three conjuncts, counted separately, so a zero can be
                    -- attributed to the leg that produced it.
                    local hOwn = GetAncient(GetTeam())
                    local hEnemy = GetAncient(GetOpposingTeam())
                    if hOwn ~= nil and hEnemy ~= nil then
                        local vB = bot:GetLocation()
                        local nDepth =
                            J.GetLocationToLocationDistance(vB, hOwn:GetLocation())
                            - J.GetLocationToLocationDistance(vB, hEnemy:GetLocation())
                        if nDepth > (G.PUSH_DEPTH or 2500) then
                            bump('pg_depth')
                            out:write(string.format('F %s %s pg_depth\n', short, u.name))
                            local tA = J.GetNearbyHeroes(bot, G.PUSH_ALLY_R or 2500,
                                false, BOT_MODE_NONE) or {}
                            local nAlly = 0
                            for _, a in pairs(tA) do
                                if J.IsValidHero(a) then
                                    nAlly = nAlly + 1
                                    -- The enemy leg below filters illusions; this
                                    -- one does not. Count how often the veto is
                                    -- carried by an illusion alone.
                                    if J.IsSuspiciousIllusion(a) then
                                        bump('pg_ally_blocked_illusion')
                                    end
                                end
                            end
                            if nAlly > 0 then bump('pg_ally_blocked')
                            else
                                bump('pg_depth_solo')
                                out:write(string.format('F %s %s pg_solo\n', short, u.name))
                            end
                        end
                    end
                    local okp, fired = pcall(J.ShouldAbortDeepSoloPush, bot)
                    if not okp then bump('pg_raised')
                    elseif fired then
                        bump('pg_fires')
                        out:write(string.format('F %s %s pg_fires\n', short, u.name))
                    end

                    -- ---- ShouldPunishDive: shipped domain vs the 'ownhalf'
                    -- extension. Same frame, two arms, so the extension's own
                    -- domain is a difference and not an assertion.
                    armed = {}
                    local okd, dtgt = pcall(J.ShouldPunishDive, bot)
                    if not okd then bump('pd_raised')
                    elseif dtgt ~= nil then
                        bump('pd_fires_shipped')
                        out:write(string.format('F %s %s pd_shipped\n', short, u.name))
                    end
                    armed = { ownhalf = true }
                    local okd2, dtgt2 = pcall(J.ShouldPunishDive, bot)
                    if okd2 and dtgt2 ~= nil then
                        bump('pd_fires_ownhalf')
                        if not (okd and dtgt ~= nil) then
                            bump('pd_ownhalf_only')
                            out:write(string.format('F %s %s pd_ownhalf\n', short, u.name))
                        end
                    end

                    -- ---- ShouldPunishOverchase, conjunct by conjunct over the
                    -- (bot, enemy) pairs the helper itself walks.
                    armed = { overchase = true }
                    local tE = J.GetNearbyHeroes(bot, G.CHASE_COLLAPSE_R or 1600,
                        true, BOT_MODE_NONE) or {}
                    for _, e in pairs(tE) do
                        if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e)
                            and not J.IsMeepoClone(e) then
                            bump('oc_pairs')
                            local vE = e:GetLocation()
                            local bIso =
                                #J.GetEnemiesNearLoc(vE, G.CHASE_ISOLATED_R or 1400) <= 1
                            local bDeep = false
                            for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                                if J.IsValidBuilding(b)
                                    and GetUnitToUnitDistance(e, b) <= 1200 then
                                    bDeep = true
                                    break
                                end
                            end
                            if not bDeep then
                                local hO, hE = GetAncient(GetTeam()), GetAncient(GetOpposingTeam())
                                if hO ~= nil and hE ~= nil then
                                    bDeep = J.GetLocationToLocationDistance(vE, hO:GetLocation())
                                        < J.GetLocationToLocationDistance(vE, hE:GetLocation()) - 800
                                end
                            end
                            if bIso then bump('oc_isolated') end
                            if bDeep then bump('oc_deep') end
                            if bIso and bDeep then
                                bump('oc_iso_deep')
                                out:write(string.format('F %s %s oc_iso_deep\n', short, u.name))
                            end
                            -- The (a) leg, split so "no low ally at all" and
                            -- "the only low ally is me" are different readings.
                            for _, a in pairs(J.GetAlliesNearLoc(vE, G.CHASE_ALLY_R or 900)) do
                                if J.IsValidHero(a) and not J.IsSuspiciousIllusion(a)
                                    and J.GetHP(a) < (G.CHASE_LOW_HP or 0.5) then
                                    if a == bot then bump('oc_lowally_is_self')
                                    else bump('oc_lowally_near') end
                                end
                            end
                        end
                    end
                    local okc, ctgt = pcall(J.ShouldPunishOverchase, bot)
                    if not okc then bump('oc_raised')
                    elseif ctgt ~= nil then
                        bump('oc_fires')
                        out:write(string.format('F %s %s oc_fires\n', short, u.name))
                    end
                end
            end
        end
    end
end

local ck = {}
for k in pairs(c) do ck[#ck + 1] = k end
table.sort(ck)
for _, k in ipairs(ck) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')
