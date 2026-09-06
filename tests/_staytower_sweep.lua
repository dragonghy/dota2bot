-- Heavy corpus sweep for tests/test_staytower_tower_ring.lua, run as a
-- SUBPROCESS: a full-corpus drive that rebuilds jmz_func once per hero-frame must
-- not run on run_tests.lua's long-lived heap.  The leading underscore keeps
-- run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  One CLAUSE is written down by one half of a family and
-- missing from the other, and the half that is missing it is the PROMOTED one:
--   * J.IsFieldRegenSituation (gated, never shipped) vetoes on
--     `#bot:GetNearbyTowers( 1200, true ) > 0`, and its comment says the clause
--     exists so the lever does not cancel the LOCAL back-off from a tower;
--   * J.ShouldStayAndRegen -- PROMOTED, live in every turbo game, cancelling the
--     same retreat bid from ABOVE the whole guard chain -- reads no building at
--     all.
-- 'staytower' is the standalone lever that brings that one clause across.
--
-- ⭐ THE COLUMN THIS FILE EXISTS FOR IS `flips_g200`, AND WHY `flips_g0` IS ZERO.
-- The shipped function's last clause is `if not bHasRegen and bot:GetGold() < 90
-- then return false end`.  Gold is NOT networked into a .dem (GH #495), so every
-- fixture reads GetGold() as the mock's `^Get -> 0` scalar and the shipped
-- function answers TRUE on only 13 of 1012 live frames -- none of which carries a
-- tower.  A single `flips` column would therefore be a ZERO produced by the gold
-- clause and attributed to this lever: the exact shape GH #171 is about.  So the
-- corpus is driven TWICE, with GetGold() overridden to 0 and to 200, and BOTH
-- columns are printed.  The gold override is the only synthetic scalar in this
-- file; every other read is the real frame.
--
-- ⭐⭐ DIRECTION IS THE MIRROR OF THIS FAMILY'S OTHER LEVERS AND IS ASSERTED, NOT
-- CLAIMED.  'staysrc' / 'staybottle' / 'staybag' widen a disjunct and can only
-- add TRUEs; this one adds a veto and can only remove them.  `flip_false_to_true`
-- counts frames where arming turns a FALSE into a TRUE; it must be 0.
--
-- ⚠️ WHAT THIS FILE CANNOT MEASURE, STATED RATHER THAN IMPLIED.  It measures the
-- PROMOTED predicate flipping, not which retreat bid then wins: releasing a frame
-- restores the whole guard chain below the call site, and the bid that wins there
-- is a function of clauses this sweep does not drive.  The 12 domain frames are
-- therefore LISTED (F rows), not just counted, so the set is auditable.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac> <tower_dist>
--       one live frame where J.ShouldStayAndRegen flips true -> false under
--       'staytower' armed ALONE, with gold driven to 200
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'
local RETREAT = 'bots/mode_retreat_generic.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction ', at + 10) or #src
    return src:sub(at, stop)
end

-- Comments are stripped before every structural claim below: a claim that a
-- constant or an id appears in the CODE must not be satisfiable by prose about
-- it, and this function's docstring quotes the sibling clause verbatim.
local function strip_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

local function count(s, needle)
    local n, at = 0, 1
    while true do
        local i = s:find(needle, at, true)
        if i == nil then return n end
        n = n + 1
        at = i + 1
    end
end

local jmzsrc = read_file(JMZ)
local retsrc = read_file(RETREAT)
local G = {}

local stay = assert(block(jmzsrc, 'function J.ShouldStayAndRegen( bot )'),
    'J.ShouldStayAndRegen not found')
local sit = assert(block(jmzsrc, 'function J.IsFieldRegenSituation( bot )'),
    'J.IsFieldRegenSituation not found')
local staycode = strip_comments(stay)
local sitcode = strip_comments(sit)

G.STAY_STRIPPED = (#staycode < #stay) and 1 or 0
G.SIT_STRIPPED = (#sitcode < #sit) and 1 or 0
G.STAY_TURBO = staycode:find('if not J.IsModeTurbo() then return false end', 1, true)
    and 1 or 0

-- The lever's own block, and the two facts that make it standalone.
G.STAY_HAS_STAYTOWER = count(staycode, "J.IsSoakCandidate( 'staytower' )")
G.STAY_TOWER_RING = staycode:find('and #bot:GetNearbyTowers( 1200, true ) > 0', 1, true)
    and 1200 or 0
-- Anchor uniqueness is part of the declaration (GH #550): the plain statement
-- form `if #bot:GetNearbyTowers( 1200, true ) > 0 then return false end` already
-- occurs twice in this file (J.IsFieldRegenSituation and
-- J.ShouldFieldBuyRegenHurt), so the lever is written as a two-line conjunction
-- whose second line occurs exactly once in the WHOLE file.
G.STAY_ANCHOR_FILEWIDE = count(jmzsrc, 'and #bot:GetNearbyTowers( 1200, true ) > 0')
-- The gate must be the FIRST conjunct: that is what makes "unarmed, the engine
-- call never happens and every sibling lever evaluates byte-identically" a fact
-- about the code rather than a sentence in a comment.
G.STAY_GATE_FIRST = staycode:find(
    "if J.IsSoakCandidate( 'staytower' )\n\tand #bot:GetNearbyTowers( 1200, true ) > 0",
    1, true) and 1 or 0
-- The sibling's constant, read off the sibling rather than restated here: if it
-- ever moves, this lever is no longer a copy and the test says so.
G.SIT_TOWER = sitcode:find('#bot:GetNearbyTowers( 1200, true )', 1, true) and 1200 or 0

-- 'pullcad' guard: the number of distinct soak ids named anywhere inside this
-- function's own gate expressions, and the maximum in any ONE condition.
do
    local ids = {}
    for id in staycode:gmatch("J%.IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
        ids[id] = true
    end
    local n = 0
    for _ in pairs(ids) do n = n + 1 end
    G.STAY_NIDS = n
    -- Every gate in this function is written one id per condition; the census is
    -- over `if`-conditions that mention IsSoakCandidate at all.
    local worst = 0
    for cond in staycode:gmatch('if([^\n]-)then') do
        local k = count(cond, 'J.IsSoakCandidate')
        if k > worst then worst = k end
    end
    -- Multi-line conditions: count per `if ... then` spanning newlines too.
    for cond in staycode:gmatch('if(.-)\n%s*then') do
        local k = count(cond, 'J.IsSoakCandidate')
        if k > worst then worst = k end
    end
    G.STAY_IDS_MAX_PER_COND = worst
end

-- The call site the whole argument rests on: the PROMOTED function cancels a
-- retreat bid from above the guard chain, and it does so exactly once.
G.RETREAT_CALLS_STAY = count(strip_comments(retsrc), 'if J.ShouldStayAndRegen(bot) then')
G.RETREAT_RETURNS_NONE = strip_comments(retsrc):find(
    'if J.ShouldStayAndRegen(bot) then\n        return BOT_MODE_DESIRE_NONE', 1, true)
    and 1 or 0

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
for _, k in ipairs({ 'fixtures', 'live', 'turbo', 'raises', 'probe_runs',
    'band', 'prefix_ok', 'prefix_tower', 'stay_true_g0', 'stay_true_g200',
    'flips_g0', 'flips_g200', 'flip_false_to_true', 'domain_tower_close',
    'domain_tower_far', 'arm_leak', 'gold_override_ok',
    'dirprobe_down_g0', 'dirprobe_down_g200',
    'dirprobe_up_g0', 'dirprobe_up_g200' }) do
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
                    local armed = false
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'staytower'
                    end
                    if J.IsModeTurbo() then bump('turbo') end

                    -- The gold override is declared, bounded and reversible: it
                    -- is the ONE scalar a .dem does not carry (GH #495), and
                    -- without it the shipped predicate answers TRUE on 13 frames
                    -- and this lever's whole domain reads as an unexplained zero.
                    local fGold = 0
                    local hOldGold = bot.GetGold
                    bot.GetGold = function() return fGold end
                    if bot:GetGold() == 0 then bump('gold_override_ok') end

                    local okp = pcall(function()
                        -- INDEPENDENT PREFIX WALK: every clause of the shipped
                        -- function above the supply block, re-derived here so a
                        -- zero in the flip columns can be told apart from a
                        -- corpus that never reaches the lever.
                        local nHP = J.GetHP(bot)
                        local bPrefix = J.IsModeTurbo()
                            and nHP >= 0.18 and nHP <= 0.75
                            and not bot:WasRecentlyDamagedByAnyHero(3.0)
                            and #J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0
                        if J.IsModeTurbo() and nHP >= 0.18 and nHP <= 0.75 then
                            bump('band')
                        end
                        local tw = bot:GetNearbyTowers(1200, true)
                        if bPrefix then
                            bump('prefix_ok')
                            if #tw > 0 then bump('prefix_tower') end
                        end

                        for _, g in ipairs({ 0, 200 }) do
                            fGold = g
                            armed = false
                            local shipped = J.ShouldStayAndRegen(bot)
                            armed = true
                            -- The arming must be ONE id wide: a stub arming the
                            -- whole family would let a sibling lever move this
                            -- answer while the flip is still credited here.
                            if J.IsSoakCandidate('staysrc')
                                or J.IsSoakCandidate('staybottle')
                                or J.IsSoakCandidate('staybag')
                                or J.IsSoakCandidate('stayattr')
                                or J.IsSoakCandidate('bagsalve') then
                                bump('arm_leak')
                            end
                            local arm = J.ShouldStayAndRegen(bot)
                            armed = false
                            if shipped then
                                bump(g == 0 and 'stay_true_g0' or 'stay_true_g200')
                            end
                            -- ⭐ THE DIRECTION COUNTER HAS TO PROVE IT CAN COUNT.
                            -- `flip_false_to_true` is a claim whose whole content
                            -- is a zero, and direction here is fixed by
                            -- construction -- so the statement that bumps it is
                            -- never reached on this corpus, and DELETING it leaves
                            -- the same zero behind. The stand's M14 survived on
                            -- exactly that, and the suspect is this instrument,
                            -- not the mutant. So both directions are tallied
                            -- through ONE function, and it is called a second time
                            -- with the two legs SWAPPED: the swapped call must
                            -- report the domain (12) through the very branch the
                            -- forward call must report 0 through. Delete either
                            -- branch and a nonzero column moves.
                            local function tally(a, b, sDown, sUp)
                                if a and not b then bump(sDown) end
                                if b and not a then bump(sUp) end
                            end
                            tally(shipped, arm,
                                g == 0 and 'flips_g0' or 'flips_g200',
                                'flip_false_to_true')
                            tally(arm, shipped,
                                g == 0 and 'dirprobe_down_g0' or 'dirprobe_down_g200',
                                g == 0 and 'dirprobe_up_g0' or 'dirprobe_up_g200')
                            if shipped and not arm then
                                if g == 200 then
                                    local nMin = 1e9
                                    for _, t in pairs(tw) do
                                        local d = GetUnitToUnitDistance(bot, t)
                                        if d < nMin then nMin = d end
                                    end
                                    if nMin <= 700 then
                                        bump('domain_tower_close')
                                    else
                                        bump('domain_tower_far')
                                    end
                                    out:write(string.format('F %s %s %.3f %.2f\n',
                                        path:match('([^/]+)%.lua$'), u.name,
                                        J.GetHP(bot), nMin))
                                end
                            end
                        end
                        fGold = 0
                    end)
                    bot.GetGold = hOldGold
                    if okp then bump('probe_runs') else bump('raises') end
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
