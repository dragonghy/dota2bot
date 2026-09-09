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
-- J.GetLaneHarassResponse's own numbers, parsed out of the shipped source in
-- the order it states them (the M13 lesson: move a number in jmz_func and this
-- census moves with it instead of quietly measuring the old one).
local hr = block(src, 'function J.GetLaneHarassResponse( bot )')
G.HR = hr and 1 or 0
G.HR_DMG_WIN = hr and tonumber(hr:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)'))
G.HR_ENEMY_R = hr and tonumber(hr:match('GetNearbyHeroes%( bot, (%d+), true'))
G.HR_ALLY_R = hr and tonumber(hr:match('GetNearbyHeroes%( bot, (%d+), false'))
G.HR_STEP = hr and tonumber(hr:match('/ n %* (%d+),'))
-- 'hrparity' (2026-09-09) reads the ally count a SECOND time on its own radius.
-- Parsed out of the armed block itself, not assumed to be 1100: the property
-- the guard claims is that the two sides of the outnumbered test use ONE ruler,
-- so the census reads the ruler the code actually picked up and
-- tests/test_hrparity_guard.lua asserts it equals HR_ENEMY_R. A hardcoded 1100
-- here would keep agreeing with a guard that had stopped symmetrising.
local hrp = hr and hr:find("IsSoakCandidate( 'hrparity' )", 1, true)
G.HR_PARITY_R = hrp
    and tonumber(hr:sub(hrp):match('GetNearbyHeroes%( bot, (%d+), false'))
-- DECLARED, not parsed and not measured: the longest attack range any hero in
-- this patch can reach (Sniper, 550 base + Take Aim + talent).  It is the bound
-- that makes `hr_fire_d_gt900` a statement about Dota rather than about
-- tests/mock/bot_api.lua's 150-unit GetAttackRange default.  It is an argument,
-- so it is labelled as one; every other G row here is parsed from source.
G.HR_UNIVERSAL_REACH_DECLARED = 900
-- Mechanism 3 of the same mega-bundle: J.IsLaneFrontTooDeepToHold's own
-- numbers, parsed in the order the source states them.  DN_ARMED_R is read out
-- of the 'deepnum' block itself and never assumed to be 1600 -- the property
-- the guard claims is that the deep tier's two counts use ONE ruler, so the
-- census picks up the ruler the code actually chose and
-- tests/test_deepnum_parity.lua asserts it equals DN_ENEMY_R.  A hardcoded
-- 1600 here would keep agreeing with a guard that had stopped symmetrising.
local dn = block(src, 'function J.IsLaneFrontTooDeepToHold( bot, vLoc )')
G.DN = dn and 1 or 0
G.DN_FLOOR = dn and tonumber(dn:match('nDepth <= (%d+) then return false end'))
G.DN_ALLY_R = dn and tonumber(dn:match('GetNearbyHeroes%( bot, (%d+), false'))
-- Anchored on the SHALLOW-TIER BODY, not on the first `nDepth <=` in the
-- function: the floor test one screen above has the identical shape, and the
-- first draft of this row silently read 400 as the tier boundary.  The two
-- routes below then disagreed (4 vs 2) -- which is the whole point of running
-- both, so it is recorded here rather than quietly repaired.
G.DN_TIER = dn and tonumber(dn:match('nDepth <= (%d+) then%s*\n%s*return nAllies == 0'))
G.DN_ENEMY_R = dn and tonumber(dn:match('GetEnemiesNearLoc%( vLoc, (%d+) %)'))
local dnp = dn and dn:find("IsSoakCandidate( 'deepnum' )", 1, true)
G.DN_ARMED_R = dnp
    and tonumber(dn:sub(dnp):match('GetNearbyHeroes%( bot, (%d+), false'))
-- Mechanism 4 of the same laning bundle: J.GetOffWaveHarassSpot ('l5trees'
-- cut 2).  Every radius is parsed off the LOCAL IT IS ASSIGNED TO, never off
-- "the first GetNearbyHeroes in the block": after this round the helper holds
-- two enemy scans, and the whole property under test is that the SIDE scan is
-- no longer the TARGET scan.  A positional read would keep agreeing with a
-- helper that had merged them back together.
local ow = block(src, 'function J.GetOffWaveHarassSpot( bot )')
G.OW = ow and 1 or 0
G.OW_TGT_R = ow and tonumber(ow:match('tEnemies = J%.GetNearbyHeroes%( bot, (%d+), true'))
G.OW_SIDE_R = ow and tonumber(ow:match('tSideEnemies = J%.GetNearbyHeroes%( bot, (%d+), true'))
G.OW_ALLY_R = ow and tonumber(ow:match('tAllies = J%.GetNearbyHeroes%( bot, (%d+), false'))
G.OW_AGGRO_R = ow and tonumber(ow:match('GetNearbyLaneCreeps%( (%d+), true %)'))
G.OW_STEP = ow and tonumber(ow:match('px %* (%d+)'))
G.OW_HP = ow and tonumber(ow:match('GetHP%( bot %) < (0%.%d+)'))
G.OW_LOOKBACK = ow and tonumber(ow:match('WasRecentlyDamagedByAnyHero%( (%d+%.%d+) %)'))
-- The one call site, parsed out of the caller rather than described here: the
-- claim "this helper is reachable only under 'l5trees'" is load-bearing for the
-- decision NOT to give this change an id of its own, and last round's sister
-- finding was exactly a header making that claim falsely.
local lg = read_file('bots/mode_laning_generic.lua')
local owc = lg:find('J.GetOffWaveHarassSpot(bot)', 1, true)
G.OW_CALLSITES = 0
do
    local at = 1
    while true do
        local hit = lg:find('J.GetOffWaveHarassSpot(bot)', at, true)
        if hit == nil then break end
        G.OW_CALLSITES = G.OW_CALLSITES + 1
        at = hit + 10
    end
end
-- The gate expression guarding that call site, taken verbatim from the `if`
-- that opens the branch, so the test can read it for disjunctions.
G.OW_GATE_HAS_L5 = 0
G.OW_GATE_HAS_OR = 0
G.OW_GATE_WESTRONGER_R = nil
if owc then
    local head = lg:sub(1, owc)
    -- the last `if` that opens a branch before the call
    local ifat, at = nil, 1
    while true do
        local hit = head:find('\n\tif ', at, true)
        if hit == nil then break end
        ifat, at = hit, hit + 1
    end
    if ifat then
        local gate = head:sub(ifat)
        if gate:find("IsSoakCandidate('l5trees')", 1, true) then G.OW_GATE_HAS_L5 = 1 end
        if gate:find(' or ', 1, true) then G.OW_GATE_HAS_OR = 1 end
        G.OW_GATE_WESTRONGER_R = tonumber(gate:match('WeAreStronger%(bot, (%d+)%)'))
    end
end

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
    'l1_incoming_live', 'l5_incoming_live',
    -- J.GetLaneHarassResponse funnel, in the order the helper walks it.
    'hr_lane', 'hr_dmg2', 'hr_dmg2_lane', 'hr_valid_zero', 'hr_valid_nonzero',
    'hr_back', 'hr_fire', 'hr_fire_lane', 'hr_nil', 'hr_raised',
    -- How far the 'fire' handle is from the bot that is ordered to attack it.
    'hr_fire_d_gt900', 'hr_fire_d_gt700', 'hr_fire_d_gt_stubreach',
    'hr_fire_d_max_u',
    -- Whether this corpus can say what the subject's reach is at all.
    'hr_range_stub', 'hr_range_live',
    -- The two-radius parity test (enemies to 1100, allies to 900).
    'hr_asym_ally_band', 'hr_asym_enemy_band', 'hr_asym_flips',
    -- 'hrreach' differential (same function, second drive, id armed).
    'hr2_fire', 'hr2_back', 'hr2_nil', 'hr2_raised',
    'hr_closes', 'hr_closes_universal', 'hr_closes_stubonly',
    'hr_opens', 'hr_back_moved', 'hr_target_swapped',
    -- 'hrparity' differential (same function, third drive, only that id armed)
    -- plus the SECOND, independent path to the same number: `hp_pred_flips` is
    -- arithmetic on the raw populations, `hp_back_closes` is what the shipped
    -- function actually did when driven armed. They are equal only if the guard
    -- keys on the parity test at all (the M5 lesson from the 'hrreach' round).
    'hp2_fire', 'hp2_back', 'hp2_nil', 'hp2_raised', 'hp_noparse',
    'hp_pred_flips', 'hp_back_closes', 'hp_back_opens', 'hp_nil_moved',
    'hp_fire_opened', 'hp_ally_disc_differs', 'hp_ally_illusion', 'hp_ally_illusion_noapi', 'hp_ally_nonempty',
    -- The two ids live in the SAME helper, so a wave that arms both is a third
    -- behaviour, not the sum of two readings.  Measured here rather than argued
    -- later: `hp_opened_far` is the honest bad news about arming 'hrparity'
    -- alone, `hpb_*` is what the pair does together.
    'hp_opened_d_max_u',
    'hpb_fire', 'hpb_back', 'hpb_nil', 'hpb_raised', 'hpb_flip_ends_nil',
    -- 'deepnum' / J.IsLaneFrontTooDeepToHold (mechanism 3), priced at
    -- vLoc = bot:GetLocation().  Two routes to one number by design:
    -- `dn_pred_flips` is arithmetic on the raw populations, `dn_closes` is what
    -- the shipped function did when driven armed.
    -- 'l5trees' cut 2 / J.GetOffWaveHarassSpot (mechanism 4).  `ow_creeps_zero`
    -- is the INSTRUMENT column and it comes first on purpose: the helper cannot
    -- fire on a frame without an enemy lane creep within OW_AGGRO_R, and this
    -- corpus carries no creeps at all, so every `ow_drive_*` row below is taken
    -- under the declared stub described at the census itself.  A reader who
    -- skips that column will read the drive rows as Dota; they are not.
    'ow_live', 'ow_creeps_zero', 'ow_creeps_live', 'ow_hp_ok', 'ow_peel_supp',
    'ow_target', 'ow_reach', 'ow_side_pop_differs', 'ow_band',
    'ow_vote_ge90', 'ow_vote_deg_max', 'ow_side_flips', 'ow_side_same',
    'ow_drive_nonnil', 'ow_drive_nil_on_reach', 'ow_drive_raised',
    'ow_drive_matches_wide', 'ow_drive_matches_narrow', 'ow_step_u',
    'ow_flip_close400_wide', 'ow_flip_close400_narrow', 'ow_flip_nearer_someone',
    'dn_live', 'dn_lane', 'dn_noancient', 'dn_underfloor', 'dn_tier1',
    'dn_tier2', 'dn_tier2_enemies', 'dn_disc_differs', 'dn_pred_flips',
    'dn_shipped_true', 'dn_armed_true', 'dn_closes', 'dn_opens', 'dn_raised' }) do
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

                    -- ---- J.GetLaneHarassResponse (2026-09-09 column set).
                    -- Priced OUTSIDE `if bLane`: unlike the two helpers above,
                    -- this one carries no laning gate of its own -- the laning
                    -- phase is a property of its only CALLER, so pricing it
                    -- inside bLane would report the caller's domain as the
                    -- helper's. `hr_lane` re-splits it afterwards.
                    armed = {}
                    if bLane then bump('hr_lane') end
                    if bot:WasRecentlyDamagedByAnyHero(G.HR_DMG_WIN or 2.0) then
                        bump('hr_dmg2')
                        if bLane then bump('hr_dmg2_lane') end

                        -- The bot's OWN reach, and whether this corpus can say
                        -- what it is.  tests/mock/bot_api.lua defaults
                        -- GetAttackRange to 150 and NO fixture carries an
                        -- attack_range field, so on this corpus the answer is a
                        -- CONSTANT STUB, not ground truth (GH #656's shape).
                        -- Every bucket below that compares against it is
                        -- therefore a statement about the loader; the
                        -- `_gt900` / `_gt700` buckets are the ones that are not
                        -- (see the G_HR_UNIVERSAL_REACH note).
                        local nMyReach = bot:GetAttackRange()
                        if nMyReach == 150 then bump('hr_range_stub')
                        else bump('hr_range_live') end

                        local tE = J.GetNearbyHeroes(bot, G.HR_ENEMY_R or 1100,
                            true, BOT_MODE_NONE) or {}
                        local tValid = {}
                        for _, e in pairs(tE) do
                            if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e)
                                and J.CanBeAttacked(e) then
                                tValid[#tValid + 1] = e
                            end
                        end
                        if #tValid == 0 then
                            bump('hr_valid_zero')
                        else
                            bump('hr_valid_nonzero')
                            -- The parity test the helper runs, and the SAME
                            -- test with both populations read at one radius.
                            -- The helper counts enemies to HR_ENEMY_R and
                            -- allies to HR_ALLY_R; when those differ, an enemy
                            -- in the band counts as a harasser while an ally
                            -- standing at the identical distance does not.
                            local tA9 = J.GetNearbyHeroes(bot, G.HR_ALLY_R or 900,
                                false, BOT_MODE_NONE) or {}
                            local tA11 = J.GetNearbyHeroes(bot, G.HR_ENEMY_R or 1100,
                                false, BOT_MODE_NONE) or {}
                            local bOutnumShipped = #tValid > (1 + #tA9)
                            local bOutnumEven = #tValid > (1 + #tA11)
                            if #tA11 > #tA9 then bump('hr_asym_ally_band') end
                            if bOutnumShipped ~= bOutnumEven then
                                bump('hr_asym_flips')
                                out:write(string.format('F %s %s hr_asym_flips\n',
                                    short, u.name))
                            end
                            for _, e in pairs(tValid) do
                                if GetUnitToUnitDistance(bot, e) > (G.HR_ALLY_R or 900) then
                                    bump('hr_asym_enemy_band')
                                    break
                                end
                            end
                            -- 'hrparity' PREDICTION, on the radius parsed out
                            -- of the armed block (never assumed).  A missing
                            -- parse is counted, not defaulted: silently reading
                            -- 1100 here would let a guard that had stopped
                            -- symmetrising keep agreeing with its own census.
                            if G.HR_PARITY_R == nil then
                                bump('hp_noparse')
                            else
                                local tAp = J.GetNearbyHeroes(bot, G.HR_PARITY_R,
                                    false, BOT_MODE_NONE) or {}
                                -- Does this corpus even distinguish the two ally
                                -- discs?  Unlike GetAttackRange (a constant stub
                                -- on every frame, GH #656), positions are real
                                -- fixture data -- and this column is the proof
                                -- rather than the claim.
                                if #tAp ~= #tA9 then bump('hp_ally_disc_differs') end
                                -- PRICED, NOT FIXED (the next lever in this
                                -- helper, or the evidence that it cannot be
                                -- priced here): the enemy side drops illusions
                                -- and unattackable units before counting, the
                                -- ally side counts whatever GetNearbyHeroes
                                -- hands back.  So the outnumbered test can
                                -- still be asymmetric AFTER 'hrparity' -- on
                                -- filtering rather than on radius.
                                -- Two columns, because a zero here has two
                                -- possible causes and they are not the same
                                -- finding (the GH #171 shape): "this corpus
                                -- carries no ally illusions" and "the loader
                                -- has no IsIllusion to ask" must never be read
                                -- off one number.
                                if #tAp > 0 then bump('hp_ally_nonempty') end
                                for _, a in pairs(tAp) do
                                    if a.IsIllusion == nil then
                                        bump('hp_ally_illusion_noapi')
                                        break
                                    elseif a:IsIllusion() then
                                        bump('hp_ally_illusion')
                                        break
                                    end
                                end
                                if bOutnumShipped ~= (#tValid > (1 + #tAp)) then
                                    bump('hp_pred_flips')
                                    out:write(string.format('F %s %s hp_pred_flips\n',
                                        short, u.name))
                                end
                            end
                        end

                        local okh, sResp, xResp = pcall(J.GetLaneHarassResponse, bot)
                        if not okh then
                            bump('hr_raised')
                        elseif sResp == 'back' then
                            bump('hr_back')
                        elseif sResp == 'fire' then
                            bump('hr_fire')
                            if bLane then bump('hr_fire_lane') end
                            -- THE READING THIS COLUMN SET EXISTS FOR.  The
                            -- caller turns this handle into
                            -- `bot:Action_AttackUnit(x, true)`, an order the
                            -- engine serves by WALKING to the target when it is
                            -- out of reach.  So the distance of the returned
                            -- target is the distance the bot is being sent.
                            local d = GetUnitToUnitDistance(bot, xResp)
                            if d > c.hr_fire_d_max_u then
                                rawset(c, 'hr_fire_d_max_u', math.floor(d))
                            end
                            -- LOADER-INDEPENDENT.  No hero in this patch
                            -- attacks past ~900 (Sniper is the longest at
                            -- 550 base + Take Aim + talent), so a target beyond
                            -- G_HR_UNIVERSAL_REACH is out of reach whatever the
                            -- subject's real attack range is -- these two
                            -- buckets survive the GetAttackRange stub.
                            if d > 900 then bump('hr_fire_d_gt900') end
                            if d > 700 then bump('hr_fire_d_gt700') end
                            -- LOADER-DEPENDENT, and named so: 150 is the stub.
                            if d > nMyReach then bump('hr_fire_d_gt_stubreach') end
                            if bLane and d > 900 then
                                out:write(string.format('F %s %s hr_fire_far_lane\n',
                                    short, u.name))
                            end
                        else
                            bump('hr_nil')
                        end

                        -- DIFFERENTIAL: the same shipped function driven a
                        -- second time with 'hrreach' armed. Both drives close
                        -- over the whole entered population, so a zero column
                        -- can never be confused with a column that never ran.
                        armed = { hrreach = true }
                        local ok2, s2, x2 = pcall(J.GetLaneHarassResponse, bot)
                        armed = {}
                        if not ok2 then
                            bump('hr2_raised')
                        elseif s2 == 'fire' then
                            bump('hr2_fire')
                        elseif s2 == 'back' then
                            bump('hr2_back')
                        else
                            bump('hr2_nil')
                        end
                        -- The two FORBIDDEN directions and the one permitted
                        -- one. `hr_opens` and `hr_back_moved` must read 0 on a
                        -- clean tree: the armed candidate set is a strict
                        -- subset, so it can only delete a 'fire'.
                        if okh and ok2 then
                            if sResp ~= 'fire' and s2 == 'fire' then
                                bump('hr_opens')
                            end
                            if (sResp == 'back') ~= (s2 == 'back') then
                                bump('hr_back_moved')
                            end
                            if sResp == 'fire' and s2 ~= 'fire' then
                                bump('hr_closes')
                                -- Split the kill by WHY, because on this corpus
                                -- most of it is the 150 stub talking. Only the
                                -- >900 half survives a real GetAttackRange.
                                local dk = GetUnitToUnitDistance(bot, xResp)
                                if dk > 900 then bump('hr_closes_universal')
                                else bump('hr_closes_stubonly') end
                            end
                            if sResp == 'fire' and s2 == 'fire' and xResp ~= x2 then
                                bump('hr_target_swapped')
                            end
                        end

                        -- DIFFERENTIAL 2: the same shipped function, a THIRD
                        -- drive, with only 'hrparity' armed.  Kept separate
                        -- from the 'hrreach' drive above on purpose -- the two
                        -- ids sit in the same helper and an isolation wave arms
                        -- one of them, so the census has to be able to say what
                        -- each one does ALONE (the lanefix bundle lesson).
                        armed = { hrparity = true }
                        local ok3, s3, x3 = pcall(J.GetLaneHarassResponse, bot)
                        armed = {}
                        if not ok3 then
                            bump('hp2_raised')
                        elseif s3 == 'fire' then
                            bump('hp2_fire')
                        elseif s3 == 'back' then
                            bump('hp2_back')
                        else
                            bump('hp2_nil')
                        end
                        -- Direction, one way by construction: the armed ally
                        -- set is a SUPERSET, so nOurs can only grow and the
                        -- outnumbered verdict can only go true -> false.  Armed
                        -- may delete a 'back'; it may never create one, and it
                        -- may never move a frame into or out of the nil bucket
                        -- (nil is decided above the parity test entirely).
                        if okh and ok3 then
                            if sResp == 'back' and s3 ~= 'back' then
                                bump('hp_back_closes')
                            end
                            if sResp ~= 'back' and s3 == 'back' then
                                bump('hp_back_opens')
                            end
                            if (sResp == nil) ~= (s3 == nil) then
                                bump('hp_nil_moved')
                            end
                            if sResp ~= 'fire' and s3 == 'fire' then
                                bump('hp_fire_opened')
                                -- WHERE the opened fire is pointed.  A frame
                                -- that stops retreating hands the caller an
                                -- attack order, and the caller serves an
                                -- out-of-reach one by WALKING -- which is
                                -- exactly the defect 'hrreach' exists for. This
                                -- column is the reason this round does not
                                -- recommend arming 'hrparity' by itself.
                                -- MEASURED, not thresholded: no bucket here can
                                -- be loader-independent, because whether a
                                -- given distance is "out of reach" needs
                                -- GetAttackRange and this corpus stubs it at
                                -- 150 (GH #656).  The distance itself is real
                                -- fixture data, so the census reports it and
                                -- the per-hero reach argument is made on the
                                -- named witnesses in test_hrparity_guard.lua,
                                -- where the subject's patch range can be cited.
                                local dO = GetUnitToUnitDistance(bot, x3)
                                if dO > c.hp_opened_d_max_u then
                                    rawset(c, 'hp_opened_d_max_u', math.floor(dO))
                                end
                            end
                        end

                        -- DIFFERENTIAL 3: BOTH ids armed.  Two gates in one
                        -- helper compose; a wave that arms the pair measures
                        -- this drive and neither of the two above.
                        armed = { hrparity = true, hrreach = true }
                        local ok4, s4 = pcall(J.GetLaneHarassResponse, bot)
                        armed = {}
                        if not ok4 then
                            bump('hpb_raised')
                        elseif s4 == 'fire' then
                            bump('hpb_fire')
                        elseif s4 == 'back' then
                            bump('hpb_back')
                        else
                            bump('hpb_nil')
                        end
                        if okh and ok3 and ok4
                            and sResp == 'back' and s3 == 'fire' and s4 == nil then
                            -- The frames 'hrparity' un-retreats and 'hrreach'
                            -- then declines to charge: the pair leaves the bot
                            -- standing in its lane on the shipped farm body.
                            bump('hpb_flip_ends_nil')
                        end
                    end

                    -- ---- mechanism 3 of the SAME mega-bundle:
                    -- J.IsLaneFrontTooDeepToHold, and the 'deepnum' guard on
                    -- its deep tier.  Priced OUTSIDE the `bLane` block on
                    -- purpose: unlike the two helpers above, this one carries
                    -- no laning-phase conjunct of its own, so restricting the
                    -- census to laning frames would price the CALLER's domain
                    -- and print it under the helper's name.  `dn_lane` keeps
                    -- the caller's slice visible without deciding it.
                    --
                    -- ⛔ PRICING CONVENTION, and it is a limit not a result.
                    -- The helper is a function of (bot, vLoc) and the real
                    -- vLoc is a lane-front location, which this corpus cannot
                    -- produce: the loader REFUSES GetLaneFrontLocation (GH #61)
                    -- and lane geometry is an open corpus request (GH #648 /
                    -- #652).  So every row below is taken at
                    -- vLoc = bot:GetLocation() -- the one spot the frame
                    -- actually witnesses a hero standing on, and the same vLoc
                    -- tests/test_replay_megabundle_laning.lua already drives.
                    -- At that vLoc the two discs share a centre, so what these
                    -- rows measure is exactly the RADIUS half of the defect
                    -- (1000 vs 1600) and nothing about the centre half.  A
                    -- reader who wants the centre priced needs the corpus
                    -- request, not a bigger number here.
                    local vHere = bot:GetLocation()
                    local hOwnA = GetAncient(GetTeam())
                    local hEnyA = GetAncient(GetOpposingTeam())
                    bump('dn_live')
                    if bLane then bump('dn_lane') end
                    if hOwnA == nil or hEnyA == nil then
                        bump('dn_noancient')
                    else
                        -- ARITHMETIC PATH: raw populations only, no gate, no
                        -- call into the helper.  Everything here is positions
                        -- and ancients, the two things this corpus answers
                        -- without a stub.
                        local nDepth = J.GetLocationToLocationDistance(vHere, hOwnA:GetLocation())
                            - J.GetLocationToLocationDistance(vHere, hEnyA:GetLocation())
                        if nDepth <= (G.DN_FLOOR or 400) then
                            bump('dn_underfloor')
                        elseif nDepth <= (G.DN_TIER or 1600) then
                            bump('dn_tier1')
                        else
                            bump('dn_tier2')
                            local function count_allies(r)
                                local n = 0
                                for _, a in pairs(J.GetNearbyHeroes(bot, r, false, BOT_MODE_NONE) or {}) do
                                    if J.IsValidHero(a) then n = n + 1 end
                                end
                                return n
                            end
                            local nNear = count_allies(G.DN_ALLY_R or 1000)
                            local nWide = count_allies(G.DN_ARMED_R or 1600)
                            local nEn = #J.GetEnemiesNearLoc(vHere, G.DN_ENEMY_R or 1600)
                            if nWide > nNear then bump('dn_disc_differs') end
                            if nEn > 0 then bump('dn_tier2_enemies') end
                            -- The arithmetic statement of the flip, computed
                            -- from the populations rather than from the
                            -- function: shipped says "too deep", the one-ruler
                            -- comparison says "holdable".
                            if (1 + nNear) <= nEn and (1 + nWide) > nEn then
                                bump('dn_pred_flips')
                                out:write(string.format('F %s %s dn_pred_flips\n',
                                    short, u.name))
                            end
                        end

                        -- DRIVE PATH: the shipped function twice, unarmed and
                        -- with only 'deepnum' armed.  `dn_closes` must come out
                        -- equal to `dn_pred_flips` -- two independent routes to
                        -- one number, which is the only thing that can catch a
                        -- guard that stopped keying on the parity test.
                        armed = {}
                        local okD1, d1 = pcall(J.IsLaneFrontTooDeepToHold, bot, vHere)
                        armed = { deepnum = true }
                        local okD2, d2 = pcall(J.IsLaneFrontTooDeepToHold, bot, vHere)
                        armed = {}
                        if not okD1 or not okD2 then
                            bump('dn_raised')
                        else
                            if d1 then bump('dn_shipped_true') end
                            if d2 then bump('dn_armed_true') end
                            -- By construction the armed ally set is a superset,
                            -- so only true -> false is reachable.  `dn_opens`
                            -- is the FORBIDDEN direction and is asserted zero.
                            if d1 and not d2 then bump('dn_closes') end
                            if d2 and not d1 then bump('dn_opens') end
                        end
                    end

                    -- ---- mechanism 4 of the SAME laning bundle:
                    -- J.GetOffWaveHarassSpot ('l5trees' cut 2), and the ruler
                    -- its SIDE choice reads.
                    --
                    -- ⛔ INSTRUMENT FIRST, and it is a limit not a result.  The
                    -- helper's third conjunct is `GetNearbyLaneCreeps(500,true)
                    -- non-empty`, and this corpus carries NO CREEPS ON ANY
                    -- FRAME (`ow_creeps_zero`; the same fact
                    -- J.IsLaneZonedByEnemy's header states from the other end).
                    -- So the drive rows below inject ONE creep, and they say so
                    -- in their names.  The injection is bounded by the helper's
                    -- own precondition rather than invented: a creep list that
                    -- passes the conjunct is a list of creeps within
                    -- OW_AGGRO_R of the bot, so its centroid is within
                    -- OW_AGGRO_R of a point this frame really did witness a
                    -- hero standing on.  Putting the single creep AT the bot is
                    -- the centre of that ball -- the deepnum vLoc convention,
                    -- with a radius bound the deepnum case did not have.  What
                    -- it still cannot price is a lane axis that disagrees with
                    -- (bot -> own fountain); that is the open corpus request
                    -- (GH #648 / #652), and `ow_vote_ge90` is the column that
                    -- survives it -- see below.
                    local vMe = bot:GetLocation()
                    bump('ow_live')
                    local okC, tRealCreeps = pcall(function()
                        return bot:GetNearbyLaneCreeps(G.OW_AGGRO_R or 500, true)
                    end)
                    if okC and tRealCreeps ~= nil and #tRealCreeps > 0 then
                        bump('ow_creeps_live')
                    else
                        bump('ow_creeps_zero')
                    end

                    -- The helper's own conjuncts, in its order, on real data.
                    local bOwHp = J.GetHP(bot) >= (G.OW_HP or 0.5)
                    if bOwHp then bump('ow_hp_ok') end
                    local bPeel = false
                    if bot:WasRecentlyDamagedByAnyHero(G.OW_LOOKBACK or 2.0) then
                        bPeel = true
                    else
                        for _, a in pairs(J.GetNearbyHeroes(bot, G.OW_ALLY_R or 1200,
                            false, BOT_MODE_NONE) or {}) do
                            if J.IsValidHero(a) and a.WasRecentlyDamagedByAnyHero ~= nil
                                and a:WasRecentlyDamagedByAnyHero(G.OW_LOOKBACK or 2.0) then
                                bPeel = true
                                break
                            end
                        end
                    end
                    if bPeel then bump('ow_peel_supp') end
                    local tOwT = J.GetNearbyHeroes(bot, G.OW_TGT_R or 800, true, BOT_MODE_NONE) or {}
                    local bOwTgt = false
                    for _, e in pairs(tOwT) do
                        if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e) then
                            bOwTgt = true
                            break
                        end
                    end
                    if bOwTgt then bump('ow_target') end

                    if bOwHp and not bPeel and bOwTgt then
                        -- Every conjunct the corpus can answer is satisfied;
                        -- only the creep conjunct is missing, and it is missing
                        -- for instrument reasons.
                        bump('ow_reach')
                        local tOwS = J.GetNearbyHeroes(bot, G.OW_SIDE_R or 1200,
                            true, BOT_MODE_NONE) or {}
                        -- The two votes, each counted the way the helper counts
                        -- them (J.IsValidHero, no illusion filter on the side
                        -- census -- untouched this round and deliberately so).
                        local function centroid(t)
                            local x, y, n = 0, 0, 0
                            for _, e in pairs(t) do
                                if J.IsValidHero(e) then
                                    local v = e:GetLocation()
                                    x, y, n = x + v.x, y + v.y, n + 1
                                end
                            end
                            if n == 0 then return nil end
                            return x / n - vMe.x, y / n - vMe.y, n
                        end
                        local ax, ay, nN = centroid(tOwT)
                        local bx, by, nW = centroid(tOwS)
                        if nW ~= nil and nN ~= nil and nW > nN then
                            bump('ow_side_pop_differs')
                        end
                        for _, e in pairs(tOwS) do
                            if J.IsValidHero(e)
                                and GetUnitToUnitDistance(bot, e) > (G.OW_TGT_R or 800) then
                                bump('ow_band')
                                break
                            end
                        end
                        -- LOADER-INDEPENDENT column: the angle between the two
                        -- vote directions needs no lane axis at all.  A flip
                        -- happens iff the axis perpendicular separates them, so
                        -- an angle >= 90 degrees means MORE THAN HALF of all
                        -- conceivable lane axes flip the side on this frame.
                        -- This is the row that survives the missing lane
                        -- geometry; `ow_side_flips` below does not.
                        if ax ~= nil and bx ~= nil then
                            local la = math.sqrt(ax * ax + ay * ay)
                            local lb = math.sqrt(bx * bx + by * by)
                            if la > 1 and lb > 1 then
                                local cosv = (ax * bx + ay * by) / (la * lb)
                                if cosv > 1 then cosv = 1 elseif cosv < -1 then cosv = -1 end
                                local deg = math.deg(math.acos(cosv))
                                if deg >= 90 then
                                    bump('ow_vote_ge90')
                                    out:write(string.format('F %s %s ow_vote_ge90\n',
                                        short, u.name))
                                end
                                if math.floor(deg) > c.ow_vote_deg_max then
                                    rawset(c, 'ow_vote_deg_max', math.floor(deg))
                                end
                            end
                        end

                        -- DRIVE PATH, under the declared creep injection.  The
                        -- axis is then (bot -> own fountain) exactly, so the
                        -- arithmetic side and the driven side are computable
                        -- from the same p and must agree: two independent
                        -- routes to one number, which is the only thing that
                        -- catches a helper that stopped keying on its own
                        -- census.
                        local vF = J.GetTeamFountain()
                        if vF ~= nil then
                            local dx, dy = vF.x - vMe.x, vF.y - vMe.y
                            local mag = math.max(math.sqrt(dx * dx + dy * dy), 1)
                            local px, py = -(dy / mag), dx / mag
                            local function side_spot(cx, cy)
                                local qx, qy = px, py
                                if cx ~= nil and (qx * cx + qy * cy) > 0 then
                                    qx, qy = -qx, -qy
                                end
                                return vMe.x + qx * (G.OW_STEP or 550),
                                    vMe.y + qy * (G.OW_STEP or 550)
                            end
                            local wx, wy = side_spot(bx, by)   -- the fixed rule
                            local sx, sy = side_spot(ax, ay)   -- the old rule
                            if math.abs(wx - sx) > 1 or math.abs(wy - sy) > 1 then
                                bump('ow_side_flips')
                                out:write(string.format('F %s %s ow_side_flips\n',
                                    short, u.name))
                                -- ⚠️ THE COST OF THE WIDER VOTE, measured on
                                -- the same frames rather than argued away.
                                -- Flipping the side to clear the band enemy can
                                -- step TOWARD the hero being poked -- that is
                                -- the trade this change makes, and these two
                                -- columns are the only place a reader can see
                                -- its size.  400 is a declared bucket edge, not
                                -- a threshold in any shipped code.
                                local function nearest(qx, qy)
                                    local best = nil
                                    for _, e in pairs(tOwS) do
                                        if J.IsValidHero(e) then
                                            local v = e:GetLocation()
                                            local d = math.sqrt((qx - v.x) ^ 2 + (qy - v.y) ^ 2)
                                            if best == nil or d < best then best = d end
                                        end
                                    end
                                    return best
                                end
                                local dW, dS = nearest(wx, wy), nearest(sx, sy)
                                if dW ~= nil and dW < 400 then bump('ow_flip_close400_wide') end
                                if dS ~= nil and dS < 400 then bump('ow_flip_close400_narrow') end
                                if dW ~= nil and dS ~= nil and dW < dS then
                                    bump('ow_flip_nearer_someone')
                                end
                            else
                                bump('ow_side_same')
                                -- The NEGATIVE CONTROL population, named on the
                                -- manifest: the board really did change (an
                                -- enemy in the band got a vote) and the answer
                                -- did not.  Without these a reader cannot tell
                                -- "the wider census is doing something" from
                                -- "the wider census is doing everything".
                                if bx ~= nil and nW ~= nil and nN ~= nil and nW > nN then
                                    out:write(string.format('F %s %s ow_band_no_flip\n',
                                        short, u.name))
                                end
                            end
                            local fReal = bot.GetNearbyLaneCreeps
                            local fakeCreep = {
                                IsNull = function() return false end,
                                CanBeSeen = function() return true end,
                                IsAlive = function() return true end,
                                IsBuilding = function() return false end,
                                GetLocation = function() return Vector(vMe.x, vMe.y, vMe.z or 0) end,
                            }
                            bot.GetNearbyLaneCreeps = function(_, _r, bEnemy)
                                if bEnemy then return { fakeCreep } end
                                return {}
                            end
                            local okS, vSpot = pcall(J.GetOffWaveHarassSpot, bot)
                            bot.GetNearbyLaneCreeps = fReal
                            if not okS then
                                bump('ow_drive_raised')
                            elseif vSpot == nil then
                                -- FORBIDDEN DIRECTION.  Whether the helper
                                -- fires is decided by the TARGET list, which
                                -- this round did not touch; a frame that passes
                                -- every conjunct and still returns nil means
                                -- the side census leaked into the gate.
                                bump('ow_drive_nil_on_reach')
                            else
                                bump('ow_drive_nonnil')
                                if math.abs(vSpot.x - wx) < 1 and math.abs(vSpot.y - wy) < 1 then
                                    bump('ow_drive_matches_wide')
                                end
                                if math.abs(vSpot.x - sx) < 1 and math.abs(vSpot.y - sy) < 1 then
                                    bump('ow_drive_matches_narrow')
                                end
                                local dStep = math.floor(math.sqrt(
                                    (vSpot.x - vMe.x) ^ 2 + (vSpot.y - vMe.y) ^ 2) + 0.5)
                                if dStep > c.ow_step_u then rawset(c, 'ow_step_u', dStep) end
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
