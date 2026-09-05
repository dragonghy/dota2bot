-- Heavy corpus sweep for tests/test_midsupint_mirror_interrupt.lua, run as a
-- SUBPROCESS (backlog 0q: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame must not run on run_tests.lua's long-lived heap). The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  test_set.md §EF.7 registered four members that the
-- J.HasAvailableSupportResponder mirror "could ask and does not". §EH priced all
-- four as unwitnessable on this corpus; GH #492 repaired the fixture mock's
-- GetExtrapolatedLocation and §EL re-priced ONE of them -- the TP-channel
-- interrupt guard -- as witnessable (int_true 0 -> 73). GH #503 handed that
-- member to this stream to write. This census is the domain price of the
-- REPAIRED tree: how often the new conjunct actually changes the mirror's
-- answer, and whether it is subsumed by the leg above it.
--
-- ⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED, ON THE SIDE THAT MATTERS.  The
-- repair carries no soak id (see the note in jmz_func.lua: this predicate's only
-- consumer is already gated by 'midsupyield', and a second id would make the
-- live condition a two-id conjunction -- the pullcad trap). So the tree cannot
-- be toggled, and the PRE-repair answer has to come from a shadow. The shadow
-- is therefore built the other way round from the usual: the REPAIRED shadow is
-- checked against the real predicate on every single pair (`shipped_disagrees`,
-- asserted 0 downstream), which pins it to the tree; the PRE-repair shadow is
-- that same code with exactly one clause dropped. Without that anti-drift leg
-- this census would be measuring only itself -- the §EH lesson.
--
-- Every threshold is PARSED OUT OF THE SHIPPED SOURCE, never hardcoded (the M13
-- lesson): move a number in jmz_func and this census must move with it.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <tower_x> <tower_y> <rejected_ally>
--       one (hero, tower) pair where the conjunct flips the mirror true -> false,
--       naming the ally it rejects
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

-- Every structural fact below is a claim about CODE, and this repair ships with
-- a long comment that names both J.CanEnemyInterruptTpChannel and
-- J.IsSoakCandidate in prose. Reading the raw block would let the comment
-- satisfy the assertions -- including MIRROR_SOAKID, whose whole job is to fail
-- if an id ever appears here. Measured, not assumed: MIRROR_SOAKID read 1 off
-- the comment on the first run of this sweep.
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local src = read_file(JMZ)
local mirror = strip_comments(
    block(src, 'function J.HasAvailableSupportResponder( bot, hBuilding )'))
local interrupt = block(src, 'function J.CanEnemyInterruptTpChannel( bot )')
G.MIRROR = mirror and 1 or 0
-- The repair itself, as a parsed fact: the conjunct is present AND negated. A
-- census whose subject silently left the tree would otherwise report zeros.
G.MIRROR_INT = (mirror and mirror:find('not J.CanEnemyInterruptTpChannel( hAlly )',
    1, true)) and 1 or 0
G.MIRROR_FIGHT = (mirror and mirror:find('not J.IsInTeamFight( hAlly, 1600 )',
    1, true)) and 1 or 0
-- No soak id may appear inside this predicate -- see the header. Parsed so the
-- day someone adds one, the pullcad trap is caught here and not in a wave.
G.MIRROR_SOAKID = (mirror and mirror:find('IsSoakCandidate', 1, true)) and 1 or 0
G.INT_R = interrupt and tonumber(interrupt:match('bWide and %d+ or (%d+)')) or nil
G.FAR_FLOOR = tonumber(src:match('J%.TP_RESPONSE_FAR_FLOOR = (%d+)'))

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
for _, k in ipairs({ 'fixtures', 'live', 'pairs_eval', 'ship_true', 'pre_true',
    'flips', 'flip_frames', 'cand', 'cand_int_true', 'cand_int_raise',
    'blocked_fight_int_true', 'shipped_disagrees' }) do
    rawset(c, k, 0)
end

-- The mirror's member list, re-run as a shadow. `bWithInt` selects the REPAIRED
-- shadow (checked against the tree) or the PRE-repair one (the counterfactual).
-- Returns accepted?, and the name of an ally the interrupt clause rejected.
local function shadow(J, bot, b, tP, bWithInt)
    local sRejected = nil
    for i = 1, #tP do
        local hAlly = GetTeamMember(i)
        if hAlly ~= nil and hAlly ~= bot
            and J.IsValidHero(hAlly)
            and hAlly:IsAlive()
            and J.GetPosition(hAlly) >= 4
            and hAlly:GetLevel() >= 6
            and not J.IsInTeamFight(hAlly, 1600)
            and not J.IsRetreating(hAlly)
            and GetUnitToUnitDistance(hAlly, b) > J.TP_RESPONSE_FAR_FLOOR
        then
            local tp = J.GetItem2(hAlly, 'item_tpscroll')
            local bt = J.GetItem2(hAlly, 'item_travel_boots')
            local bTp = (tp ~= nil and tp:IsFullyCastable())
                or (bt ~= nil and bt:IsFullyCastable())
            if bTp then
                local oki, itp = pcall(J.CanEnemyInterruptTpChannel, hAlly)
                if bWithInt and oki and itp then
                    sRejected = hAlly:GetUnitName()
                else
                    return true, sRejected
                end
            end
        end
    end
    return false, sRejected
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
                    -- 'midsupyield' is the lever this repair lives under; nothing
                    -- inside the predicate reads a soak id (asserted above), so
                    -- the census is taken with every candidate disarmed.
                    J.IsSoakCandidate = function() return false end
                    local tP = GetTeamPlayers(GetTeam()) or {}

                    -- ---- the ally census, independent of any tower: is the new
                    -- clause subsumed by the IsInTeamFight leg that precedes it?
                    -- An enemy inside the interrupt scan is usually also a fight,
                    -- so "already blocked upstream" is the live alternative
                    -- explanation and it has to be measured, not assumed away.
                    for i = 1, #tP do
                        local hAlly = GetTeamMember(i)
                        if hAlly ~= nil and hAlly ~= bot
                            and J.IsValidHero(hAlly) and hAlly:IsAlive()
                            and J.GetPosition(hAlly) >= 4
                            and hAlly:GetLevel() >= 6
                            and not J.IsRetreating(hAlly) then
                            local tp = J.GetItem2(hAlly, 'item_tpscroll')
                            local bt = J.GetItem2(hAlly, 'item_travel_boots')
                            if (tp ~= nil and tp:IsFullyCastable())
                                or (bt ~= nil and bt:IsFullyCastable()) then
                                local oki, itp = pcall(J.CanEnemyInterruptTpChannel, hAlly)
                                if not J.IsInTeamFight(hAlly, 1600) then
                                    bump('cand')
                                    if not oki then bump('cand_int_raise')
                                    elseif itp then bump('cand_int_true') end
                                elseif oki and itp then
                                    bump('blocked_fight_int_true')
                                end
                            end
                        end
                    end

                    -- ---- the decision, over every allied tower.
                    local tB = GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}
                    local bFlipHere = false
                    for _, b in pairs(tB) do
                        if J.IsValidBuilding(b)
                            and string.find(b:GetUnitName(), 'tower') ~= nil then
                            bump('pairs_eval')
                            local shipped = J.HasAvailableSupportResponder(bot, b)
                            local rep, sRej = shadow(J, bot, b, tP, true)
                            local pre = shadow(J, bot, b, tP, false)
                            if rep ~= shipped then bump('shipped_disagrees') end
                            if shipped then bump('ship_true') end
                            if pre then bump('pre_true') end
                            if pre and not shipped then
                                bump('flips')
                                bFlipHere = true
                                local loc = b:GetLocation()
                                out:write(string.format('F %s %s %d %d %s\n',
                                    path:match('([^/]+)%.lua$'), u.name,
                                    loc.x, loc.y, tostring(sRej)))
                            end
                        end
                    end
                    if bFlipHere then bump('flip_frames') end
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
