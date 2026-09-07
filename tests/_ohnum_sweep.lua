-- Corpus census for the 'ohnum' lever (advantage-not-parity for a punish with
-- no building behind it), run as a SUBPROCESS (backlog 0q: a full-corpus drive
-- that rebuilds jmz_func once per hero-frame must not run on run_tests.lua's
-- long-lived heap). The leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED, and why each leg exists.
--
--   * `pd_ownhalf_only` reproduces tests/_posture_domain_sweep.lua's reading of
--     the domain this lever narrows (51). It is repeated here rather than
--     quoted so that a change to J.ShouldPunishDive cannot leave the two files
--     disagreeing in silence.
--   * `ohnum_alone_*` is THE reading that says whether this id can be armed on
--     its own leg. Its call site sits on the shipped (PROMOTED) path, not
--     inside the 'ownhalf' branch, so a wave that arms 'ohnum' alone reaches
--     it -- but the shipped domain admits only targets within 1200 of a live
--     allied building, which is exactly this helper's own release. The
--     expected reading is therefore ZERO CHANGE, and it is a MEASUREMENT of a
--     world fact ("the shipped domain is building-proximate") rather than the
--     structural impossibility a gate-inside-gate would give. A non-zero here
--     is not a failure; it means the shipped domain grew a target with no
--     building behind it, and the census comment must be re-read.
--   * `both_*` is the lever's own domain: 'ownhalf' + 'ohnum'.
--   * `both_to_nil` vs `both_switched` is the leg that a "how many fires does
--     it remove" count would get wrong. ShouldPunishDive returns the FIRST
--     enemy that clears the domain and the commit gate, so refusing one target
--     can hand the frame to a DIFFERENT enemy rather than to nil. Both
--     outcomes are behaviour changes and neither is the other.
--   * `parity` / `advantage` price the argument itself over the domain.
--   * `lethal_release` is expected to be 0 and is printed anyway: the mock's
--     GetEstimatedDamageToTarget answers 0 on every frame, so the lethal
--     release cannot be witnessed here. Printing the zero keeps that LIMIT in
--     the manifest instead of in prose someone has to remember.
--
-- Every threshold is PARSED OUT OF THE SHIPPED SOURCE, never hardcoded (the M13
-- lesson): move a number in jmz_func and this census must move with it.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <what> <detail>   one live frame in a named bucket
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
local dive = block(src, 'function J.ShouldPunishDive( bot )')
local refuse = block(src, 'function J.ShouldRefuseUnsupportedPunish( bot, target )')
G.DIVE = dive and 1 or 0
G.REFUSE = refuse and 1 or 0
-- `nil` here is a FAILED PARSE, not a zero (the GH #171 shape), so it is
-- printed as such rather than quietly defaulted.
G.DIVE_BUILDING_R = dive and tonumber(dive:match('building %) <= (%d+)'))
G.REFUSE_BUILDING_R = refuse and tonumber(refuse:match('building %) <= (%d+)'))
G.DIVE_OWNHALF = dive and tonumber(dive:match('nInvadeDepth >= (%d+)'))
G.REFUSE_ALLY_R = refuse and tonumber(refuse:match('GetAlliesNearLoc%( vLoc, (%d+) %)'))

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
-- zero" are never the same thing to the parser.
for _, k in ipairs({ 'fixtures', 'live', 'raised',
    'pd_shipped', 'pd_ownhalf', 'pd_ownhalf_only',
    'ohnum_alone_fires', 'ohnum_alone_changed',
    'both_fires', 'both_changed', 'both_to_nil', 'both_switched',
    'domain_parity', 'domain_advantage', 'lethal_release' }) do
    rawset(c, k, 0)
end

local function name_of(h)
    if h == nil then return 'nil' end
    local ok, n = pcall(h.GetUnitName, h)
    if not ok or n == nil then return '?' end
    return (n:gsub('npc_dota_hero_', ''))
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

                    -- Four arms on the SAME frame, so every column below is a
                    -- difference and not an assertion.
                    armed = {}
                    local okS, tS = pcall(J.ShouldPunishDive, bot)
                    armed = { ohnum = true }
                    local okN, tN = pcall(J.ShouldPunishDive, bot)
                    armed = { ownhalf = true }
                    local okO, tO = pcall(J.ShouldPunishDive, bot)
                    armed = { ownhalf = true, ohnum = true }
                    local okB, tB = pcall(J.ShouldPunishDive, bot)
                    if not (okS and okN and okO and okB) then
                        bump('raised')
                    else
                        if tS ~= nil then bump('pd_shipped') end
                        if tO ~= nil then bump('pd_ownhalf') end

                        -- 'ohnum' on its own leg, against shipped.
                        if tN ~= nil then bump('ohnum_alone_fires') end
                        if tN ~= tS then
                            bump('ohnum_alone_changed')
                            out:write(string.format('F %s %s ohnum_alone %s->%s\n',
                                short, u.name, name_of(tS), name_of(tN)))
                        end

                        if tB ~= nil then bump('both_fires') end
                        if tO ~= tB then
                            bump('both_changed')
                            if tB == nil then bump('both_to_nil')
                            else bump('both_switched') end
                            out:write(string.format('F %s %s both %s->%s\n',
                                short, u.name, name_of(tO), name_of(tB)))
                        end

                        -- Price the argument over the lever's own domain: the
                        -- frames that enter only through the depth test.
                        if tO ~= nil and tS == nil then
                            bump('pd_ownhalf_only')
                            local vLoc = tO:GetLocation()
                            local tA = J.GetAlliesNearLoc(vLoc, G.REFUSE_ALLY_R or 1200)
                            local tE = J.GetEnemiesNearLoc(vLoc, G.REFUSE_ALLY_R or 1200)
                            if J.GetTotalEstimatedDamageToTarget(tA, tO)
                                >= tO:GetHealth() + tO:GetHealthRegen() * 5.0 then
                                bump('lethal_release')
                            end
                            if #tA < #tE + 1 then
                                bump('domain_parity')
                                out:write(string.format('F %s %s parity %d-v-%d\n',
                                    short, u.name, #tA, #tE))
                            else
                                bump('domain_advantage')
                            end
                        end
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
