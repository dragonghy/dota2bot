-- Heavy corpus sweep for tests/test_midsupfar_yield_target.lua, run as a
-- SUBPROCESS (the backlog 0q rule: a full-corpus drive that rebuilds jmz_func
-- once per hero-frame must not run on run_tests.lua's long-lived heap). The
-- leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  J.HasAvailableSupportResponder says of itself that it
-- mirrors, "member by member, the exact gates the support would itself have to
-- clear inside J.ShouldTpSupportTowerFight".  On that mirror rests the whole
-- safety argument for 'midsupyield' -- in the source, in its test header, and
-- in the director's conditional approval (state.json AX.5: "can only
-- REALLOCATE a tower-defense response from core to support, never drop one").
--
-- One gate of the responder loop is NOT a property of the support alone: the
-- support has to be FARTHER THAN THE FAR FLOOR from the very tower whose
-- response slot is being handed over.  The predicate takes no building
-- argument, so it cannot ask it.  This sweep asks it: for every corpus frame
-- where a CORE's helper actually fires, it takes the tower the helper ANSWERED
-- and measures each accepted support's distance to it.
--
-- The far floor is PARSED OUT OF THE SHIPPED SOURCE, never hardcoded (the M13
-- lesson): mutate `> 3500` in jmz_func and this census must move, or it is not
-- measuring the shipped tree.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>     a constant parsed out of the shipped helper
--   C <key> <n>          a counter bucket
--   Y <fixture> <hero> <pos> <d_bot_tower> <n_sup> <n_sup_far> <n_sup_near> <shipped>
--       one live CORE frame whose helper fires AND whose PRE-midsupfar member
--       list accepts at least one support: how many of those supports could
--       actually take this tower (far) and how many could not (near), plus what
--       the SHIPPED predicate answers when handed the answered tower. The last
--       field is what ties this census to the tree: `shipped` must equal
--       `n_sup_far > 0` on every record.
--   S <fixture> <hero> <support> <d_sup_tower> <far|near>
--       one accepted support on such a frame, with its distance to the
--       answered tower
--   DONE
-- The test treats absence of the final DONE line as a failed subprocess.

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

-- The responder helper, sliced out by its own header so a `> 3500` elsewhere
-- in this 11,000-line file cannot be picked up by mistake.
local function responder_block(src)
    local at = src:find('function J.ShouldTpSupportTowerFight( bot )', 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction J.', at + 10) or #src
    return src:sub(at, stop)
end

-- The far floor is now a NAMED constant read by both the responder loop and the
-- predicate. Parse the declaration for its value, and separately record that the
-- loop clause reads the NAME -- a re-inlined literal would silently un-do the
-- single-source property this census rests on. (First run after the refactor,
-- the old regex matched the literal that no longer exists, G.FAR_FLOOR went nil,
-- and every support classified `near`; the `shipped_disagrees` column below is
-- what caught it. A census that cannot disagree with the tree measures itself.)
local G = {}
local src = read_file(JMZ)
local blk = responder_block(src)
if blk == nil then
    G.PARSE = 'MISSING_FUNCTION'
else
    G.FAR_FLOOR = tonumber(src:match('J%.TP_RESPONSE_FAR_FLOOR = (%d+)'))
    G.LOOP_READS_CONST = blk:find(
        'GetUnitToUnitDistance( bot, building ) > J.TP_RESPONSE_FAR_FLOOR',
        1, true) ~= nil and 1 or 0
    G.TOWER_ENEMY_R = tonumber(blk:match('J.GetEnemiesNearLoc%( vTower, (%d+) %)'))
end
for _, k in ipairs({ 'PARSE', 'FAR_FLOOR', 'LOOP_READS_CONST', 'TOWER_ENEMY_R' }) do
    if G[k] ~= nil then out:write(string.format('G %s %s\n', k, tostring(G[k]))) end
end

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

-- Zero-initialised so an absent key and a measured zero are never the same
-- thing to the parser (the GH #171 shape: "the assertion never ran" must not
-- read as "the assertion passed").
for _, k in ipairs({ 'fixtures', 'live', 'fires', 'fires_core', 'yield_domain',
    'yield_all_near', 'yield_some_far', 'sup_accepted', 'sup_far', 'sup_near',
    'core_no_support', 'shipped_disagrees' }) do
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
                    -- Only 'midtp' armed: the helper fires and RETURNS the
                    -- tower, and 'midsupyield' stays off so the yield cannot
                    -- swallow the very answer being measured.
                    J.IsSoakCandidate = function(id) return id == 'midtp' end
                    local okc, building = pcall(J.ShouldTpSupportTowerFight, bot)
                    if okc and building ~= nil then
                        bump('fires')
                        if J.IsCore(bot) then
                            bump('fires_core')
                            local nSup, nFar, nNear = 0, 0, 0
                            local tP = GetTeamPlayers(GetTeam()) or {}
                            for i = 1, #tP do
                                local hAlly = GetTeamMember(i)
                                -- The member list AS IT STOOD BEFORE midsupfar,
                                -- re-run here so each accepted support can be
                                -- NAMED and classified. It is a shadow of the
                                -- shipped predicate, so the `shipped` column
                                -- below re-asks the SHIPPED function and the
                                -- test asserts the two agree -- otherwise this
                                -- census would be measuring only itself.
                                if hAlly ~= nil and hAlly ~= bot
                                    and J.IsValidHero(hAlly)
                                    and hAlly:IsAlive()
                                    and J.GetPosition(hAlly) >= 4
                                    and hAlly:GetLevel() >= 6
                                    and not J.IsInTeamFight(hAlly, 1600)
                                    and not J.IsRetreating(hAlly) then
                                    local tp = J.GetItem2(hAlly, 'item_tpscroll')
                                    local bt = J.GetItem2(hAlly, 'item_travel_boots')
                                    if (tp ~= nil and tp:IsFullyCastable())
                                        or (bt ~= nil and bt:IsFullyCastable()) then
                                        nSup = nSup + 1
                                        bump('sup_accepted')
                                        local d = GetUnitToUnitDistance(hAlly, building)
                                        local far = (G.FAR_FLOOR ~= nil
                                            and d > G.FAR_FLOOR)
                                        if far then
                                            nFar = nFar + 1; bump('sup_far')
                                        else
                                            nNear = nNear + 1; bump('sup_near')
                                        end
                                        out:write(string.format('S %s %s %s %.0f %s\n',
                                            path:match('([^/]+)%.lua$'), u.name,
                                            hAlly:GetUnitName(), d,
                                            far and 'far' or 'near'))
                                    end
                                end
                            end
                            local shipped =
                                J.HasAvailableSupportResponder(bot, building)
                            if nSup > 0 then
                                bump('yield_domain')
                                if nFar > 0 then bump('yield_some_far')
                                else bump('yield_all_near') end
                                if shipped ~= (nFar > 0) then
                                    bump('shipped_disagrees')
                                end
                                out:write(string.format('Y %s %s %d %.0f %d %d %d %s\n',
                                    path:match('([^/]+)%.lua$'), u.name,
                                    J.GetPosition(bot),
                                    GetUnitToUnitDistance(bot, building),
                                    nSup, nFar, nNear, tostring(shipped)))
                            else
                                bump('core_no_support')
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
