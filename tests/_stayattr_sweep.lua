-- Heavy corpus sweep for tests/test_stayattr_global_ult.lua, run as a
-- SUBPROCESS: a full-corpus drive that rebuilds jmz_func once per hero-frame
-- must not run on run_tests.lua's long-lived heap. The leading underscore keeps
-- run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  J.ShouldStayAndRegen is PROMOTED -- live in every turbo
-- game -- and its chase read is `bot:WasRecentlyDamagedByAnyHero(3.0)` with no
-- attribution: a global ult landed from across the map vetoes the "stay and
-- heal" answer exactly as a hero standing on top of the bot does, and the bot
-- is released to go home. Owner priority P2 forbids that trip. The 'stayattr'
-- lever keeps the veto only when the hero damage is attributable to an enemy
-- still inside 3000 -- the shape J.IsFieldRegenSituation already uses.
--
-- This census is the DOMAIN PRICE of that lever on the real-frame corpus:
--   * how many live hero frames the unattributed read vetoes at all;
--   * on how many of those the damage is UNATTRIBUTABLE (nobody inside 3000
--     hit this bot) -- the frames the lever is about;
--   * how many of those survive every OTHER clause of the function, i.e. the
--     frames where J.ShouldStayAndRegen itself flips false -> true.
--
-- ⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  The lever carries a real soak id,
-- so both answers come from the shipped function with J.IsSoakCandidate stubbed
-- to false and then to true. Nothing here re-implements the decision, so this
-- census cannot drift away from the tree the way a shadow can (the §EH lesson).
-- The one thing that IS parsed rather than driven is the set of structural
-- facts below -- constants and call shapes read out of the source, never
-- hardcoded (the M13 lesson): move a number in jmz_func and this census moves.
--
-- ⛔ DIRECTION IS ASSERTED, NOT CLAIMED.  `flip_true_to_false` counts frames
-- where arming turns a TRUE into a FALSE. The lever can only remove vetoes, so
-- that counter must be 0; downstream asserts it. It is the census's own
-- anti-drift leg -- without it this file would only be measuring itself.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <nearest_enemy_dist> <hp_frac>
--       one live frame where J.ShouldStayAndRegen flips false -> true
--   U <fixture> <hero> <nearest_enemy_dist>
--       one live frame where the veto fires on UNATTRIBUTABLE hero damage
--       (the defect shape) but some other clause still answers false
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

-- Every structural fact below is a claim about CODE, and this lever ships with
-- a long comment naming J.IsSoakCandidate, J.HasNearbyHeroDamager and the
-- radius in prose. Reading the raw block would let the COMMENT satisfy the
-- assertions -- the mistake §EN caught on its own first run, where a counter
-- that must read 0 read 1 off a comment explaining why it was 0.
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local src = read_file(JMZ)
local stay = strip_comments(block(src, 'function J.ShouldStayAndRegen( bot )'))
local damager = strip_comments(
    block(src, 'function J.HasNearbyHeroDamager( bot, nRadius, fTime )'))
G.STAY = stay and 1 or 0
G.DAMAGER = damager and 1 or 0
-- The lever itself, as parsed facts: the id is present, and it is present in
-- the NEGATED disjunct that makes the unarmed path the shipped read.
G.STAY_SOAKID = (stay and stay:find("J.IsSoakCandidate( 'stayattr' )", 1, true))
    and 1 or 0
G.STAY_NEGATED = (stay and stay:find("not J.IsSoakCandidate( 'stayattr' )",
    1, true)) and 1 or 0
-- The 'pullcad' trap is TWO IDS IN ONE CONDITION: the live condition becomes a
-- conjunction that freezes FALSE the day either id is promoted, while
-- check_armed_wiring.py still calls it WIRED.
--
-- This was measured as "ids anywhere in the function == 1" until 2026-09-05,
-- which is a PROXY, not the invariant, and it held only while this function
-- carried exactly one lever. 'staysrc' then put a second, independent lever on
-- the supply clause -- a different `if`, no shared condition -- and the proxy
-- went red on a tree with no trap on it. The two numbers are both kept: the
-- total is still reported (a reader wants to know how many levers live here),
-- but what is ASSERTED downstream is the per-condition maximum, which is the
-- shape the trap actually has.
local nIds = 0
if stay then for _ in stay:gmatch('IsSoakCandidate') do nIds = nIds + 1 end end
G.STAY_NIDS = nIds
local nMax = 0
if stay then
    for cond in stay:gmatch('if(.-)then') do
        local n = 0
        for _ in cond:gmatch('IsSoakCandidate') do n = n + 1 end
        if n > nMax then nMax = n end
    end
end
G.STAY_IDS_MAX_PER_COND = nMax
-- The radius and window the call site passes, and the ring below it. Parsed so
-- the test asserts the tree's numbers, not this file's memory of them.
G.STAY_RADIUS = stay and tonumber(stay:match('HasNearbyHeroDamager%( bot, (%d+)'))
G.STAY_WINDOW = stay and tonumber(stay:match('HasNearbyHeroDamager%( bot, %d+, ([%d%.]+)'))
G.STAY_RING = stay and tonumber(stay:match('GetNearbyHeroes%( bot, (%d+), true'))
G.STAY_HP_LO = stay and tonumber(stay:match('nHP < ([%d%.]+)'))
G.STAY_HP_HI = stay and tonumber(stay:match('nHP > ([%d%.]+)'))
-- The helper must not carry a gate of its own -- the decision (and the id) is
-- the caller's. A gate here would be a second, invisible arming point.
G.DAMAGER_SOAKID = (damager and damager:find('IsSoakCandidate', 1, true))
    and 1 or 0
-- The sibling attributed scan this lever is modelled on, still where the
-- comment says it is. If it moves or changes radius, the "same shape, same
-- constants" claim in the shipped comment needs re-reading.
local sit = strip_comments(block(src, 'function J.IsFieldRegenSituation( bot )'))
G.SIB_RADIUS = sit and tonumber(sit:match('GetNearbyHeroes%( bot, (%d+), true, BOT_MODE_NONE %)\n%s*for'))
    or (sit and tonumber(sit:match('WasRecentlyDamagedByAnyHero%( 3%.0 %) then\n%s*local hEnemyList = J%.GetNearbyHeroes%( bot, (%d+)')))

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
for _, k in ipairs({ 'fixtures', 'live', 'hp_band', 'anyhero', 'attributed',
    'unattributed', 'ship_true', 'arm_true', 'flips', 'flip_true_to_false',
    'unattr_out_of_band', 'unattr_blocked_ring', 'unattr_blocked_supply',
    'unattr_ring_tested', 'arm_leak', 'raises' }) do
    rawset(c, k, 0)
end

local function nearest_enemy(J, bot)
    local best = -1
    local t = J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE) or {}
    for _, h in pairs(t) do
        if J.IsValidHero(h) then
            local d = GetUnitToUnitDistance(bot, h)
            if best < 0 or d < best then best = d end
        end
    end
    return best
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
                    local armed = false
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'stayattr'
                    end

                    local nHP = J.GetHP(bot)
                    local bBand = (nHP >= G.STAY_HP_LO and nHP <= G.STAY_HP_HI)
                    if bBand then bump('hp_band') end

                    -- The defect shape, measured independently of the whole
                    -- function so that "the lever's situation" and "the lever
                    -- changed the answer" stay two different numbers.
                    local bAny = bot:WasRecentlyDamagedByAnyHero(3.0)
                    local bAttr = false
                    if bAny then
                        bump('anyhero')
                        bAttr = J.HasNearbyHeroDamager(bot, G.STAY_RADIUS,
                            G.STAY_WINDOW)
                        if bAttr then bump('attributed') else bump('unattributed') end
                    end

                    local ok1, shipped = pcall(J.ShouldStayAndRegen, bot)
                    armed = true
                    -- The arming must be ONE id wide. 141 live gate ids exist in
                    -- this tree; a stub that armed them all would let any of the
                    -- other 140 move this guard's answer while the flip is still
                    -- attributed to this lever. Checked here rather than read
                    -- off the stub's source, because what matters is what the
                    -- shipped code is ABLE to observe. Asserted 0 downstream.
                    -- (This counter exists because the mutation stand's M8 --
                    -- widen the stub to `return armed` -- SURVIVED the first
                    -- run: nothing in the suite could tell one id from all of
                    -- them, which on this corpus happened to give the same
                    -- numbers. A gap found by a survivor, not by review.)
                    if J.IsSoakCandidate('stayfield')
                        or J.IsSoakCandidate('fieldsip')
                        or J.IsSoakCandidate('tphome') then
                        bump('arm_leak')
                    end
                    local ok2, arm = pcall(J.ShouldStayAndRegen, bot)
                    armed = false
                    if not (ok1 and ok2) then
                        bump('raises')
                    else
                        if shipped then bump('ship_true') end
                        if arm then bump('arm_true') end
                        if arm and not shipped then
                            bump('flips')
                            out:write(string.format('F %s %s %.1f %.4f\n',
                                path:match('([^/]+)%.lua$'), u.name,
                                nearest_enemy(J, bot), nHP))
                        elseif shipped and not arm then
                            -- Must never happen: the lever only removes vetoes.
                            -- Asserted 0 downstream.
                            bump('flip_true_to_false')
                        end
                        -- EXCLUSIVE partition of the lever's own situation
                        -- (`unattributed`), taken in the function's own clause
                        -- order. Counting it out rather than inferring the last
                        -- bucket by subtraction is the point: "the lever is
                        -- inert here" and "the situation is rare" are different
                        -- claims, and only a named bucket keeps them apart.
                        -- The four counters must sum to `unattributed`, and the
                        -- test asserts exactly that.
                        if bAny and not bAttr then
                            local sBucket
                            if not bBand then
                                sBucket = 'unattr_out_of_band'
                            else
                                -- Counted separately from the bucket it feeds,
                                -- so that "the ring branch was reached and the
                                -- ring was empty" and "the ring branch was never
                                -- reached" are different numbers. Without this,
                                -- `unattr_blocked_ring == 0` is the GH #171
                                -- shape: a zero that reads the same whether it
                                -- was measured or skipped. See the note on that
                                -- bucket in the test file -- on THIS corpus the
                                -- zero is VACUOUS, and that is registered rather
                                -- than dressed up.
                                bump('unattr_ring_tested')
                                if #J.GetNearbyHeroes(bot, G.STAY_RING, true,
                                    BOT_MODE_NONE) > 0 then
                                    sBucket = 'unattr_blocked_ring'
                                elseif not arm then
                                    sBucket = 'unattr_blocked_supply'
                                end
                            end
                            if sBucket ~= nil then
                                bump(sBucket)
                                out:write(string.format('U %s %s %.1f %s\n',
                                    path:match('([^/]+)%.lua$'), u.name,
                                    nearest_enemy(J, bot), sBucket))
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
