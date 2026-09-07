-- Corpus domain census for the LANE-KILL pair `l1trade` / `l5combo`, run as a
-- SUBPROCESS (same reason as _posture_domain_sweep.lua: a full-corpus drive
-- that rebuilds jmz_func once per hero-frame must not run on run_tests.lua's
-- long-lived heap). The leading underscore keeps run_tests.lua from globbing it.
--
-- WHY THIS EXISTS.  Both ids have been armed >= 44 days (the oldest bucket of
-- `iterations/armed_since.json`) with `verify_coverage.py` reading verify=0 --
-- i.e. nobody has ever bought condition (a) for either.  Before a director
-- ruling can say WHY that is (structurally unbuyable, as with `zusstatic` /
-- `teambrain` -- or buyable and simply never bought, as with `tpdying`), the
-- APPLICABLE-FRAME POPULATION has to be priced.  This census prices it on the
-- only frame corpus that exists locally: tests/fixtures (110 fixtures).
--
-- ⛔ WHAT IT FOUND, AND WHY THAT IS NOT THE OBVIOUS READING (2026-09-07).
-- Both funnels survive every conjunct down to the LAST one and then read zero:
-- l1trade 842 laning frames -> 295 backed -> 138 with an enemy in range -> 131
-- past self-risk -> 155 shallow (bot,target) pairs -> 0 lethal -> 0 fires;
-- l5combo 130 -> 33 -> 30 -> 22 -> 16 shallow -> 11 with a core on the target
-- -> 0 lethal -> 0 fires.  It would be very easy, and WRONG, to write that up
-- as "the lever's domain is empty".  The last conjunct of both helpers is an
-- OUTGOING burst estimate (my allies -> an enemy), and this corpus is blind in
-- exactly that direction: `replay_fixture` gives every hero the damage it dealt
-- TO THE SUBJECT, so ally->enemy is identically 0 on every frame while
-- enemy->me on the SAME frames is real ground truth (`*_incoming_live` counts
-- it).  The zero measures the instrument, not the tree.  `*_est_blind` vs
-- `*_est_live` keeps the two apart at the manifest level so no later reader can
-- collapse them; `tests/test_lanekill_domain_census.lua` pins it and goes RED
-- the day the harness grows an outgoing-damage model.
--
-- CONSEQUENCE for condition (a): it is not buyable for these two ids from the
-- fixture corpus at all -- not "nobody got round to it".  Buying it needs a
-- behavioural detector on wave replays, where the engine's own estimator is
-- live.  That obligation is registered in `iterations/owed_executions.json`.
--
-- Every threshold is PARSED OUT OF THE SHIPPED SOURCE, never hardcoded (the
-- M13 lesson): move a number in jmz_func and this census moves with it.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>            a constant / structural fact parsed out of the tree
--   C <key> <n>                 a counter bucket
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
local l1 = block(src, 'function J.ShouldInitiateLaneKill( bot )')
local l5 = block(src, 'function J.ShouldSupportComboKill( bot )')
G.L1 = l1 and 1 or 0
G.L5 = l5 and 1 or 0
-- l1trade's own numbers, in the order the source states them.
G.L1_ALLY_R = l1 and tonumber(l1:match('GetNearbyHeroes%( bot, (%d+), false'))
G.L1_ENEMY_R = l1 and tonumber(l1:match('GetNearbyHeroes%( bot, (%d+), true'))
G.L1_ALLY_HP = l1 and tonumber(l1:match('GetHP%( hAlly %) >= (0%.%d+)'))
G.L1_SELFRISK = l1 and tonumber(l1:match('bot:GetHealth%(%) %* (0%.%d+)'))
G.L1_DEPTH = l1 and tonumber(l1:match('<= (%d+)%s*%)'))
G.L1_TGT_R = l1 and tonumber(l1:match('GetAlliesNearLoc%( hTarget:GetLocation%(%), (%d+) %)'))
-- l5combo's own numbers.
G.L5_ENEMY_R = l5 and tonumber(l5:match('GetNearbyHeroes%( bot, (%d+), true'))
G.L5_SELFRISK = l5 and tonumber(l5:match('bot:GetHealth%(%) %* (0%.%d+)'))
G.L5_CLOSE_R = l5 and tonumber(l5:match('<= (%d+) then'))
G.L5_CLOSE_N = l5 and tonumber(l5:match('nCloseEnemies >= (%d+)'))
G.L5_DEPTH = l5 and tonumber(l5:match('<= (%d+)%s*%)'))
G.L5_CORE_R = l5 and tonumber(l5:match('GetAlliesNearLoc%( hTarget:GetLocation%(%), (%d+) %)'))
G.L5_CORE_HP = l5 and tonumber(l5:match('GetHP%( a %) >= (0%.%d+)'))
-- The laning-phase floor both helpers sit behind (turbo leg, c2 unarmed).
local lane = block(src, 'function J.IsInLaningPhase()')
G.LANE_FLOOR = lane and tonumber(lane:match('bTurbo and (%d+) %* 60 or'))

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
for _, k in ipairs({ 'fixtures', 'live', 'lane', 'lane_core', 'lane_sup',
    -- l1trade funnel (core arm), each conjunct counted where the helper walks it
    'l1_backed', 'l1_enemies', 'l1_selfrisk_ok', 'l1_pairs', 'l1_shallow',
    'l1_lethal', 'l1_fires', 'l1_raised', 'l1_shipped_fires',
    -- l5combo funnel (support arm)
    'l5_enemies', 'l5_selfrisk_ok', 'l5_notcrowded', 'l5_pairs', 'l5_shallow',
    'l5_coreonit', 'l5_lethal', 'l5_fires', 'l5_raised', 'l5_shipped_fires',
    -- How FAR from lethal the surviving candidates are.  A funnel that dies on
    -- its last conjunct says nothing about whether the clause is a hair too
    -- strict or off by a factor of five; these buckets say which.
    'l1_ratio_ge25', 'l1_ratio_ge50', 'l1_ratio_ge75', 'l1_ratio_max_pct',
    'l5_ratio_ge25', 'l5_ratio_ge50', 'l5_ratio_ge75', 'l5_ratio_max_pct',
    -- INSTRUMENT STATE for the lethality clause, kept separate from its result.
    'l1_est_blind', 'l1_est_live', 'l5_est_blind', 'l5_est_live',
    -- The SAME engine call, read in the other direction on the SAME frames, so
    -- "the instrument is directional" is measured here and not merely argued.
    'l1_incoming_live', 'l5_incoming_live' }) do
    rawset(c, k, 0)
end

-- burst / required, as an integer percent, plus the >=25/50/75% buckets.
--
-- ⛔ READ THIS BEFORE QUOTING `*_lethal 0` OR `*_ratio_max_pct 0`.
-- On a fixture frame `GetEstimatedDamageToTarget` is GROUND TRUTH IN ONE
-- DIRECTION ONLY: `replay_fixture` gives each hero the damage it actually dealt
-- TO THE SUBJECT in the following window.  The self-risk clause (enemy -> me)
-- therefore reads a real number, and the lethality clause (my allies -> an
-- enemy target) reads 0 for every ally on every frame -- a property of the
-- corpus format, not of the tree.  `tests/mock/bot_api.lua:134` states the same
-- fact from the other side.  So a zero here is NOT "the burst was never
-- enough"; it is "this instrument cannot see outgoing burst at all".
-- `*_est_blind` / `*_est_live` say which of the two produced the number, so the
-- two can never be read as the same thing (the GH #171 shape).  The day the
-- harness grows a real outgoing-damage model, `*_est_live` goes non-zero and
-- the census starts answering the question it looks like it is answering.
local function ratio(prefix, nBurst, nNeed)
    if nNeed == nil or nNeed <= 0 then return end
    if nBurst <= 0 then bump(prefix .. '_est_blind') else bump(prefix .. '_est_live') end
    local pct = math.floor((nBurst / nNeed) * 100 + 0.5)
    if pct > c[prefix .. '_ratio_max_pct'] then
        rawset(c, prefix .. '_ratio_max_pct', pct)
    end
    if pct >= 25 then bump(prefix .. '_ratio_ge25') end
    if pct >= 50 then bump(prefix .. '_ratio_ge50') end
    if pct >= 75 then bump(prefix .. '_ratio_ge75') end
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

                    -- The gate both helpers share, priced once. `c2` stays
                    -- unarmed, so this is the shipped 8-minute turbo floor.
                    local bLane = J.IsInLaningPhase()
                    if bLane then
                        bump('lane')
                        local bCore = J.IsCore(bot)
                        if bCore then bump('lane_core') else bump('lane_sup') end

                        -- ---- l1trade (core arm). Conjunct by conjunct, in the
                        -- order the helper itself evaluates them, so a zero can
                        -- be attributed to the leg that produced it.
                        if bCore then
                            armed = { l1trade = true }
                            local tA = J.GetNearbyHeroes(bot, G.L1_ALLY_R or 1000,
                                false, BOT_MODE_NONE) or {}
                            local bBacked = false
                            for _, a in pairs(tA) do
                                if J.IsValidHero(a) and J.GetHP(a) >= (G.L1_ALLY_HP or 0.4) then
                                    bBacked = true
                                    break
                                end
                            end
                            if bBacked then
                                bump('l1_backed')
                                local tE = J.GetNearbyHeroes(bot, G.L1_ENEMY_R or 800,
                                    true, BOT_MODE_NONE) or {}
                                if #tE > 0 then
                                    bump('l1_enemies')
                                    out:write(string.format('F %s %s l1_enemies\n', short, u.name))
                                    local nIn = 0
                                    for _, e in pairs(tE) do
                                        if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e) then
                                            nIn = nIn + e:GetEstimatedDamageToTarget(
                                                true, bot, 3.0, DAMAGE_TYPE_ALL)
                                        end
                                    end
                                    if nIn > 0 then bump('l1_incoming_live') end
                                    if nIn < bot:GetHealth() * (G.L1_SELFRISK or 0.75) then
                                        bump('l1_selfrisk_ok')
                                        local hO = GetAncient(GetTeam())
                                        local hE = GetAncient(GetOpposingTeam())
                                        for _, t in pairs(tE) do
                                            if J.IsValidHero(t)
                                                and not J.IsSuspiciousIllusion(t)
                                                and not J.IsMeepoClone(t)
                                                and J.CanBeAttacked(t) then
                                                bump('l1_pairs')
                                                local bShallow = true
                                                if hO ~= nil and hE ~= nil then
                                                    local vT = t:GetLocation()
                                                    bShallow =
                                                        J.GetLocationToLocationDistance(vT, hO:GetLocation())
                                                        - J.GetLocationToLocationDistance(vT, hE:GetLocation())
                                                        <= (G.L1_DEPTH or 800)
                                                end
                                                if bShallow then
                                                    bump('l1_shallow')
                                                    local tOurs = J.GetAlliesNearLoc(
                                                        t:GetLocation(), G.L1_TGT_R or 1000)
                                                    local nB = J.GetTotalEstimatedDamageToTarget(tOurs, t)
                                                    local nNeed = t:GetHealth() + t:GetHealthRegen() * 4.0
                                                    ratio('l1', nB, nNeed)
                                                    if nB >= nNeed then
                                                        bump('l1_lethal')
                                                        out:write(string.format(
                                                            'F %s %s l1_lethal\n', short, u.name))
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            local okl, tgt = pcall(J.ShouldInitiateLaneKill, bot)
                            if not okl then bump('l1_raised')
                            elseif tgt ~= nil then
                                bump('l1_fires')
                                out:write(string.format('F %s %s l1_fires\n', short, u.name))
                            end
                            -- Control: the SHIPPED arm must be silent on every
                            -- frame. A non-zero here means the gate leaks.
                            armed = {}
                            local oks, stgt = pcall(J.ShouldInitiateLaneKill, bot)
                            if oks and stgt ~= nil then bump('l1_shipped_fires') end
                        end

                        -- ---- l5combo (support arm).
                        if not bCore then
                            armed = { l5combo = true }
                            local tE = J.GetNearbyHeroes(bot, G.L5_ENEMY_R or 900,
                                true, BOT_MODE_NONE) or {}
                            if #tE > 0 then
                                bump('l5_enemies')
                                out:write(string.format('F %s %s l5_enemies\n', short, u.name))
                                local nIn, nClose = 0, 0
                                for _, e in pairs(tE) do
                                    if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e) then
                                        nIn = nIn + e:GetEstimatedDamageToTarget(
                                            true, bot, 3.0, DAMAGE_TYPE_ALL)
                                        if GetUnitToUnitDistance(bot, e) <= (G.L5_CLOSE_R or 700) then
                                            nClose = nClose + 1
                                        end
                                    end
                                end
                                if nIn > 0 then bump('l5_incoming_live') end
                                if nIn < bot:GetHealth() * (G.L5_SELFRISK or 0.6) then
                                    bump('l5_selfrisk_ok')
                                    if nClose < (G.L5_CLOSE_N or 2) then
                                        bump('l5_notcrowded')
                                        local hO = GetAncient(GetTeam())
                                        local hE = GetAncient(GetOpposingTeam())
                                        for _, t in pairs(tE) do
                                            if J.IsValidHero(t)
                                                and not J.IsSuspiciousIllusion(t)
                                                and not J.IsMeepoClone(t)
                                                and J.CanBeAttacked(t) then
                                                bump('l5_pairs')
                                                local bShallow = true
                                                if hO ~= nil and hE ~= nil then
                                                    local vT = t:GetLocation()
                                                    bShallow =
                                                        J.GetLocationToLocationDistance(vT, hO:GetLocation())
                                                        - J.GetLocationToLocationDistance(vT, hE:GetLocation())
                                                        <= (G.L5_DEPTH or 400)
                                                end
                                                if bShallow then
                                                    bump('l5_shallow')
                                                    local bCoreOnIt = false
                                                    local tOurs = J.GetAlliesNearLoc(
                                                        t:GetLocation(), G.L5_CORE_R or 900)
                                                    for _, a in pairs(tOurs or {}) do
                                                        if a ~= bot and J.IsValidHero(a)
                                                            and J.IsCore(a)
                                                            and J.GetHP(a) >= (G.L5_CORE_HP or 0.4) then
                                                            bCoreOnIt = true
                                                            break
                                                        end
                                                    end
                                                    if bCoreOnIt then
                                                        bump('l5_coreonit')
                                                        local nB = J.GetTotalEstimatedDamageToTarget(tOurs, t)
                                                        local nNeed = t:GetHealth()
                                                            + t:GetHealthRegen() * 4.0
                                                        ratio('l5', nB, nNeed)
                                                        if nB >= nNeed then
                                                            bump('l5_lethal')
                                                            out:write(string.format(
                                                                'F %s %s l5_lethal\n', short, u.name))
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            local okl, tgt = pcall(J.ShouldSupportComboKill, bot)
                            if not okl then bump('l5_raised')
                            elseif tgt ~= nil then
                                bump('l5_fires')
                                out:write(string.format('F %s %s l5_fires\n', short, u.name))
                            end
                            armed = {}
                            local oks, stgt = pcall(J.ShouldSupportComboKill, bot)
                            if oks and stgt ~= nil then bump('l5_shipped_fires') end
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
